import Foundation
import Observation

protocol ServiceStatusCaching: Sendable {
    func load() -> [ServiceHealthSnapshot]
    func save(_ snapshots: [ServiceHealthSnapshot])
}

struct UserDefaultsServiceStatusCache: ServiceStatusCaching,
    @unchecked Sendable
{
    static let cacheKey = "DockMagicServiceStatusCacheV1"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ServiceHealthSnapshot] {
        guard let data = defaults.data(forKey: Self.cacheKey) else {
            return []
        }
        return (try? JSONDecoder().decode(
            [ServiceHealthSnapshot].self,
            from: data
        )) ?? []
    }

    func save(_ snapshots: [ServiceHealthSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }
        defaults.set(data, forKey: Self.cacheKey)
    }
}

final class InMemoryServiceStatusCache: ServiceStatusCaching,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var snapshots: [ServiceHealthSnapshot]

    init(snapshots: [ServiceHealthSnapshot] = []) {
        self.snapshots = snapshots
    }

    func load() -> [ServiceHealthSnapshot] {
        lock.withLock { snapshots }
    }

    func save(_ snapshots: [ServiceHealthSnapshot]) {
        lock.withLock { self.snapshots = snapshots }
    }
}

private enum ServiceStatusFetchOutcome: Sendable {
    case success(ServiceHealthSnapshot)
    case failure(ServiceStatusProviderID, String)
}

@MainActor
@Observable
final class ServiceStatusStore {
    nonisolated static let operationalPollingInterval: TimeInterval = 5 * 60
    nonisolated static let incidentPollingInterval: TimeInterval = 60
    nonisolated static let staleAfter: TimeInterval = 10 * 60

    private(set) var codexState: ServiceStatusState
    private(set) var claudeCodeState: ServiceStatusState
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false

    @ObservationIgnored
    private let provider: any ServiceStatusProviding

    @ObservationIgnored
    private let cache: any ServiceStatusCaching

    @ObservationIgnored
    private let operationalPollingInterval: TimeInterval

    @ObservationIgnored
    private let incidentPollingInterval: TimeInterval

    @ObservationIgnored
    private let staleAfter: TimeInterval

    @ObservationIgnored
    private let now: @Sendable () -> Date

    @ObservationIgnored
    private var cachedSnapshots: [ServiceStatusProviderID: ServiceHealthSnapshot]

    @ObservationIgnored
    private var consecutiveTotalFailures = 0

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    init(
        provider: any ServiceStatusProviding = ServiceStatusAPIClient(),
        cache: any ServiceStatusCaching = UserDefaultsServiceStatusCache(),
        operationalPollingInterval: TimeInterval = ServiceStatusStore
            .operationalPollingInterval,
        incidentPollingInterval: TimeInterval = ServiceStatusStore
            .incidentPollingInterval,
        staleAfter: TimeInterval = ServiceStatusStore.staleAfter,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(
            operationalPollingInterval > 0,
            "Operational polling interval must be positive."
        )
        precondition(
            incidentPollingInterval > 0,
            "Incident polling interval must be positive."
        )
        precondition(staleAfter > 0, "Stale interval must be positive.")

        self.provider = provider
        self.cache = cache
        self.operationalPollingInterval = operationalPollingInterval
        self.incidentPollingInterval = incidentPollingInterval
        self.staleAfter = staleAfter
        self.now = now

        let currentDate = now()
        let snapshots = Dictionary(
            uniqueKeysWithValues: cache.load().map { ($0.provider, $0) }
        )
        cachedSnapshots = snapshots
        codexState = Self.initialState(
            for: .codex,
            cachedSnapshots: snapshots,
            now: currentDate,
            staleAfter: staleAfter
        )
        claudeCodeState = Self.initialState(
            for: .claudeCode,
            cachedSnapshots: snapshots,
            now: currentDate,
            staleAfter: staleAfter
        )
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
    }

    func state(for provider: ServiceStatusProviderID) -> ServiceStatusState {
        switch provider {
        case .codex: codexState
        case .claudeCode: claudeCodeState
        }
    }

