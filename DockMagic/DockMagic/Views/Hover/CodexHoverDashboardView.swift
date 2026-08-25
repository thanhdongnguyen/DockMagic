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
    var appearanceMode: DSAppearanceMode = .dark
    var initialHoveredBucketID: Date?

    init(
        appModel: DockAppModel,
        pointerEdge: DockHoverPointerEdge,
        appearanceMode: DSAppearanceMode = .dark,
        initialHoveredBucketID: Date? = nil
    ) {
        self.appModel = appModel
        self.pointerEdge = pointerEdge
        self.appearanceMode = appearanceMode
        self.initialHoveredBucketID = initialHoveredBucketID
    }

    var body: some View {
        DockMagicThemeRoot(
            content: DockHoverChrome(pointerEdge: pointerEdge) {
                if appModel.preferences.activeFeature == .codex {
                    CodexHoverDashboardView(
                        state: appModel.codexStore.state,
                        initialHoveredBucketID: initialHoveredBucketID
                    )
                } else {
                    DockHoverFeatureSummaryView(
                        feature: appModel.preferences.activeFeature
                    )
                }
            },
            appearanceMode: appearanceMode
        )
        .frame(
            width: DockHoverPanelPlacement.panelSize.width,
            height: DockHoverPanelPlacement.panelSize.height
        )
        .accessibilityIdentifier("dockHover.dashboard")
    }
}

@MainActor
struct CodexHoverDashboardView: View {
    let state: CodexUsageState

    @Environment(\.designTheme) private var theme
    @State private var hoveredBucketID: Date?

    init(
        state: CodexUsageState,
        initialHoveredBucketID: Date? = nil
    ) {
        self.state = state
        _hoveredBucketID = State(initialValue: initialHoveredBucketID)
    }

