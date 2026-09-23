import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsDestination: String, CaseIterable, Identifiable {
    case general
    case systemMetrics
    case network
    case storage
    case weather
    case clock
    case calendar
    case nowPlaying
    case batteries
    case github
    case codex
    case claudeCode
    case antigravity
    case openCode
    case grokBuild
    case binance
    case searchConsole

    init(activeFeature: DockFeature) {
        switch activeFeature {
        case .dockMagic:
            self = .general
        case .systemMetrics:
            self = .systemMetrics
        case .network:
            self = .network
        case .storage:
            self = .storage
        case .weather:
            self = .weather
        case .calendar:
            self = .calendar
        case .nowPlaying:
            self = .nowPlaying
        case .clock:
            self = .clock
        case .batteries:
            self = .batteries
        case .github:
            self = .github
        case .codex:
            self = .codex
        case .claudeCode:
            self = .claudeCode
        case .grokBuild:
            self = GrokBuildFeatureGate.experimentalEnabled ? .grokBuild : .general
        case .openCode:
            self = .openCode
        case .antigravity:
            self = .antigravity
        case .binance:
            self = .binance
        case .searchConsole:
            self = .searchConsole
        }
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            "General"
        case .systemMetrics:
            "CPU & RAM"
        case .network:
            "Network"
        case .storage:
            "Storage"
        case .weather:
            "Weather"
        case .calendar:
            "Calendar"
        case .nowPlaying:
            "Now Playing"
        case .clock:
            "Clock"
        case .batteries:
            "Batteries"
        case .github:
            "GitHub"
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
        case .grokBuild:
            "Grok Build (Experimental)"
        case .openCode:
            "OpenCode"
        case .antigravity:
            "Antigravity"
        case .binance:
            "Binance"
        case .searchConsole:
            "Search Console"
        }
    }

    var detail: String {
        switch self {
        case .general:
            "Choose Dock Active or Shelf Dock and manage the features shown there."
        case .systemMetrics:
            "Customize live CPU and memory rings."
        case .network:
            "Monitor live download and upload throughput."
        case .storage:
            "Monitor usage on the startup disk."
        case .weather:
            "Show current conditions supplied by Open-Meteo."
        case .calendar:
            "Your calendars, reminders, and daily agenda."
        case .nowPlaying:
            "Artwork and music controls for Spotify and Apple Music."
        case .clock:
            "Show local time or the time at another location."
        case .batteries:
            "Monitor your Mac and connected devices."
        case .github:
            "Track repository stars and forks in the Dock."
        case .codex:
            "Show Codex rate limits and aggregate token usage."
        case .claudeCode:
            "Show remaining 5-hour and weekly Claude Code limits."
        case .grokBuild:
            "Test local Grok tokens and activity. Quota remains unavailable."
        case .openCode:
            "Show local OpenCode tokens, history, and activity."
        case .antigravity:
            "Show official model-pool quota from Antigravity."
        case .binance:
            "Live Spot prices and individual coin charts."
        case .searchConsole:
            "A focused view of your Google Search performance."
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .systemMetrics:
            "cpu"
        case .network:
            "network"
        case .storage:
            "internaldrive.fill"
        case .weather:
            "cloud.sun.fill"
        case .calendar:
            "calendar"
        case .nowPlaying:
            "music.note"
        case .clock:
            "clock.fill"
        case .batteries:
            "battery.75percent"
        case .github:
            "point.3.connected.trianglepath.dotted"
        case .codex:
            "sparkles"
        case .claudeCode:
            "chevron.left.forwardslash.chevron.right"
        case .grokBuild:
            "g.circle"
        case .openCode:
            "terminal"
        case .antigravity:
            "sparkle"
        case .binance:
            "chart.xyaxis.line"
        case .searchConsole:
            "magnifyingglass"
        }
    }

    var feature: DockFeature? {
        switch self {
        case .general:
            nil
        case .systemMetrics:
            .systemMetrics
        case .network:
            .network
        case .storage:
            .storage
        case .weather:
            .weather
        case .calendar:
            .calendar
        case .nowPlaying:
            .nowPlaying
        case .clock:
            .clock
        case .batteries:
            .batteries
        case .github:
            .github
        case .codex:
            .codex
        case .claudeCode:
            .claudeCode
        case .grokBuild:
            .grokBuild
        case .openCode:
            .openCode
        case .antigravity:
            .antigravity
        case .binance:
            .binance
        case .searchConsole:
            .searchConsole
        }
    }
}

@MainActor
struct SettingsView: View {
    let appModel: DockAppModel
    let dockHoverPermissionController: DockHoverPermissionController?
    let windowRouter: SettingsWindowRouter?
    let softwareUpdateController: SoftwareUpdateController

