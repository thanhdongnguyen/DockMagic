import Foundation
import XCTest
@testable import DockMagic

final class AntigravityFeatureTests: XCTestCase {
    func testUsageParserKeepsModelPoolsSeparateAndPreservesZero() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: fetchedAt
        )

        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        XCTAssertEqual(snapshot.buckets.map(\.id), ["gemini-weekly", "3p-weekly"])
        XCTAssertEqual(snapshot.buckets[0].groupName, "Gemini Models")
        XCTAssertEqual(snapshot.buckets[0].remainingFraction, 1)
        XCTAssertEqual(snapshot.buckets[0].windowDurationMinutes, 10_080)
        XCTAssertEqual(snapshot.buckets[1].groupName, "Claude and GPT models")
        XCTAssertEqual(snapshot.buckets[1].remainingFraction, 0)
        XCTAssertNotNil(snapshot.buckets[1].resetsAt)
    }

    func testUsageParserDoesNotFallBackToHumanReadableResponse() {
        let output = #"{"status":"SUCCESS","response":"Gemini Models Weekly Limit Remaining 100%"}"#
        XCTAssertThrowsError(try AntigravityUsageResponseParser.parse(
            output: output,
            fetchedAt: .now
        )) { error in
            XCTAssertEqual(error as? AntigravityUsageError, .unsupportedResponse)
        }
    }

    func testUsageParserKeepsMissingQuotaUnavailableAndMapsSignedOut() {
        let missingFraction = #"{"status":"SUCCESS","command":{"name":"usage","data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly","name":"Weekly","window":"weekly"}]}]}}}"#
        XCTAssertThrowsError(try AntigravityUsageResponseParser.parse(
            output: missingFraction,
            fetchedAt: .now
        )) { error in
            XCTAssertEqual(error as? AntigravityUsageError, .unsupportedResponse)
        }

        let signedOut = #"{"status":"ERROR","error":"Authentication required. Sign in first."}"#
        XCTAssertThrowsError(try AntigravityUsageResponseParser.parse(
            output: signedOut,
            fetchedAt: .now
        )) { error in
            XCTAssertEqual(error as? AntigravityUsageError, .signedOut)
        }
    }

    func testUsageParserClampsFractionsButDoesNotInventUnknownWindows() throws {
        let output = #"{"status":"SUCCESS","command":{"name":"usage","data":{"groups":[{"name":"Future pool","buckets":[{"id":"high","name":"Rolling","window":"rolling","remaining_fraction":1.4},{"id":"low","name":"Rolling","window":"rolling","remaining_fraction":-0.2}]}]}}}"#
        let snapshot = try AntigravityUsageResponseParser.parse(
            output: output,
            fetchedAt: .now
        )

        XCTAssertEqual(snapshot.buckets.map(\.remainingFraction), [1, 0])
        XCTAssertTrue(snapshot.buckets.allSatisfy {
            $0.windowDurationMinutes == nil
        })
    }

    func testUsageProviderUsesFixedDocumentedCommand() async throws {
        let runner = RecordingAntigravityRunner(output: Self.usageJSON)
        let provider = AntigravityCLIUsageProvider(
            processRunner: runner,
            environment: ["PATH": "/usr/bin"],
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
        _ = try await provider.fetchQuota(
            executableURL: URL(fileURLWithPath: "/tmp/agy")
        )
        let calls = await runner.calls
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.arguments, [
            "-p", "/usage", "--output-format", "json",
            "--print-timeout", "30s"
        ])
        XCTAssertEqual(call.environment["AGY_CLI_DISABLE_AUTO_UPDATE"], "true")
        XCTAssertEqual(call.environment["NO_COLOR"], "1")
        XCTAssertEqual(call.timeout, 45)
    }

    func testAuthenticationProviderSignsOutWithoutInteractiveTerminal()
        async throws {
        let runner = RecordingAntigravityRunner(
            output: #"{"status":"SUCCESS"}"#
        )
        let provider = AntigravityCLIAuthenticationProvider(
            processRunner: runner,
            environment: ["PATH": "/usr/bin"]
        )

        try await provider.signOut(
            executableURL: URL(fileURLWithPath: "/tmp/agy")
        )

        let calls = await runner.calls
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.arguments, [
            "-p", "/logout", "--output-format", "json",
            "--print-timeout", "30s"
        ])
        XCTAssertEqual(call.environment["AGY_CLI_DISABLE_AUTO_UPDATE"], "true")
        XCTAssertEqual(call.environment["NO_COLOR"], "1")
        XCTAssertEqual(call.timeout, 45)
    }

    func testAuthenticationProviderRejectsUnconfirmedSignOut() async {
        let runner = RecordingAntigravityRunner(
            output: #"{"status":"ERROR","error":"keyring unavailable"}"#
        )
        let provider = AntigravityCLIAuthenticationProvider(
            processRunner: runner
        )

        do {
            try await provider.signOut(
                executableURL: URL(fileURLWithPath: "/tmp/agy")
            )
            XCTFail("An unsuccessful logout envelope must not be accepted.")
        } catch {
            XCTAssertEqual(error as? AntigravityUsageError, .signOutFailed)
        }
    }

    @MainActor
    func testStoreExposesSignedOutAuthenticationState() async {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let provider = CountingAntigravityProvider(
            result: .failure(.signedOut)
        )
        let store = AntigravityUsageStore(
            provider: provider,
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions",
                    isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )

        await store.refresh()

        XCTAssertEqual(store.connectionState, .signedOut)
        XCTAssertEqual(store.resolvedExecutablePath, "/usr/bin/true")
        guard case let .unavailable(message) = store.state else {
            return XCTFail("Signed-out quota should be unavailable without a cache.")
        }
        XCTAssertEqual(
            message,
            "Sign in to agy, then refresh Antigravity usage."
        )

        store.beginSignIn()
        XCTAssertEqual(store.connectionState, .signingIn)
        await store.cancelAuthentication()
        XCTAssertEqual(store.connectionState, .signedOut)
        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 1, "Cancel must not start another auth probe.")
    }

    @MainActor
    func testSignInRetriesACancelledQuotaProbeInsteadOfStayingChecking()
        async throws {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let provider = CancellableAntigravityProvider(snapshot: quota)
        let store = AntigravityUsageStore(
            provider: provider,
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions", isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )

        let firstRefresh = Task { await store.refresh() }
        await provider.waitUntilStarted()
        XCTAssertEqual(store.connectionState, .checking)

        store.beginSignIn()
        await store.signInProcessDidFinish()
        await firstRefresh.value

        guard case .connected = store.connectionState else {
            return XCTFail("A completed sign-in must not remain Checking.")
        }
        XCTAssertNotNil(store.state.snapshot?.quota)
        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 2)
    }

    @MainActor
    func testStoppingACheckCancelsCheckingAndAllowsRetry() async throws {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let provider = CancellableAntigravityProvider(snapshot: quota)
        let store = AntigravityUsageStore(
            provider: provider,
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions", isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )

        let firstRefresh = Task { await store.refresh() }
        await provider.waitUntilStarted()
        XCTAssertEqual(store.connectionState, .checking)

        store.stop()
        guard case .failed = store.connectionState else {
            return XCTFail("An interrupted check must offer Retry, not Checking.")
        }

        let retry = Task { await store.refresh() }
        await retry.value
        await firstRefresh.value
        guard case .connected = store.connectionState else {
            return XCTFail(
                "Retry must survive a late cancelled check and connect."
            )
        }
        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 2)
    }

    @MainActor
    func testBackgroundQuotaRefreshKeepsConnectedPresentation() async throws {
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let provider = PausingSecondAntigravityProvider(snapshot: quota)
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let store = AntigravityUsageStore(
            provider: provider,
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions", isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        await store.refresh()
        let settledState = store.connectionState

        let refresh = Task { await store.refresh() }
        await provider.waitUntilSecondCallStarted()

        XCTAssertEqual(store.connectionState, settledState)
        XCTAssertTrue(store.isRefreshing)

        await provider.resumeSecondCall()
        await refresh.value
    }

    @MainActor
    func testSettingsHidesOnlyAutomaticAntigravityCheck() {
        XCTAssertFalse(
            AntigravityConnectionSettingsView.displaysConnectionSummary(
                for: .checking
            )
        )
        XCTAssertTrue(
            AntigravityConnectionSettingsView.displaysConnectionSummary(
                for: .signingIn
            )
        )
        XCTAssertTrue(
            AntigravityConnectionSettingsView.displaysConnectionSummary(
                for: .signingOut
            )
        )
        XCTAssertEqual(
            AntigravityConnectionSettingsView.actionPresentation(
                for: .checking,
                hasAuthenticatedContext: false
            ),
            .signIn
        )
        XCTAssertEqual(
            AntigravityConnectionSettingsView.actionPresentation(
                for: .checking,
                hasAuthenticatedContext: true
            ),
            .authenticated
        )
    }

    @MainActor
    func testStoreShowsSigningOutUntilLogoutIsVerified() async throws {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let provider = SequencedAntigravityProvider(results: [
            .success(quota),
            .failure(.signedOut)
        ])
        let authenticator = SuspendedAntigravityAuthenticator()
        let store = AntigravityUsageStore(
            provider: provider,
            authenticationProvider: authenticator,
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions",
                    isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        await store.refresh()
        guard case .connected = store.connectionState else {
            return XCTFail("The fixture must begin connected.")
        }

        let signOutTask = Task { await store.signOut() }
        await authenticator.waitUntilStarted()
        XCTAssertEqual(store.connectionState, .signingOut)

        await authenticator.resume()
        await signOutTask.value

        XCTAssertEqual(store.connectionState, .signedOut)
        XCTAssertNil(store.state.snapshot?.quota)
        let signOutCount = await authenticator.signOutCount
        let quotaCallCount = await provider.callCount
        XCTAssertEqual(signOutCount, 1)
        XCTAssertEqual(quotaCallCount, 2)
    }

    @MainActor
    func testStoreStartDoesNotProbeQuotaBeforeExplicitSignIn() async throws {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let provider = CountingAntigravityProvider(
            result: .failure(.signedOut)
        )
        let store = AntigravityUsageStore(
            provider: provider,
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions",
                    isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )

        XCTAssertEqual(store.connectionState, .signedOut)
        store.start()
        try await Task.sleep(for: .milliseconds(50))
        store.stop()

        let callCount = await provider.callCount
        XCTAssertEqual(
            callCount,
            0,
            "Opening Settings must not run agy or start its OAuth flow."
        )
    }

    @MainActor
    func testSignedOutResponseClearsCachedQuota() async throws {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let cacheURL = cacheDirectory.appendingPathComponent("cache.json")
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let bridge = FakeAntigravityBridge(
            sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                "sessions",
                isDirectory: true
            )
        )
        let connectedStore = AntigravityUsageStore(
            provider: FixedAntigravityProvider(snapshot: quota),
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheURL,
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        await connectedStore.refresh()
        XCTAssertNotNil(connectedStore.state.snapshot?.quota)

        let signedOutStore = AntigravityUsageStore(
            provider: FailingAntigravityProvider(error: .signedOut),
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheURL,
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        await signedOutStore.refresh()

        XCTAssertEqual(signedOutStore.connectionState, .signedOut)
        XCTAssertNil(signedOutStore.state.snapshot?.quota)

        let reloadedStore = AntigravityUsageStore(
            provider: FailingAntigravityProvider(error: .commandFailed),
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheURL,
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        XCTAssertEqual(reloadedStore.connectionState, .signedOut)
        XCTAssertNil(reloadedStore.state.snapshot?.quota)
    }

    @MainActor
    func testStoreExposesMissingCLIAuthenticationState() async {
        let cacheDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let store = AntigravityUsageStore(
            provider: FailingAntigravityProvider(error: .commandFailed),
            locator: MissingAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: cacheDirectory.appendingPathComponent(
                    "sessions",
                    isDirectory: true
                )
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )

        await store.refresh()

        XCTAssertEqual(store.connectionState, .cliMissing)
        XCTAssertNil(store.executableURL)
    }

    @MainActor
    func testStatusLineBridgeStoresOnlyAllowlistedFieldsAndHashesSessionID()
        throws {
        let home = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let bridge = AntigravityStatusLineBridge(home: home)
        try bridge.install()
        XCTAssertTrue(bridge.isInstalled())

        let payload = #"{"conversation_id":"session-123","email":"private@example.com","cwd":"/secret/project","transcript_path":"/secret/transcript.jsonl","model":{"id":"gemini-pro","display_name":"Gemini Pro"},"version":"1.2.2","plan_tier":"pro","agent_state":"working","task_count":2,"context_window":{"total_input_tokens":120,"total_output_tokens":30,"context_window_size":200000,"remaining_percentage":42}}"#
        try runStatusLineBridge(
            home.appendingPathComponent(
                ".gemini/dockmagic-antigravity/dockmagic-statusline.sh"
            ), payload: payload
        )

        let files = try FileManager.default.contentsOfDirectory(
            at: bridge.sessionsDirectoryURL,
            includingPropertiesForKeys: nil
        )
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(file.deletingPathExtension().lastPathComponent.count, 64)
        XCTAssertNotEqual(file.deletingPathExtension().lastPathComponent, "session-123")
        let stored = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(stored.contains("private@example.com"))
        XCTAssertFalse(stored.contains("/secret/project"))
        XCTAssertFalse(stored.contains("transcript"))
        XCTAssertFalse(stored.contains("session-123"))

        let historyDirectory = bridge.sessionsDirectoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("history")
            .appendingPathComponent(
                TokenUsageCalendarDay.containing(.now).key
                    .replacingOccurrences(of: "-", with: "")
            )
        let historyFiles = try FileManager.default.contentsOfDirectory(
            at: historyDirectory, includingPropertiesForKeys: nil
        )
        XCTAssertEqual(historyFiles.count, 2)
        let directoryPermissions = try FileManager.default.attributesOfItem(
            atPath: historyDirectory.path
        )[.posixPermissions] as? NSNumber
        XCTAssertEqual(directoryPermissions?.intValue, 0o700)
        for historyFile in historyFiles {
            let filePermissions = try FileManager.default.attributesOfItem(
                atPath: historyFile.path
            )[.posixPermissions] as? NSNumber
            XCTAssertEqual(filePermissions?.intValue, 0o600)
            let archived = try String(contentsOf: historyFile, encoding: .utf8)
            XCTAssertFalse(archived.contains("private@example.com"))
            XCTAssertFalse(archived.contains("/secret/project"))
            XCTAssertFalse(archived.contains("transcript"))
            XCTAssertFalse(archived.contains("session-123"))
            XCTAssertFalse(archived.contains("plan_tier"))
            XCTAssertFalse(archived.contains("task_count"))
            XCTAssertFalse(archived.contains("agent_state"))
        }

        let sessions = AntigravityStatusLineReader(
            sessionsDirectoryURL: bridge.sessionsDirectoryURL,
            now: .now
        ).readSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].modelID, "gemini-pro")
        XCTAssertEqual(sessions[0].context?.observedTotalTokens, 150)
        XCTAssertEqual(sessions[0].context?.remainingPercent, 42)
    }

    @MainActor
    func testHistoryReplaysOfflineSamplesWithoutDoubleCountingAfterRestart()
        throws {
        let home = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let bridge = AntigravityStatusLineBridge(home: home)
        try bridge.install()
        let scriptURL = home.appendingPathComponent(
            ".gemini/dockmagic-antigravity/dockmagic-statusline.sh"
        )
        let first = #"{"conversation_id":"offline-session","model":{"id":"gemini-pro"},"context_window":{"total_input_tokens":100,"total_output_tokens":25}}"#
        let last = #"{"conversation_id":"offline-session","model":{"id":"gemini-pro"},"context_window":{"total_input_tokens":160,"total_output_tokens":45}}"#
        try runStatusLineBridge(scriptURL, payload: first)
        try runStatusLineBridge(scriptURL, payload: last)

        let reader = AntigravityStatusLineReader(
            sessionsDirectoryURL: bridge.sessionsDirectoryURL,
            now: .now
        )
        let archived = reader.readHistorySessions()
        XCTAssertEqual(archived.count, 2)
        XCTAssertEqual(archived.map(\.context?.observedTotalTokens), [125, 205])

        let cacheURL = home.appendingPathComponent("cache.json")
        let store = AntigravityUsageStore(
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheURL,
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        XCTAssertEqual(
            store.state.snapshot?.tokenUsage?.dailyUsageBuckets.last?.tokens,
            80
        )

        let reloaded = AntigravityUsageStore(
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheURL,
            readSessions: { [] },
            pollingInterval: .seconds(60)
        )
        XCTAssertEqual(
            reloaded.state.snapshot?.tokenUsage?.dailyUsageBuckets.last?.tokens,
            80
        )

        let oldDay = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: -31, to: .now)
        )
        let oldDirectory = bridge.sessionsDirectoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("history")
            .appendingPathComponent(
                TokenUsageCalendarDay.containing(oldDay).key
                    .replacingOccurrences(of: "-", with: "")
            )
        try FileManager.default.createDirectory(
            at: oldDirectory, withIntermediateDirectories: true
        )
        try runStatusLineBridge(scriptURL, payload: last)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.path))
    }

    @MainActor
    func testHistoryReplayKeepsOfflineDaysSeparateAndDropsCrossDayGap()
        throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(
            for: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let yesterday = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: today)
        )
        let now = today.addingTimeInterval(12 * 3_600)
        let sessionID = String(repeating: "b", count: 64)
        let historyDirectory = root.appendingPathComponent("history")
        for (day, firstInput, firstOutput, lastInput, lastOutput) in [
            (yesterday, Int64(100), Int64(10), Int64(160), Int64(20)),
            (today, Int64(170), Int64(25), Int64(230), Int64(35))
        ] {
            let directory = historyDirectory.appendingPathComponent(
                TokenUsageCalendarDay.containing(day, calendar: calendar)
                    .key.replacingOccurrences(of: "-", with: "")
            )
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            try writeHistorySample(
                to: directory.appendingPathComponent("\(sessionID)-first.json"),
                input: firstInput,
                output: firstOutput,
                at: day.addingTimeInterval(10 * 3_600)
            )
            try writeHistorySample(
                to: directory.appendingPathComponent("\(sessionID)-last.json"),
                input: lastInput,
                output: lastOutput,
                at: day.addingTimeInterval(11 * 3_600)
            )
        }

        let store = AntigravityUsageStore(
            locator: FixedAntigravityLocator(),
            bridge: FakeAntigravityBridge(
                sessionsDirectoryURL: root.appendingPathComponent("sessions")
            ),
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: root.appendingPathComponent("cache.json"),
            readSessions: { [] },
            now: { now }
        )
        XCTAssertEqual(
            store.state.snapshot?.tokenUsage?.dailyUsageBuckets.map(\.tokens),
            [70, 70]
        )
    }

    @MainActor
    func testHistoryPrunesExpiredDaysOnLaunchWithoutNewCLIEvent() throws {
        let home = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let bridge = AntigravityStatusLineBridge(home: home)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let history = bridge.rootDirectoryURL.appendingPathComponent("history")
        var directories: [URL] = []
        for offset in [29, 30] {
            let day = try XCTUnwrap(calendar.date(
                byAdding: .day, value: -offset, to: now
            ))
            let key = TokenUsageCalendarDay.containing(day, calendar: calendar)
                .key.replacingOccurrences(of: "-", with: "")
            let directory = history.appendingPathComponent(key)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            directories.append(directory)
        }

        try bridge.pruneArchivedHistory(asOf: now)

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directories[0].path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directories[1].path
        ))
    }

    @MainActor
    func testHistoryDoesNotArchiveMissingTokenCounters() throws {
        let home = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let bridge = AntigravityStatusLineBridge(home: home)
        try bridge.install()
        let scriptURL = bridge.rootDirectoryURL.appendingPathComponent(
            "dockmagic-statusline.sh"
        )
        try runStatusLineBridge(
            scriptURL,
            payload: #"{"conversation_id":"session-without-output","context_window":{"total_input_tokens":100}}"#
        )

        XCTAssertEqual(
            AntigravityStatusLineReader(
                sessionsDirectoryURL: bridge.sessionsDirectoryURL,
                now: .now
            ).readHistorySessions().count,
            0
        )
    }

    func testHistoryReaderSkipsSymlinkedArchiveRoot() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("external-history")
        let todayKey = TokenUsageCalendarDay.containing(.now).key
            .replacingOccurrences(of: "-", with: "")
        let day = target.appendingPathComponent(todayKey)
        try FileManager.default.createDirectory(
            at: day, withIntermediateDirectories: true
        )
        let sessionID = String(repeating: "c", count: 64)
        try writeHistorySample(
            to: day.appendingPathComponent("\(sessionID)-first.json"),
            input: 100, output: 10, at: .now
        )
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("history"),
            withDestinationURL: target
        )

        XCTAssertTrue(AntigravityStatusLineReader(
            sessionsDirectoryURL: root.appendingPathComponent("sessions"),
            now: .now
        ).readHistorySessions().isEmpty)
    }

    @MainActor
    func testStoreAccumulatesOnlyPositiveSameSessionDeltas() async throws {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let sessions = LockedSessionBox([
            Self.session(input: 100, output: 25, at: observedAt)
        ])
        let bridge = FakeAntigravityBridge(
            sessionsDirectoryURL: temporaryDirectory()
        )
        let cacheURL = temporaryDirectory().appendingPathComponent("cache.json")
        defer {
            try? FileManager.default.removeItem(
                at: cacheURL.deletingLastPathComponent()
            )
            try? FileManager.default.removeItem(at: bridge.sessionsDirectoryURL)
        }
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: observedAt
        )
        let store = AntigravityUsageStore(
            provider: FixedAntigravityProvider(snapshot: quota),
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheURL,
            readSessions: { sessions.value },
            pollingInterval: .seconds(60),
            now: { observedAt.addingTimeInterval(60) }
        )
        sessions.value = [
            Self.session(
                input: 160,
                output: 45,
                at: observedAt.addingTimeInterval(60)
            )
        ]

        await store.refresh()

        XCTAssertEqual(
            store.connectionState,
            .connected(lastUpdated: observedAt)
        )
        XCTAssertEqual(
            store.state.snapshot?.tokenUsage?.dailyUsageBuckets.last?.tokens,
            80
        )
        XCTAssertEqual(
            store.state.snapshot?.tokenUsage?.modelUsage?.first?.tokens,
            80
        )
        XCTAssertEqual(store.state.snapshot?.historyIsPartial, true)
        XCTAssertEqual(
            store.state.snapshot?.activityObservedAt,
            observedAt.addingTimeInterval(60)
        )
        sessions.value = [
            Self.session(
                input: 160,
                output: 45,
                at: observedAt.addingTimeInterval(61)
            )
        ]
        await store.refresh()
        XCTAssertEqual(
            store.state.snapshot?.activityObservedAt,
            observedAt.addingTimeInterval(60),
            "A later session sample without a token delta must not freshen the activity card."
        )
    }

    @MainActor
    func testStoreDoesNotExposeExpiredSessionAsCurrent() async throws {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let now = observedAt.addingTimeInterval(16 * 60)
        let quota = try AntigravityUsageResponseParser.parse(
            output: Self.usageJSON,
            fetchedAt: now
        )
        let bridge = FakeAntigravityBridge(
            sessionsDirectoryURL: temporaryDirectory()
        )
        let cacheDirectory = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: cacheDirectory)
            try? FileManager.default.removeItem(at: bridge.sessionsDirectoryURL)
        }

        let store = AntigravityUsageStore(
            provider: FixedAntigravityProvider(snapshot: quota),
            locator: FixedAntigravityLocator(),
            bridge: bridge,
            streakTracker: FakeAntigravityStreakTracker(),
            cacheURL: cacheDirectory.appendingPathComponent("cache.json"),
            readSessions: {
                [Self.session(input: 100, output: 25, at: observedAt)]
            },
            pollingInterval: .seconds(60),
            staleAfter: 15 * 60,
            now: { now }
        )
        await store.refresh()

        XCTAssertNil(store.state.snapshot?.currentSession)
        XCTAssertEqual(store.state.snapshot?.activeSessionCount, 1)
    }

    func testDashboardPresentationKeepsUnobservedDaysUnavailable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 14,
            hour: 12
        )))
        let yesterday = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: now)
        )
        let laterYesterday = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: 2, to: yesterday)
        )
        let usage = CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: 200,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(
                    startDate: yesterday,
                    tokens: 100
                ),
                CodexTokenUsageDailyBucket(
                    startDate: laterYesterday,
                    tokens: 50
                ),
                CodexTokenUsageDailyBucket(startDate: now, tokens: 200)
            ],
            modelUsage: nil,
            isModelUsagePartial: true
        )

        let observations = AntigravityHoverDashboardPresentation
            .dayObservations(from: usage, now: now, calendar: calendar)

        XCTAssertEqual(observations.count, 30)
        XCTAssertEqual(observations.suffix(2).first?.tokens, 150)
        XCTAssertEqual(observations.last?.tokens, 200)
        XCTAssertNil(observations.first?.tokens)
        XCTAssertEqual(
            AntigravityHoverDashboardPresentation.todayTokens(
                in: observations,
                now: now,
                calendar: calendar
            ),
            200
        )
    }

    func testDashboardShipMomentumRequiresObservedToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 14,
            hour: 12
        )))
        let yesterday = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: now)
        )
        let yesterdayOnly = CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: 500,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(
                    startDate: yesterday,
                    tokens: 500
                )
            ],
            modelUsage: nil,
            isModelUsagePartial: true
        )
        let missingToday = AntigravityHoverDashboardPresentation
            .dayObservations(
                from: yesterdayOnly,
                now: now,
                calendar: calendar
            )
        XCTAssertNil(
            AntigravityHoverDashboardPresentation.shipMomentum(
                from: missingToday,
                now: now,
                calendar: calendar
            )
        )

        let explicitToday = AntigravityHoverDashboardPresentation
            .dayObservations(
                from: CodexAccountTokenUsage(
                    lifetimeTokens: nil,
                    peakDailyTokens: 12_000_000,
                    longestRunningTurnSeconds: nil,
                    dailyUsageBuckets: [
                        CodexTokenUsageDailyBucket(
                            startDate: now,
                            tokens: 12_000_000
                        )
                    ],
                    modelUsage: nil,
                    isModelUsagePartial: true
                ),
                now: now,
                calendar: calendar
            )
        let momentum = try XCTUnwrap(
            AntigravityHoverDashboardPresentation.shipMomentum(
                from: explicitToday,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertEqual(momentum.todayTokens, 12_000_000)
        XCTAssertGreaterThan(momentum.score, 10)
    }

    private static func session(
        input: Int64,
        output: Int64,
        at date: Date
    ) -> AntigravitySessionSnapshot {
        AntigravitySessionSnapshot(
            id: String(repeating: "a", count: 64),
            modelID: "gemini-pro",
            modelDisplayName: "Gemini Pro",
            cliVersion: "1.2.2",
            planTier: "pro",
            agentState: "working",
            executionMode: "headless",
            taskCount: 1,
            artifactCount: 0,
            pendingInputCount: 0,
            toolConfirmationPending: false,
            context: AntigravityContextUsage(
                totalInputTokens: input,
                totalOutputTokens: output,
                contextWindowSize: 200_000,
                usedPercent: nil,
                remainingPercent: nil,
                currentInputTokens: nil,
                currentOutputTokens: nil,
                cacheCreationInputTokens: nil,
                cacheReadInputTokens: nil
            ),
            observedAt: date
        )
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DockMagic-AntigravityTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    private func runStatusLineBridge(_ scriptURL: URL, payload: String) throws {
        let process = Process()
        let input = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        process.standardInput = input
        try process.run()
        input.fileHandleForWriting.write(Data(payload.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    private func writeHistorySample(
        to url: URL,
        input: Int64,
        output: Int64,
        at date: Date
    ) throws {
        let payload: [String: Any] = [
            "schema_version": 1,
            "observed_at": date.timeIntervalSince1970,
            "model": ["id": "gemini-pro"],
            "context_window": [
                "total_input_tokens": input,
                "total_output_tokens": output
            ]
        ]
        try JSONSerialization.data(withJSONObject: payload).write(to: url)
    }

    private static let usageJSON = #"{"conversation_id":"","status":"SUCCESS","response":"ignored","duration_seconds":0,"num_turns":0,"usage":{"input_tokens":0,"output_tokens":0},"command":{"name":"usage","data":{"description":"Quota is shared within each group.","groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly","name":"Weekly Limit Remaining","window":"weekly","remaining_fraction":1,"reset_time":"2026-09-21T14:29:56.590Z"}]},{"name":"Claude and GPT models","buckets":[{"id":"3p-weekly","name":"Weekly Limit Remaining","window":"weekly","remaining_fraction":0,"reset_time":"2026-09-15T08:08:56.761Z"}]}]}}}"#
}

private actor RecordingAntigravityRunner: InstallerProcessRunning {
    struct Call: Sendable {
        let arguments: [String]
        let environment: [String: String]
        let timeout: TimeInterval
    }

    private(set) var calls: [Call] = []
    let output: String

    init(output: String) { self.output = output }

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> InstallerProcessResult {
        calls.append(Call(
            arguments: arguments,
            environment: environment,
            timeout: timeout
        ))
        return InstallerProcessResult(terminationStatus: 0, output: output)
    }
}

private actor SequencedAntigravityProvider: AntigravityQuotaProviding {
    private var results: [
        Result<AntigravityQuotaSnapshot, AntigravityUsageError>
    ]
    private(set) var callCount = 0

    init(
        results: [Result<AntigravityQuotaSnapshot, AntigravityUsageError>]
    ) {
        self.results = results
    }

    func fetchQuota(executableURL: URL) async throws
        -> AntigravityQuotaSnapshot {
        callCount += 1
        guard !results.isEmpty else {
            throw AntigravityUsageError.commandFailed
        }
        return try results.removeFirst().get()
    }
}

private actor CancellableAntigravityProvider: AntigravityQuotaProviding {
    let snapshot: AntigravityQuotaSnapshot
    private var firstCallStarted = false
    private(set) var callCount = 0

    init(snapshot: AntigravityQuotaSnapshot) {
        self.snapshot = snapshot
    }

    func fetchQuota(executableURL: URL) async throws
        -> AntigravityQuotaSnapshot {
        callCount += 1
        if callCount == 1 {
            firstCallStarted = true
            try await Task.sleep(for: .seconds(30))
        }
        return snapshot
    }

    func waitUntilStarted() async {
        while !firstCallStarted { await Task.yield() }
    }
}

private actor PausingSecondAntigravityProvider: AntigravityQuotaProviding {
    let snapshot: AntigravityQuotaSnapshot
    private var callCount = 0
    private var secondCallStarted = false
    private var secondCallContinuation: CheckedContinuation<Void, Never>?

    init(snapshot: AntigravityQuotaSnapshot) {
        self.snapshot = snapshot
    }

    func fetchQuota(executableURL: URL) async throws
        -> AntigravityQuotaSnapshot {
        callCount += 1
        if callCount == 2 {
            secondCallStarted = true
            await withCheckedContinuation {
                secondCallContinuation = $0
            }
        }
        return snapshot
    }

    func waitUntilSecondCallStarted() async {
        while !secondCallStarted { await Task.yield() }
    }

    func resumeSecondCall() {
        secondCallContinuation?.resume()
        secondCallContinuation = nil
    }
}

private actor SuspendedAntigravityAuthenticator:
    AntigravityAuthenticationProviding
{
    private var isStarted = false
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var signOutCount = 0

    func signOut(executableURL: URL) async throws {
        signOutCount += 1
        isStarted = true
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilStarted() async {
        while !isStarted { await Task.yield() }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private struct FixedAntigravityLocator: AntigravityExecutableLocating {
    func locate() throws -> URL { URL(fileURLWithPath: "/usr/bin/true") }
}

private struct MissingAntigravityLocator: AntigravityExecutableLocating {
    func locate() throws -> URL {
        throw AntigravityUsageError.executableNotFound
    }
}

private struct FixedAntigravityProvider: AntigravityQuotaProviding {
    let snapshot: AntigravityQuotaSnapshot
    func fetchQuota(executableURL: URL) async throws -> AntigravityQuotaSnapshot {
        snapshot
    }
}

private struct FailingAntigravityProvider: AntigravityQuotaProviding {
    let error: AntigravityUsageError

    func fetchQuota(executableURL: URL) async throws
        -> AntigravityQuotaSnapshot {
        throw error
    }
}

private actor CountingAntigravityProvider: AntigravityQuotaProviding {
    private(set) var callCount = 0
    let result: Result<AntigravityQuotaSnapshot, AntigravityUsageError>

    init(
        result: Result<AntigravityQuotaSnapshot, AntigravityUsageError>
    ) {
        self.result = result
    }

    func fetchQuota(executableURL: URL) async throws
        -> AntigravityQuotaSnapshot {
        callCount += 1
        return try result.get()
    }
}

@MainActor
private final class FakeAntigravityBridge: AntigravityStatusLineBridging {
    let sessionsDirectoryURL: URL
    init(sessionsDirectoryURL: URL) {
        self.sessionsDirectoryURL = sessionsDirectoryURL
    }
    func isInstalled() -> Bool { false }
    func install() throws {}
    func uninstall() throws {}
}

@MainActor
private final class FakeAntigravityStreakTracker: TokenUsageStreakTracking {
    func observeToday(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar
    ) -> TokenUsageStreakSummary {
        .fixture(currentDays: 1, bestDays: 1, endingAt: observedAt)
    }

    func observeHistory(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar
    ) -> TokenUsageStreakSummary {
        .fixture(currentDays: 1, bestDays: 1, endingAt: observedAt)
    }
}

private final class LockedSessionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AntigravitySessionSnapshot]

    init(_ value: [AntigravitySessionSnapshot]) { storage = value }

    var value: [AntigravitySessionSnapshot] {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}
