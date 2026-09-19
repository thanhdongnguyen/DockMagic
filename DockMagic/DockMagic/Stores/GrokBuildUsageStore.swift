import Foundation
import Observation

@MainActor
@Observable
final class GrokBuildUsageStore {
    let authentication: GrokBuildAuthenticationController
    private(set) var signInCommandCompleted = false
    private(set) var local = GrokBuildObservation<GrokBuildHistorySnapshot>()
    private(set) var activity: GrokBuildActivityLedger?
    private(set) var quota = GrokBuildObservation<GrokBuildQuotaSnapshot>()
    private(set) var connection: GrokBuildConnectionState = .notConfigured
    private(set) var configuration: GrokBuildCLIConfiguration?
    private(set) var cliVersion: String?
    private(set) var isEnabled = false
    private(set) var monitoringEnabled = false
    private(set) var isMonitoring = false
    private(set) var isRefreshingLocal = false
    private(set) var isRefreshingQuota = false
    private(set) var cacheWarning: GrokBuildError?
    private(set) var eventMonitorAvailable = false

    @ObservationIgnored private let cli: any GrokBuildCLIProviding
    @ObservationIgnored private let collector: any GrokBuildLocalCollecting
    @ObservationIgnored private let persistence: GrokBuildHistoryPersistence
    @ObservationIgnored private let monitor: any GrokBuildFileMonitoring
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private let pollingInterval: Duration
    @ObservationIgnored private let quotaInterval: TimeInterval
    @ObservationIgnored private let quotaStaleAfter: TimeInterval
    @ObservationIgnored private var cache: GrokBuildHistoryCache?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var quotaGeneration = UUID()
    @ObservationIgnored private var lifecycleActive = false
    @ObservationIgnored private var configurationTask: Task<Void, Never>?
    @ObservationIgnored private var versionTask: Task<Void, Never>?
    @ObservationIgnored private var localTask: Task<Void, Never>?
    @ObservationIgnored private var quotaTask: Task<Void, Never>?
    @ObservationIgnored private var authenticationTask: Task<Void, Never>?
    @ObservationIgnored private var signInAttempt: GrokBuildSignInAttempt?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var celebrationTask: Task<GrokBuildStreakCelebration?, Never>?
    @ObservationIgnored private var projectionTask: Task<Void, Never>?
    @ObservationIgnored private var nextQuotaAttempt: Date?
    @ObservationIgnored private var nextVersionAttempt: Date?
    @ObservationIgnored private var nextLocalAttempt: Date?
    @ObservationIgnored private var localFailures = 0
    @ObservationIgnored private var quotaFailures = 0

    init(cli: any GrokBuildCLIProviding = GrokBuildCLIProvider(),
         collector: (any GrokBuildLocalCollecting)? = nil,
         repository: any GrokBuildHistoryCaching = GrokBuildHistoryCacheRepository(),
         monitor: any GrokBuildFileMonitoring = GrokBuildFileEventMonitor(),
         pollingInterval: Duration = .seconds(15), quotaInterval: TimeInterval = 300,
         quotaStaleAfter: TimeInterval = 900, now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { Calendar.current },
         authentication: GrokBuildAuthenticationController? = nil) {
        precondition(pollingInterval > .zero && quotaInterval > 0 && quotaStaleAfter > 0)
        self.cli = cli
        self.collector = collector ?? GrokBuildLocalUsageProvider(cli: cli)
        self.persistence = .init(repository: repository)
        self.monitor = monitor
        self.pollingInterval = pollingInterval
        self.quotaInterval = quotaInterval
        self.quotaStaleAfter = quotaStaleAfter
        self.now = now
        self.calendar = calendar
        self.authentication = authentication ?? GrokBuildAuthenticationController()
    }

    deinit {
        configurationTask?.cancel()
        versionTask?.cancel()
        localTask?.cancel()
        quotaTask?.cancel()
        authenticationTask?.cancel()
        pollingTask?.cancel()
        debounceTask?.cancel()
        celebrationTask?.cancel()
        projectionTask?.cancel()
        monitor.stop()
    }