    @State private var destination: SettingsDestination
    @State private var launchAtLoginController: LaunchAtLoginController
    @AppStorage(DSAppearanceMode.storageKey)
    private var appearanceRawValue = DSAppearanceMode.system.rawValue
    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        appModel: DockAppModel,
        dockHoverPermissionController: DockHoverPermissionController? = nil,
        windowRouter: SettingsWindowRouter? = nil,
        softwareUpdateController: SoftwareUpdateController? = nil,
        launchAtLoginController: LaunchAtLoginController? = nil,
        initialDestination: SettingsDestination = .general
    ) {
        self.appModel = appModel
        self.dockHoverPermissionController = dockHoverPermissionController
        self.windowRouter = windowRouter
        self.softwareUpdateController = softwareUpdateController ?? .disabled()
        _destination = State(
            initialValue: windowRouter?.destination ?? initialDestination
        )
        _launchAtLoginController = State(
            initialValue: launchAtLoginController
                ?? LaunchAtLoginController()
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: DSLayout.sidebarMinimumWidth,
                    ideal: DSLayout.sidebarIdealWidth,
                    max: DSLayout.sidebarMaximumWidth
                )
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: DSLayout.minimumWindowWidth,
            minHeight: DSLayout.minimumWindowHeight
        )
        .background(SettingsWindowPresentationBridge(appearanceMode: appearanceMode))
        .onChange(of: windowRouter?.destination, initial: true) { _, request in
            guard let request, request != destination else {
                return
            }
            destination = request
        }
        .onChange(of: destination, initial: true) { _, newDestination in
            if let feature = newDestination.feature {
                if feature == .claudeCode {
                    appModel.prepareExistingClaudeCodeIntegration()
                    appModel.claudeCodeStore.start()
                } else if feature == .antigravity {
                    appModel.antigravityStore.start()
                } else {
                    appModel.requestDeveloperToolPreparation(for: feature)
                }
            }

            switch newDestination {
            case .weather:
                appModel.weatherStore.refreshLocationAuthorizationStatus()
                refreshWeather()
            case .calendar:
                break // CalendarSettingsView owns its monitoring interest.
            case .clock:
                appModel.clockStore.start()
            case .batteries:
                appModel.batteryStore.start()
            case .searchConsole:
                appModel.searchConsoleStore.start()
            case .general, .systemMetrics, .network, .storage, .codex,
                 .claudeCode, .antigravity, .grokBuild, .openCode, .github, .binance, .nowPlaying:
                if newDestination == .general {
                    launchAtLoginController.refresh()
                }
                if appModel.preferences.activeFeature != .batteries {
                    appModel.batteryStore.stop()
                }
                if appModel.preferences.activeFeature != .searchConsole {
                    appModel.searchConsoleStore.stop()
                }
                if appModel.preferences.activeFeature != .clock {
                    appModel.clockStore.stop()
                }
                break
            }

            if newDestination != .clock,
               appModel.preferences.activeFeature != .clock {
                appModel.clockStore.stop()
            }
            if newDestination != .batteries,
               appModel.preferences.activeFeature != .batteries {
                appModel.batteryStore.stop()
            }
            if newDestination != .searchConsole,
               appModel.preferences.activeFeature != .searchConsole {
                appModel.searchConsoleStore.stop()
            }
            if newDestination != .antigravity,
               appModel.preferences.activeFeature != .antigravity,
               !appModel.antigravityStore.isBridgeInstalled {
                appModel.antigravityStore.stop()
            }
        }
        .onDisappear {
            if appModel.preferences.activeFeature != .batteries {
                appModel.batteryStore.stop()
            }
            if appModel.preferences.activeFeature != .searchConsole {
                appModel.searchConsoleStore.stop()
            }
            if appModel.preferences.activeFeature != .clock {
                appModel.clockStore.stop()
            }
            if appModel.preferences.activeFeature != .antigravity,
               !appModel.antigravityStore.isBridgeInstalled {
                appModel.antigravityStore.stop()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            refreshWeatherAfterReturningFromSystemSettings()
            dockHoverPermissionController?.refresh()
            launchAtLoginController.refresh()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            SettingsHeaderView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.xLarge)
                .padding(.vertical, DSSpacing.large)

            sidebarDivider
                .padding(.horizontal, DSSpacing.medium)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DSSpacing.large) {
                    sidebarRow(.general)

                    sidebarSection(
                        title: "AI Features",
                        identifier: "aiFeatures",
                        items: [.codex, .claudeCode, .antigravity, .openCode] + (GrokBuildFeatureGate.experimentalEnabled ? [.grokBuild] : [])
                    )

                    sidebarSection(
                        title: "Features",
                        identifier: "features",
                        items: [
                            .systemMetrics,
                            .network,
                            .storage,
                            .weather,
                            .clock,
                            .calendar,
                            .nowPlaying,
                            .batteries,
                            .github,
                            .binance,
                            .searchConsole
                        ]
                    )
                }
                .padding(.horizontal, DSSpacing.medium)
                .padding(.vertical, DSSpacing.medium)
            }

            if let availableVersion = softwareUpdateController.availableVersion {
                SoftwareUpdateFooterButton(
                    version: availableVersion,
                    action: softwareUpdateController.checkForUpdates
                )
                .padding(.horizontal, DSSpacing.medium)
                .padding(.bottom, DSSpacing.medium)
            }
        }
        .background(theme.opaqueSurfaceChrome)
    }

    private func sidebarSection(
        title: String,
        identifier: String,
        items: [SettingsDestination]
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            sidebarDivider

            Text(title)
                .font(DSTypography.metadata)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, DSSpacing.medium)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("settings.nav.section.\(identifier)")

            VStack(spacing: DSSpacing.xSmall) {
                ForEach(items) { item in
                    sidebarRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebarDivider: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 1))
            }
            .stroke(
                effectivelyIncreasesContrast
                    ? theme.outlineStrong
                    : theme.outline,
                style: StrokeStyle(
                    lineWidth: effectivelyIncreasesContrast ? 1.5 : 1,
                    dash: [4, 5]
                )
            )
        }
        .frame(height: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var effectivelyIncreasesContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }

    private func sidebarRow(_ item: SettingsDestination) -> some View {
        Button {
            navigate(to: item)
        } label: {
            HStack(spacing: DSSpacing.standard) {
                sidebarIcon(item)

                Text(item.title)
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .frame(minWidth: 104, alignment: .leading)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                if item.feature == appModel.preferences.activeFeature {
                    Circle()
                        .fill(theme.action)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DSSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background {
                if destination == item {
                    RoundedRectangle(
                        cornerRadius: DSRadius.row,
                        style: .continuous
                    )
                    .fill(theme.sidebarSelectionFill)
                    .overlay {
                        if effectivelyIncreasesContrast {
                            RoundedRectangle(
                                cornerRadius: DSRadius.row,
                                style: .continuous
                            )
                            .strokeBorder(theme.selectionOutline, lineWidth: 1.5)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: DSRadius.row,
                    style: .continuous
                )
            )
        }
        .buttonStyle(DSContentButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(
            item.feature == appModel.preferences.activeFeature
                ? "Active"
                : ""
        )
        .accessibilityAddTraits(destination == item ? .isSelected : [])
        .accessibilityIdentifier("settings.nav.\(item.rawValue)")
    }

    @ViewBuilder
    private func sidebarIcon(_ item: SettingsDestination) -> some View {
        if let feature = item.feature {
            DockFeatureIcon(feature: feature, size: 22)
        } else if item == .general {
            ZStack {
                RoundedRectangle(
                    cornerRadius: DSRadius.keycap,
                    style: .continuous
                )
                .fill(theme.sidebarIconFill)

                DSIcon(systemName: item.systemImage)
                    .dsFont(size: 13, weight: .semibold)
                    .foregroundStyle(theme.onSidebarIcon)
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
        } else {
            DSIcon(systemName: item.systemImage)
                .dsFont(size: 13, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(
                        cornerRadius: DSRadius.keycap,
                        style: .continuous
                    )
                    .fill(theme.surfaceChrome)
                )
                .accessibilityHidden(true)
        }
    }

    private var detailPane: some View {
        ZStack {
            theme.opaqueSurface
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.section) {
                    detailHeader
                    destinationContent
                }
                .padding(.horizontal, detailHorizontalPadding)
                .padding(.vertical, detailVerticalPadding)
                .frame(maxWidth: detailMaximumWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityIdentifier("settings.\(destination.rawValue)")
    }

    // The selected Search Console reference uses a wider, denser analytics
    // canvas than the other Settings destinations. Keep that layout local so
    // existing feature screens retain their established geometry.
    private var detailHorizontalPadding: CGFloat {
        destination == .searchConsole ? 24 : DSLayout.detailHorizontalPadding
    }

    private var detailVerticalPadding: CGFloat {
        destination == .searchConsole ? 8 : DSLayout.detailVerticalPadding
    }

    private var detailMaximumWidth: CGFloat {
        destination == .searchConsole ? 1_100 : DSLayout.detailMaximumWidth
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(destination.title)
                .font(DSTypography.settingsTitle)
                .foregroundStyle(theme.textPrimary)

            Text(destination.detail)
                .font(DSTypography.body)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.bottom, DSSpacing.large)
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch destination {
        case .general:
            generalContent
        case .systemMetrics:
            systemMetricsContent
        case .network:
            networkContent
        case .storage:
            storageContent
        case .weather:
            weatherContent
        case .binance:
            BinanceSettingsView(store: appModel.binanceStore, isActive: appModel.preferences.activeFeature == .binance)
        case .calendar:
            CalendarSettingsView(store: appModel.calendarStore,
                                 weatherStore: appModel.calendarWeatherStore,
                                 isActive: appModel.preferences.activeFeature == .calendar)
        case .nowPlaying:
            NowPlayingSettingsView(store: appModel.nowPlayingStore, isActive: appModel.preferences.activeFeature == .nowPlaying, onOpen: { appModel.openNowPlaying?() })
        case .clock:
            clockContent
        case .batteries:
            batteriesContent
        case .github:
            githubContent
        case .codex:
            codexContent
        case .claudeCode:
            claudeCodeContent
        case .grokBuild:
            if GrokBuildFeatureGate.experimentalEnabled {
                GrokBuildSettingsView(store: appModel.grokBuildStore, preferences: appModel.preferences)
            }
        case .openCode:
            OpenCodeSettingsView(store: appModel.openCodeStore, preferences: appModel.preferences)
        case .antigravity:
            antigravityContent
        case .searchConsole:
            searchConsoleContent
        }
    }

    private var generalContent: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(
                title: "Appearance",
                detail: appearanceMode.detail
            ) {
                DSSegmentedControl(title: "Appearance", selection: appearanceBinding,
                    options: DSAppearanceMode.settingsCases.map {
                        .init(value: $0, title: $0.title, icon: DSIconName.fromLegacySymbol($0.systemImage),
                              accessibilityIdentifier: "settings.appearanceOption.\($0.rawValue)")
                    })
                .accessibilityIdentifier("settings.appearancePicker")
            }

            DSSettingsSection(
                title: "Startup",
                detail: "Choose whether DockMagic starts automatically when you sign in to your Mac."
            ) {
                VStack(spacing: DSSpacing.standard) {
                    DSSettingsRow(
                        title: "Launch at login",
                        detail: launchAtLoginController.state.detail,
                        systemImage: "power"
                    ) {
                        Toggle(
                            "Launch at login",
                            isOn: launchAtLoginBinding
                        )
                        .labelsHidden()
                        .toggleStyle(DSSwitchStyle())
                        .accessibilityIdentifier(
                            "settings.launchAtLogin.toggle"
                        )
                    }

                    if launchAtLoginController.state == .requiresApproval {
                        DSDivider()
                        launchAtLoginApprovalRow
                    }

                    if let errorDescription =
                        launchAtLoginController.errorDescription
                    {
                        DSDivider()
                        DSStatusCard(
                            title: "Launch at login couldn't be updated",
                            detail: errorDescription,
                            systemImage: "exclamationmark.triangle.fill",
                            role: .danger
                        )
                        .accessibilityIdentifier(
                            "settings.launchAtLogin.error"
                        )
                    }
                }
            }

            DSSettingsSection(
                title: "Dock",
                detail: "Choose one feature on the Apple Dock, or use a Custom Dock with a Shelf group."
            ) {
                VStack(spacing: DSSpacing.standard) {
                    DSSegmentedControl(
                        title: "Dock mode",
                        selection: Binding(
                            get: { appModel.preferences.dockMode },
                            set: { mode in
                                if mode == .shelfDock {
                                    dockHoverPermissionController?.synchronize(isEnabled: true)
                                    dockHoverPermissionController?.requestAccess()
                                }
                                appModel.preferences.dockMode = mode
                            }
                        ),
                        options: DockMode.allCases.map {
                            .init(value: $0, title: $0.title,
                                  accessibilityIdentifier: "settings.dockMode.\($0.rawValue)")
                        }
                    )
                    .accessibilityIdentifier("settings.dockMode")

                    if let status = appModel.preferences.customDockStatusMessage {
                        DSStatusCard(title: "Shelf Dock unavailable", detail: status,
                                     systemImage: "exclamationmark.triangle.fill", role: .danger)
                            .accessibilityIdentifier("settings.customDock.status")
                    }

                    if appModel.preferences.dockMode == .shelfDock {
                        customDockSettings
                    } else {
                    DSSettingsRow(
                        title: "Active Dock Feature",
                        detail: appModel.preferences.activeFeature.detail,
                        systemImage: "dock.rectangle"
                    ) {
                        ActiveDockFeaturePicker(selection: activeFeatureBinding)
                    }

                    if appModel.preferences.activeFeature == .clock {
                        DSDivider()
                        DSSettingsRow(
                            title: "Clock style",
                            detail: appModel.preferences.clockConfiguration
                                .displayStyle.detail,
                            systemImage: appModel.preferences.clockConfiguration
                                .displayStyle.systemImage
                        ) {
                            ClockDisplayStylePicker(
                                selection: clockDisplayStyleBinding
                            )
                            .frame(width: 280)
                        }
                    }
                    }
                }
            }

            if appModel.preferences.dockMode == .dockActive {
            DSSettingsSection(
                title: "Dock hover dashboard",
                detail: "Available for supported dashboards, including Now Playing, Calendar, Weather, CPU & RAM and AI features. Dock-only features never open a hover dashboard."
            ) {
                VStack(spacing: DSSpacing.standard) {
                    DSSettingsRow(
                        title: "Show dashboard on Dock hover",
                        detail: appModel.preferences.activeFeature.hasHoverDashboard
                            ? "Off by default. Requires Accessibility to detect only DockMagic's own Dock item and position."
                            : "Unavailable while \(appModel.preferences.activeFeature.title) is active. Your preference is preserved for supported features."
                    ) {
                        Toggle(
                            "Show dashboard on Dock hover",
                            isOn: dockHoverEnabledBinding
                        )
                        .labelsHidden()
                        .toggleStyle(DSSwitchStyle())
                        .disabled(
                            !appModel.preferences.activeFeature.hasHoverDashboard
                        )
                        .accessibilityIdentifier("settings.dockHover.toggle")
                    }

                    if appModel.preferences.isDockHoverDashboardEnabled,
                       appModel.preferences.activeFeature.hasHoverDashboard {
                        DSDivider()

                        HStack(alignment: .top, spacing: DSSpacing.medium) {
                            DSIconPlate(
                                dockHoverPermissionIcon,
                                role: dockHoverPermissionRole
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(dockHoverPermissionState.title)
                                    .font(DSTypography.bodyEmphasis)
                                    .foregroundStyle(theme.textPrimary)

                                Text(dockHoverPermissionState.detail)
                                    .font(DSTypography.metadata)
                                    .foregroundStyle(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                dockHoverPermissionActions
                                    .padding(.top, DSSpacing.xSmall)
                            }

                            Spacer(minLength: 0)
                        }
                        .accessibilityIdentifier("settings.dockHover.permission")
                    }
                }
            }
            }

            DSSettingsSection(
                title: "Software Updates",
                detail: "Keep DockMagic current with signed releases published on GitHub."
            ) {
                VStack(spacing: DSSpacing.standard) {
                    DSSettingsRow(
                        title: "Check for updates",
                        detail: currentVersionDetail,
                        systemImage: "arrow.triangle.2.circlepath"
                    ) {
                        Button("Check Now…") {
                            softwareUpdateController.checkForUpdates()
                        }
                        .buttonStyle(DSButtonStyle())
                        .disabled(
                            !softwareUpdateController.canCheckForUpdates
                        )
                        .accessibilityIdentifier(
                            "settings.softwareUpdate.checkNow"
                        )
                    }

                    DSDivider()

                    DSSettingsRow(
                        title: "Automatically check for updates",
                        detail: "Checks GitHub periodically while DockMagic is running.",
                        systemImage: "clock.arrow.circlepath"
                    ) {
                        Toggle(
                            "Automatically check for updates",
                            isOn: automaticallyChecksForUpdatesBinding
                        )
                        .labelsHidden()
                        .toggleStyle(DSSwitchStyle())
                        .accessibilityValue(
                            softwareUpdateController
                                .automaticallyChecksForUpdates
                                ? "On"
                                : "Off"
                        )
                        .accessibilityLabel(
                            "Automatically check for updates, "
                                + (softwareUpdateController
                                    .automaticallyChecksForUpdates
                                    ? "On"
                                    : "Off")
                        )
                        .accessibilityIdentifier(
                            "settings.softwareUpdate.automaticChecks"
                        )
                    }

                    DSDivider()

                    DSSettingsRow(
                        title: "Automatically download updates",
                        detail: "Downloads verified updates in the background and installs them when you approve or quit.",
                        systemImage: "arrow.down.circle"
                    ) {
                        Toggle(
                            "Automatically download updates",
                            isOn: automaticallyDownloadsUpdatesBinding
                        )
                        .labelsHidden()
                        .toggleStyle(DSSwitchStyle())
                        .accessibilityValue(
                            softwareUpdateController
                                .automaticallyDownloadsUpdates
                                ? "On"
                                : "Off"
                        )
                        .accessibilityLabel(
                            "Automatically download updates, "
                                + (softwareUpdateController
                                    .automaticallyDownloadsUpdates
                                    ? "On"
                                    : "Off")
                        )
                        .disabled(
                            !softwareUpdateController
                                .automaticallyChecksForUpdates
                                || !softwareUpdateController
                                    .allowsAutomaticUpdates
                        )
                        .accessibilityIdentifier(
                            "settings.softwareUpdate.automaticDownloads"
                        )
                    }
                }
            }
        }
    }

    private var launchAtLoginApprovalRow: some View {
        HStack(alignment: .top, spacing: DSSpacing.medium) {
            DSIconPlate(
                systemImage: "checkmark.shield.fill",
                role: .warning
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Approval required")
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)

                Text(
                    "Allow DockMagic under Open at Login to finish enabling this feature."
                )
                .font(DSTypography.metadata)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Button("Open Login Items…") {
                    launchAtLoginController.openSystemSettings()
                }
                .buttonStyle(DSButtonStyle())
                .padding(.top, DSSpacing.xSmall)
                .accessibilityIdentifier(
                    "settings.launchAtLogin.openSystemSettings"
                )
            }

            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("settings.launchAtLogin.approval")
    }

    @ViewBuilder
    private var dockHoverPermissionActions: some View {
        switch dockHoverPermissionState {
        case .disabled, .authorized:
            EmptyView()
        case .needsPermission:
            Button("Allow Accessibility…") {
                dockHoverPermissionController?.requestAccess()
            }
            .buttonStyle(DSButtonStyle(emphasis: .primary))
            .disabled(dockHoverPermissionController == nil)
            .accessibilityIdentifier("settings.dockHover.allow")
        case .awaitingUserAction:
            HStack(spacing: DSSpacing.compact) {
                Button("Open System Settings") {
                    dockHoverPermissionController?.openAccessibilitySettings()
                }
                .buttonStyle(DSButtonStyle(emphasis: .primary))

                Button("Check Again") {
                    dockHoverPermissionController?.refresh()
                }
                .buttonStyle(DSButtonStyle())
            }
            .accessibilityIdentifier("settings.dockHover.awaitingActions")
        }
    }

    private var systemMetricsContent: some View {
        VStack(spacing: DSSpacing.section) {
            featurePreviewSection(
                title: "Live Dock preview",
                detail: appModel.preferences.activeFeature == .systemMetrics
                    ? "Changes are applied to the Dock immediately."
                    : "CPU & RAM is not active, so changes update this preview only."
            ) {
                DockMetricsView(
                    snapshot: appModel.metricsStore.current,
                    appearance: appModel.preferences.systemMetricsAppearance,
                    errorDescription: appModel.metricsStore.lastErrorDescription,
                    animatesChanges: true
                )
            } values: {
                PreviewMetric(
                    title: "CPU",
                    value: appModel.metricsStore.current.cpuUsage,
                    color: appModel.preferences.systemMetricsAppearance.outerColor.color
                )
                PreviewMetric(
                    title: "RAM",
                    value: appModel.metricsStore.current.memoryUsage,
                    color: appModel.preferences.systemMetricsAppearance.innerColor.color
                )
            }

            DockDisplayStyleEditor(
                featureTitle: "CPU & RAM",
                selection: systemMetricsDisplayStyleBinding
            )

            RingAppearanceEditor(
                outerTitle: "CPU",
                innerTitle: "RAM",
                appearance: appModel.preferences.systemMetricsAppearance,
                outerColor: systemMetricsOuterColorBinding,
                innerColor: systemMetricsInnerColorBinding,
                outerWidth: systemMetricsOuterWidthBinding,
                innerWidth: systemMetricsInnerWidthBinding,
                reset: appModel.preferences.resetSystemMetricsAppearance
            )

            if let error = appModel.metricsStore.lastErrorDescription {
                DSStatusCard(
                    title: "System monitoring unavailable",
                    detail: error,
                    systemImage: "exclamationmark.triangle.fill",
                    role: .danger
                )
            } else if appModel.metricsStore.isMonitoring {
                DSStatusCard(
                    title: "Updating every second",
                    detail: "Only the current sample is sent to the Dock renderer.",
                    systemImage: "waveform.path.ecg",
                    role: .processing
                )
            }
        }
    }

    private var networkContent: some View {
        VStack(spacing: DSSpacing.section) {
            featurePreviewSection(
                title: "Live Dock preview",
                detail: appModel.preferences.activeFeature == .network
                    ? "The Dock chart shows the latest 30 seconds."
                    : "Network is not active, so the sampler is paused."
            ) {
                DockNetworkView(
                    history: appModel.networkStore.history,
                    appearance: appModel.preferences.networkAppearance,
                    errorDescription: appModel.networkStore.lastErrorDescription
                )
            } values: {
                PreviewTextMetric(
                    title: "Download",
                    value: networkValue(
                        appModel.networkStore.current.downloadBytesPerSecond
                    ),
                    color: appModel.preferences.networkAppearance.downloadColor.color,
                    systemImage: "arrow.down"
                )
                PreviewTextMetric(
                    title: "Upload",
                    value: networkValue(
                        appModel.networkStore.current.uploadBytesPerSecond
                    ),
                    color: appModel.preferences.networkAppearance.uploadColor.color,
                    systemImage: "arrow.up"
                )
                PreviewTextMetric(
                    title: "Interface",
                    value: appModel.networkStore.current.interfaceName,
                    color: theme.textSecondary,
                    systemImage: "network"
                )
            }

            NetworkAppearanceEditor(
                appearance: appModel.preferences.networkAppearance,
                downloadColor: networkDownloadColorBinding,
                uploadColor: networkUploadColorBinding,
                reset: appModel.preferences.resetNetworkAppearance
            )

            if let error = appModel.networkStore.lastErrorDescription {
                DSStatusCard(
                    title: "Network monitoring unavailable",
                    detail: error,
                    systemImage: "exclamationmark.triangle.fill",
                    role: .danger
                )
            } else if appModel.networkStore.isMonitoring {
                DSStatusCard(
                    title: "Updating every second",
                    detail: "Only the primary interface is measured to avoid counting VPN and physical traffic twice.",
                    systemImage: "waveform.path.ecg",
                    role: .processing
                )
            }
        }
    }

    private var storageContent: some View {
        VStack(spacing: DSSpacing.section) {
            featurePreviewSection(
                title: "Live Dock preview",
                detail: appModel.preferences.activeFeature == .storage
                    ? "Startup disk usage is applied to the Dock every five seconds."
                    : "Storage is not active, so changes update this preview only."
            ) {
                DockStorageView(
                    snapshot: appModel.storageStore.current,
                    appearance: appModel.preferences.storageAppearance,
                    errorDescription: appModel.storageStore.lastErrorDescription,
                    animatesChanges: true
                )
            } values: {
                PreviewMetric(
                    title: "Used",
                    value: appModel.storageStore.current.totalBytes > 0
                        ? appModel.storageStore.current.usage
                        : nil,
                    color: appModel.preferences.storageAppearance.color.color
                )
                PreviewTextMetric(
                    title: "Available",
                    value: storageValue(appModel.storageStore.current.availableBytes),
                    color: theme.informationForeground,
                    systemImage: "internaldrive"
                )
                PreviewTextMetric(
                    title: "Total",
                    value: storageValue(appModel.storageStore.current.totalBytes),
                    color: theme.textSecondary,
                    systemImage: "externaldrive"
                )
            }

            DockDisplayStyleEditor(
                featureTitle: "Storage",
                selection: storageDisplayStyleBinding
            )

            SingleRingAppearanceEditor(
                colorTitle: "Storage",
                appearance: appModel.preferences.storageAppearance,
                color: storageColorBinding,
                width: storageWidthBinding,
                reset: appModel.preferences.resetStorageAppearance
            )

            if let error = appModel.storageStore.lastErrorDescription {
                DSStatusCard(
                    title: "Storage monitoring unavailable",
                    detail: error,
                    systemImage: "exclamationmark.triangle.fill",
                    role: .danger
                )
            } else if appModel.storageStore.isMonitoring {
                DSStatusCard(
                    title: "Updating every five seconds",
                    detail: "Capacity is read locally from the startup volume.",
                    systemImage: "internaldrive.fill",
                    role: .processing
                )
            }
        }
    }

    private var weatherContent: some View {
        VStack(spacing: DSSpacing.section) {
            featurePreviewSection(
                title: "Weather Dock preview",
                detail: weatherPreviewDetail
            ) {
                DockWeatherView(
                    state: appModel.weatherStore.state,
                    animatesChanges: true
                )
            } values: {
                WeatherPreviewValue(
                    title: "Temperature",
                    value: weatherSnapshot.map {
                        Self.temperatureLabel($0.temperatureCelsius)
                    },
                    systemImage: "thermometer.medium"
                )
                WeatherPreviewValue(
                    title: "Conditions",
                    value: weatherSnapshot?.conditionDescription,
                    systemImage: "cloud.sun"
                )
                WeatherPreviewValue(
                    title: "Location",
                    value: weatherLocationPreviewValue,
                    systemImage: "location"
                )
                .accessibilityIdentifier("settings.weather.location")
            }

            weatherAttribution
        }
    }

    private var weatherAttribution: some View {
        HStack(spacing: DSSpacing.compact) {
            Spacer()

            Text("Weather data by")
                .foregroundStyle(theme.textTertiary)

            Link("Open-Meteo", destination: Self.weatherAttributionURL)
                .foregroundStyle(theme.actionForeground)
                .accessibilityLabel("Open-Meteo weather data")
                .accessibilityIdentifier("settings.weather.attribution")

            Text("·")
                .foregroundStyle(theme.textTertiary)

            Link("CC BY 4.0", destination: Self.weatherLicenseURL)
                .foregroundStyle(theme.actionForeground)
        }
        .font(DSTypography.metadata)
        .padding(.horizontal, DSSpacing.compact)
    }

    private var clockContent: some View {
        ClockSettingsView(
            date: appModel.clockStore.currentDate,
            configuration: appModel.preferences.clockConfiguration,
            isActive: appModel.preferences.activeFeature == .clock,
            displayStyle: clockDisplayStyleBinding,
            followsSystemTimeZone: clockFollowsSystemTimeZoneBinding,
            timeZoneIdentifier: clockTimeZoneIdentifierBinding
        )
    }

    private var batteriesContent: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(
                title: "Live Dock preview",
                detail: "See how battery status appears in your Dock."
            ) {
                HStack(alignment: .center, spacing: DSSpacing.xLarge) {
                    DockBatteryView(
                        snapshot: appModel.batteryStore.current,
                        errorDescription: appModel.batteryStore.lastErrorDescription,
                        animatesChanges: true
                    )
                    .frame(width: 320, height: 320)
                    .accessibilityIdentifier("settings.batteries.dockPreview")

                    batteryDeviceList
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 320)
                .padding(.vertical, DSSpacing.small)
            }

            if let error = appModel.batteryStore.lastErrorDescription {
                DSStatusCard(
                    title: "Battery monitoring unavailable",
                    detail: error,
                    systemImage: "exclamationmark.triangle.fill",
                    role: .danger
                )
            }
        }
    }

    @ViewBuilder
    private var batteryDeviceList: some View {
        if appModel.batteryStore.current.devices.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.small) {
                DSIcon(systemName: "battery.0percent")
                    .dsFont(size: 28, weight: .medium)
                    .foregroundStyle(theme.textTertiary)

                Text("No battery devices detected")
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)

                Text("Connect an accessory or open its charging case near this Mac.")
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            .accessibilityIdentifier("settings.batteries.empty")
        } else {
            VStack(spacing: 0) {
                ForEach(
                    Array(appModel.batteryStore.current.devices.enumerated()),
                    id: \.element.id
                ) { index, device in
                    BatteryDeviceStatusRow(device: device)
                        .accessibilityIdentifier(
                            "settings.batteries.device.\(device.id)"
                        )

                    if index < appModel.batteryStore.current.devices.count - 1 {
                        DSDivider()
                    }
                }
            }
        }
    }

    private var codexContent: some View {
        VStack(spacing: DSSpacing.section) {
            developerToolPreviewSection(
                tool: .codex,
                title: "Codex Dock preview",
                detail: codexPreviewDetail
            ) {
                DockCodexView(
                    state: appModel.codexStore.state,
                    appearance: appModel.preferences.codexAppearance,
                    animatesChanges: true
                )
            } values: {
                ForEach(UsageQuotaPresentation.codex(codexSnapshot)) { metric in
                    PreviewMetric(
                        title: "\(metric.title) left",
                        value: metric.remainingFraction,
                        color: metric.usesSecondaryAppearance
                            ? appModel.preferences.codexAppearance.innerColor.color
                            : appModel.preferences.codexAppearance.outerColor.color
                    )
                }
            }

            DockDisplayStyleEditor(
                featureTitle: "Codex",
                selection: codexDisplayStyleBinding
            )

            RingAppearanceEditor(
                outerTitle: "5-hour",
                innerTitle: "Weekly",
                appearance: appModel.preferences.codexAppearance,
                outerColor: codexOuterColorBinding,
                innerColor: codexInnerColorBinding,
                outerWidth: codexOuterWidthBinding,
                innerWidth: codexInnerWidthBinding,
                reset: appModel.preferences.resetCodexAppearance
            )
        }
    }

    private var githubContent: some View {
        GitHubSettingsView(
            store: appModel.githubStore,
            savedRepositoryURL: appModel.preferences.githubRepositoryURL,
            isActive: appModel.preferences.activeFeature == .github,
            appearance: appModel.preferences.githubAppearance,
            displayStyle: githubDisplayStyleBinding,
            starColor: githubStarColorBinding,
            forkColor: githubForkColorBinding,
            resetAppearance: appModel.preferences.resetGitHubAppearance,
            connectRepository: appModel.connectGitHubRepository
        )
    }

    private var searchConsoleContent: some View {
        SearchConsoleSettingsView(
            store: appModel.searchConsoleStore,
            isActive: appModel.preferences.activeFeature == .searchConsole
        )
    }

    private var claudeCodeContent: some View {
        VStack(spacing: DSSpacing.section) {
            ClaudeCodeConnectionSettingsView(
                store: appModel.claudeCodeStore,
                installationState: appModel.developerToolInstallationStore
                    .state(for: .claudeCode),
                installCLI: {
                    installDeveloperTool(.claudeCode)
                }
            )

            featurePreviewSection(
                title: "Claude Code Dock preview",
                detail: claudeCodePreviewDetail
            ) {
                DockClaudeCodeView(
                    state: appModel.claudeCodeStore.state,
                    appearance: appModel.preferences.claudeCodeAppearance,
                    animatesChanges: true
                )
            } values: {
                PreviewMetric(
                    title: "5-hour left",
                    value: claudeCodeSnapshot?.fiveHour?.remainingFraction,
                    color: appModel.preferences.claudeCodeAppearance.outerColor.color
                )
                PreviewMetric(
                    title: "Weekly left",
                    value: claudeCodeSnapshot?.weekly?.remainingFraction,
                    color: appModel.preferences.claudeCodeAppearance.innerColor.color
                )
            }

            DockDisplayStyleEditor(
                featureTitle: "Claude Code",
                selection: claudeCodeDisplayStyleBinding
            )

            RingAppearanceEditor(
                outerTitle: "5-hour",
                innerTitle: "Weekly",
                appearance: appModel.preferences.claudeCodeAppearance,
                outerColor: claudeCodeOuterColorBinding,
                innerColor: claudeCodeInnerColorBinding,
                outerWidth: claudeCodeOuterWidthBinding,
                innerWidth: claudeCodeInnerWidthBinding,
                reset: appModel.preferences.resetClaudeCodeAppearance
            )
        }
    }

    private var antigravityContent: some View {
        VStack(spacing: DSSpacing.section) {
            AntigravityConnectionSettingsView(
                store: appModel.antigravityStore,
                installationState: appModel.developerToolInstallationStore
                    .state(for: .antigravity),
                installCLI: {
                    installDeveloperTool(.antigravity)
                }
            )

            featurePreviewSection(
                title: "Antigravity Dock preview",
                detail: antigravityPreviewDetail
            ) {
                DockAntigravityView(
                    state: appModel.antigravityStore.state,
                    appearance: appModel.preferences.antigravityAppearance,
                    animatesChanges: true
                )
            } values: {
                if antigravityBuckets.isEmpty {
                    PreviewMetric(
                        title: "Model quota",
                        value: nil,
                        color: appModel.preferences.antigravityAppearance
                            .outerColor.color
                    )
                } else {
                    ForEach(Array(antigravityBuckets.prefix(2))) { bucket in
                        PreviewMetric(
                            title: "\(bucket.groupName) left",
                            value: bucket.remainingFraction,
                            color: appModel.preferences.antigravityAppearance
                                .outerColor.color
                        )
                    }
                }
            }

            DockDisplayStyleEditor(
                featureTitle: "Antigravity",
                selection: antigravityDisplayStyleBinding
            )

            RingAppearanceEditor(
                outerTitle: "Primary pool",
                innerTitle: "Secondary pool",
                appearance: appModel.preferences.antigravityAppearance,
                outerColor: antigravityOuterColorBinding,
                innerColor: antigravityInnerColorBinding,
                outerWidth: antigravityOuterWidthBinding,
                innerWidth: antigravityInnerWidthBinding,
                reset: appModel.preferences.resetAntigravityAppearance
            )
        }
    }

    private func featurePreviewSection<Preview: View, Values: View>(
        title: String,
        detail: String,
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder values: @escaping () -> Values
    ) -> some View {
        DSSettingsSection(title: title, detail: detail) {
            HStack(spacing: DSSpacing.xLarge) {
                preview()
                    .frame(
                        width: DSLayout.dockPreviewSize,
                        height: DSLayout.dockPreviewSize
                    )
                    .accessibilityIdentifier("settings.dockPreview")

                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    values()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func developerToolPreviewSection<Preview: View, Values: View>(
        tool: DeveloperTool,
        title: String,
        detail: String,
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder values: @escaping () -> Values
    ) -> some View {
        featurePreviewSection(
            title: title,
            detail: detail,
            preview: preview,
            values: values
        )
        .overlay(alignment: .topTrailing) {
            developerToolInstallationIndicator(tool)
                .padding(DSSpacing.xLarge)
        }
    }

    private var customDockSettings: some View {
        let magnificationSuppressed = accessibilityOverrides.reduceMotion ?? reduceMotion
        return VStack(alignment: .leading, spacing: DSSpacing.standard) {
            DSDivider()
            DSSettingsRow(title: "Icon size", detail: "Independent of Apple Dock after the first import.", systemImage: "dock.rectangle") {
                HStack(spacing: 8) {
                    DSSlider(value: Binding(
                        get: { appModel.preferences.customDockConfiguration.preferredIconSize },
                        set: { size in appModel.preferences.updateCustomDock { $0.preferredIconSize = size } }
                    ), in: 16...128, step: 1)
                    .frame(width: 170)
                    Text("\(Int(appModel.preferences.customDockConfiguration.preferredIconSize)) pt")
                        .font(DSTypography.metadata)
                }
            }
            DSSelect(title: "Dock edge", selection: Binding(
                get: { appModel.preferences.customDockConfiguration.edge },
                set: { edge in appModel.preferences.updateCustomDock { $0.edge = edge } }
            ), options: CustomDockEdge.allCases.map {
                .init(value: $0, title: $0.rawValue.capitalized)
            })
            DSSelect(title: "Display", selection: Binding<UInt32?>(
                get: { appModel.preferences.customDockConfiguration.displayID },
                set: { id in appModel.preferences.updateCustomDock { $0.displayID = id } }
            ), options: [DSSelectOption<UInt32?>(value: nil, title: "Main display")]
                + NSScreen.screens.compactMap { screen in
                    guard let number = screen.deviceDescription[
                        NSDeviceDescriptionKey("NSScreenNumber")
                    ] as? NSNumber else { return nil }
                    return DSSelectOption<UInt32?>(
                        value: number.uint32Value, title: screen.localizedName
                    )
                })
            DSSettingsRow(
                title: "Magnification",
                detail: magnificationSuppressed
                    ? "Reduce Motion is on, so Dock items stay at their normal size."
                    : "Smoothly enlarges nearby Dock items. Shelf features stay fixed.",
                systemImage: "magnifyingglass"
            ) {
                Toggle("Magnification", isOn: Binding(
                    get: { appModel.preferences.customDockConfiguration.magnificationEnabled },
                    set: { value in appModel.preferences.updateCustomDock { $0.magnificationEnabled = value } }
                ))
                .labelsHidden().toggleStyle(DSSwitchStyle())
            }
            if let warning = appModel.preferences.customDockConfiguration.importWarning {
                DSStatusCard(title: "Apple Dock import", detail: warning,
                             systemImage: "exclamationmark.triangle.fill", role: .warning)
            }
            DSDivider()
            HStack {
                Text("Pinned apps").font(DSTypography.bodyEmphasis)
                Spacer()
                Button("Add App…", action: addCustomDockApplication)
                    .buttonStyle(DSButtonStyle())
            }
            ForEach(appModel.preferences.customDockConfiguration.pinnedApps) { app in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable().frame(width: 24, height: 24)
                    Text(app.title).font(DSTypography.body)
                    Spacer()
                    Button("↑") { appModel.preferences.moveCustomDockApplication(app.id, by: -1) }
                        .buttonStyle(DSButtonStyle()).accessibilityLabel("Move \(app.title) earlier")
                    Button("↓") { appModel.preferences.moveCustomDockApplication(app.id, by: 1) }
                        .buttonStyle(DSButtonStyle()).accessibilityLabel("Move \(app.title) later")
                    Button("Remove") { appModel.preferences.removeCustomDockApplication(app.id) }
                        .buttonStyle(DSButtonStyle(intent: .destructive))
                }
            }
            DSDivider()
            HStack {
                Text("Shelf features").font(DSTypography.bodyEmphasis)
                Spacer()
                DSSelect(title: "Add Shelf feature", selection: Binding<DockFeature?>(
                    get: { nil },
                    set: { if let feature = $0 { appModel.preferences.addCustomDockSlot(feature) } }
                ), options: DockFeature.availableCases.filter { $0 != .dockMagic }.map {
                    .init(value: Optional($0), title: $0.title, icon: $0.shelfIcon)
                }, searchable: true, placeholder: "Add Feature…")
                .frame(width: 180)
            }
            ForEach(appModel.preferences.customDockConfiguration.slots) { slot in
                HStack {
                    DSIcon(slot.feature.shelfIcon, size: 18)
                    Text(slot.feature.title).font(DSTypography.body)
                    Spacer()
                    Button("↑") { appModel.preferences.moveCustomDockSlot(slot.id, by: -1) }
                        .buttonStyle(DSButtonStyle()).accessibilityLabel("Move \(slot.feature.title) earlier")
                    Button("↓") { appModel.preferences.moveCustomDockSlot(slot.id, by: 1) }
                        .buttonStyle(DSButtonStyle()).accessibilityLabel("Move \(slot.feature.title) later")
                    Button("Remove") { appModel.preferences.removeCustomDockSlot(slot.id) }
                        .buttonStyle(DSButtonStyle(intent: .destructive))
                }
            }
            DSDivider()
            HStack {
                Text("Files and folders").font(DSTypography.bodyEmphasis)
                Spacer()
                Button("Add…", action: addCustomDockStack).buttonStyle(DSButtonStyle())
            }
            ForEach(appModel.preferences.customDockConfiguration.stacks) { stack in
                HStack {
                    Text(stack.title).font(DSTypography.body)
                    Spacer()
                    Button("Remove") {
                        appModel.preferences.updateCustomDock {
                            $0.stacks.removeAll { $0.id == stack.id }
                        }
                    }
                    .buttonStyle(DSButtonStyle(intent: .destructive))
                }
            }
        }
    }

    private func addCustomDockApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let app = CustomDockApplication(url: url) {
                appModel.preferences.addCustomDockApplication(app)
            }
        }
    }

    private func addCustomDockStack() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        appModel.preferences.updateCustomDock { config in
            config.stacks.append(contentsOf: panel.urls.map { CustomDockStack(path: $0.path) })
        }
    }

    private var activeFeatureBinding: Binding<DockFeature> {
        Binding(
            get: { appModel.preferences.activeFeature },
            set: { feature in
                appModel.activateFeature(feature)
                switch feature {
                case .nowPlaying:
                    navigate(to: .nowPlaying)
                case .binance:
                    navigate(to: .binance)
                case .calendar:
                    navigate(to: .calendar)
                case .weather:
                    navigate(to: .weather)
                    appModel.weatherStore.refreshLocationAuthorizationStatus()
                    refreshWeather()
                case .batteries:
                    navigate(to: .batteries)
                    appModel.batteryStore.start()
                case .github:
                    navigate(to: .github)
                case .searchConsole:
                    navigate(to: .searchConsole)
                    appModel.searchConsoleStore.start()
                case .codex:
                    navigate(to: .codex)
                case .claudeCode:
                    navigate(to: .claudeCode)
                case .grokBuild:
                    if GrokBuildFeatureGate.experimentalEnabled { navigate(to: .grokBuild) }
                case .openCode:
                    navigate(to: .openCode)
                case .antigravity:
                    navigate(to: .antigravity)
                case .dockMagic, .systemMetrics, .network, .storage, .clock:
                    break
                }
            }
        )
    }

    private func navigate(to destination: SettingsDestination) {
        self.destination = destination
        windowRouter?.navigate(to: destination)
    }

    private func installDeveloperTool(_ tool: DeveloperTool) {
        Task {
            await appModel.prepareDeveloperToolIntegration(
                for: tool.dockFeature
            )
        }
    }

    private func developerToolInstallationIndicator(
        _ tool: DeveloperTool
    ) -> some View {
        let state = appModel.developerToolInstallationStore.state(for: tool)
        let presentation = developerToolInstallationPresentation(
            tool,
            state: state
        )

        return Button {
            installDeveloperTool(tool)
        } label: {
            DSIconPlate(
                systemImage: presentation.systemImage,
                role: presentation.role,
                size: 32
            )
        }
        .buttonStyle(DSContentButtonStyle())
        .disabled(!presentation.allowsAction)
        .help("\(presentation.title). \(presentation.detail)")
        .accessibilityIdentifier(
            "settings.\(tool.rawValue).installationIndicator"
        )
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.detail)
        .accessibilityHint(presentation.actionHint)
    }

    private func developerToolInstallationPresentation(
        _ tool: DeveloperTool,
        state: DeveloperToolInstallationState
    ) -> (
        title: String,
        detail: String,
        systemImage: String,
        role: DSSemanticRole,
        allowsAction: Bool,
        actionHint: String
    ) {
        switch state {
        case .checking:
            (
                title: "Checking for \(tool.title)",
                detail: "DockMagic is checking supported local installation paths.",
                systemImage: "magnifyingglass",
                role: .processing,
                allowsAction: false,
                actionHint: ""
            )
        case .notInstalled:
            (
                title: "\(tool.title) is not installed",
                detail: "Click to install the official user-space CLI without sudo.",
                systemImage: "arrow.down.circle",
                role: .warning,
                allowsAction: true,
                actionHint: "Install \(tool.title)"
            )
        case .installing:
            (
                title: "Installing \(tool.title)",
                detail: "Downloading and running the official installer. Keep DockMagic open until this finishes.",
                systemImage: "arrow.down.circle.fill",
                role: .processing,
                allowsAction: false,
                actionHint: ""
            )
        case let .installed(path):
            (
                title: "\(tool.title) installed",
                detail: "DockMagic is using \(path). Click to check the connection.",
                systemImage: "checkmark.circle.fill",
                role: .information,
                allowsAction: true,
                actionHint: "Check the \(tool.title) connection"
            )
        case let .failed(message):
            (
                title: "\(tool.title) setup failed",
                detail: "\(message) Click to retry.",
                systemImage: "exclamationmark.triangle.fill",
                role: .danger,
                allowsAction: true,
                actionHint: "Retry installing \(tool.title)"
            )
        }
    }

    private var dockHoverEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.preferences.isDockHoverDashboardEnabled },
            set: { appModel.preferences.isDockHoverDashboardEnabled = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginController.state.isRequested },
            set: { launchAtLoginController.setEnabled($0) }
        )
    }

    private var automaticallyChecksForUpdatesBinding: Binding<Bool> {
        Binding(
            get: {
                softwareUpdateController.automaticallyChecksForUpdates
            },
            set: {
                softwareUpdateController
                    .setAutomaticallyChecksForUpdates($0)
            }
        )
    }

    private var automaticallyDownloadsUpdatesBinding: Binding<Bool> {
        Binding(
            get: {
                softwareUpdateController.automaticallyDownloadsUpdates
            },
            set: {
                softwareUpdateController
                    .setAutomaticallyDownloadsUpdates($0)
            }
        )
    }

    private var currentVersionDetail: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "Unknown"
        return "Installed version \(version) (\(build))."
    }

    private var dockHoverPermissionState: DockHoverPermissionState {
        dockHoverPermissionController?.state
            ?? (appModel.preferences.isDockHoverDashboardEnabled
                ? .needsPermission
                : .disabled)
    }

    private var dockHoverPermissionRole: DSSemanticRole {
        switch dockHoverPermissionState {
        case .disabled:
            .neutral
        case .needsPermission:
            .warning
        case .awaitingUserAction:
            .information
        case .authorized:
            .processing
        }
    }

    private var dockHoverPermissionIcon: DSIconName {
        switch dockHoverPermissionState {
        case .disabled:
            .eyeOff
        case .needsPermission:
            .accessibility
        case .awaitingUserAction:
            .clock
        case .authorized:
            .shield
        }
    }

    private var appearanceMode: DSAppearanceMode {
        DSAppearanceMode(rawValue: appearanceRawValue) ?? .system
    }

    private var appearanceBinding: Binding<DSAppearanceMode> {
        Binding(
            get: { appearanceMode },
            set: { newMode in
                appearanceRawValue = newMode.rawValue
                NotificationCenter.default.post(
                    name: DSAppearanceMode.didChangeNotification,
                    object: newMode
                )
            }
        )
    }

    private var clockDisplayStyleBinding: Binding<DockClockDisplayStyle> {
        Binding(
            get: { appModel.preferences.clockConfiguration.displayStyle },
            set: { appModel.preferences.setClockDisplayStyle($0) }
        )
    }

    private var clockFollowsSystemTimeZoneBinding: Binding<Bool> {
        Binding(
            get: {
                appModel.preferences.clockConfiguration.followsSystemTimeZone
            },
            set: { appModel.preferences.setClockFollowsSystemTimeZone($0) }
        )
    }

    private var clockTimeZoneIdentifierBinding: Binding<String> {
        Binding(
            get: { appModel.preferences.clockConfiguration.timeZoneIdentifier },
            set: { appModel.preferences.setClockTimeZoneIdentifier($0) }
        )
    }

    private var systemMetricsOuterColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.systemMetricsAppearance.outerColor.color },
            set: { appModel.preferences.setSystemMetricsOuterColor(DockColor($0)) }
        )
    }

    private var systemMetricsInnerColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.systemMetricsAppearance.innerColor.color },
            set: { appModel.preferences.setSystemMetricsInnerColor(DockColor($0)) }
        )
    }

    private var systemMetricsOuterWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.systemMetricsAppearance.outerWidth },
            set: appModel.preferences.setSystemMetricsOuterWidth
        )
    }

    private var systemMetricsInnerWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.systemMetricsAppearance.innerWidth },
            set: appModel.preferences.setSystemMetricsInnerWidth
        )
    }

    private var systemMetricsDisplayStyleBinding: Binding<DockDisplayStyle> {
        Binding(
            get: { appModel.preferences.systemMetricsAppearance.displayStyle },
            set: appModel.preferences.setSystemMetricsDisplayStyle
        )
    }

    private var networkDownloadColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.networkAppearance.downloadColor.color },
            set: { appModel.preferences.setNetworkDownloadColor(DockColor($0)) }
        )
    }

    private var networkUploadColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.networkAppearance.uploadColor.color },
            set: { appModel.preferences.setNetworkUploadColor(DockColor($0)) }
        )
    }

    private var storageColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.storageAppearance.color.color },
            set: { appModel.preferences.setStorageColor(DockColor($0)) }
        )
    }

    private var storageWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.storageAppearance.width },
            set: appModel.preferences.setStorageWidth
        )
    }

    private var storageDisplayStyleBinding: Binding<DockDisplayStyle> {
        Binding(
            get: { appModel.preferences.storageAppearance.displayStyle },
            set: appModel.preferences.setStorageDisplayStyle
        )
    }

    private var githubStarColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.githubAppearance.starColor.color },
            set: { appModel.preferences.setGitHubStarColor(DockColor($0)) }
        )
    }

    private var githubForkColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.githubAppearance.forkColor.color },
            set: { appModel.preferences.setGitHubForkColor(DockColor($0)) }
        )
    }

    private var githubDisplayStyleBinding: Binding<DockDisplayStyle> {
        Binding(
            get: { appModel.preferences.githubAppearance.displayStyle },
            set: appModel.preferences.setGitHubDisplayStyle
        )
    }

    private var codexOuterColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.codexAppearance.outerColor.color },
            set: { appModel.preferences.setCodexOuterColor(DockColor($0)) }
        )
    }

    private var codexInnerColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.codexAppearance.innerColor.color },
            set: { appModel.preferences.setCodexInnerColor(DockColor($0)) }
        )
    }

    private var codexOuterWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.codexAppearance.outerWidth },
            set: appModel.preferences.setCodexOuterWidth
        )
    }

    private var codexInnerWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.codexAppearance.innerWidth },
            set: appModel.preferences.setCodexInnerWidth
        )
    }

    private var codexDisplayStyleBinding: Binding<DockDisplayStyle> {
        Binding(
            get: { appModel.preferences.codexAppearance.displayStyle },
            set: appModel.preferences.setCodexDisplayStyle
        )
    }

    private var claudeCodeOuterColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.claudeCodeAppearance.outerColor.color },
            set: { appModel.preferences.setClaudeCodeOuterColor(DockColor($0)) }
        )
    }

    private var claudeCodeInnerColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.claudeCodeAppearance.innerColor.color },
            set: { appModel.preferences.setClaudeCodeInnerColor(DockColor($0)) }
        )
    }

    private var claudeCodeOuterWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.claudeCodeAppearance.outerWidth },
            set: appModel.preferences.setClaudeCodeOuterWidth
        )
    }

    private var claudeCodeInnerWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.claudeCodeAppearance.innerWidth },
            set: appModel.preferences.setClaudeCodeInnerWidth
        )
    }

    private var claudeCodeDisplayStyleBinding: Binding<DockDisplayStyle> {
        Binding(
            get: { appModel.preferences.claudeCodeAppearance.displayStyle },
            set: appModel.preferences.setClaudeCodeDisplayStyle
        )
    }

    private var antigravityDisplayStyleBinding: Binding<DockDisplayStyle> {
        Binding(
            get: { appModel.preferences.antigravityAppearance.displayStyle },
            set: appModel.preferences.setAntigravityDisplayStyle
        )
    }

    private var antigravityOuterColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.antigravityAppearance.outerColor.color },
            set: { appModel.preferences.setAntigravityOuterColor(DockColor($0)) }
        )
    }

    private var antigravityInnerColorBinding: Binding<Color> {
        Binding(
            get: { appModel.preferences.antigravityAppearance.innerColor.color },
            set: { appModel.preferences.setAntigravityInnerColor(DockColor($0)) }
        )
    }

    private var antigravityOuterWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.antigravityAppearance.outerWidth },
            set: appModel.preferences.setAntigravityOuterWidth
        )
    }

    private var antigravityInnerWidthBinding: Binding<Double> {
        Binding(
            get: { appModel.preferences.antigravityAppearance.innerWidth },
            set: appModel.preferences.setAntigravityInnerWidth
        )
    }

    private var codexSnapshot: CodexRateLimitSnapshot? {
        appModel.codexStore.state.snapshot
    }

    private var weatherSnapshot: WeatherSnapshot? {
        appModel.weatherStore.state.snapshot
    }

    private func networkValue(_ bytesPerSecond: Double) -> String? {
        guard appModel.networkStore.current.interfaceName != nil else {
            return nil
        }
        return MetricsFormatting.byteRate(bytesPerSecond)
    }

    private func storageValue(_ bytes: UInt64) -> String? {
        guard appModel.storageStore.current.totalBytes > 0 else {
            return nil
        }
        return MetricsFormatting.byteCount(bytes)
    }

    private var weatherPreviewDetail: String {
        if appModel.preferences.activeFeature == .weather {
            return "Weather is active. Fresh results are applied to the Dock every 10 minutes."
        }
        return "Weather is not active, so results update this preview only."
    }

    private var weatherLocationPreviewValue: String? {
        appModel.weatherStore.locationPreviewValue
    }

    private func refreshWeather() {
        Task {
            await appModel.weatherStore.refresh()
        }
    }

    private func refreshWeatherAfterReturningFromSystemSettings() {
        guard destination == .weather else {
            return
        }

        let previousAuthorization = appModel.weatherStore.locationAuthorization
        appModel.weatherStore.refreshLocationAuthorizationStatus()
        guard previousAuthorization != .authorized,
              appModel.weatherStore.locationAuthorization == .authorized
        else {
            return
        }

        refreshWeather()
    }

    private static func temperatureLabel(_ celsius: Double) -> String {
        let usesFahrenheit = Locale.current.measurementSystem == .us
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°\(usesFahrenheit ? "F" : "C")"
    }

    private var claudeCodeSnapshot: ClaudeCodeRateLimitSnapshot? {
        appModel.claudeCodeStore.state.snapshot
    }

    private var antigravityBuckets: [AntigravityQuotaBucket] {
        appModel.antigravityStore.state.snapshot?.quota?.buckets ?? []
    }

    private var codexPreviewDetail: String {
        if appModel.preferences.activeFeature == .codex {
            return "Codex is active. Fresh values are applied to the Dock."
        }
        return "Codex is not active, so changes update this preview only."
    }

    private var claudeCodePreviewDetail: String {
        if appModel.preferences.activeFeature == .claudeCode {
            return "Claude Code is active. Fresh values are applied to the Dock."
        }
        return "Claude Code is not active, so changes update this preview only."
    }

    private var antigravityPreviewDetail: String {
        if appModel.preferences.activeFeature == .antigravity {
            return "Antigravity is active. Each model pool stays separate in the Dock."
        }
        return "Antigravity is not active, so changes update this preview only."
    }

    private static let weatherAttributionURL = URL(
        string: "https://open-meteo.com/"
    )!

    private static let weatherLicenseURL = URL(
        string: "https://open-meteo.com/en/licence"
    )!
}

