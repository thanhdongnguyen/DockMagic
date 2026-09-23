import Foundation

struct CalendarWeatherHour: Codable, Equatable, Sendable, Identifiable {
    let date: Date
    let condition: WeatherCondition
    let conditionDescription: String
    let temperatureCelsius: Double?
    let precipitationChance: Double?

    var id: Date { date }
}

struct CalendarWeatherDay: Codable, Equatable, Sendable, Identifiable {
    /// Gregorian date in the Calendar dashboard's time zone.
    let dayID: String
    let condition: WeatherCondition
    let conditionDescription: String
    let highCelsius: Double?
    let lowCelsius: Double?
    let precipitationChance: Double?
    let hours: [CalendarWeatherHour]

    var id: String { dayID }
}

struct CalendarCurrentWeather: Codable, Equatable, Sendable {
    let condition: WeatherCondition
    let conditionDescription: String
    let isDaylight: Bool?
    let temperatureCelsius: Double
    let observedAt: Date
}

struct CalendarWeatherResult: Sendable {
    let coordinate: WeatherCoordinate
    let location: String
    let timeZoneID: String
    let current: CalendarCurrentWeather?
    let days: [CalendarWeatherDay]
}

struct CalendarWeatherCache: Codable, Equatable, Sendable {
    var location: String
    var timeZoneID: String
    var latitude: Double?
    var longitude: Double?
    var current: CalendarCurrentWeather?
    var today: CalendarWeatherDay?
    var future: [CalendarWeatherDay]
    var todayFetchedAt: Date?
    var futureFetchedAt: Date?
}

enum CalendarWeatherDates {
    static func dayID(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func offsetDayID(from date: Date, by days: Int, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let target = calendar.date(byAdding: .day, value: days, to: date) ?? date
        return dayID(for: target, timeZone: timeZone)
    }
}

enum CalendarWeatherIcon {
    static func assetName(for condition: WeatherCondition, isDaylight: Bool? = true) -> String {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return isDaylight == false ? "CalendarWeatherMoon" : "CalendarWeatherSun"
        case .partlyCloudy:
            return isDaylight == false ? "CalendarWeatherMoon" : "CalendarWeatherPartlyCloudy"
        case .cloudy, .fog, .unknown:
            return "CalendarWeatherCloud"
        case .wind:
            return "CalendarWeatherWind"
        case .drizzle, .rain:
            return "CalendarWeatherRain"
        case .sleet, .snow, .cold:
            return "CalendarWeatherIce"
        case .thunderstorm:
            return "CalendarWeatherStorm"
        }
    }
}
