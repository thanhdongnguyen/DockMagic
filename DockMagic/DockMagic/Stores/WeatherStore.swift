import Foundation
import Observation

enum WeatherPollingDefaults {
    static let interval: Duration = .seconds(10 * 60)
}

protocol WeatherSnapshotCaching: Sendable {
    func load() -> WeatherSnapshot?
    func save(_ snapshot: WeatherSnapshot)
}

struct UserDefaultsWeatherSnapshotCache: WeatherSnapshotCaching, @unchecked Sendable {
    // A new namespace prevents legacy Apple Weather/Shortcut snapshots from
    // being displayed under Open-Meteo attribution.
    static let cacheKey = "DockMagicOpenMeteoWeatherSnapshotCacheV1"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WeatherSnapshot? {
        guard let data = defaults.data(forKey: Self.cacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }

    func save(_ snapshot: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: Self.cacheKey)
    }
}

@MainActor
@Observable
final class WeatherStore {
    static let defaultPollingInterval = WeatherPollingDefaults.interval

    private(set) var state: WeatherState
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var locationAuthorization: WeatherLocationAuthorization

    @ObservationIgnored
    private let provider: any WeatherSnapshotProviding

    @ObservationIgnored
    private let authorizationProvider: any WeatherLocationAuthorizationProviding

    @ObservationIgnored
    private let cache: any WeatherSnapshotCaching

    @ObservationIgnored
    private let pollingInterval: Duration

    @ObservationIgnored
    private let staleAfter: TimeInterval

    @ObservationIgnored
    private let now: @Sendable () -> Date

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRefreshID: UUID?

    init(
        provider: (any WeatherSnapshotProviding)? = nil,
        authorizationProvider: (any WeatherLocationAuthorizationProviding)? = nil,
        cache: any WeatherSnapshotCaching = UserDefaultsWeatherSnapshotCache(),
        pollingInterval: Duration = WeatherPollingDefaults.interval,
        staleAfter: TimeInterval = 45 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(pollingInterval > .zero, "Polling interval must be positive.")
        precondition(staleAfter > 0, "Stale interval must be positive.")
        let resolvedProvider = provider ?? OpenMeteoWeatherProvider()
        self.provider = resolvedProvider
        self.authorizationProvider = authorizationProvider
            ?? (resolvedProvider as? any WeatherLocationAuthorizationProviding)
            ?? AssumedAuthorizedWeatherLocationProvider()
        self.cache = cache
        self.pollingInterval = pollingInterval
        self.staleAfter = staleAfter
        self.now = now
        locationAuthorization = self.authorizationProvider
            .weatherLocationAuthorization()

        if let cached = cache.load() {
            state = .stale(
                cached,
                message: "Showing saved weather while DockMagic refreshes."
            )
        } else {
            state = .idle
        }
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

        refreshLocationAuthorizationStatus()
        guard locationAuthorization.allowsLocationRequest else {
            applyLocationAuthorizationFailure()
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

    func refreshLocationAuthorizationStatus() {
        locationAuthorization = authorizationProvider
            .weatherLocationAuthorization()
    }

    private func performRefresh(
        id: UUID,
        previousSnapshot: WeatherSnapshot?
    ) async {
        defer {
            if activeRefreshID == id {
                activeRefreshID = nil
                refreshTask = nil
                isRefreshing = false
            }
        }

        do {
            let snapshot = try await provider.fetchWeather()
            try Task.checkCancellation()
            guard activeRefreshID == id else {
                return
            }

            refreshLocationAuthorizationStatus()

            cache.save(snapshot)
            if now().timeIntervalSince(snapshot.observedAt) > staleAfter {
                state = .stale(
                    snapshot,
                    message: "Open-Meteo returned weather older than 45 minutes."
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
            refreshLocationAuthorizationStatus()
            let failureMessage = locationAuthorization.errorDescription
                ?? error.localizedDescription
            if let previousSnapshot {
                state = .stale(previousSnapshot, message: failureMessage)
            } else {
                state = .unavailable(message: failureMessage)
            }
        }
    }

    private func applyLocationAuthorizationFailure() {
        guard let message = locationAuthorization.errorDescription else {
            return
        }

        if let snapshot = state.snapshot {
            state = .stale(snapshot, message: message)
        } else {
            state = .unavailable(message: message)
        }
    }
}

private struct AssumedAuthorizedWeatherLocationProvider:
    WeatherLocationAuthorizationProviding
{
    @MainActor
    func weatherLocationAuthorization() -> WeatherLocationAuthorization {
        .authorized
    }
}