private struct SoftwareUpdateFooterButton: View {
    let version: String
    let action: () -> Void

    @Environment(\.designTheme) private var theme
    @FocusState private var isFocused: Bool
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.compact) {
                DSIcon(systemName: "arrow.down.circle")
                    .dsFont(size: 14, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text("Update available")
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: DSSpacing.compact)

                Text(version)
                    .font(DSTypography.metadata)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                DSIcon(systemName: "chevron.right")
                    .dsFont(size: 9, weight: .semibold)
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DSSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .dsSurface(
                RoundedRectangle(
                    cornerRadius: DSRadius.row,
                    style: .continuous
                ),
                kind: .chrome
            )
            .dsInteractiveRow(isFocused: isFocused)
        }
        .buttonStyle(DSContentButtonStyle())
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Update available, version \(version)")
        .accessibilityHint("Opens the software update installer")
        .accessibilityIdentifier("settings.updateAvailable")
    }
}

private struct SettingsHeaderView: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.medium) {
            Image("DockMagicLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(
                    Capsule(style: .circular)
                )
                .overlay {
                    Capsule(style: .circular)
                    .strokeBorder(theme.outline, lineWidth: 1)
                }
                .accessibilityHidden(true)

            Text("Settings")
                .font(DSTypography.headline)
                .foregroundStyle(theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DockMagic Settings")
        .accessibilityIdentifier("settings.header")
    }
}

