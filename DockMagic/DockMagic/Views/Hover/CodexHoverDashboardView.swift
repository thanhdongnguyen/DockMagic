import AppKit
import SwiftUI

enum DockHoverPointerEdge: Sendable {
    case bottom
    case left
    case right
}

enum CodexDailyTokenDetailLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded(CodexDailyTokenDetail?)
    case failed(String)
}

@MainActor
struct CodexHoverDashboardView: View {

    let state: CodexUsageState
    let serviceStatus: ServiceStatusState?
    let brand: StreakServiceBrand
    let now: Date
    let dailyDetailLoader: (
        @MainActor @Sendable (Date) async throws -> CodexDailyTokenDetail?
    )?
    let initialIntensityHoveredBucketID: Date?
    let captureConfiguration: CodexDashboardCaptureConfiguration?
    let streakCelebrationAutoDismissDelay: Duration
    let onStreakCelebrationDismissed: (String) -> Void

    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredBucketID: Date?
    @State private var selectedDailyBucketID: Date?
    @State private var isStreakDetailPresented: Bool
    @State private var streakCelebration: TokenUsageStreakCelebration?
    @State private var dailyDetailLoadState: CodexDailyTokenDetailLoadState
    @State private var isCaptureMenuPresented: Bool
    @State private var captureErrorText: String?
    @State private var pendingShareURL: URL?

    init(
        state: CodexUsageState,
        serviceStatus: ServiceStatusState? = .operational(provider: .codex),
        brand: StreakServiceBrand = .codex,
        now: Date = .now,
        dailyDetailLoader: (
            @MainActor @Sendable (Date) async throws -> CodexDailyTokenDetail?
        )? = nil,
        initialHoveredBucketID: Date? = nil,
        initialSelectedDailyBucketID: Date? = nil,
        initialIntensityHoveredBucketID: Date? = nil,
        initialStreakDetailPresented: Bool = false,
        initialStreakCelebration: TokenUsageStreakCelebration? = nil,
        streakCelebrationAutoDismissDelay: Duration = .milliseconds(2_800),
        onStreakCelebrationDismissed: @escaping (String) -> Void = { _ in },
        captureConfiguration: CodexDashboardCaptureConfiguration? = nil,
        initialCaptureMenuPresented: Bool = false
    ) {
        self.state = state
        self.serviceStatus = serviceStatus
        self.brand = brand
        self.now = now
        self.dailyDetailLoader = dailyDetailLoader
        self.initialIntensityHoveredBucketID = initialIntensityHoveredBucketID
        self.captureConfiguration = captureConfiguration
        self.streakCelebrationAutoDismissDelay =
            streakCelebrationAutoDismissDelay
        self.onStreakCelebrationDismissed = onStreakCelebrationDismissed
        _hoveredBucketID = State(initialValue: initialHoveredBucketID)
        _selectedDailyBucketID = State(
            initialValue: initialSelectedDailyBucketID
        )
        _isStreakDetailPresented = State(
            initialValue: initialStreakDetailPresented
        )
        _streakCelebration = State(initialValue: initialStreakCelebration)
        _dailyDetailLoadState = State(initialValue: .idle)
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
                    accent: theme.action,
                    planLabel: snapshot?.planType,
                    trailingMetricValue: tokenUsage?.lifetimeTokens.map(
                        Self.tokenLabel
                    ),
                    trailingMetricLabel: tokenUsage?.lifetimeTokens == nil
                        ? nil
                        : "lifetime",
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
            } else if let selectedDailyBucket {
                CodexDailyTokenDetailView(
                    accountBucket: selectedDailyBucket,
                    detail: selectedDailyDetail,
                    loadState: effectiveDailyDetailLoadState,
                    providerName: brand.displayName,
                    dataColor: activityColor,
                    dataForeground: activityForeground,
                    onBack: { setSelectedDailyBucketID(nil) }
                )
                .id(selectedDailyBucket.id)
                .transition(.opacity)
            } else {
                overview
                    .transition(.opacity)
            }

