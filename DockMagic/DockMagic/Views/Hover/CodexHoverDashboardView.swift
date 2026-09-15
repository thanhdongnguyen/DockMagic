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
struct DockHoverDashboardRoot: View {
    let appModel: DockAppModel
    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    var appearanceMode: DSAppearanceMode = .dark
    var initialHoveredBucketID: Date?
    var initialSelectedDailyBucketID: Date?
    var initialIntensityHoveredBucketID: Date?
    var initialStreakDetailPresented: Bool
    var initialStreakCelebration: TokenUsageStreakCelebration?
    var streakCelebrationAutoDismissDelay: Duration
    var onStreakCelebrationDismissed: (String) -> Void
    var showsCaptureControls: Bool
    var initialCaptureMenuPresented: Bool

    init(
        appModel: DockAppModel,
        pointerEdge: DockHoverPointerEdge,
        panelSize: CGSize? = nil,
        appearanceMode: DSAppearanceMode = .dark,
        initialHoveredBucketID: Date? = nil,
        initialSelectedDailyBucketID: Date? = nil,
        initialIntensityHoveredBucketID: Date? = nil,
        initialStreakDetailPresented: Bool = false,
        initialStreakCelebration: TokenUsageStreakCelebration? = nil,
        streakCelebrationAutoDismissDelay: Duration = .milliseconds(2_800),
        onStreakCelebrationDismissed: @escaping (String) -> Void = { _ in },
        showsCaptureControls: Bool = true,
        initialCaptureMenuPresented: Bool = false
    ) {
        self.appModel = appModel
        self.pointerEdge = pointerEdge
        self.panelSize = panelSize
            ?? DockHoverPanelPlacement.panelSize(
                for: appModel.preferences.activeFeature
            )
        self.appearanceMode = appearanceMode
        self.initialHoveredBucketID = initialHoveredBucketID
        self.initialSelectedDailyBucketID = initialSelectedDailyBucketID
        self.initialIntensityHoveredBucketID = initialIntensityHoveredBucketID
        self.initialStreakDetailPresented = initialStreakDetailPresented
        self.initialStreakCelebration = initialStreakCelebration
        self.streakCelebrationAutoDismissDelay =
            streakCelebrationAutoDismissDelay
        self.onStreakCelebrationDismissed = onStreakCelebrationDismissed
        self.showsCaptureControls = showsCaptureControls
        self.initialCaptureMenuPresented = initialCaptureMenuPresented
    }