    var body: some View {
        VStack(spacing: 7) {
            header
            quotaRows
            tokenHeader
            tokenChart
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Codex usage dashboard")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("CodexLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                // The supplied logo includes faint edge pixels outside the
                // brand mark. Crop that transparent fringe at presentation
                // time so it stays clean on an opaque dark surface.
                .frame(width: 42, height: 42)
                .frame(width: 26, height: 26)
                .clipShape(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)

            Text("Codex")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let plan = snapshot?.planType, !plan.isEmpty {
                CodexPlanBadge(plan: plan)
            }

            if let statusTitle, let statusSystemImage {
                HStack(spacing: 3) {
                    Image(systemName: statusSystemImage)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)

                    Text(statusTitle)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(statusForeground)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 4)

            if let lifetimeTokens = tokenUsage?.lifetimeTokens {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Self.tokenLabel(lifetimeTokens))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text("lifetime")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Lifetime tokens")
                .accessibilityValue(lifetimeTokens.formatted())
            }
        }
        .frame(height: 30)
    }

    private var quotaRows: some View {
        VStack(spacing: 6) {
            ForEach(visibleQuotaWindows, id: \.windowDurationMinutes) { window in
                CodexHoverQuotaRow(
                    title: window.kind == .fiveHour ? "5-hour" : "Weekly",
                    systemImage: window.kind == .fiveHour ? "clock" : "calendar",
                    window: window,
                    resetLabel: CodexHoverDashboardPresentation.resetLabel(
                        for: window
                    )
                )
            }
        }
    }

    private var tokenHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("Daily tokens")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let dateRangeLabel {
                Text(dateRangeLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 4)

            if let hoveredBucket {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Self.hoverDateLabel(hoveredBucket.startDate))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text(hoveredBucket.tokens.formatted())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text("tokens")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else if let todayTokens = tokenUsage?.latestDailyTokens {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Self.tokenLabel(todayTokens))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text("today")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private var tokenChart: some View {
        if chartBuckets.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
                Text(tokenEmptyMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: tokenChartHeight)
            .background(theme.opaqueSurfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            CodexTokenHistoryChart(
                buckets: chartBuckets,
                hoveredBucketID: $hoveredBucketID,
                plotHeight: tokenChartPlotHeight
            )
        }
    }

    private var snapshot: CodexRateLimitSnapshot? { state.snapshot }
    private var tokenUsage: CodexAccountTokenUsage? { snapshot?.tokenUsage }

    private var visibleQuotaWindows: [CodexRateLimitWindow] {
        CodexHoverDashboardPresentation.visibleQuotaWindows(in: snapshot)
    }

    private var chartBuckets: [CodexTokenUsageDailyBucket] {
        CodexHoverDashboardPresentation.chartBuckets(from: tokenUsage)
    }

    private var hoveredBucket: CodexTokenUsageDailyBucket? {
        guard let hoveredBucketID else { return nil }
        return chartBuckets.first { $0.id == hoveredBucketID }
    }

    private var tokenChartPlotHeight: CGFloat {
        visibleQuotaWindows.count < 2 ? 128 : 88
    }

    private var tokenChartHeight: CGFloat {
        tokenChartPlotHeight + 38
    }

    private var statusTitle: String? {
        switch state {
        case .idle:
            "Idle"
        case .loading:
            "Loading"
        case .live:
            nil
        case .stale:
            "Stale"
        case .unavailable:
            "Unavailable"
        }
    }

    private var statusSystemImage: String? {
        switch state {
        case .idle:
            "minus.circle"
        case .loading:
            "ellipsis.circle"
        case .live:
            nil
        case .stale:
            "exclamationmark.triangle"
        case .unavailable:
            "xmark.circle"
        }
    }

    private var statusForeground: Color {
        switch state {
        case .loading:
            theme.processingForeground
        case .stale:
            theme.warningForeground
        case .unavailable:
            theme.dangerForeground
        case .idle, .live:
            theme.textTertiary
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

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }

    private static func monthLabel(_ date: Date) -> String {
        formatter("MMM").string(from: date)
    }

    private static func hoverDateLabel(_ date: Date) -> String {
        formatter("MMM d").string(from: date)
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

enum CodexHoverDashboardPresentation {
    static let maximumChartDays = 30

    static func visibleQuotaWindows(
        in snapshot: CodexRateLimitSnapshot?
    ) -> [CodexRateLimitWindow] {
        [snapshot?.fiveHour, snapshot?.weekly].compactMap { $0 }
    }

    static func chartBuckets(
        from tokenUsage: CodexAccountTokenUsage?
    ) -> [CodexTokenUsageDailyBucket] {
        Array(tokenUsage?.dailyUsageBuckets.suffix(maximumChartDays) ?? [])
    }

    static func resetLabel(for window: CodexRateLimitWindow) -> String {
        guard let reset = window.resetsAt else { return "Reset —" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, h:mm a"
        return "Resets \(formatter.string(from: reset))"
    }
}

private struct CodexPlanBadge: View {
    let plan: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 9, weight: .bold))
                    .accessibilityHidden(true)
            }

            Text(plan.localizedUppercase)
                .font(.system(size: 10, weight: isPremium ? .bold : .semibold))
                .tracking(isPremium ? 0.25 : 0)
        }
        .foregroundStyle(isPremium ? theme.textPrimary : theme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(
                isPremium ? theme.opaqueSurfaceInset : theme.opaqueSurfaceRaised
            )
        )
        .overlay {
            Capsule().strokeBorder(
                isPremium ? theme.outlineStrong : theme.outline,
                lineWidth: isPremium ? 1.25 : 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex \(plan.localizedCapitalized) plan")
    }

    private var normalizedPlan: String {
        plan.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isPremium: Bool {
        normalizedPlan == "pro" || normalizedPlan == "plus"
    }

    private var systemImage: String? {
        switch normalizedPlan {
        case "pro":
            "crown.fill"
        case "plus":
            "sparkles"
        default:
            nil
        }
    }
}

struct CodexTokenHistoryChart: View {
    let buckets: [CodexTokenUsageDailyBucket]
    @Binding var hoveredBucketID: Date?
    let plotHeight: CGFloat

    @Environment(\.designTheme) private var theme

    private let columnWidth: CGFloat = 46
    private let columnSpacing: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            yAxis

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        ForEach(buckets) { bucket in
                            tokenColumn(for: bucket)
                                .id(bucket.id)
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(alignment: .top) {
                        chartGrid
                    }
                }
                .onAppear {
                    scrollToLatest(using: proxy)
                }
                .onChange(of: buckets.last?.id) { _, _ in
                    scrollToLatest(using: proxy)
                }
            }
        }
        .frame(height: plotHeight + 38)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily token usage over the last 30 days")
    }

    private var yAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(Self.tokenAxisLabel(axisMaximum))
            Spacer()
            Text(Self.tokenAxisLabel(axisMaximum / 2))
            Spacer()
            Text("0")
        }
        .font(.system(size: 7.5, weight: .medium))
        .foregroundStyle(theme.textTertiary)
        .monospacedDigit()
        .frame(width: 31, height: plotHeight, alignment: .trailing)
    }

    private var chartGrid: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.outline).frame(height: 0.5)
            Spacer()
            Rectangle().fill(theme.outline).frame(height: 0.5)
            Spacer()
            Rectangle().fill(theme.outline).frame(height: 0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: plotHeight)
    }

    private func tokenColumn(
        for bucket: CodexTokenUsageDailyBucket
    ) -> some View {
        let isLatest = bucket.id == buckets.last?.id
        let isHovered = bucket.id == hoveredBucketID
        let height = barHeight(for: bucket.tokens)

        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                Color.clear

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.action)
                    .opacity(isHovered ? 1 : (isLatest ? 0.9 : 0.5))
                    .frame(width: 27, height: height)
                    .overlay {
                        if isHovered {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(theme.outlineStrong, lineWidth: 1)
                                .frame(width: 27, height: height)
                        }
                    }
            }
            .frame(width: columnWidth, height: plotHeight)

            VStack(spacing: 0) {
                Text(Self.weekdayLabel(bucket.startDate))
                Text(Self.dayLabel(bucket.startDate))
            }
            .font(.system(size: 8, weight: isLatest ? .semibold : .medium))
            .foregroundStyle(isLatest ? theme.textSecondary : theme.textTertiary)
            .monospacedDigit()
        }
        .frame(width: columnWidth)
        .contentShape(Rectangle())
        .onHover { isInside in
            if isInside {
                hoveredBucketID = bucket.id
            } else if hoveredBucketID == bucket.id {
                hoveredBucketID = nil
            }
        }
        .help(
            "\(Self.fullDateLabel(bucket.startDate)): "
                + "\(bucket.tokens.formatted()) tokens"
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.fullDateLabel(bucket.startDate))
        .accessibilityValue("\(bucket.tokens.formatted()) tokens")
    }

    private var axisMaximum: Int64 {
        let peak = buckets.map(\.tokens).max() ?? 0
        guard peak > 0 else { return 1 }
        return max(1, Int64((Double(peak) * 1.1).rounded(.up)))
    }

    private func barHeight(for tokens: Int64) -> CGFloat {
        guard tokens > 0 else { return 0 }
        let fraction = min(1, Double(tokens) / Double(axisMaximum))
        return max(2, plotHeight * CGFloat(fraction))
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let latestID = buckets.last?.id else { return }
        proxy.scrollTo(latestID, anchor: .trailing)
    }

    private static func tokenAxisLabel(_ tokens: Int64) -> String {
        guard tokens > 0 else { return "0" }
        return tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }

    private static func weekdayLabel(_ date: Date) -> String {
        formatter("EEE").string(from: date)
    }

    private static func dayLabel(_ date: Date) -> String {
        formatter("d").string(from: date)
    }

    private static func fullDateLabel(_ date: Date) -> String {
        formatter("MMM d, yyyy").string(from: date)
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
    let window: CodexRateLimitWindow
    let resetLabel: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 15)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 50, alignment: .leading)

            Text(remainingLabel)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(valueForeground)
                .monospacedDigit()
                .frame(width: 43, alignment: .trailing)

            Text("left")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            GeometryReader { proxy in
                let fraction = window.remainingFraction
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.dockTrack)
                    Capsule()
                        .fill(progressFill)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)

            Text(resetLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 126, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(remainingLabel) left. \(resetLabel).")
    }

    private var remainingLabel: String {
        return "\(Int((window.remainingFraction * 100).rounded()))%"
    }

    private var progressFill: Color {
        switch window.remainingFraction {
        case ...0.05:
            return theme.danger
        case ...0.2:
            return theme.warning
        default:
            return theme.action
        }
    }

    private var valueForeground: Color {
        switch window.remainingFraction {
        case ...0.05:
            return theme.dangerForeground
        case ...0.2:
            return theme.warningForeground
        default:
            return theme.textPrimary
        }
    }
}

