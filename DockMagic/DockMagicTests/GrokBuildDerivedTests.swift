import Foundation
import XCTest
@testable import DockMagic

final class GrokBuildDerivedTests: XCTestCase {
    private let now = GrokBuildDates.parse("2026-09-16T12:00:00Z")!
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testLegacyStreakKeepsYesterdayEndpointAndTodayPending() {
        let summary = TokenUsageStreakCalculator.summary(from: records(offsets: [-3, -2, -1]), now: now, calendar: calendar)
        XCTAssertEqual(summary.currentDays, 3)
        XCTAssertEqual(summary.bestDays, 3)
        XCTAssertEqual(summary.recentDays.last?.state, .todayPending)
        XCTAssertEqual(summary.earnedBadge, .spark)
    }

    func testLegacyStreakKeepsMissingTrackedDaysInactive() {
        let summary = TokenUsageStreakCalculator.summary(from: records(offsets: [-4, -2, 0]), now: now, calendar: calendar)
        XCTAssertEqual(summary.recentDays[3].state, .inactive)
        XCTAssertEqual(summary.recentDays[5].state, .inactive)
        XCTAssertEqual(summary.currentDays, 1)
        XCTAssertEqual(summary.bestDays, 1)
    }

    func testLegacyStreakMilestoneAndUnknownPrefixAreUnchanged() {
        let summary = TokenUsageStreakCalculator.summary(from: records(offsets: [-2, -1, 0]), now: now, calendar: calendar)
        XCTAssertEqual(summary.recentDays.first?.state, .unknown)
        XCTAssertEqual(summary.earnedBadge, .spark)
        XCTAssertEqual(summary.previousBadge, .firstPrompt)
        XCTAssertEqual(summary.nextBadge, .loop)
        XCTAssertEqual(summary.daysUntilNextBadge, 4)
    }

    func testObservedOnlyDoesNotMarkUnknownDaysInactiveOrBridgeGaps() {
        let summary = TokenUsageStreakCalculator.summary(from: records(offsets: [-4, -3, -1, 0]),
            now: now, calendar: calendar, coverage: .observedOnly)
        XCTAssertEqual(summary.recentDays[4].state, .unknown)
        XCTAssertEqual(summary.currentDays, 2)
        XCTAssertEqual(summary.bestDays, 2)
        XCTAssertFalse(summary.recentDays.contains { $0.state == .inactive })
        XCTAssertEqual(summary.nextBadge, .spark)
    }

    func testObservedOnlyDoesNotExtendYesterdayThroughUnknownToday() {
        let summary = TokenUsageStreakCalculator.summary(from: records(offsets: [-3, -2, -1]),
            now: now, calendar: calendar, coverage: .observedOnly)
        let snapshot = GrokBuildContinuitySnapshot(summary: summary)
        XCTAssertNil(snapshot.currentDays)
        XCTAssertEqual(snapshot.bestDays, 3)
        XCTAssertEqual(summary.recentDays.last?.state, .unknown)
    }

    func testInitialImportIsLimitedToThirtyDaysAndUnlocksWithoutCelebration() {
        var ledger = emptyActivity()
        observe(&ledger, offsets: Array(-40...0), at: now)
        let summary = ledger.snapshot(at: now, calendar: calendar).summary
        XCTAssertEqual(ledger.witnesses.count, 30)
        XCTAssertEqual(summary.currentDays, 30)
        XCTAssertEqual(summary.earnedBadge, .flow)
        XCTAssertNil(ledger.claimCelebration(at: now, calendar: calendar))
    }

    func testRepeatedObservationAndTurnRevisionUseStableIdentity() {
        var ledger = emptyActivity()
        observe(&ledger, offsets: [-1], at: now)
        observe(&ledger, offsets: [-1], at: now)
        XCTAssertEqual(ledger.witnesses.count, 1)
        // Revise the same turn from yesterday to today, not append a new event.
        ledger.recordAccepted(usage(dates: [now]), lineage: lineage(), at: now, calendar: calendar)
        ledger.finishObservation(at: now, calendar: calendar)
        XCTAssertEqual(ledger.witnesses.count, 1)
        let summary = ledger.snapshot(at: now, calendar: calendar).summary
        XCTAssertEqual(summary.recentDays[5].state, .unknown)
        XCTAssertEqual(summary.recentDays[6].state, .active)
        XCTAssertEqual(summary.bestDays, 1)
    }

