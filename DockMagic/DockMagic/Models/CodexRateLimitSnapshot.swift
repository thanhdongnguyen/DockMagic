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

struct ClaudeCodeContextUsage: Codable, Equatable, Sendable {
    let totalInputTokens: Int64?
    let totalOutputTokens: Int64?
    let contextWindowSize: Int64?
    let usedPercent: Double?
    let remainingPercent: Double?
    let currentUsage: CodexTokenBreakdown?

    var usedTokens: Int64? {
        guard let currentUsage else { return nil }
        return currentUsage.totalTokens
    }
}

struct ClaudeCodeSessionUsage: Codable, Equatable, Sendable {
    let sessionID: String?
    let sessionName: String?
    let modelID: String?
    let modelDisplayName: String?
    let agentName: String?
    let claudeCodeVersion: String?
    let estimatedCostUSD: Double?
    let totalDurationMilliseconds: Int64?
    let totalAPIDurationMilliseconds: Int64?
    let totalLinesAdded: Int64?
    let totalLinesRemoved: Int64?
    let context: ClaudeCodeContextUsage?
    let observedAt: Date
}

struct ClaudeCodeDailyCostUsage: Codable, Equatable, Identifiable, Sendable {
    let startDate: Date
    let estimatedCostUSD: Double

    var id: Date { startDate }
}

struct ClaudeCodeModelCostUsage: Codable, Equatable, Identifiable, Sendable {
    let model: String
    let estimatedCostUSD: Double

    var id: String { model }
}

enum ClaudeCodeTaskState: String, Codable, Equatable, Sendable {
    case pending
    case running
    case paused
    case completed
    case failed
    case stopped
    case unknown

    var isActive: Bool {
        switch self {
        case .pending, .running, .paused:
            true
        case .completed, .failed, .stopped, .unknown:
            false
        }
    }
}

struct ClaudeCodeActiveTask: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String?
    let name: String
    let kind: String?
    let state: ClaudeCodeTaskState
    let description: String?
    let label: String?
    let startedAt: Date?
    let tokenCount: Int64?
    let lastToolName: String?
    let observedAt: Date
}

enum ClaudeCodeGoalState: String, Codable, Equatable, Sendable {
    case active
    case paused
    case blocked
    case limited
    case complete
}

struct ClaudeCodeActiveGoal: Codable, Equatable, Identifiable, Sendable {
    let sessionID: String
    let objective: String
    let state: ClaudeCodeGoalState
    let iterations: Int?
    let lastReason: String?
    let createdAt: Date?
    let updatedAt: Date
    let tokenBudget: Int64?
    let tokensUsed: Int64?
    let timeUsedSeconds: Int64?

    var id: String { sessionID }
}

enum ClaudeCodeTelemetrySource: String, Codable, Equatable, Sendable {
    case statusLine
    case localHistory
    case statusLineAndLocalHistory
}

struct ClaudeCodeTelemetrySnapshot: Codable, Equatable, Sendable {
    let source: ClaudeCodeTelemetrySource
    let currentSession: ClaudeCodeSessionUsage?
    let observedSessionCount: Int
    let dailyCosts: [ClaudeCodeDailyCostUsage]
    let modelCosts: [ClaudeCodeModelCostUsage]
    let activeTasks: [ClaudeCodeActiveTask]
    let activeGoals: [ClaudeCodeActiveGoal]
    let historyIsPartial: Bool
    let costIsPartial: Bool
}

struct CodexRateLimitSnapshot: Codable, Equatable, Sendable {
    let planType: String?
    let limitID: String?
    let fiveHour: CodexRateLimitWindow?
    let weekly: CodexRateLimitWindow?
    let tokenUsage: CodexAccountTokenUsage?
    let recentTaskActivity: CodexRecentTaskActivity?
    let claudeTelemetry: ClaudeCodeTelemetrySnapshot?
    let fetchedAt: Date

    init(
        planType: String?,
        limitID: String?,
        fiveHour: CodexRateLimitWindow?,
        weekly: CodexRateLimitWindow?,
        tokenUsage: CodexAccountTokenUsage? = nil,
        recentTaskActivity: CodexRecentTaskActivity? = nil,
        claudeTelemetry: ClaudeCodeTelemetrySnapshot? = nil,
        fetchedAt: Date
    ) {
        self.planType = planType
        self.limitID = limitID
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.tokenUsage = tokenUsage
        self.recentTaskActivity = recentTaskActivity
        self.claudeTelemetry = claudeTelemetry
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
