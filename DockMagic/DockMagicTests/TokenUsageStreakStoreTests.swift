import Foundation
import SwiftData
import XCTest
@testable import DockMagic

final class TokenUsageStreakStoreTests: XCTestCase {
    @MainActor
    func testObservationCreatesOnePersistentRecordPerProviderAndDay() {
        let container = TokenUsageStreakStore.inMemoryContainer()
        let store = TokenUsageStreakStore(modelContainer: container)
        let calendar = testCalendar
        let now = date(year: 2026, month: 8, day: 30, hour: 18)

        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 120, at: now),
            at: now,
            calendar: calendar
        )
        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 240, at: now),
            at: now,
            calendar: calendar
        )
        _ = store.observeToday(
            provider: .claudeCode,
            tokenUsage: usage(tokens: 80, at: now),
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(
            store.records.first { $0.provider == .codex }?.tokenCount,
            240
        )
        XCTAssertEqual(
            store.summary(for: .codex, at: now, calendar: calendar).currentDays,
            1
        )
        XCTAssertEqual(
            store.summary(for: .claudeCode, at: now, calendar: calendar).currentDays,
            1
        )

        let reloaded = TokenUsageStreakStore(modelContainer: container)
        XCTAssertEqual(reloaded.records.count, 2)
        XCTAssertEqual(
            reloaded.summary(for: .codex, at: now, calendar: calendar).bestDays,
            1
        )
    }

    @MainActor
    func testObservationOnlyCountsTodayAndDoesNotBackfillProviderHistory() {
        let store = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let calendar = testCalendar
        let now = date(year: 2026, month: 8, day: 30, hour: 18)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let providerHistory = CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: 900,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(
                    startDate: yesterday,
                    tokens: 900
                ),
                CodexTokenUsageDailyBucket(startDate: now, tokens: 0)
            ]
        )

        let pending = store.observeToday(
            provider: .codex,
            tokenUsage: providerHistory,
            at: now,
            calendar: calendar
        )

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(pending.currentDays, 0)
        XCTAssertEqual(pending.recentDays.last?.state, .todayPending)

        let active = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 1, at: now),
            at: now,
            calendar: calendar
        )
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(active.currentDays, 1)
        XCTAssertEqual(active.bestDays, 1)
    }

    @MainActor
    func testCelebrationCanBeClaimedOncePerProviderAndActiveDay() {
        let container = TokenUsageStreakStore.inMemoryContainer()
        let store = TokenUsageStreakStore(modelContainer: container)
        let calendar = testCalendar
        let now = date(year: 2026, month: 8, day: 30, hour: 18)

        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 120, at: now),
            at: now,
            calendar: calendar
        )
        _ = store.observeToday(
            provider: .claudeCode,
            tokenUsage: usage(tokens: 80, at: now),
            at: now,
            calendar: calendar
        )

        let codexCelebration = store.claimCelebration(
            for: .codex,
            at: now,
            calendar: calendar
        )
        XCTAssertEqual(codexCelebration?.provider, .codex)
        XCTAssertEqual(codexCelebration?.summary.currentDays, 1)
        XCTAssertEqual(codexCelebration?.summary.earnedBadge, .firstPrompt)
        XCTAssertNil(
            store.claimCelebration(
                for: .codex,
                at: now,
                calendar: calendar
            )
        )

        XCTAssertEqual(
            store.claimCelebration(
                for: .claudeCode,
                at: now,
                calendar: calendar
            )?.provider,
            .claudeCode
        )

        let reloaded = TokenUsageStreakStore(modelContainer: container)
        XCTAssertNil(
            reloaded.claimCelebration(
                for: .codex,
                at: now,
                calendar: calendar
            ),
            "The celebration claim must survive a SwiftData reload."
        )
    }

    @MainActor
    func testCelebrationWaitsForUsageAndBecomesAvailableAgainNextDay() {
        let store = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let calendar = testCalendar
        let firstDay = date(year: 2026, month: 8, day: 30, hour: 18)
        let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: firstDay
        )!

        XCTAssertNil(
            store.claimCelebration(
                for: .codex,
                at: firstDay,
                calendar: calendar
            )
        )

        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 120, at: firstDay),
            at: firstDay,
            calendar: calendar
        )
        XCTAssertNotNil(
            store.claimCelebration(
                for: .codex,
                at: firstDay,
                calendar: calendar
            )
        )

        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 240, at: nextDay),
            at: nextDay,
            calendar: calendar
        )
        let nextCelebration = store.claimCelebration(
            for: .codex,
            at: nextDay,
            calendar: calendar
        )
        XCTAssertEqual(nextCelebration?.summary.currentDays, 2)
        XCTAssertEqual(nextCelebration?.dayKey, "2026-08-31")
    }

    @MainActor
    func testCelebrationClaimRemainsConsumedAfterLaterTokenRefresh() {
        let store = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let calendar = testCalendar
        let firstObservation = date(
            year: 2026,
            month: 8,
            day: 30,
            hour: 9
        )
        let laterObservation = date(
            year: 2026,
            month: 8,
            day: 30,
            hour: 22
        )

        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 120, at: firstObservation),
            at: firstObservation,
            calendar: calendar
        )
        let firstClaim = store.claimCelebration(
            for: .codex,
            at: firstObservation,
            calendar: calendar
        )
        XCTAssertNotNil(firstClaim)

        _ = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 980, at: laterObservation),
            at: laterObservation,
            calendar: calendar
        )

        XCTAssertNil(
            store.claimCelebration(
                for: .codex,
                at: laterObservation,
                calendar: calendar
            ),
            "Refreshing a claimed day must not show the celebration twice."
        )
        XCTAssertEqual(store.records.first?.tokenCount, 980)
        XCTAssertEqual(
            store.records.first?.celebrationShownAt,
            firstClaim?.presentedAt
        )
    }

    @MainActor
    func testLocalMidnightCreatesNewDayAndExtendsStreak() {
        let store = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let calendar = testCalendar
        let beforeMidnight = date(
            year: 2026,
            month: 8,
            day: 30,
            hour: 23,
            minute: 59
        )
        let afterMidnight = date(
            year: 2026,
            month: 8,
            day: 31,
            hour: 0,
            minute: 1
        )

        _ = store.observeToday(
            provider: .claudeCode,
            tokenUsage: usage(tokens: 50, at: beforeMidnight),
            at: beforeMidnight,
            calendar: calendar
        )
        XCTAssertEqual(
            store.claimCelebration(
                for: .claudeCode,
                at: beforeMidnight,
                calendar: calendar
            )?.dayKey,
            "2026-08-30"
        )

        _ = store.observeToday(
            provider: .claudeCode,
            tokenUsage: usage(tokens: 75, at: afterMidnight),
            at: afterMidnight,
            calendar: calendar
        )
        let nextDayClaim = store.claimCelebration(
            for: .claudeCode,
            at: afterMidnight,
            calendar: calendar
        )

        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(nextDayClaim?.dayKey, "2026-08-31")
        XCTAssertEqual(nextDayClaim?.summary.currentDays, 2)
    }

    @MainActor
    func testMissedDayResetsCurrentRunButKeepsBestAndBadges() {
        let store = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let calendar = testCalendar
        let firstDay = date(year: 2026, month: 8, day: 1, hour: 18)

        for offset in 0..<3 {
            let observedAt = calendar.date(
                byAdding: .day,
                value: offset,
                to: firstDay
            )!
            _ = store.observeToday(
                provider: .codex,
                tokenUsage: usage(tokens: 50, at: observedAt),
                at: observedAt,
                calendar: calendar
            )
        }

        let pendingDay = calendar.date(
            byAdding: .day,
            value: 3,
            to: firstDay
        )!
        XCTAssertEqual(
            store.summary(
                for: .codex,
                at: pendingDay,
                calendar: calendar
            ).currentDays,
            3,
            "A streak remains alive until the current local day ends."
        )

        let dayAfterMiss = calendar.date(
            byAdding: .day,
            value: 4,
            to: firstDay
        )!
        let reset = store.summary(
            for: .codex,
            at: dayAfterMiss,
            calendar: calendar
        )
        XCTAssertEqual(reset.currentDays, 0)
        XCTAssertEqual(reset.bestDays, 3)
        XCTAssertEqual(reset.earnedBadge, .spark)

        let restarted = store.observeToday(
            provider: .codex,
            tokenUsage: usage(tokens: 75, at: dayAfterMiss),
            at: dayAfterMiss,
            calendar: calendar
        )
        XCTAssertEqual(restarted.currentDays, 1)
        XCTAssertEqual(restarted.bestDays, 3)
        XCTAssertEqual(restarted.earnedBadge, .spark)
    }

    @MainActor
    func testCodexUsageStoreAttachesDockMagicOwnedSummary() async {
        let now = date(year: 2026, month: 8, day: 30, hour: 18)
        let streakStore = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let snapshot = CodexRateLimitSnapshot(
            planType: "pro",
            limitID: "codex",
            fiveHour: CodexRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 10,
                windowDurationMinutes: 300,
                resetsAt: nil
            ),
            weekly: nil,
            tokenUsage: usage(tokens: 100, at: now),
            fetchedAt: now
        )
        let usageStore = CodexUsageStore(
            provider: FixedCodexProvider(snapshot: snapshot),
            locator: FixedCodexLocator(),
            streakTracker: streakStore,
            pollingInterval: .seconds(60),
            now: { now }
        )

        await usageStore.refresh()

        XCTAssertEqual(usageStore.state.snapshot?.streakSummary?.currentDays, 1)
        XCTAssertEqual(usageStore.state.snapshot?.streakSummary?.bestDays, 1)
        XCTAssertEqual(streakStore.records.count, 1)
        XCTAssertEqual(streakStore.records.first?.provider, .codex)
        XCTAssertNil(streakStore.persistenceErrorDescription)
    }

    @MainActor
    func testClaudeCodeUsageStoreUsesItsOwnDockMagicLedger() async {
        let now = date(year: 2026, month: 8, day: 30, hour: 18)
        let streakStore = TokenUsageStreakStore(
            modelContainer: TokenUsageStreakStore.inMemoryContainer()
        )
        let snapshot = ClaudeCodeRateLimitSnapshot(
            planType: nil,
            limitID: "claude-code-local",
            fiveHour: ClaudeCodeRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 20,
                windowDurationMinutes: 300,
                resetsAt: nil
            ),
            weekly: nil,
            tokenUsage: usage(tokens: 250, at: now),
            fetchedAt: now
        )
        let usageStore = ClaudeCodeUsageStore(
            provider: FixedClaudeCodeProvider(snapshot: snapshot),
            bridge: AlwaysInstalledClaudeCodeBridge(),
            streakTracker: streakStore,
            pollingInterval: .seconds(60),
            now: { now }
        )

        await usageStore.refresh()

        XCTAssertEqual(usageStore.state.snapshot?.streakSummary?.currentDays, 1)
        XCTAssertEqual(usageStore.state.snapshot?.streakSummary?.bestDays, 1)
        XCTAssertEqual(streakStore.records.count, 1)
        XCTAssertEqual(streakStore.records.first?.provider, .claudeCode)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        testCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func usage(tokens: Int64, at date: Date) -> CodexAccountTokenUsage {
        CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: tokens,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(startDate: date, tokens: tokens)
            ]
        )
    }
}

private struct FixedCodexProvider: CodexRateLimitProviding {
    let snapshot: CodexRateLimitSnapshot

    func fetchRateLimits(
        executableURL: URL
    ) async throws -> CodexRateLimitSnapshot {
        snapshot
    }
}

private struct FixedCodexLocator: CodexExecutableLocating {
    func locate(overridePath: String?) throws -> URL {
        URL(fileURLWithPath: "/usr/bin/true")
    }
}

private struct FixedClaudeCodeProvider: ClaudeCodeRateLimitProviding {
    let snapshot: ClaudeCodeRateLimitSnapshot

    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot {
        snapshot
    }
}

@MainActor
private struct AlwaysInstalledClaudeCodeBridge: ClaudeCodeStatusLineBridging {
    let snapshotURL = URL(fileURLWithPath: "/tmp/dockmagic-test-usage.json")

    func isInstalled() -> Bool { true }
    func install() throws {}
    func uninstall() throws {}
}
