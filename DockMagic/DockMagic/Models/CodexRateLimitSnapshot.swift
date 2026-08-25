import Foundation

enum CodexRateLimitWindowKind: String, Codable, Sendable {
    case fiveHour
    case weekly
}

struct CodexRateLimitWindow: Codable, Equatable, Sendable {
    let kind: CodexRateLimitWindowKind
    let usedPercent: Int
    let windowDurationMinutes: Int
    let resetsAt: Date?

    var remainingFraction: Double {
        1 - Double(min(max(usedPercent, 0), 100)) / 100
    }
}

struct CodexTokenUsageDailyBucket: Codable, Equatable, Identifiable, Sendable {
    let startDate: Date
    let tokens: Int64

    var id: Date { startDate }
}

struct CodexAccountTokenUsage: Codable, Equatable, Sendable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let currentStreakDays: Int64?
    let longestStreakDays: Int64?
    let longestRunningTurnSeconds: Int64?
    let dailyUsageBuckets: [CodexTokenUsageDailyBucket]

    var latestDailyTokens: Int64? {
        dailyUsageBuckets.last?.tokens
    }
}

struct CodexRecentTaskActivity: Codable, Equatable, Sendable {
    let currentWeekCount: Int
    let previousWeekCount: Int
    let isPartial: Bool
}

struct CodexRateLimitSnapshot: Codable, Equatable, Sendable {
    let planType: String?
    let limitID: String?
    let fiveHour: CodexRateLimitWindow?
    let weekly: CodexRateLimitWindow?
    let tokenUsage: CodexAccountTokenUsage?
    let recentTaskActivity: CodexRecentTaskActivity?
    let fetchedAt: Date

    init(
        planType: String?,
        limitID: String?,
        fiveHour: CodexRateLimitWindow?,
        weekly: CodexRateLimitWindow?,
        tokenUsage: CodexAccountTokenUsage? = nil,
        recentTaskActivity: CodexRecentTaskActivity? = nil,
        fetchedAt: Date
    ) {
        self.planType = planType
        self.limitID = limitID
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.tokenUsage = tokenUsage
        self.recentTaskActivity = recentTaskActivity
        self.fetchedAt = fetchedAt
    }

    var hasSupportedWindow: Bool {
        fiveHour != nil || weekly != nil
    }
}

enum CodexUsageState: Equatable, Sendable {
    case idle
    case loading
    case live(CodexRateLimitSnapshot)
    case stale(CodexRateLimitSnapshot, message: String)
    case unavailable(message: String)

    var snapshot: CodexRateLimitSnapshot? {
        switch self {
        case let .live(snapshot), let .stale(snapshot, _):
            snapshot
        case .idle, .loading, .unavailable:
            nil
        }
    }

    var statusTitle: String {
        switch self {
        case .idle:
            "Not connected"
        case .loading:
            "Loading"
        case .live:
            "Live"
        case .stale:
            "Last known"
        case .unavailable:
            "Unavailable"
        }
    }
}

// Claude Code and Codex expose the same two product-level windows even though
// they arrive through different supported local integrations. Keep distinct
// names at each feature boundary while sharing the small normalized model.
typealias ClaudeCodeRateLimitWindowKind = CodexRateLimitWindowKind
typealias ClaudeCodeRateLimitWindow = CodexRateLimitWindow
typealias ClaudeCodeRateLimitSnapshot = CodexRateLimitSnapshot
typealias ClaudeCodeUsageState = CodexUsageState
