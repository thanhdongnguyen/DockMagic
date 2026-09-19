import Foundation
import XCTest
@testable import DockMagic

/// Synthetic integration tests: none launch Grok, read credentials or claim
/// that a released CLI/account has passed the runtime capability gate.
final class GrokBuildIntegrationTests: XCTestCase {
    private let fixture = GrokIntegrationFixture()

    func testCollectorRepeatedRefreshSkipsCLIAndDoesNotDoubleCount() async throws {
        let cli = GrokIntegrationCLI()
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        let collector = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery)
        let first = try await collect(collector)
        let second = try await collect(collector, cache: first.cache)
        XCTAssertEqual(second.snapshot.days.last?.tokens, 120)
        XCTAssertEqual(second.readableRootCount, 1)
        let calls = await cli.calls
        XCTAssertEqual(calls.usage, 1)
    }

    func testFutureTurnIsQuarantinedThenRecoveredWithoutAFileChange() async throws {
        let cli = GrokIntegrationCLI()
        let future = fixture.now.addingTimeInterval(60)
        await cli.setUsageDate(future)
        let collector = GrokBuildLocalUsageProvider(cli: cli,
            discovery: GrokIntegrationDiscovery(sources: [fixture.source()]))
        let premature = try await collect(collector)
        XCTAssertNil(premature.snapshot.days.last?.tokens)
        XCTAssertEqual(premature.snapshot.coverage.quarantinedSessions, 1)
        XCTAssertEqual(premature.readableRootCount, 0)
        XCTAssertNil(premature.cache.activity?.snapshot(at: fixture.now, calendar: fixture.calendar).currentDays)

        // The fingerprint stays identical. Backoff expiry must trigger a new
        // eligibility check rather than leave activity permanently missing.
        let later = future.addingTimeInterval(1)
        let recovered = try await collector.collect(configuration: fixture.configuration,
            cache: premature.cache, now: later, calendar: fixture.calendar)
        XCTAssertEqual(recovered.snapshot.days.last?.tokens, 120)
        XCTAssertEqual(recovered.snapshot.coverage.quarantinedSessions, 0)
        XCTAssertEqual(recovered.cache.activity?.snapshot(at: later, calendar: fixture.calendar).currentDays, 1)
        let repeated = try await collector.collect(configuration: fixture.configuration,
            cache: recovered.cache, now: later, calendar: fixture.calendar)
        XCTAssertEqual(repeated.snapshot.days, recovered.snapshot.days)
        let calls = await cli.calls
        XCTAssertEqual(calls.usage, 2)
    }

    func testFutureRevisionKeepsLastGoodTokensUntilTimestampIsEligible() async throws {
        let cli = GrokIntegrationCLI()
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        let collector = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery)
        let first = try await collect(collector)
        let future = fixture.now.addingTimeInterval(60)
        await cli.setUsageDate(future)
        await cli.setInput(200)
        discovery.replace([fixture.source(fingerprint: "future-revision")])
        let held = try await collect(collector, cache: first.cache)
        XCTAssertEqual(held.snapshot.days.last?.tokens, 120)
        XCTAssertEqual(held.snapshot.coverage.quarantinedSessions, 1)
        XCTAssertEqual(held.cache.activity?.witnesses.values.first, fixture.now)
        let recovered = try await collector.collect(configuration: fixture.configuration,
            cache: held.cache, now: future.addingTimeInterval(1), calendar: fixture.calendar)
        XCTAssertEqual(recovered.snapshot.days.last?.tokens, 220)
        XCTAssertEqual(recovered.snapshot.topModels.first?.tokens, 220)
        XCTAssertEqual(recovered.cache.activity?.witnesses.count, 1)
        XCTAssertEqual(recovered.cache.activity?.witnesses.values.first, future)
    }

    func testClockRollbackDoesNotExposeFutureCachedTokensAsCurrentActivity() {
        let cache = fixture.cache()
        let earlier = fixture.now.addingTimeInterval(-30)
        let snapshot = cache.ledger.snapshot(now: earlier, calendar: fixture.calendar)
        let activity = GrokBuildActivityLedger.importing(cache.ledger, at: fixture.now, calendar: fixture.calendar)
        XCTAssertNil(snapshot.days.last?.tokens)
        XCTAssertTrue(snapshot.topModels.isEmpty)
        XCTAssertNil(activity.snapshot(at: earlier, calendar: fixture.calendar).currentDays)
        XCTAssertEqual(cache.ledger.snapshot(now: fixture.now, calendar: fixture.calendar).days.last?.tokens, 120)
    }

    func testEarlierExperimentalPrematureCacheRevalidatesDespiteUnchangedFingerprint() async throws {
        var old = fixture.cache()
        let key = old.ledger.sessionKey(fixture.id)
        old.fingerprints[key] = fixture.source().fingerprint
        var activity = GrokBuildActivityLedger(namespace: old.ledger.namespace)
        activity.beginObservation(at: fixture.now.addingTimeInterval(-60), calendar: fixture.calendar)
        activity.finishObservation(at: fixture.now.addingTimeInterval(-60), calendar: fixture.calendar)
        old.activity = activity
        // Older experimental builds accepted a turn up to five minutes ahead
        // of observation but did not record its activity witness.
        var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        var ledger = try XCTUnwrap(encoded["ledger"] as? [String: Any])
        var sessions = try XCTUnwrap(ledger["sessions"] as? [String: Any])
        var record = try XCTUnwrap(sessions[key] as? [String: Any])
        record["observedAt"] = fixture.now.addingTimeInterval(-60).timeIntervalSinceReferenceDate
        sessions[key] = record; ledger["sessions"] = sessions; encoded["ledger"] = ledger
        old = try JSONDecoder().decode(GrokBuildHistoryCache.self, from: JSONSerialization.data(withJSONObject: encoded))
        XCTAssertNil(old.ledger.snapshot(now: fixture.now, calendar: fixture.calendar).days.last?.tokens,
            "Passing wall-clock time cannot retroactively validate a premature cache record")
        XCTAssertNil(GrokBuildActivityLedger.importing(old.ledger, at: fixture.now, calendar: fixture.calendar)
            .snapshot(at: fixture.now, calendar: fixture.calendar).currentDays)
        let cli = GrokIntegrationCLI()
        let collector = GrokBuildLocalUsageProvider(cli: cli,
            discovery: GrokIntegrationDiscovery(sources: [fixture.source()]))
        await cli.setUsageError(.commandFailed)
        let unavailable = try await collect(collector, cache: old)
        XCTAssertNil(unavailable.snapshot.days.last?.tokens)
        XCTAssertEqual(unavailable.snapshot.coverage.unavailableSources, 1)
        XCTAssertNil(unavailable.cache.activity?.snapshot(at: fixture.now, calendar: fixture.calendar).currentDays)
        await cli.setUsageError(nil)
        let retriedAt = fixture.now.addingTimeInterval(16)
        let repaired = try await collector.collect(configuration: fixture.configuration, cache: unavailable.cache,
            now: retriedAt, calendar: fixture.calendar)
        XCTAssertEqual(repaired.snapshot.days.last?.tokens, 120)
        XCTAssertEqual(repaired.cache.activity?.snapshot(at: fixture.now, calendar: fixture.calendar).currentDays, 1)
        XCTAssertEqual(repaired.cache.ledger.sessions[key]?.observedAt, retriedAt)
        _ = try await collector.collect(configuration: fixture.configuration, cache: repaired.cache,
            now: retriedAt, calendar: fixture.calendar)
        let calls = await cli.calls
        XCTAssertEqual(calls.usage, 2, "One failure plus one successful revalidation, then the unchanged fast path")
    }

    func testCollectorReplacesRevisionAndKeepsQuarantineVisibleDuringBackoff() async throws {
        let cli = GrokIntegrationCLI()
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        let collector = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery)
        let first = try await collect(collector)
        await cli.setInput(200)
        discovery.replace([fixture.source(fingerprint: "revision-2")])
        let revised = try await collect(collector, cache: first.cache)
        XCTAssertEqual(revised.snapshot.days.last?.tokens, 220)
        await cli.setInput(50)
        discovery.replace([fixture.source(fingerprint: "revision-3")])
        let shrink = try await collect(collector, cache: revised.cache)
        XCTAssertEqual(shrink.snapshot.days.last?.tokens, 220)
        XCTAssertEqual(shrink.snapshot.coverage.quarantinedSessions, 1)
        XCTAssertEqual(shrink.readableRootCount, 0)
        let waiting = try await collect(collector, cache: shrink.cache)
        XCTAssertEqual(waiting.snapshot.coverage.quarantinedSessions, 1)
        XCTAssertEqual(waiting.snapshot.coverage.unavailableSources, 0)
        let calls = await cli.calls
        XCTAssertEqual(calls.usage, 3)
    }

    func testCollectorRejectsLineageOrFingerprintChangedDuringFinalScan() async throws {
        let cli = GrokIntegrationCLI()
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        discovery.replaceOnSecondScan([fixture.source(fingerprint: "changed")])
        let result = try await collect(.init(cli: cli, discovery: discovery))
        XCTAssertTrue(result.cache.ledger.sessions.isEmpty)
        XCTAssertEqual(result.snapshot.coverage.unavailableSources, 1)
        XCTAssertEqual(result.readableRootCount, 0)
    }

    func testCollectorExcludesForksSubagentsAndOrphansWithoutInvokingUsage() async throws {
        let cli = GrokIntegrationCLI()
        let child = fixture.source(id: UUID(), kind: "subagent", parent: fixture.id.uuidString)
        let fork = fixture.source(id: UUID(), kind: "fork", parent: fixture.id.uuidString)
        let orphan = fixture.source(id: UUID(), parent: UUID().uuidString)
        let result = try await collect(.init(cli: cli,
            discovery: GrokIntegrationDiscovery(sources: [fixture.source(), child, fork, orphan])))
        XCTAssertEqual(result.snapshot.days.last?.tokens, 120)
        XCTAssertEqual(result.snapshot.coverage.excludedSessions, 3)
        let calls = await cli.calls
        XCTAssertEqual(calls.usage, 1)
    }

    func testCollectorKeepsLastGoodDataWhenSourceDisappears() async throws {
        let cli = GrokIntegrationCLI()
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        let collector = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery)
        let first = try await collect(collector)
        discovery.replace([])
        let deleted = try await collect(collector, cache: first.cache)
        XCTAssertEqual(deleted.snapshot.days.last?.tokens, 120)
        XCTAssertEqual(deleted.snapshot.coverage.unavailableSources, 1)
        XCTAssertEqual(deleted.readableRootCount, 0)
        XCTAssertTrue(deleted.cache.fingerprints.isEmpty)
    }

    func testCollectorBoundedScansMakeProgressOnLaterSources() async throws {
        let cli = GrokIntegrationCLI()
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source(), fixture.source(id: UUID())])
        let collector = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery, maximumCommandsPerScan: 1)
        let first = try await collect(collector)
        XCTAssertTrue(first.snapshot.coverage.scanWasLimited)
        XCTAssertEqual(first.snapshot.days.last?.tokens, 120)
        let second = try await collect(collector, cache: first.cache)
        XCTAssertFalse(second.snapshot.coverage.scanWasLimited)
        XCTAssertEqual(second.snapshot.days.last?.tokens, 240)
        let calls = await cli.calls
        XCTAssertEqual(calls.usage, 2)
    }

    func testCollectorChangedFingerprintBypassesFailedSourceBackoff() async throws {
        let cli = GrokIntegrationCLI()
        await cli.setUsageError(.invalidResponse)
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        let collector = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery)
        let failed = try await collect(collector)
        XCTAssertEqual(failed.snapshot.coverage.unavailableSources, 1)
        let waiting = try await collect(collector, cache: failed.cache)
        var calls = await cli.calls
        XCTAssertEqual(calls.usage, 1)
        await cli.setUsageError(nil)
        discovery.replace([fixture.source(fingerprint: "fixed")])
        let fixed = try await collect(collector, cache: waiting.cache)
        XCTAssertEqual(fixed.snapshot.days.last?.tokens, 120)
        XCTAssertTrue(fixed.cache.retries.isEmpty)
        calls = await cli.calls
        XCTAssertEqual(calls.usage, 2)
    }

    func testCollectorNeverUsesAnotherHomeCache() async throws {
        do {
            _ = try await collect(.init(cli: GrokIntegrationCLI(), discovery: GrokIntegrationDiscovery(sources: [])),
                                  cache: .init(home: URL(fileURLWithPath: "/different-home")))
            XCTFail("Expected home isolation")
        } catch { XCTAssertEqual(error as? GrokBuildError, .invalidHome) }
    }

    func testCacheRoundTripSeparatesHomesAndPersistsNoRawIdentity() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        let cache = fixture.cache()
        try repository.save(cache)
        XCTAssertEqual(try repository.load(home: fixture.configuration.home), cache)
        XCTAssertNil(try repository.load(home: URL(fileURLWithPath: "/different-home")))
        let url = directory.appendingPathComponent(cache.ledger.namespace + ".json")
        let encoded = try String(contentsOf: url)
        XCTAssertFalse(encoded.contains(fixture.id.uuidString.lowercased()))
        XCTAssertFalse(encoded.contains(fixture.configuration.home.path))
        XCTAssertFalse(encoded.contains("subscriptionTier"))
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }

    func testCacheRejectsCorruptUnsupportedAndInconsistentRecords() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        let cache = fixture.cache()
        let url = directory.appendingPathComponent(cache.ledger.namespace + ".json")
        try Data("broken".utf8).write(to: url)
        XCTAssertThrowsError(try repository.load(home: fixture.configuration.home))
        var unsupported = cache
        unsupported.schemaVersion = 900
        try JSONEncoder().encode(unsupported).write(to: url)
        XCTAssertThrowsError(try repository.load(home: fixture.configuration.home))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(cache)) as? [String: Any])
        var ledger = try XCTUnwrap(object["ledger"] as? [String: Any])
        var sessions = try XCTUnwrap(ledger["sessions"] as? [String: Any])
        let key = cache.ledger.sessionKey(fixture.id)
        var session = try XCTUnwrap(sessions[key] as? [String: Any])
        session["total"] = ["input": 1, "output": 1, "total": 2]
        sessions[key] = session; ledger["sessions"] = sessions; object["ledger"] = ledger
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        XCTAssertThrowsError(try repository.load(home: fixture.configuration.home))
    }

    func testCacheRejectsSymlinkWithoutOverwritingItsDestination() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = fixture.cache()
        let protected = directory.appendingPathComponent("unrelated")
        try Data("preserve".utf8).write(to: protected)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent(cache.ledger.namespace + ".json"), withDestinationURL: protected)
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        XCTAssertThrowsError(try repository.load(home: fixture.configuration.home))
        XCTAssertThrowsError(try repository.save(cache))
        XCTAssertEqual(try String(contentsOf: protected), "preserve")
    }

    @MainActor
    func testDisabledStoreDoesNoIO() async {
        let cli = GrokIntegrationCLI()
        let collector = GrokIntegrationCollector()
        let repository = GrokIntegrationCache()
        let monitor = GrokIntegrationMonitor()
        let store = makeStore(cli: cli, collector: collector, repository: repository, monitor: monitor)
        await store.configure(fixture.configuration, enabled: false, monitoring: true)
        await store.refresh(forceQuota: true)
        let calls = await cli.calls
        let collections = await collector.calls
        XCTAssertEqual(calls.version + calls.billing, 0)
        XCTAssertEqual(collections, 0)
        XCTAssertEqual(repository.loads, 0)
        XCTAssertEqual(monitor.starts, 0)
    }

    @MainActor
    func testSignedOutQuotaDoesNotBlockLocalHistory() async {
        let cli = GrokIntegrationCLI()
        await cli.setBillingError(.authenticationRequired)
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertEqual(store.connection, .signedOut)
        XCTAssertEqual(store.quota.status, .notConfigured)
        XCTAssertEqual(store.local.status, .live)
        XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
    }

    @MainActor
    func testZeroOrMissingLocalDataRemainsUnknown() async {
        let collector = GrokIntegrationCollector()
        await collector.setInput(0)
        let store = makeStore(collector: collector)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertEqual(store.local.status, .unavailable)
        XCTAssertTrue(store.local.value?.days.allSatisfy { $0.tokens == nil } == true)
    }

    @MainActor
    func testQuotaCacheExpiresAtFiveMinutesAndStalesAtFifteen() async {
        let cli = GrokIntegrationCLI()
        let clock = GrokIntegrationClock(fixture.now)
        let store = makeStore(cli: cli, clock: clock)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        clock.date = fixture.now.addingTimeInterval(299)
        await store.refreshQuota()
        var calls = await cli.calls
        XCTAssertEqual(calls.billing, 1)
        clock.date = fixture.now.addingTimeInterval(300)
        await store.refreshQuota()
        calls = await cli.calls
        XCTAssertEqual(calls.billing, 2)
        clock.date = fixture.now.addingTimeInterval(1_199)
        store.updateFreshness()
        XCTAssertEqual(store.quota.status, .live)
        clock.date = fixture.now.addingTimeInterval(1_200)
        store.updateFreshness()
        XCTAssertEqual(store.quota.status, .stale)
        XCTAssertNotNil(store.quota.value)
    }

    @MainActor
    func testNetworkFailureKeepsLastQuotaAndNeverBecomesSignedOut() async {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let previous = store.quota.value
        await cli.setBillingError(.timedOut)
        await store.refresh(forceQuota: true)
        XCTAssertEqual(store.connection, .failed(.timedOut))
        XCTAssertEqual(store.quota.status, .stale)
        XCTAssertEqual(store.quota.value, previous)
        XCTAssertEqual(store.local.status, .live)
    }

    @MainActor
    func testLoginExitZeroStillRequiresSuccessfulQuotaProbe() async throws {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let attempt = try XCTUnwrap(store.beginSignIn())
        XCTAssertEqual(attempt.configuration, fixture.configuration)
        XCTAssertNil(store.quota.value)
        await cli.setBillingError(.billingUnavailable)
        await store.finishSignIn(attempt: attempt, exitCode: 0)
        XCTAssertEqual(store.connection, .failed(.billingUnavailable))
        XCTAssertEqual(store.quota.status, .unavailable)
        XCTAssertEqual(store.local.status, .live)
        let calls = await cli.calls
        XCTAssertEqual(calls.billing, 2)
    }

    @MainActor
    func testCancelledLoginDoesNotStartQuotaProbe() async throws {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let attempt = try XCTUnwrap(store.beginSignIn())
        await store.finishSignIn(attempt: attempt, exitCode: nil)
        XCTAssertEqual(store.connection, .failed(.cancelled))
        let calls = await cli.calls
        XCTAssertEqual(calls.billing, 1)
    }

    @MainActor
    func testRepeatedSignInStartDoesNotCreateAnotherAttempt() async {
        let store = makeStore()
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertNotNil(store.beginSignIn())
        XCTAssertNil(store.beginSignIn(), "A second click must not replace the running login")
        XCTAssertEqual(store.connection, .signingIn)
    }

    @MainActor
    func testOldLoginCompletionCannotFinishNewHomeAttempt() async throws {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let oldAttempt = try XCTUnwrap(store.beginSignIn())
        let other = GrokBuildCLIConfiguration(executable: fixture.configuration.executable,
            home: URL(fileURLWithPath: "/synthetic-other-home"))
        await store.configure(other, enabled: true, monitoring: false)
        let newAttempt = try XCTUnwrap(store.beginSignIn())
        XCTAssertEqual(newAttempt.configuration, other)
        // A delayed callback from the first terminal, not the new terminal.
        await store.finishSignIn(attempt: oldAttempt, exitCode: 0)
        XCTAssertEqual(store.connection, .signingIn)
        XCTAssertNil(store.quota.value)
        let calls = await cli.calls
        XCTAssertEqual(calls.billing, 2, "Old login must not probe the new home")
        await store.finishSignIn(attempt: newAttempt, exitCode: 0)
        XCTAssertEqual(store.connection, .connected)
        let finalCalls = await cli.calls
        XCTAssertEqual(finalCalls.billing, 3)
    }

    @MainActor
    func testOldCancelledLoginCallbackCannotCancelRetry() async throws {
        let store = makeStore()
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let oldAttempt = try XCTUnwrap(store.beginSignIn())
        await store.finishSignIn(attempt: oldAttempt, exitCode: nil)
        let retry = try XCTUnwrap(store.beginSignIn())
        XCTAssertNotEqual(oldAttempt.id, retry.id)
        // Terminal teardown may send its own callback after explicit cancel.
        await store.finishSignIn(attempt: oldAttempt, exitCode: nil)
        XCTAssertEqual(store.connection, .signingIn)
        await store.finishSignIn(attempt: retry, exitCode: nil)
        XCTAssertEqual(store.connection, .failed(.cancelled))
    }

    @MainActor
    func testStoppedLoginCannotFinishRetryAfterResumeWithSameConfiguration() async throws {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let oldAttempt = try XCTUnwrap(store.beginSignIn())
        store.stop()
        XCTAssertNil(store.beginSignIn())
        await store.resume()
        let retry = try XCTUnwrap(store.beginSignIn())
        XCTAssertEqual(oldAttempt.configuration, retry.configuration)
        XCTAssertNotEqual(oldAttempt.id, retry.id)
        await store.finishSignIn(attempt: oldAttempt, exitCode: 0)
        XCTAssertEqual(store.connection, .signingIn)
        let before = await cli.calls
        XCTAssertEqual(before.billing, 1)
        await store.finishSignIn(attempt: retry, exitCode: 0)
        await store.finishSignIn(attempt: retry, exitCode: 0)
        XCTAssertEqual(store.connection, .connected)
        let after = await cli.calls
        XCTAssertEqual(after.billing, 2, "Each successful attempt gets exactly one new quota proof")
        XCTAssertEqual(store.local.status, .stale, "Auth must not rewrite local source freshness")
    }

    @MainActor
    func testLogoutPreservesLocalHistoryAndFailureIsNotSignedOut() async {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let local = store.local.value
        await cli.setSignOutError(.timedOut)
        await store.signOut()
        XCTAssertEqual(store.connection, .failed(.timedOut))
        XCTAssertEqual(store.quota.status, .stale)
        await cli.setSignOutError(nil)
        await store.signOut()
        XCTAssertEqual(store.connection, .signedOut)
        XCTAssertNil(store.quota.value)
        XCTAssertEqual(store.local.value, local)
    }

    @MainActor
    func testConcurrentRefreshesCoalesceIndependently() async {
        let cli = GrokIntegrationCLI()
        let collector = GrokIntegrationCollector()
        let store = makeStore(cli: cli, collector: collector)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        await cli.setDelay(.milliseconds(100))
        await collector.setDelay(.milliseconds(100))
        async let first: Void = store.refresh(forceQuota: true)
        async let second: Void = store.refresh(forceQuota: true)
        async let third: Void = store.refresh(forceQuota: true)
        _ = await (first, second, third)
        let calls = await cli.calls
        let collections = await collector.calls
        XCTAssertEqual(calls.billing, 2)
        XCTAssertEqual(collections, 2)
    }

    @MainActor
    func testStopCancelsVersionSetupBeforeAnyCollection() async throws {
        let cli = GrokIntegrationCLI()
        await cli.setDelay(.seconds(10))
        let collector = GrokIntegrationCollector()
        let store = makeStore(cli: cli, collector: collector)
        let task = Task { await store.configure(fixture.configuration, enabled: true, monitoring: false) }
        try await eventually { await cli.calls.version == 1 }
        store.stop()
        await task.value
        let calls = await cli.calls
        let collections = await collector.calls
        XCTAssertEqual(calls.billing, 0)
        XCTAssertEqual(calls.cancellations, 1)
        XCTAssertEqual(collections, 0)
        XCTAssertNil(store.cliVersion)
    }

    @MainActor
    func testStopCancelsInFlightRefreshesAndRetainsStaleValues() async throws {
        let cli = GrokIntegrationCLI()
        let collector = GrokIntegrationCollector()
        let store = makeStore(cli: cli, collector: collector)
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        await cli.setDelay(.seconds(10))
        await collector.setDelay(.seconds(10))
        let task = Task { await store.refresh(forceQuota: true) }
        try await eventually {
            let collections = await collector.calls
            let billing = await cli.calls.billing
            return collections == 2 && billing == 2
        }
        store.stop()
        await task.value
        XCTAssertFalse(store.isRefreshingLocal)
        XCTAssertFalse(store.isRefreshingQuota)
        XCTAssertEqual(store.local.status, .stale)
        XCTAssertEqual(store.quota.status, .stale)
        let calls = await cli.calls
        let cancellations = await collector.cancellations
        XCTAssertEqual(calls.cancellations, 1)
        XCTAssertEqual(cancellations, 1)
    }

    @MainActor
    func testChangingHomeIgnoresLateOldCollection() async throws {
        let collector = GrokIntegrationCollector()
        let store = makeStore(collector: collector)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        await collector.setDelay(.milliseconds(120), ignoreCancellation: true)
        let old = Task { await store.refreshLocal(force: true) }
        try await eventually { await collector.calls == 2 }
        await collector.setDelay(.zero)
        await collector.setInput(300)
        let other = GrokBuildCLIConfiguration(executable: fixture.configuration.executable, home: URL(fileURLWithPath: "/other-grok-home"))
        await store.configure(other, enabled: true, monitoring: false)
        await old.value
        XCTAssertEqual(store.configuration, other)
        XCTAssertEqual(store.local.value?.days.last?.tokens, 320)
    }

    @MainActor
    func testCLIInstalledAfterStartupRecoversVersion() async {
        let cli = GrokIntegrationCLI()
        let clock = GrokIntegrationClock(fixture.now)
        await cli.setVersionError(.executableMissing)
        let store = makeStore(cli: cli, clock: clock)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertNil(store.cliVersion)
        await cli.setVersionError(nil)
        clock.date = clock.date.addingTimeInterval(16)
        await store.refresh()
        XCTAssertEqual(store.cliVersion, "0.0.0-fixture")
    }

    @MainActor
    func testCacheWriteFailureDoesNotDiscardLiveObservations() async {
        let repository = GrokIntegrationCache()
        repository.saveFails = true
        let store = makeStore(repository: repository)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertEqual(store.cacheWarning, .cacheUnavailable)
        XCTAssertEqual(store.local.status, .live)
        XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
    }

    @MainActor
    func testRestoreKeepsCachedHistoryWhenCollectionFails() async {
        let repository = GrokIntegrationCache()
        repository.put(fixture.cache())
        let collector = GrokIntegrationCollector()
        await collector.setError(.invalidHome)
        let store = makeStore(collector: collector, repository: repository)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertEqual(store.local.status, .stale)
        XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
        XCTAssertEqual(store.local.error, .invalidHome)
        XCTAssertEqual(store.quota.status, .live)
    }

    @MainActor
    func testFileEventsDebounceAndOldHomeCallbacksAreIgnored() async throws {
        let collector = GrokIntegrationCollector()
        let monitor = GrokIntegrationMonitor()
        let store = makeStore(collector: collector, monitor: monitor)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: true)
        let oldCallback = monitor.callback
        for _ in 0..<10 { monitor.fire() }
        try await eventually { await collector.calls == 2 }
        try await Task.sleep(for: .milliseconds(600))
        var calls = await collector.calls
        XCTAssertEqual(calls, 2)
        let other = GrokBuildCLIConfiguration(executable: fixture.configuration.executable, home: URL(fileURLWithPath: "/other"))
        await store.configure(other, enabled: true, monitoring: true)
        oldCallback?()
        try await Task.sleep(for: .milliseconds(600))
        calls = await collector.calls
        XCTAssertEqual(calls, 3)
    }

    @MainActor
    func testPollingFallbackRetriesFileMonitorAndStopsOnDisable() async throws {
        let monitor = GrokIntegrationMonitor()
        monitor.canStart = false
        let collector = GrokIntegrationCollector()
        let store = makeStore(collector: collector, monitor: monitor, polling: .milliseconds(50))
        await store.configure(fixture.configuration, enabled: true, monitoring: true)
        XCTAssertFalse(store.eventMonitorAvailable)
        monitor.canStart = true
        try await eventually { await collector.calls >= 2 }
        XCTAssertTrue(store.eventMonitorAvailable)
        await store.configure(fixture.configuration, enabled: false, monitoring: false)
        let before = await collector.calls
        monitor.fire()
        try await Task.sleep(for: .milliseconds(150))
        let after = await collector.calls
        XCTAssertEqual(after, before)
        XCTAssertFalse(store.isMonitoring)
    }

    @MainActor
    func testManualOnlyResumeDoesNotCollectUntilExplicitRefresh() async {
        let cli = GrokIntegrationCLI()
        let collector = GrokIntegrationCollector()
        let monitor = GrokIntegrationMonitor()
        let store = makeStore(cli: cli, collector: collector, monitor: monitor)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let before = await cli.calls
        store.stop()
        await store.resume()
        let after = await cli.calls
        let collections = await collector.calls
        XCTAssertEqual(collections, 1)
        XCTAssertEqual(after.version, before.version)
        XCTAssertEqual(after.billing, before.billing)
        XCTAssertEqual(monitor.starts, 0)
        XCTAssertFalse(store.isMonitoring)
        XCTAssertEqual(store.local.status, .stale)
        await store.refresh(forceQuota: true, forceLocal: true)
        let refreshedCollections = await collector.calls
        XCTAssertEqual(refreshedCollections, 2)
        XCTAssertEqual(store.local.status, .live)
    }

    @MainActor
    func testCalendarProjectionMovesTodayAtMidnightWithoutCollectingOrRefreshingTimestamps() async {
        let cli = GrokIntegrationCLI()
        let collector = GrokIntegrationCollector()
        let clock = GrokIntegrationClock(fixture.now)
        let store = makeStore(cli: cli, collector: collector, clock: clock)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let before = store.local
        let calls = await cli.calls
        clock.date = fixture.calendar.date(byAdding: .day, value: 1, to: fixture.now)!
        await store.reprojectCalendar()
        XCTAssertEqual(store.local.value?.days.count, 30)
        XCTAssertNil(store.local.value?.days.last?.tokens)
        XCTAssertEqual(store.local.value?.days.dropLast().last?.tokens, 120)
        XCTAssertNil(store.continuity()?.currentDays)
        XCTAssertEqual(store.local.collectedAt, before.collectedAt)
        XCTAssertEqual(store.local.sourceUpdatedAt, before.sourceUpdatedAt)
        XCTAssertEqual(store.local.lastAttemptAt, before.lastAttemptAt)
        XCTAssertEqual(store.quota.status, .stale)
        let after = await cli.calls
        let collections = await collector.calls
        XCTAssertEqual(after.version, calls.version)
        XCTAssertEqual(after.billing, calls.billing)
        XCTAssertEqual(collections, 1)
        XCTAssertFalse(store.isMonitoring)
    }

    @MainActor
    func testCalendarProjectionPrunesDetailsButKeepsDurableBadgeAndSourceAge() async throws {
        let (store, cli, repository, clock, _) = await claimableStore()
        defer { store.stop() }
        let collected = store.local.collectedAt
        let calls = await cli.calls
        clock.date = fixture.calendar.date(byAdding: .day, value: 90, to: clock.date)!
        await store.reprojectCalendar()
        XCTAssertTrue(store.local.value?.days.allSatisfy { $0.tokens == nil && $0.modelTokens.isEmpty } == true)
        XCTAssertEqual(store.continuity()?.summary.earnedBadge, .firstPrompt)
        XCTAssertEqual(store.local.collectedAt, collected)
        let saved = try XCTUnwrap(repository.load(home: fixture.configuration.home))
        XCTAssertTrue(saved.ledger.sessions.isEmpty)
        XCTAssertNil(saved.calendarIdentifier)
        XCTAssertEqual(saved.activity?.witnesses.count, 1)
        XCTAssertNil(saved.activity?.pendingDay)
        XCTAssertEqual(saved.collectedAt, collected)
        let after = await cli.calls
        XCTAssertEqual(after.usage, calls.usage)
        let celebration = await store.claimCelebration()
        XCTAssertNil(celebration)
        // A clock/timezone reversal can make that discarded edge relevant
        // again. A normal explicit refresh must not reuse unchanged metadata.
        clock.date = fixture.now.addingTimeInterval(30)
        await store.refreshLocal()
        XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
        let recovered = await cli.calls
        XCTAssertEqual(recovered.usage, calls.usage + 1)
    }

    @MainActor
    func testTimezoneRoundTripClearsPendingCelebrationAndDoesNotCallCLI() async throws {
        let (store, cli, repository, clock, _) = await claimableStore()
        defer { store.stop() }
        XCTAssertNotNil(store.activity?.pendingDay)
        let before = await cli.calls
        let collected = store.local.collectedAt
        clock.calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        await store.reprojectCalendar()
        XCTAssertEqual(store.local.value?.days.last?.startDate, clock.calendar.startOfDay(for: clock.date))
        XCTAssertNil(store.activity?.pendingDay)
        clock.calendar = fixture.calendar
        await store.reprojectCalendar()
        let celebration = await store.claimCelebration()
        XCTAssertNil(celebration)
        let saved = try XCTUnwrap(repository.load(home: fixture.configuration.home))
        XCTAssertEqual(saved.activity?.timeZoneIdentifier, clock.calendar.timeZone.identifier)
        XCTAssertNil(saved.activity?.pendingDay)
        XCTAssertEqual(store.local.collectedAt, collected)
        let after = await cli.calls
        XCTAssertEqual(after.usage, before.usage)
        XCTAssertEqual(after.billing, before.billing)
    }

    @MainActor
    func testCalendarProjectionDuringStartupDoesNotCompleteInitialImport() async throws {
        let cli = GrokIntegrationCLI()
        let clock = GrokIntegrationClock(fixture.now)
        let recorded = fixture.now.addingTimeInterval(30)
        await cli.setDelay(.milliseconds(75))
        await cli.setUsageDate(recorded)
        let store = GrokBuildUsageStore(cli: cli,
            collector: GrokBuildLocalUsageProvider(cli: cli, discovery: GrokIntegrationDiscovery(sources: [fixture.source()])),
            repository: GrokIntegrationCache(), monitor: GrokIntegrationMonitor(),
            now: { clock.date }, calendar: { clock.calendar })
        defer { store.stop() }
        let configure = Task { await store.configure(fixture.configuration, enabled: true, monitoring: false) }
        try await eventually { await cli.calls.version == 1 }
        XCTAssertFalse(store.activity?.initialImportCompleted ?? true)
        clock.date = recorded
        await configure.value
        XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
        XCTAssertTrue(store.activity?.initialImportCompleted == true)
        XCTAssertNil(store.activity?.pendingDay, "Initial source import must not celebrate even after slow CLI startup")
        let banner = await store.claimCelebration()
        XCTAssertNil(banner)
    }

    @MainActor
    func testCalendarProjectionOldHomeWriteCannotPublishIntoNewConfiguration() async throws {
        let (store, _, repository, clock, _) = await claimableStore()
        defer { store.stop() }
        let gate = repository.holdNextSave()
        defer { gate.release() }
        clock.calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let projection = Task { await store.reprojectCalendar() }
        try await eventually { gate.entered }
        let replacement = GrokBuildCLIConfiguration(executable: fixture.configuration.executable,
            home: URL(fileURLWithPath: "/synthetic-grok-other-home"))
        let configure = Task { await store.configure(replacement, enabled: true, monitoring: false) }
        try await eventually { store.configuration == replacement }
        gate.release()
        await projection.value
        await configure.value
        XCTAssertEqual(store.configuration, replacement)
        XCTAssertEqual(store.activity?.namespace, GrokBuildHistoryLedger(home: replacement.home).namespace)
        XCTAssertNotEqual(store.activity?.namespace, GrokBuildHistoryLedger(home: fixture.configuration.home).namespace)
        let old = try XCTUnwrap(repository.load(home: fixture.configuration.home))
        XCTAssertEqual(old.activity?.timeZoneIdentifier, clock.calendar.timeZone.identifier)
    }

    @MainActor
    func testCalendarProjectionWaitsForClaimWriteAndDoesNotDeliverAnOldTimezoneBanner() async throws {
        let (store, _, repository, clock, _) = await claimableStore()
        defer { store.stop() }
        let gate = repository.holdNextSave()
        defer { gate.release() }
        let claim = Task { await store.claimCelebration() }
        try await eventually { gate.entered }
        clock.calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let projection = Task { await store.reprojectCalendar() }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(store.activity?.timeZoneIdentifier, fixture.calendar.timeZone.identifier)
        gate.release()
        let staleBanner = await claim.value
        await projection.value
        XCTAssertNil(staleBanner)
        let saved = try XCTUnwrap(repository.load(home: fixture.configuration.home))
        XCTAssertTrue(saved.activity?.celebratedDays.contains("2026-09-16") == true)
        XCTAssertEqual(saved.activity?.timeZoneIdentifier, clock.calendar.timeZone.identifier)
        clock.calendar = fixture.calendar
        await store.reprojectCalendar()
        let replay = await store.claimCelebration()
        XCTAssertNil(replay)
    }

    @MainActor
    func testCalendarProjectionWaitsForInFlightCollectionAndUsesCurrentDay() async throws {
        let collector = GrokIntegrationCollector()
        let clock = GrokIntegrationClock(fixture.now)
        let store = makeStore(collector: collector, clock: clock)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        await collector.setDelay(.milliseconds(150))
        let refresh = Task { await store.refreshLocal(force: true) }
        try await eventually { store.isRefreshingLocal }
        clock.date = fixture.calendar.date(byAdding: .day, value: 1, to: clock.date)!
        await store.reprojectCalendar()
        await refresh.value
        XCTAssertNil(store.local.value?.days.last?.tokens)
        XCTAssertEqual(store.local.value?.days.dropLast().last?.tokens, 120)
        let count = await collector.calls
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testCalendarProjectionWriteFailureCanRetryWithoutLosingData() async throws {
        let (store, _, repository, clock, _) = await claimableStore()
        defer { store.stop() }
        repository.saveFails = true
        clock.calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        await store.reprojectCalendar()
        XCTAssertEqual(store.cacheWarning, .cacheUnavailable)
        XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
        XCTAssertNil(store.activity?.pendingDay)
        repository.saveFails = false
        await store.reprojectCalendar()
        XCTAssertNil(store.cacheWarning)
        let saved = try XCTUnwrap(repository.load(home: fixture.configuration.home))
        XCTAssertEqual(saved.activity?.timeZoneIdentifier, clock.calendar.timeZone.identifier)
        XCTAssertNil(saved.activity?.pendingDay)
    }

    @MainActor
    func testCalendarProjectionUses23And25HourDSTDays() async {
        for (instant, hours) in [("2026-03-08T12:00:00Z", 23), ("2026-11-01T12:00:00Z", 25)] {
            let clock = GrokIntegrationClock(GrokBuildDates.parse(instant)!)
            let store = makeStore(clock: clock)
            await store.configure(fixture.configuration, enabled: true, monitoring: false)
            clock.calendar.timeZone = TimeZone(identifier: "America/New_York")!
            await store.reprojectCalendar()
            let today = clock.calendar.startOfDay(for: clock.date)
            let tomorrow = clock.calendar.date(byAdding: .day, value: 1, to: today)!
            XCTAssertEqual(tomorrow.timeIntervalSince(today), Double(hours * 3600))
            XCTAssertEqual(store.local.value?.days.last?.startDate, today)
            XCTAssertEqual(store.local.value?.days.last?.tokens, 120)
            clock.date = tomorrow.addingTimeInterval(1)
            await store.reprojectCalendar()
            XCTAssertNil(store.local.value?.days.last?.tokens)
            XCTAssertEqual(store.local.value?.days.dropLast().last?.tokens, 120)
            store.stop()
        }
    }

    func testRecursiveFileMonitorObservesNestedSessionWrite() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let nested = directory.appendingPathComponent("sessions/cwd/session")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let event = expectation(description: "nested filesystem event")
        event.assertForOverFulfill = false
        let monitor = GrokBuildFileEventMonitor()
        defer { monitor.stop() }
        XCTAssertTrue(monitor.start(home: directory) { event.fulfill() })
        try Data("synthetic".utf8).write(to: nested.appendingPathComponent("usage.json"))
        await fulfillment(of: [event], timeout: 5)
    }

    @MainActor
    func testStorePersistsClaimBeforeReturningAndRestartDoesNotReplay() async throws {
        let (store, cli, repository, clock, discovery) = await claimableStore()
        defer { store.stop() }
        let celebration = await store.claimCelebration()
        XCTAssertNotNil(celebration)
        let persisted = try repository.load(home: fixture.configuration.home)
        XCTAssertTrue(persisted?.activity?.celebratedDays.contains("2026-09-16") == true)
        store.stop()
        let restored = GrokBuildUsageStore(cli: cli,
            collector: GrokBuildLocalUsageProvider(cli: cli, discovery: discovery), repository: repository,
            monitor: GrokIntegrationMonitor(), now: { clock.date }, calendar: { self.fixture.calendar })
        defer { restored.stop() }
        await restored.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertEqual(restored.continuity()?.currentDays, 1)
        let repeated = await restored.claimCelebration()
        XCTAssertNil(repeated)
    }

    @MainActor
    func testClaimWriteFailureReturnsNoCelebrationAndCanRetrySafely() async {
        let (store, _, repository, _, _) = await claimableStore()
        defer { store.stop() }
        repository.saveFails = true
        let failed = await store.claimCelebration()
        XCTAssertNil(failed)
        XCTAssertEqual(store.cacheWarning, .cacheUnavailable)
        XCTAssertNotNil(store.activity?.pendingDay)
        repository.saveFails = false
        let successful = await store.claimCelebration()
        XCTAssertNotNil(successful)
        let repeated = await store.claimCelebration()
        XCTAssertNil(repeated)
    }

    @MainActor
    func testConcurrentClaimAndCollectionCannotOverwriteClaim() async throws {
        let (store, _, repository, _, _) = await claimableStore()
        defer { store.stop() }
        async let first = store.claimCelebration()
        async let second = store.claimCelebration()
        async let refresh: Void = store.refreshLocal(force: true)
        let claims = await [first, second]
        _ = await refresh
        XCTAssertEqual(claims.compactMap { $0 }.count, 1)
        let persisted = try repository.load(home: fixture.configuration.home)
        XCTAssertTrue(persisted?.activity?.celebratedDays.contains("2026-09-16") == true)
        let repeated = await store.claimCelebration()
        XCTAssertNil(repeated)
    }

    @MainActor
    func testReconfigurationWaitsForAlreadyStartedClaimWrite() async throws {
        let (store, _, repository, _, _) = await claimableStore()
        defer { store.stop() }
        let gate = repository.holdNextSave()
        defer { gate.release() }
        let claim = Task { await store.claimCelebration() }
        try await eventually { gate.entered }
        let loads = repository.loads
        let reconfigure = Task {
            await store.configure(self.fixture.configuration, enabled: true, monitoring: false)
        }
        // Configuration must not read an older cache while the cancelled
        // generation's atomic claim write is still finishing on disk.
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(repository.loads, loads)
        gate.release()
        _ = await claim.value
        await reconfigure.value
        XCTAssertTrue(store.activity?.celebratedDays.contains("2026-09-16") == true)
        let repeated = await store.claimCelebration()
        XCTAssertNil(repeated)
    }

    @MainActor
    private func claimableStore() async -> (GrokBuildUsageStore, GrokIntegrationCLI, GrokIntegrationCache, GrokIntegrationClock, GrokIntegrationDiscovery) {
        let cli = GrokIntegrationCLI()
        await cli.setInput(0)
        let discovery = GrokIntegrationDiscovery(sources: [fixture.source()])
        let repository = GrokIntegrationCache()
        let clock = GrokIntegrationClock(fixture.now)
        let store = GrokBuildUsageStore(cli: cli, collector: GrokBuildLocalUsageProvider(cli: cli, discovery: discovery),
            repository: repository, monitor: GrokIntegrationMonitor(), now: { clock.date }, calendar: { clock.calendar })
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        clock.date = fixture.now.addingTimeInterval(30)
        await cli.setInput(100)
        await cli.setUsageDate(clock.date)
        discovery.replace([fixture.source(fingerprint: "new-activity")])
        await store.refreshLocal(force: true)
        return (store, cli, repository, clock, discovery)
    }

    private func collect(_ provider: GrokBuildLocalUsageProvider, cache: GrokBuildHistoryCache? = nil) async throws -> GrokBuildLocalCollection {
        try await provider.collect(configuration: fixture.configuration, cache: cache ?? .init(home: fixture.configuration.home),
                                   now: fixture.now, calendar: fixture.calendar, force: false)
    }

    @MainActor
    private func makeStore(cli: GrokIntegrationCLI = .init(), collector: GrokIntegrationCollector = .init(),
                           repository: GrokIntegrationCache = .init(), monitor: GrokIntegrationMonitor = .init(),
                           clock: GrokIntegrationClock? = nil, polling: Duration = .seconds(60),
                           authentication: GrokBuildAuthenticationController? = nil) -> GrokBuildUsageStore {
        let instant = fixture.now
        let calendar = fixture.calendar
        return .init(cli: cli, collector: collector, repository: repository, monitor: monitor,
                     pollingInterval: polling, now: { clock?.date ?? instant }, calendar: { clock?.calendar ?? calendar },
                     authentication: authentication)
    }

    @MainActor
    func testAuthenticationControllerCompletesThenRequiresQuotaAndClearsOutput() async throws {
        let runner = GrokAuthenticationFixtureRunner()
        let auth = GrokBuildAuthenticationController(runner: runner, supportedVersions: ["0.0.0-fixture"])
        let cli = GrokIntegrationCLI()
        await cli.setBillingError(.billingStartupUnverified)
        let store = makeStore(cli: cli, authentication: auth)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let local = store.local.value
        XCTAssertTrue(auth.start(store: store, deviceCode: false))
        XCTAssertFalse(auth.start(store: store, deviceCode: true))
        try await eventually { !auth.isRunning }
        XCTAssertTrue(store.signInCommandCompleted)
        XCTAssertEqual(store.connection, .failed(.billingStartupUnverified))
        XCTAssertTrue(auth.output.isEmpty)
        XCTAssertEqual(store.local.value, local)
        let requests = await runner.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.0, fixture.configuration)
        XCTAssertEqual(requests.first?.1, false)
        let calls = await cli.calls
        XCTAssertEqual(calls.billing, 2)
    }

    @MainActor
    func testDeviceAuthenticationCancellationStopsRunnerAndAllowsRetry() async throws {
        let runner = GrokAuthenticationFixtureRunner(delay: .seconds(10))
        let auth = GrokBuildAuthenticationController(runner: runner, supportedVersions: ["0.0.0-fixture"])
        let store = makeStore(authentication: auth)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertTrue(auth.start(store: store, deviceCode: true))
        try await eventually { !auth.output.isEmpty }
        auth.cancel()
        XCTAssertTrue(auth.output.isEmpty)
        XCTAssertFalse(auth.start(store: store, deviceCode: false), "Must wait for cancellation cleanup")
        try await eventually { !auth.isRunning }
        XCTAssertEqual(store.connection, .failed(.cancelled))
        XCTAssertFalse(store.signInCommandCompleted)
        let requests = await runner.requests
        XCTAssertEqual(requests.first?.1, true)
        XCTAssertTrue(auth.start(store: store, deviceCode: false))
        auth.cancel()
        try await eventually { !auth.isRunning }
    }

    @MainActor
    func testAuthenticationTimeoutAndOutputOverflowDoNotBecomeSignedOut() async throws {
        for failure in [GrokBuildError.timedOut, .outputTooLarge, .commandFailed] {
            let runner = GrokAuthenticationFixtureRunner(failure: failure)
            let auth = GrokBuildAuthenticationController(runner: runner, supportedVersions: ["0.0.0-fixture"])
            let store = makeStore(authentication: auth)
            await store.configure(fixture.configuration, enabled: true, monitoring: false)
            XCTAssertTrue(auth.start(store: store, deviceCode: false))
            try await eventually { !auth.isRunning }
            XCTAssertEqual(store.connection, .failed(failure))
            XCTAssertFalse(store.signInCommandCompleted)
            XCTAssertTrue(auth.output.isEmpty)
            XCTAssertEqual(store.local.status, .live)
            store.stop()
        }
    }

    @MainActor
    func testChangingHomeCancelsAuthenticationWithoutLateOutputOrCompletion() async throws {
        let runner = GrokAuthenticationFixtureRunner(delay: .seconds(10))
        let auth = GrokBuildAuthenticationController(runner: runner, supportedVersions: ["0.0.0-fixture"])
        let store = makeStore(authentication: auth)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertTrue(auth.start(store: store, deviceCode: false))
        try await eventually { !auth.output.isEmpty }
        let other = GrokBuildCLIConfiguration(executable: fixture.configuration.executable, home: URL(fileURLWithPath: "/other-home"))
        await store.configure(other, enabled: true, monitoring: false)
        try await eventually { !auth.isRunning }
        XCTAssertTrue(auth.output.isEmpty)
        XCTAssertFalse(store.signInCommandCompleted)
        XCTAssertEqual(store.connection, .connected)
        XCTAssertEqual(store.configuration, other)
    }

    @MainActor
    func testUnsupportedVersionDoesNotStartAuthentication() async {
        let auth = GrokBuildAuthenticationController(runner: GrokAuthenticationFixtureRunner())
        let store = makeStore(authentication: auth)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertFalse(auth.start(store: store, deviceCode: false))
        XCTAssertFalse(auth.isRunning)
    }

    @MainActor
    func testCancelDuringPostLoginQuotaCheckCannotConnectLater() async throws {
        let auth = GrokBuildAuthenticationController(runner: GrokAuthenticationFixtureRunner(), supportedVersions: ["0.0.0-fixture"])
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli, authentication: auth)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        await cli.setDelay(.seconds(10))
        XCTAssertTrue(auth.start(store: store, deviceCode: false))
        try await eventually { store.connection == .checking && store.signInCommandCompleted }
        store.cancelAuthentication()
        try await eventually { !auth.isRunning }
        XCTAssertEqual(store.connection, .failed(.cancelled))
        XCTAssertNil(store.quota.value)
        XCTAssertFalse(store.isRefreshingQuota)
        XCTAssertEqual(store.local.status, .live)
    }

    @MainActor
    func testAuthenticationControllerConnectsOnlyAfterSuccessfulBilling() async throws {
        let auth = GrokBuildAuthenticationController(runner: GrokAuthenticationFixtureRunner(), supportedVersions: ["0.0.0-fixture"])
        let store = makeStore(authentication: auth)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        XCTAssertTrue(auth.start(store: store, deviceCode: false))
        try await eventually { !auth.isRunning }
        XCTAssertTrue(store.signInCommandCompleted)
        XCTAssertEqual(store.connection, .connected)
        XCTAssertEqual(store.quota.status, .live)
        XCTAssertTrue(auth.output.isEmpty)
    }

    @MainActor
    func testCompletedUnverifiedLogoutDropsAccountQuotaButPreservesLocalHistory() async {
        let cli = GrokIntegrationCLI()
        let store = makeStore(cli: cli)
        defer { store.stop() }
        await store.configure(fixture.configuration, enabled: true, monitoring: false)
        let history = store.local
        let badge = store.continuity()
        await cli.setSignOutError(.signOutUnverified)
        await store.signOut()
        XCTAssertNil(store.quota.value)
        XCTAssertEqual(store.connection, .failed(.signOutUnverified))
        XCTAssertEqual(store.local, history)
        XCTAssertEqual(store.continuity(), badge)
    }

    private func eventually(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition did not become true within two seconds")
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grok-integration-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private actor GrokAuthenticationFixtureRunner: GrokBuildAuthenticationRunning {
    let delay: Duration
    let failure: GrokBuildError?
    private(set) var requests: [(GrokBuildCLIConfiguration, Bool)] = []
    init(delay: Duration = .milliseconds(20), failure: GrokBuildError? = nil) {
        self.delay = delay; self.failure = failure
    }
    func signIn(configuration: GrokBuildCLIConfiguration, deviceCode: Bool,
                onOutput: @escaping @Sendable (Data) -> Void) async throws -> Int32 {
        requests.append((configuration, deviceCode))
        onOutput(Data("Synthetic sign-in instructions; no real code or URL.\n".utf8))
        do { try await Task.sleep(for: delay) }
        catch {
            // A final queued output chunk must not repopulate a cancelled view.
            onOutput(Data("Late synthetic output".utf8))
            throw error
        }
        if let failure { throw failure }
        return 0
    }
}

private struct GrokIntegrationFixture: Sendable {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let now = GrokBuildDates.parse("2026-09-16T12:00:00Z")!
    let configuration = GrokBuildCLIConfiguration(executable: URL(fileURLWithPath: "/synthetic/grok"), home: URL(fileURLWithPath: "/synthetic-grok-home"))
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    func source(id suppliedID: UUID? = nil, fingerprint: String = "initial", kind: String? = nil, parent: String? = nil) -> GrokBuildSessionSource {
        let identity = suppliedID ?? id
        return .init(id: identity, directory: configuration.home.appendingPathComponent("sessions/cwd/\(identity)"),
                     lineage: .init(info: .init(id: identity), parentSessionID: parent, forkedAt: nil,
                                    sessionKind: kind, forkContextSource: nil), fingerprint: fingerprint)
    }
    func usage(id suppliedID: UUID? = nil, input: Int64 = 100, at: Date? = nil) -> GrokBuildSessionUsage {
        let counts = GrokBuildTokenCounts(input: input, output: input > 0 ? 20 : 0,
            total: input > 0 ? input + 20 : 0, cacheRead: nil, cacheWrite: nil, reasoning: nil)
        return .init(id: suppliedID ?? id, sourceUpdatedAt: at ?? now, total: counts,
                     turns: [.init(number: 1, recordedAt: at ?? now, tokens: counts,
                                   models: ["synthetic-model": counts], upstreamIncomplete: false)])
    }
    func cache(home: URL? = nil, input: Int64 = 100, at: Date? = nil) -> GrokBuildHistoryCache {
        var cache = GrokBuildHistoryCache(home: home ?? configuration.home)
        _ = cache.ledger.ingest(usage(input: input, at: at), lineage: source().lineage,
                                observedAt: at ?? now, calendar: calendar)
        cache.collectedAt = at ?? now
        return cache
    }
}

private actor GrokIntegrationCLI: GrokBuildCLIProviding {
    struct Calls { var version = 0; var usage = 0; var billing = 0; var signOut = 0; var cancellations = 0 }
    private(set) var calls = Calls()
    private var input: Int64 = 100
    private var delay = Duration.zero
    private var versionError: GrokBuildError?
    private var usageError: GrokBuildError?
    private var usageDate: Date?
    private var billingError: GrokBuildError?
    private var signOutError: GrokBuildError?
    func setInput(_ value: Int64) { input = value }
    func setDelay(_ value: Duration) { delay = value }
    func setVersionError(_ value: GrokBuildError?) { versionError = value }
    func setUsageError(_ value: GrokBuildError?) { usageError = value }
    func setUsageDate(_ value: Date) { usageDate = value }
    func setBillingError(_ value: GrokBuildError?) { billingError = value }
    func setSignOutError(_ value: GrokBuildError?) { signOutError = value }
    private func wait() async throws {
        do { try await Task.sleep(for: delay); try Task.checkCancellation() }
        catch { calls.cancellations += 1; throw error }
    }
    func version(configuration: GrokBuildCLIConfiguration) async throws -> String {
        calls.version += 1
        try await wait()
        if let versionError { throw versionError }
        return "0.0.0-fixture"
    }
    func usage(id: UUID, configuration: GrokBuildCLIConfiguration) async throws -> GrokBuildSessionUsage {
        calls.usage += 1
        try await wait()
        if let usageError { throw usageError }
        return GrokIntegrationFixture().usage(id: id, input: input, at: usageDate)
    }
    func billing(configuration: GrokBuildCLIConfiguration, observedAt: Date) async throws -> GrokBuildQuotaSnapshot {
        calls.billing += 1
        try await wait()
        if let billingError { throw billingError }
        return .init(usedPercent: 25, periodType: nil, startsAt: nil, resetsAt: nil,
                     scope: .unspecified, subscriptionTier: nil, observedAt: observedAt)
    }
    func signOut(configuration: GrokBuildCLIConfiguration) async throws {
        calls.signOut += 1
        try await wait()
        if let signOutError { throw signOutError }
    }
}

private final class GrokIntegrationDiscovery: GrokBuildSessionDiscovering, @unchecked Sendable {
    private let lock = NSLock()
    private var sources: [GrokBuildSessionSource]
    private var secondScan: [GrokBuildSessionSource]?
    private var scans = 0
    init(sources: [GrokBuildSessionSource]) { self.sources = sources }
    func replace(_ value: [GrokBuildSessionSource]) { lock.withLock { sources = value } }
    func replaceOnSecondScan(_ value: [GrokBuildSessionSource]) { lock.withLock { secondScan = value } }
    func scan(home: URL) throws -> GrokBuildDiscoveryResult {
        lock.withLock {
            scans += 1
            if scans == 2, let secondScan { sources = secondScan }
            return .init(sources: sources, excludedCount: 0, limited: false)
        }
    }
    func fingerprint(directory: URL) throws -> String {
        try lock.withLock {
            guard let source = sources.first(where: { $0.directory == directory }) else { throw GrokBuildError.sourceChanged }
            return source.fingerprint
        }
    }
}

private actor GrokIntegrationCollector: GrokBuildLocalCollecting {
    private(set) var calls = 0
    private(set) var cancellations = 0
    private var input: Int64 = 100
    private var delay = Duration.zero
    private var ignoresCancellation = false
    private var failure: GrokBuildError?
    func setDelay(_ value: Duration, ignoreCancellation: Bool = false) { delay = value; ignoresCancellation = ignoreCancellation }
    func setError(_ value: GrokBuildError?) { failure = value }
    func setInput(_ value: Int64) { input = value }
    func collect(configuration: GrokBuildCLIConfiguration, cache: GrokBuildHistoryCache, now: Date,
                 calendar: Calendar, force: Bool) async throws -> GrokBuildLocalCollection {
        calls += 1
        let input = input
        let ignoresCancellation = ignoresCancellation
        do { try await Task.sleep(for: delay) }
        catch { cancellations += 1; if !ignoresCancellation { throw error } }
        if let failure { throw failure }
        let result = GrokIntegrationFixture().cache(home: configuration.home, input: input, at: now)
        return .init(cache: result, snapshot: result.ledger.snapshot(now: now, calendar: calendar), readableRootCount: 1)
    }
}

private final class GrokIntegrationCache: GrokBuildHistoryCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: GrokBuildHistoryCache] = [:]
    private var loadCount = 0
    private var fails = false
    private var nextSaveGate: GrokIntegrationWriteGate?
    var saveFails: Bool { get { lock.withLock { fails } } set { lock.withLock { fails = newValue } } }
    var loads: Int { lock.withLock { loadCount } }
    func holdNextSave() -> GrokIntegrationWriteGate {
        let gate = GrokIntegrationWriteGate()
        lock.withLock { nextSaveGate = gate }
        return gate
    }
    func put(_ value: GrokBuildHistoryCache) { lock.withLock { values[value.ledger.namespace] = value } }
    func load(home: URL) throws -> GrokBuildHistoryCache? {
        lock.withLock { loadCount += 1; return values[GrokBuildHistoryLedger(home: home).namespace] }
    }
    func save(_ cache: GrokBuildHistoryCache) throws {
        let gate = lock.withLock { () -> GrokIntegrationWriteGate? in
            defer { nextSaveGate = nil }
            return nextSaveGate
        }
        gate?.wait()
        try lock.withLock {
            if fails { throw GrokBuildError.cacheUnavailable }
            values[cache.ledger.namespace] = cache
        }
    }
}

private final class GrokIntegrationWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var didEnter = false
    var entered: Bool { lock.withLock { didEnter } }
    func wait() {
        lock.withLock { didEnter = true }
        _ = semaphore.wait(timeout: .now() + 5)
    }
    func release() { semaphore.signal() }
}

private final class GrokIntegrationMonitor: GrokBuildFileMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var action: (@Sendable () -> Void)?
    private var startsCount = 0
    private var allowed = true
    var canStart: Bool { get { lock.withLock { allowed } } set { lock.withLock { allowed = newValue } } }
    var starts: Int { lock.withLock { startsCount } }
    var callback: (@Sendable () -> Void)? { lock.withLock { action } }
    func start(home: URL, onChange: @escaping @Sendable () -> Void) -> Bool {
        lock.withLock { startsCount += 1; action = onChange; return allowed }
    }
    func stop() { lock.withLock { action = nil } }
    func fire() { callback?() }
}

@MainActor private final class GrokIntegrationClock {
    var date: Date
    var calendar = GrokIntegrationFixture().calendar
    init(_ date: Date) { self.date = date }
}