private struct BatteryDeviceStatusRow: View {
    let device: BatteryDeviceSnapshot

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.medium) {
            BatteryDeviceGlyph(
                kind: device.kind,
                color: theme.textPrimary,
                size: 32
            )
            .frame(width: 64, height: 64)
            .dsSurface(
                Capsule(style: .circular),
                kind: .inset
            )

            Text(device.name)
                .dsFont(size: 16, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DSSpacing.small)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(device.percentage)%")
                    .dsFont(size: 20, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(
                        BatteryLevelStyle.foreground(
                            for: device.level,
                            theme: theme
                        )
                    )

                Text(device.detail)
                    .dsFont(size: 14, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(device.name)
        .accessibilityValue(
            "\(device.percentage) percent, \(device.detail)"
        )
    }
}

private struct ActiveDockFeaturePicker: View {
    @Binding var selection: DockFeature

    var body: some View {
        DSSelect(title: "Active Dock feature", selection: $selection,
            options: DockFeature.availableCases.map {
                .init(value: $0, title: $0.title,
                      detail: $0.detail, accessibilityIdentifier: "settings.activeFeatureOption.\($0.rawValue)")
            }, searchable: true, popupWidth: 300,
            optionIdentity: { feature in
                AnyView(DockFeatureIcon(feature: feature, size: 22))
            }, initiallyPresented: initiallyPresentsForUITesting) {
                DSSelectionSummary(title: selection.title, detail: selection.detail) {
                    DockFeatureIcon(feature: selection, size: 24)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("settings.activeFeaturePicker")
            .frame(width: 280, height: 48)
    }

    private var initiallyPresentsForUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment[
            "DockMagicUITestOpenActiveFeaturePicker"
        ] == "1"
        #else
        false
        #endif
    }
}

private struct DockFeatureIcon: View {
    let feature: DockFeature
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch feature {
            case .dockMagic:
                Image("DockMagicLogo")
                    .resizable()
                    .scaledToFill()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: size * 0.28,
                            style: .continuous
                        )
                    )
            case .codex:
                PreservedVectorAssetImage(assetName: "CodexLogo")
                    .scaledToFit()
            case .claudeCode:
                PreservedVectorAssetImage(assetName: "ClaudeCodeLogo")
                    .scaledToFit()
            case .grokBuild:
                GrokBuildIdentityMark()
            case .openCode:
                PreservedVectorAssetImage(assetName: "OpenCodeLogo").scaledToFit()
            case .antigravity:
                PreservedVectorAssetImage(assetName: "AntigravityLogo")
                    .scaledToFit()
            case .github:
                ZStack {
                    Circle()
                        .fill(.white)

                    Image("GitHubLogo")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                }
            case .searchConsole:
                Image("GoogleSearchConsoleLogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            case .weather:
                if let weatherApplicationIcon = Self.weatherApplicationIcon {
                    Image(nsImage: weatherApplicationIcon)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    DSIcon(systemName: featureSystemImage)
                        .symbolRenderingMode(.monochrome)
                        .dsFont(size: size * 0.58, weight: .semibold)
                        .frame(width: size, height: size)
                }
            case .batteries:
                PreservedVectorAssetImage(assetName: "DockFeatureBatteries")
                    .scaledToFit()
            case .binance:
                BinanceBrandIcon(size: size)
            case .systemMetrics:
                PreservedVectorAssetImage(assetName: "DockFeatureCPUAndRAM")
                    .scaledToFit()
            case .network:
                PreservedVectorAssetImage(assetName: "DockFeatureNetwork")
                    .scaledToFit()
            case .storage:
                PreservedVectorAssetImage(assetName: "DockFeatureStorage")
                    .scaledToFit()
            case .clock:
                PreservedVectorAssetImage(assetName: "DockFeatureClock")
                    .scaledToFit()
            case .calendar:
                PreservedVectorAssetImage(assetName: "DockFeatureCalendar")
                    .scaledToFit()
            case .nowPlaying:
                PreservedVectorAssetImage(assetName: "DockFeatureNowPlaying")
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let weatherApplicationIcon: NSImage? = {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.weather"
        ) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.isTemplate = false
        return icon
    }()

    private var featureSystemImage: String {
        switch feature {
        case .dockMagic:
            "dock.rectangle"
        case .systemMetrics:
            "cpu"
        case .network:
            "network"
        case .storage:
            "internaldrive.fill"
        case .weather:
            "cloud.sun.fill"
        case .calendar:
            "calendar"
        case .nowPlaying:
            "music.note"
        case .clock:
            "clock.fill"
        case .batteries:
            "battery.75percent"
        case .github:
            "point.3.connected.trianglepath.dotted"
        case .codex:
            "sparkles"
        case .claudeCode:
            "chevron.left.forwardslash.chevron.right"
        case .grokBuild:
            "g.circle"
        case .openCode:
            "terminal"
        case .antigravity:
            "sparkle"
        case .binance:
            "chart.xyaxis.line"
        case .searchConsole:
            "magnifyingglass"
        }
    }
}

/// Settings may be hosted in an AppKit window, where SwiftUI's color scheme
/// alone does not change the appearance used to resolve asset catalog colors.
private struct SettingsWindowPresentationBridge: NSViewRepresentable {
    let appearanceMode: DSAppearanceMode

    func makeNSView(context: Context) -> WindowPresentationView {
        WindowPresentationView()
    }

    func updateNSView(
        _ nsView: WindowPresentationView,
        context: Context
    ) {
        nsView.applyPresentation(appearanceMode: appearanceMode)
    }
}

private final class WindowPresentationView: NSView {
    private var appearanceMode: DSAppearanceMode = .system

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyPresentation(appearanceMode: appearanceMode)
    }

    func applyPresentation(appearanceMode: DSAppearanceMode) {
        self.appearanceMode = appearanceMode
        guard let window else {
            return
        }

        switch appearanceMode {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }

        // Keep the scene title for routing and accessibility while the sidebar
        // header owns the visible title treatment.
        window.titleVisibility = .hidden

        // SwiftUI can reapply the scene title while the window is being
        // configured. Apply this again on the next run loop so only the
        // branded sidebar header is visible.
        DispatchQueue.main.async { [weak window] in
            window?.titleVisibility = .hidden
        }
    }
}

