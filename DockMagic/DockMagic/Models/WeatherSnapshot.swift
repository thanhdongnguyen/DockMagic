import Foundation

enum WeatherCondition: String, Codable, CaseIterable, Sendable {
    case clear
    case mostlyClear
    case partlyCloudy
    case cloudy
    case fog
    case wind
    case drizzle
    case rain
    case sleet
    case snow
    case thunderstorm
    case hot
    case cold
    case unknown

    static func resolve(code: String?, description: String) -> Self {
        if let code {
            let normalizedCode = normalize(code)
            if let exact = Self.allCases.first(where: {
                normalize($0.rawValue) == normalizedCode
            }) {
                return exact
            }
        }

        let value = normalize(description)
        let rules: [([String], Self)] = [
            (["thunder", "storm", "lightning", "giong", "samset", "bao"], .thunderstorm),
            (["sleet", "freezingrain", "wintrymix", "icepellet", "muatuyet"], .sleet),
            (["snow", "flurr", "blizzard", "tuyet"], .snow),
            (["drizzle", "sprinkle", "muaphun"], .drizzle),
            (["rain", "shower", "downpour", "mua"], .rain),
            (["fog", "mist", "haze", "smoke", "suongmu"], .fog),
            (["wind", "breez", "gale", "gio"], .wind),
            (["partlycloud", "scatteredcloud", "maytungphan", "mayrairac"], .partlyCloudy),
            (["mostlyclear", "fewcloud", "itmay"], .mostlyClear),
            (["cloud", "overcast", "nhieumay", "uam"], .cloudy),
            (["clear", "sunny", "fair", "quangdang", "troinang", "nang"], .clear),
            (["hot"], .hot),
            (["cold", "frigid"], .cold)
        ]

        return rules.first(where: { keywords, _ in
            keywords.contains(where: value.contains)
        })?.1 ?? .unknown
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .filter(\.isLetter)
    }

    func symbolName(isDaylight: Bool? = true) -> String {
        let daylight = isDaylight != false
        return switch self {
        case .clear, .hot:
            daylight ? "sun.max.fill" : "moon.stars.fill"
        case .mostlyClear:
            daylight ? "sun.horizon.fill" : "moon.stars.fill"
        case .partlyCloudy:
            daylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy, .unknown:
            "cloud.fill"
        case .fog:
            "cloud.fog.fill"
        case .wind:
            "wind"
        case .drizzle:
            "cloud.drizzle.fill"
        case .rain:
            "cloud.rain.fill"
        case .sleet:
            "cloud.sleet.fill"
        case .snow, .cold:
            "cloud.snow.fill"
        case .thunderstorm:
            "cloud.bolt.rain.fill"
        }
    }
}

struct DailyWeatherForecast: Codable, Equatable, Sendable, Identifiable {
    let date: Date
    let conditionDescription: String
    let condition: WeatherCondition
    let highCelsius: Double?
    let lowCelsius: Double?
    let precipitationChance: Double?

    var id: Date { date }
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    let location: String
    let temperatureCelsius: Double
    let feelsLikeCelsius: Double?
    let conditionDescription: String
    let condition: WeatherCondition
    let highCelsius: Double?
    let lowCelsius: Double?
    let precipitationChance: Double?
    let relativeHumidity: Double?
    let windSpeedKPH: Double?
    let forecast: [DailyWeatherForecast]
    let isDaylight: Bool?
    let observedAt: Date
    let fetchedAt: Date
}

enum WeatherState: Equatable, Sendable {
    case idle
    case loading
    case live(WeatherSnapshot)
    case stale(WeatherSnapshot, message: String)
    case unavailable(message: String)

    var snapshot: WeatherSnapshot? {
        switch self {
        case .idle, .loading, .unavailable:
            nil
        case let .live(snapshot), let .stale(snapshot, _):
            snapshot
        }
    }
}
