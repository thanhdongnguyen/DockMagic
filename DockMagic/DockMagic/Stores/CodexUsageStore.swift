import Foundation
import Observation

@MainActor
@Observable
final class CodexUsageStore {
    private(set) var state: CodexUsageState = .idle
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var resolvedExecutablePath: String?

    var executableOverridePath: String?

    @ObservationIgnored
    private let provider: any CodexRateLimitProviding

    @ObservationIgnored
    private let locator: any CodexExecutableLocating

    @ObservationIgnored
    private let pollingInterval: Duration

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRefreshID: UUID?

    init(
        provider: any CodexRateLimitProviding = CodexAppServerRateLimitProvider(),
        locator: any CodexExecutableLocating = CodexExecutableLocator(),
        pollingInterval: Duration = .seconds(300),
        executableOverridePath: String? = nil
    ) {
        precondition(pollingInterval > .zero, "Polling interval must be positive.")
        self.provider = provider
        self.locator = locator
        self.pollingInterval = pollingInterval
        self.executableOverridePath = executableOverridePath
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

    func refresh() async {
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
        previousSnapshot: CodexRateLimitSnapshot?
    ) async {
        defer {
            if activeRefreshID == id {
                activeRefreshID = nil
                refreshTask = nil
                isRefreshing = false
            }
        }

        do {
            let executableURL = try locator.locate(
                overridePath: executableOverridePath
            )
            resolvedExecutablePath = executableURL.path
            let snapshot = try await provider.fetchRateLimits(
                executableURL: executableURL
            )
            try Task.checkCancellation()
            guard activeRefreshID == id else {
                return
            }
            state = .live(snapshot)
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