    func testBadgeSurvivesARevisionThatShortensTheCurrentRecordedRun() {
        var ledger = emptyActivity()
        observe(&ledger, offsets: [-2, -1, 0], at: now)
        ledger.recordAccepted(usage(dates: [now, now, now]), lineage: lineage(), at: now, calendar: calendar)
        ledger.finishObservation(at: now, calendar: calendar)
        let summary = ledger.snapshot(at: now, calendar: calendar).summary
        XCTAssertEqual(summary.currentDays, 1)
        XCTAssertEqual(summary.bestDays, 3)
        XCTAssertEqual(summary.earnedBadge, .spark)
    }

    func testActivityAndBadgesSurviveDetailedCacheExpiration() throws {
        var history = GrokBuildHistoryLedger(home: home)
        let session = usage(dates: (-6...0).map(day))
        _ = history.ingest(session, lineage: lineage(), observedAt: now, calendar: calendar)
        var cache = GrokBuildHistoryCache(home: home)
        cache.ledger = history
        cache.activity = .importing(history, at: now, calendar: calendar)
        let later = calendar.date(byAdding: .day, value: 90, to: now)!
        cache.ledger.prune(now: later, calendar: calendar)
        XCTAssertTrue(cache.ledger.sessions.isEmpty)
        let restored = try JSONDecoder().decode(GrokBuildHistoryCache.self, from: JSONEncoder().encode(cache))
        XCTAssertEqual(restored.activity?.witnesses.count, 7)
        XCTAssertEqual(restored.activity?.snapshot(at: later, calendar: calendar).summary.earnedBadge, .loop)
        XCTAssertNil(restored.activity?.snapshot(at: later, calendar: calendar).currentDays)
    }

    func testNewActivityCelebratesOnceAndClaimSurvivesRestart() throws {
        var ledger = emptyActivity()
        observe(&ledger, offsets: [], at: now)
        let later = now.addingTimeInterval(30)
        observe(&ledger, dates: [later], at: later)
        let first = try XCTUnwrap(ledger.claimCelebration(at: later, calendar: calendar))
        XCTAssertTrue(first.id.hasPrefix("grokBuild|"))
        XCTAssertEqual(first.summary.currentDays, 1)
        XCTAssertNil(ledger.claimCelebration(at: later, calendar: calendar))
        var restored = try JSONDecoder().decode(GrokBuildActivityLedger.self, from: JSONEncoder().encode(ledger))
        observe(&restored, dates: [later], at: later.addingTimeInterval(30))
        XCTAssertNil(restored.claimCelebration(at: later, calendar: calendar))
    }

    func testDelayedInitialBackfillNeverCreatesOldCelebrations() {
        var ledger = emptyActivity()
        // A bounded first scan can have no eligible rows yet.
        observe(&ledger, offsets: [], at: now)
        observe(&ledger, dates: [now.addingTimeInterval(-60)], at: now.addingTimeInterval(30))
        XCTAssertEqual(ledger.snapshot(at: now, calendar: calendar).summary.earnedBadge, .firstPrompt)
        XCTAssertNil(ledger.claimCelebration(at: now.addingTimeInterval(30), calendar: calendar))
    }

    func testFirstImportDoesNotCelebrateEvenIfSetupStartedEarlier() {
        var ledger = emptyActivity()
        ledger.beginObservation(at: now, calendar: calendar)
        let later = now.addingTimeInterval(30)
        ledger.recordAccepted(usage(dates: [later]), lineage: lineage(), at: later, calendar: calendar)
        ledger.finishObservation(at: later, calendar: calendar)
        XCTAssertEqual(ledger.snapshot(at: later, calendar: calendar).currentDays, 1)
        XCTAssertNil(ledger.claimCelebration(at: later, calendar: calendar))
    }

