import XCTest
import AppKit
import SwiftUI
import CoreImage
@testable import DockMagic

final class ClaudeCodeUsageConnectionTests: XCTestCase {
    func testAuthStatusParsesSignedInSubscription() async throws {
        let provider = ClaudeCodeAuthStatusProvider(
            runner: StubInstallerRunner(
                auth: .init(
                    terminationStatus: 0,
                    output: #"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}"#
                ),
                version: .init(terminationStatus: 0, output: "2.1.268 (Claude Code)")
            )
        )

        let status = try await provider.status(
            executableURL: URL(fileURLWithPath: "/tmp/claude")
        )

        XCTAssertTrue(status.loggedIn)
        XCTAssertEqual(status.authInfo.authMethod, "claude.ai")
        XCTAssertTrue(status.authInfo.isSubscriptionLogin)
        XCTAssertEqual(status.version, "2.1.268")
    }

    func testAuthStatusAcceptsSignedOutExitCodeOne() async throws {
        let provider = ClaudeCodeAuthStatusProvider(
            runner: StubInstallerRunner(
                auth: .init(
                    terminationStatus: 1,
                    output: #"{"loggedIn":false,"authMethod":null,"apiProvider":null}"#
                ),
                version: .init(terminationStatus: 0, output: "2.1.268")
            )
        )

        let status = try await provider.status(
            executableURL: URL(fileURLWithPath: "/tmp/claude")
        )
        XCTAssertFalse(status.loggedIn)
    }

    func testAuthStatusRejectsMalformedJSON() async {
        let provider = ClaudeCodeAuthStatusProvider(
            runner: StubInstallerRunner(
                auth: .init(terminationStatus: 0, output: "not-json"),
                version: .init(terminationStatus: 0, output: "2.1.268")
            )
        )

        await XCTAssertThrowsErrorAsync(
            try await provider.status(
                executableURL: URL(fileURLWithPath: "/tmp/claude")
            )
        ) { error in
            XCTAssertEqual(error as? ClaudeCodeAuthStatusError, .malformedResponse)
        }
    }

    func testAuthStatusSurfacesMissingBinary() async {
        let provider = ClaudeCodeAuthStatusProvider(
            runner: FailingInstallerRunner()
        )
        await XCTAssertThrowsErrorAsync(
            try await provider.status(
                executableURL: URL(fileURLWithPath: "/missing/claude")
            )
        ) { error in
            guard case .commandFailed = error as? ClaudeCodeAuthStatusError else {
                return XCTFail("Expected a command failure")
            }
        }
    }

    func testAPIBillingIsNotPresentedAsSubscriptionQuota() async throws {
        let provider = ClaudeCodeAuthStatusProvider(
            runner: StubInstallerRunner(
                auth: .init(
                    terminationStatus: 0,
                    output: #"{"loggedIn":true,"authMethod":"api_key","apiProvider":"anthropic"}"#
                ),
                version: .init(terminationStatus: 0, output: "2.1.268")
            )
        )
        let status = try await provider.status(
            executableURL: URL(fileURLWithPath: "/tmp/claude")
        )
        XCTAssertFalse(status.authInfo.isSubscriptionLogin)
    }

    func testAuthProviderUsesOfficialLogoutCommand() async throws {
        let runner = RecordingInstallerRunner(
            result: .init(terminationStatus: 0, output: "Logged out")
        )
        let provider = ClaudeCodeAuthStatusProvider(runner: runner)

        try await provider.signOut(
            executableURL: URL(fileURLWithPath: "/tmp/claude")
        )

        let calls = await runner.arguments
        XCTAssertEqual(calls, [["auth", "logout"]])
    }

    func testAuthProviderSurfacesLogoutFailure() async {
        let runner = RecordingInstallerRunner(
            result: .init(terminationStatus: 1, output: "Logout failed")
        )
        let provider = ClaudeCodeAuthStatusProvider(runner: runner)

        await XCTAssertThrowsErrorAsync(
            try await provider.signOut(
                executableURL: URL(fileURLWithPath: "/tmp/claude")
            )
        ) { error in
            XCTAssertEqual(
                error as? ClaudeCodeAuthStatusError,
                .commandFailed("Logout failed")
            )
        }
    }

    func testUsageParserIgnoresModelSpecificWeekAndStripsANSI() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let output = """
        \u{001B}[2JCurrent session
        ███████ 37% used
        Resets in 2 hr 15 min

        Current week (Sonnet only)
        ███████ 91% used
        Resets Sep 20 at 5:00 PM

        Current week (all models)
        ███████ 62% used
        Resets Sep 18 at 7:00 PM (Asia/Ho_Chi_Minh)
        Esc to cancel
        """

