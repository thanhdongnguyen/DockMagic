import SwiftUI

@MainActor
struct ClaudeCodeHoverDashboardView: View {
    private enum UsageMetric: String, CaseIterable {
        case tokens = "Tokens"
        case cost = "Cost"
    }

    let state: ClaudeCodeUsageState
    var now: Date = .now

    @Environment(\.designTheme) private var theme
    @State private var selectedMetric = UsageMetric.tokens

    init(
        state: ClaudeCodeUsageState,
        now: Date = .now,
        initialMetric: String = "Tokens"
    ) {
        self.state = state
        self.now = now
        _selectedMetric = State(
            initialValue: UsageMetric(rawValue: initialMetric) ?? .tokens
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            quotaRows
            usageCard
            shipMomentumSection
            modelsCard
            activeWorkCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Claude Code usage dashboard")
        .accessibilityIdentifier("dockHover.claudeCode")
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image("ClaudeCodeLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("Claude Code")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    if let statusTitle, let statusSystemImage {
                        Image(systemName: statusSystemImage)
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(statusForeground)
                            .accessibilityLabel(statusTitle)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 7.5, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(sessionSubtitle)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 5)

            headerMetric(
                value: snapshot?.tokenUsage == nil
                    ? "—"
                    : ClaudeCodeHoverDashboardPresentation.tokenLabel(
                        totalTokens30Days
                    ),
                label: "30d tokens"
            )

            Rectangle()
                .fill(theme.outline)
                .frame(width: 0.5, height: 28)
                .accessibilityHidden(true)

            headerMetric(
                value: observedCost.map(
                    ClaudeCodeHoverDashboardPresentation.costLabel
                ) ?? "—",
                label: "observed est."
            )
        }
        .frame(height: 42)
    }

    private func headerMetric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var quotaRows: some View {
        VStack(spacing: 6) {
            quotaRow(kind: .fiveHour, title: "5-hour", systemImage: "clock")
            quotaRow(kind: .weekly, title: "Weekly", systemImage: "calendar")
        }
    }

    @ViewBuilder
    private func quotaRow(
        kind: ClaudeCodeRateLimitWindowKind,
        title: String,
        systemImage: String
    ) -> some View {
        if let window = window(for: kind) {
            UsageLimitHoverRow(
                title: title,
                systemImage: systemImage,
                window: window,
                resetLabel: CodexHoverDashboardPresentation.resetLabel(
                    for: window
                ),
                usageAccent: ProjectTheme.claudeCodeUsage
            )
        } else {
            ClaudeCodeUnavailableLimitRow(
                title: title,
                systemImage: systemImage
            )
        }
    }