struct DockDisplayStyleEditor: View {
    let featureTitle: String
    @Binding var selection: DockDisplayStyle

    var body: some View {
        DSSettingsSection(
            title: "Dock display",
            detail: "Choose whether \(featureTitle) uses progress rings or direct numeric values in the Dock."
        ) {
            DSSegmentedControl(title: "\(featureTitle) Dock display style", selection: $selection,
                options: DockDisplayStyle.allCases.map {
                    .init(value: $0, title: $0.title, icon: DSIconName.fromLegacySymbol($0.systemImage),
                          accessibilityIdentifier: "settings.displayStyleOption.\($0.rawValue)")
                })
            .accessibilityIdentifier("settings.displayStyle")
        }
    }
}

struct RingAppearanceEditor: View {
    let outerTitle: String
    let innerTitle: String
    let appearance: DockRingAppearance
    let outerColor: Binding<Color>
    let innerColor: Binding<Color>
    let outerWidth: Binding<Double>
    let innerWidth: Binding<Double>
    let reset: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSettingsSection(
            title: appearance.displayStyle == .chart
                ? "Ring appearance"
                : "Number appearance",
            detail: appearance.displayStyle == .chart
                ? "Widths are constrained automatically so both rings stay clear at small Dock sizes."
                : "The two numeric values keep the same semantic colors as their chart rings."
        ) {
            colorRow(
                title: appearanceTitle(outerTitle),
                color: outerColor,
                hex: appearance.outerColor.hex
            )

            if appearance.displayStyle == .chart {
                widthRow(
                    title: "\(outerTitle) ring width",
                    value: outerWidth,
                    range: DockRingAppearance.minimumOuterWidth
                        ... DockRingAppearance.maximumOuterWidth
                )
            }

            DSDivider()

            colorRow(
                title: appearanceTitle(innerTitle),
                color: innerColor,
                hex: appearance.innerColor.hex
            )

            if appearance.displayStyle == .chart {
                widthRow(
                    title: "\(innerTitle) ring width",
                    value: innerWidth,
                    range: DockRingAppearance.minimumInnerWidth
                        ... DockRingAppearance.maximumInnerWidth
                )
            }

            HStack {
                Spacer()
                Button(action: reset) {
                    DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.rings.reset")
            }
        }
    }