        let parsed = try ClaudeCodeUsageOutputParser.parse(output, now: now)
        XCTAssertEqual(parsed.fiveHour.usedPercent, 37)
        XCTAssertEqual(parsed.fiveHour.windowDurationMinutes, 300)
        XCTAssertEqual(parsed.weekly.usedPercent, 62)
        XCTAssertEqual(parsed.weekly.windowDurationMinutes, 10_080)
        XCTAssertEqual(
            parsed.fiveHour.resetsAt,
            now.addingTimeInterval(2 * 3_600 + 15 * 60)
        )
        XCTAssertNotNil(parsed.weekly.resetsAt)
    }

    func testUsageParserKeepsQuotaWhenResetFormatChanges() throws {
        let output = """
        Current session
        140% used
        Resets whenever Claude decides
        Current week (all models)
        4% used
        Resets sometime next week
        Esc to cancel
        """
        let parsed = try ClaudeCodeUsageOutputParser.parse(output)
        XCTAssertEqual(parsed.fiveHour.usedPercent, 100)
        XCTAssertNil(parsed.fiveHour.resetsAt)
        XCTAssertEqual(parsed.weekly.usedPercent, 4)
        XCTAssertNil(parsed.weekly.resetsAt)
    }

    func testUsageParserHandlesRealScreenReaderRefreshStream() throws {
        let output = """
        you: /usage
        Settings  Status   Config   Usage   Stats
        Current session
        0% 0% used
        Resets 4:20am (Asia/Saigon)
        Current week (all models)
        58% 57% used
        Resets Sep 13 at 10am (Asia/Saigon)
        Refreshing…
        Esc to cancel
        59% 59% used
        Resets Sep 13 at 10am (Asia/Saigon)
        Usage credits
        0% 0% used
        $0.00 / $30.00 spent · Resets Oct 1 (Asia/Saigon)
        Esc to cancel
        """

        let parsed = try ClaudeCodeUsageOutputParser.parse(output)

        XCTAssertEqual(parsed.fiveHour.usedPercent, 0)
        XCTAssertEqual(parsed.weekly.usedPercent, 59)
        XCTAssertNotNil(parsed.fiveHour.resetsAt)
        XCTAssertNotNil(parsed.weekly.resetsAt)
    }

    func testUsageParserRefreshesBothWindowsWithoutMixingUnlabelledRows() throws {
        let initial = """
        Current session
        17% 17% used
        Resets 1:50pm (Asia/Saigon)
        Current week (all models)
        24% 24% used
        Resets Sep 20 at 10am (Asia/Saigon)
        Refreshing…
        Esc to cancel
        """
        let output = initial + """
        18% 18% used
        Resets 1:50pm (Asia/Saigon)
        Current week (all models)
        25% 25% used
        Resets Sep 20 at 10am (Asia/Saigon)
        What's contributing to your limits usage?
        55% of your usage came from local sessions
        Usage credits
        0% 0% used
        Esc to cancel
        """
        let parsed = try ClaudeCodeUsageOutputParser.parse(output)
        XCTAssertEqual(parsed.fiveHour.usedPercent, 18)
        XCTAssertEqual(parsed.weekly.usedPercent, 25)

        let onlySessionRedraw = initial + """
        19% 19% used
        Resets 1:50pm (Asia/Saigon)
        Esc to cancel
        """
        let sessionOnly = try ClaudeCodeUsageOutputParser.parse(onlySessionRedraw)
        XCTAssertEqual(sessionOnly.fiveHour.usedPercent, 19)
        XCTAssertEqual(sessionOnly.weekly.usedPercent, 24)
    }

    func testUsageParserRejectsPartialOrChangedOutput() {
        XCTAssertThrowsError(
            try ClaudeCodeUsageOutputParser.parse(
                "Current session\n12% used\nEsc to cancel"
            )
        ) { error in
            XCTAssertEqual(
                error as? ClaudeCodeUsageCaptureError,
                .outputFormatChanged
            )
        }
    }

    func testUsageParserDoesNotAssignAnAmbiguousUnlabelledReset() throws {
        let output = """
        Current session
        17% used
        Resets in 2h
        Current week (all models)
        24% used
        Resets in 2h
        Refreshing…
        Esc to cancel
        19% used
        Resets in 2h
        Esc to cancel
        """
        let parsed = try ClaudeCodeUsageOutputParser.parse(output)
        XCTAssertEqual(parsed.fiveHour.usedPercent, 17)
        XCTAssertEqual(parsed.weekly.usedPercent, 24)
    }

    func testUsageParserRecognizesSignedOutOutput() {
        XCTAssertThrowsError(
            try ClaudeCodeUsageOutputParser.parse(
                "Please log in to use Claude Code."
            )
        ) { error in
            XCTAssertEqual(error as? ClaudeCodeUsageCaptureError, .signedOut)
        }
    }

    @MainActor
    func testPTYCaptureWaitsForReadinessSendsUsageAndEscapes() async throws {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(
                initialText: "Claude Code\nWhat can I help you with?",
                usageResponse: .immediate(Self.completeUsageOutput)
            )
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        let capture = try await collector.capture()

        XCTAssertEqual(capture.fiveHour.usedPercent, 21)
        XCTAssertEqual(capture.weekly.usedPercent, 43)
        let session = try XCTUnwrap(builder.sessions.first)
        XCTAssertEqual(
            session.startedArguments,
            ["--safe-mode", "--ax-screen-reader", "--no-chrome"]
        )
        XCTAssertTrue(
            session.startedEnvironment.contains(
                "CLAUDE_CODE_SKIP_PROMPT_HISTORY=1"
            )
        )
        XCTAssertEqual(session.sentText, ["/usage\r"])
        XCTAssertEqual(session.sentBytes.filter { $0 == [0x1b] }.count, 1)
        XCTAssertEqual(session.clearCount, 1)
    }

    @MainActor
    func testPTYCaptureTrustsOnlyOwnedWorkerDirectoryBeforeUsage() async throws {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(
                initialText: """
                Permission Required: Accessing workspace:
                /private/tmp/DockMagic-ClaudeCode
                y. Yes, I trust this folder
                """,
                usageResponse: .immediate(Self.completeUsageOutput),
                trustResponse: "Claude Code v2.1.268\n-- INSERT --\n$"
            )
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        let capture = try await collector.capture()

        XCTAssertEqual(capture.weekly.usedPercent, 43)
        let session = try XCTUnwrap(builder.sessions.first)
        XCTAssertEqual(session.sentText, ["y\r", "/usage\r"])
    }

    @MainActor
    func testPTYCaptureWaitsForRefreshedUsageRedraw() async throws {
        let cached = """
        Current session
        0% used
        Resets 4:20am
        Current week (all models)
        57% used
        Resets Sep 13 at 10am
        Refreshing…
        Esc to cancel
        """
        let refreshed = """
        59% used
        Resets Sep 13 at 10am
        Usage credits
        0% used
        Esc to cancel
        """
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(
                initialText: Self.readyPrompt,
                usageResponse: .progressive(
                    cached: cached,
                    refreshed: refreshed,
                    delay: .milliseconds(4)
                )
            )
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        let capture = try await collector.capture()

        XCTAssertEqual(capture.fiveHour.usedPercent, 0)
        XCTAssertEqual(capture.weekly.usedPercent, 59)
    }

    @MainActor
    func testPTYCaptureCoalescesConcurrentRefreshes() async throws {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(
                initialText: Self.readyPrompt,
                usageResponse: .delayed(
                    Self.completeUsageOutput,
                    .milliseconds(4)
                )
            )
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        let first = Task { @MainActor in try await collector.capture() }
        let second = Task { @MainActor in try await collector.capture() }
        _ = try await (first.value, second.value)

        let session = try XCTUnwrap(builder.sessions.first)
        XCTAssertEqual(session.sentText.filter { $0 == "/usage\r" }.count, 1)
        XCTAssertEqual(builder.sessions.count, 1)
    }

    @MainActor
    func testPTYCaptureRestartsOnceAfterTimeout() async throws {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(initialText: Self.readyPrompt, usageResponse: .none),
            .init(
                initialText: Self.readyPrompt,
                usageResponse: .immediate(Self.completeUsageOutput)
            )
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        let capture = try await collector.capture()

        XCTAssertEqual(capture.weekly.usedPercent, 43)
        XCTAssertEqual(builder.sessions.count, 2)
        XCTAssertEqual(builder.sessions[0].terminateCount, 1)
    }

    @MainActor
    func testPTYCaptureTimesOutAfterSingleRestart() async {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(initialText: Self.readyPrompt, usageResponse: .none),
            .init(initialText: Self.readyPrompt, usageResponse: .none)
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        await XCTAssertThrowsErrorAsync(try await collector.capture()) { error in
            XCTAssertEqual(error as? ClaudeCodeUsageCaptureError, .timedOut)
        }
        XCTAssertEqual(builder.sessions.count, 2)
    }

    @MainActor
    func testPTYCaptureDoesNotSendUsageBeforePromptIsReady() async {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(initialText: "Starting…", usageResponse: .none),
            .init(initialText: "Starting…", usageResponse: .none)
        ])
        let collector = makePTYCollector(builder: builder)
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )

        await XCTAssertThrowsErrorAsync(try await collector.capture())

        XCTAssertTrue(builder.sessions.allSatisfy { $0.sentText.isEmpty })
    }

    @MainActor
    func testPTYStopInterruptsThenTerminatesRunningProcess() async throws {
        let builder = FakeUsageTerminalBuilder(plans: [
            .init(
                initialText: Self.readyPrompt,
                usageResponse: .immediate(Self.completeUsageOutput)
            )
        ])
        let collector = makePTYCollector(
            builder: builder,
            stopGracePeriod: .milliseconds(2)
        )
        collector.configure(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            cliVersion: "2.1.268"
        )
        _ = try await collector.capture()
        let session = try XCTUnwrap(builder.sessions.first)

        collector.stop()
        try? await Task.sleep(for: .milliseconds(10))

        XCTAssertTrue(session.sentBytes.contains([0x03]))
        XCTAssertEqual(session.terminateCount, 1)
    }

    @MainActor
    func testStoreUsesOnlyPTYQuotaAndDoesNotRequireStatusLineBridge() async {
        let telemetry = sampleSnapshot(fiveHour: 99, weekly: 98)
        let collector = StubUsageCollector(results: [
            .success(sampleCapture(fiveHour: 23, weekly: 41))
        ])
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: telemetry),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: FixedClaudeAuthProvider(loggedIn: true),
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))

        await store.refresh()

        XCTAssertEqual(store.state.snapshot?.fiveHour?.usedPercent, 23)
        XCTAssertEqual(store.state.snapshot?.weekly?.usedPercent, 41)
        XCTAssertEqual(collector.captureCount, 1)
        guard case .connected = store.connectionState else {
            return XCTFail("Expected connected state")
        }
    }

    @MainActor
    func testBackgroundQuotaRefreshKeepsConnectedPresentation() async {
        let capture = sampleCapture(fiveHour: 23, weekly: 41)
        let collector = PausingSecondClaudeUsageCollector(capture: capture)
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: FixedClaudeAuthProvider(loggedIn: true),
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        await store.refresh()
        let settledState = store.connectionState

        let refresh = Task { await store.refresh() }
        await collector.waitUntilSecondCaptureStarted()

        XCTAssertEqual(store.connectionState, settledState)
        XCTAssertTrue(store.isRefreshing)

        collector.resumeSecondCapture()
        await refresh.value
    }

    @MainActor
    func testSettingsSeparatesSetupFromQuotaLoading() {
        let authInfo = ClaudeCodeAuthInfo(
            authMethod: "claude.ai",
            apiProvider: "firstParty"
        )

        XCTAssertFalse(
            ClaudeCodeConnectionSettingsView.displaysConnectionSummary(
                for: .checking
            )
        )
        XCTAssertTrue(
            ClaudeCodeConnectionSettingsView.displaysConnectionSummary(
                for: .signedInWaitingForQuota(authInfo)
            )
        )
        XCTAssertTrue(
            ClaudeCodeConnectionSettingsView.displaysConnectionSummary(
                for: .signingIn
            )
        )
        XCTAssertTrue(
            ClaudeCodeConnectionSettingsView.displaysConnectionSummary(
                for: .signingOut
            )
        )
        XCTAssertEqual(
            ClaudeCodeConnectionSettingsView.actionPresentation(
                for: .checking,
                hasAuthenticatedContext: false
            ),
            .signIn
        )
        XCTAssertEqual(
            ClaudeCodeConnectionSettingsView.actionPresentation(
                for: .checking,
                hasAuthenticatedContext: true
            ),
            .authenticated
        )
        XCTAssertEqual(
            ClaudeCodeConnectionSettingsView.actionPresentation(
                for: .signedInWaitingForQuota(authInfo),
                hasAuthenticatedContext: true
            ),
            .authenticated
        )
    }

    @MainActor
    func testStorePreservesLastQuotaWhenPTYRefreshFails() async {
        let collector = StubUsageCollector(results: [
            .success(sampleCapture(fiveHour: 18, weekly: 52)),
            .failure(ClaudeCodeUsageCaptureError.timedOut)
        ])
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: FixedClaudeAuthProvider(loggedIn: true),
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        await store.refresh()
        await store.refresh()

        XCTAssertEqual(store.state.snapshot?.fiveHour?.usedPercent, 18)
        guard case .stale = store.state else {
            return XCTFail("Expected stale state")
        }
        guard case .stale = store.connectionState else {
            return XCTFail("Expected stale connection")
        }
    }

    @MainActor
    func testSignedOutAuthNeverStartsUsageCapture() async {
        let collector = StubUsageCollector(results: [])
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: FixedClaudeAuthProvider(loggedIn: false),
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        await store.refresh()

        XCTAssertEqual(collector.captureCount, 0)
        XCTAssertGreaterThan(collector.stopCount, 0)
        guard case .signedOut = store.connectionState else {
            return XCTFail("Expected signed-out connection state")
        }
    }

    @MainActor
    func testStoreSignOutStopsPTYAndClearsQuota() async {
        let auth = RecordingClaudeAuthProvider()
        let collector = StubUsageCollector(results: [
            .success(sampleCapture(fiveHour: 18, weekly: 52))
        ])
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: auth,
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        await store.refresh()

        await store.signOut()

        let signOutCount = await auth.signOutCount
        XCTAssertEqual(signOutCount, 1)
        XCTAssertGreaterThan(collector.stopCount, 0)
        XCTAssertNil(store.state.snapshot?.fiveHour)
        XCTAssertNil(store.state.snapshot?.weekly)
        guard case .signedOut = store.connectionState else {
            return XCTFail("Expected signed-out connection state")
        }
    }

    @MainActor
    func testStoreKeepsLastQuotaWhenSignOutFails() async {
        let auth = RecordingClaudeAuthProvider(failsSignOut: true)
        let collector = StubUsageCollector(results: [
            .success(sampleCapture(fiveHour: 18, weekly: 52))
        ])
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: auth,
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        await store.refresh()

        await store.signOut()

        XCTAssertEqual(store.state.snapshot?.fiveHour?.usedPercent, 18)
        XCTAssertEqual(store.state.snapshot?.weekly?.usedPercent, 52)
        guard case .stale = store.connectionState else {
            return XCTFail("Expected stale state after failed sign out")
        }
    }

    @MainActor
    func testActivityHookRefreshDoesNotIssueUsageCommand() async {
        let collector = StubUsageCollector(results: [])
        let activity = TestClaudeActivityBridge()
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: activity,
            authProvider: FixedClaudeAuthProvider(loggedIn: true),
            usageCollector: collector
        )

        await store.installActivityHook()

        XCTAssertTrue(store.isActivityHookInstalled)
        XCTAssertEqual(collector.captureCount, 0)
        XCTAssertNotNil(store.state.snapshot)
    }

    @MainActor
    func testMigrationRemovesOwnedStatusLineBridgeWithoutTouchingActivityHook() {
        let bridge = TestClaudeStatusLineBridge(installed: true)
        let activity = TestClaudeActivityBridge(installed: true)
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: bridge,
            activityHookBridge: activity,
            authProvider: FixedClaudeAuthProvider(loggedIn: false),
            usageCollector: StubUsageCollector(results: [])
        )

        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))

        XCTAssertEqual(bridge.uninstallCount, 1)
        XCTAssertFalse(store.isBridgeInstalled)
        XCTAssertTrue(activity.isInstalled())
    }

    @MainActor
    func testStoreStopAndWakeRestartQuotaLifecycle() async {
        let collector = StubUsageCollector(results: [
            .success(sampleCapture(fiveHour: 11, weekly: 22)),
            .success(sampleCapture(fiveHour: 12, weekly: 23))
        ])
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: FixedClaudeAuthProvider(loggedIn: true),
            usageCollector: collector
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        await store.refresh()

        await store.refreshAfterInterruption()

        XCTAssertEqual(collector.captureCount, 2)
        XCTAssertGreaterThan(collector.stopCount, 0)
        store.stop()
        XCTAssertFalse(store.isMonitoring)
        XCTAssertGreaterThan(collector.stopCount, 1)
    }

    @MainActor
    func testManualRefreshRearmsPollingWithoutImmediateDuplicateCapture() async {
        let collector = StubUsageCollector(results: (0..<6).map { index in
            .success(
                sampleCapture(
                    fiveHour: 10 + index,
                    weekly: 20 + index
                )
            )
        })
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: FixedClaudeAuthProvider(loggedIn: true),
            usageCollector: collector,
            pollingInterval: .milliseconds(25)
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        store.start()
        try? await Task.sleep(for: .milliseconds(5))
        XCTAssertEqual(collector.captureCount, 1)

        await store.refresh()
        XCTAssertEqual(collector.captureCount, 2)
        try? await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(
            collector.captureCount,
            2,
            "Manual refresh should re-arm, not immediately duplicate, /usage."
        )

        try? await Task.sleep(for: .milliseconds(25))
        XCTAssertGreaterThanOrEqual(collector.captureCount, 3)
        store.stop()
    }

    @MainActor
    func testExternalLogoutCannotRestoreQuotaFromActivity() async {
        let auth = RecordingClaudeAuthProvider()
        let store = connectionStore(auth: auth)
        await store.refresh()
        XCTAssertNotNil(store.state.snapshot?.fiveHour)
        await auth.setLoggedIn(false)
        await store.refresh()
        XCTAssertEqual(store.connectionState, .signedOut)
        XCTAssertFalse(store.hasAuthenticatedConnectionContext)
        await store.installActivityHook()
        XCTAssertNil(store.state.snapshot?.fiveHour)
        XCTAssertNil(store.state.snapshot?.weekly)
    }

    @MainActor
    func testPTYSignedOutClearsAuthenticationAndQuota() async {
        let collector = StubUsageCollector(results: [
            .success(sampleCapture(fiveHour: 18, weekly: 52)),
            .failure(ClaudeCodeUsageCaptureError.signedOut)
        ])
        let store = connectionStore(auth: RecordingClaudeAuthProvider(), collector: collector)
        await store.refresh()
        await store.refresh()
        XCTAssertEqual(store.connectionState, .signedOut)
        XCTAssertFalse(store.hasAuthenticatedConnectionContext)
        XCTAssertNil(store.state.snapshot?.fiveHour)
        XCTAssertNil(store.state.snapshot?.weekly)
    }

    @MainActor
    func testSignOutBlocksRefreshUntilSignedOutProbeCompletes() async {
        let auth = RecordingClaudeAuthProvider(pauseVerification: true)
        let collector = StubUsageCollector(results: [.success(sampleCapture(fiveHour: 18, weekly: 52))])
        let store = connectionStore(auth: auth, collector: collector)
        await store.refresh()
        let logout = Task { await store.signOut() }
        await auth.waitUntilVerificationStarted()
        XCTAssertEqual(store.connectionState, .signingOut)
        await store.refresh()
        await store.refreshAfterInterruption()
        XCTAssertEqual(store.connectionState, .signingOut)
        XCTAssertEqual(collector.captureCount, 1)
        let duplicate = Task { await store.signOut() }
        await auth.resumeVerification()
        await logout.value
        await duplicate.value
        XCTAssertEqual(store.connectionState, .signedOut)
        let count = await auth.signOutCount
        XCTAssertEqual(count, 1)
        XCTAssertFalse(store.hasAuthenticatedConnectionContext)
    }

    @MainActor
    func testSuccessfulLogoutCommandStillRequiresSignedOutStatus() async {
        let auth = RecordingClaudeAuthProvider(keepsSessionAfterLogout: true)
        let store = connectionStore(auth: auth)
        await store.refresh()
        await store.signOut()
        guard case let .stale(_, message) = store.connectionState else {
            return XCTFail("A successful command must not override a still-signed-in probe.")
        }
        XCTAssertTrue(message.contains("still reports a signed-in session"))
        XCTAssertTrue(store.hasAuthenticatedConnectionContext)
    }

    @MainActor
    func testFailedSignOutWithoutQuotaStillOffersSignOut() async {
        let auth = RecordingClaudeAuthProvider(failsSignOut: true)
        let store = connectionStore(auth: auth, collector: StubUsageCollector(results: [
            .failure(ClaudeCodeUsageCaptureError.timedOut)
        ]))
        await store.refresh()
        await store.signOut()
        guard case .failed = store.connectionState else { return XCTFail("Expected logout error") }
        XCTAssertTrue(store.hasAuthenticatedConnectionContext)
        XCTAssertEqual(ClaudeCodeConnectionSettingsView.actionPresentation(
            for: store.connectionState,
            hasAuthenticatedContext: store.hasAuthenticatedConnectionContext
        ), .stale, "Retry and the Sign Out menu must remain available without a quota snapshot.")
    }

    @MainActor
    func testSignInFinishesWithFreshProbeInsteadOfJoiningCancelledRefresh() async {
        let collector = PausingSecondClaudeUsageCollector(capture: sampleCapture(fiveHour: 18, weekly: 52))
        let store = connectionStore(auth: RecordingClaudeAuthProvider(), collector: collector)
        await store.refresh()
        let oldRefresh = Task { await store.refresh() }
        await collector.waitUntilSecondCaptureStarted()
        store.beginSignIn()
        await store.refresh()
        XCTAssertEqual(store.connectionState, .signingIn)
        await store.loginProcessDidFinish()
        guard case .connected = store.connectionState else { return XCTFail("Expected a fresh quota capture") }
        collector.resumeSecondCapture()
        await oldRefresh.value
        guard case .connected = store.connectionState else { return XCTFail("Cancelled work changed connection state") }
    }

    @MainActor
    func testPTYRecognizesSignedOutBeforeUsageAndDuringUsage() async {
        for plan in [
            FakeUsageTerminalBuilder.Plan(initialText: "Not logged in. Please run /login", usageResponse: .none),
            FakeUsageTerminalBuilder.Plan(initialText: Self.readyPrompt, usageResponse: .immediate("Not logged in"))
        ] {
            let builder = FakeUsageTerminalBuilder(plans: [plan])
            let collector = makePTYCollector(builder: builder)
            collector.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"), cliVersion: "2.1.273")
            do {
                _ = try await collector.capture()
                XCTFail("Expected authentication failure")
            } catch {
                XCTAssertEqual(error as? ClaudeCodeUsageCaptureError, .signedOut)
                XCTAssertEqual(builder.sessions.count, 1, "Authentication errors must not be retried as timeouts.")
            }
            collector.stop()
        }
    }

    @MainActor
    func testConnectionCardsAppearanceMatrix() async throws {
        let connected = connectionStore(auth: RecordingClaudeAuthProvider())
        let signedOut = connectionStore(auth: FixedClaudeAuthProvider(loggedIn: false))
        let unavailable = connectionStore(auth: RecordingClaudeAuthProvider(), collector: StubUsageCollector(results: [
            .failure(ClaudeCodeUsageCaptureError.timedOut)
        ]))
        for store in [connected, signedOut, unavailable] { await store.refresh() }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("connection-preview-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        func antigravity(signedOut: Bool) -> AntigravityUsageStore {
            let adapter = ConnectionPreviewAntigravity(signedOut: signedOut)
            return AntigravityUsageStore(
                provider: adapter, locator: adapter,
                bridge: AntigravityStatusLineBridge(home: temporary),
                cacheURL: temporary.appendingPathComponent("\(signedOut).json"),
                readSessions: { [] }, readHistorySessions: { _ in [] }
            )
        }
        let agConnected = antigravity(signedOut: false)
        let agSignedOut = antigravity(signedOut: true)
        await agConnected.refresh()
        await agSignedOut.refresh()
        let cards = VStack(spacing: 16) {
            ClaudeCodeConnectionSettingsView(store: connected, installationState: .installed(path: "/tmp/claude"), installCLI: {})
            AntigravityConnectionSettingsView(store: agConnected, installationState: .installed(path: "/tmp/agy"), installCLI: {})
            ClaudeCodeConnectionSettingsView(store: signedOut, installationState: .installed(path: "/tmp/claude"), installCLI: {})
            AntigravityConnectionSettingsView(store: agSignedOut, installationState: .installed(path: "/tmp/agy"), installCLI: {})
            ClaudeCodeConnectionSettingsView(store: unavailable, installationState: .installed(path: "/tmp/claude"), installCLI: {})
        }.padding(20).frame(width: 900, height: 610)
        let variants: [(String, DSAppearanceMode, NSAppearance.Name, DSAccessibilityOverrides, Bool)] = [
            ("light", .light, .aqua, .init(), false),
            ("dark", .dark, .darkAqua, .init(), false),
            ("contrast", .dark, .accessibilityHighContrastDarkAqua, .init(increaseContrast: true), false),
            ("opaque", .dark, .darkAqua, .init(reduceTransparency: true), false),
            ("grayscale", .light, .aqua, .init(), true)
        ]
        let output = URL(fileURLWithPath: "/tmp/DockMagicConnectionAppearance", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, mode, appearance, overrides, grayscale) in variants {
            let content = DockMagicThemeRoot(content: cards, appearanceMode: mode)
                .environment(\.dsAccessibilityOverrides, overrides)
            let host = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 610), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: appearance)
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.contentView = host
            host.wantsLayer = true
            try await Task.sleep(for: .milliseconds(80))
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            var data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            if grayscale {
                let input = try XCTUnwrap(CIImage(data: data))
                let filter = try XCTUnwrap(CIFilter(name: "CIColorControls"))
                filter.setValue(input, forKey: kCIInputImageKey)
                filter.setValue(0, forKey: kCIInputSaturationKey)
                let output = try XCTUnwrap(filter.outputImage)
                let image = try XCTUnwrap(CIContext().createCGImage(output, from: output.extent))
                data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "Connection cards — " + name
            attachment.lifetime = .keepAlways
            add(attachment)
            window.contentView = nil
            window.close()
        }
    }

    /// Explicit local smoke check; never changes the real account session.
    @MainActor
    func testLiveClaudeQuotaIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["DockMagicLiveClaudeQuota"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_DockMagicLiveClaudeQuota=1 for a read-only local CLI check.")
        }
        let executable = try ClaudeCodeExecutableLocator().locate()
        let status = try await ClaudeCodeAuthStatusProvider().status(executableURL: executable)
        guard status.loggedIn else {
            throw XCTSkip("Claude CLI is signed out; the live check requires an existing login.")
        }
        let collector = ClaudeCodeUsageTerminalCollector()
        defer { collector.stop() }
        collector.configure(executableURL: executable, cliVersion: status.version)
        let quota = try await collector.capture()
        XCTAssertTrue((0...100).contains(quota.fiveHour.usedPercent))
        XCTAssertTrue((0...100).contains(quota.weekly.usedPercent))
        print("Live Claude CLI \(status.version): 5H used=\(quota.fiveHour.usedPercent), weekly used=\(quota.weekly.usedPercent)")
    }

    @MainActor
    private func connectionStore(
        auth: any ClaudeCodeAuthStatusProviding,
        collector: (any ClaudeCodeUsageCollecting)? = nil
    ) -> ClaudeCodeUsageStore {
        let store = ClaudeCodeUsageStore(
            provider: FixedClaudeTelemetryProvider(snapshot: sampleSnapshot()),
            bridge: TestClaudeStatusLineBridge(installed: false),
            activityHookBridge: TestClaudeActivityBridge(),
            authProvider: auth,
            usageCollector: collector ?? StubUsageCollector(results: [
                .success(sampleCapture(fiveHour: 18, weekly: 52))
            ])
        )
        store.configure(executableURL: URL(fileURLWithPath: "/tmp/claude"))
        return store
    }

    @MainActor
    private func makePTYCollector(
        builder: FakeUsageTerminalBuilder,
        stopGracePeriod: Duration = .milliseconds(1)
    ) -> ClaudeCodeUsageTerminalCollector {
        ClaudeCodeUsageTerminalCollector(
            sessionBuilder: builder,
            readyTimeout: .milliseconds(250),
            captureTimeout: .milliseconds(250),
            pollInterval: .milliseconds(1),
            settleDelay: .milliseconds(1),
            stopGracePeriod: stopGracePeriod
        )
    }

    private static let completeUsageOutput = """
    Current session
    21% used
    Resets in 2 hr
    Current week (all models)
    43% used
    Resets Sep 18 at 7:00 PM
    Esc to cancel
    """

    private static let readyPrompt = """
    Claude Code v2.1.268
    -- INSERT --
    $
    """

    private func sampleCapture(
        fiveHour: Int,
        weekly: Int
    ) -> ClaudeCodeQuotaCapture {
        ClaudeCodeQuotaCapture(
            fiveHour: .init(
                kind: .fiveHour,
                usedPercent: fiveHour,
                windowDurationMinutes: 300,
                resetsAt: nil
            ),
            weekly: .init(
                kind: .weekly,
                usedPercent: weekly,
                windowDurationMinutes: 10_080,
                resetsAt: nil
            ),
            capturedAt: Date(),
            cliVersion: "2.1.268"
        )
    }

    private func sampleSnapshot(
        fiveHour: Int? = nil,
        weekly: Int? = nil
    ) -> ClaudeCodeRateLimitSnapshot {
        .init(
            planType: nil,
            limitID: "local",
            fiveHour: fiveHour.map {
                .init(kind: .fiveHour, usedPercent: $0, windowDurationMinutes: 300, resetsAt: nil)
            },
            weekly: weekly.map {
                .init(kind: .weekly, usedPercent: $0, windowDurationMinutes: 10_080, resetsAt: nil)
            },
            fetchedAt: Date()
        )
    }
}

