import Foundation
import Observation

@MainActor
@Observable
final class AntigravityUsageStore {
    private(set) var state: AntigravityUsageState = .idle
    private(set) var connectionState: AntigravityConnectionState = .checking
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var isBridgeInstalled: Bool
    private(set) var isInstallingBridge = false
    private(set) var bridgeErrorText: String?
    private(set) var executableURL: URL?

    var resolvedExecutablePath: String? { executableURL?.path }

    @ObservationIgnored private let provider: any AntigravityQuotaProviding
    @ObservationIgnored private let locator: any AntigravityExecutableLocating
    @ObservationIgnored private let bridge: any AntigravityStatusLineBridging
    @ObservationIgnored private let streakTracker: any TokenUsageStreakTracking
    @ObservationIgnored private let readSessions: @Sendable () -> [AntigravitySessionSnapshot]
    @ObservationIgnored private let cacheURL: URL
    @ObservationIgnored private let pollingInterval: Duration
    @ObservationIgnored private let quotaRefreshInterval: TimeInterval
    @ObservationIgnored private let staleAfter: TimeInterval
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var pollingSleepTask: Task<Void, Error>?
    @ObservationIgnored private var eventMonitor: LocalTelemetryEventMonitor?
    @ObservationIgnored private var eventDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastQuotaAttemptAt: Date?
    @ObservationIgnored private var lastQuota: AntigravityQuotaSnapshot?
    @ObservationIgnored private var cache: Cache
    @ObservationIgnored private var connectionStateBeforeAuthentication:
        AntigravityConnectionState?