    private func appearanceTitle(_ title: String) -> String {
        "\(title) \(appearance.displayStyle == .chart ? "ring" : "value")"
    }

    private func colorRow(
        title: String,
        color: Binding<Color>,
        hex: String
    ) -> some View {
        HStack(spacing: DSSpacing.standard) {
            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            DSColorPalettePicker(
                selection: color,
                selectionHex: hex,
                options: ProjectTheme.rendererColorOptions,
                accessibilityLabel: title,
                identifier: "settings.ringColor.\(controlIdentifier(for: title))"
            )
        }
        .frame(minHeight: 40)
    }

    private func widthRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: DSSpacing.standard) {
            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            DSSlider(value: value, in: range)
                .frame(maxWidth: DSLayout.sliderMaximumWidth)
                .accessibilityLabel(title)
                .accessibilityValue(
                    "\(Int((value.wrappedValue * 100).rounded())) percent"
                )
                .accessibilityIdentifier(
                    "settings.ringWidth.\(controlIdentifier(for: title))"
                )

            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .font(DSTypography.keycap)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 34, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 28)
    }

    private func controlIdentifier(for title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: ".")
    }
}

private struct NetworkAppearanceEditor: View {
    let appearance: DockNetworkAppearance
    let downloadColor: Binding<Color>
    let uploadColor: Binding<Color>
    let reset: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSettingsSection(
            title: "Chart appearance",
            detail: "Download and upload keep distinct colors in the Dock chart and live preview."
        ) {
            colorRow(
                title: "Download",
                color: downloadColor,
                hex: appearance.downloadColor.hex,
                identifier: "download"
            )

            DSDivider()

            colorRow(
                title: "Upload",
                color: uploadColor,
                hex: appearance.uploadColor.hex,
                identifier: "upload"
            )

            HStack {
                Spacer()
                Button(action: reset) {
                    DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.network.reset")
            }
        }
    }

