import SwiftUI

@MainActor
struct ClaudeCodeHoverDashboardView: View {

    private enum UsageMetric: String, CaseIterable {
        case tokens = "Tokens"
        case cost = "Cost"
    }

    let state: ClaudeCodeUsageState
    let brand: StreakServiceBrand
    private let providerID = "claudeCode"
    private var usageAccent: Color { ProjectTheme.claudeCodeUsage }
    let serviceStatus: ServiceStatusState
    var now: Date = .now
    let streakCelebrationAutoDismissDelay: Duration
    let onStreakCelebrationDismissed: (String) -> Void
    let captureConfiguration: CodexDashboardCaptureConfiguration?
    let isActivityHookInstalled: Bool
    let isInstallingActivityHook: Bool
    let activityHookErrorText: String?
    let onInstallActivityHook: @MainActor () -> Void

    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isDashboardCapture) private var isDashboardCapture
    @State private var selectedMetric = UsageMetric.tokens
    @State private var isStreakDetailPresented: Bool
    @State private var streakCelebration: TokenUsageStreakCelebration?
    @State private var isCaptureMenuPresented: Bool
    @State private var captureErrorText: String?
    @State private var pendingShareURL: URL?

    init(
        state: ClaudeCodeUsageState,
        brand: StreakServiceBrand = .claudeCode,
        serviceStatus: ServiceStatusState = .operational(
            provider: .claudeCode
        ),
        now: Date = .now,
        initialMetric: String = "Tokens",
        initialStreakDetailPresented: Bool = false,
        initialStreakCelebration: TokenUsageStreakCelebration? = nil,
        streakCelebrationAutoDismissDelay: Duration = .milliseconds(2_800),
        onStreakCelebrationDismissed: @escaping (String) -> Void = { _ in },
        captureConfiguration: CodexDashboardCaptureConfiguration? = nil,
        initialCaptureMenuPresented: Bool = false,
        isActivityHookInstalled: Bool = true,
        isInstallingActivityHook: Bool = false,
        activityHookErrorText: String? = nil,
        onInstallActivityHook: @escaping @MainActor () -> Void = {}
    ) {
        self.state = state
        self.brand = brand
        self.serviceStatus = serviceStatus
        self.now = now
        self.streakCelebrationAutoDismissDelay =
            streakCelebrationAutoDismissDelay
        self.onStreakCelebrationDismissed = onStreakCelebrationDismissed
        self.captureConfiguration = captureConfiguration
        self.isActivityHookInstalled = isActivityHookInstalled
        self.isInstallingActivityHook = isInstallingActivityHook
        self.activityHookErrorText = activityHookErrorText
        self.onInstallActivityHook = onInstallActivityHook
        _selectedMetric = State(
            initialValue: UsageMetric(rawValue: initialMetric) ?? .tokens
        )
        _isStreakDetailPresented = State(
            initialValue: initialStreakDetailPresented
        )
        _streakCelebration = State(initialValue: initialStreakCelebration)
        _isCaptureMenuPresented = State(
            initialValue: initialCaptureMenuPresented
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let streakCelebration {
                StreakCelebrationView(
                    celebration: streakCelebration,
                    brand: brand,
                    accent: usageAccent,
                    planLabel: snapshot?.planType,
                    trailingMetricValue: snapshot?.tokenUsage == nil
                        ? nil
                        : ClaudeCodeHoverDashboardPresentation.tokenLabel(
                            totalTokens30Days
                        ),
                    trailingMetricLabel: snapshot?.tokenUsage == nil
                        ? nil
                        : "30d tokens",
                    onViewBadges: { dismissStreakCelebration(openBadges: true) }
                )
                .id(streakCelebration.id)
                .transition(streakCelebrationTransition)
            } else if isStreakDetailPresented {
                StreakDetailView(
                    summary: streakSummary,
                    brand: brand,
                    onBack: { setStreakDetailPresented(false) }
                )
                .transition(.opacity)
            } else {
                overview.transition(.opacity)
            }

            if streakCelebration == nil,
               !isStreakDetailPresented,
               isCaptureMenuPresented,
               captureConfiguration != nil {
                captureMenu
                    .padding(.top, 29)
                    .zIndex(2)
                    .transition(
                        .opacity.combined(
                            with: .scale(
                                scale: 0.96,
                                anchor: .topTrailing
                            )
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(alignment: .topTrailing) {
            if captureConfiguration != nil {
                DashboardSharePresenter(itemURL: $pendingShareURL)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
            }
        }
        .dsOverlayInteraction(isPresented: isCaptureMenuPresented || isStreakDetailPresented)
        .onExitCommand {
            if streakCelebration != nil {
                dismissStreakCelebration(openBadges: false)
            } else if isStreakDetailPresented {
                setStreakDetailPresented(false)
            } else if isCaptureMenuPresented {
                setCaptureMenuPresented(false)
            }
        }
        .task(id: streakCelebration?.id) {
            guard streakCelebration != nil else { return }
            do {
                try await Task.sleep(for: streakCelebrationAutoDismissDelay)
                try Task.checkCancellation()
                dismissStreakCelebration(openBadges: false)
            } catch {
                return
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            streakCelebration != nil
                ? "\(brand.displayName) streak celebration"
                : isStreakDetailPresented
                ? "\(brand.displayName) streak details"
                : "\(brand.displayName) usage dashboard"
        )
        .accessibilityIdentifier("dockHover.\(providerID)")
    }

    private var overview: some View {
        Group {
            if isDashboardCapture {
                overviewContent
            } else {
                ScrollView(.vertical) {
                    overviewContent
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var overviewContent: some View {
        VStack(spacing: 6) {
            Group {
                header
                quotaRows
                usageCard
                    .layoutPriority(1)
                StreakContinuityStrip(
                    summary: streakSummary,
                    brand: brand,
                    accent: usageAccent,
                    onOpen: { setStreakDetailPresented(true) }
                )
                shipMomentumCard
                usageInsights
                activeWorkCard
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                PreservedVectorAssetImage(assetName: brand.logoAssetName)
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .accessibilityHidden(true)

                Text(brand.displayName)
                    .dsFont(size: 17, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                if let plan = snapshot?.planType, !plan.isEmpty {
                    DSPlanBadge(plan: plan, providerName: brand.displayName)
                }

                if let statusTitle, let statusSystemImage {
                    HStack(spacing: 3) {
                        DSIcon(systemName: statusSystemImage)
                            .symbolRenderingMode(.monochrome)
                            .dsFont(size: 9, weight: .semibold)
                            .accessibilityHidden(true)

                        Text(statusTitle)
                            .dsFont(size: 10, weight: .semibold)
                    }
                    .foregroundStyle(statusForeground)
                    .accessibilityElement(children: .combine)
                }

                Spacer(minLength: 4)

                if captureConfiguration != nil {
                    captureButton
                }
            }
            .frame(height: 30)

            ServiceStatusHeaderView(state: serviceStatus)
        }
    }

    private var captureButton: some View {
        DSExportButton(isPresented: isCaptureMenuPresented, identifier: "\(providerID).capture" + ".button") {
            captureErrorText = nil
            setCaptureMenuPresented(!isCaptureMenuPresented)
        }
    }

    private var captureMenu: some View {
        DSExportActions(identifier: "\(providerID).capture",
            pixelSizeLabel: CodexDashboardCaptureService.activityCardPixelSizeLabel,
            error: captureErrorText, pointerTrailing: 7,
            save: saveDashboard, copy: copyDashboard, share: shareDashboard)
    }

    private func setCaptureMenuPresented(_ isPresented: Bool) {
        if !isPresented {
        }

        if reduceMotion {
            isCaptureMenuPresented = isPresented
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                isCaptureMenuPresented = isPresented
            }
        }
    }

    private func makeCaptureArtifact() -> CodexDashboardCaptureArtifact? {
        guard let captureConfiguration else { return nil }
        do {
            captureErrorText = nil
            return try CodexDashboardCaptureService.renderActivityCard(
                state: state,
                brand: brand,
                appearanceMode: captureConfiguration.appearanceMode,
                now: now
            )
        } catch {
            captureErrorText = error.localizedDescription
            setCaptureMenuPresented(true)
            return nil
        }
    }

    private func saveDashboard() {
        guard let artifact = makeCaptureArtifact() else { return }
        setCaptureMenuPresented(false)
        CodexDashboardCaptureService.presentSavePanel(for: artifact) { error in
            guard let error else { return }
            captureErrorText = error.localizedDescription
            setCaptureMenuPresented(true)
        }
    }

    private func copyDashboard() {
        guard let artifact = makeCaptureArtifact() else { return }
        do {
            try CodexDashboardCaptureService.copy(artifact)
            setCaptureMenuPresented(false)
        } catch {
            captureErrorText = error.localizedDescription
            setCaptureMenuPresented(true)
        }
    }

    private func shareDashboard() {
        guard let artifact = makeCaptureArtifact() else { return }
        do {
            pendingShareURL = try CodexDashboardCaptureService
                .temporaryShareURL(for: artifact)
            setCaptureMenuPresented(false)
        } catch {
            captureErrorText = error.localizedDescription
            setCaptureMenuPresented(true)
        }
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
                remainingFraction: window.remainingFraction,
                resetLabel: CodexHoverDashboardPresentation.resetLabel(
                    for: window
                ),
                usageAccent: usageAccent
            )
        } else {
            ClaudeCodeUnavailableLimitRow(
                title: title,
                systemImage: systemImage
            )
        }
    }

    private var usageCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Daily usage")
                    .dsFont(size: 11, weight: .bold)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                metricSelector
                    .fixedSize()
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    usageRange
                    Spacer(minLength: 8)
                    todayUsage
                }
                VStack(alignment: .leading, spacing: 4) {
                    usageRange
                    todayUsage
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            ProviderDailyUsageBars(
                buckets: visibleChartBuckets,
                metric: selectedMetric.rawValue,
                accent: usageAccent,
                providerID: providerID,
                hasData: selectedMetric == .tokens
                    ? snapshot?.tokenUsage != nil
                    : !dailyCosts.isEmpty
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private var usageRange: some View {
        Text(usageRangeLabel)
            .dsFont(size: 8.5, weight: .medium)
            .foregroundStyle(theme.textTertiary)
            .fixedSize()
    }

    private var todayUsage: some View {
        Text(todayUsageLabel)
            .dsFont(size: 13, weight: .bold)
            .foregroundStyle(theme.textPrimary)
            .monospacedDigit()
            .fixedSize()
    }

    private var metricSelector: some View {
        DSSegmentedControl(title: "Usage metric", selection: $selectedMetric,
            options: UsageMetric.allCases.map {
                .init(value: $0, title: $0.rawValue,
                      accessibilityIdentifier: "dockHover.\(providerID).metric.\($0.rawValue.lowercased())")
            }, size: .small)
            .frame(width: 150)
    }

    private var shipMomentumCard: some View {
        CodexShipMomentumCard(
            momentum: shipMomentum,
            accent: usageAccent
        )
    }

    private var dailyIntensityCard: some View {
        AIUsageDailyIntensityCard(
            buckets: intensityBuckets,
            accent: usageAccent
        )
        .accessibilityIdentifier("dockHover.\(providerID).dailyIntensity")
    }

    private var usageInsights: some View {
        HStack(spacing: 7) {
            dailyIntensityCard
            CodexTopModelsCard(
                models: compactTopModels,
                isPartial: snapshot?.tokenUsage?.isModelUsagePartial == true,
                accent: usageAccent,
                providerName: brand.displayName
            )
        }
        .frame(height: 90)
    }

    private var activeWorkCard: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Active work")
                    .dsFont(size: 10.5, weight: .bold)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 4)
                if isActivityHookInstalled,
                   visibleActiveTasks.count + activeGoals.count > 0 {
                    Text(
                        "\(visibleActiveTasks.count) active · \(activeGoals.count) "
                            + (activeGoals.count == 1 ? "goal" : "goals")
                    )
                        .dsFont(size: 8, weight: .medium)
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
            }

            if !isActivityHookInstalled {
                activityHookSetup
            } else if let task = visibleActiveTasks.first {
                workRow(
                    systemImage: "bolt.horizontal.circle",
                    title: task.name,
                    detail: taskDetail(task),
                    state: task.state.rawValue,
                    foreground: taskForeground(task.state)
                )
            }

            if isActivityHookInstalled, let goal = activeGoals.first {
                workRow(
                    systemImage: "scope",
                    title: goal.objective,
                    detail: goalDetail(goal),
                    state: goal.state.rawValue,
                    foreground: goalForeground(goal.state)
                )
            }

            if isActivityHookInstalled,
               visibleActiveTasks.isEmpty,
               activeGoals.isEmpty {
                unavailableRow(
                    systemImage: "circle.dashed",
                    text: "No active \(brand.displayName) work observed"
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(providerID).activeWork")
    }

    private var activityHookSetup: some View {
        VStack(spacing: 6) {
            Text("Connect \(brand.displayName) events to see sessions and tools here in realtime.")
                .dsFont(size: 8.5, weight: .medium)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onInstallActivityHook) {
                HStack(spacing: 6) {
                    if isInstallingActivityHook {
                        ProgressView()
                            .controlSize(.small)
                            .tint(theme.onAction)
                    }
                    Text(
                        isInstallingActivityHook
                            ? "Connecting…"
                            : "Enable realtime tracking"
                    )
                }
            }
            .buttonStyle(DSButtonStyle(emphasis: .primary))
            .disabled(isInstallingActivityHook)
            .accessibilityHint(
                "Adds DockMagic event hooks while preserving existing hooks"
            )
            .accessibilityIdentifier("\(providerID).activeWork.install")

            if let activityHookErrorText {
                Text(activityHookErrorText)
                    .dsFont(size: 8, weight: .medium)
                    .foregroundStyle(theme.dangerForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("\(providerID).activeWork.error")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func workRow(
        systemImage: String,
        title: String,
        detail: String,
        state: String,
        foreground: Color
    ) -> some View {
        HStack(spacing: 7) {
            DSIcon(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 11, weight: .semibold)
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
                    .dsFont(size: 9, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .dsFont(size: 8, weight: .medium)
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(state.replacingOccurrences(of: "_", with: " ").capitalized)
                .dsFont(size: 7.5, weight: .bold)
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
            DSIcon(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 9, weight: .semibold)
                .accessibilityHidden(true)
            Text(text)
                .dsFont(size: 8.5, weight: .medium)
                .lineLimit(2)
        }
        .foregroundStyle(theme.textTertiary)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var snapshot: ClaudeCodeRateLimitSnapshot? { state.snapshot }
    private var streakSummary: TokenUsageStreakSummary? {
        snapshot?.streakSummary
    }
    private var telemetry: ClaudeCodeTelemetrySnapshot? {
        snapshot?.claudeTelemetry
    }
    private var activeTasks: [ClaudeCodeActiveTask] {
        telemetry?.activeTasks ?? []
    }
    private var visibleActiveTasks: [ClaudeCodeActiveTask] {
        activeTasks
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
    private var compactTopModels: [CodexModelTokenUsage] {
        topModels.map {
            CodexModelTokenUsage(
                model: ClaudeCodeHoverDashboardPresentation.modelLabel($0.model),
                tokens: $0.tokens
            )
        }
    }
    private var totalTokens30Days: Int64 {
        snapshot?.tokenUsage?.dailyUsageBuckets.reduce(0) {
            $0 + $1.tokens
        } ?? 0
    }
    private var shipMomentum: CodexShipMomentum? {
        CodexHoverDashboardPresentation.shipMomentum(
            in: snapshot,
            now: now
        )
    }
    private var intensityBuckets: [CodexTokenUsageDailyBucket] {
        CodexHoverDashboardPresentation.chartBuckets(
            from: snapshot?.tokenUsage,
            now: now
        )
    }

    private var visibleChartBuckets: [ProviderDailyUsageChartBucket] {
        ClaudeCodeHoverDashboardPresentation.chartBuckets(
            tokenUsage: snapshot?.tokenUsage,
            dailyCosts: dailyCosts,
            metric: selectedMetric.rawValue,
            now: now
        )
    }

    private var usageRangeLabel: String {
        guard let start = visibleChartBuckets.first?.startDate,
              let end = visibleChartBuckets.last?.startDate else {
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

    private func window(
        for kind: ClaudeCodeRateLimitWindowKind
    ) -> ClaudeCodeRateLimitWindow? {
        switch kind {
        case .fiveHour: return snapshot?.fiveHour
        case .weekly: return snapshot?.weekly
        }
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
        case .live, .stale: return nil
        case .unavailable: return "Unavailable"
        }
    }

    private var statusSystemImage: String? {
        switch state {
        case .idle: return "minus.circle"
        case .loading: return "ellipsis.circle"
        case .live, .stale: return nil
        case .unavailable: return "xmark.circle"
        }
    }

    private var statusForeground: Color {
        switch state {
        case .loading: return theme.processingForeground
        case .unavailable: return theme.dangerForeground
        case .idle, .live, .stale: return theme.textTertiary
        }
    }

    private var streakCelebrationTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.985))
    }

    private func dismissStreakCelebration(openBadges: Bool) {
        guard let celebration = streakCelebration else { return }
        let update = {
            streakCelebration = nil
            if openBadges {
                isCaptureMenuPresented = false
                isStreakDetailPresented = true
            }
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.22), update)
        }
        onStreakCelebrationDismissed(celebration.id)
    }

    private func setStreakDetailPresented(_ isPresented: Bool) {
        if isPresented, isCaptureMenuPresented {
            setCaptureMenuPresented(false)
        }
        if reduceMotion {
            isStreakDetailPresented = isPresented
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                isStreakDetailPresented = isPresented
            }
        }
    }
}

enum ClaudeCodeHoverDashboardPresentation {
    static let maximumChartDays = 30

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
    ) -> [ProviderDailyUsageChartBucket] {
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
        return (0..<maximumChartDays).compactMap { offset in
            guard let date = calendar.date(
                byAdding: .day,
                value: offset - (maximumChartDays - 1),
                to: today
            ) else { return nil }
            if metric == "Cost" {
                let cost = costsByDay[date] ?? 0
                return ProviderDailyUsageChartBucket(
                    startDate: date,
                    value: cost,
                    accessibilityValue: "\(costLabel(cost)) observed estimated cost"
                )
            }
            let tokens = tokensByDay[date] ?? 0
            return ProviderDailyUsageChartBucket(
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
            DSIcon(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 10, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 15)
                .accessibilityHidden(true)

            Text(title)
                .dsFont(size: 10.5, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .frame(width: 50, alignment: .leading)

            Text("—")
                .dsFont(size: 11.5, weight: .bold)
                .foregroundStyle(theme.textTertiary)
                .frame(width: 67, alignment: .center)

            Capsule().fill(theme.dockTrack).frame(height: 6)

            Text("Not reported")
                .dsFont(size: 9, weight: .medium)
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
                longestRunningTurnSeconds: nil,
                dailyUsageBuckets: daily,
                modelUsage: [
                    CodexModelTokenUsage(model: "claude-sonnet-5", tokens: 4_200_000),
                    CodexModelTokenUsage(model: "claude-opus-5", tokens: 2_700_000),
                    CodexModelTokenUsage(model: "claude-haiku-4-5", tokens: 1_300_000)
                ],
                isModelUsagePartial: true
            ),
            streakSummary: TokenUsageStreakSummary.fixture(
                currentDays: 8,
                bestDays: 12,
                endingAt: now,
                calendar: calendar
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
