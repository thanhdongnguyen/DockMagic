import AppKit
import SwiftUI
import XCTest

@testable import DockMagic

final class StartupRecoveryTests: XCTestCase {
    func testRetriesBackOffToRegularPollingAndResetAfterSuccess() {
        var schedule = UsageRetrySchedule(
            pollingInterval: .seconds(300), initialRetryInterval: .seconds(5)
        )
        XCTAssertEqual(schedule.nextDelay, .seconds(300))
        for seconds in [5, 10, 20, 40, 80, 160, 300, 300] {
            schedule.failed()
            XCTAssertEqual(schedule.nextDelay, .seconds(seconds))
        }
        for _ in 0..<100 { schedule.failed() }
        XCTAssertEqual(schedule.nextDelay, .seconds(300))
        schedule.succeeded()
        XCTAssertEqual(schedule.nextDelay, .seconds(300))
        schedule.failed()
        XCTAssertEqual(schedule.nextDelay, .seconds(5))
    }

    @MainActor
    func testColdSettingsRouteCreatesOneWindowAndReopensAfterClosing() throws {
        let router = SettingsWindowRouter(showExistingWindow: { false }, activateApplication: {})
        var windows: [NSWindow] = []
        router.installDefaultWindowFactory {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.contentView = NSView()
            windows.append(window)
            return window
        }
        defer { windows.forEach { $0.close() } }
        XCTAssertTrue(windows.isEmpty, "Registering a factory must not display Settings at login.")
        XCTAssertTrue(router.showSettings(destination: .claudeCode))
        let first = try XCTUnwrap(windows.first)
        XCTAssertTrue(first.isVisible)
        XCTAssertEqual(router.destination, .claudeCode)
        XCTAssertTrue(router.showSettings())
        XCTAssertEqual(windows.count, 1)
        first.miniaturize(nil)
        XCTAssertTrue(router.showSettings())
        XCTAssertFalse(first.isMiniaturized)
        first.close()
        XCTAssertNil(first.contentView, "Closing must release content that observes the router.")
        XCTAssertTrue(router.showSettings())
        XCTAssertEqual(windows.count, 2)
        XCTAssertTrue(windows[1].isVisible)
    }

