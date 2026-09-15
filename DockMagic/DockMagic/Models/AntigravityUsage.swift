import Foundation

struct AntigravityQuotaBucket: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let groupName: String
    let title: String
    let description: String?
    let windowDurationMinutes: Int?
    let remainingFraction: Double
    let resetsAt: Date?

    var shortTitle: String {
        let normalized = "\(id) \(groupName)".lowercased()
        if normalized.contains("gemini") { return "GEM" }
        if normalized.contains("3p")
            || normalized.contains("claude")
            || normalized.contains("gpt") {
            return "3P"
        }
        return windowDurationMinutes == 10_080 ? "7D" : "Q"
    }

    var windowTitle: String {
        switch windowDurationMinutes {
        case 300: "5-hour"
        case 10_080: "Weekly"
        case nil: title
        default: title
        }
    }
}

struct AntigravityQuotaSnapshot: Codable, Equatable, Sendable {
    let buckets: [AntigravityQuotaBucket]
    let fetchedAt: Date
    let cliVersion: String?

    var dockBuckets: [AntigravityQuotaBucket] {
        Array(buckets.prefix(2))
    }
}

struct AntigravityContextUsage: Codable, Equatable, Sendable {
    let totalInputTokens: Int64?
    let totalOutputTokens: Int64?
    let contextWindowSize: Int64?
    let usedPercent: Double?
    let remainingPercent: Double?
    let currentInputTokens: Int64?
    let currentOutputTokens: Int64?
    let cacheCreationInputTokens: Int64?
    let cacheReadInputTokens: Int64?

    var observedTotalTokens: Int64? {
        guard totalInputTokens != nil || totalOutputTokens != nil else {
            return nil
        }
        return (totalInputTokens ?? 0) + (totalOutputTokens ?? 0)
    }
}

struct AntigravitySessionSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let modelID: String?
    let modelDisplayName: String?
    let cliVersion: String?
    let planTier: String?
    let agentState: String?
    let executionMode: String?
    let taskCount: Int?
    let artifactCount: Int?
    let pendingInputCount: Int?
    let toolConfirmationPending: Bool
    let context: AntigravityContextUsage?
    let observedAt: Date

    var isActiveWork: Bool {
        toolConfirmationPending
            || (taskCount ?? 0) > 0
            || ![nil, "", "idle"].contains(agentState?.lowercased())
    }

    var modelLabel: String? {
        modelDisplayName ?? modelID
    }
}

struct AntigravityUsageSnapshot: Codable, Equatable, Sendable {
    let quota: AntigravityQuotaSnapshot?
    let tokenUsage: CodexAccountTokenUsage?
    let streakSummary: TokenUsageStreakSummary?
    let currentSession: AntigravitySessionSnapshot?
    let activeSessionCount: Int
    let historyIsPartial: Bool
    let fetchedAt: Date

    var planType: String? { currentSession?.planTier }
    var cliVersion: String? { currentSession?.cliVersion ?? quota?.cliVersion }
    var dockBuckets: [AntigravityQuotaBucket] { quota?.dockBuckets ?? [] }

    func withStreakSummary(_ summary: TokenUsageStreakSummary) -> Self {
        Self(
            quota: quota,
            tokenUsage: tokenUsage,
            streakSummary: summary,
            currentSession: currentSession,
            activeSessionCount: activeSessionCount,
            historyIsPartial: historyIsPartial,
            fetchedAt: fetchedAt
        )
    }
}

enum AntigravityUsageState: Equatable, Sendable {
    case idle
    case loading
    case live(AntigravityUsageSnapshot)
    case stale(AntigravityUsageSnapshot, message: String)
    case unavailable(message: String)

    var snapshot: AntigravityUsageSnapshot? {
        switch self {
        case let .live(snapshot), let .stale(snapshot, _): snapshot
        case .idle, .loading, .unavailable: nil
        }
    }

    var statusTitle: String {
        switch self {
        case .idle: "Not connected"
        case .loading: "Loading"
        case .live: "Live"
        case .stale: "Last known"
        case .unavailable: "Unavailable"
        }
    }
}

enum AntigravityConnectionState: Equatable, Sendable {
    case cliMissing
    case checking
    case signedOut
    case signingIn
    case signingOut
    case connected(lastUpdated: Date)
    case stale(lastSnapshot: AntigravityUsageSnapshot, message: String)
    case failed(message: String)
}

enum AntigravityUsageError: LocalizedError, Equatable {
    case executableNotFound
    case commandFailed
    case signedOut
    case invalidResponse
    case unsupportedResponse
    case invalidConfiguration
    case bridgeConflict

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Antigravity CLI is not installed. Install agy to load usage."
        case .commandFailed:
            "Antigravity usage could not be refreshed. Try again after checking agy."
        case .signedOut:
            "Sign in to agy, then refresh Antigravity usage."
        case .invalidResponse:
            "agy returned an invalid usage response. Existing data was preserved."
        case .unsupportedResponse:
            "This agy version does not expose structured quota data. Update agy and try again."
        case .invalidConfiguration:
            "Antigravity settings could not be read. Existing settings were preserved."
        case .bridgeConflict:
            "The Antigravity status-line configuration changed outside DockMagic. Review it before reconnecting."
        }
    }
}