    private var usageCard: some View {
        VStack(spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Daily usage")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Text(usageRangeLabel)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer(minLength: 5)
                metricSelector
            }

            Text(todayUsageLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            ClaudeCodeUsageBars(
                buckets: visibleChartBuckets,
                metric: selectedMetric.rawValue,
                hasData: selectedMetric == .tokens
                    ? snapshot?.tokenUsage != nil
                    : !dailyCosts.isEmpty
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 190)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private var metricSelector: some View {
        HStack(spacing: 2) {
            ForEach(UsageMetric.allCases, id: \.self) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    Text(metric.rawValue)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(
                            selectedMetric == metric
                                ? theme.textPrimary
                                : theme.textTertiary
                        )
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background {
                            if selectedMetric == metric {
                                Capsule().fill(theme.opaqueSurfaceRaised)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "dockHover.claudeCode.metric.\(metric.rawValue.lowercased())"
                )
                .accessibilityAddTraits(
                    selectedMetric == metric ? .isSelected : []
                )
            }
        }
        .padding(2)
        .background(Capsule().fill(theme.dockTrack))
        .overlay {
            Capsule().strokeBorder(theme.outline, lineWidth: 0.5)
        }
    }

    private var shipMomentumSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Ship momentum")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let shipMomentum {
                HStack(spacing: 13) {
                    ClaudeCodeShipMomentumGauge(score: shipMomentum.score)
                        .frame(width: 138)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(shipMomentum.rank.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ProjectTheme.claudeCodeUsage)

                        HStack(spacing: 13) {
                            momentumMetric(
                                value: "\(shipMomentum.currentTasks)"
                                    + (shipMomentum.isTaskCountPartial ? "+" : ""),
                                label: "tasks"
                            )

                            Rectangle()
                                .fill(theme.outline)
                                .frame(width: 0.5, height: 25)
                                .accessibilityHidden(true)

                            momentumMetric(
                                value: ClaudeCodeHoverDashboardPresentation
                                    .tokenLabel(shipMomentum.currentTokens),
                                label: "tokens"
                            )
                        }

                        Text("Local · 7d vs prior 7d")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            } else {
                unavailableRow(
                    systemImage: "gauge.with.dots.needle.0percent",
                    text: "Not enough recent task and token activity"
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
        }
        .help(
            "Ship momentum compares the latest 7 calendar days with the prior "
                + "7. It is an activity trend, not a productivity rating."
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ship momentum")
        .accessibilityValue(shipMomentumAccessibilityValue)
    }

    private func momentumMetric(value: String, label: String) -> some View {
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

    private var shipMomentumAccessibilityValue: String {
        guard let shipMomentum else {
            return "Not enough task and token activity data."
        }
        let partial = shipMomentum.isTaskCountPartial ? "at least " : ""
        return "\(shipMomentum.score) out of 100, rank "
            + "\(shipMomentum.rank.title). Latest 7 days: \(partial)"
            + "\(shipMomentum.currentTasks) tasks and "
            + "\(shipMomentum.currentTokens.formatted()) tokens."
    }

    private var modelsCard: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Top models")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 4)
                Text("Tokens")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 45, alignment: .trailing)
                Text("Est. USD")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 48, alignment: .trailing)
            }

            if topModels.isEmpty {
                unavailableRow(
                    systemImage: "chart.bar",
                    text: "No real model usage observed in the last 30 days"
                )
            } else {
                VStack(spacing: 5) {
                    ForEach(Array(topModels.enumerated()), id: \.element.id) {
                        entry in
                        modelRow(index: entry.offset, model: entry.element)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 118)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private func modelRow(
        index: Int,
        model: CodexModelTokenUsage
    ) -> some View {
        let maximum = max(topModels.map(\.tokens).max() ?? 1, 1)
        let cost = modelCost(for: model.model)
        return HStack(spacing: 7) {
            Text("\(index + 1)")
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(width: 10, alignment: .leading)

            Text(ClaudeCodeHoverDashboardPresentation.modelLabel(model.model))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .frame(width: 105, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.dockTrack)
                    Capsule()
                        .fill(ProjectTheme.claudeCodeUsage)
                        .frame(
                            width: max(
                                3,
                                proxy.size.width
                                    * CGFloat(model.tokens)
                                    / CGFloat(maximum)
                            )
                        )
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)

            Text(ClaudeCodeHoverDashboardPresentation.tokenLabel(model.tokens))
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .frame(width: 45, alignment: .trailing)

            Text(cost.map(ClaudeCodeHoverDashboardPresentation.costLabel) ?? "—")
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: 23)
        .overlay(alignment: .bottom) {
            if index < topModels.count - 1 {
                Rectangle()
                    .fill(theme.outline)
                    .frame(height: 0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.model)
        .accessibilityValue(
            "\(model.tokens.formatted()) tokens"
                + (cost.map {
                    ", \(ClaudeCodeHoverDashboardPresentation.costLabel($0)) observed estimated cost"
                } ?? "")
        )
    }

    private var activeWorkCard: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Active work")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 4)
                if activeTasks.count + activeGoals.count > 0 {
                    Text(
                        "\(activeTasks.count) running · \(activeGoals.count) "
                            + (activeGoals.count == 1 ? "goal" : "goals")
                    )
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
            }

            if let task = activeTasks.first {
                workRow(
                    systemImage: "bolt.horizontal.circle",
                    title: task.name,
                    detail: taskDetail(task),
                    state: task.state.rawValue,
                    foreground: taskForeground(task.state)
                )
            }

            if let goal = activeGoals.first {
                workRow(
                    systemImage: "scope",
                    title: goal.objective,
                    detail: goalDetail(goal),
                    state: goal.state.rawValue,
                    foreground: goalForeground(goal.state)
                )
            }

            if activeTasks.isEmpty && activeGoals.isEmpty {
                unavailableRow(
                    systemImage: "circle.dashed",
                    text: "No active Claude tasks or goals observed"
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 126)
        .accessibilityElement(children: .contain)
    }

    private func workRow(
        systemImage: String,
        title: String,
        detail: String,
        state: String,
        foreground: Color
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 27, height: 27)
                .background(theme.opaqueSurfaceInset)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(theme.outlineStrong, lineWidth: 0.5)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(state.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(state). \(detail)")
    }

    private func unavailableRow(
        systemImage: String,
        text: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 9, weight: .semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 8.5, weight: .medium))
                .lineLimit(2)
        }
        .foregroundStyle(theme.textTertiary)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var snapshot: ClaudeCodeRateLimitSnapshot? { state.snapshot }
    private var telemetry: ClaudeCodeTelemetrySnapshot? {
        snapshot?.claudeTelemetry
    }
    private var activeTasks: [ClaudeCodeActiveTask] {
        telemetry?.activeTasks ?? []
    }
    private var activeGoals: [ClaudeCodeActiveGoal] {
        telemetry?.activeGoals.filter { $0.state != .complete } ?? []
    }
    private var dailyCosts: [ClaudeCodeDailyCostUsage] {
        telemetry?.dailyCosts ?? []
    }
    private var topModels: [CodexModelTokenUsage] {
        CodexHoverDashboardPresentation.topModels(from: snapshot?.tokenUsage)
    }
    private var totalTokens30Days: Int64 {
        snapshot?.tokenUsage?.dailyUsageBuckets.reduce(0) {
            $0 + $1.tokens
        } ?? 0
    }
    private var observedCost: Double? {
        guard !dailyCosts.isEmpty else { return nil }
        return dailyCosts.reduce(0) { $0 + $1.estimatedCostUSD }
    }
    private var shipMomentum: CodexShipMomentum? {
        CodexHoverDashboardPresentation.shipMomentum(in: snapshot)
    }

    private var visibleChartBuckets: [ClaudeCodeUsageChartBucket] {
        ClaudeCodeHoverDashboardPresentation.chartBuckets(
            tokenUsage: snapshot?.tokenUsage,
            dailyCosts: dailyCosts,
            metric: selectedMetric.rawValue,
            now: now
        )
    }

    private var usageRangeLabel: String {
        let dates = snapshot?.tokenUsage?.dailyUsageBuckets.map(\.startDate) ?? []
        guard let start = dates.min(), let end = dates.max() else {
            return "Last 30 days"
        }
        return ClaudeCodeHoverDashboardPresentation.dateRangeLabel(
            from: start,
            through: end
        )
    }

    private var todayUsageLabel: String {
        switch selectedMetric {
        case .tokens:
            guard snapshot?.tokenUsage != nil,
                  let value = visibleChartBuckets.last?.value else {
                return "— today"
            }
            return "\(ClaudeCodeHoverDashboardPresentation.tokenLabel(Int64(value))) today"
        case .cost:
            guard !dailyCosts.isEmpty,
                  let value = visibleChartBuckets.last?.value else {
                return "— today"
            }
            return "\(ClaudeCodeHoverDashboardPresentation.costLabel(value)) today"
        }
    }

    private var sessionSubtitle: String {
        guard telemetry != nil else { return "Local bridge" }
        let session = telemetry?.currentSession
        let model = session?.modelDisplayName ?? session?.modelID
        let context = session?.context?.usedPercent.map {
            "\(Int($0.rounded()))% context"
        }
        return [model, context, "Local observed"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func window(
        for kind: ClaudeCodeRateLimitWindowKind
    ) -> ClaudeCodeRateLimitWindow? {
        switch kind {
        case .fiveHour: return snapshot?.fiveHour
        case .weekly: return snapshot?.weekly
        }
    }

    private func modelCost(for model: String) -> Double? {
        let normalized = model.lowercased()
        return telemetry?.modelCosts.first {
            let candidate = $0.model.lowercased()
            return candidate == normalized
                || candidate.contains(normalized)
                || normalized.contains(candidate)
        }?.estimatedCostUSD
    }

    private func taskDetail(_ task: ClaudeCodeActiveTask) -> String {
        let tokens = task.tokenCount.map {
            ClaudeCodeHoverDashboardPresentation.tokenLabel($0) + " tokens"
        }
        return [task.kind, tokens, task.lastToolName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func goalDetail(_ goal: ClaudeCodeActiveGoal) -> String {
        let iterations = goal.iterations.map { "\($0) iterations" }
        let budget: String?
        if let used = goal.tokensUsed, let total = goal.tokenBudget {
            budget = "\(ClaudeCodeHoverDashboardPresentation.tokenLabel(used))/\(ClaudeCodeHoverDashboardPresentation.tokenLabel(total)) tokens"
        } else {
            budget = nil
        }
        return [iterations, budget, goal.lastReason]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func taskForeground(_ state: ClaudeCodeTaskState) -> Color {
        switch state {
        case .running: return theme.processingForeground
        case .paused: return theme.warningForeground
        case .failed, .stopped: return theme.dangerForeground
        case .pending, .completed, .unknown: return theme.textSecondary
        }
    }

    private func goalForeground(_ state: ClaudeCodeGoalState) -> Color {
        switch state {
        case .active: return theme.processingForeground
        case .paused, .limited: return theme.warningForeground
        case .blocked: return theme.dangerForeground
        case .complete: return theme.textSecondary
        }
    }

    private var statusTitle: String? {
        switch state {
        case .idle: return "Waiting"
        case .loading: return "Loading"
        case .live: return nil
        case .stale: return "Stale"
        case .unavailable: return "Unavailable"
        }
    }

    private var statusSystemImage: String? {
        switch state {
        case .idle: return "minus.circle"
        case .loading: return "ellipsis.circle"
        case .live: return nil
        case .stale: return "exclamationmark.triangle"
        case .unavailable: return "xmark.circle"
        }
    }

    private var statusForeground: Color {
        switch state {
        case .loading: return theme.processingForeground
        case .stale: return theme.warningForeground
        case .unavailable: return theme.dangerForeground
        case .idle, .live: return theme.textTertiary
        }
    }
}

private struct ClaudeCodeShipMomentumGauge: View {
    let score: Int

    @Environment(\.designTheme) private var theme

    private var fraction: Double {
        Double(min(max(score, 0), 100)) / 100
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ClaudeCodeGaugeArcShape(fraction: 1)
                .stroke(
                    theme.dockTrack,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            ClaudeCodeGaugeArcShape(fraction: fraction)
                .stroke(
                    ProjectTheme.claudeCodeUsage,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            ClaudeCodeGaugeNeedleShape(fraction: fraction)
                .stroke(
                    theme.textPrimary,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

            Circle()
                .fill(theme.textPrimary)
                .frame(width: 5, height: 5)

            Text("\(score)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .padding(.horizontal, 4)
                .background(theme.opaqueSurfaceRaised)
                .offset(y: 2)
        }
        .frame(width: 136, height: 64)
        .accessibilityHidden(true)
    }
}

private struct ClaudeCodeGaugeArcShape: Shape {
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

private struct ClaudeCodeGaugeNeedleShape: Shape {
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

struct ClaudeCodeUsageChartBucket: Identifiable, Equatable, Sendable {
    let startDate: Date
    let value: Double
    let accessibilityValue: String

    var id: Date { startDate }
}

private struct ClaudeCodeUsageBars: View {
    let buckets: [ClaudeCodeUsageChartBucket]
    let metric: String
    let hasData: Bool

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(axisLabel(axisMaximum))
                    Spacer(minLength: 0)
                    Text(axisLabel(axisMaximum / 2))
                    Spacer(minLength: 0)
                    Text("0")
                }
                .font(.system(size: 7, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(width: 31, height: 100)

                GeometryReader { proxy in
                    if hasData {
                        ZStack {
                            VStack(spacing: 0) {
                                Rectangle().fill(theme.outline).frame(height: 0.5)
                                Spacer(minLength: 0)
                                Rectangle().fill(theme.outline).frame(height: 0.5)
                                Spacer(minLength: 0)
                                Rectangle().fill(theme.outline).frame(height: 0.5)
                            }

                            HStack(alignment: .bottom, spacing: 7) {
                                ForEach(buckets) { bucket in
                                    bar(bucket, height: proxy.size.height)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.xaxis")
                                .symbolRenderingMode(.monochrome)
                                .accessibilityHidden(true)
                            Text("Waiting for real \(metric.lowercased()) data")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 100)
            }

            HStack(spacing: 6) {
                Color.clear
                    .frame(width: 31, height: 1)
                    .accessibilityHidden(true)

                HStack(spacing: 7) {
                    ForEach(buckets) { bucket in
                        VStack(spacing: 1) {
                            Text(Self.weekdayLabel(bucket.startDate))
                            Text(Self.dayLabel(bucket.startDate))
                        }
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seven day \(metric.lowercased()) chart")
    }

    private func bar(
        _ bucket: ClaudeCodeUsageChartBucket,
        height: CGFloat
    ) -> some View {
        let maximum = max(buckets.map(\.value).max() ?? 0, 1)
        let fraction = min(max(bucket.value / maximum, 0), 1)
        return VStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    bucket.value > 0
                        ? ProjectTheme.claudeCodeUsage
                        : theme.dockTrack
                )
                .frame(height: bucket.value > 0 ? max(4, height * fraction) : 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.fullDateLabel(bucket.startDate))
        .accessibilityValue(bucket.accessibilityValue)
    }

    private var axisMaximum: Double {
        max(buckets.map(\.value).max() ?? 0, 1)
    }

    private func axisLabel(_ value: Double) -> String {
        if metric == "Cost" {
            return ClaudeCodeHoverDashboardPresentation.costLabel(value)
        }
        return ClaudeCodeHoverDashboardPresentation.tokenLabel(Int64(value))
    }

    private static func weekdayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private static func fullDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

enum ClaudeCodeHoverDashboardPresentation {
    struct Reset: Equatable {
        let title: String
        let date: Date
    }

    static func chartBuckets(
        tokenUsage: CodexAccountTokenUsage?,
        dailyCosts: [ClaudeCodeDailyCostUsage],
        metric: String,
        now: Date,
        calendar inputCalendar: Calendar = .current
    ) -> [ClaudeCodeUsageChartBucket] {
        var calendar = inputCalendar
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: now)
        let tokensByDay = (tokenUsage?.dailyUsageBuckets ?? []).reduce(
            into: [Date: Int64]()
        ) { result, bucket in
            result[calendar.startOfDay(for: bucket.startDate), default: 0]
                += bucket.tokens
        }
        let costsByDay = dailyCosts.reduce(into: [Date: Double]()) {
            result, bucket in
            result[calendar.startOfDay(for: bucket.startDate), default: 0]
                += bucket.estimatedCostUSD
        }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(
                byAdding: .day,
                value: offset - 6,
                to: today
            ) else { return nil }
            if metric == "Cost" {
                let cost = costsByDay[date] ?? 0
                return ClaudeCodeUsageChartBucket(
                    startDate: date,
                    value: cost,
                    accessibilityValue: "\(costLabel(cost)) observed estimated cost"
                )
            }
            let tokens = tokensByDay[date] ?? 0
            return ClaudeCodeUsageChartBucket(
                startDate: date,
                value: Double(tokens),
                accessibilityValue: "\(tokens.formatted()) tokens"
            )
        }
    }

    static func nextReset(
        in snapshot: ClaudeCodeRateLimitSnapshot?,
        now: Date = .now
    ) -> Reset? {
        let resets = [
            snapshot?.fiveHour?.resetsAt.map {
                Reset(title: "5-hour", date: $0)
            },
            snapshot?.weekly?.resetsAt.map {
                Reset(title: "Weekly", date: $0)
            }
        ].compactMap { $0 }
        return resets.filter { $0.date > now }.min { $0.date < $1.date }
    }

    static func ageLabel(since date: Date, now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 { return "Just now" }
        if elapsed < 3_600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86_400 {
            let hours = Int(elapsed / 3_600)
            let minutes = Int(elapsed.truncatingRemainder(dividingBy: 3_600) / 60)
            return minutes == 0 ? "\(hours)h ago" : "\(hours)h \(minutes)m ago"
        }
        return "\(Int(elapsed / 86_400))d ago"
    }

    static func countdownLabel(until date: Date, now: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return "Time passed" }
        if remaining < 60 { return "<1m" }
        if remaining < 3_600 { return "\(Int(remaining / 60))m" }
        if remaining < 86_400 {
            let hours = Int(remaining / 3_600)
            let minutes = Int(
                remaining.truncatingRemainder(dividingBy: 3_600) / 60
            )
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        let days = Int(remaining / 86_400)
        let hours = Int(
            remaining.truncatingRemainder(dividingBy: 86_400) / 3_600
        )
        return hours == 0 ? "\(days)d" : "\(days)d \(hours)h"
    }

    static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    static func dateRangeLabel(from start: Date, through end: Date) -> String {
        let startFormatter = DateFormatter()
        startFormatter.calendar = Calendar(identifier: .gregorian)
        startFormatter.locale = Locale(identifier: "en_US_POSIX")
        startFormatter.timeZone = .current
        startFormatter.dateFormat = "MMM d"
        let endFormatter = DateFormatter()
        endFormatter.calendar = startFormatter.calendar
        endFormatter.locale = startFormatter.locale
        endFormatter.timeZone = startFormatter.timeZone
        endFormatter.dateFormat = "MMM d, yyyy"
        return "\(startFormatter.string(from: start))–"
            + endFormatter.string(from: end)
    }

    static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }

    static func costLabel(_ cost: Double) -> String {
        String(
            format: "$%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            cost
        )
    }

    static func modelLabel(_ model: String) -> String {
        var parts = model
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-latest", with: "")
            .split(separator: "-")
            .map(String.init)
        if parts.count >= 2,
           Int(parts[parts.count - 2]) != nil,
           Int(parts[parts.count - 1]) != nil {
            let version = parts.removeLast()
            parts[parts.count - 1] += ".\(version)"
        }
        return "Claude " + parts.map(\.capitalized).joined(separator: " ")
    }
}

private struct ClaudeCodeUnavailableLimitRow: View {
    let title: String
    let systemImage: String

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

            Text("—")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 67, alignment: .center)

            Capsule().fill(theme.dockTrack).frame(height: 6)

            Text("Not reported")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
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
        .accessibilityValue("Not reported by Claude Code")
    }
}

#if DEBUG
extension CodexRateLimitSnapshot {
    static func claudeCodeHoverDesignPreview(now: Date = .now) -> Self {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let daily = (0..<30).compactMap { offset -> CodexTokenUsageDailyBucket? in
            guard let date = calendar.date(
                byAdding: .day,
                value: offset - 29,
                to: today
            ) else { return nil }
            let priorWeek: [Int64] = [150_000, 140_000, 180_000, 160_000, 120_000, 170_000, 180_000]
            let currentWeek: [Int64] = [990_000, 700_000, 1_120_000, 1_280_000, 1_050_000, 680_000, 1_280_000]
            let tokens: Int64
            if offset >= 23 {
                tokens = currentWeek[offset - 23]
            } else if offset >= 16 {
                tokens = priorWeek[offset - 16]
            } else {
                tokens = 0
            }
            return CodexTokenUsageDailyBucket(
                startDate: date,
                tokens: tokens
            )
        }
        return Self(
            planType: nil,
            limitID: "claude-code-local",
            fiveHour: ClaudeCodeRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 26,
                windowDurationMinutes: 300,
                resetsAt: now.addingTimeInterval(2 * 3_600 + 18 * 60)
            ),
            weekly: ClaudeCodeRateLimitWindow(
                kind: .weekly,
                usedPercent: 59,
                windowDurationMinutes: 10_080,
                resetsAt: now.addingTimeInterval(4 * 86_400 + 7 * 3_600)
            ),
            tokenUsage: CodexAccountTokenUsage(
                lifetimeTokens: nil,
                peakDailyTokens: daily.map(\.tokens).max(),
                currentStreakDays: 8,
                longestStreakDays: 12,
                longestRunningTurnSeconds: nil,
                dailyUsageBuckets: daily,
                modelUsage: [
                    CodexModelTokenUsage(model: "claude-sonnet-5", tokens: 4_200_000),
                    CodexModelTokenUsage(model: "claude-opus-5", tokens: 2_700_000),
                    CodexModelTokenUsage(model: "claude-haiku-4-5", tokens: 1_300_000)
                ],
                isModelUsagePartial: true
            ),
            recentTaskActivity: CodexRecentTaskActivity(
                currentWeekCount: 12,
                previousWeekCount: 38,
                isPartial: true
            ),
            claudeTelemetry: ClaudeCodeTelemetrySnapshot(
                source: .statusLineAndLocalHistory,
                currentSession: ClaudeCodeSessionUsage(
                    sessionID: "preview-session",
                    sessionName: "Dashboard implementation",
                    modelID: "claude-sonnet-5",
                    modelDisplayName: "Sonnet 5",
                    agentName: nil,
                    claudeCodeVersion: "2.1.219",
                    estimatedCostUSD: 1.46,
                    totalDurationMilliseconds: 840_000,
                    totalAPIDurationMilliseconds: 230_000,
                    totalLinesAdded: 420,
                    totalLinesRemoved: 72,
                    context: ClaudeCodeContextUsage(
                        totalInputTokens: 220_000,
                        totalOutputTokens: 34_000,
                        contextWindowSize: 1_000_000,
                        usedPercent: 34,
                        remainingPercent: 66,
                        currentUsage: nil
                    ),
                    observedAt: now
                ),
                observedSessionCount: 7,
                dailyCosts: [4.81, 5.32, 6.14, 7.21, 5.42, 4.16, 5.36]
                    .enumerated().compactMap { entry in
                    calendar.date(byAdding: .day, value: entry.offset - 6, to: today)
                        .map {
                            ClaudeCodeDailyCostUsage(
                                startDate: $0,
                                estimatedCostUSD: entry.element
                            )
                        }
                },
                modelCosts: [
                    ClaudeCodeModelCostUsage(model: "claude-sonnet-5", estimatedCostUSD: 19.84),
                    ClaudeCodeModelCostUsage(model: "claude-opus-5", estimatedCostUSD: 13.02),
                    ClaudeCodeModelCostUsage(model: "claude-haiku-4-5", estimatedCostUSD: 5.56)
                ],
                activeTasks: [
                    ClaudeCodeActiveTask(
                        id: "task-1",
                        sessionID: "preview-session",
                        name: "Audit telemetry sources",
                        kind: "Explore",
                        state: .running,
                        description: nil,
                        label: nil,
                        startedAt: now.addingTimeInterval(-540),
                        tokenCount: 42_800,
                        lastToolName: nil,
                        observedAt: now
                    ),
                    ClaudeCodeActiveTask(
                        id: "task-2",
                        sessionID: "preview-session",
                        name: "Validate native bridge",
                        kind: "general-purpose",
                        state: .running,
                        description: nil,
                        label: nil,
                        startedAt: now.addingTimeInterval(-360),
                        tokenCount: 16_200,
                        lastToolName: "Bash",
                        observedAt: now
                    )
                ],
                activeGoals: [
                    ClaudeCodeActiveGoal(
                        sessionID: "preview-session",
                        objective: "Ship Claude dashboard",
                        state: .active,
                        iterations: 3,
                        lastReason: nil,
                        createdAt: now.addingTimeInterval(-3_600),
                        updatedAt: now,
                        tokenBudget: 120_000,
                        tokensUsed: 74_000,
                        timeUsedSeconds: 3_600
                    )
                ],
                historyIsPartial: true,
                costIsPartial: true
            ),
            fetchedAt: now.addingTimeInterval(-4 * 60)
        )
    }
}
#endif
