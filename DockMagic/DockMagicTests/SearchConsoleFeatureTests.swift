import Foundation
import SwiftData
import XCTest
@testable import DockMagic

@MainActor
final class SearchConsoleFeatureTests: XCTestCase {
    func testDefaultConfigurationMatchesAdaptiveFocusMockup() {
        let configuration = SearchConsoleConfiguration.defaultValue
        XCTAssertEqual(configuration.primaryMetric, .clicks)
        XCTAssertEqual(configuration.timeRange, .last7Days)
        XCTAssertEqual(configuration.displayMode, .focus)
        XCTAssertFalse(configuration.isConnected)
        XCTAssertEqual(SearchConsoleStore.refreshIntervalSeconds, 300)
    }

    func testServiceAccountJSONValidationAndMetadataExtraction() throws {
        let account = try SearchConsoleServiceAccountFile(
            data: serviceAccountJSON()
        )
        XCTAssertEqual(account.type, "service_account")
        XCTAssertEqual(account.projectID, "dockmagic-tests")
        XCTAssertEqual(
            account.clientEmail,
            "dockmagic@dockmagic-tests.iam.gserviceaccount.com"
        )
        XCTAssertEqual(account.metadata.privateKeyID, "key-123")

        XCTAssertThrowsError(
            try SearchConsoleServiceAccountFile(
                data: serviceAccountJSON(type: "authorized_user")
            )
        ) { error in
            XCTAssertEqual(
                error as? SearchConsoleConfigurationError,
                .invalidAccountType
            )
        }
    }

    func testCountFormattingForDockDensity() {
        XCTAssertEqual(SearchConsoleCountFormatting.compact(824), "824")
        XCTAssertEqual(SearchConsoleCountFormatting.compact(2_400), "2.4K")
        XCTAssertEqual(SearchConsoleCountFormatting.compact(184_000), "184K")
        XCTAssertEqual(SearchConsoleCountFormatting.compact(1_250_000), "1.3M")
    }

    func testImportStoresOnlyPrivateKeyInVaultAndPersistsConfiguration() async throws {
        let container = SearchConsoleStore.inMemoryContainer()
        let vault = SearchConsoleTestVault()
        let api = SearchConsoleTestAPI()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: api,
            vault: vault
        )

        try await store.importServiceAccountJSON(serviceAccountJSON())

        XCTAssertTrue(store.configuration.isConnected)
        XCTAssertEqual(store.configuration.selectedProperty, "sc-domain:example.com")
        XCTAssertEqual(store.availableSites.count, 2)
        XCTAssertNotNil(store.state.snapshot)
        XCTAssertEqual(
            vault.value(for: "service-account.key-123"),
            "-----BEGIN PRIVATE KEY-----\nZmFrZQ==\n-----END PRIVATE KEY-----"
        )

