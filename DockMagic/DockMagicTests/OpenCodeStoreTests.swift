import XCTest
@testable import DockMagic

private actor OpenCodeProbeReader: OpenCodeHistoryReading {
    private(set) var reads = 0
    var fails = false
    func setFailure() { fails = true }
    func read(database: URL, timezone: TimeZone, now: Date) async throws -> OpenCodeUsageSnapshot {
        reads += 1
        try? await Task.sleep(for: .milliseconds(database.lastPathComponent == "slow.db" ? 180 : 40))
        if fails { throw OpenCodeReadError.unavailable }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timezone
        return OpenCodeUsageSnapshot(sourceID: OpenCodeSourceDiscovery.identifier(for: database), timezoneID: timezone.identifier,
            readAt: now, schema: "fixture", days: [OpenCodeDailyDetail(startDate: calendar.startOfDay(for: now),
                tokens: .zero, cost: OpenCodeCost(), hourly: [], models: [], sessionCount: 0, messageCount: 0, isPartial: false)],
            recordKeys: [], skippedRecords: 0, lifetimeTokens: 0, cost: OpenCodeCost())
    }
}

@MainActor
final class OpenCodeStoreTests: XCTestCase {
    private func configured(_ reader: OpenCodeProbeReader, path: String = "/fixture/fast.db") -> (OpenCodeUsageStore, URL, UserDefaults) {
        let defaults = UserDefaults(suiteName: "OpenCodeTests.\(UUID())")!
        defaults.set(true, forKey: "DockMagicOpenCodeUsed")
        defaults.set(path, forKey: "DockMagicOpenCodeDatabase")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCodeCacheTests-\(UUID())")
        return (OpenCodeUsageStore(reader: reader, cache: OpenCodeHistoryCache(directory: directory), defaults: defaults, minimumRefreshInterval: 0), directory, defaults)
    }
    private func settle(_ store: OpenCodeUsageStore) async throws {
        for _ in 0..<100 {
            if !store.state.isRefreshing { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Refresh did not settle")
    }
    func testConcurrentRefreshesCoalesceAndDoNotAddTotals() async throws {
        let reader = OpenCodeProbeReader()
        let (store, directory, _) = configured(reader)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        store.refresh(); store.refresh(); store.refresh()
        try await settle(store)
        let count = await reader.reads
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.state.snapshot?.lifetimeTokens, 0)
        store.refresh(); try await settle(store)
        XCTAssertEqual(store.state.snapshot?.lifetimeTokens, 0)
    }
    func testChangingSourceRejectsLateOldResult() async throws {
        let reader = OpenCodeProbeReader()
        let (store, directory, _) = configured(reader, path: "/fixture/slow.db")
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        store.refresh()
        try await Task.sleep(for: .milliseconds(15))
        let newSource = URL(fileURLWithPath: "/fixture/fast.db")
        store.chooseDatabase(newSource)
        try await settle(store)
        try await Task.sleep(for: .milliseconds(210))
        XCTAssertEqual(store.state.snapshot?.sourceID, OpenCodeSourceDiscovery.identifier(for: newSource))
        XCTAssertEqual(store.state.observation, .current)
    }
    func testFailedRefreshRetainsLastSnapshotAsStale() async throws {
        let reader = OpenCodeProbeReader()
        let (store, directory, _) = configured(reader)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        store.refresh(); try await settle(store)
        let old = store.state.snapshot
        await reader.setFailure()
        store.refresh(); try await settle(store)
        XCTAssertEqual(store.state.snapshot, old)
        XCTAssertEqual(store.state.observation, .stale)
        XCTAssertNotNil(store.state.message)
    }
    func testBackgroundOffKeepsManualRefreshAndLastSnapshot() async throws {
        let reader = OpenCodeProbeReader()
        let (store, directory, _) = configured(reader)
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        store.setSelected(true); try await settle(store)
        store.setBackgroundEnabled(false)
        XCTAssertFalse(store.backgroundEnabled)
        XCTAssertNotNil(store.state.snapshot)
        store.refresh(); try await settle(store)
        XCTAssertEqual(store.state.observation, .current)
    }
    func testClearingCacheWaitsForInflightWriter() async throws {
        let reader = OpenCodeProbeReader()
        let (store, directory, _) = configured(reader, path: "/fixture/slow.db")
        defer { store.stop(); try? FileManager.default.removeItem(at: directory) }
        store.refresh()
        store.clearCache()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(store.state.snapshot)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        XCTAssertTrue(contents.isEmpty)
        store.refresh(); try await settle(store)
        XCTAssertNotNil(store.state.snapshot)
    }
    func testRestoredCacheStartsStaleAndThenReconciles() async throws {
        let reader = OpenCodeProbeReader()
        let (first, directory, defaults) = configured(reader, path: "/fixture/slow.db")
        defer { first.stop(); try? FileManager.default.removeItem(at: directory) }
        first.refresh(); try await settle(first)
        try await Task.sleep(for: .milliseconds(30)) // allow asynchronous cache write
        let restored = OpenCodeUsageStore(reader: reader, cache: OpenCodeHistoryCache(directory: directory), defaults: defaults, minimumRefreshInterval: 0)
        defer { restored.stop() }
        restored.refresh()
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(restored.state.observation, .stale)
        XCTAssertNotNil(restored.state.snapshot)
        try await settle(restored)
        XCTAssertEqual(restored.state.observation, .current)
    }
}