    var body: some View {
        Group {
            if appModel.preferences.activeFeature.hasHoverDashboard {
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
                                appearance: appModel.preferences
                                    .systemMetricsAppearance,
                                systemErrorDescription: appModel.metricsStore
                                    .lastErrorDescription,
                                processErrorDescription: appModel.metricsStore
                                    .lastProcessErrorDescription
                            )
                        case .weather:
                            WeatherHoverDashboardView(
                                state: appModel.weatherStore.state,
                                locationPlaceholder: appModel.weatherStore
                                    .locationPreviewValue
                            )
                        case .codex:
                            CodexHoverDashboardView(
                                state: appModel.codexStore.state,
                                serviceStatus: appModel.serviceStatusStore
                                    .codexState,
                                dailyDetailLoader: { date in
                                    try await appModel.codexStore
                                        .loadDailyTokenDetail(for: date)
                                },
                                initialHoveredBucketID: initialHoveredBucketID,
                                initialSelectedDailyBucketID:
                                    initialSelectedDailyBucketID,
                                initialIntensityHoveredBucketID:
                                    initialIntensityHoveredBucketID,
                                initialStreakDetailPresented:
                                    initialStreakDetailPresented,
                                initialStreakCelebration:
                                    initialStreakCelebration,
                                streakCelebrationAutoDismissDelay:
                                    streakCelebrationAutoDismissDelay,
                                onStreakCelebrationDismissed:
                                    onStreakCelebrationDismissed,
                                captureConfiguration: showsCaptureControls
                                    ? CodexDashboardCaptureConfiguration(
                                        pointerEdge: pointerEdge,
                                        panelSize: panelSize,
                                        appearanceMode: appearanceMode
                                    )
                                    : nil,
                                initialCaptureMenuPresented:
                                    initialCaptureMenuPresented
                            )
                        case .claudeCode:
                            ClaudeCodeHoverDashboardView(
                                state: appModel.claudeCodeStore.state,
                                serviceStatus: appModel.serviceStatusStore
                                    .claudeCodeState,
                                initialStreakDetailPresented:
                                    initialStreakDetailPresented,
                                initialStreakCelebration:
                                    initialStreakCelebration,
                                streakCelebrationAutoDismissDelay:
                                    streakCelebrationAutoDismissDelay,
                                onStreakCelebrationDismissed:
                                    onStreakCelebrationDismissed,
                                captureConfiguration: showsCaptureControls
                                    ? CodexDashboardCaptureConfiguration(
                                        pointerEdge: pointerEdge,
                                        panelSize: panelSize,
                                        appearanceMode: appearanceMode
                                    )
                                    : nil,
                                initialCaptureMenuPresented:
                                    initialCaptureMenuPresented,
                                isActivityHookInstalled: appModel
                                    .claudeCodeStore
                                    .isActivityHookInstalled,
                                isInstallingActivityHook: appModel
                                    .claudeCodeStore
                                    .isInstallingActivityHook,
                                activityHookErrorText: appModel
                                    .claudeCodeStore
                                    .activityHookErrorText,
                                onInstallActivityHook: {
                                    Task { @MainActor in
                                        await appModel.claudeCodeStore
                                            .installActivityHook()
                                    }
                                }
                            )
                        case .antigravity:
                            AntigravityHoverDashboardView(
                                state: appModel.antigravityStore.state,
                                initialHoveredBucketID: initialHoveredBucketID,
                                initialIntensityHoveredBucketID:
                                    initialIntensityHoveredBucketID,
                                initialStreakDetailPresented:
                                    initialStreakDetailPresented,
                                initialStreakCelebration:
                                    initialStreakCelebration,
                                streakCelebrationAutoDismissDelay:
                                    streakCelebrationAutoDismissDelay,
                                onStreakCelebrationDismissed:
                                    onStreakCelebrationDismissed,
                                captureConfiguration: showsCaptureControls
                                    ? CodexDashboardCaptureConfiguration(
                                        pointerEdge: pointerEdge,
                                        panelSize: panelSize,
                                        appearanceMode: appearanceMode
                                    )
                                    : nil,
                                initialCaptureMenuPresented:
                                    initialCaptureMenuPresented
                            )
                        case .dockMagic, .network, .storage, .clock,
                             .batteries, .github, .searchConsole:
                            EmptyView()
                        }
                    },
                    appearanceMode: appearanceMode
                )
            }
        }
        .frame(
            width: panelSize.width,
            height: panelSize.height
        )
        .accessibilityIdentifier("dockHover.dashboard")
    }
}

@MainActor
struct CodexHoverDashboardView: View {
    private enum CaptureAction {
        case save
        case copy
        case share
    }

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
    @State private var isCaptureButtonHovered = false
    @State private var isCaptureMenuPresented: Bool
    @State private var hoveredCaptureAction: CaptureAction?
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
                PreservedVectorAssetImage(assetName: brand.logoAssetName)
                    .scaledToFill()
                    // Preserve the established optical size of the compact
                    // Codex cloud while the source remains a clean SVG.
                    .frame(width: 42, height: 42)
                    .frame(width: 26, height: 26)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .accessibilityHidden(true)

