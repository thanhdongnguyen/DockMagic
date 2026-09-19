import SwiftUI

enum GrokBuildPresentation {
    static func today(_ history: GrokBuildHistorySnapshot?, now: Date = .now, calendar: Calendar = .current) -> Int64? {
        history?.days.first { calendar.isDate($0.startDate, inSameDayAs: now) }?.tokens
    }
    static func compact(_ value: Int64?) -> String {
        guard let value else { return "—" }
        for (scale, suffix) in [(1_000_000_000.0, "B"), (1_000_000.0, "M"), (1_000.0, "K")] where Double(value) >= scale {
            return (Double(value) / scale).formatted(.number.precision(.fractionLength(0...1))) + suffix
        }
        return value.formatted()
    }
    // Shared chart APIs require numeric storage plus an explicit missing set.
    // The missing set must always travel with these compatibility buckets.
    static func buckets(_ history: GrokBuildHistorySnapshot) -> [CodexTokenUsageDailyBucket] {
        history.days.map { .init(startDate: $0.startDate, tokens: $0.tokens ?? 0) }
    }
    static func unknown(_ history: GrokBuildHistorySnapshot) -> Set<Date> {
        Set(history.days.filter { $0.tokens == nil }.map(\.startDate))
    }
    static func momentum(_ history: GrokBuildHistorySnapshot?, now: Date = .now) -> CodexShipMomentum? {
        today(history, now: now).map { .init(score: CodexShipMomentum.score(forTodayTokens: $0), todayTokens: $0) }
    }
    static func models(_ history: GrokBuildHistorySnapshot) -> [CodexModelTokenUsage] {
        history.topModels.map { .init(model: $0.model, tokens: $0.tokens) }
    }
    static func modelCoverage(_ history: GrokBuildHistorySnapshot) -> String {
        guard history.days.contains(where: { ($0.tokens ?? 0) > 0 }) else {
            return "Model coverage unavailable: no eligible tokens observed."
        }
        return history.days.contains { $0.tokens != nil && $0.modelCoverageIsPartial }
            ? "Model coverage: some observed tokens have no model."
            : "Model coverage: all observed tokens attributed."
    }
    static func coverage(_ history: GrokBuildHistorySnapshot) -> String {
        let coverage = history.coverage
        return "\(history.days.filter { $0.tokens != nil }.count)/30 days observed · \(coverage.excludedSessions) excluded · \(coverage.unavailableSources) unavailable · \(coverage.quarantinedSessions) quarantined\(coverage.scanWasLimited ? " · scan limited" : "")"
    }
}

/// Neutral experimental identity mark, not an invented official brand asset.
struct GrokBuildIdentityMark: View {
    @Environment(\.designTheme) private var theme
    var body: some View {
        Text("G").dsFont(size: 20, weight: .bold)
            .foregroundStyle(theme.textPrimary).frame(width: 26, height: 26)
            .accessibilityHidden(true)
    }
}
