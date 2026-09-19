import Foundation

/// Internal research surface only. Neither a successful parse nor a fixture
/// enables the provider in a distributed build.
enum GrokBuildFeatureGate {
    static let productionEnabled = false
    static let runtimeVerifiedVersions: Set<String> = []
    /// Explicit auth command entry points only, not live account/billing proof.
    static let authenticationCommandVersions: Set<String> = ["1.0.30"]
    /// CLI 1.0.30 initialize deletes stale worktree_pool entries even with
    /// GROK_WORKTREE_AUTO_GC=0. Do not launch it in a user's home for polling.
    /// An experimental UI flag is not authority to bypass this safety gate.
    static let billingStartupSafetyVerified = false

    static var experimentalEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DOCKMAGIC_EXPERIMENTAL_GROK"] == "1"
        #else
        false
        #endif
    }
}

enum GrokBuildError: String, Error, LocalizedError, Sendable {
    case executableMissing, invalidHome, unsafeSource, invalidResponse
    case unsupportedSchema, authenticationRequired, unsupportedAuthentication
    case commandFailed, timedOut, outputTooLarge, protocolError, billingUnavailable
    case sourceChanged, cancelled
    case cacheUnavailable
    case billingStartupUnverified
    case signOutUnverified
    case authenticationVersionUnverified

    var errorDescription: String? {
        switch self {
        case .executableMissing: "Grok CLI was not found. Choose its executable or install Grok Build."
        case .invalidHome: "The selected Grok home is not a readable local directory."
        case .unsafeSource: "A local source could not be read safely and was excluded."
        case .invalidResponse: "Grok returned invalid usage data. Previous observations were preserved."
        case .unsupportedSchema: "This Grok response is not supported by the researched schema."
        case .authenticationRequired: "Sign in with Grok to read account credits. Local history remains available."
        case .unsupportedAuthentication: "Account credits require a supported Grok sign-in, not API-key authentication."
        case .commandFailed: "The Grok command failed. Try again or check the configured CLI."
        case .timedOut: "Grok did not respond before the timeout."
        case .outputTooLarge: "Grok output exceeded the safety limit and was not collected."
        case .protocolError: "Grok's ACP response was not understood."
        case .billingUnavailable: "Grok account credits are unavailable for this response."
        case .sourceChanged: "A usage source changed during collection. Retry to read a consistent snapshot."
        case .cancelled: "Grok collection was cancelled."
        case .cacheUnavailable: "Grok history could not be saved or restored. Local source files were not changed."
        case .billingStartupUnverified: "Account credits are disabled: this Grok startup can remove stale worktree data. Local history remains available."
        case .signOutUnverified: "The Grok logout command completed, but account status could not be verified. Local history was kept."
        case .authenticationVersionUnverified: "Authentication commands are not verified for this Grok CLI version. Refresh the configured installation."
        }
    }
}

struct GrokBuildTokenCounts: Codable, Equatable, Sendable {
    let input: Int64
    let output: Int64
    let total: Int64
    /// Zero breakdowns from the CLI cannot distinguish original missingness.
    let cacheRead: Int64?
    let cacheWrite: Int64?
    let reasoning: Int64?

    func covers(_ old: Self) -> Bool {
        input >= old.input && output >= old.output && total >= old.total
    }
}

struct GrokBuildRecordedTurn: Codable, Equatable, Sendable {
    let number: UInt32
    let recordedAt: Date
    let tokens: GrokBuildTokenCounts
    let models: [String: GrokBuildTokenCounts]
    let upstreamIncomplete: Bool
}

struct GrokBuildSessionUsage: Equatable, Sendable {
    let id: UUID
    let sourceUpdatedAt: Date
    let total: GrokBuildTokenCounts
    let turns: [GrokBuildRecordedTurn]
}

struct GrokBuildLineage: Decodable, Equatable, Sendable {
    struct Info: Decodable, Equatable, Sendable { let id: UUID }
    let info: Info
    let parentSessionID: String?
    let forkedAt: String?
    let sessionKind: String?
    let forkContextSource: String?

    enum CodingKeys: String, CodingKey {
        case info
        case parentSessionID = "parent_session_id"
        case forkedAt = "forked_at"
        case sessionKind = "session_kind"
        case forkContextSource = "fork_context_source"
    }

    /// V1 intentionally does not merge inherited prefixes or child ledgers.
    var isUnambiguousRoot: Bool {
        parentSessionID == nil && forkedAt == nil && sessionKind == nil
            && (forkContextSource == nil || forkContextSource == "new")
    }
}

struct GrokBuildQuotaSnapshot: Codable, Equatable, Sendable {
    enum Scope: String, Codable, Sendable { case sharedConsumer, unspecified }
    let usedPercent: Double
    let periodType: String?
    let startsAt: Date?
    let resetsAt: Date?
    let scope: Scope
    let subscriptionTier: String?
    let observedAt: Date

    var remainingFraction: Double { 1 - usedPercent / 100 }
}

struct GrokBuildDailyObservation: Equatable, Identifiable, Sendable {
    let startDate: Date
    /// nil means unknown; an absent session/day is never measured zero.
    let tokens: Int64?
    let modelTokens: [String: Int64]
    let modelCoverageIsPartial: Bool
    var id: Date { startDate }
}

struct GrokBuildHistoryCoverage: Codable, Equatable, Sendable {
    var excludedSessions = 0
    var quarantinedSessions = 0
    var unavailableSources = 0
    var scanWasLimited = false
    /// Side calls, other devices, background folds and historical defaults are
    /// not certified by usageIsIncomplete == false.
    var isPartial: Bool { true }
}

struct GrokBuildHistorySnapshot: Equatable, Sendable {
    let days: [GrokBuildDailyObservation]
    let coverage: GrokBuildHistoryCoverage
    let observedAt: Date
    let sourceUpdatedAt: Date?

    var topModels: [(model: String, tokens: Int64)] {
        var totals: [String: Int64] = [:]
        for day in days {
            for (model, tokens) in day.modelTokens {
                totals[model] = GrokBuildNumbers.add(totals[model] ?? 0, tokens)
            }
        }
        var ranked: [(model: String, tokens: Int64)] = []
        for (model, tokens) in totals { ranked.append((model: model, tokens: tokens)) }
        ranked.sort { lhs, rhs in
            if lhs.tokens == rhs.tokens { return lhs.model < rhs.model }
            return lhs.tokens > rhs.tokens
        }
        return Array(ranked.prefix(3))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.days == rhs.days && lhs.coverage == rhs.coverage
            && lhs.observedAt == rhs.observedAt && lhs.sourceUpdatedAt == rhs.sourceUpdatedAt
    }
}

enum GrokBuildNumbers {
    static func add(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let sum = lhs.addingReportingOverflow(rhs)
        return sum.overflow ? Int64.max : sum.partialValue
    }
}

enum GrokBuildDates {
    static func parse(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
