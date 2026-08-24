import AppKit
import SwiftUI

enum SettingsDestination: String, CaseIterable, Identifiable {
    case general
    case systemMetrics
    case network
    case storage
    case weather
    case batteries
    case github
    case codex
    case claudeCode
    case searchConsole
    case about

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
        case .batteries:
            "Batteries"
        case .github:
            "GitHub"
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
        case .searchConsole:
            "Search Console"
        case .about:
            "About"
        }
    }

    var detail: String {
        switch self {
        case .general:
            "Choose the single feature shown in your Dock."
        case .systemMetrics:
            "Customize live CPU and memory rings."
        case .network:
            "Monitor live download and upload throughput."
        case .storage:
            "Monitor usage on the startup disk."
        case .weather:
            "Show current conditions supplied by Open-Meteo."
        case .batteries:
            "Monitor your Mac and connected devices."
        case .github:
            "Track repository stars and forks in the Dock."
        case .codex:
            "Show Codex rate limits and aggregate token usage."
        case .claudeCode:
            "Show remaining 5-hour and weekly Claude Code limits."
        case .searchConsole:
            "A focused view of your Google Search performance."
        case .about:
            "Version, privacy, and distribution details."
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
        case .batteries:
            "battery.75percent"
        case .github:
            "point.3.connected.trianglepath.dotted"
        case .codex:
            "sparkles"
        case .claudeCode:
            "chevron.left.forwardslash.chevron.right"
        case .searchConsole:
            "magnifyingglass"
        case .about:
            "info.circle"
        }
    }

    var feature: DockFeature? {
        switch self {
        case .general, .about:
            nil
        case .systemMetrics:
            .systemMetrics
        case .network:
            .network
        case .storage:
            .storage
        case .weather:
            .weather
        case .batteries:
            .batteries
        case .github:
            .github
        case .codex:
            .codex
        case .claudeCode:
            .claudeCode
        case .searchConsole:
            .searchConsole
        }
    }
}

@MainActor
struct SettingsView: View {
    let appModel: DockAppModel
    let dockHoverPermissionController: DockHoverPermissionController?

    @State private var destination: SettingsDestination
    @AppStorage(DSAppearanceMode.storageKey)
    private var appearanceRawValue = DSAppearanceMode.system.rawValue
    @Environment(\.designTheme) private var theme

    init(
        appModel: DockAppModel,
        dockHoverPermissionController: DockHoverPermissionController? = nil,
        initialDestination: SettingsDestination = .general
    ) {
        self.appModel = appModel
        self.dockHoverPermissionController = dockHoverPermissionController
        _destination = State(initialValue: initialDestination)
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
        .background(SettingsWindowTitleVisibilityBridge())
        .onChange(of: destination, initial: true) { _, newDestination in
            switch newDestination {
            case .weather:
                appModel.weatherStore.refreshLocationAuthorizationStatus()
                refreshWeather()
            case .batteries:
                appModel.batteryStore.start()
            case .searchConsole:
                appModel.searchConsoleStore.start()
            case .general, .systemMetrics, .network, .storage, .codex,
                 .claudeCode, .github, .about:
                if appModel.preferences.activeFeature != .batteries {
                    appModel.batteryStore.stop()
                }
                if appModel.preferences.activeFeature != .searchConsole {
                    appModel.searchConsoleStore.stop()
                }
                break
            }
        }
        .onDisappear {
            if appModel.preferences.activeFeature != .batteries {
                appModel.batteryStore.stop()
            }
            if appModel.preferences.activeFeature != .searchConsole {
                appModel.searchConsoleStore.stop()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            refreshWeatherAfterReturningFromSystemSettings()
            dockHoverPermissionController?.refresh()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            SettingsHeaderView()
                .padding(DSSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsSurface(
                    RoundedRectangle(
                        cornerRadius: DSRadius.largePanel,
                        style: .continuous
                    ),
                    kind: .chrome,
                    elevation: .primary
                )
                .padding(.horizontal, DSSpacing.medium)
                .padding(.top, DSSpacing.small)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                    sidebarRow(.general)

                    Text("Features")
                        .font(DSTypography.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)
                        .padding(.top, DSSpacing.medium)
                        .padding(.horizontal, DSSpacing.small)
                        .accessibilityAddTraits(.isHeader)

                    sidebarRow(.systemMetrics)
                    sidebarRow(.network)
                    sidebarRow(.storage)
                    sidebarRow(.weather)
                    sidebarRow(.batteries)
                    sidebarRow(.github)
                    sidebarRow(.codex)
                    sidebarRow(.claudeCode)
                    sidebarRow(.searchConsole)

                    DSDivider()
                        .padding(.vertical, DSSpacing.small)

                    sidebarRow(.about)
                }
                .padding(.horizontal, DSSpacing.medium)
                .padding(.vertical, DSSpacing.small)
            }

            HStack(spacing: DSSpacing.compact) {
                Image(systemName: appearanceMode.systemImage)
                    .accessibilityHidden(true)
                Text("\(appearanceMode.title) appearance")
            }
            .font(DSTypography.metadata)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, DSSpacing.medium)
            .padding(.vertical, DSSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .dsSurface(
                Capsule(),
                kind: .chrome,
                elevation: .secondary
            )
            .padding(DSSpacing.medium)
            .accessibilityIdentifier("settings.appearanceBadge")
        }
        .background(theme.opaqueSurfaceChrome)
    }