            if streakCelebration == nil,
               !isStreakDetailPresented,
               selectedDailyBucket == nil,
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .topTrailing) {
            if captureConfiguration != nil {
                DashboardSharePresenter(itemURL: $pendingShareURL)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
            }
        }
        .dsOverlayInteraction(isPresented: isCaptureMenuPresented || isStreakDetailPresented || selectedDailyBucketID != nil)
        .onExitCommand {
            if streakCelebration != nil {
                dismissStreakCelebration(openBadges: false)
            } else if isStreakDetailPresented {
                setStreakDetailPresented(false)
            } else if isCaptureMenuPresented {
                setCaptureMenuPresented(false)
            } else if selectedDailyBucketID != nil {
                setSelectedDailyBucketID(nil)
            }
        }
        .task(id: selectedDailyBucket?.id) {
            await loadSelectedDailyDetail()
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
                : selectedDailyBucket == nil
                    ? "\(brand.displayName) usage dashboard"
                    : "\(brand.displayName) daily token detail"
        )
    }

    private var overview: some View {
        VStack(spacing: 6) {
            header
            quotaRows
            tokenHeader
            tokenChart
            StreakContinuityStrip(
                summary: streakSummary,
                brand: brand,
                accent: theme.action,
                onOpen: { setStreakDetailPresented(true) }
            )
            shipMomentumCard
            usageInsights
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                DSIdentityContainer(size: 26) {
                    PreservedVectorAssetImage(assetName: brand.logoAssetName)
                        .scaledToFill().frame(width: 42, height: 42)
                }

                Text(brand.displayName)
                    .dsFont(size: 17, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                if let plan = snapshot?.planType, !plan.isEmpty {
                    DSPlanBadge(
                        plan: plan,
                        providerName: brand.displayName
                    )
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

                if let lifetimeTokens = tokenUsage?.lifetimeTokens {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(Self.tokenLabel(lifetimeTokens))
                            .dsFont(size: 14, weight: .bold)
                            .foregroundStyle(theme.textPrimary)
                        Text("lifetime")
                            .dsFont(size: 10, weight: .medium)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .monospacedDigit()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Lifetime tokens")
                    .accessibilityValue(lifetimeTokens.formatted())
                }
            }
            .frame(height: 30)

            if let serviceStatus {
                ServiceStatusHeaderView(state: serviceStatus)
            }
        }
    }

    private var captureButton: some View {
        DSExportButton(isPresented: isCaptureMenuPresented, identifier: "codex.capture" + ".button") {
            captureErrorText = nil
            setCaptureMenuPresented(!isCaptureMenuPresented)
        }
    }

    private var captureMenu: some View {
        DSExportActions(identifier: "codex.capture",
            pixelSizeLabel: CodexDashboardCaptureService.activityCardPixelSizeLabel,
            error: captureErrorText, pointerTrailing: tokenUsage?.lifetimeTokens == nil ? 7 : 98,
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
            ForEach(quotaMetrics) { metric in
                UsageLimitHoverRow(
                    title: metric.title,
                    systemImage: metric.systemImage,
                    remainingFraction: metric.remainingFraction,
                    resetLabel: CodexHoverDashboardPresentation.resetLabel(
                        for: metric
                    ),
                    usageAccent: activityColor
                )
            }
        }
    }

    private var tokenHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("Daily tokens")
                .dsFont(size: 12, weight: .bold)
                .foregroundStyle(theme.textPrimary)

            if let dateRangeLabel {
                Text(dateRangeLabel)
                    .dsFont(size: 9, weight: .medium)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 4)

            if let hoveredBucket {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Self.hoverDateLabel(hoveredBucket.startDate))
                        .dsFont(size: 9, weight: .medium)
                        .foregroundStyle(theme.textSecondary)
                    Text(hoveredBucket.tokens.formatted())
                        .dsFont(size: 12, weight: .bold)
                        .foregroundStyle(activityColor)
                        .monospacedDigit()
                    Text("tokens")
                        .dsFont(size: 9, weight: .semibold)
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else if let todayTokens {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Self.tokenLabel(todayTokens))
                        .dsFont(size: 13, weight: .bold)
                        .foregroundStyle(activityColor)
                        .monospacedDigit()
                    Text("today")
                        .dsFont(size: 9, weight: .semibold)
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private var tokenChart: some View {
        ZStack(alignment: .top) {
            AIUsageTokenHistoryChart(
                buckets: chartBuckets,
                hoveredBucketID: $hoveredBucketID,
                plotHeight: tokenChartPlotHeight,
                dataColor: activityColor,
                onSelectBucket: setSelectedDailyBucketID
            )

            if !hasTokenHistory {
                HStack(spacing: 6) {
                    DSIcon(systemName: "chart.bar")
                        .symbolRenderingMode(.monochrome)
                        .accessibilityHidden(true)
                    Text(tokenEmptyMessage)
                        .dsFont(size: 10, weight: .medium)
                }
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: tokenChartPlotHeight)
                .offset(x: 19)
                .allowsHitTesting(false)
            }
        }
    }

    private var snapshot: CodexRateLimitSnapshot? { state.snapshot }
    private var tokenUsage: CodexAccountTokenUsage? { snapshot?.tokenUsage }
    private var streakSummary: TokenUsageStreakSummary? {
        snapshot?.streakSummary
    }

    private var shipMomentum: CodexShipMomentum? {
        CodexHoverDashboardPresentation.shipMomentum(in: snapshot, now: now)
    }

    private var quotaMetrics: [UsageQuotaMetric] {
        UsageQuotaPresentation.codex(
            snapshot,
            includesMissing: false
        )
    }

    private var chartBuckets: [CodexTokenUsageDailyBucket] {
        CodexHoverDashboardPresentation.chartBuckets(
            from: tokenUsage,
            now: now
        )
    }

    private var hasTokenHistory: Bool {
        chartBuckets.contains { $0.tokens > 0 }
    }

    private var todayTokens: Int64? {
        guard let tokenUsage else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let matchingBuckets = tokenUsage.dailyUsageBuckets.filter {
            calendar.isDate($0.startDate, inSameDayAs: now)
        }
        guard !matchingBuckets.isEmpty else { return nil }
        return matchingBuckets.reduce(Int64(0)) { $0 + $1.tokens }
    }

    private var hoveredBucket: CodexTokenUsageDailyBucket? {
        guard let hoveredBucketID else { return nil }
        return chartBuckets.first { $0.id == hoveredBucketID }
    }

    private var selectedDailyBucket: CodexTokenUsageDailyBucket? {
        guard let selectedDailyBucketID else { return nil }
        return chartBuckets.first {
            $0.id == selectedDailyBucketID && $0.tokens > 0
        }
    }

    private var embeddedSelectedDailyDetail: CodexDailyTokenDetail? {
        guard let selectedDailyBucket else { return nil }
        guard let detail = tokenUsage?.localDetail(
            for: selectedDailyBucket.startDate
        ), detail.usage.totalTokens == selectedDailyBucket.tokens else {
            return nil
        }
        return detail
    }

    private var selectedDailyDetail: CodexDailyTokenDetail? {
        guard let selectedDailyBucket else { return nil }
        if case let .loaded(detail) = dailyDetailLoadState,
           let detail,
           Calendar.current.isDate(
               detail.startDate,
               inSameDayAs: selectedDailyBucket.startDate
           ) {
            return detail
        }
        return embeddedSelectedDailyDetail
    }

    private var effectiveDailyDetailLoadState: CodexDailyTokenDetailLoadState {
        if selectedDailyDetail != nil {
            switch dailyDetailLoadState {
            case .idle, .loading:
                return .loaded(selectedDailyDetail)
            case .loaded, .failed:
                break
            }
        }
        return dailyDetailLoadState
    }

    private var tokenChartPlotHeight: CGFloat {
        quotaMetrics.count < 2 ? 84 : 46
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
                selectedDailyBucketID = nil
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
        if isPresented {
            selectedDailyBucketID = nil
            if isCaptureMenuPresented {
                setCaptureMenuPresented(false)
            }
        }

        if reduceMotion {
            isStreakDetailPresented = isPresented
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                isStreakDetailPresented = isPresented
            }
        }
    }

    private func setSelectedDailyBucketID(_ bucketID: Date?) {
        if let bucketID,
           (chartBuckets.first(where: { $0.id == bucketID })?.tokens ?? 0) <= 0 {
            return
        }
        hoveredBucketID = nil
        dailyDetailLoadState = bucketID == nil || dailyDetailLoader == nil
            ? .idle
            : .loading
        if bucketID != nil, isCaptureMenuPresented {
            setCaptureMenuPresented(false)
        }
        if reduceMotion {
            selectedDailyBucketID = bucketID
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                selectedDailyBucketID = bucketID
            }
        }
    }

    private func loadSelectedDailyDetail() async {
        guard let selectedDailyBucket else {
            dailyDetailLoadState = .idle
            return
        }
        guard let dailyDetailLoader else {
            dailyDetailLoadState = embeddedSelectedDailyDetail.map {
                .loaded($0)
            } ?? .loaded(nil)
            return
        }

        dailyDetailLoadState = .loading
        do {
            let detail = try await dailyDetailLoader(
                selectedDailyBucket.startDate
            )
            try Task.checkCancellation()
            dailyDetailLoadState = .loaded(detail)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            dailyDetailLoadState = .failed(error.localizedDescription)
        }
    }

    private var shipMomentumCard: some View {
        CodexShipMomentumCard(momentum: shipMomentum, accent: activityColor,
                              accentForeground: activityForeground)
    }

    private var activityColor: Color {
        brand == .codex ? theme.codexActivity : theme.action
    }

    private var activityForeground: Color {
        brand == .codex ? theme.codexActivityForeground : theme.textPrimary
    }

    private var usageInsights: some View {
        HStack(spacing: 7) {
            AIUsageDailyIntensityCard(
                buckets: chartBuckets,
                accent: activityColor,
                initialHoveredBucketID: initialIntensityHoveredBucketID
            )
            CodexTopModelsCard(
                models: CodexHoverDashboardPresentation.topModels(
                    from: tokenUsage
                ),
                isPartial: tokenUsage?.isModelUsagePartial == true,
                accent: activityColor,
                providerName: brand.displayName
            )
        }
        .frame(height: 90)
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
            "Loading token usage from \(brand.displayName)…"
        case let .unavailable(message), let .stale(_, message):
            message
        case .idle, .live:
            "Token history is not available from \(brand.displayName)."
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

        if calendar.isDate(first, inSameDayAs: last) {
            return "\(Self.monthLabel(last)) \(lastDay), \(year)"
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
    let todayTokens: Int64

    var rank: CodexShipRank {
        CodexShipRank.rank(for: score)
    }

    static func score(forTodayTokens rawTokens: Int64) -> Int {
        let tokens = max(0, rawTokens)
        switch tokens {
        case ..<10_000_000:
            return interpolatedScore(
                tokens: tokens,
                tokenFloor: 0,
                tokenCeiling: 10_000_000,
                scoreFloor: 0,
                scoreCeiling: 10
            )
        case ..<50_000_000:
            return interpolatedScore(
                tokens: tokens,
                tokenFloor: 10_000_000,
                tokenCeiling: 50_000_000,
                scoreFloor: 10,
                scoreCeiling: 30
            )
        case ..<200_000_000:
            return interpolatedScore(
                tokens: tokens,
                tokenFloor: 50_000_000,
                tokenCeiling: 200_000_000,
                scoreFloor: 30,
                scoreCeiling: 50
            )
        case ..<500_000_000:
            return interpolatedScore(
                tokens: tokens,
                tokenFloor: 200_000_000,
                tokenCeiling: 500_000_000,
                scoreFloor: 50,
                scoreCeiling: 70
            )
        case ...1_000_000_000:
            return min(
                89,
                interpolatedScore(
                    tokens: tokens,
                    tokenFloor: 500_000_000,
                    tokenCeiling: 1_000_000_000,
                    scoreFloor: 70,
                    scoreCeiling: 90
                )
            )
        default:
            return 100
        }
    }

    private static func interpolatedScore(
        tokens: Int64,
        tokenFloor: Int64,
        tokenCeiling: Int64,
        scoreFloor: Int,
        scoreCeiling: Int
    ) -> Int {
        let tokenProgress = max(0, tokens - tokenFloor)
        let tokenSpan = tokenCeiling - tokenFloor
        let scoreSpan = scoreCeiling - scoreFloor
        let scaledProgress = tokenProgress * Int64(scoreSpan) / tokenSpan
        return scoreFloor + Int(scaledProgress)
    }
}

enum CodexShipRank: Int, CaseIterable, Identifiable, Equatable, Sendable {
    case starter
    case builder
    case creator
    case shipper
    case shipmaster
    case legend

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .starter: "Starter"
        case .builder: "Builder"
        case .creator: "Creator"
        case .shipper: "Shipper"
        case .shipmaster: "Shipmaster"
        case .legend: "Legend"
        }
    }

    static func rank(for score: Int) -> CodexShipRank {
        switch min(max(score, 0), 100) {
        case ..<10: .starter
        case ..<30: .builder
        case ..<50: .creator
        case ..<70: .shipper
        case ..<90: .shipmaster
        default: .legend
        }
    }
}

