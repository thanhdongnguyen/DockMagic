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
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var isBridgeInstalled: Bool
    private(set) var isActivityHookInstalled: Bool
    private(set) var isInstallingActivityHook = false
    private(set) var activityHookErrorText: String?

    @ObservationIgnored
    private let provider: any ClaudeCodeRateLimitProviding

    @ObservationIgnored
    private let bridge: any ClaudeCodeStatusLineBridging

    @ObservationIgnored
    private let activityHookBridge: any ClaudeCodeActivityHookBridging

    @ObservationIgnored
    private let streakTracker: any TokenUsageStreakTracking

    @ObservationIgnored
    private let pollingInterval: Duration

    @ObservationIgnored
    private let staleAfter: TimeInterval

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRefreshID: UUID?

    @ObservationIgnored
    private var activityMonitor: ClaudeCodeActivityEventMonitor?

    @ObservationIgnored
    private var activityDebounceTask: Task<Void, Never>?

    init(
        provider: any ClaudeCodeRateLimitProviding = ClaudeCodeStatusLineRateLimitProvider(),
        bridge: (any ClaudeCodeStatusLineBridging)? = nil,
        activityHookBridge: (any ClaudeCodeActivityHookBridging)? = nil,
        streakTracker: (any TokenUsageStreakTracking)? = nil,
        pollingInterval: Duration = .seconds(15),
        staleAfter: TimeInterval = 15 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        precondition(pollingInterval > .zero, "Polling interval must be positive.")
        precondition(staleAfter > 0, "Stale interval must be positive.")
        self.provider = provider
        let bridge = bridge ?? ClaudeCodeStatusLineBridge()
        self.bridge = bridge
        let activityHookBridge = activityHookBridge
            ?? ClaudeCodeActivityHookBridge()
        self.activityHookBridge = activityHookBridge
        self.streakTracker = streakTracker ?? TokenUsageStreakStore()
        self.pollingInterval = pollingInterval
        self.staleAfter = staleAfter
        self.now = now
        isBridgeInstalled = bridge.isInstalled()
        isActivityHookInstalled = activityHookBridge.isInstalled()
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
        activityDebounceTask?.cancel()
        activityMonitor?.stop()
    }

    func start() {
        guard pollingTask == nil else {
            return
        }

        let runID = UUID()
        activeRunID = runID
        isMonitoring = true
        syncActivityMonitor()
        let pollingInterval = pollingInterval
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else {
                    break
                }

                await self?.refresh()

                do {
                    try await Task.sleep(for: pollingInterval)
                } catch {
                    break
                }
            }

            guard let self, self.activeRunID == runID else {
                return
            }

            self.activeRunID = nil
            self.pollingTask = nil
            self.isMonitoring = false
        }
    }

    func stop() {
        activeRunID = nil
        pollingTask?.cancel()
        pollingTask = nil
        activeRefreshID = nil
        refreshTask?.cancel()
        refreshTask = nil
        activityDebounceTask?.cancel()
        activityDebounceTask = nil
        activityMonitor?.stop()
        activityMonitor = nil
        isMonitoring = false
        isRefreshing = false

        if case .loading = state {
            state = .idle
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
            claudeActivityLogger.notice(
                "Installed Claude Code activity hooks and enabled realtime monitoring."
            )
            await refresh()
        } catch {
            isActivityHookInstalled = activityHookBridge.isInstalled()
            activityHookErrorText = error.localizedDescription
            syncActivityMonitor()
            claudeActivityLogger.error(
                "Claude Code activity hook installation failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func installBridge() async {
        do {
            try bridge.install()
            isBridgeInstalled = true
            state = .idle
            await refresh()
        } catch {
            isBridgeInstalled = bridge.isInstalled()
            state = .unavailable(message: error.localizedDescription)
        }
    }

    func uninstallBridge() {
        do {
            try bridge.uninstall()
            isBridgeInstalled = false
            state = .unavailable(
                message: ClaudeCodeRateLimitProviderError.bridgeNotInstalled
                    .localizedDescription
            )
        } catch {
            isBridgeInstalled = bridge.isInstalled()
            state = .unavailable(message: error.localizedDescription)
        }
    }

    func refresh() async {
        isBridgeInstalled = bridge.isInstalled()
        isActivityHookInstalled = activityHookBridge.isInstalled()
        syncActivityMonitor()
        guard isBridgeInstalled else {
            state = .unavailable(
                message: ClaudeCodeRateLimitProviderError.bridgeNotInstalled
                    .localizedDescription
            )
            return
        }

        if let refreshTask {
            await refreshTask.value
            return
        }

        let refreshID = UUID()
        activeRefreshID = refreshID
        isRefreshing = true
        let previousSnapshot = state.snapshot
        if previousSnapshot == nil {
            state = .loading
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.performRefresh(
                id: refreshID,
                previousSnapshot: previousSnapshot
            )
        }
        refreshTask = task
        await task.value
    }

    private func syncActivityMonitor() {
        guard isMonitoring, isActivityHookInstalled else {
            activityMonitor?.stop()
            activityMonitor = nil
            return
        }
        guard activityMonitor == nil else { return }

        let monitor = ClaudeCodeActivityEventMonitor(
            directoryURL: activityHookBridge.eventsDirectoryURL
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleActivityRefresh()
            }
        }
        guard monitor.start() else {
            claudeActivityLogger.error(
                "Could not start the Claude Code activity directory monitor."
            )
            return
        }
        activityMonitor = monitor
    }

    private func scheduleActivityRefresh() {
        activityDebounceTask?.cancel()
        activityDebounceTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(75))
                try Task.checkCancellation()
                await self?.refresh()
            } catch {
                return
            }
        }
    }

    private func performRefresh(
        id: UUID,
        previousSnapshot: ClaudeCodeRateLimitSnapshot?
    ) async {
        defer {
            if activeRefreshID == id {
                activeRefreshID = nil
                refreshTask = nil
                isRefreshing = false
            }
        }

        do {
            let providerSnapshot = try await provider.fetchRateLimits()
            try Task.checkCancellation()
            guard activeRefreshID == id else {
                return
            }

            let observedAt = now()
            let streakSummary = streakTracker.observeToday(
                provider: .claudeCode,
                tokenUsage: providerSnapshot.tokenUsage,
                at: observedAt
            )
            let snapshot = providerSnapshot.withStreakSummary(streakSummary)

            if observedAt.timeIntervalSince(snapshot.fetchedAt) > staleAfter {
                state = .stale(
                    snapshot,
                    message: "Usage is older than 15 minutes. Complete a Claude Code response to update it."
                )
            } else {
                state = .live(snapshot)
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeRefreshID == id else {
                return
            }

            let message = error.localizedDescription
            if let previousSnapshot {
                let streakSummary = streakTracker.observeToday(
                    provider: .claudeCode,
                    tokenUsage: nil,
                    at: now()
                )
                state = .stale(
                    previousSnapshot.withStreakSummary(streakSummary),
                    message: message
                )
            } else {
                state = .unavailable(message: message)
            }
        }
    }
}

private final class ClaudeCodeActivityEventMonitor: @unchecked Sendable {
    private let directoryURL: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(
        label: "com.hypevibe.DockMagic.claude-activity-events",
        qos: .utility
    )
    private var source: DispatchSourceFileSystemObject?

    init(
        directoryURL: URL,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.directoryURL = directoryURL
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard source == nil else { return true }
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return false }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler {
            close(descriptor)
        }
        self.source = source
        source.resume()
        return true
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