@MainActor
private final class FakeUsageTerminalBuilder:
    ClaudeCodeUsageTerminalSessionBuilding
{
    struct Plan {
        enum UsageResponse {
            case immediate(String)
            case delayed(String, Duration)
            case progressive(cached: String, refreshed: String, delay: Duration)
            case none
        }

        let initialText: String
        let usageResponse: UsageResponse
        let trustResponse: String?

        init(
            initialText: String,
            usageResponse: UsageResponse,
            trustResponse: String? = nil
        ) {
            self.initialText = initialText
            self.usageResponse = usageResponse
            self.trustResponse = trustResponse
        }
    }

    private var plans: [Plan]
    private(set) var sessions: [FakeUsageTerminalSession] = []

    init(plans: [Plan]) {
        self.plans = plans
    }

    func makeSession(
        onExit: @escaping (Int32?) -> Void
    ) -> any ClaudeCodeUsageTerminalSession {
        let plan = plans.isEmpty
            ? Plan(initialText: "", usageResponse: .none)
            : plans.removeFirst()
        let session = FakeUsageTerminalSession(plan: plan, onExit: onExit)
        sessions.append(session)
        return session
    }
}

@MainActor
private final class FakeUsageTerminalSession: ClaudeCodeUsageTerminalSession {
    private let plan: FakeUsageTerminalBuilder.Plan
    private let onExit: (Int32?) -> Void
    private(set) var isRunning = false
    private(set) var bufferText: String
    private(set) var startedArguments: [String] = []
    private(set) var startedEnvironment: [String] = []
    private(set) var sentText: [String] = []
    private(set) var sentBytes: [[UInt8]] = []
    private(set) var clearCount = 0
    private(set) var terminateCount = 0

