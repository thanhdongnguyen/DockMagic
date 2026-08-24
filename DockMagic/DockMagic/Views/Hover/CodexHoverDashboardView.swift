import Charts
import SwiftUI

enum DockHoverPointerEdge: Sendable {
    case bottom
    case left
    case right
}

@MainActor
struct DockHoverDashboardRoot: View {
    let appModel: DockAppModel
    let pointerEdge: DockHoverPointerEdge

    var body: some View {
        DockMagicThemeRoot(
            content: DockHoverChrome(pointerEdge: pointerEdge) {
                if appModel.preferences.activeFeature == .codex {
                    CodexHoverDashboardView(
                        state: appModel.codexStore.state,
                        appearance: appModel.preferences.codexAppearance
                    )
                } else {
                    DockHoverFeatureSummaryView(
                        feature: appModel.preferences.activeFeature
                    )
                }
            },
            appearanceMode: .dark
        )
        .frame(width: 360, height: 224)
        .accessibilityIdentifier("dockHover.dashboard")
    }
}

@MainActor
struct CodexHoverDashboardView: View {
    let state: CodexUsageState
    let appearance: DockRingAppearance
    var now: Date = .now

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 5) {
            header
            quotaRows
            tokenHeader
            tokenChart
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Codex usage dashboard")
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image("CodexLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 21, height: 21)
                .accessibilityHidden(true)

            Text("Codex")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let plan = snapshot?.planType, !plan.isEmpty {
                Text(plan.localizedCapitalized)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(theme.opaqueSurfaceRaised)
                    )
                    .overlay {
                        Capsule().strokeBorder(theme.outline, lineWidth: 1)
                    }
            }

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.65), radius: 3)
                .accessibilityHidden(true)

            Text(statusTitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(statusColor)

            Spacer(minLength: 4)

            if let lifetimeTokens = tokenUsage?.lifetimeTokens {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Self.tokenLabel(lifetimeTokens))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text("lifetime")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Lifetime tokens")
                .accessibilityValue(lifetimeTokens.formatted())
            }
        }
        .frame(height: 22)
    }

    private var quotaRows: some View {
        VStack(spacing: 4) {
            CodexHoverQuotaRow(
                title: "5-hour",
                systemImage: "clock",
                window: snapshot?.fiveHour,
                tint: appearance.outerColor.color,
                resetLabel: resetLabel(for: snapshot?.fiveHour, isWeekly: false)
            )
            CodexHoverQuotaRow(
                title: "Weekly",
                systemImage: "calendar",
                window: snapshot?.weekly,
                tint: appearance.innerColor.color,
                resetLabel: resetLabel(for: snapshot?.weekly, isWeekly: true)
            )
        }
    }

    private var tokenHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text("Daily tokens")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let dateRangeLabel {
                Text(dateRangeLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 4)

            if let todayTokens = tokenUsage?.latestDailyTokens {
                Text(Self.tokenLabel(todayTokens))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                Text("today")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(appearance.innerColor.color)
            }
        }
        .frame(height: 15)
    }

    @ViewBuilder
    private var tokenChart: some View {
        if chartBuckets.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
                Text(tokenEmptyMessage)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 67)
            .background(theme.opaqueSurfaceInset.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Chart(chartBuckets) { bucket in
                BarMark(
                    x: .value("Day", bucket.startDate, unit: .day),
                    y: .value("Tokens", bucket.tokens)
                )
                .cornerRadius(3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            appearance.outerColor.color,
                            appearance.innerColor.color
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .opacity(bucket.id == chartBuckets.last?.id ? 1 : 0.7)
            }
            .chartXAxis {
                AxisMarks(values: chartBuckets.map(\.startDate)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            VStack(spacing: 0) {
                                Text(Self.weekdayLabel(date))
                                Text(Self.dayLabel(date))
                            }
                            .font(.system(size: 6.5, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) {
                    value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(theme.outline)
                    AxisValueLabel {
                        if let tokens = value.as(Int64.self) {
                            Text(Self.tokenAxisLabel(tokens))
                                .font(.system(size: 6.5, weight: .medium))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(theme.opaqueSurfaceInset.opacity(0.38))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 73)
            .accessibilityLabel("Daily token usage over the last seven days")
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if case .loading = state {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 7, weight: .semibold))
                    .accessibilityHidden(true)
            }

            Text(updatedLabel)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(theme.textTertiary)

            Spacer(minLength: 0)
        }
        .frame(height: 9)
    }

    private var snapshot: CodexRateLimitSnapshot? { state.snapshot }
    private var tokenUsage: CodexAccountTokenUsage? { snapshot?.tokenUsage }

    private var chartBuckets: [CodexTokenUsageDailyBucket] {
        Array(tokenUsage?.dailyUsageBuckets.suffix(7) ?? [])
    }

    private var statusTitle: String {
        switch state {
        case .idle:
            "Idle"
        case .loading:
            "Loading"
        case .live:
            "Live"
        case .stale:
            "Stale"
        case .unavailable:
            "Unavailable"
        }
    }

    private var statusColor: Color {
        switch state {
        case .live:
            theme.processingForeground
        case .loading:
            theme.informationForeground
        case .stale:
            theme.warningForeground
        case .idle, .unavailable:
            theme.dangerForeground
        }
    }

    private var tokenEmptyMessage: String {
        switch state {
        case .loading:
            "Loading token usage from Codex…"
        case let .unavailable(message), let .stale(_, message):
            message
        case .idle, .live:
            "Token history is not available from this Codex version."
        }
    }

    private var dateRangeLabel: String? {
        guard let first = chartBuckets.first?.startDate,
              let last = chartBuckets.last?.startDate else {
            return nil
        }
        let calendar = Calendar(identifier: .gregorian)
        let firstComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: first
        )
        let lastComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: last
        )
        guard let firstDay = firstComponents.day,
              let lastDay = lastComponents.day,
              let year = lastComponents.year else {
            return nil
        }

        if firstComponents.month == lastComponents.month {
            return "\(Self.monthLabel(last)) \(firstDay)–\(lastDay), \(year)"
        }
        return "\(Self.monthLabel(first)) \(firstDay)–\(Self.monthLabel(last)) \(lastDay), \(year)"
    }

    private var updatedLabel: String {
        guard let fetchedAt = snapshot?.fetchedAt else {
            return state.statusTitle
        }
        let elapsed = max(0, now.timeIntervalSince(fetchedAt))
        if elapsed < 60 {
            return "Updated just now"
        }
        return "Updated \(Int(elapsed / 60))m ago"
    }

    private func resetLabel(
        for window: CodexRateLimitWindow?,
        isWeekly: Bool
    ) -> String {
        guard let reset = window?.resetsAt else {
            return "Reset —"
        }
        if isWeekly {
            return "Resets \(reset.formatted(.dateTime.weekday(.abbreviated)))"
        }
        return "Resets \(reset.formatted(.dateTime.hour().minute()))"
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }

    private static func tokenAxisLabel(_ tokens: Int64) -> String {
        guard tokens > 0 else { return "0" }
        let millions = Double(tokens) / 1_000_000
        if millions >= 1 {
            return millions.formatted(
                .number.precision(.fractionLength(0...1))
            ) + "M"
        }
        return (Double(tokens) / 1_000).formatted(
            .number.precision(.fractionLength(0))
        ) + "K"
    }

    private static func weekdayLabel(_ date: Date) -> String {
        formatter("EEE").string(from: date)
    }

    private static func dayLabel(_ date: Date) -> String {
        formatter("d").string(from: date)
    }

    private static func monthLabel(_ date: Date) -> String {
        formatter("MMM").string(from: date)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}

private struct CodexHoverQuotaRow: View {
    let title: String
    let systemImage: String
    let window: CodexRateLimitWindow?
    let tint: Color
    let resetLabel: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 13)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 42, alignment: .leading)

            Text(remainingLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .frame(width: 41, alignment: .trailing)

            Text("left")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            GeometryReader { proxy in
                let fraction = window?.remainingFraction ?? 0
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.dockTrack)
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 5)

            Text(resetLabel)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 66, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(theme.opaqueSurfaceInset.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(theme.outline.opacity(0.75), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(remainingLabel) left. \(resetLabel).")
    }

    private var remainingLabel: String {
        guard let window else { return "—" }
        return "\(Int((window.remainingFraction * 100).rounded()))%"
    }
}

