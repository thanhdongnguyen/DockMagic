import AppKit
import SwiftUI

enum WeatherSystemSettings {
    static let locationServicesURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"
    )!
    static let privacyAndSecurityURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
    )!

    @MainActor
    @discardableResult
    static func openLocationServices() -> Bool {
        if NSWorkspace.shared.open(locationServicesURL) {
            return true
        }
        return NSWorkspace.shared.open(privacyAndSecurityURL)
    }
}

enum SettingsDestination: String, CaseIterable, Identifiable {
    case general
    case systemMetrics
    case network
    case storage
    case weather
    case codex
    case claudeCode
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
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
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
        case .codex:
            "Show remaining 5-hour and weekly Codex limits."
        case .claudeCode:
            "Show remaining 5-hour and weekly Claude Code limits."
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
        case .codex:
            "sparkles"
        case .claudeCode:
            "chevron.left.forwardslash.chevron.right"
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
        case .codex:
            .codex
        case .claudeCode:
            .claudeCode
        }
    }
}

@MainActor
struct SettingsView: View {
    let appModel: DockAppModel

    @State private var destination: SettingsDestination
    @Environment(\.designTheme) private var theme

    init(
        appModel: DockAppModel,
        initialDestination: SettingsDestination = .general
    ) {
        self.appModel = appModel
        _destination = State(initialValue: initialDestination)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: 190,
                    ideal: 220,
                    max: 260
                )
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SettingsHeaderView()
            }
        }
        .background(SettingsWindowTitleVisibilityBridge())
        .onChange(of: destination, initial: true) { _, newDestination in
            guard newDestination == .weather else {
                return
            }
            appModel.weatherStore.refreshLocationAuthorizationStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            refreshWeatherAfterReturningFromSystemSettings()
        }
    }

    private var sidebar: some View {
        List {
            Section {
                sidebarRow(.general)
            }

            Section("Features") {
                sidebarRow(.systemMetrics)
                sidebarRow(.network)
                sidebarRow(.storage)
                sidebarRow(.weather)
                sidebarRow(.codex)
                sidebarRow(.claudeCode)
            }

            Section {
                sidebarRow(.about)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.opaqueSurfaceChrome)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: DSSpacing.compact) {
                Image(systemName: "sun.max.fill")
                    .accessibilityHidden(true)
                Text("Light appearance")
            }
            .font(DSTypography.metadata)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, DSSpacing.panel)
            .padding(.vertical, DSSpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sidebarRow(_ item: SettingsDestination) -> some View {
        Button {
            destination = item
        } label: {
            HStack(spacing: DSSpacing.standard) {
                sidebarIcon(item)

                Text(item.title)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if item.feature == appModel.preferences.activeFeature {
                    Circle()
                        .fill(theme.processing)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
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
        .listRowInsets(
            EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8)
        )
        .listRowBackground(Color.clear)
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
        if item == .general {
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
        } else if item == .codex || item == .claudeCode {
            Image(item == .codex ? "CodexLogo" : "ClaudeCodeLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    item == .systemMetrics
                        || item == .network
                        || item == .storage
                        || item == .weather
                        ? theme.processing
                        : theme.textSecondary
                )
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
                .padding(28)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityIdentifier("settings.\(destination.rawValue)")
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
        .padding(.bottom, DSSpacing.compact)
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
        case .codex:
            codexContent
        case .claudeCode:
            claudeCodeContent
        case .about:
            aboutContent
        }
    }

    private var generalContent: some View {
        DSSettingsSection(
            title: "Dock",
            detail: "Choose the single feature DockMagic shows and updates in the Dock."
        ) {
            DSSettingsRow(
                title: "Active Dock Feature",
                detail: appModel.preferences.activeFeature.detail,
                systemImage: "dock.rectangle"
            ) {
                Picker(
                    "Active Dock feature",
                    selection: activeFeatureBinding
                ) {
                    ForEach(DockFeature.allCases) { feature in
                        Text(feature.title)
                            .tag(feature)
                            .accessibilityIdentifier(
                                "settings.activeFeatureOption.\(feature.rawValue)"
                            )
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 154)
                .accessibilityIdentifier("settings.activeFeaturePicker")
            }
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

            RingAppearanceEditor(
                outerTitle: "CPU ring",
                innerTitle: "RAM ring",
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
            } else {
                DSStatusCard(
                    title: appModel.metricsStore.isMonitoring ? "Updating every second" : "Paused while inactive",
                    detail: appModel.metricsStore.isMonitoring
                        ? "Only the current sample is sent to the Dock renderer."
                        : "Select CPU & RAM in General to resume local sampling.",
                    systemImage: appModel.metricsStore.isMonitoring
                        ? "waveform.path.ecg"
                        : "pause.circle",
                    role: appModel.metricsStore.isMonitoring ? .processing : .neutral
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

            DSSettingsSection(
                title: "60-second history",
                detail: "Upload is above the baseline and download is below it. Both directions share one honest scale."
            ) {
                NetworkHistoryChart(
                    history: appModel.networkStore.history,
                    appearance: appModel.preferences.networkAppearance
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
            } else {
                DSStatusCard(
                    title: appModel.networkStore.isMonitoring
                        ? "Updating every second"
                        : "Paused while inactive",
                    detail: appModel.networkStore.isMonitoring
                        ? "Only the primary interface is measured to avoid counting VPN and physical traffic twice."
                        : "Select Network in General to start local throughput sampling.",
                    systemImage: appModel.networkStore.isMonitoring
                        ? "waveform.path.ecg"
                        : "pause.circle",
                    role: appModel.networkStore.isMonitoring ? .processing : .neutral
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
                    color: theme.information,
                    systemImage: "internaldrive"
                )
                PreviewTextMetric(
                    title: "Total",
                    value: storageValue(appModel.storageStore.current.totalBytes),
                    color: theme.textSecondary,
                    systemImage: "externaldrive"
                )
            }

            SingleRingAppearanceEditor(
                title: "Ring appearance",
                detail: "Storage uses one ring because used and available space are complementary values.",
                colorTitle: "Storage ring",
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
            } else {
                DSStatusCard(
                    title: appModel.storageStore.isMonitoring
                        ? "Updating every five seconds"
                        : "Paused while inactive",
                    detail: appModel.storageStore.isMonitoring
                        ? "Capacity is read locally from the startup volume."
                        : "Select Storage in General to resume local sampling.",
                    systemImage: appModel.storageStore.isMonitoring
                        ? "internaldrive.fill"
                        : "pause.circle",
                    role: appModel.storageStore.isMonitoring ? .processing : .neutral
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
                    value: weatherSnapshot?.location,
                    systemImage: "location"
                )
            }

            weatherAttribution

            weatherConnectionSection
            weatherSetupSection
        }
    }

    private var weatherAttribution: some View {
        HStack(spacing: DSSpacing.compact) {
            Spacer()

            Text("Weather data by")
                .foregroundStyle(theme.textTertiary)

            Link("Open-Meteo", destination: Self.weatherAttributionURL)
                .accessibilityLabel("Open-Meteo weather data")
                .accessibilityIdentifier("settings.weather.attribution")

            Text("·")
                .foregroundStyle(theme.textTertiary)

            Link("CC BY 4.0", destination: Self.weatherLicenseURL)
        }
        .font(DSTypography.metadata)
        .padding(.horizontal, DSSpacing.compact)
    }

    private var weatherConnectionSection: some View {
        DSSettingsSection(
            title: "Open-Meteo connection",
            detail: "DockMagic uses macOS Current Location, then requests the forecast directly from Open-Meteo. No Shortcut or additional app is required."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                LabeledContent("Provider", value: "Open-Meteo Forecast API")
                LabeledContent("Refresh interval", value: "Every 10 minutes")
                LabeledContent("Location", value: "macOS Current Location")
                LabeledContent(
                    "Location access",
                    value: weatherLocationAuthorizationLabel
                )

                HStack(spacing: DSSpacing.standard) {
                    weatherLocationActions

                    if appModel.weatherStore.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing weather")
                    }
                }

                weatherStatusCard
            }
        }
    }

    private var weatherSetupSection: some View {
        DSSettingsSection(
            title: "Location & privacy",
            detail: "The first refresh asks for the standard macOS Location permission. DockMagic does not require an account, API key, Shortcut, or helper app."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                setupStep(
                    number: 1,
                    text: "Select Weather as the active Dock feature. DockMagic immediately checks the current Location permission."
                )
                setupStep(
                    number: 2,
                    text: "If permission has not been requested, choose Allow Location & Refresh and approve the standard macOS prompt."
                )
                setupStep(
                    number: 3,
                    text: "If access was denied or Location Services is off, open Location Services, enable DockMagic, then return here. DockMagic refreshes automatically; Refresh Location & Weather is also available."
                )

                Text("For each refresh, the current coordinates are sent over HTTPS to Open-Meteo. DockMagic stores only the last successful weather snapshot for resilience, not a location history.")
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var weatherStatusCard: some View {
        switch appModel.weatherStore.locationAuthorization {
        case .notDetermined:
            DSStatusCard(
                title: "Location access needed",
                detail: "Choose Allow Location & Refresh, then approve the macOS permission prompt. No coordinates are sent until permission is granted.",
                systemImage: "location.circle",
                role: .information
            )
        case .denied:
            DSStatusCard(
                title: "Location access is off for DockMagic",
                detail: "Open Location Services, enable DockMagic, return to DockMagic, and refresh Weather.",
                systemImage: "location.slash.fill",
                role: .warning
            )
        case .restricted:
            DSStatusCard(
                title: "Location access is restricted",
                detail: "Review Location Services in System Settings or contact the administrator of this Mac, then refresh Weather.",
                systemImage: "lock.trianglebadge.exclamationmark.fill",
                role: .danger
            )
        case .servicesDisabled:
            DSStatusCard(
                title: "Location Services is off",
                detail: "Open Location Services, turn it on, enable DockMagic, then return and refresh Weather.",
                systemImage: "location.slash.fill",
                role: .warning
            )
        case .authorized:
            weatherDataStatusCard
        }
    }

    @ViewBuilder
    private var weatherDataStatusCard: some View {
        switch appModel.weatherStore.state {
        case .idle:
            DSStatusCard(
                title: "Waiting for weather",
                detail: "Refresh now or activate Weather. macOS will request Location access the first time.",
                systemImage: "location.circle",
                role: .neutral
            )
        case .loading:
            DSStatusCard(
                title: "Updating weather",
                detail: "DockMagic is locating this Mac and requesting Open-Meteo.",
                systemImage: "arrow.clockwise",
                role: .neutral
            )
        case let .live(snapshot):
            DSStatusCard(
                title: "Weather is current",
                detail: "\(snapshot.location) · \(snapshot.conditionDescription) · updated \(snapshot.observedAt.formatted(date: .omitted, time: .shortened)).",
                systemImage: "checkmark.circle.fill",
                role: .processing
            )
        case let .stale(_, message):
            DSStatusCard(
                title: "Showing last known weather",
                detail: message,
                systemImage: "clock.badge.exclamationmark",
                role: .warning
            )
        case let .unavailable(message):
            DSStatusCard(
                title: "Weather unavailable",
                detail: message,
                systemImage: "exclamationmark.triangle.fill",
                role: .danger
            )
        }
    }

    @ViewBuilder
    private var weatherLocationActions: some View {
        switch appModel.weatherStore.locationAuthorization {
        case .notDetermined:
            Button("Allow Location & Refresh") {
                refreshWeather()
            }
            .buttonStyle(DSButtonStyle(kind: .primary))
            .disabled(appModel.weatherStore.isRefreshing)
            .accessibilityIdentifier("settings.weather.refresh")
        case .authorized:
            Button("Refresh Now") {
                refreshWeather()
            }
            .buttonStyle(DSButtonStyle(kind: .primary))
            .disabled(appModel.weatherStore.isRefreshing)
            .accessibilityIdentifier("settings.weather.refresh")
        case .denied, .restricted, .servicesDisabled:
            Button("Open Location Services") {
                WeatherSystemSettings.openLocationServices()
            }
            .buttonStyle(DSButtonStyle(kind: .primary))
            .accessibilityIdentifier("settings.weather.openLocationSettings")

            Button("Refresh Location & Weather") {
                refreshWeather()
            }
            .buttonStyle(DSButtonStyle())
            .disabled(appModel.weatherStore.isRefreshing)
            .accessibilityIdentifier("settings.weather.refresh")
        }
    }

    private func setupStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.standard) {
            Text("\(number)")
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.onAction)
                .frame(width: 24, height: 24)
                .background(theme.action, in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(DSTypography.body)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number), \(text)")
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

            codexConnectionSection

            RingAppearanceEditor(
                outerTitle: "5-hour ring",
                innerTitle: "Weekly ring",
                appearance: appModel.preferences.codexAppearance,
                outerColor: codexOuterColorBinding,
                innerColor: codexInnerColorBinding,
                outerWidth: codexOuterWidthBinding,
                innerWidth: codexInnerWidthBinding,
                reset: appModel.preferences.resetCodexAppearance
            )
        }
    }

    private var codexConnectionSection: some View {
        DSSettingsSection(
            title: "Codex connection",
            detail: "DockMagic starts codex app-server directly and uses the CLI's existing authentication."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                LabeledContent("Executable") {
                    Text(codexExecutableLabel)
                        .font(DSTypography.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .help(codexExecutableLabel)
                }

                HStack(spacing: DSSpacing.standard) {
                    Button("Detect Automatically") {
                        appModel.preferences.codexExecutablePath = nil
                        refreshCodex()
                    }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.codex.detect")

                    Button("Choose…", action: chooseCodexExecutable)
                        .buttonStyle(DSButtonStyle())
                        .accessibilityIdentifier("settings.codex.choose")

                    Button("Refresh", action: refreshCodex)
                        .buttonStyle(DSButtonStyle(kind: .primary))
                        .disabled(appModel.codexStore.isRefreshing)
                        .accessibilityIdentifier("settings.codex.refresh")

                    if appModel.codexStore.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing Codex usage")
                    }
                }
            }
        }
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

            claudeCodeConnectionSection

            RingAppearanceEditor(
                outerTitle: "5-hour ring",
                innerTitle: "Weekly ring",
                appearance: appModel.preferences.claudeCodeAppearance,
                outerColor: claudeCodeOuterColorBinding,
                innerColor: claudeCodeInnerColorBinding,
                outerWidth: claudeCodeOuterWidthBinding,
                innerWidth: claudeCodeInnerWidthBinding,
                reset: appModel.preferences.resetClaudeCodeAppearance
            )
        }
    }

    private var claudeCodeConnectionSection: some View {
        DSSettingsSection(
            title: "Claude Code connection",
            detail: "Claude Code's supported status line JSON supplies 5-hour and weekly usage after each response. DockMagic caches only the rate_limits object."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                LabeledContent("Status line bridge") {
                    Text(
                        appModel.claudeCodeStore.isBridgeInstalled
                            ? "Enabled"
                            : "Not enabled"
                    )
                    .font(DSTypography.metadata)
                    .foregroundStyle(
                        appModel.claudeCodeStore.isBridgeInstalled
                            ? theme.processing
                            : theme.textSecondary
                    )
                }

                HStack(spacing: DSSpacing.standard) {
                    if appModel.claudeCodeStore.isBridgeInstalled {
                        Button("Disable Bridge") {
                            appModel.claudeCodeStore.uninstallBridge()
                        }
                        .buttonStyle(DSButtonStyle())
                        .accessibilityIdentifier("settings.claudeCode.disable")
                    } else {
                        Button("Enable Bridge") {
                            Task {
                                await appModel.claudeCodeStore.installBridge()
                            }
                        }
                        .buttonStyle(DSButtonStyle(kind: .primary))
                        .accessibilityIdentifier("settings.claudeCode.enable")
                    }

                    Button("Refresh") {
                        Task {
                            await appModel.claudeCodeStore.refresh()
                        }
                    }
                    .buttonStyle(
                        DSButtonStyle(
                            kind: appModel.claudeCodeStore.isBridgeInstalled
                                ? .primary
                                : .neutral
                        )
                    )
                    .disabled(
                        !appModel.claudeCodeStore.isBridgeInstalled
                            || appModel.claudeCodeStore.isRefreshing
                    )
                    .accessibilityIdentifier("settings.claudeCode.refresh")

                    if appModel.claudeCodeStore.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing Claude Code usage")
                    }
                }

                Text("After enabling, restart Claude Code if it asks you to accept status line trust, then complete one response. Existing command-based status line output is preserved and restored when the bridge is disabled.")
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)

                claudeCodeStatusCard
            }
        }
    }

    @ViewBuilder
    private var claudeCodeStatusCard: some View {
        switch appModel.claudeCodeStore.state {
        case .idle:
            DSStatusCard(
                title: "Waiting for Claude Code",
                detail: "Complete a Claude Code response to create the first usage snapshot.",
                systemImage: "clock",
                role: .neutral
            )
        case .loading:
            DSStatusCard(
                title: "Reading usage",
                detail: "DockMagic is checking the local rate-limit snapshot.",
                systemImage: "ellipsis",
                role: .neutral
            )
        case .live:
            DSStatusCard(
                title: "Usage is current",
                detail: "Fresh Claude Code limits are available to the Dock renderer.",
                systemImage: "checkmark.circle.fill",
                role: .processing
            )
        case let .stale(_, message):
            DSStatusCard(
                title: "Showing last known usage",
                detail: message,
                systemImage: "clock.badge.exclamationmark",
                role: .warning
            )
        case let .unavailable(message):
            DSStatusCard(
                title: "Claude Code usage unavailable",
                detail: message,
                systemImage: "exclamationmark.triangle.fill",
                role: .danger
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
                LabeledContent("Appearance", value: "Light")
                LabeledContent(
                    "Features",
                    value: "CPU & RAM, Network, Storage, Weather, Codex, Claude Code"
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
                detail: "CPU, memory, network, and storage metrics remain local. Weather sends current coordinates to Open-Meteo; Codex uses its selected executable; Claude Code uses a local status line snapshot containing only rate_limits."
            ) {
                Text("DockMagic stores only the last successful weather result for resilience and does not keep a location history. It does not inspect prompts, conversations, transcripts, OAuth tokens, API keys, or Keychain items. Open-Meteo data is used under CC BY 4.0.")
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
            HStack(spacing: 24) {
                preview()
                    .frame(width: 152, height: 152)
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
                guard feature == .weather else {
                    return
                }

                destination = .weather
                appModel.weatherStore.refreshLocationAuthorizationStatus()
                refreshWeather()
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

    private var weatherLocationAuthorizationLabel: String {
        switch appModel.weatherStore.locationAuthorization {
        case .notDetermined:
            "Not requested"
        case .authorized:
            "Allowed"
        case .denied:
            "Denied"
        case .restricted:
            "Restricted"
        case .servicesDisabled:
            "Location Services off"
        }
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

    private var codexExecutableLabel: String {
        if let resolved = appModel.codexStore.resolvedExecutablePath {
            return resolved
        }
        if let configured = appModel.preferences.codexExecutablePath {
            return configured
        }
        return "Automatic detection"
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

    private func refreshCodex() {
        Task {
            await appModel.codexStore.refresh()
        }
    }

    private func chooseCodexExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Choose Codex Executable"
        panel.message = "Choose the codex executable used for app-server usage limits."
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        appModel.preferences.codexExecutablePath = url.path
        refreshCodex()
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
        HStack(spacing: 10) {
            Image("DockMagicLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .padding(2)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                    .stroke(theme.outlineStrong, lineWidth: 1)
                }
                .accessibilityHidden(true)

            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DockMagic Settings")
        .accessibilityIdentifier("settings.header")
    }
}

/// SwiftUI does not expose `NSWindow.titleVisibility`. Keep the scene's title
/// intact for window routing and accessibility while the custom toolbar header
/// owns the visible title treatment.
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
        window?.titleVisibility = .hidden
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
            title: "Ring appearance",
            detail: "Widths are constrained automatically so both rings stay clear at small Dock sizes."
        ) {
            colorRow(
                title: outerTitle,
                color: outerColor,
                hex: appearance.outerColor.hex
            )
            widthRow(
                title: "\(outerTitle) width",
                value: outerWidth,
                range: DockRingAppearance.minimumOuterWidth
                    ... DockRingAppearance.maximumOuterWidth
            )

            DSDivider()

            colorRow(
                title: innerTitle,
                color: innerColor,
                hex: appearance.innerColor.hex
            )
            widthRow(
                title: "\(innerTitle) width",
                value: innerWidth,
                range: DockRingAppearance.minimumInnerWidth
                    ... DockRingAppearance.maximumInnerWidth
            )

            HStack {
                Spacer()
                Button("Reset Defaults", action: reset)
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.rings.reset")
            }
        }
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

            Text(hex)
                .font(DSTypography.keycap)
                .foregroundStyle(theme.textSecondary)

            ColorPicker(title, selection: color, supportsOpacity: false)
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityValue(hex)
                .accessibilityIdentifier(
                    "settings.ringColor.\(controlIdentifier(for: title))"
                )
        }
        .frame(minHeight: 28)
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
                .frame(maxWidth: 240)
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
            detail: "Download and upload keep distinct colors in both the Dock and the 60-second history chart."
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
                Button("Reset Defaults", action: reset)
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

            Text(hex)
                .font(DSTypography.keycap)
                .foregroundStyle(theme.textSecondary)

            ColorPicker(title, selection: color, supportsOpacity: false)
                .labelsHidden()
                .accessibilityLabel("\(title) chart color")
                .accessibilityValue(hex)
                .accessibilityIdentifier("settings.network.color.\(identifier)")
        }
        .frame(minHeight: 28)
    }
}

private struct SingleRingAppearanceEditor: View {
    let title: String
    let detail: String
    let colorTitle: String
    let appearance: DockSingleRingAppearance
    let color: Binding<Color>
    let width: Binding<Double>
    let reset: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSettingsSection(title: title, detail: detail) {
            HStack(spacing: DSSpacing.standard) {
                Text(colorTitle)
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: DSSpacing.standard)

                Text(appearance.color.hex)
                    .font(DSTypography.keycap)
                    .foregroundStyle(theme.textSecondary)

                ColorPicker(colorTitle, selection: color, supportsOpacity: false)
                    .labelsHidden()
                    .accessibilityLabel(colorTitle)
                    .accessibilityValue(appearance.color.hex)
                    .accessibilityIdentifier("settings.storage.color")
            }
            .frame(minHeight: 28)

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
                .frame(maxWidth: 240)
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

            HStack {
                Spacer()
                Button("Reset Defaults", action: reset)
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
                .foregroundStyle(theme.information)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            Text(value ?? "—")
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(value == nil ? theme.textTertiary : theme.information)
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