    private func sidebarRow(_ item: SettingsDestination) -> some View {
        Button {
            destination = item
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
                        .fill(theme.processingForeground)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DSSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background {
                if destination == item {
                    RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    )
                    .fill(theme.sidebarSelectionFill)
                    .accessibilityHidden(true)
                }
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: DSRadius.control,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
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

                Image(systemName: item.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.onSidebarIcon)
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: 13, weight: .semibold))
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
        case .batteries:
            batteriesContent
        case .github:
            githubContent
        case .codex:
            codexContent
        case .claudeCode:
            claudeCodeContent
        case .searchConsole:
            searchConsoleContent
        case .about:
            aboutContent
        }
    }

    private var generalContent: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(
                title: "Appearance",
                detail: appearanceMode.detail
            ) {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(DSAppearanceMode.settingsCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                            .accessibilityIdentifier(
                                "settings.appearanceOption.\(mode.rawValue)"
                            )
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
                .accessibilityValue(appearanceMode.title)
                .accessibilityIdentifier("settings.appearancePicker")
            }

            DSSettingsSection(
                title: "Dock",
                detail: "Choose the single feature DockMagic shows and updates in the Dock."
            ) {
                DSSettingsRow(
                    title: "Active Dock Feature",
                    detail: appModel.preferences.activeFeature.detail,
                    systemImage: "dock.rectangle"
                ) {
                    ActiveDockFeaturePicker(selection: activeFeatureBinding)
                }
            }

            DSSettingsSection(
                title: "Dock hover dashboard",
                detail: "Show a read-only dashboard above DockMagic when its Dock icon is hovered. Codex includes rate limits and a seven-day token chart."
            ) {
                VStack(spacing: DSSpacing.standard) {
                    DSSettingsRow(
                        title: "Show dashboard on Dock hover",
                        detail: "Off by default. Requires Accessibility to detect only DockMagic's own Dock item and position."
                    ) {
                        Toggle(
                            "Show dashboard on Dock hover",
                            isOn: dockHoverEnabledBinding
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.dockHover.toggle")
                    }

                    if appModel.preferences.isDockHoverDashboardEnabled {
                        DSDivider()

                        HStack(alignment: .top, spacing: DSSpacing.medium) {
                            DSIconPlate(
                                systemImage: dockHoverPermissionSystemImage,
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
            .buttonStyle(DSButtonStyle(kind: .primary))
            .disabled(dockHoverPermissionController == nil)
            .accessibilityIdentifier("settings.dockHover.allow")
        case .awaitingUserAction:
            HStack(spacing: DSSpacing.compact) {
                Button("Open System Settings") {
                    dockHoverPermissionController?.openAccessibilitySettings()
                }
                .buttonStyle(DSButtonStyle(kind: .primary))

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
                Image(systemName: "battery.0percent")
                    .font(.system(size: 28, weight: .medium))
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
            featurePreviewSection(
                title: "Codex Dock preview",
                detail: codexPreviewDetail
            ) {
                DockCodexView(
                    state: appModel.codexStore.state,
                    appearance: appModel.preferences.codexAppearance,
                    animatesChanges: true
                )
            } values: {
                PreviewMetric(
                    title: "5-hour left",
                    value: codexSnapshot?.fiveHour?.remainingFraction,
                    color: appModel.preferences.codexAppearance.outerColor.color
                )
                PreviewMetric(
                    title: "Weekly left",
                    value: codexSnapshot?.weekly?.remainingFraction,
                    color: appModel.preferences.codexAppearance.innerColor.color
                )
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

    private var aboutContent: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(
                title: "DockMagic",
                detail: "A focused macOS utility that turns its own Dock icon into live information."
            ) {
                LabeledContent("Version", value: "1.0")
                LabeledContent("Appearance", value: appearanceMode.title)
                LabeledContent(
                    "Features",
                    value: "CPU & RAM, Network, Storage, Weather, Batteries, GitHub, Codex, Claude Code"
                )
            }

            DSSettingsSection(
                title: "Distribution",
                detail: "DockMagic is distributed directly instead of through the Mac App Store."
            ) {
                DSStatusCard(
                    title: "Release hardening required",
                    detail: "Production builds should use Developer ID signing, Hardened Runtime, notarization, and stapling.",
                    systemImage: "checkmark.shield.fill",
                    role: .information
                )
            }

            DSSettingsSection(
                title: "Data boundaries",
                detail: "CPU, memory, network, storage, and battery metrics remain local. GitHub receives the configured repository path every 15 minutes while active; Weather sends current coordinates to Open-Meteo; Codex uses the automatically detected CLI for rate limits and aggregate account token totals; Claude Code uses a local status line snapshot containing only rate_limits."
            ) {
                Text("Battery status is read from public local macOS power-source and device-registry APIs; DockMagic does not pair with devices or retain a connection history. It stores only the last successful weather result and up to seven days of GitHub count history. An optional GitHub token is kept only in macOS Keychain. DockMagic reads Codex's aggregate daily and lifetime token counts, but does not inspect prompts, conversations, transcripts, or Claude Code OAuth tokens. Open-Meteo data is used under CC BY 4.0.")
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textSecondary)
            }
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

    private var activeFeatureBinding: Binding<DockFeature> {
        Binding(
            get: { appModel.preferences.activeFeature },
            set: { feature in
                appModel.preferences.activeFeature = feature
                switch feature {
                case .weather:
                    destination = .weather
                    appModel.weatherStore.refreshLocationAuthorizationStatus()
                    refreshWeather()
                case .batteries:
                    destination = .batteries
                    appModel.batteryStore.start()
                case .github:
                    destination = .github
                case .searchConsole:
                    destination = .searchConsole
                    appModel.searchConsoleStore.start()
                case .dockMagic, .systemMetrics, .network, .storage, .codex,
                     .claudeCode:
                    break
                }
            }
        )
    }

    private var dockHoverEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.preferences.isDockHoverDashboardEnabled },
            set: { appModel.preferences.isDockHoverDashboardEnabled = $0 }
        )
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

    private var dockHoverPermissionSystemImage: String {
        switch dockHoverPermissionState {
        case .disabled:
            "eye.slash"
        case .needsPermission:
            "accessibility"
        case .awaitingUserAction:
            "clock.badge.questionmark"
        case .authorized:
            "checkmark.shield.fill"
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

    private static let weatherAttributionURL = URL(
        string: "https://open-meteo.com/"
    )!

    private static let weatherLicenseURL = URL(
        string: "https://open-meteo.com/en/licence"
    )!
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
                    RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    )
                    .strokeBorder(theme.outline, lineWidth: 1)
                }
                .shadow(color: theme.shadow, radius: 4, y: 2)
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
                RoundedRectangle(
                    cornerRadius: DSRadius.control,
                    style: .continuous
                ),
                kind: .inset
            )

            Text(device.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DSSpacing.small)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(device.percentage)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        BatteryLevelStyle.foreground(
                            for: device.level,
                            theme: theme
                        )
                    )

                Text(device.detail)
                    .font(.system(size: 14, weight: .medium))
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

    @State private var isChoosingFeature = false
    @Environment(\.designTheme) private var theme

    var body: some View {
        Button {
            isChoosingFeature.toggle()
        } label: {
            selectedFeatureField
        }
        .buttonStyle(.plain)
        .contentShape(
            RoundedRectangle(
                cornerRadius: DSRadius.control,
                style: .continuous
            )
        )
        .popover(isPresented: $isChoosingFeature, arrowEdge: .bottom) {
            featureOptions
        }
        .accessibilityLabel(
            "Active Dock feature with \(selection.title) icon"
        )
        .accessibilityValue(selection.title)
        .accessibilityIdentifier("settings.activeFeaturePicker")
        .frame(width: 280, height: 48)
        .fixedSize()
    }

    private var featureOptions: some View {
        VStack(spacing: DSSpacing.xSmall) {
            ForEach(DockFeature.allCases) { feature in
                ActiveDockFeatureOption(
                    feature: feature,
                    isSelected: selection == feature
                ) {
                    selection = feature
                    isChoosingFeature = false
                }
                .accessibilityIdentifier(
                    "settings.activeFeatureOption.\(feature.rawValue)"
                )
            }
        }
        .padding(DSSpacing.small)
        .background(theme.opaqueSurfaceRaised)
    }

    private var selectedFeatureField: some View {
        HStack(spacing: DSSpacing.medium) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: DSRadius.keycap,
                    style: .continuous
                )
                .fill(theme.selectionFill)

                RoundedRectangle(
                    cornerRadius: DSRadius.keycap,
                    style: .continuous
                )
                .strokeBorder(theme.selectionOutline, lineWidth: 1)

                DockFeatureIcon(feature: selection, size: 24)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(selection.title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(selection.detail)
                    .font(DSTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DSSpacing.small)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, DSSpacing.medium)
        .frame(width: 280, height: 48)
        .background(
            theme.opaqueSurfaceRaised,
            in: RoundedRectangle(
                cornerRadius: DSRadius.control,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DSRadius.control,
                style: .continuous
            )
            .strokeBorder(theme.outline, lineWidth: 1)
            .allowsHitTesting(false)
        }
        .shadow(color: theme.shadow.opacity(0.34), radius: 3, y: 1)
    }
}

private struct ActiveDockFeatureOption: View {
    let feature: DockFeature
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.standard) {
                DockFeatureIcon(feature: feature, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(DSTypography.bodyEmphasis)
                        .foregroundStyle(theme.textPrimary)

                    Text(feature.detail)
                        .font(DSTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DSSpacing.small)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.action)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DSSpacing.standard)
            .frame(width: 280, height: 44, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    )
                    .fill(theme.selectionFill)
                }
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: DSRadius.control,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private struct DockFeatureIcon: View {
    let feature: DockFeature
    var size: CGFloat = 22

    @Environment(\.designTheme) private var theme

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
                Image("CodexLogo")
                    .resizable()
                    .scaledToFit()
            case .claudeCode:
                Image("ClaudeCodeLogo")
                    .resizable()
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
                    Image(systemName: featureSystemImage)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: size * 0.58, weight: .semibold))
                        .frame(width: size, height: size)
                }
            case .batteries:
                Image(systemName: featureSystemImage)
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(BatteryLevelStyle.healthy)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(
                            cornerRadius: max(5, size * 0.32),
                            style: .continuous
                        )
                        .fill(theme.surfaceChrome)
                    )
            case .systemMetrics, .network, .storage:
                Image(systemName: featureSystemImage)
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(theme.processingForeground)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(
                            cornerRadius: max(5, size * 0.32),
                            style: .continuous
                        )
                        .fill(theme.surfaceChrome)
                    )
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
        case .batteries:
            "battery.75percent"
        case .github:
            "point.3.connected.trianglepath.dotted"
        case .codex:
            "sparkles"
        case .claudeCode:
            "chevron.left.forwardslash.chevron.right"
        case .searchConsole:
            "magnifyingglass"
        }
    }
}