    init(
        plan: FakeUsageTerminalBuilder.Plan,
        onExit: @escaping (Int32?) -> Void
    ) {
        self.plan = plan
        self.onExit = onExit
        bufferText = plan.initialText
    }

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String],
        currentDirectory: URL
    ) {
        isRunning = true
        startedArguments = arguments
        startedEnvironment = environment
    }

    func send(_ text: String) {
        sentText.append(text)
        if text == "y\r", let trustResponse = plan.trustResponse {
            bufferText = trustResponse
            return
        }
        guard text == "/usage\r" else { return }
        switch plan.usageResponse {
        case let .immediate(output):
            bufferText = output
        case let .delayed(output, delay):
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: delay)
                self?.bufferText = output
            }
        case let .progressive(cached, refreshed, delay):
            bufferText = cached
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: delay)
                self?.bufferText += "\n" + refreshed
            }
        case .none:
            break
        }
    }

    func send(bytes: [UInt8]) {
        sentBytes.append(bytes)
    }

    func clearScrollback() {
        clearCount += 1
        bufferText = ""
    }

    func terminate() {
        terminateCount += 1
        isRunning = false
        onExit(-15)
    }
}

private struct StubInstallerRunner: InstallerProcessRunning {
    let auth: InstallerProcessResult
    let version: InstallerProcessResult

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> InstallerProcessResult {
        arguments.first == "auth" ? auth : version
    }
}