    /// No work occurs until explicitly configured/enabled by app composition.
    /// There is no dependency on which feature currently occupies the Dock.
    func configure(_ value: GrokBuildCLIConfiguration?, enabled: Bool, monitoring: Bool) async {
        stop()
        configuration = value
        isEnabled = enabled
        monitoringEnabled = monitoring
        local = .init()
        activity = nil
        quota = .init()
        connection = .notConfigured
        signInCommandCompleted = false
        cache = nil
        cliVersion = nil
        cacheWarning = nil
        nextLocalAttempt = nil
        nextQuotaAttempt = nil
        nextVersionAttempt = nil
        localFailures = 0
        quotaFailures = 0
        guard enabled, let value else { return }
        lifecycleActive = true
        let epoch = generation
        let task = Task { @MainActor [weak self] in
            if let self { await self.prepareConfiguration(value, epoch: epoch) }
        }
        configurationTask = task
        await task.value
        if generation == epoch { configurationTask = nil }
    }

    private func prepareConfiguration(_ value: GrokBuildCLIConfiguration, epoch: UUID) async {
        do {
            let restored = try await persistence.load(home: value.home)
            guard generation == epoch, lifecycleActive else { return }
            cache = restored ?? .init(home: value.home)
        } catch {
            guard generation == epoch, lifecycleActive else { return }
            cache = .init(home: value.home)
            cacheWarning = .cacheUnavailable
        }
        if var restored = cache {
            if restored.activity == nil {
                restored.activity = .importing(restored.ledger, at: now(), calendar: calendar())
            }
            cache = restored
            activity = restored.activity
            if let collectedAt = restored.collectedAt {
                let snapshot = restored.ledger.snapshot(now: now(), calendar: calendar(), coverage: restored.coverage)
                local = .init(status: .stale, value: snapshot, sourceUpdatedAt: snapshot.sourceUpdatedAt, collectedAt: collectedAt)
            }
        }
        guard generation == epoch, lifecycleActive else { return }
        await reprojectCalendar()
        guard generation == epoch, lifecycleActive else { return }
        startMonitoringIfNeeded()
        await refresh(forceQuota: true)
    }

    func refresh(forceQuota: Bool = false, forceLocal: Bool = false) async {
        guard isEnabled, lifecycleActive else { return }
        let epoch = generation
        await refreshVersion(force: forceLocal)
        guard generation == epoch, lifecycleActive else { return }
        if isMonitoring, !eventMonitorAvailable { startFileMonitor() }
        updateFreshness()
        async let localRefresh: Void = refreshLocal(force: forceLocal)
        async let quotaRefresh: Void = refreshQuota(force: forceQuota)
        _ = await (localRefresh, quotaRefresh)
    }

    private func refreshVersion(force: Bool) async {
        guard let configuration, lifecycleActive else { return }
        if let versionTask { await versionTask.value; return }
        if !force, let nextVersionAttempt, now() < nextVersionAttempt { return }
        let epoch = generation
        let task = Task { @MainActor [weak self, cli] in
            do {
                let version = try await cli.version(configuration: configuration)
                try Task.checkCancellation()
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                if self.cache?.cliVersion != version {
                    self.cache?.fingerprints = [:]
                    self.cache?.retries = [:]
                }
                self.cliVersion = version
                self.cache?.cliVersion = version
                self.nextVersionAttempt = self.now().addingTimeInterval(self.quotaInterval)
            } catch is CancellationError { }
            catch {
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                let failure = Self.safeError(error)
                if self.cliVersion == nil {
                    self.local.status = self.local.value == nil ? .notConfigured : .stale
                    self.local.error = failure
                    self.quota.status = self.quota.value == nil ? .notConfigured : .stale
                    self.quota.error = failure
                    self.connection = .failed(failure)
                }
                self.nextVersionAttempt = self.now().addingTimeInterval(15)
            }
            guard let self, self.generation == epoch else { return }
            self.versionTask = nil
        }
        versionTask = task
        await task.value
    }

