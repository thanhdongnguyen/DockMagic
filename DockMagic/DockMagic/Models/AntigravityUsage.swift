import Foundation
import CoreFoundation

/// A quota bucket is independent of token/cost telemetry. Legacy IDEs do not
/// identify the window duration, so `kind == nil` deliberately means unknown.
struct AntigravityQuotaBucket: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let kind: CodexRateLimitWindowKind?
    let remainingFraction: Double?
    let resetsAt: Date?
    let resetDescription: String?

    var shortTitle: String {
        switch kind {
        case .fiveHour: "5H"
        case .weekly: "7D"
        case nil: "QUOTA"
        }
    }

    var normalizedWindow: CodexRateLimitWindow? {
        guard let kind, let remainingFraction else { return nil }
        return CodexRateLimitWindow(
            kind: kind,
            usedPercent: Int(((1 - remainingFraction) * 100).rounded()),
            windowDurationMinutes: kind == .fiveHour ? 300 : 10_080,
            resetsAt: resetsAt
        )
    }
}

struct AntigravityQuotaGroup: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let buckets: [AntigravityQuotaBucket]

    var lowestRemaining: Double? { buckets.compactMap(\.remainingFraction).min() }
}

struct AntigravityQuotaSnapshot: Codable, Equatable, Sendable {
    let groups: [AntigravityQuotaGroup]
    let plan: String?
    let source: String
    let observedAt: Date

    func selectedGroup(_ id: String) -> AntigravityQuotaGroup? {
        if id != "auto" { return groups.first { $0.id == id } }
        return groups.min {
            ($0.lowestRemaining ?? 2, $0.id) < ($1.lowestRemaining ?? 2, $1.id)
        }
    }
}

struct AntigravityTelemetrySnapshot: Codable, Equatable, Sendable {
    let quota: AntigravityQuotaSnapshot?
    let selectedGroupID: String
    /// Shared normalized session/task/cost fields; the legacy type name is kept
    /// for backwards-compatible Claude cache decoding.
    let local: ClaudeCodeTelemetrySnapshot?
    let diagnostic: String?

    var selectedGroup: AntigravityQuotaGroup? {
        quota?.selectedGroup(selectedGroupID)
    }
}

enum AntigravityDataError: LocalizedError {
    case notRunning
    case unavailable
    case invalidConfiguration
    case bridgeConflict
    case missingPython

    var errorDescription: String? {
        switch self {
        case .notRunning:
            "Open Antigravity and sign in, or enable the local CLI bridge to receive usage."
        case .unavailable:
            "Antigravity did not return quota. Open its usage panel, then refresh."
        case .invalidConfiguration:
            "Antigravity settings could not be read. Existing settings were preserved."
        case .bridgeConflict:
            "The DockMagic integration configuration was changed externally. Restore it before reconnecting."
        case .missingPython:
            "The local bridge requires Python 3. Install Apple's command line tools, then reconnect."
        }
    }
}

enum AntigravityJSON {
    static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }

    static func count(_ value: Any?) -> Int64? {
        guard let value = number(value), value >= 0,
              value < Double(Int64.max), value.rounded(.down) == value else { return nil }
        return Int64(value)
    }

    static func date(_ value: Any?) -> Date? {
        if let value = number(value), value > 0 {
            return Date(timeIntervalSince1970: value > 10_000_000_000 ? value / 1000 : value)
        }
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    static func text(_ value: Any?, limit: Int = 160) -> String? {
        guard let value = value as? String else { return nil }
        let clean = value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let result = String(String.UnicodeScalarView(clean)).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : String(result.prefix(limit))
    }
}