    func testTimezoneRebucketsUTCWitnessesWithoutReplayingPendingCelebration() {
        var ledger = emptyActivity()
        observe(&ledger, offsets: [], at: now)
        let later = now.addingTimeInterval(30)
        observe(&ledger, dates: [later], at: later)
        var eastern = calendar
        eastern.timeZone = TimeZone(secondsFromGMT: 14 * 3_600)!
        ledger.beginObservation(at: later, calendar: eastern)
        ledger.finishObservation(at: later, calendar: eastern)
        XCTAssertEqual(ledger.snapshot(at: later, calendar: eastern).currentDays, 1)
        XCTAssertNil(ledger.claimCelebration(at: later, calendar: eastern))
        ledger.beginObservation(at: later, calendar: calendar)
        XCTAssertNil(ledger.claimCelebration(at: later, calendar: calendar))
    }

    func testTimezoneCanChangeContinuityButDoesNotEraseEarnedBadge() {
        let dates = ["2026-09-14T23:30:00Z", "2026-09-15T01:00:00Z", "2026-09-16T01:00:00Z"].map { GrokBuildDates.parse($0)! }
        var ledger = emptyActivity()
        observe(&ledger, dates: dates, at: now)
        XCTAssertEqual(ledger.snapshot(at: now, calendar: calendar).summary.bestDays, 3)
        var shifted = calendar
        shifted.timeZone = TimeZone(secondsFromGMT: 7 * 3_600)!
        ledger.beginObservation(at: now, calendar: shifted)
        ledger.finishObservation(at: now, calendar: shifted)
        let summary = ledger.snapshot(at: now, calendar: shifted).summary
        XCTAssertEqual(summary.currentDays, 2)
        XCTAssertEqual(summary.earnedBadge, .spark)
        XCTAssertEqual(summary.bestDays, 3)
        XCTAssertNil(ledger.claimCelebration(at: now, calendar: shifted))
    }

    func testZeroFutureAndExcludedSourcesCannotUnlockBadges() {
        var ledger = emptyActivity()
        ledger.beginObservation(at: now, calendar: calendar)
        ledger.recordAccepted(usage(dates: [now], tokens: 0), lineage: lineage(), at: now, calendar: calendar)
        ledger.recordAccepted(usage(dates: [now.addingTimeInterval(60)]), lineage: lineage(), at: now, calendar: calendar)
        ledger.recordAccepted(usage(dates: [now]), lineage: lineage(parent: UUID().uuidString), at: now, calendar: calendar)
        ledger.finishObservation(at: now, calendar: calendar)
        XCTAssertTrue(ledger.witnesses.isEmpty)
        XCTAssertNil(ledger.snapshot(at: now, calendar: calendar).summary.earnedBadge)
    }

    func testMinimalDurableLedgerOmitsTokenAndModelDetailsAndRawIdentity() throws {
        var ledger = emptyActivity()
        observe(&ledger, offsets: [-1, 0], at: now)
        let string = String(decoding: try JSONEncoder().encode(ledger), as: UTF8.self)
        for forbidden in ["tokens", "models", "input", "output", id.uuidString.lowercased(), home.path] {
            XCTAssertFalse(string.contains(forbidden), forbidden)
        }
    }

    func testActivityNamespacesAndCelebrationIDsSeparateHomes() throws {
        var one = emptyActivity()
        var two = GrokBuildActivityLedger(namespace: GrokBuildHistoryLedger(home: URL(fileURLWithPath: "/second-home")).namespace)
        observe(&one, offsets: [], at: now)
        observe(&two, offsets: [], at: now)
        let later = now.addingTimeInterval(30)
        observe(&one, dates: [later], at: later)
        observe(&two, dates: [later], at: later)
        XCTAssertNotEqual(one.witnesses.keys.first, two.witnesses.keys.first)
        let first = try XCTUnwrap(one.claimCelebration(at: later, calendar: calendar))
        let second = try XCTUnwrap(two.claimCelebration(at: later, calendar: calendar))
        XCTAssertNotEqual(first.id, second.id)
    }