private struct DockHoverFeatureSummaryView: View {
    let feature: DockFeature

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(theme.actionForeground)
                .accessibilityHidden(true)

            Text(feature.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Text(feature.detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Text("Detailed hover dashboard coming next")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct DockHoverChrome<Content: View>: View {
    let pointerEdge: DockHoverPointerEdge
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch pointerEdge {
        case .bottom:
            VStack(spacing: 0) {
                card.frame(height: 214)
                DockHoverPointerShape(direction: .down)
                    .fill(.ultraThinMaterial)
                    .frame(width: 20, height: 10)
            }
        case .left:
            HStack(spacing: 0) {
                DockHoverPointerShape(direction: .left)
                    .fill(.ultraThinMaterial)
                    .frame(width: 10, height: 20)
                card.frame(width: 350)
            }
        case .right:
            HStack(spacing: 0) {
                card.frame(width: 350)
                DockHoverPointerShape(direction: .right)
                    .fill(.ultraThinMaterial)
                    .frame(width: 10, height: 20)
            }
        }
    }

    private var card: some View {
        content()
            .padding(10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.36),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.48), radius: 18, y: 8)
    }
}

private struct DockHoverPointerShape: Shape {
    enum Direction {
        case down
        case left
        case right
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .left:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

#if DEBUG
extension CodexRateLimitSnapshot {
    static var hoverDesignPreview: Self {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 18
        ))!
        let values: [Int64] = [980_000, 1_320_000, 1_560_000, 1_210_000,
                               1_010_000, 730_000, 1_280_000]
        return Self(
            planType: "pro",
            limitID: "codex",
            fiveHour: CodexRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 26,
                windowDurationMinutes: 300,
                resetsAt: calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 24,
                    hour: 2,
                    minute: 40
                ))
            ),
            weekly: CodexRateLimitWindow(
                kind: .weekly,
                usedPercent: 59,
                windowDurationMinutes: 10_080,
                resetsAt: calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 28
                ))
            ),
            tokenUsage: CodexAccountTokenUsage(
                lifetimeTokens: 18_400_000,
                peakDailyTokens: 1_560_000,
                currentStreakDays: 7,
                longestStreakDays: 28,
                longestRunningTurnSeconds: 1_460,
                dailyUsageBuckets: values.enumerated().map { index, tokens in
                    CodexTokenUsageDailyBucket(
                        startDate: calendar.date(
                            byAdding: .day,
                            value: index,
                            to: start
                        )!,
                        tokens: tokens
                    )
                }
            ),
            fetchedAt: .now
        )
    }
}
#endif