        let records = try ModelContext(container).fetch(
            FetchDescriptor<SearchConsoleConfigurationRecord>()
        )
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].projectID, "dockmagic-tests")
        XCTAssertEqual(records[0].privateKeyID, "key-123")
        XCTAssertEqual(
            records[0].credentialReference,
            "service-account.key-123"
        )
        XCTAssertNotNil(records[0].cachedSnapshotData)

        let reloaded = SearchConsoleStore(
            modelContainer: container,
            api: api,
            vault: vault
        )
        XCTAssertEqual(reloaded.configuration, store.configuration)
        XCTAssertNotNil(reloaded.state.snapshot)
    }

    func testEveryMetricRangeAndDisplayModePersistsThroughSwiftData() {
        let container = SearchConsoleStore.inMemoryContainer()
        let vault = SearchConsoleTestVault()
        let api = SearchConsoleTestAPI()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: api,
            vault: vault
        )

        for metric in SearchConsoleMetric.allCases {
            for range in SearchConsoleTimeRange.allCases {
                for mode in SearchConsoleDisplayMode.allCases {
                    store.setPrimaryMetric(metric)
                    store.setTimeRange(range)
                    store.setDisplayMode(mode)

                    let reloaded = SearchConsoleStore(
                        modelContainer: container,
                        api: api,
                        vault: vault
                    )
                    XCTAssertEqual(reloaded.configuration.primaryMetric, metric)
                    XCTAssertEqual(reloaded.configuration.timeRange, range)
                    XCTAssertEqual(reloaded.configuration.displayMode, mode)
                }
            }
        }
    }

    func testRefreshRetainsLastSnapshotWhenGoogleFails() async throws {
        let api = SearchConsoleTestAPI()
        let store = SearchConsoleStore(
            modelContainer: SearchConsoleStore.inMemoryContainer(),
            api: api,
            vault: SearchConsoleTestVault()
        )
        try await store.importServiceAccountJSON(serviceAccountJSON())
        let previous = try XCTUnwrap(store.state.snapshot)

        api.performanceError = SearchConsoleAPIError.requestFailed(
            status: 403,
            message: "Permission denied"
        )
        await store.refresh()

        guard case let .stale(snapshot, message) = store.state else {
            return XCTFail("Expected stale cached data after a refresh failure")
        }
        XCTAssertEqual(snapshot, previous)
        XCTAssertTrue(message.contains("403"))
        XCTAssertTrue(message.contains("Permission denied"))
    }

    func testDisconnectDeletesVaultSecretAndSwiftDataRecord() async throws {
        let container = SearchConsoleStore.inMemoryContainer()
        let vault = SearchConsoleTestVault()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: SearchConsoleTestAPI(),
            vault: vault
        )
        try await store.importServiceAccountJSON(serviceAccountJSON())

        try store.disconnect()

        XCTAssertEqual(store.state, .disconnected)
        XCTAssertNil(vault.value(for: "service-account.key-123"))
        XCTAssertTrue(
            try ModelContext(container).fetch(
                FetchDescriptor<SearchConsoleConfigurationRecord>()
            ).isEmpty
        )
    }

    func testAppModelRunsSearchConsoleOnlyWhenItIsTheActiveDockFeature() {
        let suiteName = "DockMagicTests.SearchConsoleActive.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .searchConsole
        let searchConsole = SearchConsoleStore.uiTestFixture()
        let appModel = DockAppModel(
            preferences: preferences,
            searchConsoleStore: searchConsole
        )

        appModel.start()

        XCTAssertTrue(appModel.isRunning)
        XCTAssertTrue(searchConsole.isMonitoring)
        XCTAssertFalse(appModel.metricsStore.isMonitoring)
        XCTAssertFalse(appModel.networkStore.isMonitoring)
        XCTAssertFalse(appModel.storageStore.isMonitoring)
        XCTAssertFalse(appModel.weatherStore.isMonitoring)
        XCTAssertFalse(appModel.batteryStore.isMonitoring)
        XCTAssertFalse(appModel.codexStore.isMonitoring)
        XCTAssertFalse(appModel.claudeCodeStore.isMonitoring)

        appModel.stop()

        XCTAssertFalse(appModel.isRunning)
        XCTAssertFalse(searchConsole.isMonitoring)
    }

    func testAPIClientBuildsReadOnlyOAuthAndAnalyticsRequests() async throws {
        SearchConsoleURLProtocolStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchConsoleURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let client = SearchConsoleAPIClient(
            session: session,
            assertionFactory: { _, _, _ in "signed.jwt" }
        )
        let metadata = SearchConsoleServiceAccountMetadata(
            projectID: "dockmagic-tests",
            privateKeyID: "key-123",
            clientEmail: "dockmagic@dockmagic-tests.iam.gserviceaccount.com",
            tokenURI: URL(string: "https://oauth2.googleapis.com/token")!
        )

        let sites = try await client.sites(
            metadata: metadata,
            privateKey: "unused"
        )
        XCTAssertEqual(sites.map(\.siteURL), ["sc-domain:example.com"])

        let now = Date(timeIntervalSince1970: 1_786_600_000)
        let snapshot = try await client.performance(
            property: "sc-domain:example.com",
            range: .last24Hours,
            metadata: metadata,
            privateKey: "unused",
            now: now
        )
        XCTAssertEqual(snapshot.points.count, 2)
        XCTAssertEqual(snapshot.clicks, 23)
        XCTAssertEqual(snapshot.impressions, 1_850)

        let requests = SearchConsoleURLProtocolStub.requests
        XCTAssertEqual(
            requests.filter { $0.url?.host == "oauth2.googleapis.com" }.count,
            1,
            "The OAuth token should be cached between calls."
        )
        let query = try XCTUnwrap(
            requests.first {
                $0.url?.absoluteString.contains("searchAnalytics/query") == true
            }
        )
        XCTAssertTrue(
            query.url?.absoluteString.contains("sc-domain%3Aexample.com") == true
        )
        XCTAssertEqual(query.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        let body = try XCTUnwrap(query.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["dataState"] as? String, "hourly_all")
        XCTAssertEqual(json["dimensions"] as? [String], ["hour"])
        XCTAssertEqual(json["rowLimit"] as? Int, 25_000)
    }

    func testAPIClientMapsEveryConfiguredTimeRangeToGoogleQuery() async throws {
        SearchConsoleURLProtocolStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchConsoleURLProtocolStub.self]
        let client = SearchConsoleAPIClient(
            session: URLSession(configuration: configuration),
            assertionFactory: { _, _, _ in "signed.jwt" }
        )
        let metadata = SearchConsoleServiceAccountMetadata(
            projectID: "dockmagic-tests",
            privateKeyID: "key-123",
            clientEmail: "dockmagic@dockmagic-tests.iam.gserviceaccount.com",
            tokenURI: URL(string: "https://oauth2.googleapis.com/token")!
        )
        let now = Date(timeIntervalSince1970: 1_786_600_000)

        for range in SearchConsoleTimeRange.allCases {
            _ = try await client.performance(
                property: "sc-domain:example.com",
                range: range,
                metadata: metadata,
                privateKey: "unused",
                now: now
            )
        }

        let queryRequests = SearchConsoleURLProtocolStub.requests.filter {
            $0.url?.absoluteString.contains("searchAnalytics/query") == true
        }
        XCTAssertEqual(queryRequests.count, SearchConsoleTimeRange.allCases.count)

        for (range, request) in zip(SearchConsoleTimeRange.allCases, queryRequests) {
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["rowLimit"] as? Int, 25_000)
            XCTAssertEqual(
                json["dimensions"] as? [String],
                [range == .last24Hours ? "hour" : "date"]
            )
            XCTAssertEqual(
                json["dataState"] as? String,
                range == .last24Hours ? "hourly_all" : "all"
            )
            XCTAssertNotNil(json["startDate"] as? String)
            XCTAssertNotNil(json["endDate"] as? String)
        }

        XCTAssertEqual(
            SearchConsoleURLProtocolStub.requests.filter {
                $0.url?.host == "oauth2.googleapis.com"
            }.count,
            1,
            "All range queries should reuse the same unexpired access token."
        )
    }

    private func serviceAccountJSON(
        type: String = "service_account"
    ) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "type": type,
            "project_id": "dockmagic-tests",
            "private_key_id": "key-123",
            "private_key": "-----BEGIN PRIVATE KEY-----\nZmFrZQ==\n-----END PRIVATE KEY-----",
            "client_email": "dockmagic@dockmagic-tests.iam.gserviceaccount.com",
            "token_uri": "https://oauth2.googleapis.com/token"
        ])
    }
}

