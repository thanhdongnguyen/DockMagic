import XCTest
@testable import DockMagic

private actor AugmentProbeClient: AugmentAnalyticsProviding {
    var fails = false
    private(set) var reads = 0
    private(set) var resourceReads = 0
    func fail() { fails = true }
    func overview(token: String, range: AugmentDateRange) async throws -> AugmentUsageSnapshot {
        reads += 1
        try? await Task.sleep(for: .milliseconds(token == "slow" ? 160 : 10))
        if fails || token == "invalid" { throw AugmentAPIError.authentication }
        return AugmentUsageSnapshot(range: range, days: token == "empty" ? [] : [.init(date: range.end, metrics: .init(input: token == "slow" ? 111 : 222, output: 0))], fetchedAt: Date(), generatedAt: nil)
    }
    func resources(token: String, range: AugmentDateRange) async throws -> AugmentResourceSnapshot {
        resourceReads += 1
        try? await Task.sleep(for: .milliseconds(30))
        if fails { throw AugmentAPIError.network }
        return AugmentResourceSnapshot(range: range, resources: [], fetchedAt: Date())
    }
}

private final class AugmentTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date()
    func read() -> Date { lock.withLock { date } }
    func advance(_ interval: TimeInterval) { lock.withLock { date = date.addingTimeInterval(interval) } }
}

@MainActor
final class AugmentStoreTests: XCTestCase {
    private func make(_ client: AugmentProbeClient, token: String? = "valid") -> (AugmentUsageStore, InMemoryAugmentCredentialVault, AugmentHistoryCache, UserDefaults) {
        let vault = InMemoryAugmentCredentialVault(token: token)
        let cache = AugmentHistoryCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let defaults = UserDefaults(suiteName: "AugmentTests.\(UUID())")!
        return (AugmentUsageStore(client: client, vault: vault, cache: cache, defaults: defaults, manualCooldown: 0), vault, cache, defaults)
    }
    private func settle(_ store: AugmentUsageStore) async throws {
        for _ in 0..<100 {
            if !store.state.isRefreshing { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Refresh did not finish")
    }
    func testRefreshCoalescesAndCacheSurvivesRestart() async throws {
        let client = AugmentProbeClient(); let (store, vault, cache, defaults) = make(client)
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually(); store.refreshManually()
        try await settle(store)
        let count = await client.reads; XCTAssertEqual(count, 1)
        XCTAssertEqual(store.state.snapshot?.latest?.metrics.input, 222)
        let restored = AugmentUsageStore(client: client, vault: vault, cache: cache, defaults: defaults)
        XCTAssertEqual(restored.state.snapshot, store.state.snapshot)
        XCTAssertEqual(restored.state.observation, .live)
        restored.stop()
    }
    func testFailedReplacementKeepsOldTokenAndSnapshot() async throws {
        let client = AugmentProbeClient(); let (store, vault, cache, _) = make(client)
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually(); try await settle(store)
        let snapshot = store.state.snapshot
        let connected = await store.connect(token: "invalid")
        XCTAssertFalse(connected); XCTAssertEqual(try vault.loadAccessToken(), "valid")
        XCTAssertEqual(store.state.snapshot, snapshot)
    }
    func testDisconnectRejectsLateResponseAndClearsSecret() async throws {
        let client = AugmentProbeClient(); let (store, vault, cache, _) = make(client, token: "slow")
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually(); store.disconnect()
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertNil(store.state.snapshot); XCTAssertNil(try vault.loadAccessToken())
        XCTAssertFalse(store.isConfigured)
    }
    func testTokenRotationRejectsInflightOldOrganization() async throws {
        let client = AugmentProbeClient(); let (store, vault, cache, _) = make(client, token: "slow")
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually()
        let connected = await store.connect(token: "valid"); XCTAssertTrue(connected)
        try await settle(store); try await Task.sleep(for: .milliseconds(220))
        XCTAssertEqual(store.state.snapshot?.latest?.metrics.input, 222)
        XCTAssertEqual(try vault.loadAccessToken(), "valid")
    }
    func testFailureRetainsSnapshotAndStopsAuthPolling() async throws {
        let client = AugmentProbeClient(); let (store, _, cache, _) = make(client)
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually(); try await settle(store)
        let snapshot = store.state.snapshot
        await client.fail(); store.refreshManually(); try await settle(store)
        XCTAssertEqual(store.state.snapshot, snapshot); XCTAssertEqual(store.state.observation, .stale)
        store.refreshManually(); try await settle(store)
        let count = await client.reads; XCTAssertEqual(count, 2)
    }
    func testResourceFailureDoesNotEraseOverview() async throws {
        let client = AugmentProbeClient(); let (store, _, cache, _) = make(client)
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually(); try await settle(store)
        let snapshot = store.state.snapshot!
        await client.fail()
        do { _ = try await store.resourceDetail(range: snapshot.range); XCTFail() } catch {}
        XCTAssertEqual(store.state.snapshot, snapshot)
    }
    func testVisibilityTTLAndManualCooldown() async throws {
        let client = AugmentProbeClient(), clock = AugmentTestClock()
        let cache = AugmentHistoryCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let store = AugmentUsageStore(client: client, vault: InMemoryAugmentCredentialVault(token: "valid"), cache: cache,
            defaults: UserDefaults(suiteName: "AugmentTiming.\(UUID())")!, now: { clock.read() })
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshIfNeeded()
        var count = await client.reads; XCTAssertEqual(count, 0)
        store.setSelected(true); try await settle(store)
        store.refreshIfNeeded(); store.refreshManually(); try await settle(store)
        count = await client.reads; XCTAssertEqual(count, 1)
        clock.advance(31); store.refreshManually(); try await settle(store)
        count = await client.reads; XCTAssertEqual(count, 2)
        clock.advance(AugmentUsageStore.freshnessInterval); store.refreshIfNeeded(); try await settle(store)
        count = await client.reads; XCTAssertEqual(count, 3)
        store.setSelected(false); clock.advance(AugmentUsageStore.freshnessInterval)
        store.refreshIfNeeded(); try await settle(store)
        count = await client.reads; XCTAssertEqual(count, 3)
        store.setSettingsVisible(true); try await settle(store)
        count = await client.reads; XCTAssertEqual(count, 4)
    }
    func testResourceQueriesCoalesceAndEmptyProbeConnects() async throws {
        let client = AugmentProbeClient(); let (store, _, cache, _) = make(client, token: nil)
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        let connected = await store.connect(token: "empty")
        XCTAssertTrue(connected); try await settle(store)
        XCTAssertTrue(store.isConfigured); XCTAssertEqual(store.state.observation, .unavailable)
        let range = try XCTUnwrap(store.state.snapshot?.range)
        async let first = store.resourceDetail(range: range)
        async let second = store.resourceDetail(range: range)
        let (a, b) = try await (first, second)
        XCTAssertEqual(a, b)
        let count = await client.resourceReads; XCTAssertEqual(count, 1)
    }
    func testClearCacheBlocksInflightWriter() async throws {
        let client = AugmentProbeClient(); let (store, _, cache, defaults) = make(client, token: "slow")
        defer { store.stop(); try? FileManager.default.removeItem(at: cache.directory) }
        store.refreshManually(); store.clearHistory()
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertNil(store.state.snapshot)
        XCTAssertNil(cache.load(connectionID: defaults.string(forKey: "DockMagicAugmentConnectionID")!))
    }
}
