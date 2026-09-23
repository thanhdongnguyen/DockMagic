import AppKit
import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class CalendarWeatherStore {
    enum Interest: Hashable { case dock, shelf, settings, hover, preview }

    static let todayInterval: TimeInterval = 15 * 60
    static let futureInterval: TimeInterval = 4 * 60 * 60
    static let currentMaximumAge: TimeInterval = 45 * 60
    static let cacheKey = "DockMagicCalendarWeatherCacheV1"

    private(set) var authorization: WeatherLocationAuthorization
    private(set) var cache: CalendarWeatherCache?
    private(set) var todayError: String?
    private(set) var futureError: String?
    private(set) var isRefreshing = false
    private(set) var clockTick = Date()

    @ObservationIgnored private let provider: any CalendarWeatherProviding
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let timeZone: @Sendable () -> TimeZone
    @ObservationIgnored private var interests: Set<Interest> = []
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastCoordinate: WeatherCoordinate?

    init(
        provider: (any CalendarWeatherProviding)? = nil,
        defaults: UserDefaults = DockMagicRuntimeDefaults.current,
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: @escaping @Sendable () -> TimeZone = { .autoupdatingCurrent }
    ) {
        self.provider = provider ?? OpenMeteoCalendarWeatherProvider()
        self.defaults = defaults
        self.now = now
        self.timeZone = timeZone
        authorization = self.provider.authorization()
        if let data = defaults.data(forKey: Self.cacheKey) {
            cache = try? JSONDecoder().decode(CalendarWeatherCache.self, from: data)
        }
        if authorization == .authorized,
           let latitude = cache?.latitude, let longitude = cache?.longitude {
            lastCoordinate = WeatherCoordinate(latitude: latitude, longitude: longitude)
        } else if authorization != .authorized {
            cache = nil
            defaults.removeObject(forKey: Self.cacheKey)
        }
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
    }

    var currentScene: CalendarCurrentWeather? {
        _ = clockTick
        guard authorization == .authorized, let current = cache?.current,
              now().timeIntervalSince(current.observedAt) >= 0,
              now().timeIntervalSince(current.observedAt) <= Self.currentMaximumAge
        else { return nil }
        return current
    }

    var locationName: String? { authorization == .authorized ? cache?.location : nil }

    func day(for date: Date) -> CalendarWeatherDay? {
        _ = clockTick
        guard authorization == .authorized, let cache,
              cache.timeZoneID == timeZone().identifier,
              cache.today?.dayID == CalendarWeatherDates.dayID(for: now(), timeZone: timeZone())
        else { return nil }
        let id = CalendarWeatherDates.dayID(for: date, timeZone: timeZone())
        let todayID = CalendarWeatherDates.dayID(for: now(), timeZone: timeZone())
        if id == todayID { return cache.today }
        guard cache.futureFetchedAt != nil else { return nil }
        return cache.future.first { $0.dayID == id }
    }

    func isLastKnown(_ day: CalendarWeatherDay) -> Bool {
        _ = clockTick
        guard let cache else { return false }
        let todayID = CalendarWeatherDates.dayID(for: now(), timeZone: timeZone())
        if day.dayID == todayID {
            return todayError != nil || now().timeIntervalSince(cache.todayFetchedAt ?? .distantPast) > Self.todayInterval
        }
        return futureError != nil || now().timeIntervalSince(cache.futureFetchedAt ?? .distantPast) > Self.futureInterval
    }

    func forecastError(for date: Date) -> String? {
        let id = CalendarWeatherDates.dayID(for: date, timeZone: timeZone())
        let todayID = CalendarWeatherDates.dayID(for: now(), timeZone: timeZone())
        if id == todayID { return todayError }
        let futureIDs = (1 ... 6).map { CalendarWeatherDates.offsetDayID(from: now(), by: $0, timeZone: timeZone()) }
        return futureIDs.contains(id) ? futureError : nil
    }

    func setInterest(_ interest: Interest, active: Bool) {
        if active { interests.insert(interest) } else { interests.remove(interest) }
        refreshAuthorization()
        if interest == .settings, active, authorization == .notDetermined, NSApp.isActive {
            requestAccess()
        }
        if !interests.isEmpty {
            startPolling()
        } else {
            stopPolling()
            refreshTask?.cancel()
        }
    }

    func requestAccess() {
        guard authorization == .notDetermined else { return }
        Task { await requestAccessAndRefresh() }
    }

    func requestAccessAndRefresh() async {
        guard authorization == .notDetermined else { return }
        await refresh(force: true, requestingAccess: true)
    }

    func refreshAuthorization() {
        let updated = provider.authorization()
        guard updated != authorization else { return }
        authorization = updated
        if !updated.allowsLocationRequest {
            cache = nil
            defaults.removeObject(forKey: Self.cacheKey)
        }
        if !interests.isEmpty {
            startPolling()
        }
    }

    func refreshAfterInterruption() async {
        refreshAuthorization()
        guard authorization == .authorized, !interests.isEmpty else { return }
        await refresh(force: true)
    }

    func refresh(force: Bool = false, requestingAccess: Bool = false) async {
        if let refreshTask { await refreshTask.value; return }
        refreshAuthorization()
        guard (authorization == .authorized || (requestingAccess && authorization == .notDetermined)),
              !interests.isEmpty else { return }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(force: force)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.clockTick = self.now()
                await self.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func performRefresh(force: Bool) async {
        isRefreshing = true
        defer { isRefreshing = false; clockTick = now() }
        let date = now()
        let zone = timeZone()
        let todayID = CalendarWeatherDates.dayID(for: date, timeZone: zone)
        let rollover = cache?.today?.dayID != todayID || cache?.timeZoneID != zone.identifier
        if rollover {
            cache = nil
            lastCoordinate = nil
        }
        let needsToday = force || rollover || cache?.todayFetchedAt == nil
            || date.timeIntervalSince(cache?.todayFetchedAt ?? .distantPast) >= Self.todayInterval
        var needsFuture = force || rollover || cache?.futureFetchedAt == nil
            || date.timeIntervalSince(cache?.futureFetchedAt ?? .distantPast) >= Self.futureInterval

        if needsToday {
            do {
                let result = try await provider.fetch(.today, now: date, timeZone: zone)
                try Task.checkCancellation()
                if let previous = lastCoordinate, Self.distance(previous, result.coordinate) > 10_000 {
                    needsFuture = true
                    cache?.future = []
                    cache?.futureFetchedAt = nil
                }
                lastCoordinate = result.coordinate
                guard let current = result.current, let today = result.days.first else {
                    throw OpenMeteoWeatherError.invalidPayload
                }
                var updated = cache ?? CalendarWeatherCache(
                    location: result.location, timeZoneID: result.timeZoneID,
                    latitude: nil, longitude: nil,
                    current: nil, today: nil, future: [], todayFetchedAt: nil, futureFetchedAt: nil
                )
                updated.location = result.location
                updated.timeZoneID = result.timeZoneID
                updated.latitude = result.coordinate.latitude
                updated.longitude = result.coordinate.longitude
                updated.current = current
                updated.today = today
                updated.todayFetchedAt = date
                cache = updated
                todayError = nil
                refreshAuthorization()
                save()
            } catch is CancellationError { return }
            catch {
                refreshAuthorization()
                todayError = error.localizedDescription
                if authorization != .authorized { cache = nil; defaults.removeObject(forKey: Self.cacheKey) }
            }
        }

        guard authorization == .authorized else { return }
        if needsFuture {
            do {
                let result = try await provider.fetch(.future, now: date, timeZone: zone)
                try Task.checkCancellation()
                if let previous = lastCoordinate, Self.distance(previous, result.coordinate) > 10_000 {
                    cache?.today = nil
                    cache?.todayFetchedAt = nil
                    cache?.current = nil
                }
                lastCoordinate = result.coordinate
                var updated = cache ?? CalendarWeatherCache(
                    location: result.location, timeZoneID: result.timeZoneID,
                    latitude: nil, longitude: nil,
                    current: nil, today: nil, future: [], todayFetchedAt: nil, futureFetchedAt: nil
                )
                updated.location = result.location
                updated.timeZoneID = result.timeZoneID
                updated.latitude = result.coordinate.latitude
                updated.longitude = result.coordinate.longitude
                updated.future = result.days
                updated.futureFetchedAt = date
                cache = updated
                futureError = nil
                save()
            } catch is CancellationError { return }
            catch { futureError = error.localizedDescription }
        }
    }

    private func save() {
        guard let cache, let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: Self.cacheKey)
    }

    private static func distance(_ lhs: WeatherCoordinate, _ rhs: WeatherCoordinate) -> CLLocationDistance {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }
}
