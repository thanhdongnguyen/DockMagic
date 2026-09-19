import Foundation

/// Recorded usage, not account quota or a billing statement. Unknown buckets stay nil.
struct OpenCodeTokens: Codable, Equatable, Sendable {
    var input: Int64?
    var output: Int64?
    var reasoning: Int64?
    var cacheRead: Int64?
    var cacheWrite: Int64?

    static let zero = Self(input: 0, output: 0, reasoning: 0, cacheRead: 0, cacheWrite: 0)
    var values: [Int64?] { [input, output, reasoning, cacheRead, cacheWrite] }
    var total: Int64? {
        let known = values.compactMap { $0 }
        return known.isEmpty ? nil : known.reduce(0, Self.sum)
    }
    var isPartial: Bool { values.contains(nil) }
    static func sum(_ a: Int64, _ b: Int64) -> Int64 {
        let result = a.addingReportingOverflow(b)
        return result.overflow ? Int64.max : result.partialValue
    }
    func adding(_ other: Self) -> Self {
        func add(_ a: Int64?, _ b: Int64?) -> Int64? {
            guard a != nil || b != nil else { return nil }
            return Self.sum(a ?? 0, b ?? 0)
        }
        return Self(input: add(input, other.input), output: add(output, other.output),
                    reasoning: add(reasoning, other.reasoning), cacheRead: add(cacheRead, other.cacheRead),
                    cacheWrite: add(cacheWrite, other.cacheWrite))
    }
}

struct OpenCodeCost: Codable, Equatable, Sendable {
    var recordedUSD: Double = 0
    var eligibleMessages = 0
    var usageMessages = 0
    var value: Double? { eligibleMessages > 0 ? recordedUSD : nil }
    var isPartial: Bool { eligibleMessages < usageMessages }
    static let provenance = "Estimated cost recorded by legacy OpenCode; not billed spend. V2 and unknown zero costs are unavailable."
}

struct OpenCodeModelUsage: Codable, Equatable, Identifiable, Sendable {
    let provider: String
    let model: String
    var tokens: OpenCodeTokens
    var isPartial: Bool
    var id: String { "\(provider)/\(model)" }
}

struct OpenCodeHourlyUsage: Codable, Equatable, Identifiable, Sendable {
    let startDate: Date
    var tokens: OpenCodeTokens
    var isPartial: Bool
    var id: Date { startDate }
}

struct OpenCodeDailyDetail: Codable, Equatable, Identifiable, Sendable {
    let startDate: Date
    var tokens: OpenCodeTokens
    var cost: OpenCodeCost
    var hourly: [OpenCodeHourlyUsage]
    var models: [OpenCodeModelUsage]
    var sessionCount: Int
    var messageCount: Int
    var isPartial: Bool
    var id: Date { startDate }
}

struct OpenCodeUsageSnapshot: Codable, Equatable, Sendable {
    let sourceID: String
    let timezoneID: String
    let readAt: Date
    let schema: String
    let days: [OpenCodeDailyDetail]
    let recordKeys: [String]
    let skippedRecords: Int
    let lifetimeTokens: Int64?
    let cost: OpenCodeCost

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneID) ?? .current
        return calendar
    }
    var isPartial: Bool { skippedRecords > 0 || days.contains { $0.isPartial } }
    func day(_ date: Date) -> OpenCodeDailyDetail? {
        let start = calendar.startOfDay(for: date)
        return days.first { $0.startDate == start }
    }
    func trailingDays(_ count: Int, now: Date = .now) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }
    static let coverageNote = "Retained local history across all projects, providers and models in one database. Forked or imported copies with new IDs may be counted separately."
}

enum OpenCodeObservation: String, Codable, Sendable {
    case notConfigured, loading, current, stale, unavailable, failed, unsupportedSchema, needsSelection
}

struct OpenCodeUsageState: Equatable, Sendable {
    var snapshot: OpenCodeUsageSnapshot?
    var observation: OpenCodeObservation = .notConfigured
    var message: String?
    var isRefreshing = false
    var isStale: Bool { snapshot != nil && observation != .current }
    var label: String {
        switch observation {
        case .notConfigured: "Choose a local database"
        case .loading: "Reading local history…"
        case .current: snapshot?.isPartial == true ? "Local history · partial" : "Local history"
        case .stale: "Last known local history"
        case .unavailable: "Database unavailable"
        case .failed: "Could not read local history"
        case .unsupportedSchema: "Unsupported database schema"
        case .needsSelection: "Choose one database"
        }
    }
}

/// The manifest is deliberately scoped to OpenCode; no provider parity is implied.
enum OpenCodeDashboardManifest {
    enum Module: String, CaseIterable {
        case identity, dailyUsage, lifetime, streak, badges, shipMomentum, dailyIntensity, topModels, dailyDetail, activityExport
    }
    enum Capability: String { case supported, unsupported, unknown, prohibited }
    struct Entry {
        let module: Module
        let capability: Capability
        let source: String
    }
    static let selectedModules: [Module] = [.identity, .dailyUsage, .lifetime, .streak, .badges, .shipMomentum, .dailyIntensity, .topModels, .dailyDetail, .activityExport]
    static let entries = selectedModules.map {
        Entry(module: $0, capability: .supported, source: "Read-only message / session_message metadata; observed local history")
    }
    static func supports(_ module: Module) -> Bool { entries.contains { $0.module == module && $0.capability == .supported } }
    static let excluded: [String: Capability] = [
        "quota": .unknown, "reset": .unknown, "balance": .unknown, "plan": .unknown,
        "upstreamStatus": .unknown, "activeSessions": .unsupported, "credentials": .prohibited,
        "transcripts": .prohibited
    ]
}