private final class SearchConsoleTestVault:
    SearchConsoleCredentialVault, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    func store(privateKey: String, reference: String) throws {
        lock.withLock { storage[reference] = privateKey }
    }

    func load(reference: String) throws -> String? {
        lock.withLock { storage[reference] }
    }

    func delete(reference: String) throws {
        _ = lock.withLock { storage.removeValue(forKey: reference) }
    }

    func value(for reference: String) -> String? {
        lock.withLock { storage[reference] }
    }
}

private final class SearchConsoleTestAPI:
    SearchConsoleAPIProviding, @unchecked Sendable {
    private let lock = NSLock()
    var performanceError: Error?

    func sites(
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String
    ) async throws -> [SearchConsoleSite] {
        [
            SearchConsoleSite(
                siteURL: "sc-domain:example.com",
                permissionLevel: "siteFullUser"
            ),
            SearchConsoleSite(
                siteURL: "https://www.example.com/",
                permissionLevel: "siteFullUser"
            )
        ]
    }

    func performance(
        property: String,
        range: SearchConsoleTimeRange,
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String,
        now: Date
    ) async throws -> SearchConsoleSnapshot {
        if let error = lock.withLock({ performanceError }) { throw error }
        return SearchConsoleSnapshot(
            property: property,
            range: range,
            points: [
                SearchConsoleDataPoint(
                    key: "2026-08-12",
                    date: Date(timeIntervalSince1970: 1_786_492_800),
                    clicks: 2_400,
                    impressions: 184_000
                )
            ],
            fetchedAt: now,
            firstIncompleteDate: now
        )
    }
}

private final class SearchConsoleURLProtocolStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var capturedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.withLock { capturedRequests }
    }

    static func reset() {
        lock.withLock { capturedRequests = [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var bytes: [UInt8] = []
            let bufferSize = 1_024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: bufferSize)
                guard count > 0 else { break }
                bytes.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = Data(bytes)
        }
        Self.lock.withLock { Self.capturedRequests.append(captured) }
        let url = request.url!
        let body: Data
        if url.host == "oauth2.googleapis.com" {
            body = Data(#"{"access_token":"test-token","expires_in":3600}"#.utf8)
        } else if url.path.hasSuffix("/sites") {
            body = Data(
                #"{"siteEntry":[{"siteUrl":"sc-domain:example.com","permissionLevel":"siteFullUser"}]}"#.utf8
            )
        } else {
            body = Data(
                #"{"rows":[{"keys":["2026-08-12T08:00:00-07:00"],"clicks":11,"impressions":900},{"keys":["2026-08-12T09:00:00-07:00"],"clicks":12,"impressions":950}],"metadata":{"firstIncompleteHour":"2026-08-12T09:00:00-07:00"}}"#.utf8
            )
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
