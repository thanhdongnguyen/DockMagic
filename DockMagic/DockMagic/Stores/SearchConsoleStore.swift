import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SearchConsoleStore {
    static let refreshInterval: Duration = .seconds(300)
    static let refreshIntervalSeconds: TimeInterval = 300

    private(set) var configuration: SearchConsoleConfiguration
    private(set) var credentials: [SearchConsoleCredential]
    private(set) var state: SearchConsoleState
    private(set) var availableSites: [SearchConsoleSite] = []
    private(set) var isRefreshing = false
    private(set) var isMonitoring = false

    @ObservationIgnored
    private let modelContainer: ModelContainer
    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private let api: any SearchConsoleAPIProviding
    @ObservationIgnored
    private let clock = ContinuousClock()
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var configurationRecord: SearchConsoleConfigurationRecord
    @ObservationIgnored
    private var credentialRecords: [SearchConsoleCredentialRecord]

    init(
        modelContainer: ModelContainer? = nil,
        api: any SearchConsoleAPIProviding = SearchConsoleAPIClient()
    ) {
        let container = modelContainer ?? Self.makeDefaultContainer()
        let context = ModelContext(container)
        let storedConfiguration = try? context.fetch(
            FetchDescriptor<SearchConsoleConfigurationRecord>()
        ).first
        let configurationRecord = storedConfiguration
            ?? SearchConsoleConfigurationRecord()
        if storedConfiguration == nil {
            context.insert(configurationRecord)
        }

        let descriptor = FetchDescriptor<SearchConsoleCredentialRecord>(
            sortBy: [SortDescriptor(\SearchConsoleCredentialRecord.createdAt)]
        )
        let credentialRecords = (try? context.fetch(descriptor)) ?? []
        let activeRecord = credentialRecords.first {
            $0.identifier == configurationRecord.activeCredentialIdentifier
        } ?? credentialRecords.first
        if configurationRecord.activeCredentialIdentifier != activeRecord?.identifier {
            configurationRecord.activeCredentialIdentifier = activeRecord?.identifier
        }

        self.modelContainer = container
        self.context = context
        self.api = api
        self.configurationRecord = configurationRecord
        self.credentialRecords = credentialRecords
        self.configuration = configurationRecord.configuration(
            credential: activeRecord
        )
        self.credentials = credentialRecords.map {
            $0.summary(isActive: $0.identifier == activeRecord?.identifier)
        }
        self.state = Self.initialState(
            credential: activeRecord,
            isConnected: activeRecord != nil
        )

        try? context.save()
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                do {
                    try await self.clock.sleep(for: Self.refreshInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }

    func stop() {
        isMonitoring = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        guard !isRefreshing,
              let record = activeCredentialRecord,
              let account = record.serviceAccount,
              !record.selectedProperty.isEmpty else {
            if activeCredentialRecord == nil { state = .disconnected }
            return
        }

        isRefreshing = true
        let previous = state.snapshot
        state = .loading(previous)
        defer { isRefreshing = false }

        do {
            let snapshot = try await api.performance(
                property: record.selectedProperty,
                range: configuration.timeRange,
                metadata: account.metadata,
                privateKey: account.privateKey,
                now: .now
            )
            state = .live(snapshot)
            persist(snapshot: snapshot, for: record)
        } catch {
            if let previous {
                state = .stale(previous, message: error.localizedDescription)
            } else {
                state = .unavailable(error.localizedDescription)
            }
        }
    }

    func importServiceAccountJSON(_ data: Data) async throws {
        let account = try SearchConsoleServiceAccountFile(data: data)
        let sites = try await api.sites(
            metadata: account.metadata,
            privateKey: account.privateKey
        )
        guard !sites.isEmpty else {
            throw SearchConsoleConfigurationError.noAccessibleProperties
        }

        let existing = credentialRecords.first {
            $0.privateKeyID == account.privateKeyID
                && $0.clientEmail == account.clientEmail
        }
        let preferredProperty = existing?.selectedProperty ?? ""
        let selectedProperty = sites.contains {
            $0.siteURL == preferredProperty
        } ? preferredProperty : sites[0].siteURL

        let record: SearchConsoleCredentialRecord
        if let existing {
            existing.update(
                serviceAccountJSONData: data,
                account: account,
                selectedProperty: selectedProperty
            )
            record = existing
        } else {
            record = SearchConsoleCredentialRecord(
                serviceAccountJSONData: data,
                account: account,
                selectedProperty: selectedProperty
            )
            context.insert(record)
            credentialRecords.append(record)
            credentialRecords.sort { $0.createdAt < $1.createdAt }
        }

        configurationRecord.activeCredentialIdentifier = record.identifier
        clearLegacyCredentialFields()
        configuration = configurationRecord.configuration(credential: record)
        availableSites = sites
        state = Self.initialState(credential: record, isConnected: true)
        syncCredentialSummaries()
        try context.save()
        await refresh()
    }

    func selectCredential(_ identifier: String) async {
        guard configurationRecord.activeCredentialIdentifier != identifier,
              let record = credentialRecords.first(where: {
                  $0.identifier == identifier
              }) else {
            return
        }

        configurationRecord.activeCredentialIdentifier = identifier
        configurationRecord.updatedAt = .now
        configuration = configurationRecord.configuration(credential: record)
        availableSites = []
        state = Self.initialState(credential: record, isConnected: true)
        syncCredentialSummaries()
        try? context.save()
        await reloadSites()
        await refresh()
    }

    func removeCredential(_ identifier: String) async throws {
        guard let index = credentialRecords.firstIndex(where: {
            $0.identifier == identifier
        }) else {
            return
        }

        let wasActive = configurationRecord.activeCredentialIdentifier == identifier
        let record = credentialRecords.remove(at: index)
        context.delete(record)

        if wasActive {
            let replacement = credentialRecords.first
            configurationRecord.activeCredentialIdentifier = replacement?.identifier
            configurationRecord.updatedAt = .now
            configuration = configurationRecord.configuration(
                credential: replacement
            )
            availableSites = []
            state = Self.initialState(
                credential: replacement,
                isConnected: replacement != nil
            )
        }

        syncCredentialSummaries()
        try context.save()

        if wasActive, activeCredentialRecord != nil {
            await reloadSites()
            await refresh()
        }
    }

    func reloadSites() async {
        guard let record = activeCredentialRecord,
              let account = record.serviceAccount else {
            availableSites = []
            return
        }
        do {
            availableSites = try await api.sites(
                metadata: account.metadata,
                privateKey: account.privateKey
            )
        } catch {
            if let snapshot = state.snapshot {
                state = .stale(snapshot, message: error.localizedDescription)
            } else {
                state = .unavailable(error.localizedDescription)
            }
        }
    }

    func setRendererColor(_ color: DockColor, for metric: SearchConsoleMetric) {
        if metric == .clicks { configuration.clicksColor = color }
        else { configuration.impressionsColor = color }
        persistConfiguration()
    }

    func resetRendererColors() {
        configuration.clicksColor = SearchConsoleConfiguration.defaultClicksColor
        configuration.impressionsColor = SearchConsoleConfiguration.defaultImpressionsColor
        persistConfiguration()
    }

    func setPrimaryMetric(_ metric: SearchConsoleMetric) {
        guard configuration.primaryMetric != metric else { return }
        configuration.primaryMetric = metric
        persistConfiguration()
    }

    func setDisplayMode(_ mode: SearchConsoleDisplayMode) {
        guard configuration.displayMode != mode else { return }
        configuration.displayMode = mode
        persistConfiguration()
    }

    func setTimeRange(_ range: SearchConsoleTimeRange) {
        guard configuration.timeRange != range else { return }
        configuration.timeRange = range
        persistConfiguration()
        Task { await refresh() }
    }

    func setSelectedProperty(_ property: String) {
        guard let record = activeCredentialRecord,
              record.selectedProperty != property else {
            return
        }
        record.selectedProperty = property
        record.updatedAt = .now
        configuration.selectedProperty = property
        syncCredentialSummaries()
        try? context.save()
        Task { await refresh() }
    }

    private var activeCredentialRecord: SearchConsoleCredentialRecord? {
        credentialRecords.first {
            $0.identifier == configurationRecord.activeCredentialIdentifier
        }
    }

    private func persistConfiguration() {
        configurationRecord.updatePreferences(from: configuration)
        try? context.save()
    }

    private func persist(
        snapshot: SearchConsoleSnapshot,
        for record: SearchConsoleCredentialRecord
    ) {
        persistConfiguration()
        record.cachedSnapshotData = try? JSONEncoder().encode(snapshot)
        record.updatedAt = .now
        syncCredentialSummaries()
        try? context.save()
    }

    private func syncCredentialSummaries() {
        let activeIdentifier = configurationRecord.activeCredentialIdentifier
        credentials = credentialRecords.map {
            $0.summary(isActive: $0.identifier == activeIdentifier)
        }
    }

    private func clearLegacyCredentialFields() {
        configurationRecord.projectID = ""
        configurationRecord.privateKeyID = ""
        configurationRecord.clientEmail = ""
        configurationRecord.tokenURI = "https://oauth2.googleapis.com/token"
        configurationRecord.selectedProperty = ""
        configurationRecord.credentialReference = nil
        configurationRecord.cachedSnapshotData = nil
        configurationRecord.updatedAt = .now
    }

    private static func initialState(
        credential: SearchConsoleCredentialRecord?,
        isConnected: Bool
    ) -> SearchConsoleState {
        if let data = credential?.cachedSnapshotData,
           let snapshot = try? JSONDecoder().decode(
               SearchConsoleSnapshot.self,
               from: data
           ) {
            return .stale(
                snapshot,
                message: "Refreshing cached Search Console data…"
            )
        }
        return isConnected ? .loading(nil) : .disconnected
    }

    private static func makeDefaultContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: SearchConsoleConfigurationRecord.self,
                SearchConsoleCredentialRecord.self
            )
        } catch {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: SearchConsoleConfigurationRecord.self,
                SearchConsoleCredentialRecord.self,
                configurations: configuration
            )
        }
    }

    static func inMemoryContainer() -> ModelContainer {
        try! ModelContainer(
            for: SearchConsoleConfigurationRecord.self,
            SearchConsoleCredentialRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    static func uiTestFixture() -> SearchConsoleStore {
        let container = inMemoryContainer()
        let context = ModelContext(container)
        let primaryData = fixtureServiceAccountJSON(
            projectID: "seo-metrics",
            privateKeyID: "ui-test-primary",
            clientEmail: "dockmagic@seo-metrics.iam.gserviceaccount.com"
        )
        let secondaryData = fixtureServiceAccountJSON(
            projectID: "marketing-reports",
            privateKeyID: "ui-test-secondary",
            clientEmail: "analytics@marketing-reports.iam.gserviceaccount.com"
        )
        let primaryAccount = try! SearchConsoleServiceAccountFile(
            data: primaryData
        )
        let secondaryAccount = try! SearchConsoleServiceAccountFile(
            data: secondaryData
        )
        let primary = SearchConsoleCredentialRecord(
            serviceAccountJSONData: primaryData,
            account: primaryAccount,
            selectedProperty: "sc-domain:example.com",
            cachedSnapshotData: try? JSONEncoder().encode(
                SearchConsoleFixtureAPI.snapshot
            ),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let secondary = SearchConsoleCredentialRecord(
            serviceAccountJSONData: secondaryData,
            account: secondaryAccount,
            selectedProperty: "https://www.example.com/",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let configuration = SearchConsoleConfigurationRecord(
            activeCredentialIdentifier: primary.identifier
        )
        context.insert(configuration)
        context.insert(primary)
        context.insert(secondary)
        try? context.save()
        return SearchConsoleStore(
            modelContainer: container,
            api: SearchConsoleFixtureAPI()
        )
    }

    private static func fixtureServiceAccountJSON(
        projectID: String,
        privateKeyID: String,
        clientEmail: String
    ) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "type": "service_account",
            "project_id": projectID,
            "private_key_id": privateKeyID,
            "private_key": "-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----",
            "client_email": clientEmail,
            "token_uri": "https://oauth2.googleapis.com/token"
        ])
    }
}

