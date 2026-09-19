import AppKit
import SwiftUI

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
    var onBinanceInteraction: (Bool) -> Void
    var onBinanceClose: () -> Void

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
        initialCaptureMenuPresented: Bool = false,
        onBinanceInteraction: @escaping (Bool) -> Void = { _ in },
        onBinanceClose: @escaping () -> Void = {}
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
        self.onBinanceInteraction = onBinanceInteraction
        self.onBinanceClose = onBinanceClose
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
                        case .binance:
                            BinanceDashboardView(store: appModel.binanceStore, onSettings: {
                                onBinanceClose()
                                appModel.openBinanceSettings()
                            }, onInteraction: onBinanceInteraction, onClose: onBinanceClose)
                        case .calendar:
                            CalendarHoverDashboardView(store: appModel.calendarStore)
                        case .nowPlaying:
                            NowPlayingHoverDashboardView(store: appModel.nowPlayingStore)
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
                        case .augment:
                            AugmentHoverDashboardView(
                                store: appModel.augmentStore,
                                chartColor: appModel.preferences.augmentAppearance.color,
                                onOpenSettings: { appModel.openAugmentSettings?() }
                            )
                        case .grokBuild:
                            if GrokBuildFeatureGate.experimentalEnabled {
                                GrokBuildHoverDashboardView(store: appModel.grokBuildStore, appearance: appModel.preferences.grokBuildAppearance,
                                    onOpenSettings: { appModel.openGrokBuildSettings?() })
                            }
                        case .openCode:
                            OpenCodeHoverDashboardView(
                                store: appModel.openCodeStore,
                                appearanceMode: appearanceMode,
                                appearance: appModel.preferences.openCodeAppearance,
                                onOpenSettings: { appModel.openOpenCodeSettings?() }
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