private struct FailingInstallerRunner: InstallerProcessRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> InstallerProcessResult {
        throw CocoaError(.fileNoSuchFile)
    }
}

private actor RecordingInstallerRunner: InstallerProcessRunning {
    private let result: InstallerProcessResult
    private(set) var arguments: [[String]] = []

    init(result: InstallerProcessResult) {
        self.result = result
    }

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> InstallerProcessResult {
        self.arguments.append(arguments)
        return result
    }
}

private actor RecordingClaudeAuthProvider: ClaudeCodeAuthStatusProviding {
    private let failsSignOut: Bool
    private let keepsSessionAfterLogout: Bool
    private let pauseVerification: Bool
    private var loggedIn = true
    private var verificationStarted = false
    private var verificationContinuation: CheckedContinuation<Void, Never>?
    private(set) var signOutCount = 0

    init(failsSignOut: Bool = false, keepsSessionAfterLogout: Bool = false, pauseVerification: Bool = false) {
        self.failsSignOut = failsSignOut
        self.keepsSessionAfterLogout = keepsSessionAfterLogout
        self.pauseVerification = pauseVerification
    }

    func setLoggedIn(_ value: Bool) { loggedIn = value }
    func waitUntilVerificationStarted() async {
        while !verificationStarted { await Task.yield() }
    }
    func resumeVerification() {
        verificationContinuation?.resume()
        verificationContinuation = nil
    }

    func status(executableURL: URL) async throws -> ClaudeCodeCLIStatus {
        if !loggedIn && pauseVerification {
            verificationStarted = true
            await withCheckedContinuation { verificationContinuation = $0 }
        }
        return .init(
            loggedIn: loggedIn,
            authInfo: .init(
                authMethod: "claude.ai",
                apiProvider: "firstParty"
            ),
            version: "2.1.268"
        )
    }

    func signOut(executableURL: URL) async throws {
        signOutCount += 1
        if failsSignOut {
            throw ClaudeCodeAuthStatusError.commandFailed("Logout failed")
        }
        if !keepsSessionAfterLogout { loggedIn = false }
    }
}