    func start() {
        guard pollingTask == nil else { return }

        let runID = UUID()
        activeRunID = runID
        isMonitoring = true
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.refresh()
                let delay = self.nextPollingDelay
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }

            guard let self, self.activeRunID == runID else { return }
            self.activeRunID = nil
            self.pollingTask = nil
            self.isMonitoring = false
        }
    }

    func stop() {
        activeRunID = nil
        pollingTask?.cancel()
        pollingTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        isMonitoring = false
        isRefreshing = false
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        isRefreshing = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.refreshTask = nil
                self.isRefreshing = false
            }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
    }

    private func performRefresh() async {
        let provider = provider
        async let codexOutcome = Self.fetchOutcome(
            provider: provider,
            id: .codex
        )
        async let claudeOutcome = Self.fetchOutcome(
            provider: provider,
            id: .claudeCode
        )

        let outcomes = await [codexOutcome, claudeOutcome]
        guard !Task.isCancelled else { return }
        let currentDate = now()
        var successCount = 0

        for outcome in outcomes {
            switch outcome {
            case let .success(snapshot):
                successCount += 1
                cachedSnapshots[snapshot.provider] = snapshot
                setState(.live(snapshot), for: snapshot.provider)
            case let .failure(provider, message):
                applyFailure(
                    provider: provider,
                    message: message,
                    now: currentDate
                )
            }
        }

        if successCount == outcomes.count {
            consecutiveTotalFailures = 0
        } else if successCount == 0 {
            consecutiveTotalFailures += 1
        } else {
            consecutiveTotalFailures = 0
        }

        if successCount > 0 {
            cache.save(
                cachedSnapshots.values.sorted {
                    $0.provider.rawValue < $1.provider.rawValue
                }
            )
        }
    }

    private func applyFailure(
        provider: ServiceStatusProviderID,
        message: String,
        now: Date
    ) {
        let previous = state(for: provider).snapshot
            ?? cachedSnapshots[provider]
        guard let previous,
              max(0, now.timeIntervalSince(previous.fetchedAt)) <= staleAfter else {
            setState(
                .unavailable(
                    provider: provider,
                    message: message,
                    lastCheckedAt: previous?.fetchedAt
                ),
                for: provider
            )
            return
        }

        setState(
            .stale(previous, message: "Cached status · \(message)"),
            for: provider
        )
    }

    private func setState(
        _ state: ServiceStatusState,
        for provider: ServiceStatusProviderID
    ) {
        switch provider {
        case .codex:
            codexState = state
        case .claudeCode:
            claudeCodeState = state
        }
    }

    private var nextPollingDelay: TimeInterval {
        if consecutiveTotalFailures > 0 {
            let exponent = min(consecutiveTotalFailures - 1, 5)
            return min(30 * pow(2, Double(exponent)), 10 * 60)
        }
        if codexState.incidentSnapshot != nil
            || claudeCodeState.incidentSnapshot != nil {
            return incidentPollingInterval
        }
        return operationalPollingInterval
    }

    private static func initialState(
        for provider: ServiceStatusProviderID,
        cachedSnapshots: [ServiceStatusProviderID: ServiceHealthSnapshot],
        now: Date,
        staleAfter: TimeInterval
    ) -> ServiceStatusState {
        guard let snapshot = cachedSnapshots[provider],
              max(0, now.timeIntervalSince(snapshot.fetchedAt)) <= staleAfter else {
            return .loading(provider: provider)
        }
        return .stale(snapshot, message: "Refreshing provider status.")
    }

    private nonisolated static func fetchOutcome(
        provider: any ServiceStatusProviding,
        id: ServiceStatusProviderID
    ) async -> ServiceStatusFetchOutcome {
        do {
            return .success(try await provider.fetchStatus(for: id))
        } catch is CancellationError {
            return .failure(id, "Refresh was cancelled.")
        } catch {
            return .failure(id, error.localizedDescription)
        }
    }
}