    func testEarlierExperimentalCacheCanImportActivityWithoutCelebratingOrDuplicating() throws {
        var cache = GrokBuildHistoryCache(home: home)
        _ = cache.ledger.ingest(usage(dates: [-1, 0].map(day)), lineage: lineage(), observedAt: now, calendar: calendar)
        XCTAssertNil(cache.activity)
        let decoded = try JSONDecoder().decode(GrokBuildHistoryCache.self, from: JSONEncoder().encode(cache))
        var ledger = GrokBuildActivityLedger.importing(decoded.ledger, at: now, calendar: calendar)
        XCTAssertEqual(ledger.witnesses.count, 2)
        observe(&ledger, offsets: [-1, 0], at: now)
        XCTAssertEqual(ledger.witnesses.count, 2)
        XCTAssertNil(ledger.claimCelebration(at: now, calendar: calendar))
    }

    func testTenYearActivitySurvivesDiskRestartsPruningAndTimezoneChanges() throws {
        let directory = try retentionDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        var cache = try retainedHistory(days: 3_650, turnsPerDay: 1, repository: repository)
        XCTAssertEqual(cache.ledger.sessions.values.reduce(0) { $0 + $1.turns.count }, 30)
        XCTAssertEqual(cache.activity?.witnesses.count, 3_650)
        XCTAssertEqual(cache.activity?.snapshot(at: now, calendar: calendar).currentDays, 3_650)
        let earned = try XCTUnwrap(cache.activity?.snapshot(at: now, calendar: calendar).summary.earnedBadge)
        let claims = cache.activity?.celebratedDays

        // After all detailed source records expire, only durable witnesses and
        // claims remain. Restart must not require the original source files.
        let later = day(90)
        cache.ledger.prune(now: later, calendar: calendar)
        XCTAssertTrue(cache.ledger.sessions.isEmpty)
        for zone in ["America/Los_Angeles", "Asia/Kathmandu", "Pacific/Kiritimati", "Etc/GMT+12", "UTC"] {
            var shifted = calendar
            shifted.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            cache.activity?.reproject(at: later, calendar: shifted)
            try repository.save(cache)
            cache = try XCTUnwrap(repository.load(home: home))
            let summary = try XCTUnwrap(cache.activity?.snapshot(at: later, calendar: shifted))
            XCTAssertNil(summary.currentDays, zone)
            XCTAssertEqual(summary.bestDays, 3_650, zone)
            XCTAssertEqual(summary.summary.earnedBadge, earned, zone)
            XCTAssertEqual(cache.activity?.witnesses.count, 3_650)
            XCTAssertEqual(cache.activity?.celebratedDays, claims)
            XCTAssertNil(cache.activity?.claimCelebration(at: later, calendar: shifted))
            XCTAssertTrue(cache.ledger.snapshot(now: later, calendar: shifted).days.allSatisfy { $0.tokens == nil })
        }
        let encoded = String(decoding: try JSONEncoder().encode(cache), as: UTF8.self)
        for forbidden in ["models", "input", "output", "synthetic-retention-model", home.path] {
            XCTAssertFalse(encoded.contains(forbidden), "Expired detail must not remain in the durable cache: \(forbidden)")
        }
        XCTAssertNil(try repository.load(home: URL(fileURLWithPath: "/unrelated-retention-home")))
    }

