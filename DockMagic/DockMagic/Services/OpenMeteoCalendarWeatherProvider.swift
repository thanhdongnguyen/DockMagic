import Foundation

enum CalendarWeatherRequestScope: Equatable, Sendable {
    case today
    case future
}

@MainActor
protocol CalendarWeatherProviding {
    func authorization() -> WeatherLocationAuthorization
    func fetch(_ scope: CalendarWeatherRequestScope, now: Date, timeZone: TimeZone) async throws -> CalendarWeatherResult
}

@MainActor
final class OpenMeteoCalendarWeatherProvider: CalendarWeatherProviding {
    private let coordinateProvider: any WeatherCoordinateProviding
    private let locationNameProvider: any WeatherLocationNameProviding
    private let httpClient: any OpenMeteoHTTPClient
    private let endpoint: URL
    private let apiKey: String?

    init(
        coordinateProvider: (any WeatherCoordinateProviding)? = nil,
        locationNameProvider: (any WeatherLocationNameProviding)? = nil,
        httpClient: any OpenMeteoHTTPClient = URLSessionOpenMeteoHTTPClient(),
        endpoint: URL = OpenMeteoWeatherProvider.openAccessEndpoint,
        apiKey: String? = nil
    ) {
        self.coordinateProvider = coordinateProvider ?? CoreLocationWeatherCoordinateProvider()
        self.locationNameProvider = locationNameProvider ?? CoreLocationWeatherLocationNameProvider()
        self.httpClient = httpClient
        self.endpoint = endpoint
        self.apiKey = apiKey
    }

    func authorization() -> WeatherLocationAuthorization {
        coordinateProvider.weatherLocationAuthorization()
    }