    private func colorRow(
        title: String,
        color: Binding<Color>,
        hex: String,
        identifier: String
    ) -> some View {
        HStack(spacing: DSSpacing.standard) {
            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            DSColorPalettePicker(
                selection: color,
                selectionHex: hex,
                options: ProjectTheme.rendererColorOptions,
                accessibilityLabel: "\(title) chart color",
                identifier: "settings.network.color.\(identifier)"
            )
        }
        .frame(minHeight: 40)
    }
}

private struct SingleRingAppearanceEditor: View {
    let colorTitle: String
    let appearance: DockSingleRingAppearance
    let color: Binding<Color>
    let width: Binding<Double>
    let reset: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSettingsSection(
            title: appearance.displayStyle == .chart
                ? "Ring appearance"
                : "Number appearance",
            detail: appearance.displayStyle == .chart
                ? "Storage uses one ring because used and available space are complementary values."
                : "The numeric style shows the percentage of storage currently used."
        ) {
            HStack(spacing: DSSpacing.standard) {
                Text(
                    "\(colorTitle) \(appearance.displayStyle == .chart ? "ring" : "value")"
                )
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: DSSpacing.standard)

                DSColorPalettePicker(
                    selection: color,
                    selectionHex: appearance.color.hex,
                    options: ProjectTheme.rendererColorOptions,
                    accessibilityLabel: colorTitle,
                    identifier: "settings.storage.color"
                )
            }
            .frame(minHeight: 40)

