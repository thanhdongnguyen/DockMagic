import SwiftUI

@MainActor
struct AntigravityHoverDashboardView: View {

    let state: AntigravityUsageState
    let brand: StreakServiceBrand
    let now: Date
    let initialIntensityHoveredBucketID: Date?
    let streakCelebrationAutoDismissDelay: Duration
    let onStreakCelebrationDismissed: (String) -> Void
    let captureConfiguration: CodexDashboardCaptureConfiguration?

    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredBucketID: Date?
    @State private var isStreakDetailPresented: Bool
    @State private var streakCelebration: TokenUsageStreakCelebration?
    @State private var isCaptureMenuPresented: Bool
    @State private var captureErrorText: String?
    @State private var pendingShareURL: URL?

    init(
        state: AntigravityUsageState,
        brand: StreakServiceBrand = .antigravity,
        now: Date = .now,
        initialHoveredBucketID: Date? = nil,
        initialIntensityHoveredBucketID: Date? = nil,
        initialStreakDetailPresented: Bool = false,
        initialStreakCelebration: TokenUsageStreakCelebration? = nil,
        streakCelebrationAutoDismissDelay: Duration = .milliseconds(2_800),
        onStreakCelebrationDismissed: @escaping (String) -> Void = { _ in },
        captureConfiguration: CodexDashboardCaptureConfiguration? = nil,
        initialCaptureMenuPresented: Bool = false
    ) {
        self.state = state
        self.brand = brand
        self.now = now
        self.initialIntensityHoveredBucketID = initialIntensityHoveredBucketID
        self.streakCelebrationAutoDismissDelay =
            streakCelebrationAutoDismissDelay
        self.onStreakCelebrationDismissed = onStreakCelebrationDismissed
        self.captureConfiguration = captureConfiguration
        _hoveredBucketID = State(initialValue: initialHoveredBucketID)
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
                    accent: theme.action,
                    planLabel: snapshot?.planType,
                    trailingMetricValue: totalTokens30Days.map(Self.tokenLabel),
                    trailingMetricLabel: totalTokens30Days == nil
                        ? nil
                        : "observed 30d",
                    onViewBadges: {
                        dismissStreakCelebration(openBadges: true)
                    }
                )
                .id(streakCelebration.id)
                .transition(streakCelebrationTransition)
            } else if isStreakDetailPresented {
                StreakDetailView(
                    summary: streakSummary,
                    brand: brand,
                    unknownDayStyle: .dash,
                    onBack: { setStreakDetailPresented(false) }
                )
                .transition(.opacity)
            } else {
                overview.transition(.opacity)
            }

            if streakCelebration == nil,
               !isStreakDetailPresented,
               isCaptureMenuPresented,
               isExportAvailable {
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
                ? "Antigravity streak celebration"
                : isStreakDetailPresented
                ? "Antigravity streak details"
                : "Antigravity usage dashboard"
        )
        .accessibilityIdentifier("dockHover.antigravity")
    }

    private var overview: some View {
        ScrollView(.vertical) {
            overviewContent
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var overviewContent: some View {
        VStack(spacing: 6) {
            header
            if let message = stateMessage {
                stateBanner(message)
            }
            quotaRows
            tokenHeader
            tokenChart
            StreakContinuityStrip(
                summary: streakSummary,
                brand: brand,
                accent: theme.action,
                unknownDayStyle: .dash,
                onOpen: { setStreakDetailPresented(true) }
            )
            CodexShipMomentumCard(
                momentum: shipMomentum,
                accent: activityColor,
                accentForeground: activityForeground,
                isPartial: true,
                showsPartialIndicator: false
            )
            usageInsights
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var header: some View {
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

            if showsHeaderState {
                HStack(spacing: 3) {
                    DSIcon(systemName: stateSystemImage)
                        .symbolRenderingMode(.monochrome)
                        .dsFont(size: 9, weight: .semibold)
                        .accessibilityHidden(true)
                    Text(state.statusTitle)
                        .dsFont(size: 10, weight: .semibold)
                }
                .foregroundStyle(stateForeground)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 4)

            if isExportAvailable {
                captureButton
            }
        }
        .frame(height: 30)
    }

    private var captureButton: some View {
        DSExportButton(isPresented: isCaptureMenuPresented, identifier: "antigravity.capture" + ".button") {
            captureErrorText = nil
            setCaptureMenuPresented(!isCaptureMenuPresented)
        }
    }

    private var captureMenu: some View {
        DSExportActions(identifier: "antigravity.capture",
            pixelSizeLabel: CodexDashboardCaptureService.activityCardPixelSizeLabel,
            layoutCaption: "ACTIVITY LAYOUT",
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
            if isActivityCardExportAvailable {
                return try CodexDashboardCaptureService.renderActivityCard(
                    state: state,
                    appearanceMode: captureConfiguration.appearanceMode,
                    now: now
                )
            }
            return try CodexDashboardCaptureService.renderAntigravityAvailabilityCard(
                state: state,
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
            if let buckets = snapshot?.quota?.buckets, !buckets.isEmpty {
                ForEach(buckets) { bucket in
                    UsageLimitHoverRow(
                        title: Self.quotaTitle(bucket),
                        systemImage: bucket.windowDurationMinutes == 10_080
                            ? "calendar"
                            : "gauge.with.dots.needle.33percent",
                        remainingFraction: bucket.remainingFraction,
                        resetLabel: Self.resetLabel(bucket.resetsAt),
                        usageAccent: activityColor
                    )
                    .help(
                        [bucket.groupName, bucket.windowTitle]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")
                    )
                }
            } else {
                unavailableRow(
                    systemImage: "gauge.with.dots.needle.0percent",
                    text: "Run agy /usage to load structured model-pool quota."
                )
            }
        }
        .accessibilityIdentifier("dockHover.antigravity.quota")
    }

    private var tokenHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("Daily tokens · CLI observed")
                .dsFont(size: 12, weight: .bold)
                .foregroundStyle(theme.textPrimary)
                .help("Only Antigravity CLI sessions connected to DockMagic contribute token samples. Antigravity Desktop activity is not included.")

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
                    Text(hoveredTokenLabel)
                        .dsFont(size: 12, weight: .bold)
                        .foregroundStyle(activityColor)
                        .monospacedDigit()
                    Text("tokens")
                        .dsFont(size: 9, weight: .semibold)
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else if let todayObservedTokens {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Self.tokenLabel(todayObservedTokens))
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
        .accessibilityIdentifier("dockHover.antigravity.dailyTokensHeader")
    }

    @ViewBuilder
    private var tokenChart: some View {
        ZStack(alignment: .top) {
            AIUsageTokenHistoryChart(
                buckets: chartBuckets,
                hoveredBucketID: $hoveredBucketID,
                plotHeight: tokenChartPlotHeight,
                unavailableBucketIDs: unavailableDayIDs,
                isSelectionEnabled: false,
                dataColor: activityColor,
                onSelectBucket: { _ in }
            )

            if !hasTokenHistory {
                HStack(spacing: 6) {
                    DSIcon(systemName: "chart.bar")
                        .symbolRenderingMode(.monochrome)
                        .accessibilityHidden(true)
                    Text(tokenEmptyMessage)
                        .dsFont(size: 10, weight: .medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: tokenChartPlotHeight)
                .offset(x: 19)
                .allowsHitTesting(false)
            }
        }
        .accessibilityIdentifier("dockHover.antigravity.dailyTokens")
    }

    private var usageInsights: some View {
        HStack(spacing: 7) {
            AIUsageDailyIntensityCard(
                buckets: intensityBuckets,
                accent: activityColor,
                unavailableBucketIDs: unavailableDayIDs,
                isPartial: true,
                showsPartialIndicator: false,
                initialHoveredBucketID: initialIntensityHoveredBucketID
            )
            .accessibilityIdentifier("dockHover.antigravity.dailyIntensity")

            CodexTopModelsCard(
                models: topModels,
                isPartial: true,
                accent: activityColor,
                providerName: brand.displayName,
                showsPartialIndicator: false
            )
            .accessibilityIdentifier("dockHover.antigravity.topModels")
        }
        .frame(height: 90)
    }

    private func unavailableRow(
        systemImage: String,
        text: String
    ) -> some View {
        HStack(spacing: 7) {
            DSIcon(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 10, weight: .semibold)
                .accessibilityHidden(true)
            Text(text)
                .dsFont(size: 9, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(theme.textTertiary)
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private func stateBanner(_ message: String) -> some View {
        DSLabel(message, systemImage: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.monochrome)
            .dsFont(size: 9.5, weight: .semibold)
            .foregroundStyle(theme.warningForeground)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.warning.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var snapshot: AntigravityUsageSnapshot? { state.snapshot }
    private var tokenUsage: CodexAccountTokenUsage? { snapshot?.tokenUsage }
    private var activityColor: Color { theme.codexActivity }
    private var activityForeground: Color { theme.codexActivityForeground }
    private var streakSummary: TokenUsageStreakSummary? {
        snapshot?.streakSummary
    }
    private var isActivityCardExportAvailable: Bool {
        guard captureConfiguration != nil,
              (shipMomentum?.todayTokens ?? 0) > 0 else {
            return false
        }
        return true
    }

    private var isAvailabilityLayoutExportAvailable: Bool {
        !(snapshot?.quota?.buckets.isEmpty ?? true)
    }

    private var isExportAvailable: Bool {
        guard captureConfiguration != nil else { return false }
        return isActivityCardExportAvailable
            || isAvailabilityLayoutExportAvailable
    }

    private var dayObservations: [AntigravityDailyTokenObservation] {
        AntigravityHoverDashboardPresentation.dayObservations(
            from: tokenUsage,
            now: now
        )
    }

    private var chartBuckets: [CodexTokenUsageDailyBucket] {
        dayObservations.map {
            CodexTokenUsageDailyBucket(
                startDate: $0.startDate,
                tokens: $0.tokens ?? 0
            )
        }
    }

    private var intensityBuckets: [CodexTokenUsageDailyBucket] { chartBuckets }

    private var unavailableDayIDs: Set<Date> {
        Set(dayObservations.filter { $0.tokens == nil }.map(\.id))
    }

    private var topModels: [CodexModelTokenUsage] {
        CodexHoverDashboardPresentation.topModels(from: tokenUsage).map {
            CodexModelTokenUsage(
                model: Self.modelLabel($0.model),
                tokens: $0.tokens
            )
        }
    }

    private var todayObservedTokens: Int64? {
        AntigravityHoverDashboardPresentation.todayTokens(
            in: dayObservations,
            now: now
        )
    }

    private var shipMomentum: CodexShipMomentum? {
        AntigravityHoverDashboardPresentation.shipMomentum(
            from: dayObservations,
            now: now
        )
    }

    private var totalTokens30Days: Int64? {
        guard tokenUsage != nil else { return nil }
        return dayObservations.compactMap(\.tokens).reduce(0, Self.add)
    }

    private var hoveredBucket: CodexTokenUsageDailyBucket? {
        guard let hoveredBucketID else { return nil }
        return chartBuckets.first { $0.id == hoveredBucketID }
    }

    private var hoveredTokenLabel: String {
        guard let hoveredBucket else { return "—" }
        guard !unavailableDayIDs.contains(hoveredBucket.id) else { return "—" }
        return hoveredBucket.tokens.formatted()
    }

    private var hasTokenHistory: Bool {
        dayObservations.contains { ($0.tokens ?? 0) > 0 }
    }

    private var tokenChartPlotHeight: CGFloat {
        (snapshot?.quota?.buckets.count ?? 0) < 2 ? 84 : 46
    }

    private var tokenEmptyMessage: String {
        switch state {
        case .loading:
            "Waiting for connected CLI token samples…"
        case .idle, .live, .stale, .unavailable:
            "Desktop token usage is not included. This chart tracks connected CLI sessions."
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
        return "\(Self.monthLabel(first)) \(firstDay)–"
            + "\(Self.monthLabel(last)) \(lastDay), \(year)"
    }

    private var stateMessage: String? {
        switch state {
        case let .stale(_, message), let .unavailable(message): message
        case .idle, .loading, .live: nil
        }
    }

    private var stateForeground: Color {
        switch state {
        case .live: theme.informationForeground
        case .stale: theme.warningForeground
        case .unavailable: theme.dangerForeground
        case .idle, .loading: theme.textSecondary
        }
    }

    private var stateSystemImage: String {
        switch state {
        case .live: "checkmark.circle.fill"
        case .stale: "clock.badge.exclamationmark"
        case .unavailable: "exclamationmark.triangle.fill"
        case .loading: "arrow.trianglehead.2.clockwise.rotate.90"
        case .idle: "circle.dashed"
        }
    }

    private var showsHeaderState: Bool {
        if case .live = state { return false }
        return true
    }

    private var streakCelebrationTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.985))
    }

    private func setStreakDetailPresented(_ isPresented: Bool) {
        if reduceMotion {
            isStreakDetailPresented = isPresented
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                isStreakDetailPresented = isPresented
            }
        }
    }

    private func dismissStreakCelebration(openBadges: Bool) {
        guard let celebration = streakCelebration else { return }
        let update = {
            streakCelebration = nil
            if openBadges {
                isStreakDetailPresented = true
            }
        }
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeOut(duration: 0.16), update)
        }
        onStreakCelebrationDismissed(celebration.id)
    }

    private static func resetLabel(_ date: Date?) -> String {
        guard let date else { return "Reset —" }
        return "Resets " + date.formatted(
            .dateTime.month(.abbreviated).day().hour().minute()
        )
    }

    private static func quotaTitle(_ bucket: AntigravityQuotaBucket) -> String {
        let normalized = "\(bucket.id) \(bucket.groupName)".lowercased()
        if normalized.contains("gemini") { return "Gemini" }
        if normalized.contains("3p")
            || normalized.contains("claude")
            || normalized.contains("gpt") {
            return "Claude + GPT"
        }
        return bucket.groupName.nonEmpty ?? bucket.title
    }

    private static func tokenLabel(_ value: Int64) -> String {
        value.formatted(
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

    private static func modelLabel(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .localizedCapitalized
    }

    private static func add(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int64.max : result.partialValue
    }
}

struct AntigravityDailyTokenObservation: Equatable, Identifiable, Sendable {
    let startDate: Date
    let tokens: Int64?

    var id: Date { startDate }
}

enum AntigravityHoverDashboardPresentation {
    static let maximumChartDays = 30

    static func dayObservations(
        from tokenUsage: CodexAccountTokenUsage?,
        now: Date = .now,
        calendar inputCalendar: Calendar = .current
    ) -> [AntigravityDailyTokenObservation] {
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
            totalsByDay[day] = add(
                totalsByDay[day] ?? 0,
                max(0, bucket.tokens)
            )
        }

        return (0..<maximumChartDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay).map {
                AntigravityDailyTokenObservation(
                    startDate: $0,
                    tokens: totalsByDay[$0]
                )
            }
        }
    }

    static func todayTokens(
        in observations: [AntigravityDailyTokenObservation],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int64? {
        observations.first {
            calendar.isDate($0.startDate, inSameDayAs: now)
        }?.tokens
    }

    static func shipMomentum(
        from observations: [AntigravityDailyTokenObservation],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CodexShipMomentum? {
        guard let tokens = todayTokens(
            in: observations,
            now: now,
            calendar: calendar
        ) else { return nil }
        return CodexShipMomentum(
            score: CodexShipMomentum.score(forTodayTokens: tokens),
            todayTokens: tokens
        )
    }

    private static func add(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int64.max : result.partialValue
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
