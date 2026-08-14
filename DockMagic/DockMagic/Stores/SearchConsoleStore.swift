import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SearchConsoleStore {
    static let refreshInterval: Duration = .seconds(300)
    static let refreshIntervalSeconds: TimeInterval = 300

    private(set) var configuration: SearchConsoleConfiguration
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
    private let vault: any SearchConsoleCredentialVault
    @ObservationIgnored
    private let clock = ContinuousClock()
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var configurationRecord: SearchConsoleConfigurationRecord?

    init(
        modelContainer: ModelContainer? = nil,
        api: any SearchConsoleAPIProviding = SearchConsoleAPIClient(),
        vault: any SearchConsoleCredentialVault =
            KeychainSearchConsoleCredentialVault()
    ) {
        let container = modelContainer ?? Self.makeDefaultContainer()
        self.modelContainer = container
        self.context = ModelContext(container)
        self.api = api
        self.vault = vault

        let record = try? context.fetch(
            FetchDescriptor<SearchConsoleConfigurationRecord>()
        ).first
        configurationRecord = record
        let loadedConfiguration = record?.configuration ?? .defaultValue
        configuration = loadedConfiguration
        if let data = record?.cachedSnapshotData,
           let snapshot = try? JSONDecoder().decode(
               SearchConsoleSnapshot.self,
               from: data
           ) {
            state = .stale(snapshot, message: "Refreshing cached Search Console data…")
        } else {
            state = loadedConfiguration.isConnected ? .loading(nil) : .disconnected
        }
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
        guard !isRefreshing, configuration.isConnected,
              let metadata = configuration.metadata,
              let reference = configuration.credentialReference else {
            if !configuration.isConnected { state = .disconnected }
            return
        }

        isRefreshing = true
        let previous = state.snapshot
        state = .loading(previous)
        defer { isRefreshing = false }

        do {
            guard let privateKey = try vault.load(reference: reference) else {
                throw SearchConsoleConfigurationError.missingPrivateKey
            }
            let snapshot = try await api.performance(
                property: configuration.selectedProperty,
                range: configuration.timeRange,
                metadata: metadata,
                privateKey: privateKey,
                now: .now
            )
            state = .live(snapshot)
            persist(snapshot: snapshot)
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
        let newReference = "service-account.\(account.privateKeyID)"
        let oldReference = configuration.credentialReference
        let oldPrivateKey = try oldReference.flatMap { try vault.load(reference: $0) }

        try vault.store(privateKey: account.privateKey, reference: newReference)
        do {
            let sites = try await api.sites(
                metadata: account.metadata,
                privateKey: account.privateKey
            )
            guard !sites.isEmpty else {
                throw SearchConsoleConfigurationError.noAccessibleProperties
            }

            var updated = configuration
            updated.metadata = account.metadata
            updated.credentialReference = newReference
            if !sites.contains(where: { $0.siteURL == updated.selectedProperty }) {
                updated.selectedProperty = sites[0].siteURL
            }
            configuration = updated
            availableSites = sites
            persistConfiguration()

            if let oldReference, oldReference != newReference {
                try? vault.delete(reference: oldReference)
            }
            await refresh()
        } catch {
            if newReference == oldReference, let oldPrivateKey {
                try? vault.store(privateKey: oldPrivateKey, reference: newReference)
            } else {
                try? vault.delete(reference: newReference)
            }
            throw error
        }
    }

    func reloadSites() async {
        guard let metadata = configuration.metadata,
              let reference = configuration.credentialReference else {
            availableSites = []
            return
        }
        do {
            guard let privateKey = try vault.load(reference: reference) else {
                throw SearchConsoleConfigurationError.missingPrivateKey
            }
            availableSites = try await api.sites(
                metadata: metadata,
                privateKey: privateKey
            )
        } catch {
            if let snapshot = state.snapshot {
                state = .stale(snapshot, message: error.localizedDescription)
            } else {
                state = .unavailable(error.localizedDescription)
            }
        }
    }

    func disconnect() throws {
        stop()
        if let reference = configuration.credentialReference {
            try vault.delete(reference: reference)
        }
        if let record = configurationRecord {
            context.delete(record)
            try context.save()
        }
        configurationRecord = nil
        configuration = .defaultValue
        availableSites = []
        state = .disconnected
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
        guard configuration.selectedProperty != property else { return }
        configuration.selectedProperty = property
        persistConfiguration()
        Task { await refresh() }
    }

    private func persistConfiguration() {
        let record: SearchConsoleConfigurationRecord
        if let configurationRecord {
            record = configurationRecord
        } else {
            record = SearchConsoleConfigurationRecord()
            context.insert(record)
            configurationRecord = record
        }
        record.update(from: configuration)
        try? context.save()
    }

    private func persist(snapshot: SearchConsoleSnapshot) {
        persistConfiguration()
        configurationRecord?.cachedSnapshotData = try? JSONEncoder().encode(snapshot)
        configurationRecord?.updatedAt = .now
        try? context.save()
    }

    private static func makeDefaultContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: SearchConsoleConfigurationRecord.self)
        } catch {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: SearchConsoleConfigurationRecord.self,
                configurations: configuration
            )
        }
    }

    static func inMemoryContainer() -> ModelContainer {
        try! ModelContainer(
            for: SearchConsoleConfigurationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    static func uiTestFixture() -> SearchConsoleStore {
        let vault = InMemorySearchConsoleCredentialVault()
        let reference = "service-account.ui-test"
        try? vault.store(privateKey: "fixture-private-key", reference: reference)
        let container = inMemoryContainer()
        let context = ModelContext(container)
        let record = SearchConsoleConfigurationRecord(
            projectID: "dockmagic-ui-tests",
            privateKeyID: "ui-test",
            clientEmail: "dockmagic@seo-metrics.iam.gserviceaccount.com",
            selectedProperty: "sc-domain:example.com",
            credentialReference: reference
        )
        record.cachedSnapshotData = try? JSONEncoder().encode(
            SearchConsoleFixtureAPI.snapshot
        )
        context.insert(record)
        try? context.save()
        return SearchConsoleStore(
            modelContainer: container,
            api: SearchConsoleFixtureAPI(),
            vault: vault
        )
    }
}

struct SearchConsoleFixtureAPI: SearchConsoleAPIProviding {
    static let sites = [
        SearchConsoleSite(siteURL: "sc-domain:example.com", permissionLevel: "siteFullUser"),
        SearchConsoleSite(siteURL: "https://www.example.com/", permissionLevel: "siteFullUser")
    ]

    static let snapshot: SearchConsoleSnapshot = {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -6, to: .now) ?? .now
        // A realistic seven-day shape with the same 2.4K / 184K totals used
        // by the selected Adaptive Focus reference.
        let clicks = [340, 400, 310, 420, 210, 450, 270]
        let impressions = [24_000, 28_000, 23_000, 29_000, 18_000, 38_000, 24_000]
        return SearchConsoleSnapshot(
            property: "sc-domain:example.com",
            range: .last7Days,
            points: clicks.indices.map { index in
                let date = calendar.date(byAdding: .day, value: index, to: start) ?? start
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