            if appearance.displayStyle == .chart {
                HStack(spacing: DSSpacing.standard) {
                    Text("Ring width")
                        .font(DSTypography.body)
                        .foregroundStyle(theme.textPrimary)

                    Spacer(minLength: DSSpacing.standard)

                    DSSlider(
                        value: width,
                        in: DockSingleRingAppearance.minimumWidth
                            ... DockSingleRingAppearance.maximumWidth
                    )
                    .frame(maxWidth: DSLayout.sliderMaximumWidth)
                    .accessibilityLabel("Storage ring width")
                    .accessibilityValue(
                        "\(Int((width.wrappedValue * 100).rounded())) percent"
                    )
                    .accessibilityIdentifier("settings.storage.width")

                    Text("\(Int((width.wrappedValue * 100).rounded()))%")
                        .font(DSTypography.keycap)
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 34, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 28)
            }

            HStack {
                Spacer()
                Button(action: reset) {
                    DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.storage.reset")
            }
        }
    }
}

private struct PreviewTextMetric: View {
    let title: String
    let value: String?
    let color: Color
    let systemImage: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.standard) {
            DSIcon(systemName: systemImage)
                .dsFont(size: 12, weight: .semibold)
                .foregroundStyle(color)
                .frame(width: 12)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text(value ?? "—")
                .font(DSTypography.metric)
                .monospacedDigit()
                .foregroundStyle(value == nil ? theme.textTertiary : color)
        }
        .padding(DSSpacing.standard)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.row,
                style: .continuous
            ),
            kind: .inset
        )
        .accessibilityElement(children: .combine)
    }
}

struct PreviewMetric: View {
    let title: String
    let value: Double?
    let color: Color

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.standard) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text(formattedValue)
                .font(DSTypography.metric)
                .monospacedDigit()
                .foregroundStyle(value == nil ? theme.textTertiary : color)
        }
        .padding(DSSpacing.standard)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.row,
                style: .continuous
            ),
            kind: .inset
        )
        .accessibilityElement(children: .combine)
    }

    private var formattedValue: String {
        guard let value else {
            return "—"
        }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct WeatherPreviewValue: View {
    let title: String
    let value: String?
    let systemImage: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.standard) {
            DSIcon(systemName: systemImage)
                .dsFont(size: 12, weight: .semibold)
                .foregroundStyle(theme.informationForeground)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            Text(value ?? "—")
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(
                    value == nil
                        ? theme.textTertiary
                        : theme.informationForeground
                )
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(DSSpacing.standard)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous),
            kind: .inset
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    DockMagicThemeRoot(
        content: SettingsView(appModel: DockAppModel())
    )
}