    init(
        provider: any AntigravityQuotaProviding = AntigravityCLIUsageProvider(),
        locator: any AntigravityExecutableLocating = AntigravityExecutableLocator(),
        bridge: (any AntigravityStatusLineBridging)? = nil,
        streakTracker: (any TokenUsageStreakTracking)? = nil,
        cacheURL: URL? = nil,
        readSessions: (@Sendable () -> [AntigravitySessionSnapshot])? = nil,
        pollingInterval: Duration = .seconds(15),
        quotaRefreshInterval: TimeInterval = 5 * 60,
        staleAfter: TimeInterval = 15 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        precondition(pollingInterval > .zero)
        precondition(quotaRefreshInterval > 0)
        precondition(staleAfter > 0)
        let bridge = bridge ?? AntigravityStatusLineBridge()
        let defaultCacheURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/DockMagic/antigravity-usage-v2.json"
            )
        self.provider = provider
        self.locator = locator
        self.bridge = bridge
        self.streakTracker = streakTracker ?? TokenUsageStreakStore()
        self.cacheURL = cacheURL ?? defaultCacheURL
        self.pollingInterval = pollingInterval
        self.quotaRefreshInterval = quotaRefreshInterval
        self.staleAfter = staleAfter
        self.now = now
        isBridgeInstalled = bridge.isInstalled()
        if let data = try? Data(contentsOf: self.cacheURL),
           data.count <= 2_000_000,
           let decoded = try? JSONDecoder().decode(Cache.self, from: data),
           decoded.schemaVersion == Cache.currentSchemaVersion {
            cache = decoded
            lastQuota = decoded.lastQuota
        } else {
            cache = Cache()
        }
        let sessionsURL = bridge.sessionsDirectoryURL
        self.readSessions = readSessions ?? {
            AntigravityStatusLineReader(
                sessionsDirectoryURL: sessionsURL,
                now: now()
            ).readSessions()
        }
        let initialSessions = self.readSessions()
        ingest(initialSessions)
        resolveExecutableAvailability()
        persistCache()
        rebuildState(sessions: initialSessions, errorMessage: nil)
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
        pollingSleepTask?.cancel()
        eventDebounceTask?.cancel()
        eventMonitor?.stop()
    }

    func start() {
        guard pollingTask == nil else { return }
        isMonitoring = true
        syncEventMonitor()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let shouldRefreshQuota = self.canRefreshQuotaAutomatically
                    && (self.lastQuotaAttemptAt.map {
                        self.now().timeIntervalSince($0)
                            >= self.quotaRefreshInterval
                    } ?? true)
                await self.refresh(forceQuota: shouldRefreshQuota)
                let sleep = Task {
                    try await Task.sleep(for: self.pollingInterval)
                }
                self.pollingSleepTask = sleep
                do {
                    try await sleep.value
                } catch {
                    if Task.isCancelled { break }
                }
                self.pollingSleepTask = nil
            }
            self?.isMonitoring = false
            self?.pollingTask = nil
        }
    }

    func stop() {
        pollingTask?.cancel()
        refreshTask?.cancel()
        pollingSleepTask?.cancel()
        eventDebounceTask?.cancel()
        pollingTask = nil
        refreshTask = nil
        pollingSleepTask = nil
        eventDebounceTask = nil
        eventMonitor?.stop()
        eventMonitor = nil
        isMonitoring = false
        isRefreshing = false
        if case .loading = state { state = .idle }
    }

    func beginSignIn() {
        refreshTask?.cancel()
        pollingSleepTask?.cancel()
        connectionStateBeforeAuthentication = connectionState
        connectionState = .signingIn
    }

    func beginSignOut() {
        refreshTask?.cancel()
        pollingSleepTask?.cancel()
        connectionStateBeforeAuthentication = connectionState
        connectionState = .signingOut
    }

    func signInProcessDidFinish() async {
        if let refreshTask { await refreshTask.value }
        connectionStateBeforeAuthentication = nil
        connectionState = .checking
        await refresh(forceQuota: true)
    }

    func signOutProcessDidFinish() async {
        if let refreshTask { await refreshTask.value }
        connectionStateBeforeAuthentication = nil
        clearQuota()
        connectionState = executableURL == nil ? .cliMissing : .signedOut
        let sessions = readSessions()
        ingest(sessions)
        persistCache()
        rebuildState(
            sessions: sessions,
            errorMessage: AntigravityUsageError.signedOut.localizedDescription
        )
    }

    func cancelAuthentication() async {
        if let refreshTask { await refreshTask.value }
        connectionState = connectionStateBeforeAuthentication
            ?? (executableURL == nil ? .cliMissing : .signedOut)
        connectionStateBeforeAuthentication = nil
        let sessions = readSessions()
        ingest(sessions)
        persistCache()
        rebuildState(sessions: sessions, errorMessage: nil)
    }

    func connectStatusLine() async {
        guard !isInstallingBridge else { return }
        isInstallingBridge = true
        bridgeErrorText = nil
        defer { isInstallingBridge = false }
        do {
            try bridge.install()
            isBridgeInstalled = bridge.isInstalled()
            guard isBridgeInstalled else {
                throw AntigravityUsageError.invalidConfiguration
            }
            syncEventMonitor()
            await refresh(forceQuota: false)
        } catch {
            isBridgeInstalled = bridge.isInstalled()
            bridgeErrorText = error.localizedDescription
        }
    }

    func disconnectStatusLine() {
        bridgeErrorText = nil
        do {
            try bridge.uninstall()
            isBridgeInstalled = bridge.isInstalled()
            syncEventMonitor()
        } catch {
            isBridgeInstalled = bridge.isInstalled()
            bridgeErrorText = error.localizedDescription
        }
    }

    func refresh(forceQuota: Bool = true) async {
        guard !isAuthenticating || !forceQuota else { return }
        if let refreshTask {
            await refreshTask.value
            return
        }
        isRefreshing = true
        let previousSnapshot = state.snapshot
        if state.snapshot == nil { state = .loading }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isRefreshing = false
                self.refreshTask = nil
                self.pollingSleepTask?.cancel()
            }

            var errorMessage: String?
            self.resolveExecutableAvailability()
            if forceQuota {
                guard self.executableURL != nil else {
                    let sessions = self.readSessions()
                    self.ingest(sessions)
                    self.isBridgeInstalled = self.bridge.isInstalled()
                    self.persistCache()
                    self.rebuildState(
                        sessions: sessions,
                        errorMessage: AntigravityUsageError.executableNotFound
                            .localizedDescription
                    )
                    return
                }
                self.connectionState = .checking
                self.lastQuotaAttemptAt = self.now()
                do {
                    let executableURL = try self.locator.locate()
                    self.executableURL = executableURL
                    let quota = try await self.provider.fetchQuota(
                        executableURL: executableURL
                    )
                    self.lastQuota = quota
                    self.cache.lastQuota = self.lastQuota
                    self.connectionState = .connected(
                        lastUpdated: quota.fetchedAt
                    )
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = error.localizedDescription
                    self.updateConnectionState(
                        for: error,
                        previousSnapshot: previousSnapshot
                    )
                }
            }

            let sessions = self.readSessions()
            self.ingest(sessions)
            self.isBridgeInstalled = self.bridge.isInstalled()
            self.persistCache()
            self.rebuildState(
                sessions: sessions,
                errorMessage: errorMessage
            )
        }
        refreshTask = task
        await task.value
    }

    private var isAuthenticating: Bool {
        switch connectionState {
        case .signingIn, .signingOut:
            true
        case .cliMissing, .checking, .signedOut, .connected, .stale, .failed:
            false
        }
    }

    private func updateConnectionState(
        for error: Error,
        previousSnapshot: AntigravityUsageSnapshot?
    ) {
        if let usageError = error as? AntigravityUsageError {
            switch usageError {
            case .executableNotFound:
                executableURL = nil
                connectionState = .cliMissing
                return
            case .signedOut:
                clearQuota()
                connectionState = .signedOut
                return
            case .commandFailed, .invalidResponse, .unsupportedResponse,
                 .invalidConfiguration, .bridgeConflict:
                break
            }
        }

        let message = error.localizedDescription
        if let previousSnapshot {
            connectionState = .stale(
                lastSnapshot: previousSnapshot,
                message: message
            )
        } else {
            connectionState = .failed(message: message)
        }
    }

    func refreshAfterInterruption() async {
        guard isMonitoring else { return }
        if let refreshTask { await refreshTask.value }
        guard isMonitoring, !Task.isCancelled else { return }
        syncEventMonitor()
        await refresh(forceQuota: canRefreshQuotaAutomatically)
    }

    private var canRefreshQuotaAutomatically: Bool {
        guard lastQuota != nil, executableURL != nil else { return false }
        switch connectionState {
        case .checking, .connected, .stale, .failed:
            return true
        case .cliMissing, .signedOut, .signingIn, .signingOut:
            return false
        }
    }

    private func resolveExecutableAvailability() {
        do {
            executableURL = try locator.locate()
            switch connectionState {
            case .cliMissing, .checking:
                connectionState = lastQuota == nil ? .signedOut : .checking
            case .signedOut, .signingIn, .signingOut, .connected, .stale,
                 .failed:
                break
            }
        } catch {
            executableURL = nil
            connectionState = .cliMissing
        }
    }

    private func clearQuota() {
        lastQuota = nil
        cache.lastQuota = nil
        lastQuotaAttemptAt = nil
    }

    private func ingest(_ sessions: [AntigravitySessionSnapshot]) {
        for session in sessions.sorted(by: { $0.observedAt < $1.observedAt }) {
            guard let input = session.context?.totalInputTokens,
                  let output = session.context?.totalOutputTokens else {
                continue
            }
            let next = Baseline(
                inputTokens: input,
                outputTokens: output,
                model: session.modelID,
                observedAt: session.observedAt
            )
            guard let previous = cache.baselines[session.id] else {
                cache.baselines[session.id] = next
                continue
            }
            guard session.observedAt > previous.observedAt else { continue }
            defer { cache.baselines[session.id] = next }
            guard Calendar.current.isDate(
                session.observedAt,
                inSameDayAs: previous.observedAt
            ), input >= previous.inputTokens,
            output >= previous.outputTokens else {
                continue
            }
            let inputDelta = input - previous.inputTokens
            let outputDelta = output - previous.outputTokens
            let (delta, overflow) = inputDelta.addingReportingOverflow(outputDelta)
            guard !overflow, delta > 0 else { continue }
            let day = TokenUsageCalendarDay.containing(
                session.observedAt,
                calendar: .current
            ).key
            cache.dailyTokens[day] = Self.add(cache.dailyTokens[day] ?? 0, delta)
            if let model = session.modelID, model == previous.model {
                var models = cache.dailyModelTokens[day] ?? [:]
                models[model] = Self.add(models[model] ?? 0, delta)
                cache.dailyModelTokens[day] = models
            }
        }
        pruneCache()
    }

    private func rebuildState(
        sessions: [AntigravitySessionSnapshot],
        errorMessage: String?
    ) {
        let timestamp = now()
        let currentSession = sessions.first {
            let age = timestamp.timeIntervalSince($0.observedAt)
            return age >= -60 && age <= staleAfter
        }
        let activeCount = sessions.filter {
            let age = timestamp.timeIntervalSince($0.observedAt)
            return age >= -60 && age <= 30 * 60
                && $0.isActiveWork
        }.count
        let tokenUsage = normalizedTokenUsage()
        let latestObservedActivity = cache.baselines.values
            .map(\.observedAt)
            .max()
        let freshest = [
            lastQuota?.fetchedAt,
            currentSession?.observedAt,
            latestObservedActivity
        ]
            .compactMap { $0 }
            .max()

        guard lastQuota != nil || currentSession != nil || tokenUsage != nil,
              let fetchedAt = freshest else {
            state = .unavailable(
                message: errorMessage
                    ?? "Run agy to load quota. Enable session metrics to observe local activity."
            )
            return
        }

        var snapshot = AntigravityUsageSnapshot(
            quota: lastQuota,
            tokenUsage: tokenUsage,
            streakSummary: nil,
            currentSession: currentSession,
            activeSessionCount: activeCount,
            historyIsPartial: true,
            fetchedAt: fetchedAt
        )
        let summary = streakTracker.observeToday(
            provider: .antigravity,
            tokenUsage: tokenUsage,
            at: timestamp
        )
        snapshot = snapshot.withStreakSummary(summary)

        if let errorMessage {
            state = .stale(snapshot, message: errorMessage)
        } else if let quota = lastQuota,
                  timestamp.timeIntervalSince(quota.fetchedAt) > staleAfter {
            state = .stale(
                snapshot,
                message: "Antigravity quota is older than 15 minutes."
            )
        } else if lastQuota == nil {
            state = .stale(
                snapshot,
                message: "Session activity is available, but product quota is unavailable."
            )
        } else {
            state = .live(snapshot)
        }
    }

    private func normalizedTokenUsage() -> CodexAccountTokenUsage? {
        let calendar = Calendar.current
        let cutoff = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: now())
        ) ?? .distantPast
        let buckets = cache.dailyTokens.compactMap { key, tokens
            -> CodexTokenUsageDailyBucket? in
            guard tokens > 0, let date = Self.date(for: key), date >= cutoff else {
                return nil
            }
            return CodexTokenUsageDailyBucket(startDate: date, tokens: tokens)
        }.sorted { $0.startDate < $1.startDate }
        guard !buckets.isEmpty else { return nil }

        var models: [String: Int64] = [:]
        for (day, values) in cache.dailyModelTokens {
            guard let date = Self.date(for: day), date >= cutoff else { continue }
            for (model, tokens) in values where tokens > 0 {
                models[model] = Self.add(models[model] ?? 0, tokens)
            }
        }
        return CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: buckets.map(\.tokens).max(),
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: buckets,
            modelUsage: models.map {
                CodexModelTokenUsage(model: $0.key, tokens: $0.value)
            }.sorted { $0.tokens > $1.tokens },
            isModelUsagePartial: true
        )
    }

    private func pruneCache() {
        let timestamp = now()
        let calendar = Calendar.current
        let cutoff = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: timestamp)
        ) ?? .distantPast
        cache.dailyTokens = cache.dailyTokens.filter {
            Self.date(for: $0.key).map { $0 >= cutoff } == true
        }
        cache.dailyModelTokens = cache.dailyModelTokens.filter {
            Self.date(for: $0.key).map { $0 >= cutoff } == true
        }
        cache.baselines = cache.baselines.filter {
            timestamp.timeIntervalSince($0.value.observedAt) <= 32 * 86_400
        }
    }

    private func persistCache() {
        cache.schemaVersion = Cache.currentSchemaVersion
        guard let data = try? JSONEncoder().encode(cache), data.count <= 2_000_000 else {
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try data.write(to: cacheURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: cacheURL.path
            )
        } catch {
            // Cache failure never erases otherwise valid live provider data.
        }
    }

    private func syncEventMonitor() {
        eventMonitor?.stop()
        eventMonitor = nil
        guard isMonitoring, isBridgeInstalled else { return }
        let monitor = LocalTelemetryEventMonitor(
            directoryURL: bridge.sessionsDirectoryURL
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.eventDebounceTask?.cancel()
                self?.eventDebounceTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .milliseconds(100))
                    } catch { return }
                    await self?.refresh(forceQuota: false)
                }
            }
        }
        if monitor.start() { eventMonitor = monitor }
    }

    private static func date(for key: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }

    private static func add(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }

    private struct Baseline: Codable, Equatable {
        let inputTokens: Int64
        let outputTokens: Int64
        let model: String?
        let observedAt: Date
    }

    private struct Cache: Codable, Equatable {
        static let currentSchemaVersion = 2
        var schemaVersion = currentSchemaVersion
        var lastQuota: AntigravityQuotaSnapshot?
        var baselines: [String: Baseline] = [:]
        var dailyTokens: [String: Int64] = [:]
        var dailyModelTokens: [String: [String: Int64]] = [:]
    }
}