                Text(brand.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                if let plan = snapshot?.planType, !plan.isEmpty {
                    CodexPlanBadge(
                        plan: plan,
                        providerName: brand.displayName
                    )
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

                if captureConfiguration != nil {
                    captureButton
                }

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

            if let serviceStatus {
                ServiceStatusHeaderView(state: serviceStatus)
            }
        }
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
        .accessibilityIdentifier("codex.capture.button")
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
                .padding(.trailing, capturePointerTrailingPadding)

            VStack(spacing: 1) {
                captureMenuRow(
                    captureAction: .save,
                    title: "Save 4× PNG",
                    subtitle: capturePixelSizeLabel,
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
                        .accessibilityIdentifier("codex.capture.error")
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
        .accessibilityIdentifier("codex.capture.menu")
    }

    private var capturePointerTrailingPadding: CGFloat {
        tokenUsage?.lifetimeTokens == nil ? 7 : 98
    }

    private var capturePixelSizeLabel: String {
        guard captureConfiguration != nil else { return "" }
        return CodexDashboardCaptureService.activityCardPixelSizeLabel
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
            } else if let todayTokens {
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
        ZStack(alignment: .top) {
            CodexTokenHistoryChart(
                buckets: chartBuckets,
                hoveredBucketID: $hoveredBucketID,
                plotHeight: tokenChartPlotHeight,
                onSelectBucket: setSelectedDailyBucketID
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
        CodexShipMomentumCard(momentum: shipMomentum)
    }

    private var usageInsights: some View {
        HStack(spacing: 7) {
            CodexDailyIntensityCard(
                buckets: chartBuckets,
                initialHoveredBucketID: initialIntensityHoveredBucketID
            )
            CodexTopModelsCard(
                models: CodexHoverDashboardPresentation.topModels(
                    from: tokenUsage
                ),
                isPartial: tokenUsage?.isModelUsagePartial == true,
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

struct CodexPlanBadge: View {
    let plan: String
    var providerName: String = "Codex"

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
        .accessibilityLabel("\(providerName) \(plan.localizedCapitalized) plan")
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

private struct DashboardCaptureKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isDashboardCapture: Bool {
        get { self[DashboardCaptureKey.self] }
        set { self[DashboardCaptureKey.self] = newValue }
    }
}

/// Export the same trailing chart viewport without a native scroll view or an
/// onAppear callback, neither of which is available to SwiftUI ImageRenderer.
struct DashboardHistoryViewport<ID: Hashable, Content: View>: View {
    let latestID: ID?
    var viewportHeight: CGFloat? = nil
    var documentSize: CGSize? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.isDashboardCapture) private var isDashboardCapture

    var body: some View {
        if isDashboardCapture {
            GeometryReader { geometry in
                content()
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .topTrailing
                    )
            }
            .clipped()
        } else if let viewportHeight, let documentSize {
            DashboardNativeHistoryViewport(
                latestID: latestID,
                viewportHeight: viewportHeight,
                documentSize: documentSize,
                content: content
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    content()
                }
                .onAppear {
                    scrollToLatest(using: proxy)
                }
                .onChange(of: latestID) { _, _ in
                    scrollToLatest(using: proxy)
                }
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let latestID else { return }
        proxy.scrollTo(latestID, anchor: .trailing)
    }
}

struct CodexTokenHistoryChart: View {
    let buckets: [CodexTokenUsageDailyBucket]
    @Binding var hoveredBucketID: Date?
    let plotHeight: CGFloat
    var unavailableBucketIDs: Set<Date> = []
    var isSelectionEnabled = true
    let onSelectBucket: @MainActor (Date) -> Void

    @Environment(\.designTheme) private var theme

    private let columnWidth: CGFloat = 46
    private let columnSpacing: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            yAxis

            DashboardHistoryViewport(latestID: buckets.last?.id) {
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
        let isAvailable = !unavailableBucketIDs.contains(bucket.id)
        let isLatest = bucket.id == buckets.last?.id
        let isHovered = bucket.id == hoveredBucketID
        let height = barHeight(for: bucket.tokens)

        return Button {
            guard isSelectionEnabled, isAvailable, bucket.tokens > 0 else {
                return
            }
            Task { @MainActor in
                onSelectBucket(bucket.id)
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .bottom) {
                    Color.clear

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.action)
                        .opacity(isHovered ? 1 : (isLatest ? 0.9 : 0.5))
                        .frame(width: 27, height: height)
                        .overlay {
                            if isHovered {
                                RoundedRectangle(
                                    cornerRadius: 4,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    theme.outlineStrong,
                                    lineWidth: 1
                                )
                                .frame(width: 27, height: height)
                            }
                        }
                }
                .frame(width: columnWidth, height: plotHeight)

                VStack(spacing: 0) {
                    Text(Self.weekdayLabel(bucket.startDate))
                    Text(Self.dayLabel(bucket.startDate))
                }
                .font(
                    .system(
                        size: 8,
                        weight: isLatest ? .semibold : .medium
                    )
                )
                .foregroundStyle(
                    isLatest ? theme.textSecondary : theme.textTertiary
                )
                .monospacedDigit()
            }
            .frame(width: columnWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSelectionEnabled && (!isAvailable || bucket.tokens <= 0))
        .onHover { isInside in
            if isInside {
                hoveredBucketID = bucket.id
            } else if hoveredBucketID == bucket.id {
                hoveredBucketID = nil
            }
        }
        .help(
            "\(Self.fullDateLabel(bucket.startDate)): " + (
                isAvailable
                    ? "\(bucket.tokens.formatted()) tokens"
                    : "Not observed"
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.fullDateLabel(bucket.startDate))
        .accessibilityValue(
            isAvailable
                ? "\(bucket.tokens.formatted()) tokens"
                : "Not observed"
        )
        .accessibilityHint(
            isSelectionEnabled && isAvailable && bucket.tokens > 0
                ? "Opens hourly and model token details"
                : isAvailable
                    ? "No token usage recorded"
                    : "No locally observed token data"
        )
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
    var accent: Color? = nil
    var isPartial = false
    var showsPartialIndicator = true

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        isPartial && showsPartialIndicator
                            ? "Ship momentum*"
                            : "Ship momentum"
                    )
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    ShipMomentumGauge(
                        score: momentum?.score,
                        rank: momentum?.rank,
                        accent: resolvedAccent
                    )
                    .frame(width: 132, height: 56)
                }
                .frame(width: 136, alignment: .leading)

                Rectangle()
                    .fill(theme.outline)
                    .frame(width: 0.5, height: 68)
                    .accessibilityHidden(true)

                CodexShipRankLadder(
                    activeRank: momentum?.rank,
                    accent: resolvedAccent
                )
            }

            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            if let momentum {
                metric(
                    value: Self.tokenLabel(momentum.todayTokens),
                    label: "tokens today"
                )
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
        Text("Today's token usage is unavailable")
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var resolvedAccent: Color {
        accent ?? theme.action
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

    private var helpText: String {
        let coverage = isPartial
            ? " For this provider, it includes only token activity observed locally by DockMagic."
            : ""
        return "Ship momentum uses only today's token activity and resets each local "
            + "calendar day. The ladder progresses from Starter to Legend. "
            + "It is an activity indicator, not a productivity rating."
            + coverage
    }

    private var accessibilityValue: String {
        guard let momentum else {
            return "Today's token usage is unavailable."
        }
        let coverage = isPartial ? " Locally observed activity only." : ""
        return "\(momentum.score) out of 100, rank \(momentum.rank.title), "
            + "\(momentum.rank.rawValue + 1) of \(CodexShipRank.allCases.count). "
            + "Today: \(momentum.todayTokens.formatted()) tokens."
            + coverage
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

struct CodexDailyIntensityCard: View {
    let buckets: [CodexTokenUsageDailyBucket]
    let accent: Color?
    let unavailableBucketIDs: Set<Date>
    let isPartial: Bool
    let showsPartialIndicator: Bool
    @State private var hoveredBucketID: Date?

    @Environment(\.designTheme) private var theme

    init(
        buckets: [CodexTokenUsageDailyBucket],
        accent: Color? = nil,
        unavailableBucketIDs: Set<Date> = [],
        isPartial: Bool = false,
        showsPartialIndicator: Bool = true,
        initialHoveredBucketID: Date? = nil
    ) {
        self.buckets = buckets
        self.accent = accent
        self.unavailableBucketIDs = unavailableBucketIDs
        self.isPartial = isPartial
        self.showsPartialIndicator = showsPartialIndicator
        _hoveredBucketID = State(initialValue: initialHoveredBucketID)
    }

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 5), spacing: 3),
        count: 15
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                cardContent

                if let hoveredBucket {
                    hoverTooltip(
                        for: hoveredBucket,
                        in: geometry.size
                    )
                }
            }
        }
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .help(helpText)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily token intensity")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(
                    isPartial && showsPartialIndicator
                        ? "Daily intensity*"
                        : "Daily intensity"
                )
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 2)

                if let bestDay {
                    Text("Best \(Self.shortDateLabel(bestDay.startDate))")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(theme.opaqueSurfaceRaised)
                        )
                        .overlay {
                            Capsule().strokeBorder(
                                theme.outline,
                                lineWidth: 0.5
                            )
                        }
                        .lineLimit(1)
                }
            }

            if buckets.isEmpty {
                Text("No intensity data")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(buckets) { bucket in
                        intensityCell(for: bucket)
                    }
                }

                HStack(spacing: 4) {
                    Text(Self.shortDateLabel(buckets.first!.startDate))

                    Spacer(minLength: 1)

                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { level in
                            RoundedRectangle(
                                cornerRadius: 1.5,
                                style: .continuous
                            )
                            .fill(fill(for: level))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 1.5,
                                    style: .continuous
                                )
                                .strokeBorder(theme.outline, lineWidth: 0.5)
                            }
                            .frame(width: 7, height: 6)
                        }
                    }
                    .accessibilityHidden(true)

                    Spacer(minLength: 1)

                    Text(Self.shortDateLabel(buckets.last!.startDate))
                }
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bestDay: CodexTokenUsageDailyBucket? {
        buckets
            .filter { !unavailableBucketIDs.contains($0.id) }
            .max { $0.tokens < $1.tokens }
    }

    private var hoveredBucket: CodexTokenUsageDailyBucket? {
        guard let hoveredBucketID else { return nil }
        return buckets.first { $0.id == hoveredBucketID }
    }

    private var maximumTokens: Int64 {
        max(
            1,
            buckets
                .filter { !unavailableBucketIDs.contains($0.id) }
                .map(\.tokens)
                .max() ?? 1
        )
    }

    private func intensityCell(
        for bucket: CodexTokenUsageDailyBucket
    ) -> some View {
        let isAvailable = !unavailableBucketIDs.contains(bucket.id)
        let level = intensityLevel(for: bucket.tokens)
        let isHovered = bucket.id == hoveredBucketID
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(fill(for: level))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(
                        isHovered
                            ? theme.actionForeground
                            : bucket.id == buckets.last?.id
                            ? theme.textPrimary
                            : theme.outline,
                        lineWidth: isHovered
                            || bucket.id == buckets.last?.id
                            ? 1
                            : 0.5
                    )
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering {
                    hoveredBucketID = bucket.id
                } else if hoveredBucketID == bucket.id {
                    hoveredBucketID = nil
                }
            }
            .accessibilityLabel(Self.fullDateLabel(bucket.startDate))
            .accessibilityValue(
                isAvailable
                    ? "\(bucket.tokens.formatted()) tokens"
                    : "Not observed"
            )
    }

    private func hoverTooltip(
        for bucket: CodexTokenUsageDailyBucket,
        in size: CGSize
    ) -> some View {
        Text(tooltipLabel(for: bucket))
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.opaqueSurfaceRaised)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.outlineStrong, lineWidth: 0.5)
            }
            .position(
                x: tooltipCenterX(for: bucket, cardWidth: size.width),
                y: max(12, size.height - 12)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func tooltipCenterX(
        for bucket: CodexTokenUsageDailyBucket,
        cardWidth: CGFloat
    ) -> CGFloat {
        guard let index = buckets.firstIndex(where: { $0.id == bucket.id })
        else {
            return cardWidth / 2
        }

        let column = index % columns.count
        let horizontalPadding: CGFloat = 9
        let usableWidth = max(0, cardWidth - horizontalPadding * 2)
        let cellCenter = horizontalPadding
            + usableWidth * (CGFloat(column) + 0.5) / CGFloat(columns.count)
        let tooltipHalfWidth: CGFloat = 36
        return min(
            max(tooltipHalfWidth, cellCenter),
            max(tooltipHalfWidth, cardWidth - tooltipHalfWidth)
        )
    }

    private func intensityLevel(for tokens: Int64) -> Int {
        guard tokens > 0 else { return 0 }
        return min(
            4,
            max(1, Int(ceil(Double(tokens) / Double(maximumTokens) * 4)))
        )
    }

    private func fill(for level: Int) -> Color {
        (accent ?? theme.action).opacity(0.10 + Double(level) * 0.19)
    }

    private var helpText: String {
        guard let bestDay else {
            return isPartial
                ? "No locally observed daily token intensity is available."
                : "Daily token intensity is unavailable."
        }
        let coverage = isPartial
            ? " Unobserved days remain unavailable and are excluded from Best calculations."
            : ""
        return "Daily token intensity for up to 30 days. Best day: "
            + "\(Self.fullDateLabel(bestDay.startDate)), "
            + "\(bestDay.tokens.formatted()) tokens."
            + coverage
    }

    private func tooltipLabel(
        for bucket: CodexTokenUsageDailyBucket
    ) -> String {
        let date = Self.fullDateLabel(bucket.startDate)
        guard !unavailableBucketIDs.contains(bucket.id) else {
            return "\(date) · Not observed"
        }
        return "\(date) · \(bucket.tokens.formatted()) tokens"
    }

    private static func shortDateLabel(_ date: Date) -> String {
        formatter("MMM d").string(from: date)
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

struct CodexTopModelsCard: View {
    let models: [CodexModelTokenUsage]
    let isPartial: Bool
    var accent: Color? = nil
    var providerName: String = "Codex"
    var showsPartialIndicator = true

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Top models")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 2)

                Text(
                    isPartial && showsPartialIndicator
                        ? "30d*"
                        : "30d"
                )
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }

            if models.isEmpty {
                Text("No model token data")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 3) {
                    ForEach(Array(models.enumerated()), id: \.element.id) {
                        index, model in
                        modelRow(model, rank: index + 1)
                    }
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .help(helpText)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Top models by token usage")
    }

    private func modelRow(
        _ model: CodexModelTokenUsage,
        rank: Int
    ) -> some View {
        HStack(spacing: 5) {
            Text("\(rank)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(width: 8, alignment: .trailing)

            Text(model.model)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 2)

            Capsule()
                .fill(accent ?? theme.action)
                .frame(width: modelBarWidth(model.tokens), height: 4)
                .accessibilityHidden(true)

            Text(Self.tokenLabel(model.tokens))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank), \(model.model)")
        .accessibilityValue("\(model.tokens.formatted()) tokens")
    }

    private func modelBarWidth(_ tokens: Int64) -> CGFloat {
        let maximum = max(1, models.map(\.tokens).max() ?? 1)
        return max(3, 13 * CGFloat(Double(tokens) / Double(maximum)))
    }

    private var helpText: String {
        let coverage = isPartial
            ? " Coverage is partial; only token activity available to DockMagic is included."
            : ""
        return "Models ranked by tokens observed for \(providerName) during "
            + "the last 30 days. Prompt and response content is not used."
            + coverage
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

private struct CodexShipRankLadder: View {
    let activeRank: CodexShipRank?
    let accent: Color

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
                                    ? accent
                                    : theme.textSecondary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(
                                width: columnWidth,
                                height: 9,
                                alignment: .top
                            )
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
            return accent
        }
        if let activeRank, rank.rawValue < activeRank.rawValue {
            return theme.outlineStrong
        }
        return theme.dockTrack
    }

    private func stepOutline(for rank: CodexShipRank) -> Color {
        rank == activeRank ? accent : theme.outline
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

struct UsageLimitHoverRow: View {
    let title: String
    let systemImage: String
    let remainingFraction: Double?
    let resetLabel: String
    var usageAccent: Color? = nil

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
                let fraction = remainingFraction ?? 0
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
        guard let remainingFraction else { return "—" }
        return "\(Int((remainingFraction * 100).rounded()))%"
    }

    private var progressFill: Color {
        guard let remainingFraction else { return theme.action }
        switch remainingFraction {
        case ...0.05:
            return theme.danger
        case ...0.2:
            return theme.warning
        default:
            return usageAccent ?? theme.action
        }
    }

    private var valueForeground: Color {
        guard let remainingFraction else { return theme.textSecondary }
        switch remainingFraction {
        case ...0.05:
            return theme.dangerForeground
        case ...0.2:
            return theme.warningForeground
        default:
            return theme.textPrimary
        }
    }
}

enum DockHoverCardLayout {
    // Keep the rounded surface fully inside the transparent NSPanel. Explicit
    // placement prevents AppKit from clipping its top outline at the host edge.
    static let panelInset: CGFloat = 6

    static func size(
        panelSize: CGSize,
        pointerEdge: DockHoverPointerEdge
    ) -> CGSize {
        switch pointerEdge {
        case .bottom:
            CGSize(
                width: panelSize.width - panelInset * 2,
                height: panelSize.height
                    - DockHoverPanelPlacement.pointerExtent - panelInset
            )
        case .left, .right:
            CGSize(
                width: panelSize.width
                    - DockHoverPanelPlacement.pointerExtent - panelInset,
                height: panelSize.height - panelInset * 2
            )
        }
    }
}

/// The dashboard surface shared by the live popup and PNG export. The popup
/// owns its external inset and Dock pointer; neither belongs in an image.
struct DockHoverDashboardCard<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(width: size.width, height: size.height)
            .dsSurface(
                RoundedRectangle(cornerRadius: 18, style: .continuous),
                kind: .raised
            )
    }
}

