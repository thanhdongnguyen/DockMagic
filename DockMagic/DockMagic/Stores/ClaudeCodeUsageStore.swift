import Darwin
import Foundation
import Observation
import OSLog

private let claudeActivityLogger = Logger(
    subsystem: "com.hypevibe.DockMagic",
    category: "ClaudeActivity"
)

@MainActor
@Observable
final class ClaudeCodeUsageStore {
    private(set) var state: ClaudeCodeUsageState = .idle
    private(set) var connectionState: ClaudeCodeConnectionState = .cliMissing
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var isBridgeInstalled: Bool
    private(set) var isActivityHookInstalled: Bool
    private(set) var isInstallingActivityHook = false
    private(set) var activityHookErrorText: String?
    private(set) var bridgeCleanupWarning: String?
    private(set) var executableURL: URL?

    @ObservationIgnored private let provider: any ClaudeCodeRateLimitProviding
    @ObservationIgnored private let bridge: any ClaudeCodeStatusLineBridging
    @ObservationIgnored private let activityHookBridge: any ClaudeCodeActivityHookBridging
    @ObservationIgnored private let streakTracker: any TokenUsageStreakTracking
    @ObservationIgnored private let authProvider: any ClaudeCodeAuthStatusProviding
    @ObservationIgnored private let usageCollector: any ClaudeCodeUsageCollecting
    @ObservationIgnored private let pollingInterval: Duration
    @ObservationIgnored private let staleAfter: TimeInterval
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var pollingSleepTask: Task<Void, Error>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var activityMonitor: LocalTelemetryEventMonitor?
    @ObservationIgnored private var activityDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastQuotaCapture: ClaudeCodeQuotaCapture?
    @ObservationIgnored private var lastAuthInfo: ClaudeCodeAuthInfo?
    @ObservationIgnored private var didAttemptBridgeMigration = false

    init(
        provider: any ClaudeCodeRateLimitProviding = ClaudeCodeStatusLineRateLimitProvider(),
        bridge: (any ClaudeCodeStatusLineBridging)? = nil,
        activityHookBridge: (any ClaudeCodeActivityHookBridging)? = nil,
        streakTracker: (any TokenUsageStreakTracking)? = nil,
        authProvider: (any ClaudeCodeAuthStatusProviding)? = nil,
        usageCollector: (any ClaudeCodeUsageCollecting)? = nil,
        pollingInterval: Duration = .seconds(60),
        initialRetryInterval _: Duration = .seconds(60),
        staleAfter: TimeInterval = 15 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        precondition(pollingInterval > .zero, "Polling interval must be positive.")
        precondition(staleAfter > 0, "Stale interval must be positive.")
        self.provider = provider
        let bridge = bridge ?? ClaudeCodeStatusLineBridge()
        self.bridge = bridge
        let activityHookBridge = activityHookBridge ?? ClaudeCodeActivityHookBridge()
        self.activityHookBridge = activityHookBridge
        self.streakTracker = streakTracker ?? TokenUsageStreakStore()
        self.authProvider = authProvider ?? ClaudeCodeAuthStatusProvider()
        self.usageCollector = usageCollector ?? ClaudeCodeUsageTerminalCollector(now: now)
        self.pollingInterval = pollingInterval
        self.staleAfter = staleAfter
        self.now = now
        isBridgeInstalled = bridge.isInstalled()
        isActivityHookInstalled = activityHookBridge.isInstalled()
    }

    deinit {
        pollingTask?.cancel()
        pollingSleepTask?.cancel()
        refreshTask?.cancel()
        activityDebounceTask?.cancel()
        activityMonitor?.stop()
    }

    func configure(executableURL: URL) {
        let normalized = executableURL.standardizedFileURL
        guard self.executableURL != normalized else {
            if isMonitoring { Task { await refresh() } }
            return
        }
        usageCollector.stop()
        self.executableURL = normalized
        lastQuotaCapture = nil
        lastAuthInfo = nil
        connectionState = .checking
        migrateRetiredStatusLineBridgeIfNeeded()
        if isMonitoring { Task { await refresh() } }
    }

