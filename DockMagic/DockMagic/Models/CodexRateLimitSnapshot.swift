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
    let toolTokens: Int64
    let totalTokens: Int64

    init(
        inputTokens: Int64,
        cachedInputTokens: Int64,
        cacheWriteInputTokens: Int64,
        outputTokens: Int64,
        reasoningOutputTokens: Int64,
        toolTokens: Int64 = 0,
        totalTokens: Int64
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteInputTokens = cacheWriteInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.toolTokens = toolTokens
        self.totalTokens = totalTokens
    }

    private enum CodingKeys: String, CodingKey {
        case inputTokens
        case cachedInputTokens
        case cacheWriteInputTokens
        case outputTokens
        case reasoningOutputTokens
        case toolTokens
        case totalTokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decode(Int64.self, forKey: .inputTokens)
        cachedInputTokens = try container.decode(
            Int64.self,
            forKey: .cachedInputTokens
        )
        cacheWriteInputTokens = try container.decode(
            Int64.self,
            forKey: .cacheWriteInputTokens
        )
        outputTokens = try container.decode(Int64.self, forKey: .outputTokens)
        reasoningOutputTokens = try container.decode(
            Int64.self,
            forKey: .reasoningOutputTokens
        )
        toolTokens = try container.decodeIfPresent(
            Int64.self,
            forKey: .toolTokens
        ) ?? 0
        totalTokens = try container.decode(Int64.self, forKey: .totalTokens)
    }

    static let zero = CodexTokenBreakdown(
        inputTokens: 0,
        cachedInputTokens: 0,
        cacheWriteInputTokens: 0,
        outputTokens: 0,
        reasoningOutputTokens: 0,
        toolTokens: 0,
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
            toolTokens: toolTokens + other.toolTokens,
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
    let longestRunningTurnSeconds: Int64?
    let dailyUsageBuckets: [CodexTokenUsageDailyBucket]
    let modelUsage: [CodexModelTokenUsage]?
    let isModelUsagePartial: Bool?
    let localDailyDetails: [CodexDailyTokenDetail]?

    init(
        lifetimeTokens: Int64?,
        peakDailyTokens: Int64?,
        longestRunningTurnSeconds: Int64?,
        dailyUsageBuckets: [CodexTokenUsageDailyBucket],
        modelUsage: [CodexModelTokenUsage]? = nil,
        isModelUsagePartial: Bool? = nil,
        localDailyDetails: [CodexDailyTokenDetail]? = nil
    ) {
        self.lifetimeTokens = lifetimeTokens
        self.peakDailyTokens = peakDailyTokens
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

enum TokenUsageStreakMilestone: String, CaseIterable, Codable, Identifiable, Sendable {
    case firstPrompt
    case spark
    case loop
    case builder
    case flow
    case navigator
    case century
    case architect
    case codexCore
    case continuum

    var id: String { rawValue }

    var requiredDays: Int64 {
        switch self {
        case .firstPrompt: 1
        case .spark: 3
        case .loop: 7
        case .builder: 14
        case .flow: 30
        case .navigator: 60
        case .century: 100
        case .architect: 180
        case .codexCore: 365
        case .continuum: 730
        }
    }

    var title: String {
        switch self {
        case .firstPrompt: "First Prompt"
        case .spark: "Spark"
        case .loop: "Loop"
        case .builder: "Builder"
        case .flow: "Flow"
        case .navigator: "Navigator"
        case .century: "Century"
        case .architect: "Architect"
        case .codexCore: "Keystone"
        case .continuum: "Continuum"
        }
    }

    var detail: String {
        switch self {
        case .firstPrompt: "The loop begins."
        case .spark: "Repeated intent is becoming a habit."
        case .loop: "A complete week of active days."
        case .builder: "A repeatable two-week rhythm."
        case .flow: "A month-scale creative routine."
        case .navigator: "Sustained direction across two months."
        case .century: "One hundred active days in sequence."
        case .architect: "Long-term structure that keeps compounding."
        case .codexCore: "A complete year held by a stable core."
        case .continuum: "Two years of remarkable continuity."
        }
    }

    var assetName: String {
        switch self {
        case .firstPrompt: "StreakBadgeFirstPrompt"
        case .spark: "StreakBadgeSpark"
        case .loop: "StreakBadgeLoop"
        case .builder: "StreakBadgeBuilder"
        case .flow: "StreakBadgeFlow"
        case .navigator: "StreakBadgeNavigator"
        case .century: "StreakBadgeCentury"
        case .architect: "StreakBadgeArchitect"
        case .codexCore: "StreakBadgeCodexCore"
        case .continuum: "StreakBadgeContinuum"
        }
    }

    static func highestUnlocked(
        for bestStreakDays: Int64
    ) -> TokenUsageStreakMilestone? {
        allCases.last { bestStreakDays >= $0.requiredDays }
    }

    static func nextLocked(
        after bestStreakDays: Int64
    ) -> TokenUsageStreakMilestone? {
        allCases.first { bestStreakDays < $0.requiredDays }
    }
}

struct TokenUsageStreakDay: Codable, Equatable, Identifiable, Sendable {
    enum State: Codable, Equatable, Sendable {
        case active
        case inactive
        case unknown
        case todayPending
    }

    let date: Date
    let state: State

    var id: Date { date }
}

struct TokenUsageStreakSummary: Codable, Equatable, Sendable {
    let currentDays: Int64
    let bestDays: Int64
    let earnedBadge: TokenUsageStreakMilestone?
    let previousBadge: TokenUsageStreakMilestone?
    let nextBadge: TokenUsageStreakMilestone?
    let daysUntilNextBadge: Int64?
    let recentDays: [TokenUsageStreakDay]

    var hasActivityToday: Bool {
        recentDays.last?.state == .active
    }

    var earnedMilestones: [TokenUsageStreakMilestone] {
        TokenUsageStreakMilestone.allCases.filter {
            bestDays >= $0.requiredDays
        }
    }
}

#if DEBUG
extension TokenUsageStreakSummary {
    static func fixture(
        currentDays: Int64,
        bestDays: Int64,
        endingAt date: Date,
        calendar: Calendar = .current
    ) -> Self {
        let normalizedCurrent = max(0, currentDays)
        let normalizedBest = max(normalizedCurrent, max(0, bestDays))
        let earnedBadge = TokenUsageStreakMilestone.highestUnlocked(
            for: normalizedBest
        )
        let previousBadge: TokenUsageStreakMilestone? = earnedBadge.flatMap {
            earned in
            guard
                let index = TokenUsageStreakMilestone.allCases.firstIndex(
                    of: earned
                ),
                index > TokenUsageStreakMilestone.allCases.startIndex
            else {
                return nil
            }
            return TokenUsageStreakMilestone.allCases[
                TokenUsageStreakMilestone.allCases.index(before: index)
            ]
        }
        let nextBadge = TokenUsageStreakMilestone.nextLocked(
            after: normalizedBest
        )
        let today = calendar.startOfDay(for: date)
        let recentDays = (0..<7).compactMap { offset in
            calendar.date(
                byAdding: .day,
                value: offset - 6,
                to: today
            ).map { day in
                TokenUsageStreakDay(
                    date: day,
                    state: offset >= 7 - Int(min(normalizedCurrent, 7))
                        ? .active
                        : .unknown
                )
            }
        }
        return Self(
            currentDays: normalizedCurrent,
            bestDays: normalizedBest,
            earnedBadge: earnedBadge,
            previousBadge: previousBadge,
            nextBadge: nextBadge,
            daysUntilNextBadge: nextBadge.map {
                max(0, $0.requiredDays - normalizedCurrent)
            },
            recentDays: recentDays
        )
    }
}
#endif

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

/// Provider-neutral quota data shared by Dock and hover dashboard UI.
struct UsageQuotaMetric: Equatable, Identifiable, Sendable {
    let id: String
    let shortLabel: String
    let title: String
    let systemImage: String
    let remainingFraction: Double?
    let resetsAt: Date?

    var usesSecondaryAppearance: Bool { id == "weekly" }
}

enum UsageQuotaPresentation {
    static func codex(
        _ snapshot: CodexRateLimitSnapshot?,
        includesMissing: Bool = false
    ) -> [UsageQuotaMetric] {
        let metrics = [
            metric(
                id: "five-hour",
                shortLabel: "5H",
                title: "5-hour",
                systemImage: "clock",
                window: snapshot?.fiveHour
            ),
            metric(
                id: "weekly",
                shortLabel: "7D",
                title: "Weekly",
                systemImage: "calendar",
                window: snapshot?.weekly
            )
        ]
        return includesMissing
            ? metrics
            : metrics.filter { $0.remainingFraction != nil }
    }

    private static func metric(
        id: String,
        shortLabel: String,
        title: String,
        systemImage: String,
        window: CodexRateLimitWindow?
    ) -> UsageQuotaMetric {
        UsageQuotaMetric(
            id: id,
            shortLabel: shortLabel,
            title: title,
            systemImage: systemImage,
            remainingFraction: window?.remainingFraction,
            resetsAt: window?.resetsAt
        )
    }
}

struct CodexRateLimitSnapshot: Codable, Equatable, Sendable {
    let planType: String?
    let limitID: String?
    let fiveHour: CodexRateLimitWindow?
    let weekly: CodexRateLimitWindow?
    let tokenUsage: CodexAccountTokenUsage?
    let streakSummary: TokenUsageStreakSummary?
    let recentTaskActivity: CodexRecentTaskActivity?
    let claudeTelemetry: ClaudeCodeTelemetrySnapshot?
    let fetchedAt: Date

    init(
        planType: String?,
        limitID: String?,
        fiveHour: CodexRateLimitWindow?,
        weekly: CodexRateLimitWindow?,
        tokenUsage: CodexAccountTokenUsage? = nil,
        streakSummary: TokenUsageStreakSummary? = nil,
        recentTaskActivity: CodexRecentTaskActivity? = nil,
        claudeTelemetry: ClaudeCodeTelemetrySnapshot? = nil,
        fetchedAt: Date
    ) {
        self.planType = planType
        self.limitID = limitID
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.tokenUsage = tokenUsage
        self.streakSummary = streakSummary
        self.recentTaskActivity = recentTaskActivity
        self.claudeTelemetry = claudeTelemetry
        self.fetchedAt = fetchedAt
    }

    var hasSupportedWindow: Bool {
        fiveHour != nil || weekly != nil
    }

    func withStreakSummary(
        _ streakSummary: TokenUsageStreakSummary
    ) -> Self {
        Self(
            planType: planType,
            limitID: limitID,
            fiveHour: fiveHour,
            weekly: weekly,
            tokenUsage: tokenUsage,
            streakSummary: streakSummary,
            recentTaskActivity: recentTaskActivity,
            claudeTelemetry: claudeTelemetry,
            fetchedAt: fetchedAt
        )
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
