import Foundation

enum AugmentUTC {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func string(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func date(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, value.count == 10,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              string(date) == value else { return nil }
        return date
    }
}

struct AugmentDateRange: Codable, Equatable, Hashable, Sendable {
    let start: Date
    let end: Date

    static func reported(days: Int, now: Date) -> Self {
        let end = AugmentUTC.calendar.date(byAdding: .day, value: -1, to: AugmentUTC.calendar.startOfDay(for: now))!
        return Self(start: AugmentUTC.calendar.date(byAdding: .day, value: -(days - 1), to: end)!, end: end)
    }

    var dates: [Date] {
        guard start <= end else { return [] }
        let count = AugmentUTC.calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard count < 90 else { return [] }
        return (0...count).compactMap { AugmentUTC.calendar.date(byAdding: .day, value: $0, to: start) }
    }
    var label: String { "\(AugmentUTC.string(start)) – \(AugmentUTC.string(end)) UTC" }
}

enum AugmentMetric: String, CaseIterable, Codable, Identifiable, Sendable {
    case input, output, cacheRead, cacheWrite, billedUSD
    var id: Self { self }
    var title: String {
        switch self {
        case .input: "Input"
        case .output: "Output"
        case .cacheRead: "Cache read"
        case .cacheWrite: "Cache write"
        case .billedUSD: "Billed USD"
        }
    }
    var unit: String { self == .billedUSD ? "USD" : "tokens" }
}

struct AugmentMetrics: Codable, Equatable, Sendable {
    var input: Int64?
    var output: Int64?
    var cacheRead: Int64?
    var cacheWrite: Int64?
    var billedUSD: Decimal?
    var estimatedUSD: Decimal?

    func value(_ metric: AugmentMetric) -> Decimal? {
        switch metric {
        case .input: input.map(Decimal.init)
        case .output: output.map(Decimal.init)
        case .cacheRead: cacheRead.map(Decimal.init)
        case .cacheWrite: cacheWrite.map(Decimal.init)
        case .billedUSD: billedUSD
        }
    }
    var isPartial: Bool { AugmentMetric.allCases.contains { value($0) == nil } }
}

struct AugmentDailyBucket: Codable, Equatable, Identifiable, Sendable {
    let date: Date
    let metrics: AugmentMetrics
    var id: Date { date }
}

struct AugmentResourceUsage: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let type: String
    let metrics: AugmentMetrics
    var id: String { type + "|" + name }
    var isModel: Bool { type == "COST_ANALYTICS_RESOURCE_TYPE_MODEL" }
}

struct AugmentUsageSnapshot: Codable, Equatable, Sendable {
    let range: AugmentDateRange
    let days: [AugmentDailyBucket]
    let fetchedAt: Date
    let generatedAt: Date?
    var latest: AugmentDailyBucket? { days.max { $0.date < $1.date } }
    var isPartial: Bool { days.count != range.dates.count || days.contains { $0.metrics.isPartial } }
    func day(_ date: Date) -> AugmentDailyBucket? { days.first { $0.date == date } }
}

struct AugmentResourceSnapshot: Equatable, Sendable {
    let range: AugmentDateRange
    let resources: [AugmentResourceUsage]
    let fetchedAt: Date
    func models(by metric: AugmentMetric) -> [AugmentResourceUsage] {
        resources.filter { $0.isModel }.sorted {
            let lhs = $0.metrics.value(metric), rhs = $1.metrics.value(metric)
            if lhs == rhs { return $0.name < $1.name }
            guard let lhs else { return false }
            guard let rhs else { return true }
            return lhs > rhs
        }
    }
}

enum AugmentObservation: String, Sendable {
    case notConfigured, loading, live, stale, unavailable, failed
}

struct AugmentUsageState: Equatable, Sendable {
    var snapshot: AugmentUsageSnapshot?
    var observation: AugmentObservation = .notConfigured
    var message: String?
    var isRefreshing = false
    var label: String {
        switch observation {
        case .notConfigured: "Connect Augment in Settings"
        case .loading: "Loading organization usage…"
        case .live: snapshot?.isPartial == true ? "Latest reported · incomplete coverage" : "Latest reported"
        case .stale: "Last known usage"
        case .unavailable: "No reported data"
        case .failed: "Could not read usage"
        }
    }
}

enum AugmentDashboardManifest {
    enum Module: String, CaseIterable {
        case identity, statusLink, dailyUsage, continuity, dailyIntensity, dailyDetail, models
    }
    static let selectedModules = Module.allCases
    static let excluded = ["totalTokens", "realtime", "quota", "credits", "lifetime", "personalStreak", "badges", "shipMomentum", "export"]
}

enum AugmentFormatting {
    static func value(_ value: Decimal?, metric: AugmentMetric, compact: Bool = false) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = .current
        if metric == .billedUSD {
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = compact ? 2 : 4
            formatter.minimumFractionDigits = 2
        } else {
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
        }
        if compact, metric != .billedUSD {
            for (divisor, suffix) in [(1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")] where value >= Decimal(divisor) {
                formatter.maximumFractionDigits = 1
                return (formatter.string(from: NSDecimalNumber(decimal: value / Decimal(divisor))) ?? "—") + suffix
            }
        }
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }
}