struct DockHoverChrome<Content: View>: View {

    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    @ViewBuilder let content: () -> Content

    @Environment(\.designTheme) private var theme

    var body: some View {
        switch pointerEdge {
        case .bottom:
            ZStack(alignment: .topLeading) {
                card
                    .offset(
                        x: DockHoverCardLayout.panelInset,
                        y: DockHoverCardLayout.panelInset
                    )

                DockHoverPointerShape(direction: .down)
                    .fill(theme.opaqueSurfaceRaised)
                    .frame(
                        width: DockHoverPanelPlacement.pointerExtent * 2,
                        height: DockHoverPanelPlacement.pointerExtent
                    )
                    .frame(
                        width: panelSize.width,
                        height: panelSize.height,
                        alignment: .bottom
                    )
            }
        case .left:
            ZStack(alignment: .topLeading) {
                card
                    .offset(
                        x: DockHoverPanelPlacement.pointerExtent,
                        y: DockHoverCardLayout.panelInset
                    )

                DockHoverPointerShape(direction: .left)
                    .fill(theme.opaqueSurfaceRaised)
                    .frame(
                        width: DockHoverPanelPlacement.pointerExtent,
                        height: DockHoverPanelPlacement.pointerExtent * 2
                    )
                    .frame(
                        width: panelSize.width,
                        height: panelSize.height,
                        alignment: .leading
                    )
            }
        case .right:
            ZStack(alignment: .topLeading) {
                card
                    .offset(
                        x: DockHoverCardLayout.panelInset,
                        y: DockHoverCardLayout.panelInset
                    )

                DockHoverPointerShape(direction: .right)
                    .fill(theme.opaqueSurfaceRaised)
                    .frame(
                        width: DockHoverPanelPlacement.pointerExtent,
                        height: DockHoverPanelPlacement.pointerExtent * 2
                    )
                    .frame(
                        width: panelSize.width,
                        height: panelSize.height,
                        alignment: .trailing
                    )
            }
        }
    }

