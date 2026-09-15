import SwiftUI

@MainActor
struct AntigravityHoverDashboardView: View {
    private enum CaptureAction {
        case save
        case copy
        case share
    }

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
    @State private var isCaptureButtonHovered = false
    @State private var isCaptureMenuPresented: Bool
    @State private var hoveredCaptureAction: CaptureAction?
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
                    onBack: { setStreakDetailPresented(false) }
                )
                .transition(.opacity)
            } else {
                overview.transition(.opacity)
            }

            if streakCelebration == nil,
               !isStreakDetailPresented,
               isCaptureMenuPresented,
               isActivityCardExportAvailable {
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
                CodexDashboardSharePresenter(itemURL: $pendingShareURL)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
            }
        }
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
                onOpen: { setStreakDetailPresented(true) }
            )
            CodexShipMomentumCard(
                momentum: shipMomentum,
                accent: theme.action,
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
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let plan = snapshot?.planType, !plan.isEmpty {
                CodexPlanBadge(plan: plan, providerName: brand.displayName)
            }

            if showsHeaderState {
                HStack(spacing: 3) {
                    Image(systemName: stateSystemImage)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(state.statusTitle)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(stateForeground)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 4)

            if isActivityCardExportAvailable {
                captureButton
            }
        }
        .frame(height: 30)
    }

    private var captureButton: some View {
        Button {
            captureErrorText = nil
            setCaptureMenuPresented(!isCaptureMenuPresented)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.opaqueSurfaceInset)
                        .opacity(
                            isCaptureButtonHovered || isCaptureMenuPresented
                                ? 1
                                : 0
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isCaptureMenuPresented
                                ? theme.outlineStrong
                                : theme.outline,
                            lineWidth: isCaptureMenuPresented ? 1 : 0.5
                        )
                        .opacity(
                            isCaptureButtonHovered || isCaptureMenuPresented
                                ? 1
                                : 0
                        )
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering in
            isCaptureButtonHovered = isHovering
        }
        .help("Export activity card")
        .accessibilityLabel("Export activity card")
        .accessibilityHint("Opens 1200 by 1200 PNG export options")
        .accessibilityIdentifier("antigravity.capture.button")
    }

    private var captureMenu: some View {
        VStack(alignment: .trailing, spacing: 0) {
            DockHoverPointerShape(direction: .up)
                .fill(theme.opaqueSurfaceRaised)
                .overlay {
                    DockHoverPointerShape(direction: .up)
                        .stroke(theme.outline, lineWidth: 0.75)
                }
                .frame(width: 12, height: 7)
                .padding(.trailing, 7)

            VStack(spacing: 1) {
                captureMenuRow(
                    captureAction: .save,
                    title: "Save 4× PNG",
                    subtitle: CodexDashboardCaptureService
                        .activityCardPixelSizeLabel,
                    systemImage: "photo",
                    accessibilityHint:
                        "Opens a save panel for the high-resolution PNG",
                    action: saveDashboard
                )
                captureMenuRow(
                    captureAction: .copy,
                    title: "Copy image",
                    systemImage: "doc.on.doc",
                    action: copyDashboard
                )
                captureMenuRow(
                    captureAction: .share,
                    title: "Share…",
                    systemImage: "square.and.arrow.up",
                    action: shareDashboard
                )

                if let captureErrorText {
                    Text(captureErrorText)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.dangerForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("antigravity.capture.error")
                }
            }
            .padding(4)
            .frame(width: 146)
            .dsSurface(
                RoundedRectangle(cornerRadius: 10, style: .continuous),
                kind: .raised,
                elevation: .secondary
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity card export options")
        .accessibilityIdentifier("antigravity.capture.menu")
    }

    private func captureMenuRow(
        captureAction: CaptureAction,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        accessibilityHint: String? = nil,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        let isActive = activeCaptureAction == captureAction

        return Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(
                        .system(
                            size: 11,
                            weight: isActive ? .bold : .medium
                        )
                    )
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(
                            .system(
                                size: 11,
                                weight: isActive ? .bold : .medium
                            )
                        )

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 8.5, weight: .medium))
                            .opacity(0.82)
                    }
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(
                isActive ? theme.textPrimary : theme.textSecondary
            )
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 26 : 36)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.outlineStrong.opacity(0.18))
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 7,
                                style: .continuous
                            )
                            .strokeBorder(theme.outlineStrong, lineWidth: 1)
                        }
                }
            }
            .contentShape(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                hoveredCaptureAction = captureAction
            } else if hoveredCaptureAction == captureAction {
                hoveredCaptureAction = nil
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityHint(accessibilityHint ?? "")
    }

    private var activeCaptureAction: CaptureAction {
        hoveredCaptureAction ?? .save
    }

    private func setCaptureMenuPresented(_ isPresented: Bool) {
        if !isPresented {
            hoveredCaptureAction = nil
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
                        usageAccent: theme.action
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
                    Text(hoveredTokenLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text("tokens")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else if let todayObservedTokens {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(Self.tokenLabel(todayObservedTokens))
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
        .accessibilityIdentifier("dockHover.antigravity.dailyTokensHeader")
    }

    @ViewBuilder
    private var tokenChart: some View {
        ZStack(alignment: .top) {
            CodexTokenHistoryChart(
                buckets: chartBuckets,
                hoveredBucketID: $hoveredBucketID,
                plotHeight: tokenChartPlotHeight,
                unavailableBucketIDs: unavailableDayIDs,
                isSelectionEnabled: false,
                onSelectBucket: { _ in }
            )

            if !hasTokenHistory {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar")
                        .symbolRenderingMode(.monochrome)
                        .accessibilityHidden(true)
                    Text(tokenEmptyMessage)
                        .font(.system(size: 10, weight: .medium))
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
            CodexDailyIntensityCard(
                buckets: intensityBuckets,
                accent: theme.action,
                unavailableBucketIDs: unavailableDayIDs,
                isPartial: true,
                showsPartialIndicator: false,
                initialHoveredBucketID: initialIntensityHoveredBucketID
            )
            .accessibilityIdentifier("dockHover.antigravity.dailyIntensity")

            CodexTopModelsCard(
                models: topModels,
                isPartial: true,
                accent: theme.action,
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
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 10, weight: .semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 9, weight: .medium))
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
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(theme.warningForeground)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.warning.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var snapshot: AntigravityUsageSnapshot? { state.snapshot }
    private var tokenUsage: CodexAccountTokenUsage? { snapshot?.tokenUsage }
    private var streakSummary: TokenUsageStreakSummary? {
        snapshot?.streakSummary
    }
    private var isActivityCardExportAvailable: Bool {
        guard captureConfiguration != nil, shipMomentum != nil else {
            return false
        }
        let samples = CodexDashboardCaptureService.activityCardChartSamples(
            from: tokenUsage,
            now: now
        )
        return CodexDashboardCaptureService.activityCardChartHasRenderableTrend(
            samples
        )
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
            "Loading token usage from \(brand.displayName)…"
        case let .unavailable(message), let .stale(_, message):
            message
        case .idle, .live:
            "Locally observed token history is not available."
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