    func fetch(_ scope: CalendarWeatherRequestScope, now: Date, timeZone: TimeZone) async throws -> CalendarWeatherResult {
        let coordinate = try await coordinateProvider.currentCoordinate()
        guard coordinate.isValid else { throw OpenMeteoWeatherError.invalidRequest }
        let request = try makeRequest(scope, coordinate: coordinate, now: now, timeZone: timeZone)
        async let locationName = locationNameProvider.locationName(for: coordinate)
        let (data, response) = try await httpClient.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw OpenMeteoWeatherError.invalidResponse }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw OpenMeteoWeatherError.httpFailure(statusCode: response.statusCode, reason: nil)
        }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) }
        catch { throw OpenMeteoWeatherError.invalidPayload }
        guard payload.daily.time.count == (scope == .today ? 1 : 6),
              payload.daily.weatherCode.count == payload.daily.time.count,
              payload.daily.high.count == payload.daily.time.count,
              payload.daily.low.count == payload.daily.time.count,
              payload.daily.precipitationChance.count == payload.daily.time.count,
              payload.hourly.time.count == payload.hourly.temperature.count,
              payload.hourly.time.count == payload.hourly.weatherCode.count,
              payload.hourly.time.count == payload.hourly.precipitationChance.count
        else { throw OpenMeteoWeatherError.invalidPayload }

        guard TimeZone(identifier: payload.timezone) != nil else { throw OpenMeteoWeatherError.invalidPayload }
        var hoursByDay: [String: [CalendarWeatherHour]] = [:]
        for index in payload.hourly.time.indices {
            let date = Date(timeIntervalSince1970: TimeInterval(payload.hourly.time[index]))
            let code = payload.hourly.weatherCode[index]
            let metadata = code.map(OpenMeteoWeatherCode.metadata(for:))
            let hour = CalendarWeatherHour(
                date: date,
                condition: metadata?.condition ?? .unknown,
                conditionDescription: metadata?.description ?? "Unknown conditions",
                temperatureCelsius: try Self.temperature(payload.hourly.temperature[index]),
                precipitationChance: try Self.percentage(payload.hourly.precipitationChance[index])
            )
            hoursByDay[CalendarWeatherDates.dayID(for: date, timeZone: timeZone), default: []].append(hour)
        }
        let requestedIDs = (scope == .today ? [0] : Array(1 ... 6))
            .map { CalendarWeatherDates.offsetDayID(from: now, by: $0, timeZone: timeZone) }
        let days = try payload.daily.time.indices.map { index -> CalendarWeatherDay in
            // Open-Meteo documents daily unixtime values as GMT+0 and requires an
            // offset to recover the date. The requested local-date range is the
            // authoritative key; hourly epochs remain real instants (including DST).
            let dayID = requestedIDs[index]
            guard let code = payload.daily.weatherCode[index] else {
                throw OpenMeteoWeatherError.invalidPayload
            }
            let metadata = OpenMeteoWeatherCode.metadata(for: code)
            return CalendarWeatherDay(
                dayID: dayID,
                condition: metadata.condition,
                conditionDescription: metadata.description,
                highCelsius: try Self.temperature(payload.daily.high[index]),
                lowCelsius: try Self.temperature(payload.daily.low[index]),
                precipitationChance: try Self.percentage(payload.daily.precipitationChance[index]),
                hours: (hoursByDay[dayID] ?? []).sorted { $0.date < $1.date }
            )
        }
        let current: CalendarCurrentWeather?
        if scope == .today, let value = payload.current {
            guard value.temperature.isFinite, (-100 ... 100).contains(value.temperature) else {
                throw OpenMeteoWeatherError.invalidPayload
            }
            let metadata = OpenMeteoWeatherCode.metadata(for: value.weatherCode)
            current = CalendarCurrentWeather(
                condition: metadata.condition,
                conditionDescription: metadata.description,
                isDaylight: value.isDay.map { $0 == 1 },
                temperatureCelsius: value.temperature,
                observedAt: Date(timeIntervalSince1970: TimeInterval(value.time))
            )
        } else {
            current = nil
        }
        let location = await locationName
        return CalendarWeatherResult(
            coordinate: coordinate,
            location: location?.isEmpty == false ? location! : "Current Location",
            timeZoneID: timeZone.identifier,
            current: current,
            days: days
        )
    }

    func makeRequest(_ scope: CalendarWeatherRequestScope, coordinate: WeatherCoordinate, now: Date, timeZone: TimeZone) throws -> URLRequest {
        guard coordinate.isValid, var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw OpenMeteoWeatherError.invalidRequest
        }
        let locale = Locale(identifier: "en_US_POSIX")
        var items = components.queryItems ?? []
        items += [
            URLQueryItem(name: "latitude", value: String(format: "%.6f", locale: locale, coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.6f", locale: locale, coordinate.longitude)),
            URLQueryItem(name: "timezone", value: timeZone.identifier),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max")
        ]
        switch scope {
        case .today:
            items += [
                URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
                URLQueryItem(name: "forecast_days", value: "1")
            ]
        case .future:
            items += [
                URLQueryItem(name: "start_date", value: CalendarWeatherDates.offsetDayID(from: now, by: 1, timeZone: timeZone)),
                URLQueryItem(name: "end_date", value: CalendarWeatherDates.offsetDayID(from: now, by: 6, timeZone: timeZone))
            ]
        }
        if let apiKey, !apiKey.isEmpty { items.append(URLQueryItem(name: "apikey", value: apiKey)) }
        components.queryItems = items
        guard let url = components.url else { throw OpenMeteoWeatherError.invalidRequest }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private static func temperature(_ value: Double?) throws -> Double? {
        guard let value else { return nil }
        guard value.isFinite, (-100 ... 100).contains(value) else { throw OpenMeteoWeatherError.invalidPayload }
        return value
    }

    private static func percentage(_ value: Double?) throws -> Double? {
        guard let value else { return nil }
        guard value.isFinite, (0 ... 100).contains(value) else { throw OpenMeteoWeatherError.invalidPayload }
        return value / 100
    }

    private struct Payload: Decodable {
        let timezone: String
        let current: Current?
        let daily: Daily
        let hourly: Hourly

        struct Current: Decodable {
            let time: Int
            let temperature: Double
            let weatherCode: Int
            let isDay: Int?
            enum CodingKeys: String, CodingKey {
                case time, weatherCode = "weather_code", isDay = "is_day"
                case temperature = "temperature_2m"
            }
        }
        struct Daily: Decodable {
            let time: [Int]
            let weatherCode: [Int?]
            let high: [Double?]
            let low: [Double?]
            let precipitationChance: [Double?]
            enum CodingKeys: String, CodingKey {
                case time, weatherCode = "weather_code"
                case high = "temperature_2m_max", low = "temperature_2m_min"
                case precipitationChance = "precipitation_probability_max"
            }
        }
        struct Hourly: Decodable {
            let time: [Int]
            let temperature: [Double?]
            let weatherCode: [Int?]
            let precipitationChance: [Double?]
            enum CodingKeys: String, CodingKey {
                case time, temperature = "temperature_2m", weatherCode = "weather_code"
                case precipitationChance = "precipitation_probability"
            }
        }
    }
}