    func refreshLocal(force: Bool = false) async {
        let epoch = generation
        while true {
            guard generation == epoch, lifecycleActive, !Task.isCancelled else { return }
            if let projectionTask { await projectionTask.value }
            else if let celebrationTask { _ = await celebrationTask.value }
            else { break }
        }
        guard isEnabled, lifecycleActive, let configuration, let currentCache = cache else { return }
        if let localTask { await localTask.value; return }
        if !force, let nextLocalAttempt, now() < nextLocalAttempt { return }
        let timestamp = now()
        let currentCalendar = calendar()
        let mustRebucket = currentCache.calendarIdentifier != currentCalendar.timeZone.identifier
        local.lastAttemptAt = timestamp
        if local.value == nil { local.status = .loading }
        isRefreshingLocal = true
        let task = Task { @MainActor [weak self, collector, persistence] in
            do {
                let result = try await collector.collect(configuration: configuration, cache: currentCache,
                    now: timestamp, calendar: currentCalendar, force: force || mustRebucket)
                try Task.checkCancellation()
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                self.cache = result.cache
                self.activity = result.cache.activity
                let hasTokens = result.snapshot.days.contains { $0.tokens != nil }
                let status: GrokBuildObservationStatus = hasTokens ? (result.readableRootCount > 0 ? .live : .stale) : .unavailable
                self.local = .init(status: status, value: result.snapshot,
                    sourceUpdatedAt: result.snapshot.sourceUpdatedAt, collectedAt: result.cache.collectedAt, lastAttemptAt: timestamp)
                self.localFailures = 0
                self.nextLocalAttempt = nil
                do {
                    try await persistence.save(result.cache)
                    if self.generation == epoch { self.cacheWarning = nil }
                } catch {
                    if self.generation == epoch { self.cacheWarning = .cacheUnavailable }
                }
            } catch is CancellationError { }
            catch {
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                self.local.status = self.local.value == nil ? .failed : .stale
                self.local.error = Self.safeError(error)
                self.localFailures += 1
                self.nextLocalAttempt = self.now().addingTimeInterval(Self.backoff(self.localFailures))
            }
            guard let self, self.generation == epoch else { return }
            self.localTask = nil
            self.isRefreshingLocal = false
        }
        localTask = task
        await task.value
    }

    func refreshQuota(force: Bool = false) async {
        guard isEnabled, lifecycleActive, let configuration,
              connection != .signingIn, connection != .signingOut else { return }
        if let quotaTask { await quotaTask.value; return }
        if !force, let nextQuotaAttempt, now() < nextQuotaAttempt { return }
        let epoch = generation
        let quotaEpoch = UUID()
        quotaGeneration = quotaEpoch
        let timestamp = now()
        quota.lastAttemptAt = timestamp
        if quota.value == nil { quota.status = .loading; connection = .checking }
        isRefreshingQuota = true
        let task = Task { @MainActor [weak self, cli] in
            do {
                let result = try await cli.billing(configuration: configuration, observedAt: timestamp)
                try Task.checkCancellation()
                guard let self, self.generation == epoch, self.quotaGeneration == quotaEpoch, self.lifecycleActive else { return }
                self.quota = .init(status: .live, value: result, collectedAt: self.now(), lastAttemptAt: timestamp)
                self.connection = .connected
                self.quotaFailures = 0
                self.nextQuotaAttempt = self.now().addingTimeInterval(self.quotaInterval)
            } catch is CancellationError { }
            catch {
                guard let self, self.generation == epoch, self.quotaGeneration == quotaEpoch, self.lifecycleActive else { return }
                let failure = Self.safeError(error)
                if failure == .authenticationRequired || failure == .unsupportedAuthentication {
                    self.quota = .init(status: .notConfigured, error: failure, lastAttemptAt: timestamp)
                    self.connection = failure == .authenticationRequired ? .signedOut : .unsupportedAuthentication
                    self.nextQuotaAttempt = self.now().addingTimeInterval(self.quotaInterval)
                } else {
                    self.quota.status = self.quota.value == nil ? .unavailable : .stale
                    self.quota.error = failure
                    self.connection = .failed(failure)
                    self.quotaFailures += 1
                    self.nextQuotaAttempt = self.now().addingTimeInterval(Self.backoff(self.quotaFailures))
                }
            }
            guard let self, self.generation == epoch, self.quotaGeneration == quotaEpoch else { return }
            self.quotaTask = nil
            self.isRefreshingQuota = false
        }
        quotaTask = task
        await task.value
    }

    func beginSignIn() -> GrokBuildSignInAttempt? {
        guard isEnabled, lifecycleActive, let configuration,
              connection != .signingIn, connection != .signingOut else { return nil }
        cancelQuotaRefresh()
        quota = .init(status: .notConfigured)
        connection = .signingIn
        signInCommandCompleted = false
        let attempt = GrokBuildSignInAttempt(configuration: configuration)
        signInAttempt = attempt
        return attempt
    }

    func finishSignIn(attempt: GrokBuildSignInAttempt, exitCode: Int32?, failure: GrokBuildError? = nil) async {
        guard isEnabled, lifecycleActive, connection == .signingIn,
              signInAttempt == attempt, configuration == attempt.configuration else { return }
        // Consume before any suspension: cancellation, duplicate process-exit
        // callbacks and old terminal teardown cannot complete a later login.
        signInAttempt = nil
        guard exitCode == 0, failure == nil else {
            connection = .failed(failure ?? (exitCode == nil ? .cancelled : .commandFailed))
            return
        }
        signInCommandCompleted = true
        connection = .checking
        // A new probe, not a joined pre-login task, is the connection proof.
        await refreshQuota(force: true)
    }

