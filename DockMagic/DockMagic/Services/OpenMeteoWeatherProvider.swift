import CoreLocation
import Foundation

enum OpenMeteoWeatherError: LocalizedError, Equatable {
    case locationServicesDisabled
    case locationPermissionDenied
    case locationUnavailable(String)
    case locationTimedOut
    case locationRequestInProgress
    case invalidRequest
    case invalidResponse
    case httpFailure(statusCode: Int, reason: String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            "Location Services is turned off. Enable it in System Settings to show local weather."
        case .locationPermissionDenied:
            "DockMagic does not have Location access. Allow it in System Settings > Privacy & Security > Location Services."
        case let .locationUnavailable(message):
            "Your current location is unavailable: \(message)"
        case .locationTimedOut:
            "DockMagic could not determine your location in time."
        case .locationRequestInProgress:
            "A location request is already in progress."
        case .invalidRequest:
            "DockMagic could not create the Open-Meteo request."
        case .invalidResponse:
            "Open-Meteo returned an invalid response."
        case let .httpFailure(statusCode, reason):
            if let reason, !reason.isEmpty {
                "Open-Meteo returned HTTP \(statusCode): \(reason)"
            } else {
                "Open-Meteo returned HTTP \(statusCode)."
            }
        case .invalidPayload:
            "Open-Meteo returned weather data DockMagic could not validate."
        }
    }
}

enum WeatherLocationAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case servicesDisabled

    var allowsLocationRequest: Bool {
        switch self {
        case .notDetermined, .authorized:
            true
        case .denied, .restricted, .servicesDisabled:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .notDetermined, .authorized:
            nil
        case .denied:
            "DockMagic does not have Location access. Enable DockMagic in System Settings > Privacy & Security > Location Services, then refresh Weather."
        case .restricted:
            "Location access is restricted on this Mac. Review Location Services in System Settings or contact the Mac administrator."
        case .servicesDisabled:
            "Location Services is turned off. Enable it in System Settings > Privacy & Security > Location Services, then refresh Weather."
        }
    }
}

protocol WeatherLocationAuthorizationProviding: Sendable {
    @MainActor
    func weatherLocationAuthorization() -> WeatherLocationAuthorization
}

struct WeatherCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90 ... 90).contains(latitude)
            && (-180 ... 180).contains(longitude)
    }
}

protocol WeatherCoordinateProviding: WeatherLocationAuthorizationProviding {
    @MainActor
    func currentCoordinate() async throws -> WeatherCoordinate
}

extension WeatherCoordinateProviding {
    @MainActor
    func weatherLocationAuthorization() -> WeatherLocationAuthorization {
        .authorized
    }
}

protocol WeatherLocationNameProviding: Sendable {
    @MainActor
    func locationName(for coordinate: WeatherCoordinate) async -> String?
}

