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

struct CodexModelTokenUsage: Codable, Equatable, Identifiable, Sendable {
    let model: String
    let tokens: Int64

    var id: String { model }
}

struct CodexTokenBreakdown: Codable, Equatable, Sendable {
    let inputTokens: Int64
    let cachedInputTokens: Int64
    let cacheWriteInputTokens: Int64
    let outputTokens: Int64
    let reasoningOutputTokens: Int64
    let totalTokens: Int64

    static let zero = CodexTokenBreakdown(
        inputTokens: 0,
        cachedInputTokens: 0,
        cacheWriteInputTokens: 0,
        outputTokens: 0,
        reasoningOutputTokens: 0,
        totalTokens: 0
    )

    var cachedInputFraction: Double? {
        guard inputTokens > 0 else { return nil }
        return min(
            1,
            max(0, Double(cachedInputTokens) / Double(inputTokens))
        )
    }

    func adding(_ other: CodexTokenBreakdown) -> CodexTokenBreakdown {
        CodexTokenBreakdown(
            inputTokens: inputTokens + other.inputTokens,
            cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
            cacheWriteInputTokens:
                cacheWriteInputTokens + other.cacheWriteInputTokens,
            outputTokens: outputTokens + other.outputTokens,
            reasoningOutputTokens:
                reasoningOutputTokens + other.reasoningOutputTokens,
            totalTokens: totalTokens + other.totalTokens
        )
    }
}

struct CodexHourlyTokenUsageBucket: Codable, Equatable, Identifiable, Sendable {
    let startDate: Date
    let usage: CodexTokenBreakdown

    var id: Date { startDate }
}

struct CodexDailyModelTokenUsage: Codable, Equatable, Identifiable, Sendable {
    let model: String
    let usage: CodexTokenBreakdown

    var id: String { model }
}

struct CodexDailyTokenDetail: Codable, Equatable, Identifiable, Sendable {
    let startDate: Date
    let usage: CodexTokenBreakdown
    let hourlyUsage: [CodexHourlyTokenUsageBucket]
    let modelUsage: [CodexDailyModelTokenUsage]
    let isPartial: Bool

    var id: Date { startDate }
}

struct CodexAccountTokenUsage: Codable, Equatable, Sendable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let currentStreakDays: Int64?
    let longestStreakDays: Int64?
    let longestRunningTurnSeconds: Int64?
    let dailyUsageBuckets: [CodexTokenUsageDailyBucket]
    let modelUsage: [CodexModelTokenUsage]?
    let isModelUsagePartial: Bool?
    let localDailyDetails: [CodexDailyTokenDetail]?

    init(
        lifetimeTokens: Int64?,
        peakDailyTokens: Int64?,
        currentStreakDays: Int64?,
        longestStreakDays: Int64?,
        longestRunningTurnSeconds: Int64?,
        dailyUsageBuckets: [CodexTokenUsageDailyBucket],
        modelUsage: [CodexModelTokenUsage]? = nil,
        isModelUsagePartial: Bool? = nil,
        localDailyDetails: [CodexDailyTokenDetail]? = nil
    ) {
        self.lifetimeTokens = lifetimeTokens
        self.peakDailyTokens = peakDailyTokens
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
        self.longestRunningTurnSeconds = longestRunningTurnSeconds
        self.dailyUsageBuckets = dailyUsageBuckets
        self.modelUsage = modelUsage
        self.isModelUsagePartial = isModelUsagePartial
        self.localDailyDetails = localDailyDetails
    }

    var latestDailyTokens: Int64? {
        dailyUsageBuckets.last?.tokens
    }

    func localDetail(
        for date: Date,
        calendar: Calendar = .current
    ) -> CodexDailyTokenDetail? {
        localDailyDetails?.first {
            calendar.isDate($0.startDate, inSameDayAs: date)
        }
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