    func signOut() async {
        guard isEnabled, lifecycleActive, let configuration, connection != .signingIn, !authentication.isRunning else { return }
        if let authenticationTask { await authenticationTask.value; return }
        cancelQuotaRefresh()
        connection = .signingOut
        signInCommandCompleted = false
        let epoch = generation
        let task = Task { @MainActor [weak self, cli] in
            do {
                try await cli.signOut(configuration: configuration)
                try Task.checkCancellation()
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                self.quota = .init(status: .notConfigured, error: .authenticationRequired)
                self.connection = .signedOut
                self.nextQuotaAttempt = self.now().addingTimeInterval(self.quotaInterval)
            } catch is CancellationError {
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                self.connection = .failed(.cancelled)
                self.quota = .init(status: .unavailable, error: .cancelled)
            }
            catch {
                guard let self, self.generation == epoch, self.lifecycleActive else { return }
                let failure = Self.safeError(error)
                self.connection = .failed(failure)
                if failure == .signOutUnverified {
                    // Do not display quota from the account just logged out.
                    self.quota = .init(status: .unavailable, error: failure)
                    self.nextQuotaAttempt = self.now().addingTimeInterval(self.quotaInterval)
                } else {
                    self.quota.status = self.quota.value == nil ? .unavailable : .stale
                    self.quota.error = failure
                }
            }
            guard let self, self.generation == epoch else { return }
            self.authenticationTask = nil
        }
        authenticationTask = task
        await task.value
    }

    func cancelAuthentication() {
        if authentication.isRunning, connection == .checking {
            cancelQuotaRefresh()
            quota = .init(status: .unavailable, error: .cancelled)
            connection = .failed(.cancelled)
            nextQuotaAttempt = now().addingTimeInterval(quotaInterval)
        }
        authentication.cancel()
        authenticationTask?.cancel()
    }

    func updateFreshness() {
        if let date = quota.collectedAt, now().timeIntervalSince(date) >= quotaStaleAfter, quota.value != nil {
            quota.status = .stale
        }
    }

    func continuity() -> GrokBuildContinuitySnapshot? {
        activity?.snapshot(at: now(), calendar: calendar())
    }

    /// Serialize with collection so an in-flight scan cannot overwrite a
    /// persisted celebration claim with the pre-claim copy of the cache.
    func claimCelebration() async -> GrokBuildStreakCelebration? {
        let epoch = generation
        while true {
            guard generation == epoch, lifecycleActive, !Task.isCancelled else { return nil }
            if let localTask { await localTask.value }
            else if let projectionTask { await projectionTask.value }
            else { break }
        }
        guard generation == epoch, isEnabled, lifecycleActive, celebrationTask == nil,
              var candidate = cache, var activity = candidate.activity,
              let celebration = activity.claimCelebration(at: now(), calendar: calendar()) else { return nil }
        candidate.activity = activity
        let task = Task { @MainActor [weak self, persistence, candidate] () -> GrokBuildStreakCelebration? in
            defer {
                // Clear before task completion: another MainActor operation
                // may already be awaiting this task's value in its barrier.
                if let self, self.generation == epoch { self.celebrationTask = nil }
            }
            do {
                try Task.checkCancellation()
                try await persistence.save(candidate)
                try Task.checkCancellation()
                guard let self, self.generation == epoch, self.lifecycleActive else { return nil }
                self.cache = candidate
                self.activity = candidate.activity
                self.cacheWarning = nil
                // The disk write may span midnight or a timezone change. The
                // claim stays consumed, but an old-day banner must not surface.
                let currentCalendar = self.calendar()
                guard candidate.activity?.timeZoneIdentifier == currentCalendar.timeZone.identifier,
                      TokenUsageCalendarDay.containing(self.now(), calendar: currentCalendar).key == celebration.dayKey else { return nil }
                return celebration
            } catch {
                if let self, self.generation == epoch, !(error is CancellationError) {
                    self.cacheWarning = .cacheUnavailable
                }
                return nil
            }
        }
        celebrationTask = task
        return await task.value
    }

