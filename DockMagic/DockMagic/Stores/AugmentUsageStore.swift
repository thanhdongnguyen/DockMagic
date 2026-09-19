import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AugmentUsageStore {
    static let freshnessInterval: TimeInterval = 6 * 60 * 60
    private(set) var state = AugmentUsageState()
    private(set) var isConfigured = false
    private(set) var isConnecting = false
    private(set) var connectionMessage: String?
    private(set) var historyDays = 30
    private(set) var models: AugmentResourceSnapshot?
    private(set) var modelsLoading = false
    private(set) var modelsError: String?
    private(set) var cacheMessage: String?

    @ObservationIgnored private let client: any AugmentAnalyticsProviding
    @ObservationIgnored private let vault: any AugmentCredentialVault
    @ObservationIgnored private let cache: AugmentHistoryCache
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let manualCooldown: TimeInterval
    @ObservationIgnored private var connectionID: String
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var connectionAttempt = UUID()
    @ObservationIgnored private var authBlocked = false
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var selected = false
    @ObservationIgnored private var settingsVisible = false
    @ObservationIgnored private var dashboardCount = 0
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var modelTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<AugmentUsageSnapshot, Error>?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private let network: any NetworkAvailabilityMonitoring
    @ObservationIgnored private var resourcesCache: [AugmentDateRange: AugmentResourceSnapshot] = [:]
    @ObservationIgnored private var resourceTasks: [AugmentDateRange: Task<AugmentResourceSnapshot, Error>] = [:]

    init(client: any AugmentAnalyticsProviding = AugmentAnalyticsClient(),
         vault: any AugmentCredentialVault = KeychainAugmentCredentialVault(),
         cache: AugmentHistoryCache = AugmentHistoryCache(), defaults: UserDefaults = .standard,
         now: @escaping @Sendable () -> Date = { Date() }, manualCooldown: TimeInterval = 30,
         network: (any NetworkAvailabilityMonitoring)? = nil) {
        self.client = client; self.vault = vault; self.cache = cache; self.defaults = defaults
        self.now = now; self.manualCooldown = manualCooldown
        self.network = network ?? NetworkAvailabilityMonitor()
        connectionID = defaults.string(forKey: "DockMagicAugmentConnectionID") ?? UUID().uuidString
        defaults.set(connectionID, forKey: "DockMagicAugmentConnectionID")
        do {
            isConfigured = try vault.loadAccessToken() != nil
            if isConfigured, let snapshot = cache.load(connectionID: connectionID) {
                state.snapshot = snapshot
                state.observation = now().timeIntervalSince(snapshot.fetchedAt) < Self.freshnessInterval
                    ? (snapshot.days.isEmpty ? .unavailable : .live) : .stale
            } else if isConfigured { state.observation = .unavailable }
        } catch { connectionMessage = "Could not access the Augment token in Keychain." }
    }

    private var interested: Bool { selected || settingsVisible || dashboardCount > 0 }
    private var desiredRange: AugmentDateRange { .reported(days: historyDays, now: now()) }

    func setSelected(_ value: Bool) { selected = value; updateInterest() }
    func setSettingsVisible(_ value: Bool) { settingsVisible = value; updateInterest() }
    func setDashboardVisible(_ visible: Bool) {
        dashboardCount = max(0, dashboardCount + (visible ? 1 : -1)); updateInterest()
        if visible { loadModels() }
    }

    private func updateInterest() {
        if interested {
            if wakeObserver == nil {
                wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.refreshIfNeeded() }
                }
                network.start { [weak self] in self?.refreshIfNeeded() }
            }
            if timer == nil {
                timer = Task { [weak self] in
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) } catch { return }
                        self?.refreshIfNeeded()
                    }
                }
            }
            refreshIfNeeded()
        } else {
            timer?.cancel(); timer = nil
            network.stop()
            if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver); self.wakeObserver = nil }
        }
    }

    func setHistoryDays(_ days: Int) {
        guard [7, 30, 90].contains(days), historyDays != days else { return }
        historyDays = days
        invalidateRequests()
        models = nil; modelsError = nil
        refresh(force: true)
    }

    func refreshIfNeeded() {
        guard interested else { return }
        if let snapshot = state.snapshot, now().timeIntervalSince(snapshot.fetchedAt) >= Self.freshnessInterval {
            state.observation = .stale
        }
        refresh(force: false)
    }

    func refreshManually() {
        guard lastAttempt.map({ now().timeIntervalSince($0) >= manualCooldown }) ?? true else { return }
        resourcesCache.removeAll()
        refresh(force: true)
    }

    private func refresh(force: Bool) {
        guard isConfigured, !isConnecting, !authBlocked, refreshTask == nil else { return }
        if !force {
            if let snapshot = state.snapshot, snapshot.range == desiredRange,
               now().timeIntervalSince(snapshot.fetchedAt) < Self.freshnessInterval { return }
            // Failed requests never turn the one-minute freshness check into polling.
            if let lastAttempt, now().timeIntervalSince(lastAttempt) < Self.freshnessInterval { return }
        }
        let token: String
        do {
            guard let stored = try vault.loadAccessToken() else { isConfigured = false; state = .init(); return }
            token = stored
        } catch { connectionMessage = "Could not access the Augment token in Keychain."; return }
        let current = generation, range = desiredRange
        lastAttempt = now()
        state.isRefreshing = true
        if state.snapshot == nil { state.observation = .loading }
        state.message = nil
        refreshTask = Task { [weak self, client] in
            do {
                let snapshot = try await client.overview(token: token, range: range)
                guard let self, self.generation == current, !Task.isCancelled else { return }
                self.state = AugmentUsageState(snapshot: snapshot, observation: snapshot.days.isEmpty ? .unavailable : .live)
                do { try self.cache.save(snapshot, connectionID: self.connectionID); self.cacheMessage = nil }
                catch { self.cacheMessage = "Usage is available, but its local cache could not be saved." }
                self.refreshTask = nil
                if self.dashboardCount > 0 { self.loadModels() }
            } catch {
                guard let self, self.generation == current, !Task.isCancelled else { return }
                self.state.isRefreshing = false
                self.state.observation = self.state.snapshot == nil ? .failed : .stale
                self.state.message = Self.message(error)
                self.authBlocked = (error as? AugmentAPIError)?.needsConnectionAction ?? false
                self.refreshTask = nil
            }
        }
    }

    @discardableResult
    func connect(token: String) async -> Bool {
        guard !isConnecting else { return false }
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            connectionMessage = "Enter an API token without spaces."; return false
        }
        isConnecting = true; connectionMessage = nil
        let attempt = UUID(); connectionAttempt = attempt
        let range = AugmentDateRange.reported(days: 1, now: now())
        let task = Task { [client] in try await client.overview(token: normalized, range: range) }
        connectionTask = task
        do {
            _ = try await task.value
            guard attempt == connectionAttempt else { return false }
            guard !Task.isCancelled else { isConnecting = false; connectionTask = nil; return false }
            try vault.storeAccessToken(normalized)
            invalidateRequests()
            connectionID = UUID().uuidString
            defaults.set(connectionID, forKey: "DockMagicAugmentConnectionID")
            do { try cache.clear(); cacheMessage = nil }
            catch { cacheMessage = "The previous local cache could not be removed. It will not be reused." }
            state = .init(); models = nil; modelsError = nil; resourcesCache.removeAll()
            isConfigured = true; authBlocked = false; lastAttempt = nil
            isConnecting = false; connectionTask = nil
            connectionMessage = "Connected to organization analytics."
            refresh(force: true)
            return true
        } catch {
            guard attempt == connectionAttempt else { return false }
            isConnecting = false; connectionTask = nil
            connectionMessage = error is AugmentCredentialVaultError ? "Could not save the token in Keychain." : Self.message(error)
            return false
        }
    }

    func testConnection() async {
        guard !isConnecting else { return }
        isConnecting = true; connectionMessage = nil
        let attempt = UUID(); connectionAttempt = attempt
        do {
            guard let token = try vault.loadAccessToken() else { isConnecting = false; return }
            let range = AugmentDateRange.reported(days: 1, now: now())
            let task = Task { [client] in try await client.overview(token: token, range: range) }
            connectionTask = task
            _ = try await task.value
            guard attempt == connectionAttempt else { return }
            authBlocked = false; connectionMessage = "Analytics connection verified."
            isConnecting = false; connectionTask = nil
            refresh(force: true)
        } catch {
            guard attempt == connectionAttempt else { return }
            isConnecting = false; connectionTask = nil; connectionMessage = Self.message(error)
            if (error as? AugmentAPIError)?.needsConnectionAction == true { authBlocked = true }
        }
    }

    func disconnect() {
        connectionAttempt = UUID(); connectionTask?.cancel(); connectionTask = nil; isConnecting = false
        invalidateRequests()
        do { try vault.deleteAccessToken() }
        catch { connectionMessage = "Could not remove the token from Keychain. Retry Disconnect."; return }
        isConfigured = false; authBlocked = false; lastAttempt = nil
        state = .init(); models = nil; modelsError = nil; resourcesCache.removeAll()
        do { try cache.clear(); cacheMessage = nil } catch { cacheMessage = "Disconnected. Local cache removal failed; use Clear local history to retry." }
        connectionMessage = "Token removed from this Mac. Revoke it on Augment to disable it elsewhere."
    }

    func clearHistory() {
        invalidateRequests(); resourcesCache.removeAll()
        state = AugmentUsageState(observation: isConfigured ? .unavailable : .notConfigured)
        models = nil; modelsError = nil
        lastAttempt = now() // Wait for manual refresh or the next scheduled refresh.
        do { try cache.clear(); cacheMessage = "Local history cleared." }
        catch { cacheMessage = "Could not remove the local cache. Try again." }
    }

    func loadModels() {
        guard isConfigured, !authBlocked, !isConnecting, modelTask == nil else { return }
        let range = state.snapshot?.range ?? desiredRange, current = generation
        if models?.range == range, modelsError == nil,
           let cached = resourcesCache[range], now().timeIntervalSince(cached.fetchedAt) < Self.freshnessInterval { return }
        modelsLoading = true; modelsError = nil
        if models?.range != range { models = nil }
        modelTask = Task { [weak self] in
            guard let self else { return }
            do {
                let value = try await self.resourceDetail(range: range)
                guard self.generation == current, !Task.isCancelled else { return }
                self.models = value
            } catch {
                guard self.generation == current, !Task.isCancelled else { return }
                self.modelsError = Self.message(error)
            }
            self.modelsLoading = false; self.modelTask = nil
            if let snapshot = self.state.snapshot, snapshot.range != range { self.loadModels() }
        }
    }

    func resourceDetail(range: AugmentDateRange) async throws -> AugmentResourceSnapshot {
        guard !authBlocked else { throw AugmentAPIError.permission }
        if let cached = resourcesCache[range], now().timeIntervalSince(cached.fetchedAt) < Self.freshnessInterval { return cached }
        let task: Task<AugmentResourceSnapshot, Error>
        if let existing = resourceTasks[range] { task = existing }
        else {
            guard let token = try vault.loadAccessToken() else { throw AugmentAPIError.authentication }
            task = Task { [client] in try await client.resources(token: token, range: range) }
            resourceTasks[range] = task
        }
        let current = generation
        do {
            let value = try await task.value
            guard generation == current, !Task.isCancelled else { throw CancellationError() }
            resourcesCache[range] = value; resourceTasks[range] = nil
            return value
        } catch {
            if generation == current {
                resourceTasks[range] = nil
                if (error as? AugmentAPIError)?.needsConnectionAction == true { authBlocked = true; connectionMessage = Self.message(error) }
            }
            throw error
        }
    }

    private func invalidateRequests() {
        generation += 1
        refreshTask?.cancel(); refreshTask = nil; state.isRefreshing = false
        modelTask?.cancel(); modelTask = nil; modelsLoading = false
        resourceTasks.values.forEach { $0.cancel() }; resourceTasks.removeAll()
    }
    func stop() {
        selected = false; settingsVisible = false; dashboardCount = 0
        updateInterest(); invalidateRequests()
        connectionAttempt = UUID(); connectionTask?.cancel(); connectionTask = nil; isConnecting = false
    }
    static func message(_ error: Error) -> String {
        (error as? AugmentAPIError)?.errorDescription ?? "Could not load Augment analytics. Retry or check Settings."
    }
}