struct SearchConsoleFixtureAPI: SearchConsoleAPIProviding {
    static let sites = [
        SearchConsoleSite(
            siteURL: "sc-domain:example.com",
            permissionLevel: "siteFullUser"
        ),
        SearchConsoleSite(
            siteURL: "https://www.example.com/",
            permissionLevel: "siteFullUser"
        )
    ]

    static let snapshot: SearchConsoleSnapshot = {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -6, to: .now) ?? .now
        let clicks = [340, 400, 310, 420, 210, 450, 270]
        let impressions = [24_000, 28_000, 23_000, 29_000, 18_000, 38_000, 24_000]
        return SearchConsoleSnapshot(
            property: "sc-domain:example.com",
            range: .last7Days,
            points: clicks.indices.map { index in
                let date = calendar.date(
                    byAdding: .day,
                    value: index,
                    to: start
                ) ?? start
                return SearchConsoleDataPoint(
                    key: date.formatted(.iso8601.year().month().day()),
                    date: date,
                    clicks: Double(clicks[index]),
                    impressions: Double(impressions[index])
                )
            },
            fetchedAt: .now,
            firstIncompleteDate: .now
        )
    }()

    func sites(
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String
    ) async throws -> [SearchConsoleSite] {
        Self.sites
    }

    func performance(
        property: String,
        range: SearchConsoleTimeRange,
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String,
        now: Date
    ) async throws -> SearchConsoleSnapshot {
        let base = Self.snapshot
        return SearchConsoleSnapshot(
            property: property,
            range: range,
            points: base.points,
            fetchedAt: now,
            firstIncompleteDate: base.firstIncompleteDate
        )
    }
}