    func testDelayedRevisionUpdatesDurableWitnessAfterDetailExpired() throws {
        var cache = GrokBuildHistoryCache(home: home)
        let original = usage(dates: (-6...0).map(day))
        XCTAssertEqual(cache.ledger.ingest(original, lineage: lineage(), observedAt: now, calendar: calendar), .accepted)
        cache.activity = .importing(cache.ledger, at: now, calendar: calendar)
        let later = day(180)
        cache.ledger.prune(now: later, calendar: calendar)
        XCTAssertTrue(cache.ledger.sessions.isEmpty)

        let revision = usage(dates: (-6..<0).map(day) + [later], tokens: 200)
        cache.activity?.beginObservation(at: later, calendar: calendar)
        XCTAssertEqual(cache.ledger.ingest(revision, lineage: lineage(), observedAt: later, calendar: calendar), .accepted)
        cache.activity?.recordAccepted(revision, lineage: lineage(), at: later, calendar: calendar)
        cache.activity?.finishObservation(at: later, calendar: calendar)
        XCTAssertEqual(cache.activity?.witnesses.count, 7, "Same old session/turn identity is revised, not appended")
        XCTAssertFalse(cache.activity?.witnesses.values.contains(now) == true)
        XCTAssertTrue(cache.activity?.witnesses.values.contains(later) == true)
        let continuity = try XCTUnwrap(cache.activity?.snapshot(at: later, calendar: calendar))
        XCTAssertEqual(continuity.currentDays, 1, "Unknown gap cannot join the old run")
        XCTAssertEqual(continuity.bestDays, 7)
        XCTAssertEqual(continuity.summary.earnedBadge, .loop)
        XCTAssertEqual(cache.ledger.snapshot(now: later, calendar: calendar).days.last?.tokens, 200)
        XCTAssertNotNil(cache.activity?.claimCelebration(at: later, calendar: calendar))

        let directory = try retentionDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        try repository.save(cache)
        var restarted = try XCTUnwrap(repository.load(home: home))
        restarted.activity?.recordAccepted(revision, lineage: lineage(), at: later, calendar: calendar)
        restarted.activity?.finishObservation(at: later, calendar: calendar)
        XCTAssertNil(restarted.activity?.claimCelebration(at: later, calendar: calendar))
        XCTAssertEqual(restarted.activity?.witnesses.count, 7)
        XCTAssertEqual(restarted.activity?.snapshot(at: later, calendar: calendar), continuity)
    }

    func testCacheSizeFailurePreservesSavedBadgeAndAllowsLaterRecovery() throws {
        let directory = try retentionDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        var cache = try retainedHistory(days: 7, turnsPerDay: 1, repository: repository)
        try repository.save(cache)
        let saved = try XCTUnwrap(repository.load(home: home))
        // Deliberately oversized synthetic metadata exercises the encoded-size
        // guard, not an assertion that a real fingerprint has this shape.
        cache.fingerprints[GrokBuildHistoryLedger.digest("oversized-fixture")] =
            String(repeating: "x", count: GrokBuildHistoryCacheRepository.maximumBytes)
        XCTAssertThrowsError(try repository.save(cache)) { error in
            XCTAssertEqual(error as? GrokBuildError, .cacheUnavailable)
        }
        XCTAssertEqual(try repository.load(home: home), saved)
        XCTAssertEqual(saved.activity?.snapshot(at: now, calendar: calendar).summary.earnedBadge, .loop)
        cache.fingerprints.removeAll()
        try repository.save(cache)
        XCTAssertEqual(try repository.load(home: home), cache)
    }