    func markCLIMissing() {
        executableURL = nil
        usageCollector.stop()
        lastQuotaCapture = nil
        connectionState = .cliMissing
    }

    func start() {
        guard pollingTask == nil else { return }
        isMonitoring = true
        syncActivityMonitor()
        pollingTask = Task { @MainActor [weak self] in
            monitoringLoop: while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()

                // A manual refresh cancels the current deadline. Re-arm the
                // full interval from that newer capture instead of issuing a
                // second `/usage` request immediately.
                while !Task.isCancelled {
                    let sleep = Task {
                        try await Task.sleep(for: self.pollingInterval)
                    }
                    self.pollingSleepTask = sleep
                    do {
                        try await sleep.value
                        self.pollingSleepTask = nil
                        break
                    } catch {
                        self.pollingSleepTask = nil
                        if Task.isCancelled { break monitoringLoop }
                    }
                }
            }
            self?.isMonitoring = false
            self?.pollingTask = nil
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingSleepTask?.cancel()
        refreshTask?.cancel()
        activityDebounceTask?.cancel()
        pollingTask = nil
        pollingSleepTask = nil
        refreshTask = nil
        activityDebounceTask = nil
        activityMonitor?.stop()
        activityMonitor = nil
        usageCollector.stop()
        isMonitoring = false
        isRefreshing = false
        if case .loading = state { state = .idle }
    }

    func beginSignIn() {
        connectionState = .signingIn
        usageCollector.stop()
    }

    func loginProcessDidFinish() async {
        connectionState = .checking
        await refresh()
    }

    func cancelSignIn() async {
        connectionState = .checking
        await refresh()
    }

    func signOut() async {
        guard let executableURL else {
            connectionState = .cliMissing
            return
        }

        let previousSnapshot = state.snapshot
        refreshTask?.cancel()
        if let refreshTask { await refreshTask.value }
        refreshTask = nil
        pollingSleepTask?.cancel()
        usageCollector.stop()
        connectionState = .signingOut

        do {
            try await authProvider.signOut(executableURL: executableURL)
            try Task.checkCancellation()
            lastQuotaCapture = nil
            lastAuthInfo = nil
            await publishTelemetryWithoutQuota(
                message: "Sign in to Claude to load 5-hour and weekly quota."
            )
            connectionState = .signedOut
        } catch is CancellationError {
            return
        } catch {
            let message = "Sign out failed: \(error.localizedDescription)"
            claudeActivityLogger.error("\(message, privacy: .public)")
            if let previousSnapshot, previousSnapshot.hasSupportedWindow {
                let stale = observingStreak(in: previousSnapshot)
                state = .stale(stale, message: message)
                connectionState = .stale(
                    lastSnapshot: stale,
                    message: message
                )
            } else {
                connectionState = .failed(message: message)
                state = .unavailable(message: message)
            }
        }
    }