private struct DockHoverFeatureSummaryView: View {
    let feature: DockFeature

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: feature.systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.actionForeground)
                .accessibilityHidden(true)

            Text(feature.title)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Text(feature.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Text("Detailed hover dashboard coming next")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct DockHoverChrome<Content: View>: View {
    let pointerEdge: DockHoverPointerEdge
    @ViewBuilder let content: () -> Content

    @Environment(\.designTheme) private var theme

    var body: some View {
        switch pointerEdge {
        case .bottom:
            VStack(spacing: 0) {
                card.frame(
                    height: DockHoverPanelPlacement.panelSize.height
                        - DockHoverPanelPlacement.pointerExtent
                )
                DockHoverPointerShape(direction: .down)
                    .fill(theme.opaqueSurfaceRaised)
                    .frame(
                        width: DockHoverPanelPlacement.pointerExtent * 2,
                        height: DockHoverPanelPlacement.pointerExtent
                    )
            }
        case .left:
            HStack(spacing: 0) {
                DockHoverPointerShape(direction: .left)
                    .fill(theme.opaqueSurfaceRaised)
                    .frame(
                        width: DockHoverPanelPlacement.pointerExtent,
                        height: DockHoverPanelPlacement.pointerExtent * 2
                    )
                card.frame(
                    width: DockHoverPanelPlacement.panelSize.width
                        - DockHoverPanelPlacement.pointerExtent
                )
            }
        case .right:
            HStack(spacing: 0) {
                card.frame(
                    width: DockHoverPanelPlacement.panelSize.width
                        - DockHoverPanelPlacement.pointerExtent
                )
                DockHoverPointerShape(direction: .right)
                    .fill(theme.opaqueSurfaceRaised)
                    .frame(
                        width: DockHoverPanelPlacement.pointerExtent,
                        height: DockHoverPanelPlacement.pointerExtent * 2
                    )
            }
        }
    }

    private var card: some View {
        content()
            .padding(12)
            .dsSurface(
                RoundedRectangle(cornerRadius: 18, style: .continuous),
                kind: .raised,
                elevation: .primary
            )
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
            month: 7,
            day: 26
        ))!
        let values: [Int64] = [
            640_000, 820_000, 510_000, 940_000, 1_080_000,
            760_000, 420_000, 1_120_000, 890_000, 1_340_000,
            980_000, 670_000, 1_460_000, 1_150_000, 720_000,
            1_280_000, 860_000, 1_020_000, 590_000, 1_390_000,
            930_000, 1_180_000, 780_000, 980_000, 1_320_000,
            1_560_000, 1_210_000, 1_010_000, 730_000, 1_280_000
        ]
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
                    day: 28,
                    hour: 9,
                    minute: 15
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