enum CodexHoverDashboardPresentation {
    static let maximumChartDays = 30
    static let maximumVisibleModels = 3

    static func visibleQuotaWindows(
        in snapshot: CodexRateLimitSnapshot?
    ) -> [CodexRateLimitWindow] {
        [snapshot?.fiveHour, snapshot?.weekly].compactMap { $0 }
    }

    static func chartBuckets(
        from tokenUsage: CodexAccountTokenUsage?,
        now: Date = .now,
        calendar inputCalendar: Calendar = .current
    ) -> [CodexTokenUsageDailyBucket] {
        let calendar = inputCalendar
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(
            byAdding: .day,
            value: -(maximumChartDays - 1),
            to: today
        ), let dayAfterToday = calendar.date(
            byAdding: .day,
            value: 1,
            to: today
        ) else { return [] }

        var totalsByDay: [Date: Int64] = [:]
        for bucket in tokenUsage?.dailyUsageBuckets ?? [] {
            let day = calendar.startOfDay(for: bucket.startDate)
            guard day >= firstDay, day < dayAfterToday else { continue }
            let result = totalsByDay[day, default: 0]
                .addingReportingOverflow(max(0, bucket.tokens))
            totalsByDay[day] = result.overflow ? Int64.max : result.partialValue
        }

        return (0..<maximumChartDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay).map {
                CodexTokenUsageDailyBucket(
                    startDate: $0,
                    tokens: totalsByDay[$0, default: 0]
                )
            }
        }
    }

    static func topModels(
        from tokenUsage: CodexAccountTokenUsage?
    ) -> [CodexModelTokenUsage] {
        Array(
            (tokenUsage?.modelUsage ?? [])
                .sorted {
                    if $0.tokens != $1.tokens {
                        return $0.tokens > $1.tokens
                    }
                    return $0.model.localizedCaseInsensitiveCompare($1.model)
                        == .orderedAscending
                }
                .prefix(maximumVisibleModels)
        )
    }

    static func shipMomentum(
        in snapshot: CodexRateLimitSnapshot?,
        now: Date = .now
    ) -> CodexShipMomentum? {
        guard
            let snapshot,
            let tokenUsage = snapshot.tokenUsage
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: now)
        guard
            let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: today
            )
        else {
            return nil
        }

        let todayTokens = tokenUsage.dailyUsageBuckets
            .filter { $0.startDate >= today && $0.startDate < nextDay }
            .reduce(Int64(0)) { $0 + $1.tokens }

        return CodexShipMomentum(
            score: CodexShipMomentum.score(forTodayTokens: todayTokens),
            todayTokens: max(0, todayTokens)
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

    static func resetLabel(for metric: UsageQuotaMetric) -> String {
        guard let reset = metric.resetsAt else { return "Reset —" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, h:mm a"
        return "Resets \(formatter.string(from: reset))"
    }
}
