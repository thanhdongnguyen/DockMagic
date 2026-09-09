import Foundation
import Observation
import OSLog

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
    private let dailyDetailLoader: any CodexDailyTokenDetailLoading

    @ObservationIgnored
    private let streakTracker: any TokenUsageStreakTracking

    @ObservationIgnored
    private var retrySchedule: UsageRetrySchedule

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.hypevibe.DockMagic", category: "CodexUsage")

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var pollingSleepTask: Task<Void, Error>?

    @ObservationIgnored
    private var activeRunID: UUID?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRefreshID: UUID?

    init(
        provider: any CodexRateLimitProviding = CodexAppServerRateLimitProvider(),
        locator: any CodexExecutableLocating = CodexExecutableLocator(),
        dailyDetailLoader: any CodexDailyTokenDetailLoading =
            CodexDailyTokenDetailLoader(),
        streakTracker: (any TokenUsageStreakTracking)? = nil,
        pollingInterval: Duration = .seconds(300),
        initialRetryInterval: Duration = .seconds(5),
        executableOverridePath: String? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        precondition(pollingInterval > .zero, "Polling interval must be positive.")
        self.provider = provider
        self.locator = locator
        self.dailyDetailLoader = dailyDetailLoader
        self.streakTracker = streakTracker ?? TokenUsageStreakStore()
        self.retrySchedule = UsageRetrySchedule(
            pollingInterval: pollingInterval,
            initialRetryInterval: initialRetryInterval
        )
        self.executableOverridePath = executableOverridePath
        self.now = now
    }

    deinit {
        pollingTask?.cancel()
        pollingSleepTask?.cancel()
        refreshTask?.cancel()
    }

    func start() {
        guard pollingTask == nil else {
            return
        }

        let runID = UUID()
        activeRunID = runID
        isMonitoring = true
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self?.activeRunID == runID else {
                    break
                }

                await self?.refresh()

                // A manual/recovery refresh can change the next deadline
                // while this loop is asleep. Cancellation re-arms the delay;
                // only an elapsed delay starts the next provider request.
                var delayElapsed = false
                while !delayElapsed, !Task.isCancelled, self?.activeRunID == runID {
                    guard let delay = self?.retrySchedule.nextDelay else { break }
                    let sleep = Task { try await Task.sleep(for: delay) }
                    self?.pollingSleepTask = sleep
                    do {
                        try await sleep.value
                        delayElapsed = true
                    } catch {
                        // A completed refresh or stop cancelled this deadline.
                    }
                    if self?.activeRunID == runID { self?.pollingSleepTask = nil }
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
        pollingSleepTask?.cancel()
        pollingTask = nil
        pollingSleepTask = nil
        activeRefreshID = nil
        refreshTask?.cancel()
        refreshTask = nil
        isMonitoring = false
        isRefreshing = false
        retrySchedule.succeeded()

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

    /// A reconnect can arrive while an offline read is still completing. Wait
    /// for that read, then make a fresh attempt instead of joining its failure.
    func refreshAfterInterruption() async {
        guard let runID = activeRunID else { return }
        if let refreshTask { await refreshTask.value }
        guard !Task.isCancelled, activeRunID == runID else { return }
        await refresh()
    }

    func loadDailyTokenDetail(
        for date: Date
    ) async throws -> CodexDailyTokenDetail? {
        try await dailyDetailLoader.loadDetail(for: date)
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
                pollingSleepTask?.cancel()
            }
        }

        do {
            let executableURL = try locator.locate(
                overridePath: executableOverridePath
            )
            resolvedExecutablePath = executableURL.path
            let providerSnapshot = try await provider.fetchRateLimits(
                executableURL: executableURL
            )
            try Task.checkCancellation()
            guard activeRefreshID == id else {
                return
            }
            retrySchedule.succeeded()
            logger.info("Usage refresh succeeded.")
            let observedAt = now()
            let streakSummary = streakTracker.observeToday(
                provider: .codex,
                tokenUsage: providerSnapshot.tokenUsage,
                at: observedAt
            )
            state = .live(
                providerSnapshot.withStreakSummary(streakSummary)
            )
        } catch is CancellationError {
            return
        } catch {
            guard activeRefreshID == id else {
                return
            }

            let message = error.localizedDescription
            retrySchedule.failed()
            logger.error("Usage refresh failed; attempt \(self.retrySchedule.failureCount), next polling delay \(String(describing: self.retrySchedule.nextDelay), privacy: .public). Error: \(message, privacy: .private)")
            if let previousSnapshot {
                let streakSummary = streakTracker.observeToday(
                    provider: .codex,
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