/// SwiftUI does not expose `NSWindow.titleVisibility`. Keep the scene's title
/// intact for window routing and accessibility while the sidebar header owns
/// the visible title treatment.
private struct SettingsWindowTitleVisibilityBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowTitleVisibilityView {
        WindowTitleVisibilityView()
    }

    func updateNSView(
        _ nsView: WindowTitleVisibilityView,
        context: Context
    ) {
        nsView.applyTitleVisibility()
    }
}

private final class WindowTitleVisibilityView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyTitleVisibility()
    }

    func applyTitleVisibility() {
        guard let window else {
            return
        }

        window.titleVisibility = .hidden

        // SwiftUI can reapply the scene title while the window is being
        // configured. Apply this again on the next run loop so only the
        // branded sidebar header is visible.
        DispatchQueue.main.async { [weak window] in
            window?.titleVisibility = .hidden
        }
    }
}

private struct DockDisplayStyleEditor: View {
    let featureTitle: String
    @Binding var selection: DockDisplayStyle

    var body: some View {
        DSSettingsSection(
            title: "Dock display",
            detail: "Choose whether \(featureTitle) uses progress rings or direct numeric values in the Dock."
        ) {
            Picker("Dock display style", selection: $selection) {
                ForEach(DockDisplayStyle.allCases) { style in
                    Label(style.title, systemImage: style.systemImage)
                        .tag(style)
                        .accessibilityIdentifier(
                            "settings.displayStyleOption.\(style.rawValue)"
                        )
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .accessibilityLabel("\(featureTitle) Dock display style")
            .accessibilityValue(selection.title)
            .accessibilityIdentifier("settings.displayStyle")
        }
    }
}

private struct RingAppearanceEditor: View {
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
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
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

            Slider(value: value, in: range)
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
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
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

                    Slider(
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
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
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
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
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

private struct PreviewMetric: View {
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
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
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