    private var card: some View {
        DockHoverDashboardCard(
            size: DockHoverCardLayout.size(
                panelSize: panelSize,
                pointerEdge: pointerEdge
            ),
            content: content
        )
    }
}

struct DockHoverPointerShape: Shape {
    enum Direction {
        case up
        case down
        case left
        case right
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
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

struct CodexDashboardSharePresenter: NSViewRepresentable {
    @Binding var itemURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let itemURL else {
            context.coordinator.presentedURL = nil
            return
        }
        guard context.coordinator.presentedURL != itemURL else {
            return
        }
        context.coordinator.presentedURL = itemURL
        let itemBinding = $itemURL
        let coordinator = context.coordinator

        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: [itemURL])
            coordinator.present(picker, relativeTo: nsView)
            itemBinding.wrappedValue = nil
        }
    }

    static func dismantleNSView(
        _ nsView: NSView,
        coordinator: Coordinator
    ) {
        coordinator.endPresentation(closePicker: true)
    }

    @MainActor
    final class Coordinator: NSObject,
        NSSharingServicePickerDelegate,
        NSSharingServiceDelegate
    {
        var presentedURL: URL?
        private var picker: NSSharingServicePicker?
        private weak var presentingWindow: NSWindow?
        private var presentingWindowLevel: NSWindow.Level?

        func present(
            _ picker: NSSharingServicePicker,
            relativeTo sourceView: NSView
        ) {
            endPresentation(closePicker: true)

            if let window = sourceView.window,
               window.level
                    > DockHoverPanelPlacement.sharePresentationWindowLevel {
                presentingWindow = window
                presentingWindowLevel = window.level
                window.level = DockHoverPanelPlacement
                    .sharePresentationWindowLevel
            }

            self.picker = picker
            picker.delegate = self
            picker.show(
                relativeTo: sourceView.bounds,
                of: sourceView,
                preferredEdge: .minY
            )
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            delegateFor sharingService: NSSharingService
        ) -> (any NSSharingServiceDelegate)? {
            self
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            didChoose service: NSSharingService?
        ) {
            guard service == nil else {
                return
            }
            endPresentation(closePicker: false)
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didShareItems items: [Any]
        ) {
            endPresentation(closePicker: false)
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didFailToShareItems items: [Any],
            error: any Error
        ) {
            endPresentation(closePicker: false)
        }

        func endPresentation(closePicker: Bool) {
            let activePicker = picker
            picker = nil
            activePicker?.delegate = nil
            if closePicker {
                activePicker?.close()
            }

            if let presentingWindow, let presentingWindowLevel {
                presentingWindow.level = presentingWindowLevel
            }
            presentingWindow = nil
            presentingWindowLevel = nil
        }
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
            0, 120_000, 510_000, 940_000, 1_080_000,
            260_000, 420_000, 1_120_000, 0, 1_340_000,
            180_000, 670_000, 1_460_000, 310_000, 720_000,
            1_280_000, 770_000, 1_020_000, 590_000, 1_390_000,
            800_000, 1_180_000, 1_000_000, 980_000, 1_320_000,
            1_560_000, 1_210_000, 1_010_000, 730_000, 1_280_000
        ]
        let detailDate = calendar.date(
            byAdding: .day,
            value: values.count - 1,
            to: start
        )!
        func breakdown(
            total: Int64,
            cachedFraction: Double
        ) -> CodexTokenBreakdown {
            let output = max(1, total / 30)
            let input = max(0, total - output)
            return CodexTokenBreakdown(
                inputTokens: input,
                cachedInputTokens: Int64(
                    (Double(input) * cachedFraction).rounded()
                ),
                cacheWriteInputTokens: 0,
                outputTokens: output,
                reasoningOutputTokens: output / 3,
                totalTokens: total
            )
        }
        let hourlyTotals: [Int64] = [
            5_000, 10_000, 15_000, 15_000, 10_000, 15_000,
            30_000, 40_000, 60_000, 110_000, 70_000, 45_000,
            40_000, 60_000, 100_000, 75_000, 35_000, 25_000,
            35_000, 40_000, 45_000, 60_000, 75_000, 40_000
        ]
        let hourlyUsage = hourlyTotals.enumerated().map { hour, total in
            CodexHourlyTokenUsageBucket(
                startDate: calendar.date(
                    byAdding: .hour,
                    value: hour,
                    to: detailDate
                )!,
                usage: breakdown(total: total, cachedFraction: 0.88)
            )
        }
        let detailUsage = hourlyUsage.reduce(CodexTokenBreakdown.zero) {
            $0.adding($1.usage)
        }
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
                },
                modelUsage: [
                    CodexModelTokenUsage(model: "gpt-5.6", tokens: 8_400_000),
                    CodexModelTokenUsage(model: "gpt-5.5", tokens: 5_700_000),
                    CodexModelTokenUsage(model: "gpt-5.4", tokens: 2_900_000)
                ],
                isModelUsagePartial: false,
                localDailyDetails: [
                    CodexDailyTokenDetail(
                        startDate: detailDate,
                        usage: detailUsage,
                        hourlyUsage: hourlyUsage,
                        modelUsage: [
                            CodexDailyModelTokenUsage(
                                model: "gpt-5.6-sol",
                                usage: breakdown(
                                    total: 780_000,
                                    cachedFraction: 0.90
                                )
                            ),
                            CodexDailyModelTokenUsage(
                                model: "codex-auto-review",
                                usage: breakdown(
                                    total: 180_000,
                                    cachedFraction: 0.84
                                )
                            ),
                            CodexDailyModelTokenUsage(
                                model: "gpt-5.5",
                                usage: breakdown(
                                    total: 95_000,
                                    cachedFraction: 0.81
                                )
                            )
                        ],
                        isPartial: false
                    )
                ]
            ),
            streakSummary: TokenUsageStreakSummary.fixture(
                currentDays: 7,
                bestDays: 28,
                endingAt: detailDate,
                calendar: calendar
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