struct FixedClaudeAuthProvider: ClaudeCodeAuthStatusProviding {
    let loggedIn: Bool

    func status(executableURL: URL) async throws -> ClaudeCodeCLIStatus {
        .init(
            loggedIn: loggedIn,
            authInfo: .init(authMethod: "claude.ai", apiProvider: "firstParty"),
            version: "2.1.268"
        )
    }
}

private struct FixedClaudeTelemetryProvider: ClaudeCodeRateLimitProviding {
    let snapshot: ClaudeCodeRateLimitSnapshot
    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot { snapshot }
}

@MainActor
final class StubUsageCollector: ClaudeCodeUsageCollecting {
    private var results: [Result<ClaudeCodeQuotaCapture, Error>]
    private(set) var captureCount = 0
    private(set) var stopCount = 0

    init(results: [Result<ClaudeCodeQuotaCapture, Error>]) {
        self.results = results
    }

    func configure(executableURL: URL, cliVersion: String) {}

    func capture() async throws -> ClaudeCodeQuotaCapture {
        captureCount += 1
        guard !results.isEmpty else { throw ClaudeCodeUsageCaptureError.timedOut }
        return try results.removeFirst().get()
    }

    func stop() { stopCount += 1 }
}

@MainActor
private final class PausingSecondClaudeUsageCollector:
    ClaudeCodeUsageCollecting
{
    private let captureValue: ClaudeCodeQuotaCapture
    private var captureCount = 0
    private var secondCaptureStarted = false
    private var secondCaptureContinuation: CheckedContinuation<Void, Never>?

    init(capture: ClaudeCodeQuotaCapture) {
        captureValue = capture
    }

    func configure(executableURL: URL, cliVersion: String) {}

    func capture() async throws -> ClaudeCodeQuotaCapture {
        captureCount += 1
        if captureCount == 2 {
            secondCaptureStarted = true
            await withCheckedContinuation {
                secondCaptureContinuation = $0
            }
        }
        return captureValue
    }

    func waitUntilSecondCaptureStarted() async {
        while !secondCaptureStarted { await Task.yield() }
    }

    func resumeSecondCapture() {
        secondCaptureContinuation?.resume()
        secondCaptureContinuation = nil
    }

    func stop() {}
}