    /// Calendar events change the projection, not source freshness. Serialize
    /// with scans and claims so persistence cannot restore a pre-claim cache.
    /// No CLI, source scan, quota request or new activity observation occurs.
    func reprojectCalendar() async {
        let epoch = generation
        while true {
            guard generation == epoch, isEnabled, lifecycleActive, !Task.isCancelled else { return }
            if let localTask { await localTask.value }
            else if let celebrationTask { _ = await celebrationTask.value }
            else if let projectionTask { await projectionTask.value }
            else { break }
        }
        guard var candidate = cache else { return }
        let previous = candidate
        let timestamp = now()
        let currentCalendar = calendar()
        if candidate.activity == nil {
            candidate.activity = .importing(candidate.ledger, at: timestamp, calendar: currentCalendar)
        }
        candidate.activity?.reproject(at: timestamp, calendar: currentCalendar)
        candidate.ledger.prune(now: timestamp, calendar: currentCalendar)
        if candidate.ledger != previous.ledger {
            // A later timezone/clock reversal may bring the pruned window edge
            // back into range. Invalidate scan reuse so the next authorized
            // collection can recover it even if source fingerprints match.
            candidate.calendarIdentifier = nil
        }
        cache = candidate
        activity = candidate.activity
        if local.value != nil {
            local.value = candidate.ledger.snapshot(now: timestamp, calendar: currentCalendar, coverage: candidate.coverage)
        }
        updateFreshness()
        // Otherwise keep the last *collection* timezone, not projection time.
        guard candidate != previous || cacheWarning != nil else { return }
        let task = Task { @MainActor [weak self, persistence, candidate] in
            do {
                try Task.checkCancellation()
                try await persistence.save(candidate)
                try Task.checkCancellation()
                if let self, self.generation == epoch { self.cacheWarning = nil }
            } catch {
                if let self, self.generation == epoch, !(error is CancellationError) {
                    self.cacheWarning = .cacheUnavailable
                }
            }
            if let self, self.generation == epoch { self.projectionTask = nil }
        }
        projectionTask = task
        await task.value
    }

    func stop() {
        authentication.cancel()
        lifecycleActive = false
        generation = UUID()
        signInAttempt = nil
        configurationTask?.cancel(); configurationTask = nil
        versionTask?.cancel(); versionTask = nil
        localTask?.cancel(); localTask = nil
        cancelQuotaRefresh()
        authenticationTask?.cancel(); authenticationTask = nil
        pollingTask?.cancel(); pollingTask = nil
        debounceTask?.cancel(); debounceTask = nil
        celebrationTask?.cancel(); celebrationTask = nil
        projectionTask?.cancel(); projectionTask = nil
        monitor.stop()
        isMonitoring = false
        eventMonitorAvailable = false
        isRefreshingLocal = false
        if local.value != nil { local.status = .stale }
        else if local.status == .loading { local.status = .unavailable; local.error = .cancelled }
        if quota.value != nil { quota.status = .stale }
        else if quota.status == .loading { quota.status = .unavailable; quota.error = .cancelled }
        if connection == .checking || connection == .signingIn || connection == .signingOut {
            connection = .failed(.cancelled)
        }
    }

    func resume() async {
        guard isEnabled, configuration != nil else { return }
        lifecycleActive = true
        // Rebucket retained UTC observations without a CLI call, including in
        // manual-only mode. Resuming is not authority to restart background IO
        // when the user has disabled monitoring.
        let epoch = generation
        await reprojectCalendar()
        guard generation == epoch, lifecycleActive, !Task.isCancelled else { return }
        guard monitoringEnabled else { return }
        startMonitoringIfNeeded()
        await refresh(forceQuota: true)
    }

    private func cancelQuotaRefresh() {
        quotaGeneration = UUID()
        quotaTask?.cancel(); quotaTask = nil
        isRefreshingQuota = false
    }

    private func startMonitoringIfNeeded() {
        guard isEnabled, lifecycleActive, monitoringEnabled, pollingTask == nil, configuration != nil else { return }
        startFileMonitor()
        isMonitoring = true
        let interval = pollingInterval
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) } catch { break }
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    private func startFileMonitor() {
        guard let configuration else { return }
        let epoch = generation
        eventMonitorAvailable = monitor.start(home: configuration.home) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == epoch else { return }
                self.scheduleFileRefresh()
            }
        }
    }

    private func scheduleFileRefresh() {
        guard isMonitoring, lifecycleActive else { return }
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            await self?.refreshLocal()
        }
    }

    private static func safeError(_ error: Error) -> GrokBuildError { error as? GrokBuildError ?? .commandFailed }
    private static func backoff(_ count: Int) -> TimeInterval { min(300, 15 * pow(2, Double(min(count - 1, 8)))) }
}
