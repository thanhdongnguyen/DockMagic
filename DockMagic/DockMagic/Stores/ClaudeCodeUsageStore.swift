import Foundation
import Observation

@MainActor
@Observable
final class ClaudeCodeUsageStore {
    private(set) var state: ClaudeCodeUsageState = .idle
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var isBridgeInstalled: Bool

    @ObservationIgnored
    private let provider: any ClaudeCodeRateLimitProviding

    @ObservationIgnored
    private let bridge: any ClaudeCodeStatusLineBridging

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

    init(
        provider: any ClaudeCodeRateLimitProviding = ClaudeCodeStatusLineRateLimitProvider(),
        bridge: (any ClaudeCodeStatusLineBridging)? = nil,
        pollingInterval: Duration = .seconds(15),
        staleAfter: TimeInterval = 15 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        precondition(pollingInterval > .zero, "Polling interval must be positive.")
        precondition(staleAfter > 0, "Stale interval must be positive.")
        self.provider = provider
        let bridge = bridge ?? ClaudeCodeStatusLineBridge()
        self.bridge = bridge
        self.pollingInterval = pollingInterval
        self.staleAfter = staleAfter
        self.now = now
        isBridgeInstalled = bridge.isInstalled()
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
    }

    func start() {
        guard pollingTask == nil else {
            return
        }

        let runID = UUID()
        activeRunID = runID
        isMonitoring = true
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
        isMonitoring = false
        isRefreshing = false

        if case .loading = state {
            state = .idle
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
            let snapshot = try await provider.fetchRateLimits()
            try Task.checkCancellation()
            guard activeRefreshID == id else {
                return
            }

            if now().timeIntervalSince(snapshot.fetchedAt) > staleAfter {
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
                state = .stale(previousSnapshot, message: message)
            } else {
                state = .unavailable(message: message)
            }
        }
    }
}