    @MainActor
    func testAppDelegateCanOpenSettingsBeforeAnySwiftUISceneAppears() throws {
        let fixture = makeFixture()
        defer { fixture.model.stop() }
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let router = SettingsWindowRouter(showExistingWindow: { false }, activateApplication: {})
        let delegate = AppDelegate(
            appModel: fixture.model, settingsWindowRouter: router,
            networkAvailabilityMonitor: RecoveryNetworkMonitor())
        XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false))
        let window = try XCTUnwrap(
            NSApp.windows.first {
                !existing.contains(ObjectIdentifier($0))
                    && $0.title == SettingsWindowRouter.windowTitle
            })
        defer { window.close() }
        XCTAssertTrue(window.isVisible)
        XCTAssertNotNil(window.contentView)
        XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true))
        XCTAssertEqual(
            NSApp.windows.filter {
                !existing.contains(ObjectIdentifier($0))
                    && $0.title == SettingsWindowRouter.windowTitle
            }.count, 1)
    }

    @MainActor
    func testCodexAutomaticallyRecoversFromOfflineStartupWithoutRestart() async throws {
        let provider = RecoveryUsageProvider(results: [
            .failure(URLError(.notConnectedToInternet)), .success(snapshot()),
        ])
        let store = codexStore(provider, retry: .milliseconds(30))
        defer { store.stop() }
        store.start()
        try await waitUntil { store.state.snapshot != nil }
        let calls = await provider.callCount
        XCTAssertEqual(calls, 2)
        try await Task.sleep(for: .milliseconds(100))
        let callsAfterSuccess = await provider.callCount
        XCTAssertEqual(callsAfterSuccess, 2, "Success must restore the long polling interval.")
    }

    @MainActor
    func testClaudeAutomaticallyRecoversWhenLocalSnapshotBecomesReadable() async throws {
        let provider = RecoveryUsageProvider(results: [
            .failure(ClaudeCodeRateLimitProviderError.snapshotMissing), .success(snapshot()),
        ])
        let store = claudeStore(provider, retry: .milliseconds(30))
        defer { store.stop() }
        store.start()
        try await waitUntil { store.state.snapshot != nil }
        let calls = await provider.callCount
        XCTAssertEqual(calls, 2)
    }

    @MainActor
    func testCodexExternalFailureRearmsAnExistingLongPollingDelay() async throws {
        let provider = RecoveryUsageProvider(results: [
            .success(snapshot()), .failure(URLError(.notConnectedToInternet)), .success(snapshot()),
        ])
        let store = codexStore(provider, retry: .milliseconds(30))
        defer { store.stop() }
        store.start()
        try await waitUntil { store.state.snapshot != nil }
        try await Task.sleep(for: .milliseconds(20))
        await store.refresh()
        guard case .stale = store.state else { return XCTFail("Expected the last known snapshot") }
        try await waitUntil { await provider.callCount >= 3 }
        guard case .live = store.state else { return XCTFail("Recovery should use a short retry") }
    }

    @MainActor
    func testClaudeExternalFailureRearmsAnExistingLongPollingDelay() async throws {
        let provider = RecoveryUsageProvider(results: [
            .success(snapshot()), .failure(ClaudeCodeRateLimitProviderError.invalidSnapshot),
            .success(snapshot()),
        ])
        let store = claudeStore(provider, retry: .milliseconds(30))
        defer { store.stop() }
        store.start()
        try await waitUntil { store.state.snapshot != nil }
        try await Task.sleep(for: .milliseconds(20))
        await store.refresh()
        guard case .stale = store.state else { return XCTFail("Expected the last known snapshot") }
        try await waitUntil { await provider.callCount >= 3 }
        guard case .live = store.state else { return XCTFail("Recovery should use a short retry") }
    }

    @MainActor
    func testCodexReconnectDuringPendingFailurePerformsAnotherRead() async throws {
        let provider = RecoveryUsageProvider(
            results: [.failure(URLError(.notConnectedToInternet)), .success(snapshot())],
            suspendFirst: true)
        let store = codexStore(provider)
        defer { store.stop() }
        store.start()
        try await waitUntil { await provider.callCount == 1 }
        let recovery = Task { await store.refreshAfterInterruption() }
        await Task.yield()
        await provider.releaseFirstRead()
        await recovery.value
        XCTAssertNotNil(store.state.snapshot)
        let calls = await provider.callCount
        XCTAssertEqual(calls, 2, "Recovery must not simply join the failed offline read.")
    }

    @MainActor
    func testClaudeResumeDuringPendingFailurePerformsAnotherRead() async throws {
        let provider = RecoveryUsageProvider(
            results: [
                .failure(ClaudeCodeRateLimitProviderError.snapshotMissing), .success(snapshot()),
            ], suspendFirst: true)
        let store = claudeStore(provider)
        defer { store.stop() }
        store.start()
        try await waitUntil { await provider.callCount == 1 }
        let recovery = Task { await store.refreshAfterInterruption() }
        await Task.yield()
        await provider.releaseFirstRead()
        await recovery.value
        XCTAssertNotNil(store.state.snapshot)
        let calls = await provider.callCount
        XCTAssertEqual(calls, 2)
    }

    @MainActor
    func testStoppingCodexPreventsPendingRecoveryFromRestartingIt() async throws {
        let provider = RecoveryUsageProvider(
            results: [.failure(URLError(.notConnectedToInternet)), .success(snapshot())],
            suspendFirst: true)
        let store = codexStore(provider)
        store.start()
        try await waitUntil { await provider.callCount == 1 }
        let recovery = Task { await store.refreshAfterInterruption() }
        await Task.yield()
        store.stop()
        await provider.releaseFirstRead()
        await recovery.value
        let stoppedCalls = await provider.callCount
        XCTAssertEqual(stoppedCalls, 1)
        XCTAssertFalse(store.isMonitoring)
        XCTAssertFalse(store.isRefreshing)
        store.start()
        defer { store.stop() }
        try await waitUntil { store.state.snapshot != nil }
        let restartedCalls = await provider.callCount
        XCTAssertEqual(restartedCalls, 2)
    }

    @MainActor
    func testStoppingClaudePreventsPendingRecoveryFromRestartingIt() async throws {
        let provider = RecoveryUsageProvider(
            results: [
                .failure(ClaudeCodeRateLimitProviderError.snapshotMissing), .success(snapshot()),
            ], suspendFirst: true)
        let store = claudeStore(provider)
        store.start()
        try await waitUntil { await provider.callCount == 1 }
        let recovery = Task { await store.refreshAfterInterruption() }
        await Task.yield()
        store.stop()
        await provider.releaseFirstRead()
        await recovery.value
        let calls = await provider.callCount
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(store.isMonitoring)
    }

    @MainActor
    func testWakeUnlockAndReconnectRefreshBothProvidersAndStopObservingOnQuit() async throws {
        let fixture = makeFixture()
        let network = RecoveryNetworkMonitor()
        let center = NotificationCenter()
        let delegate = AppDelegate(
            appModel: fixture.model, settingsWindowRouter: SettingsWindowRouter(),
            workspaceNotificationCenter: center, networkAvailabilityMonitor: network)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification))
        defer {
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification))
        }
        try await waitUntil {
            let codex = await fixture.codex.callCount
            let claude = await fixture.claude.callCount
            return codex >= 1 && claude >= 1
        }
        for trigger in [
            { center.post(name: NSWorkspace.didWakeNotification, object: nil) },
            { center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil) },
            { network.reconnect() },
        ] {
            let beforeCodex = await fixture.codex.callCount
            let beforeClaude = await fixture.claude.callCount
            trigger()
            try await waitUntil {
                let codex = await fixture.codex.callCount
                let claude = await fixture.claude.callCount
                return codex > beforeCodex && claude > beforeClaude
            }
        }
        delegate.applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification))
        let stoppedCalls = await fixture.codex.callCount
        network.reconnect()
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(60))
        let calls = await fixture.codex.callCount
        XCTAssertEqual(calls, stoppedCalls)
        XCTAssertFalse(network.isStarted)
    }

    @MainActor
    func testReconnectIsNotBlockedByPendingServiceStatusRecovery() async throws {
        let statuses = RecoveryServiceStatusProvider(delay: .seconds(30))
        let fixture = makeFixture(statuses: statuses)
        let network = RecoveryNetworkMonitor()
        let center = NotificationCenter()
        let delegate = AppDelegate(
            appModel: fixture.model, settingsWindowRouter: SettingsWindowRouter(),
            workspaceNotificationCenter: center, networkAvailabilityMonitor: network)
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification))
        defer {
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification))
        }
        try await waitUntil { await fixture.codex.callCount == 1 }
        center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        try await waitUntil { await fixture.codex.callCount >= 2 }
        let before = await fixture.codex.callCount
        network.reconnect()
        try await waitUntil { await fixture.codex.callCount > before }
    }

    private func snapshot() -> CodexRateLimitSnapshot {
        .init(
            planType: "test", limitID: "codex",
            fiveHour: .init(
                kind: .fiveHour, usedPercent: 25,
                windowDurationMinutes: 300, resetsAt: nil), weekly: nil, fetchedAt: Date())
    }

    @MainActor
    private func codexStore(_ provider: RecoveryUsageProvider, retry: Duration = .seconds(60))
        -> CodexUsageStore
    {
        CodexUsageStore(
            provider: provider, locator: RecoveryCodexLocator(),
            streakTracker: TokenUsageStreakStore(
                modelContainer: TokenUsageStreakStore.inMemoryContainer()),
            pollingInterval: .seconds(60), initialRetryInterval: retry)
    }

    @MainActor
    private func claudeStore(_ provider: RecoveryUsageProvider, retry: Duration = .seconds(60))
        -> ClaudeCodeUsageStore
    {
        ClaudeCodeUsageStore(
            provider: provider, bridge: RecoveryClaudeBridge(),
            activityHookBridge: RecoveryClaudeHook(),
            streakTracker: TokenUsageStreakStore(
                modelContainer: TokenUsageStreakStore.inMemoryContainer()),
            pollingInterval: .seconds(60), initialRetryInterval: retry)
    }

    @MainActor
    private func makeFixture(
        statuses: RecoveryServiceStatusProvider = RecoveryServiceStatusProvider()
    )
        -> (model: DockAppModel, codex: RecoveryUsageProvider, claude: RecoveryUsageProvider)
    {
        let suite = "DockMagicTests.StartupRecovery.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(false, forKey: "DockMagicAutomaticallyConfigureClaudeCode")
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .codex
        preferences.isDockHoverDashboardEnabled = false
        let codex = RecoveryUsageProvider(results: [.success(snapshot())])
        let claude = RecoveryUsageProvider(results: [.success(snapshot())])
        let model = DockAppModel(
            preferences: preferences, codexStore: codexStore(codex),
            claudeCodeStore: claudeStore(claude),
            serviceStatusStore: ServiceStatusStore(
                provider: statuses, cache: InMemoryServiceStatusCache()))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return (model, codex, claude)
    }

    @MainActor
    private func waitUntil(
        _ condition: @MainActor () async -> Bool, file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !(await condition()) {
            if ContinuousClock.now >= deadline {
                XCTFail("Recovery timed out", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private actor RecoveryUsageProvider: CodexRateLimitProviding, ClaudeCodeRateLimitProviding {
    private var results: [Result<CodexRateLimitSnapshot, Error>]
    private let suspendFirst: Bool
    private var firstRead: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0
    init(results: [Result<CodexRateLimitSnapshot, Error>], suspendFirst: Bool = false) {
        self.results = results
        self.suspendFirst = suspendFirst
    }
    func fetchRateLimits(executableURL: URL) async throws -> CodexRateLimitSnapshot {
        try await read()
    }
    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot { try await read() }
    private func read() async throws -> CodexRateLimitSnapshot {
        callCount += 1
        if suspendFirst && callCount == 1 { await withCheckedContinuation { firstRead = $0 } }
        return try (results.count > 1 ? results.removeFirst() : results[0]).get()
    }
    func releaseFirstRead() {
        firstRead?.resume()
        firstRead = nil
    }
}

private struct RecoveryCodexLocator: CodexExecutableLocating {
    func locate(overridePath: String?) throws -> URL { URL(fileURLWithPath: "/usr/bin/true") }
}

@MainActor
private final class RecoveryClaudeBridge: ClaudeCodeStatusLineBridging {
    let snapshotURL = URL(fileURLWithPath: "/tmp/dockmagic-recovery-test-usage.json")
    func isInstalled() -> Bool { true }
    func install() throws {}
    func uninstall() throws {}
}

@MainActor
private final class RecoveryClaudeHook: ClaudeCodeActivityHookBridging {
    let eventsDirectoryURL = URL(fileURLWithPath: "/tmp/dockmagic-recovery-test-events")
    func isInstalled() -> Bool { false }
    func install() throws {}
    func uninstall() throws {}
}

@MainActor
private final class RecoveryNetworkMonitor: NetworkAvailabilityMonitoring {
    private var onReconnect: (@MainActor () -> Void)?
    private(set) var isStarted = false
    func start(onReconnect: @escaping @MainActor () -> Void) {
        self.onReconnect = onReconnect
        isStarted = true
    }
    func stop() {
        onReconnect = nil
        isStarted = false
    }
    func reconnect() { onReconnect?() }
}

private struct RecoveryServiceStatusProvider: ServiceStatusProviding {
    var delay: Duration = .zero
    func fetchStatus(for provider: ServiceStatusProviderID) async throws -> ServiceHealthSnapshot {
        if delay > .zero { try await Task.sleep(for: delay) }
        return .operational(provider: provider, fetchedAt: Date())
    }
}
