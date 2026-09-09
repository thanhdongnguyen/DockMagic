import AppKit
import CoreImage
import SwiftUI
import XCTest
@testable import DockMagic

final class AntigravityFeatureTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_886_000)

    func testSummaryKeepsFourWindowsAndSelectsConstrainedFamily() throws {
        let value = try XCTUnwrap(AntigravityQuotaParser.parse(summary(), source: "fixture", now: now))
        XCTAssertEqual(value.groups.count, 2)
        XCTAssertEqual(value.groups.flatMap(\.buckets).count, 4)
        XCTAssertEqual(value.selectedGroup("auto")?.id, "gemini")
        XCTAssertEqual(value.selectedGroup("claude-gpt")?.title, "Claude and GPT models")
        XCTAssertNil(value.selectedGroup("missing"))
        let windows = try XCTUnwrap(value.selectedGroup("gemini")?.buckets)
        XCTAssertEqual(windows.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(windows[0].remainingFraction, 0.25)
        XCTAssertEqual(windows[1].normalizedWindow?.windowDurationMinutes, 10_080)
    }

    @MainActor
    func testHiddenGeminiPreferenceCannotMaskConsumedWeeklyQuota() throws {
        let suite = "Antigravity-quota-migration-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("gemini", forKey: DockPreferencesStore.antigravityGroupKey)
        let preferences = DockPreferencesStore(defaults: defaults)
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(["groups": [
            ["displayName": "Gemini Models", "buckets": [
                ["bucketId": "gemini-weekly", "remainingFraction": 1.0]]],
            ["displayName": "Claude and GPT models", "buckets": [
                ["bucketId": "3p-weekly", "remainingFraction": 0.310612]]]
        ]], source: "fixture", now: now))
        let selected = try XCTUnwrap(quota.selectedGroup(preferences.antigravityGroupID))
        XCTAssertEqual(selected.id, "claude-gpt")
        XCTAssertEqual(try XCTUnwrap(selected.buckets.first?.remainingFraction), 0.310612, accuracy: 0.000001)
        XCTAssertNil(defaults.string(forKey: DockPreferencesStore.antigravityGroupKey))
    }

    func testLegacyPoolsDoNotInventWindowDurationOrExhaustion() throws {
        let root: [String: Any] = ["userStatus": ["cascadeModelConfigData": ["clientModelConfigs": [
            ["label": "Gemini Pro", "quotaInfo": ["remainingFraction": 0.7, "resetTime": "2026-09-15T10:00:00Z"]],
            ["label": "Gemini Flash", "quotaInfo": ["remainingFraction": 0.4]],
            ["label": "Claude Sonnet", "quotaInfo": ["resetTime": "2026-09-15T10:00:00Z"]],
            ["label": "Gemini Image", "quotaInfo": ["remainingFraction": 0.0]]
        ]]]]
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(root, source: "IDE", now: now))
        XCTAssertEqual(quota.groups.count, 2)
        let gemini = try XCTUnwrap(quota.selectedGroup("gemini")?.buckets.first)
        XCTAssertEqual(gemini.remainingFraction, 0.4)
        XCTAssertNil(gemini.kind)
        XCTAssertNil(gemini.normalizedWindow)
        XCTAssertNil(quota.selectedGroup("claude-gpt")?.buckets.first?.remainingFraction)
        XCTAssertEqual(quota.selectedGroup("auto")?.id, "gemini")
    }

    func testMalformedFractionsRemainUnknownAndStatusLineParses() throws {
        for value: Any in [true, -0.1, 1.1, "0.5", NSNull()] {
            let result = try XCTUnwrap(AntigravityQuotaParser.parse(["quota": ["gemini-weekly": ["remaining_fraction": value]]], source: "CLI", now: now))
            XCTAssertNil(result.groups.first?.buckets.first?.remainingFraction)
        }
        let valid = try XCTUnwrap(AntigravityQuotaParser.parse(["plan_tier": "Pro", "quota": ["gemini-5h": ["remaining_fraction": 0.5, "reset_time": "2026-09-09T01:02:03.123456Z"]]], source: "CLI", now: now))
        XCTAssertEqual(valid.plan, "Pro")
        XCTAssertNotNil(valid.groups.first?.buckets.first?.resetsAt)
        XCTAssertNil(AntigravityQuotaParser.parse([:], source: "CLI", now: now))
    }

    func testProcessDiscoveryIsSameUserAndRejectsUnrelatedPrograms() {
        let list = """
        10 501 /Applications/Antigravity.app/bin/language_server --csrf_token secret
        11 502 /Applications/Antigravity.app/bin/language_server --csrf_token other
        12 501 /usr/bin/echo antigravity
        13 501 /Users/test/.local/bin/agy
        14 501 /Applications/Antigravity.app/bin/language_server
        """
        XCTAssertEqual(AntigravityLocalProbe.servers(from: list, userID: 501).map(\.pid), ["10", "13"])
        XCTAssertEqual(AntigravityLocalProbe.ports(from: "p10\nn127.0.0.1:4000\nn*:5000\nn127.0.0.1:4000\n"), [4000, 5000])
    }

    func testGeneratorMetadataDeduplicatesAndStripsContent() throws {
        let row: [String: Any] = ["chatModel": [
            "chatStartMetadata": ["createdAt": "2026-09-08T10:00:00Z", "prompt": "DO_NOT_KEEP"],
            "usage": ["responseId": "response-1", "model": "gemini-flash", "inputTokens": "100", "outputTokens": "30",
                      "responseOutputTokens": "20", "thinkingOutputTokens": "10", "cacheReadTokens": "50", "responseHeader": ["secret": "DO_NOT_KEEP"]]
        ]]
        let records = AntigravityHistoryParser.records(["generatorMetadata": [row, row]], sessionID: "session-1")
        XCTAssertEqual(records.count, 1)
        let usage = try XCTUnwrap(records.first?["usage"] as? [String: Int64])
        XCTAssertEqual(usage["output_tokens"], 30, "Thinking is already in outputTokens.")
        XCTAssertEqual(usage["cache_read_input_tokens"], 50)
        let bytes = try JSONSerialization.data(withJSONObject: records)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("DO_NOT_KEEP"))
        XCTAssertTrue(AntigravityHistoryParser.records(["generatorMetadata": [["chatModel": ["usage": ["inputTokens": "1"]]]]], sessionID: "s").isEmpty,
                      "Missing timestamps must not be replaced with today's date.")
    }

    func testDesktopUndatedMetadataCountsRealTokensOnReportedLocalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 7 * 3600))
        let readAt = try XCTUnwrap(AntigravityJSON.date("2026-09-08T17:35:00Z"))
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("telemetry")
        let latestSummary: [String: Any] = [
            "createdTime": "2026-09-08T17:11:56.177822Z",
            "lastModifiedTime": "2026-09-08T17:20:58.070539Z",
            "lastUserInputTime": "2026-09-08T17:12:27.823031Z", "lastUserInputStepIndex": 2
        ]
        let usage: [(String, String, String, [Int])] = [
            ("18539", "272", "0", [1]), ("845", "734", "18059", [3, 4]),
            ("916", "16003", "18808", [5, 6]), ("16208", "223", "19638", [7, 8]),
            ("36213", "435", "0", [9])
        ]
        let rows: [[String: Any]] = usage.enumerated().map { index, value in
            ["stepIndices": value.3, "chatModel": [
                "model": "MODEL_PLACEHOLDER_M26", "responseModel": "claude-opus-4-6-thinking",
                "messagePrompts": ["DO_NOT_KEEP"], "chatStartMetadata": ["checkpointIndex": -1],
                "usage": ["responseId": "reply-\(index)", "inputTokens": value.0, "outputTokens": value.1,
                          "responseOutputTokens": value.1, "cacheReadTokens": value.2,
                          "responseHeader": ["secret": "DO_NOT_KEEP"]]
            ]]
        }
        let records = AntigravityHistoryParser.records(["generatorMetadata": rows], sessionID: "new-session",
                                                       summary: latestSummary, calendar: calendar)
        XCTAssertEqual(records.count, 5)
        XCTAssertTrue(records.allSatisfy { $0["date_precision"] as? String == "day" })
        XCTAssertTrue(records.allSatisfy { AntigravityJSON.date($0["timestamp"]) == calendar.startOfDay(for: readAt) })
        XCTAssertFalse(String(decoding: try JSONSerialization.data(withJSONObject: records), as: UTF8.self).contains("DO_NOT_KEEP"))
        try write(["records": records], directory.appendingPathComponent("rpc/new-session.json"))

        // A months-old conversation was resumed today. Only the generation after
        // the reported latest input may use today's bounded turn, not old usage.
        let resumedSummary: [String: Any] = ["createdTime": "2026-01-15T16:09:51Z",
            "lastModifiedTime": "2026-09-08T17:11:36Z", "lastUserInputTime": "2026-09-08T17:11:29Z",
            "lastUserInputStepIndex": 131]
        let resumed: [String: Any] = ["stepIndices": [133], "chatModel": [
            "responseModel": "claude-opus-4-6-thinking", "usage": ["inputTokens": "72617", "outputTokens": "73"]]]
        let resumedRecords = AntigravityHistoryParser.records(["generatorMetadata": [resumed]],
            sessionID: "resumed-session", summary: resumedSummary, calendar: calendar)
        XCTAssertEqual(resumedRecords.count, 1)
        try write(["records": resumedRecords], directory.appendingPathComponent("rpc/resumed-session.json"))
        let result = AntigravityTelemetryReader(directoryURL: directory, home: root, now: readAt, calendar: calendar).read()
        XCTAssertEqual(result.tokens?.dailyUsageBuckets.count, 1)
        XCTAssertEqual(result.tokens?.dailyUsageBuckets.first?.tokens, 219_583)
        XCTAssertEqual(result.tokens?.modelUsage?.first?.model, "claude-opus-4-6-thinking")
        XCTAssertEqual(result.tokens?.modelUsage?.first?.tokens, 219_583)
    }

    func testUndatedHistoryKeepsPreviouslyKnownDaysAndRejectsAmbiguousDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 7 * 3600))
        let rows: [[String: Any]] = [
            ["stepIndices": [1], "chatModel": ["usage": ["responseId": "old", "inputTokens": "100"]]],
            ["stepIndices": [3], "chatModel": ["usage": ["responseId": "new", "inputTokens": "200"]]]
        ]
        let yesterday: [String: Any] = ["createdTime": "2026-09-07T17:10:00Z", "lastModifiedTime": "2026-09-07T17:15:00Z"]
        let old = AntigravityHistoryParser.records(["generatorMetadata": [rows[0]]], sessionID: "s", summary: yesterday, calendar: calendar)
        let today: [String: Any] = ["createdTime": "2026-09-07T17:10:00Z", "lastModifiedTime": "2026-09-08T17:15:00Z",
            "lastUserInputTime": "2026-09-08T17:10:00Z", "lastUserInputStepIndex": 2]
        let result = AntigravityHistoryParser.records(["generatorMetadata": rows], sessionID: "s", summary: today,
            previousRecords: old, calendar: calendar)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?["timestamp"] as? Double, old.first?["timestamp"] as? Double)
        XCTAssertNotEqual(result.first?["timestamp"] as? Double, result.last?["timestamp"] as? Double)
        let withoutCache = AntigravityHistoryParser.records(["generatorMetadata": rows], sessionID: "s", summary: today, calendar: calendar)
        XCTAssertEqual(withoutCache.count, 1, "An old undated turn must not be assigned to today.")
        let acrossMidnight: [String: Any] = ["createdTime": "2026-09-08T16:59:00Z", "lastModifiedTime": "2026-09-08T17:01:00Z"]
        XCTAssertTrue(AntigravityHistoryParser.records(["generatorMetadata": rows], sessionID: "s", summary: acrossMidnight, calendar: calendar).isEmpty)
    }

    func testHistoryCacheRequiresCurrentParserVersion() {
        let old: [String: Any] = ["modified_at": now.timeIntervalSince1970, "records": []]
        XCTAssertFalse(AntigravityHistoryParser.canReuseCache(old, modifiedAt: now))
        var updated = old
        updated["schema_version"] = AntigravityHistoryParser.cacheVersion
        XCTAssertTrue(AntigravityHistoryParser.canReuseCache(updated, modifiedAt: now))
        XCTAssertFalse(AntigravityHistoryParser.canReuseCache(updated, modifiedAt: now.addingTimeInterval(1)))
    }

    @MainActor
    func testBridgeRoundTripPreservesCustomizationsAndSanitizesPayload() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = root.appendingPathComponent(".gemini/antigravity-cli/settings.json")
        let hooks = root.appendingPathComponent(".gemini/config/hooks.json")
        let original: [String: Any] = ["theme": "custom", "statusLine": ["type": "command", "command": "printf original-status", "padding": 2]]
        try write(original, settings)
        try write(["my-hook": ["enabled": false]], hooks)
        let bridge = AntigravityTelemetryBridge(home: root)
        try bridge.install()
        try bridge.install()
        XCTAssertTrue(bridge.isInstalled())
        let payload: [String: Any] = [
            "session_id": "session-1", "model": ["id": "gemini", "display_name": "Gemini"],
            "context_window": ["total_input_tokens": 100, "total_output_tokens": 20],
            "quota": ["gemini-weekly": ["remaining_fraction": 0.7]],
            "email": "DO_NOT_KEEP", "cwd": "DO_NOT_KEEP", "prompt": "DO_NOT_KEEP",
            "tool_input": ["secret": "DO_NOT_KEEP"], "agent_state": "working"
        ]
        let output = try runBridge(bridge, event: "status", payload: payload)
        XCTAssertEqual(output, "original-status")
        let files = try FileManager.default.contentsOfDirectory(at: bridge.directoryURL.appendingPathComponent("sessions"), includingPropertiesForKeys: nil)
        let data = try Data(contentsOf: XCTUnwrap(files.first))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("DO_NOT_KEEP"))
        let permissions = try FileManager.default.attributesOfItem(atPath: files[0].path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        let eventOutput = try runBridge(bridge, event: "PostToolUse", payload: ["conversationId": "session-1", "toolCall": ["name": "run_command", "args": ["secret": "DO_NOT_KEEP"]], "error": "DO_NOT_KEEP"])
        XCTAssertEqual(eventOutput.trimmingCharacters(in: .whitespacesAndNewlines), "{}")
        let hookConfig = try read(hooks)
        XCTAssertNotNil(hookConfig["my-hook"])
        XCTAssertNil((hookConfig["dockmagic-antigravity"] as? [String: Any])?["PreToolUse"])
        try bridge.uninstall()
        XCTAssertFalse(bridge.isInstalled())
        XCTAssertTrue((try read(settings) as NSDictionary).isEqual(to: original))
        XCTAssertEqual(try read(hooks).count, 1)
        try write(["statusLine": ["enabled": false, "command": "printf disabled-command"]], settings)
        try bridge.install()
        XCTAssertEqual(try runBridge(bridge, event: "status", payload: payload), "",
                       "Connecting must not execute a previously disabled customization")
        try bridge.uninstall()
    }

    @MainActor
    func testInvalidSettingsAreNeverOverwritten() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent(".gemini/antigravity-cli/settings.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("{ broken".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try AntigravityTelemetryBridge(home: root).install())
        XCTAssertEqual(try Data(contentsOf: url), original)
        try write([:], url)
        let hooksURL = root.appendingPathComponent(".gemini/config/hooks.json")
        try write(["dockmagic-antigravity": false], hooksURL)
        XCTAssertThrowsError(try AntigravityTelemetryBridge(home: root).install())
        XCTAssertEqual(try read(hooksURL)["dockmagic-antigravity"] as? Bool, false)
    }

    @MainActor
    func testDisconnectPreservesExternallyChangedStatusLineAndHooks() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bridge = AntigravityTelemetryBridge(home: root)
        try bridge.install()
        let settingsURL = root.appendingPathComponent(".gemini/antigravity-cli/settings.json")
        let hooksURL = root.appendingPathComponent(".gemini/config/hooks.json")
        try write(["statusLine": ["command": "printf replacement"]], settingsURL)
        var hooks = try read(hooksURL)
        hooks["another-integration"] = ["enabled": true]
        try write(hooks, hooksURL)
        XCTAssertThrowsError(try bridge.install())
        try bridge.uninstall()
        XCTAssertEqual((try read(settingsURL)["statusLine"] as? [String: String])?["command"], "printf replacement")
        XCTAssertNotNil(try read(hooksURL)["another-integration"])
    }

    @MainActor
    func testCachedHistorySurvivesSelectionAndOfflineRefresh() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(summary(), source: "fixture", now: now))
        let cacheURL = root.appendingPathComponent("cache.json")
        let usage = CodexAccountTokenUsage(lifetimeTokens: nil, peakDailyTokens: 123, longestRunningTurnSeconds: nil,
                                          dailyUsageBuckets: [.init(startDate: now, tokens: 123)])
        let snapshot = CodexRateLimitSnapshot(planType: nil, limitID: "antigravity-local", fiveHour: nil, weekly: nil,
            tokenUsage: usage, antigravityTelemetry: .init(quota: quota, selectedGroupID: "auto", local: nil, diagnostic: nil), fetchedAt: now)
        try JSONEncoder().encode(snapshot).write(to: cacheURL)
        let provider = AntigravityTestProvider(quota: quota)
        await provider.fail()
        let store = AntigravityUsageStore(provider: provider, bridge: AntigravityTelemetryBridge(home: root),
            streakTracker: AntigravityTestStreakTracker(), cacheURL: cacheURL,
            readTelemetry: { .init(quota: nil, tokens: nil, telemetry: nil, observedAt: nil) }, now: { self.now })
        store.selectedGroupID = "claude-gpt"
        XCTAssertEqual(store.state.snapshot?.tokenUsage, usage)
        await store.refresh(force: true)
        XCTAssertEqual(store.state.snapshot?.tokenUsage, usage)
        guard case .stale = store.state else { return XCTFail("Offline cached data must remain stale") }
    }

    @MainActor
    func testCoalescingAndStopIgnoreLateProbeResults() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(summary(), source: "fixture", now: now))
        let provider = AntigravityDelayedProvider(quota: quota)
        let store = AntigravityUsageStore(provider: provider, bridge: AntigravityTelemetryBridge(home: root),
            streakTracker: AntigravityTestStreakTracker(), cacheURL: root.appendingPathComponent("cache.json"),
            readTelemetry: { .init(quota: nil, tokens: nil, telemetry: nil, observedAt: nil) })
        let first = Task { await store.refresh(force: true) }
        for _ in 0..<200 {
            if await provider.calls > 0 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let second = Task { await store.refresh(force: true) }
        try await Task.sleep(for: .milliseconds(20))
        let calls = await provider.calls
        XCTAssertEqual(calls, 1)
        store.stop()
        await provider.complete()
        await first.value
        await second.value
        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.state.snapshot, "A cancelled refresh must not resurrect the stopped store")
    }

    func testCumulativeObservationsCountOnlyDeltasAndDoNotMisattributeModelSwitch() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("telemetry")
        for (index, values) in [(100, 20, "Gemini"), (150, 40, "Gemini"), (150, 40, "Gemini"), (180, 50, "Claude"), (10, 5, "Claude")].enumerated() {
            try write(["session_id": "s", "observed_at": now.timeIntervalSince1970 - Double(10 - index),
                       "model": ["id": values.2], "context_window": ["total_input_tokens": values.0, "total_output_tokens": values.1]],
                      directory.appendingPathComponent("observations/\(index).json"))
        }
        let value = AntigravityTelemetryReader(directoryURL: directory, home: root, now: now).read()
        XCTAssertEqual(value.tokens?.dailyUsageBuckets.first?.tokens, 110)
        XCTAssertEqual(value.tokens?.modelUsage?.first?.tokens, 70)
        XCTAssertEqual(value.tokens?.modelUsage?.first?.model, "Gemini")
        XCTAssertNil(value.tokens?.lifetimeTokens)
    }

    func testTranscriptAndRPCDeduplicateAndEmptyHistoryIsNotMissingData() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("telemetry")
        try write(["known_sessions": 1, "has_usage_history": true, "observed_at": now.timeIntervalSince1970, "tasks": []], directory.appendingPathComponent("rpc/index.json"))
        let empty = AntigravityTelemetryReader(directoryURL: directory, home: root, now: now).read()
        XCTAssertNotNil(empty.tokens)
        XCTAssertEqual(empty.tokens?.dailyUsageBuckets, [])
        let record: [String: Any] = ["session_id": "s", "timestamp": now.timeIntervalSince1970 - 1, "model": "Gemini", "usage": ["input_tokens": 100, "output_tokens": 20]]
        try write(["records": [record]], directory.appendingPathComponent("rpc/s.json"))
        let transcript = root.appendingPathComponent(".gemini/antigravity/brain/s/.system_generated/logs/transcript.jsonl")
        try write(["type": "assistant", "session_id": "s", "timestamp": now.timeIntervalSince1970 - 1, "message": ["model": "Gemini", "usage": ["input_tokens": 100, "output_tokens": 20]]], transcript)
        let value = AntigravityTelemetryReader(directoryURL: directory, home: root, now: now).read()
        XCTAssertEqual(value.tokens?.dailyUsageBuckets.first?.tokens, 120)
    }

    func testCompletedAndExpiredWorkDisappears() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(["session_id": "s", "observed_at": now.timeIntervalSince1970 - 10, "event": "status", "agent_state": "working"], root.appendingPathComponent("sessions/s.json"))
        var reader = AntigravityTelemetryReader(directoryURL: root, home: root, now: now)
        XCTAssertEqual(reader.read().telemetry?.activeTasks.count, 1)
        try write(["session_id": "s", "observed_at": now.timeIntervalSince1970 - 1, "event": "Stop", "fully_idle": true], root.appendingPathComponent("events/s.json"))
        XCTAssertEqual(reader.read().telemetry?.activeTasks.count, 0)
        reader.now = now.addingTimeInterval(3600)
        XCTAssertEqual(reader.read().telemetry?.activeTasks.count, 0)
    }

    @MainActor
    func testPreferencesMigrateHiddenGroupAndStoreRecoveryPreservesStreakProvider() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "Antigravity-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("claude-gpt", forKey: DockPreferencesStore.antigravityGroupKey)
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .antigravity
        preferences.setAntigravityDisplayStyle(.numeric)
        let reread = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(reread.activeFeature, .antigravity)
        XCTAssertEqual(reread.antigravityGroupID, "auto")
        XCTAssertNil(defaults.string(forKey: DockPreferencesStore.antigravityGroupKey))
        XCTAssertEqual(reread.antigravityAppearance.displayStyle, .numeric)
        XCTAssertEqual(reread.claudeCodeAppearance.displayStyle, .chart)
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(summary(), source: "fixture", now: now))
        let provider = AntigravityTestProvider(quota: quota)
        let tracker = AntigravityTestStreakTracker()
        let store = AntigravityUsageStore(provider: provider, bridge: AntigravityTelemetryBridge(home: root), streakTracker: tracker,
                                         cacheURL: root.appendingPathComponent("cache.json"),
                                         readTelemetry: { .init(quota: nil, tokens: nil, telemetry: nil, observedAt: nil) }, now: { self.now })
        store.selectedGroupID = "claude-gpt"
        await store.refresh(force: true)
        XCTAssertEqual(store.state.snapshot?.antigravityTelemetry?.selectedGroup?.id, "claude-gpt")
        XCTAssertEqual(tracker.provider, .antigravity)
        await provider.fail()
        await store.refresh(force: true)
        guard case .stale = store.state else { return XCTFail("Keep last quota on failure") }
        await provider.succeed()
        await store.refresh(force: true)
        guard case .live = store.state else { return XCTFail("Recover without restart") }
        XCTAssertTrue(DockFeature.antigravity.hasHoverDashboard)
        XCTAssertEqual(SettingsDestination.antigravity.feature, .antigravity)
    }

    @MainActor
    func testSettingsConnectionPreservesActiveFeatureAndRetriesWithoutReinstalling() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "Antigravity-settings-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .claudeCode
        let settingsURL = root.appendingPathComponent(".gemini/antigravity-cli/settings.json")
        try write(["theme": "custom"], settingsURL)
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(summary(), source: "fixture", now: now))
        let provider = AntigravityTestProvider(quota: quota)
        let bridge = AntigravityTelemetryBridge(home: root)
        let store = AntigravityUsageStore(provider: provider, bridge: bridge,
            streakTracker: AntigravityTestStreakTracker(), cacheURL: root.appendingPathComponent("cache.json"),
            readTelemetry: { .init(quota: nil, tokens: nil, telemetry: nil, observedAt: nil) }, now: { self.now })
        let appModel = DockAppModel(preferences: preferences, antigravityStore: store)
        defer { appModel.stop() }

        appModel.requestDeveloperToolPreparation(for: .antigravity)
        for _ in 0..<100 {
            if store.isBridgeInstalled && store.state.snapshot != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(bridge.isInstalled())
        XCTAssertEqual(preferences.activeFeature, .claudeCode)
        XCTAssertEqual(store.state.snapshot?.antigravityTelemetry?.selectedGroup?.id, "gemini")
        XCTAssertEqual(try read(settingsURL)["theme"] as? String, "custom")
        let connectedSettings = try Data(contentsOf: settingsURL)

        await provider.fail()
        await appModel.prepareDeveloperToolIntegration(for: .antigravity)
        guard case .stale = store.state else { return XCTFail("Keep quota when a connection check fails") }
        await provider.succeed()
        await appModel.prepareDeveloperToolIntegration(for: .antigravity)
        guard case .live = store.state else { return XCTFail("Retry must restore the live connection") }
        XCTAssertEqual(try Data(contentsOf: settingsURL), connectedSettings)
        XCTAssertEqual(preferences.activeFeature, .claudeCode)

        // ImageRenderer covers the SwiftUI preview and connection icon. Native
        // segmented controls and sliders are checked in the running Settings UI.
        let destination = URL(fileURLWithPath: "/private/tmp/dockmagic-antigravity-qa")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for (name, mode, overrides) in [("light", DSAppearanceMode.light, DSAccessibilityOverrides()),
                                       ("dark", .dark, .init()), ("contrast", .dark, .init(increaseContrast: true)),
                                       ("opaque", .dark, .init(reduceTransparency: true))] {
            let view = DockMagicThemeRoot(content: AntigravitySettingsView(appModel: appModel)
                .padding(24).frame(width: 820), appearanceMode: mode)
                .environment(\.colorScheme, mode == .light ? .light : .dark)
                .environment(\.dsAccessibilityOverrides, overrides)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let cg = try XCTUnwrap(renderer.cgImage)
            let data = try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
            try data.write(to: destination.appendingPathComponent("settings-\(name).png"))
            if name == "light" {
                let gray = CIImage(cgImage: cg).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                let grayImage = try XCTUnwrap(CIContext().createCGImage(gray, from: gray.extent))
                try XCTUnwrap(NSBitmapImageRep(cgImage: grayImage).representation(using: .png, properties: [:]))
                    .write(to: destination.appendingPathComponent("settings-grayscale.png"))
            }
        }
    }

    @MainActor
    func testRenderDashboardAndDockAppearanceMatrix() throws {
        let quota = try XCTUnwrap(AntigravityQuotaParser.parse(summary(), source: "fixture", now: now))
        let calendar = Calendar.current
        let usage = CodexAccountTokenUsage(lifetimeTokens: nil, peakDailyTokens: 250_000_000, longestRunningTurnSeconds: nil,
            dailyUsageBuckets: (0..<30).map { .init(startDate: calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now))!, tokens: Int64(($0 % 7 + 1) * 12_000_000)) },
            modelUsage: [.init(model: "Gemini Flash", tokens: 250_000_000), .init(model: "Claude Sonnet", tokens: 140_000_000)], isModelUsagePartial: true)
        let state = CodexUsageState.live(.init(planType: "Pro", limitID: "antigravity-local", fiveHour: nil, weekly: nil,
            tokenUsage: usage, streakSummary: .fixture(currentDays: 8, bestDays: 12, endingAt: now, calendar: calendar),
            antigravityTelemetry: .init(quota: quota, selectedGroupID: "auto", local: nil, diagnostic: nil), fetchedAt: now))
        let destination = URL(fileURLWithPath: "/private/tmp/dockmagic-antigravity-qa")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for (name, mode, overrides) in [("light", DSAppearanceMode.light, DSAccessibilityOverrides()),
                                       ("dark", .dark, .init()), ("contrast", .dark, .init(increaseContrast: true)),
                                       ("opaque", .dark, .init(reduceTransparency: true))] {
            let image = try CodexDashboardCaptureService.renderAntigravity(state: state,
                configuration: .init(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: 740), appearanceMode: mode),
                now: now, accessibilityOverrides: overrides)
            XCTAssertGreaterThan(image.pngData.count, 10_000)
            try image.pngData.write(to: destination.appendingPathComponent("dashboard-\(name).png"))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: image.pngData))
            var shades = Set<Int>()
            for x in stride(from: 40, to: bitmap.pixelsWide - 40, by: 11) {
                for y in stride(from: 40, to: bitmap.pixelsHigh - 40, by: 11) {
                    if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                        shades.insert(Int(color.redComponent * 255))
                    }
                }
            }
            XCTAssertGreaterThan(shades.count, 30, "The exported card must contain content, not a blank surface")
            if name == "light" {
                let source = try XCTUnwrap(CIImage(data: image.pngData))
                let gray = source.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                let cg = try XCTUnwrap(CIContext().createCGImage(gray, from: gray.extent))
                try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
                    .write(to: destination.appendingPathComponent("dashboard-grayscale.png"))
            }
        }
        for (name, renderState, metric) in [("cost", state, "Cost"),
                                          ("unavailable", .unavailable(message: "Open Antigravity"), "Tokens"),
                                          ("stale", .stale(try XCTUnwrap(state.snapshot), message: "Last observed usage"), "Tokens")] {
            let artifact = try CodexDashboardCaptureService.renderAntigravity(state: renderState,
                configuration: .init(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: 740), appearanceMode: .dark),
                now: now, initialMetric: metric)
            try artifact.pngData.write(to: destination.appendingPathComponent("dashboard-\(name).png"))
        }
        for style in DockDisplayStyle.allCases {
            for size in [32, 48, 64, 128] {
                var appearance = DockFeatureDefaults.antigravityAppearance
                appearance.setDisplayStyle(style)
                let view = DockMagicThemeRoot(content: DockAntigravityView(state: state, appearance: appearance, animatesChanges: false), appearanceMode: .dark)
                    .frame(width: CGFloat(size), height: CGFloat(size))
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let cg = try XCTUnwrap(renderer.cgImage)
                let data = try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
                try data.write(to: destination.appendingPathComponent("dock-\(style.rawValue)-\(size).png"))
                XCTAssertEqual(cg.width, size * 2)
            }
        }
        let legacyQuota = AntigravityQuotaSnapshot(groups: [.init(id: "gemini", title: "Gemini", buckets: [
            .init(id: "gemini", title: "Model quota", kind: nil, remainingFraction: 1, resetsAt: now, resetDescription: nil)
        ])], plan: "Antigravity Starter Quota", source: "Legacy fixture", observedAt: now)
        let legacy = CodexRateLimitSnapshot(planType: legacyQuota.plan, limitID: "antigravity-local", fiveHour: nil, weekly: nil,
            antigravityTelemetry: .init(quota: legacyQuota, selectedGroupID: "auto", local: nil, diagnostic: nil), fetchedAt: now)
        var numeric = DockFeatureDefaults.antigravityAppearance
        numeric.setDisplayStyle(.numeric)
        for (name, dockState) in [("legacy", CodexUsageState.live(legacy)),
                                  ("legacy-stale", .stale(legacy, message: "Last known")),
                                  ("unavailable", .unavailable(message: "Open Antigravity"))] {
            for size in [32, 48, 64, 128] {
                let view = DockMagicThemeRoot(content: DockAntigravityView(state: dockState, appearance: numeric, animatesChanges: false), appearanceMode: .dark)
                    .frame(width: CGFloat(size), height: CGFloat(size))
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let cg = try XCTUnwrap(renderer.cgImage)
                try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
                    .write(to: destination.appendingPathComponent("dock-\(name)-\(size).png"))
            }
        }
    }

    private func summary() -> [String: Any] {
        ["response": ["groups": [
            ["displayName": "Gemini Models", "buckets": [
                ["bucketId": "gemini-weekly", "remaining": ["remainingFraction": 0.6]],
                ["bucketId": "gemini-5h", "remaining": ["remainingFraction": 0.25]]]],
            ["displayName": "Claude and GPT models", "buckets": [
                ["bucketId": "3p-weekly", "remainingFraction": 0.9],
                ["bucketId": "3p-5h", "remainingFraction": 0.8]]]
        ]]]
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("antigravity-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func write(_ object: [String: Any], _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
    }
    private func read(_ url: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }
    @MainActor private func runBridge(_ bridge: AntigravityTelemetryBridge, event: String, payload: [String: Any]) throws -> String {
        let process = Process(); let input = Pipe(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [bridge.directoryURL.appendingPathComponent("bridge.py").path, event]
        process.standardInput = input; process.standardOutput = output
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: payload))
        try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return String(decoding: data, as: UTF8.self)
    }
}

