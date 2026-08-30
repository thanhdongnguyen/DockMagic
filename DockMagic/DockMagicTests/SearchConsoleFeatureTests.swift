import Foundation
import Security
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

    func testImportStoresCompleteJSONInSwiftDataAndReloadsConfiguration() async throws {
        let container = SearchConsoleStore.inMemoryContainer()
        let api = SearchConsoleTestAPI()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: api
        )
        let json = serviceAccountJSON()

        try await store.importServiceAccountJSON(json)

        XCTAssertTrue(store.configuration.isConnected)
        XCTAssertEqual(store.configuration.selectedProperty, "sc-domain:example.com")
        XCTAssertEqual(store.availableSites.count, 2)
        XCTAssertEqual(store.credentials.count, 1)
        XCTAssertTrue(store.credentials[0].isActive)
        XCTAssertNotNil(store.state.snapshot)

        let configurationRecords = try ModelContext(container).fetch(
            FetchDescriptor<SearchConsoleConfigurationRecord>()
        )
        XCTAssertEqual(configurationRecords.count, 1)
        XCTAssertEqual(
            configurationRecords[0].activeCredentialIdentifier,
            store.credentials[0].id
        )
        XCTAssertNil(configurationRecords[0].credentialReference)

        let credentialRecords = try ModelContext(container).fetch(
            FetchDescriptor<SearchConsoleCredentialRecord>()
        )
        XCTAssertEqual(credentialRecords.count, 1)
        XCTAssertEqual(credentialRecords[0].projectID, "dockmagic-tests")
        XCTAssertEqual(credentialRecords[0].privateKeyID, "key-123")
        XCTAssertEqual(credentialRecords[0].serviceAccountJSONData, json)
        XCTAssertNotNil(credentialRecords[0].cachedSnapshotData)

        let reloaded = SearchConsoleStore(
            modelContainer: container,
            api: api
        )
        XCTAssertEqual(reloaded.configuration, store.configuration)
        XCTAssertEqual(reloaded.credentials, store.credentials)
        XCTAssertNotNil(reloaded.state.snapshot)
    }

    func testImportAcceptsGoogleStylePKCS8KeyThroughOAuthAndRefresh() async throws {
        SearchConsoleURLProtocolStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchConsoleURLProtocolStub.self]
        let generatedKey = try googleStylePKCS8Key()
        let container = SearchConsoleStore.inMemoryContainer()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: SearchConsoleAPIClient(
                session: URLSession(configuration: configuration)
            )
        )
        let json = serviceAccountJSON(
            privateKeyID: "generated-key",
            privateKey: generatedKey.pem
        )

        try await store.importServiceAccountJSON(json)

        XCTAssertTrue(store.configuration.isConnected)
        XCTAssertEqual(store.configuration.selectedProperty, "sc-domain:example.com")
        XCTAssertEqual(store.availableSites.map(\.siteURL), ["sc-domain:example.com"])
        XCTAssertNotNil(store.state.snapshot)
        let storedCredential = try XCTUnwrap(
            ModelContext(container).fetch(
                FetchDescriptor<SearchConsoleCredentialRecord>()
            ).first
        )
        XCTAssertEqual(storedCredential.serviceAccountJSONData, json)
        XCTAssertEqual(
            SearchConsoleURLProtocolStub.requests.filter {
                $0.url?.host == "oauth2.googleapis.com"
            }.count,
            1,
            "Import and refresh should share the access token."
        )
        XCTAssertEqual(
            SearchConsoleURLProtocolStub.requests.filter {
                $0.url?.path.hasSuffix("/sites") == true
            }.count,
            1
        )
        XCTAssertEqual(
            SearchConsoleURLProtocolStub.requests.filter {
                $0.url?.path.hasSuffix("/searchAnalytics/query") == true
            }.count,
            1
        )
    }

    func testEveryMetricRangeAndDisplayModePersistsThroughSwiftData() {
        let container = SearchConsoleStore.inMemoryContainer()
        let api = SearchConsoleTestAPI()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: api
        )

        for metric in SearchConsoleMetric.allCases {
            for range in SearchConsoleTimeRange.allCases {
                for mode in SearchConsoleDisplayMode.allCases {
                    store.setPrimaryMetric(metric)
                    store.setTimeRange(range)
                    store.setDisplayMode(mode)

                    let reloaded = SearchConsoleStore(
                        modelContainer: container,
                        api: api
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
            api: api
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

    func testMultipleJSONKeysCanBeSelectedAndRemovedIndependently() async throws {
        let container = SearchConsoleStore.inMemoryContainer()
        let store = SearchConsoleStore(
            modelContainer: container,
            api: SearchConsoleTestAPI()
        )
        try await store.importServiceAccountJSON(serviceAccountJSON())
        let firstID = try XCTUnwrap(store.credentials.first?.id)
        store.setPrimaryMetric(.impressions)
        store.setTimeRange(.last28Days)

        try await store.importServiceAccountJSON(
            serviceAccountJSON(
                projectID: "secondary-project",
                privateKeyID: "key-456",
                clientEmail: "analytics@secondary-project.iam.gserviceaccount.com"
            )
        )

        XCTAssertEqual(store.credentials.count, 2)
        XCTAssertEqual(
            store.credentials.first(where: \.isActive)?.privateKeyID,
            "key-456"
        )
        XCTAssertEqual(store.configuration.metadata?.projectID, "secondary-project")
        XCTAssertEqual(store.configuration.primaryMetric, .impressions)
        XCTAssertEqual(store.configuration.timeRange, .last28Days)

        await store.selectCredential(firstID)

        XCTAssertEqual(store.configuration.metadata?.privateKeyID, "key-123")
        XCTAssertEqual(
            store.credentials.first(where: \.isActive)?.id,
            firstID
        )
        let secondaryID = try XCTUnwrap(
            store.credentials.first { $0.privateKeyID == "key-456" }?.id
        )
        try await store.removeCredential(secondaryID)

        XCTAssertEqual(store.credentials.count, 1)
        XCTAssertEqual(store.credentials[0].id, firstID)
        XCTAssertTrue(store.configuration.isConnected)

        try await store.removeCredential(firstID)

        XCTAssertTrue(store.credentials.isEmpty)
        XCTAssertEqual(store.state, .disconnected)
        XCTAssertTrue(
            try ModelContext(container).fetch(
                FetchDescriptor<SearchConsoleCredentialRecord>()
            ).isEmpty
        )
        XCTAssertEqual(
            try ModelContext(container).fetch(
                FetchDescriptor<SearchConsoleConfigurationRecord>()
            ).count,
            1,
            "Display preferences remain after the last JSON key is removed."
        )
    }

    func testAppModelRunsSearchConsoleWithBackgroundStreakCollection() {
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
        XCTAssertTrue(appModel.codexStore.isMonitoring)
        XCTAssertEqual(
            appModel.claudeCodeStore.isMonitoring,
            appModel.claudeCodeStore.isBridgeInstalled
        )

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

    func testAPIClientSignsGoogleStylePKCS8PrivateKey() async throws {
        SearchConsoleURLProtocolStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchConsoleURLProtocolStub.self]
        let client = SearchConsoleAPIClient(
            session: URLSession(configuration: configuration)
        )
        let generatedKey = try googleStylePKCS8Key()
        let metadata = SearchConsoleServiceAccountMetadata(
            projectID: "dockmagic-tests",
            privateKeyID: "generated-key",
            clientEmail: "dockmagic@dockmagic-tests.iam.gserviceaccount.com",
            tokenURI: URL(string: "https://oauth2.googleapis.com/token")!
        )

        let sites = try await client.sites(
            metadata: metadata,
            privateKey: generatedKey.pem
        )
        XCTAssertEqual(sites.map(\.siteURL), ["sc-domain:example.com"])

        let tokenRequest = try XCTUnwrap(
            SearchConsoleURLProtocolStub.requests.first {
                $0.url?.host == "oauth2.googleapis.com"
            }
        )
        let body = try XCTUnwrap(tokenRequest.httpBody)
        var components = URLComponents()
        components.percentEncodedQuery = String(decoding: body, as: UTF8.self)
        let assertion = try XCTUnwrap(
            components.queryItems?.first { $0.name == "assertion" }?.value
        )
        let segments = assertion.split(separator: ".")
        XCTAssertEqual(segments.count, 3)

        let message = Data("\(segments[0]).\(segments[1])".utf8)
        let signature = try XCTUnwrap(base64URLDecoded(segments[2]))
        var verificationError: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            generatedKey.publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            message as CFData,
            signature as CFData,
            &verificationError
        )
        XCTAssertTrue(
            isValid,
            verificationError?.takeRetainedValue().localizedDescription
                ?? "The generated JWT signature was invalid."
        )

        let claimsData = try XCTUnwrap(base64URLDecoded(segments[1]))
        let claims = try XCTUnwrap(
            JSONSerialization.jsonObject(with: claimsData) as? [String: Any]
        )
        XCTAssertEqual(claims["iss"] as? String, metadata.clientEmail)
        XCTAssertEqual(claims["scope"] as? String, SearchConsoleAPIClient.readOnlyScope)
        XCTAssertEqual(claims["aud"] as? String, metadata.tokenURI.absoluteString)
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
        type: String = "service_account",
        projectID: String = "dockmagic-tests",
        privateKeyID: String = "key-123",
        clientEmail: String = "dockmagic@dockmagic-tests.iam.gserviceaccount.com",
        privateKey: String =
            "-----BEGIN PRIVATE KEY-----\nZmFrZQ==\n-----END PRIVATE KEY-----"
    ) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "type": type,
            "project_id": projectID,
            "private_key_id": privateKeyID,
            "private_key": privateKey,
            "client_email": clientEmail,
            "token_uri": "https://oauth2.googleapis.com/token"
        ])
    }

    private func googleStylePKCS8Key() throws -> (pem: String, publicKey: SecKey) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2_048
        ]
        var creationError: Unmanaged<CFError>?
        let privateKey = try XCTUnwrap(
            SecKeyCreateRandomKey(attributes as CFDictionary, &creationError),
            creationError?.takeRetainedValue().localizedDescription
                ?? "Could not generate an RSA test key."
        )
        let publicKey = try XCTUnwrap(SecKeyCopyPublicKey(privateKey))

        var exportError: Unmanaged<CFError>?
        let pkcs1 = try XCTUnwrap(
            SecKeyCopyExternalRepresentation(privateKey, &exportError) as Data?,
            exportError?.takeRetainedValue().localizedDescription
                ?? "Could not export the RSA test key."
        )
        let algorithmIdentifier = der(
            tag: 0x30,
            content: joined([
                der(
                    tag: 0x06,
                    content: Data([
                        0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D,
                        0x01, 0x01, 0x01
                    ])
                ),
                der(tag: 0x05, content: Data())
            ])
        )
        let pkcs8 = der(
            tag: 0x30,
            content: joined([
                der(tag: 0x02, content: Data([0x00])),
                algorithmIdentifier,
                der(tag: 0x04, content: pkcs1)
            ])
        )
        let base64 = pkcs8.base64EncodedString()
        let lines = stride(from: 0, to: base64.count, by: 64).map { offset in
            let start = base64.index(base64.startIndex, offsetBy: offset)
            let end = base64.index(
                start,
                offsetBy: min(64, base64.distance(from: start, to: base64.endIndex))
            )
            return String(base64[start..<end])
        }
        let pem = ["-----BEGIN PRIVATE KEY-----"]
            + lines
            + ["-----END PRIVATE KEY-----"]
        return (pem.joined(separator: "\n"), publicKey)
    }

    private func der(tag: UInt8, content: Data) -> Data {
        var encoded = Data([tag])
        encoded.append(derLength(content.count))
        encoded.append(content)
        return encoded
    }

    private func derLength(_ length: Int) -> Data {
        if length < 0x80 { return Data([UInt8(length)]) }
        var remaining = length
        var bytes: [UInt8] = []
        while remaining > 0 {
            bytes.insert(UInt8(remaining & 0xFF), at: 0)
            remaining >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }

    private func joined(_ values: [Data]) -> Data {
        values.reduce(into: Data()) { $0.append($1) }
    }

    private func base64URLDecoded(_ value: Substring) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))
        return Data(base64Encoded: base64)
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