    func installActivityHook() async {
        guard !isInstallingActivityHook else { return }
        isInstallingActivityHook = true
        activityHookErrorText = nil
        defer { isInstallingActivityHook = false }
        do {
            try activityHookBridge.install()
            isActivityHookInstalled = activityHookBridge.isInstalled()
            guard isActivityHookInstalled else {
                throw ClaudeCodeActivityHookBridgeError.fileOperationFailed(
                    "Claude Code did not retain the installed hook configuration."
                )
            }
            syncActivityMonitor()
            claudeActivityLogger.notice("Installed Claude Code activity hooks and enabled realtime monitoring.")
            await refreshTelemetryOnly()
        } catch {
            isActivityHookInstalled = activityHookBridge.isInstalled()
            activityHookErrorText = error.localizedDescription
            syncActivityMonitor()
            claudeActivityLogger.error("Claude Code activity hook installation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Source-compatible migration entry point. New installs never add a
    /// statusLine bridge.
    func installBridge() async {
        migrateRetiredStatusLineBridgeIfNeeded()
        await refresh()
    }

    func uninstallBridge() {
        migrateRetiredStatusLineBridgeIfNeeded(force: true)
    }

    func refresh() async {
        isBridgeInstalled = bridge.isInstalled()
        isActivityHookInstalled = activityHookBridge.isInstalled()
        syncActivityMonitor()
        if let refreshTask {
            await refreshTask.value
            return
        }
        isRefreshing = true
        let previousSnapshot = state.snapshot
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(previousSnapshot: previousSnapshot)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
        isRefreshing = false
        pollingSleepTask?.cancel()
    }

    func refreshAfterInterruption() async {
        activityMonitor?.stop()
        activityMonitor = nil
        syncActivityMonitor()
        usageCollector.stop()
        await refresh()
    }

    private func performRefresh(previousSnapshot: ClaudeCodeRateLimitSnapshot?) async {
        guard let executableURL else {
            connectionState = .cliMissing
            await refreshTelemetryOnly()
            return
        }
        if previousSnapshot == nil { state = .loading }
        connectionState = .checking
        do {
            let cliStatus = try await authProvider.status(executableURL: executableURL)
            try Task.checkCancellation()
            guard ClaudeCodeAuthStatusProvider.isSupported(version: cliStatus.version) else {
                usageCollector.stop()
                connectionState = .cliOutdated(
                    installed: cliStatus.version,
                    required: ClaudeCodeAuthStatusProvider.minimumVersion
                )
                await publishTelemetryWithoutQuota(message: "Update Claude Code to read /usage.")
                return
            }
            guard cliStatus.loggedIn else {
                usageCollector.stop()
                lastAuthInfo = nil
                connectionState = .signedOut
                await publishTelemetryWithoutQuota(message: "Sign in to Claude to load 5-hour and weekly quota.")
                return
            }
            lastAuthInfo = cliStatus.authInfo
            guard cliStatus.authInfo.isSubscriptionLogin else {
                usageCollector.stop()
                let reason = "This login uses API or cloud-provider billing. 5-hour and weekly plan limits require a Claude subscription."
                connectionState = .quotaUnavailable(cliStatus.authInfo, reason: reason)
                await publishTelemetryWithoutQuota(message: reason)
                return
            }
            connectionState = .signedInWaitingForQuota(cliStatus.authInfo)
            usageCollector.configure(executableURL: executableURL, cliVersion: cliStatus.version)
            let telemetry = try? await provider.fetchRateLimits()
            let capture = try await usageCollector.capture()
            try Task.checkCancellation()
            lastQuotaCapture = capture
            let snapshot = observingStreak(in: mergedSnapshot(telemetry: telemetry, quota: capture))
            state = .live(snapshot)
            connectionState = .connected(cliStatus.authInfo, lastUpdated: capture.capturedAt)
        } catch is CancellationError {
            return
        } catch {
            let message = error.localizedDescription
            claudeActivityLogger.error("Claude /usage refresh failed: \(message, privacy: .public)")
            if let previousSnapshot, previousSnapshot.hasSupportedWindow {
                let stale = observingStreak(in: previousSnapshot)
                state = .stale(stale, message: message)
                connectionState = .stale(lastSnapshot: stale, message: message)
            } else if let authInfo = lastAuthInfo {
                connectionState = .quotaUnavailable(authInfo, reason: message)
                await publishTelemetryWithoutQuota(message: message)
            } else {
                connectionState = .failed(message: message)
                state = .unavailable(message: message)
            }
        }
    }

    private func refreshTelemetryOnly() async {
        let telemetry = try? await provider.fetchRateLimits()
        guard telemetry != nil || lastQuotaCapture != nil else { return }
        let snapshot = observingStreak(in: mergedSnapshot(telemetry: telemetry, quota: lastQuotaCapture))
        if let quota = lastQuotaCapture {
            if now().timeIntervalSince(quota.capturedAt) > staleAfter {
                state = .stale(snapshot, message: "Claude quota is older than 15 minutes.")
            } else {
                state = .live(snapshot)
            }
        } else {
            state = .stale(
                snapshot,
                message: "Claude /usage quota is not available yet."
            )
        }
    }

    private func publishTelemetryWithoutQuota(message: String) async {
        guard let telemetry = try? await provider.fetchRateLimits() else {
            state = .unavailable(message: message)
            return
        }
        let snapshot = observingStreak(in: mergedSnapshot(telemetry: telemetry, quota: nil))
        state = .stale(snapshot, message: message)
    }

    private func mergedSnapshot(
        telemetry: ClaudeCodeRateLimitSnapshot?,
        quota: ClaudeCodeQuotaCapture?
    ) -> ClaudeCodeRateLimitSnapshot {
        ClaudeCodeRateLimitSnapshot(
            planType: telemetry?.planType,
            limitID: "claude-code-usage",
            fiveHour: quota?.fiveHour,
            weekly: quota?.weekly,
            tokenUsage: telemetry?.tokenUsage,
            recentTaskActivity: telemetry?.recentTaskActivity,
            claudeTelemetry: telemetry?.claudeTelemetry,
            fetchedAt: quota?.capturedAt ?? telemetry?.fetchedAt ?? now()
        )
    }

    private func observingStreak(in snapshot: ClaudeCodeRateLimitSnapshot) -> ClaudeCodeRateLimitSnapshot {
        let summary = streakTracker.observeToday(
            provider: .claudeCode,
            tokenUsage: snapshot.tokenUsage,
            at: now()
        )
        return snapshot.withStreakSummary(summary)
    }

    private func scheduleActivityRefresh() {
        activityDebounceTask?.cancel()
        activityDebounceTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(75))
                try Task.checkCancellation()
                await self?.refreshTelemetryOnly()
            } catch { return }
        }
    }