private actor AntigravityTestProvider: AntigravityQuotaProviding {
    let quota: AntigravityQuotaSnapshot
    var failing = false
    init(quota: AntigravityQuotaSnapshot) { self.quota = quota }
    func fail() { failing = true }
    func succeed() { failing = false }
    func fetchQuota() throws -> AntigravityQuotaSnapshot {
        if failing { throw AntigravityDataError.unavailable }
        return quota
    }
}

private actor AntigravityDelayedProvider: AntigravityQuotaProviding {
    let quota: AntigravityQuotaSnapshot
    var calls = 0
    private var continuation: CheckedContinuation<AntigravityQuotaSnapshot, Never>?
    init(quota: AntigravityQuotaSnapshot) { self.quota = quota }
    func fetchQuota() async throws -> AntigravityQuotaSnapshot {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func complete() { continuation?.resume(returning: quota); continuation = nil }
}

@MainActor private final class AntigravityTestStreakTracker: TokenUsageStreakTracking {
    var provider: TokenUsageProvider?
    func observeToday(provider: TokenUsageProvider, tokenUsage: CodexAccountTokenUsage?, at observedAt: Date, calendar: Calendar) -> TokenUsageStreakSummary {
        self.provider = provider
        return TokenUsageStreakCalculator.summary(from: [], now: observedAt, calendar: calendar)
    }
}