@MainActor
private final class TestClaudeStatusLineBridge: ClaudeCodeStatusLineBridging {
    private var installed: Bool
    private(set) var uninstallCount = 0
    let snapshotURL = URL(fileURLWithPath: "/tmp/unused-claude-status.json")

    init(installed: Bool) { self.installed = installed }
    func isInstalled() -> Bool { installed }
    func install() throws { installed = true }
    func uninstall() throws {
        uninstallCount += 1
        installed = false
    }
}

@MainActor
private final class TestClaudeActivityBridge: ClaudeCodeActivityHookBridging {
    let eventsDirectoryURL = URL(fileURLWithPath: "/tmp/unused-claude-events")
    private var installed: Bool
    init(installed: Bool = false) { self.installed = installed }
    func isInstalled() -> Bool { installed }
    func install() throws { installed = true }
    func uninstall() throws { installed = false }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

func testClaudeQuotaCapture(
    fiveHour: Int,
    weekly: Int,
    capturedAt: Date = Date()
) -> ClaudeCodeQuotaCapture {
    ClaudeCodeQuotaCapture(
        fiveHour: .init(
            kind: .fiveHour,
            usedPercent: fiveHour,
            windowDurationMinutes: 300,
            resetsAt: nil
        ),
        weekly: .init(
            kind: .weekly,
            usedPercent: weekly,
            windowDurationMinutes: 10_080,
            resetsAt: nil
        ),
        capturedAt: capturedAt,
        cliVersion: "2.1.268"
    )
}

private struct ConnectionPreviewAntigravity: AntigravityQuotaProviding, AntigravityExecutableLocating {
    let signedOut: Bool
    func locate() throws -> URL { URL(fileURLWithPath: "/tmp/agy") }
    func fetchQuota(executableURL: URL) async throws -> AntigravityQuotaSnapshot {
        if signedOut { throw AntigravityUsageError.signedOut }
        return .init(buckets: [
            .init(id: "weekly", groupName: "Model pool", title: "Weekly", description: nil,
                  windowDurationMinutes: 10_080, remainingFraction: 0.6, resetsAt: nil)
        ], fetchedAt: Date(), cliVersion: "fixture")
    }
}