@MainActor
final class CoreLocationWeatherLocationNameProvider:
    WeatherLocationNameProviding,
    @unchecked Sendable
{
    private let geocoder: CLGeocoder

    init(geocoder: CLGeocoder = CLGeocoder()) {
        self.geocoder = geocoder
    }

    func locationName(for coordinate: WeatherCoordinate) async -> String? {
        guard coordinate.isValid else {
            return nil
        }

        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let placemark = await withTaskCancellationHandler {
            (try? await geocoder.reverseGeocodeLocation(location))?.first
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.geocoder.cancelGeocode()
            }
        }
        guard let placemark else {
            return nil
        }

        let primary = [
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
            placemark.name
        ]
        .compactMap(Self.normalizedComponent)
        .first
        let country = Self.normalizedComponent(placemark.country)
        let components = [primary, country]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, component in
                guard !result.contains(where: {
                    $0.caseInsensitiveCompare(component) == .orderedSame
                }) else {
                    return
                }
                result.append(component)
            }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private static func normalizedComponent(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

private struct UnresolvedWeatherLocationNameProvider:
    WeatherLocationNameProviding
{
    @MainActor
    func locationName(for coordinate: WeatherCoordinate) async -> String? {
        nil
    }
}

@MainActor
final class CoreLocationWeatherCoordinateProvider: NSObject,
    WeatherCoordinateProviding,
    CLLocationManagerDelegate,
    @unchecked Sendable
{
    private let manager: CLLocationManager
    private let timeout: Duration
    private var continuation: CheckedContinuation<WeatherCoordinate, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var didRequestAuthorization = false
    private var didRequestLocation = false

    override init() {
        manager = CLLocationManager()
        timeout = .seconds(20)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    init(manager: CLLocationManager, timeout: Duration) {
        self.manager = manager
        self.timeout = timeout
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func weatherLocationAuthorization() -> WeatherLocationAuthorization {
        guard CLLocationManager.locationServicesEnabled() else {
            return .servicesDisabled
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    func currentCoordinate() async throws -> WeatherCoordinate {
        guard continuation == nil else {
            throw OpenMeteoWeatherError.locationRequestInProgress
        }
        guard CLLocationManager.locationServicesEnabled() else {
            throw OpenMeteoWeatherError.locationServicesDisabled
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                didRequestAuthorization = false
                didRequestLocation = false
                timeoutTask = Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    do {
                        try await Task.sleep(for: timeout)
                    } catch {
                        return
                    }
                    finish(.failure(OpenMeteoWeatherError.locationTimedOut))
                }
                beginLocationRequest()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor [weak self] in
            guard let self, continuation != nil else {
                return
            }
            beginLocationRequest()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 }) else {
            return
        }
        let coordinate = WeatherCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            guard coordinate.isValid else {
                finish(
                    .failure(
                        OpenMeteoWeatherError.locationUnavailable("Invalid coordinates.")
                    )
                )
                return
            }
            finish(.success(coordinate))
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        let permissionDenied = (error as? CLError)?.code == .denied
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            if permissionDenied {
                finish(.failure(OpenMeteoWeatherError.locationPermissionDenied))
            } else {
                finish(
                    .failure(OpenMeteoWeatherError.locationUnavailable(message))
                )
            }
        }
    }

    private func beginLocationRequest() {
        switch manager.authorizationStatus {
        case .notDetermined:
            guard !didRequestAuthorization else {
                return
            }
            didRequestAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard !didRequestLocation else {
                return
            }
            didRequestLocation = true
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(OpenMeteoWeatherError.locationPermissionDenied))
        @unknown default:
            finish(.failure(OpenMeteoWeatherError.locationPermissionDenied))
        }
    }

    private func finish(_ result: Result<WeatherCoordinate, Error>) {
        guard let continuation else {
            return
        }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        didRequestAuthorization = false
        didRequestLocation = false
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }
}

protocol OpenMeteoHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionOpenMeteoHTTPClient: OpenMeteoHTTPClient, @unchecked Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

protocol WeatherSnapshotProviding: Sendable {
    func fetchWeather() async throws -> WeatherSnapshot
}

struct OpenMeteoWeatherProvider: WeatherSnapshotProviding,
    WeatherLocationAuthorizationProviding,
    Sendable
{
    static let openAccessEndpoint = URL(
        string: "https://api.open-meteo.com/v1/forecast"
    )!

    private let coordinateProvider: any WeatherCoordinateProviding
    private let locationNameProvider: any WeatherLocationNameProviding
    private let httpClient: any OpenMeteoHTTPClient
    private let endpoint: URL
    private let apiKey: String?
    private let locationNameTimeout: Duration
    private let now: @Sendable () -> Date

    @MainActor
    init() {
        self.init(
            coordinateProvider: CoreLocationWeatherCoordinateProvider(),
            locationNameProvider: CoreLocationWeatherLocationNameProvider(),
            httpClient: URLSessionOpenMeteoHTTPClient()
        )
    }

    init(
        coordinateProvider: any WeatherCoordinateProviding,
        locationNameProvider: any WeatherLocationNameProviding = UnresolvedWeatherLocationNameProvider(),
        httpClient: any OpenMeteoHTTPClient,
        endpoint: URL = Self.openAccessEndpoint,
        apiKey: String? = nil,
        locationNameTimeout: Duration = .seconds(3),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(
            locationNameTimeout > .zero,
            "Location-name timeout must be positive."
        )
        self.coordinateProvider = coordinateProvider
        self.locationNameProvider = locationNameProvider
        self.httpClient = httpClient
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.locationNameTimeout = locationNameTimeout
        self.now = now
    }

    func fetchWeather() async throws -> WeatherSnapshot {
        let coordinate = try await coordinateProvider.currentCoordinate()
        guard coordinate.isValid else {
            throw OpenMeteoWeatherError.invalidRequest
        }

        async let locationName = resolveLocationName(for: coordinate)
        let request = try makeRequest(for: coordinate)
        let (data, response) = try await httpClient.data(for: request)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenMeteoWeatherError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenMeteoAPIError.self, from: data)
            throw OpenMeteoWeatherError.httpFailure(
                statusCode: httpResponse.statusCode,
                reason: apiError?.reason
            )
        }

        let fetchedAt = now()
        let responsePayload: OpenMeteoForecastResponse
        do {
            responsePayload = try JSONDecoder().decode(
                OpenMeteoForecastResponse.self,
                from: data
            )
        } catch {
            throw OpenMeteoWeatherError.invalidPayload
        }
        let resolvedLocation = await locationName
        return try Self.makeSnapshot(
            from: responsePayload,
            fetchedAt: fetchedAt,
            location: resolvedLocation
        )
    }

    @MainActor
    func weatherLocationAuthorization() -> WeatherLocationAuthorization {
        coordinateProvider.weatherLocationAuthorization()
    }

    func makeRequest(for coordinate: WeatherCoordinate) throws -> URLRequest {
        guard coordinate.isValid,
              var components = URLComponents(
                  url: endpoint,
                  resolvingAgainstBaseURL: false
              )
        else {
            throw OpenMeteoWeatherError.invalidRequest
        }

        let locale = Locale(identifier: "en_US_POSIX")
        var queryItems = components.queryItems ?? []
        queryItems += [
            URLQueryItem(
                name: "latitude",
                value: String(format: "%.6f", locale: locale, coordinate.latitude)
            ),
            URLQueryItem(
                name: "longitude",
                value: String(format: "%.6f", locale: locale, coordinate.longitude)
            ),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
            ),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            ),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]
        if let apiKey, !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw OpenMeteoWeatherError.invalidRequest
        }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private func resolveLocationName(
        for coordinate: WeatherCoordinate
    ) async -> String? {
        enum Resolution: Sendable {
            case value(String?)
            case timedOut
        }

        let locationNameProvider = locationNameProvider
        let locationNameTimeout = locationNameTimeout
        return await withTaskGroup(of: Resolution.self) { group in
            group.addTask {
                .value(
                    await locationNameProvider.locationName(for: coordinate)
                )
            }
            group.addTask {
                do {
                    try await Task.sleep(for: locationNameTimeout)
                } catch {
                    return .timedOut
                }
                return .timedOut
            }

            guard let first = await group.next() else {
                return nil
            }
            group.cancelAll()
            return switch first {
            case let .value(value):
                value
            case .timedOut:
                nil
            }
        }
    }

    static func makeSnapshot(
        from response: OpenMeteoForecastResponse,
        fetchedAt: Date,
        location: String? = nil
    ) throws -> WeatherSnapshot {
        let temperature = response.current.temperature2M
        guard Self.isValidTemperature(temperature) else {
            throw OpenMeteoWeatherError.invalidPayload
        }

        let feelsLike = try validatedTemperature(response.current.apparentTemperature)
        let relativeHumidity = try validatedPercentage(
            response.current.relativeHumidity2M
        )
        let windSpeedKPH = try validatedNonnegative(response.current.windSpeed10M)
        let forecast = try dailyForecast(
            from: response.daily,
            timezone: response.timezone,
            utcOffsetSeconds: response.utcOffsetSeconds
        )
        guard let today = forecast.first else {
            throw OpenMeteoWeatherError.invalidPayload
        }

        let weather = OpenMeteoWeatherCode.metadata(for: response.current.weatherCode)
        let observedAt = observationDate(
            response.current.time,
            utcOffsetSeconds: response.utcOffsetSeconds
        ) ?? fetchedAt
        let displayLocation = normalizedLocationName(location)
            ?? locationName(fromTimeZoneIdentifier: response.timezone)
            ?? "Current Location"

        return WeatherSnapshot(
            location: displayLocation,
            temperatureCelsius: temperature,
            feelsLikeCelsius: feelsLike,
            conditionDescription: weather.description,
            condition: weather.condition,
            highCelsius: today.highCelsius,
            lowCelsius: today.lowCelsius,
            precipitationChance: today.precipitationChance,
            relativeHumidity: relativeHumidity,
            windSpeedKPH: windSpeedKPH,
            forecast: forecast,
            isDaylight: response.current.isDay.map { $0 == 1 },
            observedAt: observedAt,
            fetchedAt: fetchedAt
        )
    }

    private static func normalizedLocationName(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func locationName(
        fromTimeZoneIdentifier identifier: String?
    ) -> String? {
        guard let identifier = normalizedLocationName(identifier),
              let finalComponent = identifier.split(separator: "/").last
        else {
            return nil
        }

        let name = finalComponent.replacingOccurrences(of: "_", with: " ")
        guard name.caseInsensitiveCompare("GMT") != .orderedSame,
              !name.hasPrefix("GMT+") && !name.hasPrefix("GMT-")
        else {
            return nil
        }
        return name
    }

    private static func validatedTemperature(_ value: Double?) throws -> Double? {
        guard let value else {
            return nil
        }
        guard isValidTemperature(value) else {
            throw OpenMeteoWeatherError.invalidPayload
        }
        return value
    }

    private static func validatedPercentage(_ value: Double?) throws -> Double? {
        guard let value else {
            return nil
        }
        guard value.isFinite, (0 ... 100).contains(value) else {
            throw OpenMeteoWeatherError.invalidPayload
        }
        return value / 100
    }

    private static func validatedNonnegative(_ value: Double?) throws -> Double? {
        guard let value else {
            return nil
        }
        guard value.isFinite, (0 ... 500).contains(value) else {
            throw OpenMeteoWeatherError.invalidPayload
        }
        return value
    }

    private static func dailyForecast(
        from daily: OpenMeteoForecastResponse.Daily,
        timezone: String?,
        utcOffsetSeconds: Int
    ) throws -> [DailyWeatherForecast] {
        let count = daily.time.count
        guard count == 7,
              daily.weatherCode.count == count,
              daily.temperature2MMax.count == count,
              daily.temperature2MMin.count == count,
              daily.precipitationProbabilityMax.count == count
        else {
            throw OpenMeteoWeatherError.invalidPayload
        }

        let forecast = try (0 ..< count).map { index in
            guard let date = dailyDate(
                daily.time[index],
                timezone: timezone,
                utcOffsetSeconds: utcOffsetSeconds
            ), let weatherCode = daily.weatherCode[index]
            else {
                throw OpenMeteoWeatherError.invalidPayload
            }
            let weather = OpenMeteoWeatherCode.metadata(for: weatherCode)
            return DailyWeatherForecast(
                date: date,
                conditionDescription: weather.description,
                condition: weather.condition,
                highCelsius: try validatedTemperature(daily.temperature2MMax[index]),
                lowCelsius: try validatedTemperature(daily.temperature2MMin[index]),
                precipitationChance: try validatedPercentage(
                    daily.precipitationProbabilityMax[index]
                )
            )
        }
        guard Set(forecast.map(\.date)).count == count else {
            throw OpenMeteoWeatherError.invalidPayload
        }
        return forecast
    }

    private static func isValidTemperature(_ value: Double) -> Bool {
        value.isFinite && (-100 ... 100).contains(value)
    }

    private static func observationDate(
        _ value: String,
        utcOffsetSeconds: Int
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: utcOffsetSeconds)
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private static func dailyDate(
        _ value: String,
        timezone: String?,
        utcOffsetSeconds: Int
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone.flatMap(TimeZone.init(identifier:))
            ?? TimeZone(secondsFromGMT: utcOffsetSeconds)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

struct OpenMeteoForecastResponse: Decodable, Sendable {
    let utcOffsetSeconds: Int
    let timezone: String?
    let current: Current
    let daily: Daily

    struct Current: Decodable, Sendable {
        let time: String
        let temperature2M: Double
        let apparentTemperature: Double?
        let relativeHumidity2M: Double?
        let weatherCode: Int
        let isDay: Int?
        let windSpeed10M: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2M = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2M = "relative_humidity_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case windSpeed10M = "wind_speed_10m"
        }
    }

    struct Daily: Decodable, Sendable {
        let time: [String]
        let weatherCode: [Int?]
        let temperature2MMax: [Double?]
        let temperature2MMin: [Double?]
        let precipitationProbabilityMax: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2MMax = "temperature_2m_max"
            case temperature2MMin = "temperature_2m_min"
            case precipitationProbabilityMax = "precipitation_probability_max"
        }
    }

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case timezone
        case current
        case daily
    }
}

private struct OpenMeteoAPIError: Decodable {
    let reason: String?
}

enum OpenMeteoWeatherCode {
    static func metadata(
        for code: Int
    ) -> (description: String, condition: WeatherCondition) {
        switch code {
        case 0:
            ("Clear sky", .clear)
        case 1:
            ("Mainly clear", .mostlyClear)
        case 2:
            ("Partly cloudy", .partlyCloudy)
        case 3:
            ("Overcast", .cloudy)
        case 45, 48:
            ("Fog", .fog)
        case 51, 53, 55:
            ("Drizzle", .drizzle)
        case 56, 57:
            ("Freezing drizzle", .sleet)
        case 61, 63, 65:
            ("Rain", .rain)
        case 66, 67:
            ("Freezing rain", .sleet)
        case 71, 73, 75, 77:
            ("Snow", .snow)
        case 80, 81, 82:
            ("Rain showers", .rain)
        case 85, 86:
            ("Snow showers", .snow)
        case 95:
            ("Thunderstorm", .thunderstorm)
        case 96, 99:
            ("Thunderstorm with hail", .thunderstorm)
        default:
            ("Unknown conditions", .unknown)
        }
    }
}