    func testLargeDurableActivityRetentionStress() throws {
        guard ProcessInfo.processInfo.environment["GROK_RUN_RETENTION_STRESS"] == "1" else {
            throw XCTSkip("Opt-in synthetic retention stress; no real CLI or home is used")
        }
        let directory = try retentionDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = GrokBuildHistoryCacheRepository(directory: directory)
        let started = ProcessInfo.processInfo.systemUptime
        let cache = try retainedHistory(days: 1_095, turnsPerDay: 100, repository: repository)
        let generated = ProcessInfo.processInfo.systemUptime
        try repository.save(cache)
        let saved = ProcessInfo.processInfo.systemUptime
        let restarted = try XCTUnwrap(repository.load(home: home))
        let loaded = ProcessInfo.processInfo.systemUptime
        let snapshot = try XCTUnwrap(restarted.activity?.snapshot(at: now, calendar: calendar))
        let projected = ProcessInfo.processInfo.systemUptime
        let url = directory.appendingPathComponent(cache.ledger.namespace + ".json")
        let bytes = try XCTUnwrap(url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        XCTAssertEqual(restarted, cache)
        XCTAssertEqual(restarted.activity?.witnesses.count, 109_500)
        XCTAssertEqual(restarted.ledger.sessions.values.reduce(0) { $0 + $1.turns.count }, 3_000)
        XCTAssertEqual(snapshot.currentDays, 1_095)
        XCTAssertEqual(snapshot.bestDays, 1_095)
        XCTAssertLessThan(bytes, GrokBuildHistoryCacheRepository.maximumBytes)
        print("GROK_RETENTION_STRESS days=1095 witnesses=109500 recentTurns=3000 bytes=\(bytes) generateSeconds=\(generated - started) saveSeconds=\(saved - generated) loadSeconds=\(loaded - saved) snapshotSeconds=\(projected - loaded)")
    }

    func testDayDeduplicationMatchesPerTurnProjectionAcrossDSTAndClockRollback() throws {
        // Spring/fall transitions, leap day, and Samoa's skipped local date.
        for text in ["2026-03-08T12:00:00Z", "2025-11-02T12:00:00Z",
                     "2024-02-29T12:00:00Z", "2011-12-30T12:00:00Z"] {
            let center = try XCTUnwrap(GrokBuildDates.parse(text))
            let dates = (-72...72).map { center.addingTimeInterval(Double($0) * 1_800) }
            let observedAt = try XCTUnwrap(dates.last)
            var activity = emptyActivity()
            observe(&activity, dates: dates, at: observedAt)
            for zone in ["America/Los_Angeles", "America/New_York", "Australia/Lord_Howe",
                         "Pacific/Apia", "Asia/Kathmandu", "Pacific/Kiritimati", "Etc/GMT+12", "UTC"] {
                var shifted = calendar
                shifted.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
                for delta in [0.0, -3_600, -86_400, -172_800] {
                    let instant = observedAt.addingTimeInterval(delta)
                    let reference = Set(activity.witnesses.values.filter { $0 <= instant }.map {
                        TokenUsageCalendarDay.containing($0, calendar: shifted).index
                    })
                    let expected = TokenUsageStreakCalculator.summary(activeDayIndices: reference,
                        now: instant, calendar: shifted, coverage: .observedOnly,
                        retainedBestDays: activity.bestVerifiedDays)
                    XCTAssertEqual(activity.snapshot(at: instant, calendar: shifted).summary, expected,
                        "\(text) \(zone) rollback=\(delta)")
                }
            }
        }
    }

    /// Each batch is a real 30-day-eligible observation at its own synthetic
    /// clock time. This is accumulation across many observations, not a single
    /// import that bypasses the 30-day backfill rule. Disk restarts occur every
    /// 360 days and at the end; all paths and data are task-owned fixtures.
    private func retainedHistory(days: Int, turnsPerDay: Int,
                                 repository: GrokBuildHistoryCacheRepository) throws -> GrokBuildHistoryCache {
        var cache = GrokBuildHistoryCache(home: home)
        var activity = GrokBuildActivityLedger(namespace: cache.ledger.namespace)
        let counts = GrokBuildTokenCounts(input: 100, output: 0, total: 100,
            cacheRead: nil, cacheWrite: nil, reasoning: nil)
        for first in stride(from: 0, to: days, by: 30) {
            let last = min(first + 29, days - 1)
            let instant = day(last - days + 1)
            let sessionID = UUID()
            let source = GrokBuildLineage(info: .init(id: sessionID), parentSessionID: nil,
                forkedAt: nil, sessionKind: nil, forkContextSource: nil)
            var turns: [GrokBuildRecordedTurn] = []
            for offset in first...last {
                let date = day(offset - days + 1)
                for index in 0..<turnsPerDay {
                    let number = UInt32((offset - first) * turnsPerDay + index + 1)
                    let turn = GrokBuildRecordedTurn(number: number,
                        recordedAt: date.addingTimeInterval(-Double(index)), tokens: counts,
                        models: ["synthetic-retention-model": counts], upstreamIncomplete: false)
                    turns.append(turn)
                }
            }
            let total = Int64(turns.count) * 100
            let usage = GrokBuildSessionUsage(id: sessionID, sourceUpdatedAt: instant,
                total: .init(input: total, output: 0, total: total, cacheRead: nil, cacheWrite: nil, reasoning: nil), turns: turns)
            activity.beginObservation(at: instant, calendar: calendar)
            XCTAssertEqual(cache.ledger.ingest(usage, lineage: source, observedAt: instant, calendar: calendar), .accepted)
            activity.recordAccepted(usage, lineage: source, at: instant, calendar: calendar)
            activity.finishObservation(at: instant, calendar: calendar)
            XCTAssertEqual(activity.witnesses.count, (last + 1) * turnsPerDay)
            let celebration = activity.claimCelebration(at: instant, calendar: calendar)
            if first == 0 { XCTAssertNil(celebration, "Initial backfill never celebrates") }
            else { XCTAssertNotNil(celebration, "Only this observation's current day can celebrate") }
            XCTAssertNil(activity.claimCelebration(at: instant, calendar: calendar))
            cache.activity = activity
            cache.collectedAt = instant
            if (last + 1).isMultiple(of: 360) || last == days - 1 {
                try repository.save(cache)
                cache = try XCTUnwrap(repository.load(home: home))
                activity = try XCTUnwrap(cache.activity)
                XCTAssertNil(activity.claimCelebration(at: instant, calendar: calendar))
            }
        }
        XCTAssertEqual(cache.activity?.celebratedDays.count, (days + 29) / 30 - 1,
            "One current-day claim per later batch; no bulk historical celebrations")
        return cache
    }

    private func retentionDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grok-retention-\(UUID())").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private let home = URL(fileURLWithPath: "/synthetic-grok-home")
    private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private func emptyActivity() -> GrokBuildActivityLedger { .init(namespace: GrokBuildHistoryLedger(home: home).namespace) }
    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now)! }
    private func lineage(parent: String? = nil) -> GrokBuildLineage {
        .init(info: .init(id: id), parentSessionID: parent, forkedAt: nil, sessionKind: nil, forkContextSource: nil)
    }
    private func observe(_ ledger: inout GrokBuildActivityLedger, offsets: [Int], at date: Date) {
        observe(&ledger, dates: offsets.map(day), at: date)
    }
    private func observe(_ ledger: inout GrokBuildActivityLedger, dates: [Date], at date: Date) {
        ledger.beginObservation(at: date, calendar: calendar)
        ledger.recordAccepted(usage(dates: dates), lineage: lineage(), at: date, calendar: calendar)
        ledger.finishObservation(at: date, calendar: calendar)
    }
    private func usage(dates: [Date], tokens: Int64 = 100) -> GrokBuildSessionUsage {
        let total = Int64(dates.count) * tokens
        return .init(id: id, sourceUpdatedAt: dates.max() ?? now,
            total: .init(input: total, output: 0, total: total, cacheRead: nil, cacheWrite: nil, reasoning: nil),
            turns: dates.enumerated().map { offset, date in
                .init(number: UInt32(offset + 1), recordedAt: date,
                      tokens: .init(input: tokens, output: 0, total: tokens, cacheRead: nil, cacheWrite: nil, reasoning: nil),
                      models: [:], upstreamIncomplete: false)
            })
    }

    private func records(offsets: [Int]) -> [TokenUsageStreakRecordValue] {
        offsets.map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let day = TokenUsageCalendarDay.containing(date, calendar: calendar)
            return .init(identifier: "codex|\(day.key)", provider: .codex, dayKey: day.key,
                         dayIndex: day.index, tokenCount: 100, firstObservedAt: date, lastObservedAt: date)
        }
    }
}
