import Foundation
import XCTest
@testable import DockMagic

@MainActor
final class GitHubFeatureTests: XCTestCase {
    private let reference = GitHubRepositoryReference(
        urlString: "https://github.com/apple/swift"
    )!

    func testAPIClientDecodesCountsAndSendsRequiredHeaders() async throws {
        GitHubURLProtocolStub.reset(
            status: 200,
            headers: [
                "ETag": "\"repo-v1\"",
                "X-RateLimit-Limit": "5000",
                "X-RateLimit-Remaining": "4999",
                "X-RateLimit-Reset": "1786603600"
            ],
            body: #"{"full_name":"apple/swift","stargazers_count":70123,"forks_count":10567}"#
        )
        let now = Date(timeIntervalSince1970: 1_786_600_000)
        let client = makeClient(now: now)

        let result = try await client.fetchRepository(
            reference,
            accessToken: "github_pat_test",
            etag: "\"old\""
        )

        guard case let .modified(snapshot, etag, rateLimit) = result else {
            return XCTFail("Expected a modified response")
        }
        XCTAssertEqual(snapshot.repository, "apple/swift")
        XCTAssertEqual(snapshot.stars, 70_123)
        XCTAssertEqual(snapshot.forks, 10_567)
        XCTAssertEqual(snapshot.fetchedAt, now)
        XCTAssertEqual(etag, "\"repo-v1\"")
        XCTAssertEqual(rateLimit?.limit, 5_000)
        XCTAssertEqual(rateLimit?.remaining, 4_999)
        XCTAssertEqual(
            rateLimit?.resetAt,
            Date(timeIntervalSince1970: 1_786_603_600)
        )

        let request = try XCTUnwrap(GitHubURLProtocolStub.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/repos/apple/swift")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Accept"),
            "application/vnd.github+json"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-GitHub-Api-Version"),
            GitHubRepositoryAPIClient.apiVersion
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer github_pat_test"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "If-None-Match"),
            "\"old\""
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "User-Agent"),
            "DockMagic/1.0"
        )
    }

    func testAPIClientSupportsUnauthenticatedConditional304() async throws {
        GitHubURLProtocolStub.reset(
            status: 304,
            headers: ["ETag": "\"same\""],
            body: ""
        )
        let result = try await makeClient().fetchRepository(
            reference,
            accessToken: nil,
            etag: "\"same\""
        )
        XCTAssertEqual(
            result,
            .notModified(etag: "\"same\"", rateLimit: nil)
        )
        XCTAssertNil(
            GitHubURLProtocolStub.lastRequest?.value(
                forHTTPHeaderField: "Authorization"
            )
        )
    }

    func testAPIClientMapsAuthenticationNotFoundAndRateLimitErrors() async {
        await assertAPIError(
            status: 401,
            headers: [:],
            expected: .invalidAccessToken
        )
        await assertAPIError(
            status: 404,
            headers: [:],
            expected: .repositoryNotFoundOrPrivate
        )
        await assertAPIError(
            status: 403,
            headers: [
                "X-RateLimit-Limit": "60",
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": "1786603600"
            ],
            expected: .rateLimited(
                resetAt: Date(timeIntervalSince1970: 1_786_603_600)
            )
        )
        await assertAPIError(
            status: 503,
            headers: [:],
            expected: .serverError(status: 503)
        )
        await assertAPIError(
            status: 403,
            headers: ["Retry-After": "120"],
            expected: .rateLimited(
                resetAt: Date(timeIntervalSince1970: 1_786_600_120)
            )
        )
    }

    func testStoreRefreshPersistsHistoryAndUsesETagOnNextRequest() async {
        let api = GitHubTestAPI()
        let cache = InMemoryGitHubRepositoryHistoryCache()
        let store = GitHubRepositoryStore(
            api: api,
            vault: InMemoryGitHubCredentialVault(token: "secret-token"),
            cache: cache,
            pollingInterval: 900,
            now: { Date(timeIntervalSince1970: 1_786_600_100) }
        )
        store.configure(repositoryURL: reference.webURLString)
        api.enqueue(.success(.modified(
            snapshot: snapshot(stars: 100, forks: 20, time: 1_786_600_000),
            etag: "\"v1\"",
            rateLimit: GitHubRateLimit(
                limit: 5_000,
                remaining: 4_999,
                resetAt: nil
            )
        )))

        await store.refresh()

        XCTAssertEqual(store.history.map(\.stars), [100])
        XCTAssertEqual(
            store.lastSuccessfulRefreshAt,
            Date(timeIntervalSince1970: 1_786_600_000)
        )
        XCTAssertEqual(store.rateLimit?.remaining, 4_999)
        XCTAssertNil(store.lastErrorDescription)
        XCTAssertTrue(store.hasAccessToken)
        XCTAssertEqual(api.requests.first?.accessToken, "secret-token")
        XCTAssertEqual(cache.load()?.history, store.history)

        api.enqueue(.success(.notModified(etag: "\"v1\"", rateLimit: nil)))
        await store.refresh()

        XCTAssertEqual(api.requests.last?.etag, "\"v1\"")
        XCTAssertEqual(store.history.count, 2)
        XCTAssertEqual(store.history.last?.stars, 100)
        XCTAssertEqual(
            store.history.last?.fetchedAt,
            Date(timeIntervalSince1970: 1_786_600_100)
        )
    }

    func testStoreRestoresOnlyMatchingRepositoryHistory() {
        let cached = GitHubRepositoryCacheEntry(
            repository: "apple/swift",
            history: [snapshot(stars: 90, forks: 19, time: 1_786_600_000)],
            etag: "\"cached\""
        )
        let store = GitHubRepositoryStore(
            api: GitHubTestAPI(),
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(entry: cached),
            now: { Date(timeIntervalSince1970: 1_786_600_100) }
        )

        store.configure(repositoryURL: reference.webURLString)
        XCTAssertEqual(store.history.map(\.stars), [90])

        store.configure(
            repositoryURL: "https://github.com/octocat/Hello-World"
        )
        XCTAssertTrue(store.history.isEmpty)
    }

    func testStoreRestoresAtMostSevenDaysAnd672Samples() {
        let currentTime = Date(timeIntervalSince1970: 1_786_700_000)
        let recentHistory = (0..<700).map { index in
            snapshot(
                stars: index,
                forks: index,
                time: currentTime.timeIntervalSince1970 - Double(699 - index)
            )
        }
        let recentStore = GitHubRepositoryStore(
            api: GitHubTestAPI(),
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(
                entry: GitHubRepositoryCacheEntry(
                    repository: reference.fullName,
                    history: recentHistory,
                    etag: "\"recent\""
                )
            ),
            now: { currentTime }
        )

        recentStore.configure(repositoryURL: reference.webURLString)

        XCTAssertEqual(
            recentStore.history.count,
            GitHubRepositoryStore.retainedSampleCount
        )
        XCTAssertEqual(recentStore.history.first?.stars, 28)
        XCTAssertEqual(recentStore.history.last?.stars, 699)

        let expiredStore = GitHubRepositoryStore(
            api: GitHubTestAPI(),
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(
                entry: GitHubRepositoryCacheEntry(
                    repository: reference.fullName,
                    history: [snapshot(
                        stars: 1,
                        forks: 1,
                        time: currentTime.timeIntervalSince1970 - 604_801
                    )],
                    etag: "\"expired\""
                )
            ),
            now: { currentTime }
        )

        expiredStore.configure(repositoryURL: reference.webURLString)

        XCTAssertTrue(expiredStore.history.isEmpty)
        XCTAssertNil(expiredStore.lastSuccessfulRefreshAt)
    }

    func testStoreKeepsLastGoodDataWhenRefreshFails() async {
        let api = GitHubTestAPI()
        let store = GitHubRepositoryStore(
            api: api,
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(),
            now: { Date(timeIntervalSince1970: 1_786_600_100) }
        )
        store.configure(repositoryURL: reference.webURLString)
        api.enqueue(.success(.modified(
            snapshot: snapshot(stars: 100, forks: 20, time: 1_786_600_000),
            etag: nil,
            rateLimit: nil
        )))
        await store.refresh()

        api.enqueue(.failure(
            GitHubRepositoryAPIError.serverError(status: 503)
        ))
        await store.refresh()

        XCTAssertEqual(store.history.map(\.stars), [100])
        XCTAssertTrue(store.lastErrorDescription?.contains("503") == true)
    }

    func testStoreCoalescesConcurrentRefreshes() async {
        let api = GitHubTestAPI(delayNanoseconds: 50_000_000)
        api.enqueue(.success(.modified(
            snapshot: snapshot(stars: 101, forks: 21, time: 1_786_600_000),
            etag: nil,
            rateLimit: nil
        )))
        let store = GitHubRepositoryStore(
            api: api,
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(),
            now: { Date(timeIntervalSince1970: 1_786_600_100) }
        )
        store.configure(repositoryURL: reference.webURLString)

        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await (first, second)

        XCTAssertEqual(api.requests.count, 1)
        XCTAssertEqual(store.history.count, 1)
    }

    func testPollingStartsImmediatelyRepeatsAndStops() async throws {
        let api = GitHubTestAPI()
        for count in 1...4 {
            api.enqueue(.success(.modified(
                snapshot: snapshot(
                    stars: count,
                    forks: count,
                    time: 1_786_600_000 + Double(count)
                ),
                etag: nil,
                rateLimit: nil
            )))
        }
        let store = GitHubRepositoryStore(
            api: api,
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(),
            pollingInterval: 0.03,
            now: { Date(timeIntervalSince1970: 1_786_600_100) }
        )
        store.configure(repositoryURL: reference.webURLString)
        store.start()

        try await waitUntil { api.requests.count >= 2 }
        XCTAssertTrue(store.isMonitoring)
        XCTAssertEqual(store.history.count, 2)

        store.stop()
        let stoppedCount = api.requests.count
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(store.isMonitoring)
        XCTAssertEqual(api.requests.count, stoppedCount)
    }

    func testPollingHonorsRateLimitResetBeforeRetrying() async throws {
        let currentTime = Date(timeIntervalSince1970: 1_786_700_000)
        let resetAt = currentTime.addingTimeInterval(120)
        let api = GitHubTestAPI()
        api.enqueue(.failure(
            GitHubRepositoryAPIError.rateLimited(resetAt: resetAt)
        ))
        let store = GitHubRepositoryStore(
            api: api,
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(),
            pollingInterval: 0.03,
            now: { currentTime }
        )
        store.configure(repositoryURL: reference.webURLString)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.nextRefreshAt != nil }

        XCTAssertEqual(store.nextRefreshAt, resetAt)
        XCTAssertTrue(
            store.lastErrorDescription?.localizedCaseInsensitiveContains(
                "rate limit"
            ) == true
        )
    }

    func testTokenLifecycleUsesVault() throws {
        let vault = InMemoryGitHubCredentialVault()
        let store = GitHubRepositoryStore(
            api: GitHubTestAPI(),
            vault: vault,
            cache: InMemoryGitHubRepositoryHistoryCache()
        )
        store.configure(repositoryURL: reference.webURLString)

        try store.saveAccessToken("  github_pat_secret  ")
        XCTAssertTrue(store.hasAccessToken)
        XCTAssertEqual(try vault.loadAccessToken(), "github_pat_secret")

        try store.removeAccessToken()
        XCTAssertFalse(store.hasAccessToken)
        XCTAssertNil(try vault.loadAccessToken())
    }

    func testKeychainVaultRoundTripsUpdatesAndDeletesToken() throws {
        let service = "com.hypevibe.DockMagic.tests.\(UUID().uuidString)"
        let vault = KeychainGitHubCredentialVault(
            service: service,
            account: "github.access-token"
        )
        try? vault.deleteAccessToken()
        defer { try? vault.deleteAccessToken() }

        XCTAssertNil(try vault.loadAccessToken())
        try vault.storeAccessToken("  github_pat_first  ")
        XCTAssertEqual(try vault.loadAccessToken(), "github_pat_first")

        try vault.storeAccessToken("github_pat_updated")
        XCTAssertEqual(try vault.loadAccessToken(), "github_pat_updated")

        try vault.deleteAccessToken()
        XCTAssertNil(try vault.loadAccessToken())
        XCTAssertThrowsError(try vault.storeAccessToken("contains space")) {
            XCTAssertEqual(
                $0 as? GitHubCredentialVaultError,
                .tokenContainsWhitespace
            )
        }
    }

    func testInvalidRepositoryDoesNotStartPolling() {
        let store = GitHubRepositoryStore(
            api: GitHubTestAPI(),
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache()
        )
        store.configure(repositoryURL: "https://example.com/owner/repo")
        store.start()

        XCTAssertFalse(store.isMonitoring)
        XCTAssertEqual(
            store.lastErrorDescription,
            "Enter a valid GitHub repository URL."
        )
    }

    func testAppModelRunsGitHubWithBackgroundStreakCollection() async {
        let suite = "DockMagicTests.GitHub.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.githubRepositoryURL = reference.webURLString
        preferences.activeFeature = .github
        let api = GitHubTestAPI()
        api.enqueue(.success(.modified(
            snapshot: snapshot(stars: 123, forks: 45, time: 1_786_600_000),
            etag: nil,
            rateLimit: nil
        )))
        let githubStore = GitHubRepositoryStore(
            api: api,
            vault: InMemoryGitHubCredentialVault(),
            cache: InMemoryGitHubRepositoryHistoryCache(),
            pollingInterval: 900,
            now: { Date(timeIntervalSince1970: 1_786_600_100) }
        )
        let appModel = DockAppModel(
            preferences: preferences,
            githubStore: githubStore
        )

        appModel.start()
        try? await waitUntil { !githubStore.history.isEmpty }

        XCTAssertTrue(githubStore.isMonitoring)
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
        guard case let .github(history, _, error) = appModel.dockPresentation else {
            return XCTFail("Expected GitHub Dock presentation")
        }
        XCTAssertEqual(history.last?.stars, 123)
        XCTAssertNil(error)

        appModel.stop()
        XCTAssertFalse(githubStore.isMonitoring)
    }

    private func makeClient(
        now: Date = Date(timeIntervalSince1970: 1_786_600_000)
    ) -> GitHubRepositoryAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GitHubURLProtocolStub.self]
        return GitHubRepositoryAPIClient(
            session: URLSession(configuration: configuration),
            now: { now }
        )
    }

    private func assertAPIError(
        status: Int,
        headers: [String: String],
        expected: GitHubRepositoryAPIError
    ) async {
        GitHubURLProtocolStub.reset(
            status: status,
            headers: headers,
            body: #"{"message":"test failure"}"#
        )
        do {
            _ = try await makeClient().fetchRepository(
                reference,
                accessToken: nil,
                etag: nil
            )
            XCTFail("Expected request to fail with \(expected)")
        } catch let error as GitHubRepositoryAPIError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func snapshot(
        stars: Int,
        forks: Int,
        time: TimeInterval
    ) -> GitHubRepositorySnapshot {
        GitHubRepositorySnapshot(
            repository: "apple/swift",
            stars: stars,
            forks: forks,
            fetchedAt: Date(timeIntervalSince1970: time)
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private final class GitHubTestAPI:
    GitHubRepositoryAPIProviding,
    @unchecked Sendable
{
    struct Request: Equatable {
        let reference: GitHubRepositoryReference
        let accessToken: String?
        let etag: String?
    }

    private let lock = NSLock()
    private var results: [Result<GitHubRepositoryFetchResult, Error>] = []
    private var capturedRequests: [Request] = []
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 0) {
        self.delayNanoseconds = delayNanoseconds
    }

    var requests: [Request] {
        lock.withLock { capturedRequests }
    }

    func enqueue(_ result: Result<GitHubRepositoryFetchResult, Error>) {
        lock.withLock { results.append(result) }
    }

    func fetchRepository(
        _ reference: GitHubRepositoryReference,
        accessToken: String?,
        etag: String?
    ) async throws -> GitHubRepositoryFetchResult {
        lock.withLock {
            capturedRequests.append(
                Request(
                    reference: reference,
                    accessToken: accessToken,
                    etag: etag
                )
            )
        }
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        let result: Result<GitHubRepositoryFetchResult, Error> = lock.withLock {
            results.isEmpty
                ? .failure(GitHubRepositoryAPIError.invalidResponse)
                : results.removeFirst()
        }
        return try result.get()
    }
}

private final class GitHubURLProtocolStub: URLProtocol, @unchecked Sendable {
    private struct Stub {
        let status: Int
        let headers: [String: String]
        let body: Data
    }

    private static let lock = NSLock()
    private static var stub = Stub(
        status: 500,
        headers: [:],
        body: Data()
    )
    private static var capturedRequest: URLRequest?

    static var lastRequest: URLRequest? {
        lock.withLock { capturedRequest }
    }

    static func reset(
        status: Int,
        headers: [String: String],
        body: String
    ) {
        lock.withLock {
            stub = Stub(
                status: status,
                headers: headers,
                body: Data(body.utf8)
            )
            capturedRequest = nil
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        let current = Self.lock.withLock { () -> Stub in
            Self.capturedRequest = request
            return Self.stub
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: current.status,
            httpVersion: "HTTP/1.1",
            headerFields: current.headers
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        if !current.body.isEmpty {
            client?.urlProtocol(self, didLoad: current.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
