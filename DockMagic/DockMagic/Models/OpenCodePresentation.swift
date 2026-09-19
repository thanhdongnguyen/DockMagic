import Foundation
import SwiftUI

struct OpenCodeDockAppearance: Codable, Equatable, Sendable {
    var chartColor: DockColor
    var tokenColor: DockColor
    var lineWidth: Double

    static let standard = Self(
        chartColor: ProjectTheme.defaultUsageRingColor,
        tokenColor: ProjectTheme.defaultUsageRingColor,
        lineWidth: 1.8
    )

    init(chartColor: DockColor, tokenColor: DockColor, lineWidth: Double = 1.8) {
        self.chartColor = Self.normalized(chartColor)
        self.tokenColor = Self.normalized(tokenColor)
        self.lineWidth = Self.normalized(lineWidth)
    }

    private enum CodingKeys: String, CodingKey {
        case chartColor, tokenColor, lineWidth
        case legacyColor = "color"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacyColor = try values.decodeIfPresent(DockColor.self, forKey: .legacyColor)
        chartColor = Self.normalized(try values.decodeIfPresent(DockColor.self, forKey: .chartColor)
            ?? legacyColor
            ?? Self.standard.chartColor)
        tokenColor = Self.normalized(try values.decodeIfPresent(DockColor.self, forKey: .tokenColor)
            ?? legacyColor
            ?? Self.standard.tokenColor)
        lineWidth = Self.normalized(try values.decodeIfPresent(Double.self, forKey: .lineWidth)
            ?? Self.standard.lineWidth)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(chartColor, forKey: .chartColor)
        try values.encode(tokenColor, forKey: .tokenColor)
        try values.encode(lineWidth, forKey: .lineWidth)
    }

    private static func normalized(_ color: DockColor) -> DockColor {
        DockColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private static func normalized(_ lineWidth: Double) -> Double {
        guard lineWidth.isFinite else { return Self.standard.lineWidth }
        return min(max(lineWidth, 1), 4)
    }
}

/// Compatibility inputs for shared activity-only components. No quota model is fabricated.
enum OpenCodePresentation {
    static func compact(_ value: Int64?) -> String {
        guard let value else { return "—" }
        let magnitude = Double(value)
        for (divisor, suffix) in [(1_000_000_000.0, "B"), (1_000_000.0, "M"), (1_000.0, "K")] where magnitude >= divisor {
            return (magnitude / divisor).formatted(.number.precision(.fractionLength(0...1))) + suffix
        }
        return value.formatted()
    }
    static func money(_ value: Double?) -> String {
        value?.formatted(.currency(code: "USD").precision(.fractionLength(2...4))) ?? "—"
    }
    static func buckets(_ snapshot: OpenCodeUsageSnapshot?, count: Int = 30, now: Date = .now) -> [CodexTokenUsageDailyBucket] {
        guard let snapshot else { return [] }
        return snapshot.trailingDays(count, now: now).map {
            CodexTokenUsageDailyBucket(startDate: $0, tokens: snapshot.day($0)?.tokens.total ?? 0)
        }
    }
    static func unavailable(_ snapshot: OpenCodeUsageSnapshot?, now: Date = .now) -> Set<Date> {
        guard let snapshot else { return [] }
        return Set(snapshot.trailingDays(30, now: now).filter { snapshot.day($0)?.tokens.total == nil })
    }
    static func account(_ snapshot: OpenCodeUsageSnapshot) -> CodexAccountTokenUsage {
        CodexAccountTokenUsage(lifetimeTokens: snapshot.lifetimeTokens, peakDailyTokens: nil,
            longestRunningTurnSeconds: nil, dailyUsageBuckets: snapshot.days.compactMap {
                guard let tokens = $0.tokens.total else { return nil }
                return CodexTokenUsageDailyBucket(startDate: $0.startDate, tokens: tokens)
            })
    }
    static func streak(_ snapshot: OpenCodeUsageSnapshot?, now: Date = .now) -> TokenUsageStreakSummary? {
        guard let snapshot else { return nil }
        let records = snapshot.days.compactMap { detail -> TokenUsageStreakRecordValue? in
            guard let tokens = detail.tokens.total, tokens > 0 else { return nil }
            let day = TokenUsageCalendarDay.containing(detail.startDate, calendar: snapshot.calendar)
            return TokenUsageStreakRecordValue(identifier: "openCode|\(snapshot.sourceID)|\(day.key)", provider: .openCode,
                dayKey: day.key, dayIndex: day.index, tokenCount: tokens, firstObservedAt: snapshot.readAt, lastObservedAt: snapshot.readAt)
        }
        // Reconcile from this source snapshot, never a union of unrelated databases or deleted messages.
        return TokenUsageStreakCalculator.summary(from: records, now: now, calendar: snapshot.calendar, coverage: .observedOnly)
    }
    static func momentum(_ snapshot: OpenCodeUsageSnapshot?, now: Date = .now) -> CodexShipMomentum? {
        guard let tokens = snapshot?.day(now)?.tokens.total else { return nil }
        return CodexShipMomentum(score: CodexShipMomentum.score(forTodayTokens: tokens), todayTokens: tokens)
    }
    static func topModels(_ snapshot: OpenCodeUsageSnapshot?, now: Date = .now) -> [CodexModelTokenUsage] {
        guard let snapshot, let from = snapshot.trailingDays(30, now: now).first else { return [] }
        var values: [String: Int64] = [:]
        for day in snapshot.days where day.startDate >= from && day.startDate <= now {
            for model in day.models {
                if let total = model.tokens.total { values[model.id] = OpenCodeTokens.sum(values[model.id] ?? 0, total) }
            }
        }
        let models: [CodexModelTokenUsage] = values.map { entry in
            CodexModelTokenUsage(model: entry.key, tokens: entry.value)
        }
        let ranked = models.sorted { lhs, rhs in
            if lhs.tokens == rhs.tokens { return lhs.model < rhs.model }
            return lhs.tokens > rhs.tokens
        }
        return Array(ranked.prefix(3))
    }
    static func hours(_ detail: OpenCodeDailyDetail, calendar: Calendar, now: Date = .now) -> [OpenCodeHourlyUsage] {
        guard let interval = calendar.dateInterval(of: .day, for: detail.startDate) else { return detail.hourly }
        var result: [OpenCodeHourlyUsage] = []
        var cursor = interval.start
        while cursor < interval.end {
            if let recorded = detail.hourly.first(where: { $0.startDate == cursor }) { result.append(recorded) }
            else {
                let unknown = cursor > now || detail.isPartial
                result.append(OpenCodeHourlyUsage(startDate: cursor, tokens: unknown ? OpenCodeTokens() : .zero, isPartial: unknown))
            }
            cursor = cursor.addingTimeInterval(3600) // elapsed hours preserve both occurrences at a DST fall-back
        }
        return result
    }
    static func breakdown(_ tokens: OpenCodeTokens) -> CodexTokenBreakdown {
        CodexTokenBreakdown(inputTokens: tokens.input ?? 0, cachedInputTokens: tokens.cacheRead ?? 0,
            cacheWriteInputTokens: tokens.cacheWrite ?? 0, outputTokens: tokens.output ?? 0,
            reasoningOutputTokens: tokens.reasoning ?? 0, totalTokens: tokens.total ?? 0)
    }
    static func canExport(_ state: OpenCodeUsageState, now: Date = .now) -> Bool {
        (state.snapshot?.day(now)?.tokens.total ?? 0) > 0
    }
}
