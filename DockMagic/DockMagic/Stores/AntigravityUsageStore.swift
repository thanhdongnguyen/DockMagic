import Foundation
import Observation

@MainActor
@Observable
final class AntigravityUsageStore {
    private(set) var state: CodexUsageState = .idle
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var isBridgeInstalled: Bool
    private(set) var isInstallingBridge = false
    private(set) var bridgeError: String?
    var selectedGroupID = "auto" {
        didSet { if oldValue != selectedGroupID { rebuildState() } }
    }

    @ObservationIgnored private let provider: any AntigravityQuotaProviding
    @ObservationIgnored private let bridge: any AntigravityTelemetryBridging
    @ObservationIgnored private let streakTracker: any TokenUsageStreakTracking
    @ObservationIgnored private let readTelemetry: @Sendable () -> AntigravityLocalTelemetry
    @ObservationIgnored private let cacheURL: URL
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let pollingInterval: Duration
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshID: UUID?
    @ObservationIgnored private var monitors: [LocalTelemetryEventMonitor] = []
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastProbeAt: Date?
    @ObservationIgnored private var lastQuota: AntigravityQuotaSnapshot?
    @ObservationIgnored private var latestLocal: AntigravityLocalTelemetry?
    @ObservationIgnored private var lastError: String?

    init(provider: any AntigravityQuotaProviding = AntigravityLocalProbe(),
         bridge: (any AntigravityTelemetryBridging)? = nil,
         streakTracker: (any TokenUsageStreakTracking)? = nil,
         cacheURL: URL? = nil,
         readTelemetry: (@Sendable () -> AntigravityLocalTelemetry)? = nil,
         pollingInterval: Duration = .seconds(30), now: @escaping () -> Date = Date.init) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bridge = bridge ?? AntigravityTelemetryBridge()
        self.provider = provider
        self.bridge = bridge
        self.streakTracker = streakTracker ?? TokenUsageStreakStore()
        self.cacheURL = cacheURL ?? home.appendingPathComponent("Library/Application Support/DockMagic/antigravity-usage.json")
        let directory = bridge.directoryURL
        self.readTelemetry = readTelemetry ?? {
            AntigravityTelemetryReader(directoryURL: directory, home: home).read()
        }
        self.pollingInterval = pollingInterval
        self.now = now
        isBridgeInstalled = bridge.isInstalled()
        if let data = try? Data(contentsOf: self.cacheURL), data.count < 4_000_000,
           let snapshot = try? JSONDecoder().decode(CodexRateLimitSnapshot.self, from: data),
           let cached = snapshot.antigravityTelemetry {
            lastQuota = snapshot.antigravityTelemetry?.quota
            latestLocal = .init(quota: nil, tokens: snapshot.tokenUsage, telemetry: cached.local, observedAt: snapshot.fetchedAt)
            lastError = "Refreshing saved Antigravity usage…"
            state = .stale(snapshot, message: "Refreshing saved Antigravity usage…")
        }
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        syncMonitors()
        pollingTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                do { try await Task.sleep(for: self.pollingInterval) } catch { return }
            }
        }
    }

    func stop() {
        isMonitoring = false
        pollingTask?.cancel(); pollingTask = nil
        refreshID = nil
        refreshTask?.cancel(); refreshTask = nil
        debounceTask?.cancel(); debounceTask = nil
        monitors.forEach { $0.stop() }; monitors = []
        isRefreshing = false
        if case .loading = state { state = .idle }
    }

    func connect() async {
        guard !isInstallingBridge else { return }
        isInstallingBridge = true
        bridgeError = nil
        defer { isInstallingBridge = false }
        do {
            try bridge.install()
            isBridgeInstalled = bridge.isInstalled()
            syncMonitors()
            start()
            await refresh(force: true)
        } catch { bridgeError = error.localizedDescription }
    }

    func disconnect() {
        bridgeError = nil
        do {
            try bridge.uninstall()
            isBridgeInstalled = bridge.isInstalled()
            syncMonitors()
        } catch { bridgeError = error.localizedDescription }
    }

    func refresh(force: Bool = false) async {
        if let refreshTask { await refreshTask.value; return }
        let id = UUID()
        refreshID = id
        isRefreshing = true
        if state.snapshot == nil { state = .loading }
        let shouldProbe = force || lastProbeAt.map { now().timeIntervalSince($0) >= 15 } != false
        let reader = readTelemetry
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            var result: AntigravityQuotaSnapshot?
            var errorMessage: String?
            if shouldProbe {
                do {
                    result = try await self.provider.fetchQuota()
                    try? await self.provider.captureHistory()
                }
                catch { errorMessage = error.localizedDescription }
            }
            let telemetry = await Task.detached(priority: .utility) { reader() }.value
            guard !Task.isCancelled, self.refreshID == id else { return }
            if shouldProbe {
                self.lastProbeAt = self.now()
                self.lastError = errorMessage
            }
            if let result { self.lastQuota = result }
            if let quota = telemetry.quota, quota.observedAt > (self.lastQuota?.observedAt ?? .distantPast) {
                self.lastQuota = quota
                self.lastError = nil
            }
            if telemetry.observedAt != nil { self.latestLocal = telemetry }
            self.isBridgeInstalled = self.bridge.isInstalled()
            self.rebuildState()
            self.isRefreshing = false
            self.refreshTask = nil
            self.refreshID = nil
        }
        refreshTask = task
        await task.value
    }

    func refreshAfterInterruption() async {
        guard isMonitoring else { return }
        monitors.forEach { $0.stop() }; monitors = []
        syncMonitors()
        if let refreshTask { await refreshTask.value }
        guard isMonitoring, !Task.isCancelled else { return }
        await refresh(force: true)
    }

    private func rebuildState() {
        let local = latestLocal
        let group = lastQuota?.selectedGroup(selectedGroupID)
        let observedAt = [lastQuota?.observedAt, local?.observedAt].compactMap { $0 }.max()
        guard let observedAt else {
            state = .unavailable(message: lastError ?? AntigravityDataError.notRunning.localizedDescription)
            return
        }
        let diagnostic: String? = lastError ?? (local?.tokens == nil
            ? "Token history appears after local usage is observed. Costs are shown only when Antigravity reports them."
            : "Local token history is partial. Costs are shown only when Antigravity reports them.")
        var snapshot = CodexRateLimitSnapshot(
            planType: lastQuota?.plan, limitID: "antigravity-local",
            fiveHour: group?.buckets.first { $0.kind == .fiveHour }?.normalizedWindow,
            weekly: group?.buckets.first { $0.kind == .weekly }?.normalizedWindow,
            tokenUsage: local?.tokens,
            antigravityTelemetry: .init(quota: lastQuota, selectedGroupID: selectedGroupID, local: local?.telemetry, diagnostic: diagnostic),
            fetchedAt: observedAt
        )
        snapshot = snapshot.withStreakSummary(streakTracker.observeToday(provider: .antigravity, tokenUsage: snapshot.tokenUsage, at: now()))
        let quotaStale = lastQuota.map { now().timeIntervalSince($0.observedAt) > 15 * 60 } ?? false
        let stale = quotaStale || now().timeIntervalSince(observedAt) > 15 * 60 || (lastError != nil && lastQuota != nil)
        state = stale ? .stale(snapshot, message: lastError ?? "Showing the last observed Antigravity usage.") : .live(snapshot)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try? data.write(to: cacheURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: cacheURL.path)
        }
    }

    private func syncMonitors() {
        monitors.forEach { $0.stop() }; monitors = []
        guard isMonitoring, isBridgeInstalled else { return }
        for folder in ["sessions", "events"] {
            let directory = bridge.directoryURL.appendingPathComponent(folder)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let monitor = LocalTelemetryEventMonitor(directoryURL: directory) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.debounceTask?.cancel()
                    self?.debounceTask = Task { @MainActor [weak self] in
                        do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                        await self?.refresh()
                    }
                }
            }
            if monitor.start() { monitors.append(monitor) }
        }
    }
}
