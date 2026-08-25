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
    let panelSize: CGSize
    var appearanceMode: DSAppearanceMode = .dark
    var initialHoveredBucketID: Date?

    init(
        appModel: DockAppModel,
        pointerEdge: DockHoverPointerEdge,
        panelSize: CGSize? = nil,
        appearanceMode: DSAppearanceMode = .dark,
        initialHoveredBucketID: Date? = nil
    ) {
        self.appModel = appModel
        self.pointerEdge = pointerEdge
        self.panelSize = panelSize
            ?? DockHoverPanelPlacement.panelSize(
                for: appModel.preferences.activeFeature
            )
        self.appearanceMode = appearanceMode
        self.initialHoveredBucketID = initialHoveredBucketID
    }

    var body: some View {
        DockMagicThemeRoot(
            content: DockHoverChrome(
                pointerEdge: pointerEdge,
                panelSize: panelSize
            ) {
                switch appModel.preferences.activeFeature {
                case .systemMetrics:
                    SystemMetricsHoverDashboardView(
                        current: appModel.metricsStore.current,
                        history: appModel.metricsStore.history,
                        processes: appModel.metricsStore.currentProcesses,
                        appearance: appModel.preferences.systemMetricsAppearance,
                        systemErrorDescription: appModel.metricsStore
                            .lastErrorDescription,
                        processErrorDescription: appModel.metricsStore
                            .lastProcessErrorDescription
                    )
                case .codex:
                    CodexHoverDashboardView(
                        state: appModel.codexStore.state,
                        initialHoveredBucketID: initialHoveredBucketID
                    )
                case .claudeCode:
                    ClaudeCodeHoverDashboardView(
                        state: appModel.claudeCodeStore.state
                    )
                default:
                    DockHoverFeatureSummaryView(
                        feature: appModel.preferences.activeFeature
                    )
                }
            },
            appearanceMode: appearanceMode
        )
        .frame(
            width: panelSize.width,
            height: panelSize.height
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
            shipMomentumCard
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
                UsageLimitHoverRow(
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

    private var shipMomentum: CodexShipMomentum? {
        CodexHoverDashboardPresentation.shipMomentum(in: snapshot)
    }

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

    private var shipMomentumCard: some View {
        CodexShipMomentumCard(momentum: shipMomentum)
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

struct CodexShipMomentum: Equatable, Sendable {
    let score: Int
    let currentTokens: Int64
    let previousTokens: Int64
    let currentTasks: Int
    let previousTasks: Int
    let isTaskCountPartial: Bool

    var rank: CodexShipRank {
        CodexShipRank.rank(for: score)
    }
}

enum CodexShipRank: Int, CaseIterable, Identifiable, Equatable, Sendable {
    case spark
    case builder
    case maker
    case shipper
    case accelerator
    case vanguard

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .spark: "Spark"
        case .builder: "Builder"
        case .maker: "Maker"
        case .shipper: "Shipper"
        case .accelerator: "Accelerator"
        case .vanguard: "Vanguard"
        }
    }

    static func rank(for score: Int) -> CodexShipRank {
        switch min(max(score, 0), 100) {
        case ..<10: .spark
        case ..<30: .builder
        case ..<50: .maker
        case ..<70: .shipper
        case ..<90: .accelerator
        default: .vanguard
        }
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

    static func shipMomentum(
        in snapshot: CodexRateLimitSnapshot?
    ) -> CodexShipMomentum? {
        guard
            let snapshot,
            let tokenUsage = snapshot.tokenUsage,
            let taskActivity = snapshot.recentTaskActivity
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: snapshot.fetchedAt)
        guard
            let currentStart = calendar.date(
                byAdding: .day,
                value: -6,
                to: today
            ),
            let previousStart = calendar.date(
                byAdding: .day,
                value: -13,
                to: today
            ),
            let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: today
            )
        else {
            return nil
        }

        let currentTokens = tokenUsage.dailyUsageBuckets
            .filter { $0.startDate >= currentStart && $0.startDate < nextDay }
            .reduce(Int64(0)) { $0 + $1.tokens }
        let previousTokens = tokenUsage.dailyUsageBuckets
            .filter {
                $0.startDate >= previousStart && $0.startDate < currentStart
            }
            .reduce(Int64(0)) { $0 + $1.tokens }
        guard
            currentTokens + previousTokens > 0,
            taskActivity.currentWeekCount + taskActivity.previousWeekCount > 0
        else {
            return nil
        }

        let tokenShare = comparisonShare(
            current: Double(currentTokens),
            previous: Double(previousTokens)
        )
        let taskShare = comparisonShare(
            current: Double(taskActivity.currentWeekCount),
            previous: Double(taskActivity.previousWeekCount)
        )
        let score = Int(
            ((tokenShare + taskShare) * 50).rounded()
        )

        return CodexShipMomentum(
            score: min(max(score, 0), 100),
            currentTokens: currentTokens,
            previousTokens: previousTokens,
            currentTasks: taskActivity.currentWeekCount,
            previousTasks: taskActivity.previousWeekCount,
            isTaskCountPartial: taskActivity.isPartial
        )
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

    private static func comparisonShare(
        current: Double,
        previous: Double
    ) -> Double {
        let total = max(0, current) + max(0, previous)
        guard total > 0 else { return 0 }
        return max(0, current) / total
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

struct CodexShipMomentumCard: View {
    let momentum: CodexShipMomentum?

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ship momentum")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    CodexShipMomentumGauge(score: momentum?.score)
                }
                .frame(width: 136, alignment: .leading)

                Rectangle()
                    .fill(theme.outline)
                    .frame(width: 0.5, height: 68)
                    .accessibilityHidden(true)

                CodexShipRankLadder(activeRank: momentum?.rank)
            }

            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            if let momentum {
                HStack(spacing: 34) {
                    metric(
                        value: taskLabel(momentum),
                        label: "tasks"
                    )
                    metric(
                        value: Self.tokenLabel(momentum.currentTokens),
                        label: "tokens"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                unavailableDetails
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ship momentum")
        .accessibilityValue(accessibilityValue)
    }

    private var unavailableDetails: some View {
        Text("Not enough recent task and token activity")
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func metric(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func taskLabel(_ momentum: CodexShipMomentum) -> String {
        "\(momentum.currentTasks)\(momentum.isTaskCountPartial ? "+" : "")"
    }

    private var helpText: String {
        "Ship momentum compares the latest 7 calendar days with the prior 7. "
            + "The ladder progresses from Spark to Vanguard. It is an activity "
            + "trend, not a productivity rating."
    }

    private var accessibilityValue: String {
        guard let momentum else {
            return "Not enough task and token activity data."
        }
        let partial = momentum.isTaskCountPartial ? "at least " : ""
        return "\(momentum.score) out of 100, rank \(momentum.rank.title), "
            + "\(momentum.rank.rawValue + 1) of \(CodexShipRank.allCases.count). "
            + "Latest 7 days: \(partial)\(momentum.currentTasks) tasks and "
            + "\(momentum.currentTokens.formatted()) tokens."
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

private struct CodexShipMomentumGauge: View {
    let score: Int?

    @Environment(\.designTheme) private var theme

    private var fraction: Double {
        Double(min(max(score ?? 0, 0), 100)) / 100
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CodexGaugeArcShape(fraction: 1)
                .stroke(
                    theme.dockTrack,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            if score != nil {
                CodexGaugeArcShape(fraction: fraction)
                    .stroke(
                        theme.action,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )

                CodexGaugeNeedleShape(fraction: fraction)
                    .stroke(
                        theme.textPrimary,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )

                Circle()
                    .fill(theme.textPrimary)
                    .frame(width: 5, height: 5)
            }

            Text(score.map(String.init) ?? "—")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            .padding(.horizontal, 3)
            .background(theme.opaqueSurfaceInset)
            .offset(y: 2)
        }
        .frame(width: 132, height: 56)
        .accessibilityHidden(true)
    }
}

private struct CodexShipRankLadder: View {
    let activeRank: CodexShipRank?

    @Environment(\.designTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let columnWidth = max(
                0,
                (proxy.size.width
                    - spacing * CGFloat(CodexShipRank.allCases.count - 1))
                    / CGFloat(CodexShipRank.allCases.count)
            )

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(CodexShipRank.allCases) { rank in
                    VStack(spacing: 3) {
                        ZStack {
                            CodexRankStepShape()
                                .fill(stepFill(for: rank))
                            CodexRankStepShape()
                                .stroke(
                                    stepOutline(for: rank),
                                    lineWidth: rank == activeRank ? 1 : 0.5
                                )

                            Text("\(rank.rawValue + 1)")
                                .font(.system(
                                    size: 9,
                                    weight: .bold,
                                    design: .rounded
                                ))
                                .foregroundStyle(stepNumber(for: rank))
                                .monospacedDigit()
                        }
                        .frame(
                            width: columnWidth,
                            height: 23 + CGFloat(rank.rawValue * 3)
                        )

                        Text(rank.title)
                            .font(.system(
                                size: 7,
                                weight: rank == activeRank ? .bold : .medium
                            ))
                            .foregroundStyle(
                                rank == activeRank
                                    ? theme.action
                                    : theme.textSecondary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: columnWidth)
                    }
                    .frame(width: columnWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 61)
        .accessibilityHidden(true)
    }

    private func stepFill(for rank: CodexShipRank) -> Color {
        if rank == activeRank {
            return theme.action
        }
        if let activeRank, rank.rawValue < activeRank.rawValue {
            return theme.outlineStrong
        }
        return theme.dockTrack
    }

    private func stepOutline(for rank: CodexShipRank) -> Color {
        rank == activeRank ? theme.action : theme.outline
    }

    private func stepNumber(for rank: CodexShipRank) -> Color {
        rank == activeRank ? theme.onAction : theme.textPrimary
    }
}

private struct CodexRankStepShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(6, rect.width * 0.2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CodexGaugeArcShape: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.maxY - 3)
        let radius = min(rect.width / 2 - 7, rect.height - 7)
        let segments = max(1, Int(48 * clamped))
        var path = Path()

        for step in 0...segments {
            let progress = clamped * Double(step) / Double(segments)
            let angle = Double.pi * (1 - progress)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y - CGFloat(sin(angle)) * radius
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct CodexGaugeNeedleShape: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.maxY - 3)
        let radius = min(rect.width / 2 - 17, rect.height - 17)
        let angle = Double.pi * (1 - clamped)
        let endpoint = CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y - CGFloat(sin(angle)) * radius
        )
        var path = Path()
        path.move(to: center)
        path.addLine(to: endpoint)
        return path
    }
}

struct UsageLimitHoverRow: View {
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
    let panelSize: CGSize
    @ViewBuilder let content: () -> Content

    @Environment(\.designTheme) private var theme

    var body: some View {
        switch pointerEdge {
        case .bottom:
            VStack(spacing: 0) {
                card.frame(
                    height: panelSize.height
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
                    width: panelSize.width
                        - DockHoverPanelPlacement.pointerExtent
                )
            }
        case .right:
            HStack(spacing: 0) {
                card.frame(
                    width: panelSize.width
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
            recentTaskActivity: CodexRecentTaskActivity(
                currentWeekCount: 12,
                previousWeekCount: 8,
                isPartial: false
            ),
            fetchedAt: calendar.date(from: DateComponents(
                year: 2026,
                month: 8,
                day: 25,
                hour: 12
            ))!
        )
    }
}
#endif