    private func syncActivityMonitor() {
        guard isMonitoring, isActivityHookInstalled else {
            activityMonitor?.stop()
            activityMonitor = nil
            return
        }
        guard activityMonitor == nil else { return }
        let monitor = LocalTelemetryEventMonitor(
            directoryURL: activityHookBridge.eventsDirectoryURL
        ) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleActivityRefresh() }
        }
        guard monitor.start() else {
            claudeActivityLogger.error("Could not start the Claude Code activity directory monitor.")
            return
        }
        activityMonitor = monitor
    }

    private func migrateRetiredStatusLineBridgeIfNeeded(force: Bool = false) {
        guard force || !didAttemptBridgeMigration else { return }
        didAttemptBridgeMigration = true
        isBridgeInstalled = bridge.isInstalled()
        guard isBridgeInstalled else { return }
        do {
            try bridge.uninstall()
            isBridgeInstalled = false
            bridgeCleanupWarning = nil
        } catch {
            isBridgeInstalled = bridge.isInstalled()
            bridgeCleanupWarning = "DockMagic could not remove its retired status line bridge: \(error.localizedDescription)"
        }
    }
}

final class LocalTelemetryEventMonitor: @unchecked Sendable {
    private let directoryURL: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(
        label: "com.hypevibe.DockMagic.claude-activity-events",
        qos: .utility
    )
    private var source: DispatchSourceFileSystemObject?

    init(directoryURL: URL, onChange: @escaping @Sendable () -> Void) {
        self.directoryURL = directoryURL
        self.onChange = onChange
    }

    deinit { stop() }

    func start() -> Bool {
        guard source == nil else { return true }
        let descriptor = open(directoryURL.path, O_EVTONLY | O_CLOEXEC)
        guard descriptor >= 0 else { return false }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
        return true
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
