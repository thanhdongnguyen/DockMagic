import AppKit
import Observation
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel: DockAppModel
    let settingsWindowRouter: SettingsWindowRouter
    let dockHoverPermissionController: DockHoverPermissionController
    let softwareUpdateController: SoftwareUpdateController

    private let dockTile: NSDockTile
    private let application: any ApplicationIconDisplaying
    private let appearanceStore: UserDefaults
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private let dockFeatureMenuController: DockFeatureMenuController
    private let networkAvailabilityMonitor: any NetworkAvailabilityMonitoring
    private var recoveryTasks: [UUID: Task<Void, Never>] = [:]
    private let lifecycleLogger = Logger(
        subsystem: "com.hypevibe.DockMagic", category: "Lifecycle"
    )
    private var dockTileController: DockTileController?
    private var dockHoverCoordinator: DockHoverCoordinator?
    private var appearanceObserver: NSObjectProtocol?
    private var accessibilityDisplayObserver: NSObjectProtocol?
    private var workspaceWakeObserver: NSObjectProtocol?
    private var workspaceSessionActiveObserver: NSObjectProtocol?
    private var effectiveAppearanceObservation: NSKeyValueObservation?

    override convenience init() {
        DSFonts.register()
        self.init(
            appModel: Self.makeAppModel(),
            settingsWindowRouter: SettingsWindowRouter(),
            dockTile: NSApplication.shared.dockTile,
            application: NSApplication.shared,
            appearanceStore: DockMagicRuntimeDefaults.current,
            notificationCenter: .default,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter,
            softwareUpdateController: Self.makeSoftwareUpdateController()
        )
    }

    private static func makeSoftwareUpdateController(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SoftwareUpdateController {
        guard environment["DockMagicUITesting"] == "1" else {
            return .production()
        }

        return .uiTestFixture(
            availableVersion:
                environment["DockMagicUITestUpdateAvailableVersion"]
        )
    }

    private static func makeAppModel(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DockAppModel {
        guard environment["DockMagicUITesting"] != "1" else {
            let claudeConnected = environment[
                "DockMagicUITestClaudeConnected"
            ] == "1"
            let claudeExecutableURL = environment[
                "DockMagicUITestClaudeExecutablePath"
            ].map { URL(fileURLWithPath: $0) }
            let claudeLoginMarkerURL = environment[
                "DockMagicUITestClaudeLoginMarkerPath"
            ].map { URL(fileURLWithPath: $0) }
            let antigravitySignedOut = environment[
                "DockMagicUITestAntigravitySignedOut"
            ] == "1"
            let antigravityConnected = environment[
                "DockMagicUITestAntigravityConnected"
            ] == "1"
            let antigravityBridgeInstalled = environment[
                "DockMagicUITestAntigravityBridgeInstalled"
            ] == "1"
            let antigravityExecutableURL = environment[
                "DockMagicUITestAntigravityExecutablePath"
            ].map { URL(fileURLWithPath: $0) }
            let antigravityCacheSuffix = environment[
                "DockMagicUITestDefaultsSuite"
            ]?.replacingOccurrences(of: "/", with: "-") ?? "default"
            var installedTools = Set<DeveloperTool>()
            var executableOverrides = [DeveloperTool: URL]()
            if claudeConnected || claudeExecutableURL != nil {
                installedTools.insert(.claudeCode)
            }
            if let claudeExecutableURL {
                executableOverrides[.claudeCode] = claudeExecutableURL
            }
            if let antigravityExecutableURL {
                installedTools.insert(.antigravity)
                executableOverrides[.antigravity] = antigravityExecutableURL
            }
            let developerToolInstaller = DockMagicUITestDeveloperToolInstaller(
                installedTools: installedTools,
                executableOverrides: executableOverrides
            )
            let antigravityProvider = DockMagicUITestAntigravityProvider(
                signedOut: antigravitySignedOut
            )
            let antigravityStore = AntigravityUsageStore(
                provider: antigravityProvider,
                authenticationProvider: antigravityProvider,
                locator: DockMagicUITestAntigravityLocator(
                    executableURL: antigravityExecutableURL
                ),
                bridge: DockMagicUITestAntigravityBridge(
                    installed: antigravityBridgeInstalled
                ),
                cacheURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "dockmagic-ui-test-antigravity-\(antigravityCacheSuffix).json"
                    ),
                readSessions: { [] },
                pollingInterval: .seconds(60)
            )
            if antigravityConnected {
                Task { await antigravityStore.refresh() }
            }
            let binancePreferences = DockPreferencesStore(defaults: DockMagicRuntimeDefaults.current)
            let binanceStore: BinanceMarketStore?
#if DEBUG
            if environment["DockMagicUITestBinanceFixtures"] == "1" {
                if DockMagicRuntimeDefaults.current.data(forKey: DockPreferencesStore.binanceConfigurationKey) == nil {
                    binancePreferences.binanceConfiguration = BinanceFixtureProvider.configuration(count: Int(environment["DockMagicUITestBinanceCount"] ?? "3") ?? 3)
                }
                binanceStore = BinanceMarketStore(configuration: binancePreferences.binanceConfiguration,
                    provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil),
                    persist: { binancePreferences.binanceConfiguration = $0 })
            } else { binanceStore = nil }
#else
            binanceStore = nil
#endif
            let augmentStore: AugmentUsageStore
#if DEBUG
            augmentStore = AugmentFixtureClient.store(mode: environment["DockMagicUITestAugment"] ?? "setup", defaults: DockMagicRuntimeDefaults.current)
#else
            augmentStore = AugmentUsageStore(vault: InMemoryAugmentCredentialVault())
#endif
            let calendarStore: CalendarStore
            let nowPlayingStore: NowPlayingStore
            let grokBuildStore: GrokBuildUsageStore?
#if DEBUG
            grokBuildStore = environment["DockMagicUITestGrok"].map {
                GrokUIFixtures.store(mode: $0, preferences: binancePreferences)
            }
            nowPlayingStore = environment["DockMagicUITestNowPlaying"].map { NowPlayingFixtures.store(mode: $0) } ?? NowPlayingStore()
            calendarStore = CalendarStore(provider: CalendarUITestProvider(
                access: environment["DockMagicUITestCalendarAccess"],
                remindersAccess: environment["DockMagicUITestRemindersAccess"]
            ))
#else
            grokBuildStore = nil
            nowPlayingStore = NowPlayingStore()
            calendarStore = CalendarStore()
#endif
            return DockAppModel(
                preferences: binancePreferences,
                binanceStore: binanceStore,
                weatherStore: WeatherStore(
                    provider: DockMagicUITestWeatherProvider(),
                    authorizationProvider: DockMagicUITestWeatherAuthorizationProvider(),
                    cache: DockMagicUITestWeatherCache()
                ),
                calendarStore: calendarStore,
                nowPlayingStore: nowPlayingStore,
                batteryStore: BatteryMetricsStore(
                    sampler: DockMagicUITestBatterySampler(),
                    samplingInterval: .seconds(60)
                ),
                githubStore: GitHubRepositoryStore(
                    api: DockMagicUITestGitHubProvider(),
                    vault: InMemoryGitHubCredentialVault(),
                    cache: InMemoryGitHubRepositoryHistoryCache(),
                    pollingInterval: 60
                ),
                claudeCodeStore: ClaudeCodeUsageStore(
                    provider: DockMagicUITestClaudeCodeProvider(),
                    bridge: DockMagicUITestClaudeCodeBridge(),
                    activityHookBridge:
                        DockMagicUITestClaudeCodeActivityHookBridge(),
                    authProvider: DockMagicUITestClaudeAuthProvider(
                        loggedIn: claudeConnected,
                        loginMarkerURL: claudeLoginMarkerURL
                    ),
                    usageCollector: DockMagicUITestClaudeUsageCollector(
                        providesQuota: claudeConnected,
                        loginMarkerURL: claudeLoginMarkerURL
                    ),
                    pollingInterval: .seconds(60)
                ),
                antigravityStore: antigravityStore,
                augmentStore: augmentStore,
                openCodeStore: OpenCodeUsageStore(
                    cache: OpenCodeHistoryCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("dockmagic-ui-opencode-\(antigravityCacheSuffix)")),
                    defaults: DockMagicRuntimeDefaults.current
                ),
                grokBuildStore: grokBuildStore,
                developerToolInstallationStore:
                    DeveloperToolInstallationStore(
                        installer: developerToolInstaller
                    ),
                serviceStatusStore: ServiceStatusStore(
                    provider: DockMagicUITestServiceStatusProvider(),
                    cache: InMemoryServiceStatusCache(),
                    operationalPollingInterval: 60,
                    incidentPollingInterval: 60
                ),
                searchConsoleStore: SearchConsoleStore.uiTestFixture()
            )
        }

        return DockAppModel()
    }

    init(
        appModel: DockAppModel,
        settingsWindowRouter: SettingsWindowRouter,
        dockTile: NSDockTile? = nil,
        application: (any ApplicationIconDisplaying)? = nil,
        appearanceStore: UserDefaults = DockMagicRuntimeDefaults.current,
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        dockHoverPermissionController: DockHoverPermissionController? = nil,
        softwareUpdateController: SoftwareUpdateController? = nil,
        networkAvailabilityMonitor: (any NetworkAvailabilityMonitoring)? = nil
    ) {
        self.appModel = appModel
        self.settingsWindowRouter = settingsWindowRouter
        appModel.openBinanceSettings = { [weak settingsWindowRouter] in
            settingsWindowRouter?.showSettings(destination: .binance)
        }
        appModel.openAugmentSettings = { [weak settingsWindowRouter] in
            settingsWindowRouter?.showSettings(destination: .augment)
        }
        appModel.openGrokBuildSettings = { [weak settingsWindowRouter] in
            guard GrokBuildFeatureGate.experimentalEnabled else { return }
            settingsWindowRouter?.showSettings(destination: .grokBuild)
        }
        appModel.openOpenCodeSettings = { [weak settingsWindowRouter] in
            settingsWindowRouter?.showSettings(destination: .openCode)
        }
        self.dockHoverPermissionController = dockHoverPermissionController
            ?? DockHoverPermissionController()
        self.softwareUpdateController = softwareUpdateController ?? .disabled()
        self.dockTile = dockTile ?? NSApplication.shared.dockTile
        self.application = application ?? NSApplication.shared
        self.appearanceStore = appearanceStore
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.networkAvailabilityMonitor = networkAvailabilityMonitor
            ?? NetworkAvailabilityMonitor()
        dockFeatureMenuController = DockFeatureMenuController(appModel: appModel)
        super.init()
        installSettingsWindowFactory()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        lifecycleLogger.notice("Starting DockMagic services.")
        NSApplication.shared.setActivationPolicy(.regular)
        dockTileController = DockTileController(
            dockTile: dockTile,
            application: application,
            initialPresentation: appModel.dockPresentation,
            appearanceStore: appearanceStore
        )
        observeAppearance()
        observeEffectiveAppearance()
        observeAccessibilityDisplayOptions()
        observeSystemResume()
        observeDockPresentation()
        softwareUpdateController.start()
        appModel.start()
        networkAvailabilityMonitor.start { [weak self] in
            self?.scheduleRecovery(reason: "network restored")
        }
        dockHoverCoordinator = DockHoverCoordinator(
            appModel: appModel,
            permissionController: dockHoverPermissionController
        )
        dockHoverCoordinator?.start()
        appModel.openNowPlaying = { [weak self] in self?.dockHoverCoordinator?.openNowPlaying() }
        appModel.openNowPlayingSettings = { [weak self] in _ = self?.settingsWindowRouter.showSettings(destination: .nowPlaying) }
        dockFeatureMenuController.onMenuClose = { [weak self] in self?.dockHoverCoordinator?.dockMenuDidClose() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        dockHoverCoordinator?.applicationDidBecomeActive()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        dockHoverCoordinator?.dockMenuWillOpen()
        return dockFeatureMenuController.makeMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        dockHoverCoordinator?.dockIconClicked()
        let destination = SettingsDestination(
            activeFeature: appModel.preferences.activeFeature
        )
        // Allow AppKit/SwiftUI to handle the request if our route cannot open it.
        return !settingsWindowRouter.showSettings(destination: destination)
    }

    func applicationWillTerminate(_ notification: Notification) {
        dockHoverCoordinator?.stop()
        networkAvailabilityMonitor.stop()
        for task in recoveryTasks.values { task.cancel() }
        recoveryTasks.removeAll()
        appModel.stop()
        if let appearanceObserver {
            notificationCenter.removeObserver(appearanceObserver)
        }
        if let accessibilityDisplayObserver {
            workspaceNotificationCenter.removeObserver(
                accessibilityDisplayObserver
            )
        }
        if let workspaceWakeObserver {
            workspaceNotificationCenter.removeObserver(workspaceWakeObserver)
        }
        if let workspaceSessionActiveObserver {
            workspaceNotificationCenter.removeObserver(
                workspaceSessionActiveObserver
            )
        }
        appearanceObserver = nil
        accessibilityDisplayObserver = nil
        workspaceWakeObserver = nil
        workspaceSessionActiveObserver = nil
        effectiveAppearanceObservation = nil
        dockHoverCoordinator = nil
        dockTileController = nil
    }

    private func observeDockPresentation() {
        withObservationTracking {
            _ = appModel.dockPresentation
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.dockTileController?.update(
                    presentation: self.appModel.dockPresentation
                )
                self.observeDockPresentation()
            }
        }
    }

    private func observeAppearance() {
        appearanceObserver = notificationCenter.addObserver(
            forName: DSAppearanceMode.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dockTileController?.updateAppearance()
            }
        }
    }

    private func observeEffectiveAppearance() {
        effectiveAppearanceObservation = NSApplication.shared.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.dockTileController?.updateAppearance()
            }
        }
    }

    private func observeAccessibilityDisplayOptions() {
        accessibilityDisplayObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dockTileController?.updateAppearance()
            }
        }
    }

    private func observeSystemResume() {
        workspaceWakeObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRecovery(reason: "system wake")
            }
        }
        workspaceSessionActiveObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRecovery(reason: "session active")
            }
        }
    }

    private func scheduleRecovery(reason: String) {
        guard appModel.isRunning else { return }
        lifecycleLogger.notice("Refreshing after \(reason, privacy: .public).")
        // Every event must reach each store even when an unrelated provider is
        // still busy. Stores coalesce their own work; quit cancels all waiters.
        let id = UUID()
        recoveryTasks[id] = Task { @MainActor [weak self] in
            guard let appModel = self?.appModel else { return }
            async let usage: Void = appModel.refreshDeveloperUsageAfterInterruption()
            async let otherFeatures: Void = appModel.refreshAfterInterruption()
            _ = await (usage, otherFeatures)
            self?.recoveryTasks[id] = nil
        }
    }

    private func installSettingsWindowFactory() {
        // Capture the scene's dependencies, not the delegate or router, to avoid
        // a retain cycle. This factory works even when SwiftUI has no scene yet.
        let appModel = appModel
        let permissionController = dockHoverPermissionController
        let updateController = softwareUpdateController
        settingsWindowRouter.installDefaultWindowFactory { [weak settingsWindowRouter] in
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1_160, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = SettingsWindowRouter.windowTitle
            window.identifier = NSUserInterfaceItemIdentifier(
                SettingsWindowRouter.sceneID
            )
            window.contentView = NSHostingView(
                rootView: SettingsSceneRoot(
                    appModel: appModel,
                    dockHoverPermissionController: permissionController,
                    windowRouter: settingsWindowRouter,
                    softwareUpdateController: updateController
                )
            )
            window.contentMinSize = NSSize(
                width: DSLayout.minimumWindowWidth,
                height: DSLayout.minimumWindowHeight
            )
            window.setFrameAutosaveName("DockMagic Settings")
            if !window.setFrameUsingName("DockMagic Settings") { window.center() }
            return window
        }
    }
}

@MainActor
private final class DockFeatureMenuController: NSObject, NSMenuDelegate {
    var onMenuClose: (() -> Void)?
    func menuDidClose(_ menu: NSMenu) { onMenuClose?() }
    private let appModel: DockAppModel

    init(appModel: DockAppModel) {
        self.appModel = appModel
        super.init()
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "DockMagic")
        menu.delegate = self
        menu.autoenablesItems = false

        if appModel.preferences.activeFeature == .nowPlaying {
            let item = NSMenuItem(title: "Open Now Playing", action: #selector(openNowPlaying(_:)), keyEquivalent: "")
            item.target = self
            item.identifier = NSUserInterfaceItemIdentifier("dockMenu.openNowPlaying")
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let switchFeatureItem = NSMenuItem(
            title: "Switch Feature",
            action: nil,
            keyEquivalent: ""
        )
        switchFeatureItem.identifier = NSUserInterfaceItemIdentifier(
            "dockMenu.switchFeature"
        )
        switchFeatureItem.submenu = makeFeatureSubmenu()
        menu.addItem(switchFeatureItem)

        return menu
    }

    private func makeFeatureSubmenu() -> NSMenu {
        let submenu = NSMenu(title: "Switch Feature")
        submenu.autoenablesItems = false

        for feature in DockFeature.availableCases {
            let item = NSMenuItem(
                title: feature.title,
                action: action(for: feature),
                keyEquivalent: ""
            )
            item.identifier = NSUserInterfaceItemIdentifier(
                "dockMenu.feature.\(feature.rawValue)"
            )
            item.target = self
            item.isEnabled = true
            item.state = appModel.preferences.activeFeature == feature ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    private func action(for feature: DockFeature) -> Selector {
        switch feature {
        case .dockMagic:
            #selector(selectDockMagic(_:))
        case .systemMetrics:
            #selector(selectSystemMetrics(_:))
        case .network:
            #selector(selectNetwork(_:))
        case .storage:
            #selector(selectStorage(_:))
        case .weather:
            #selector(selectWeather(_:))
        case .binance:
            #selector(selectBinance(_:))
        case .calendar:
            #selector(selectCalendar(_:))
        case .nowPlaying:
            #selector(selectNowPlaying(_:))
        case .clock:
            #selector(selectClock(_:))
        case .batteries:
            #selector(selectBatteries(_:))
        case .github:
            #selector(selectGitHub(_:))
        case .codex:
            #selector(selectCodex(_:))
        case .claudeCode:
            #selector(selectClaudeCode(_:))
        case .augment:
            #selector(selectAugment(_:))
        case .grokBuild:
            #selector(selectGrokBuild(_:))
        case .openCode:
            #selector(selectOpenCode(_:))
        case .antigravity:
            #selector(selectAntigravity(_:))
        case .searchConsole:
            #selector(selectSearchConsole(_:))
        }
    }

    private func select(_ feature: DockFeature) {
        appModel.activateFeature(feature)
    }

    @objc private func selectDockMagic(_ sender: Any?) {
        select(.dockMagic)
    }

    @objc private func selectSystemMetrics(_ sender: Any?) {
        select(.systemMetrics)
    }

    @objc private func selectNetwork(_ sender: Any?) {
        select(.network)
    }

    @objc private func selectStorage(_ sender: Any?) {
        select(.storage)
    }

    @objc private func selectWeather(_ sender: Any?) {
        select(.weather)
    }

    @objc private func selectNowPlaying(_ sender: Any?) { select(.nowPlaying) }
    @objc private func openNowPlaying(_ sender: Any?) { appModel.openNowPlaying?() }

    @objc private func selectBinance(_ sender: Any?) { select(.binance) }

    @objc private func selectCalendar(_ sender: Any?) {
        select(.calendar)
    }

    @objc private func selectClock(_ sender: Any?) {
        select(.clock)
    }

    @objc private func selectBatteries(_ sender: Any?) {
        select(.batteries)
    }

    @objc private func selectGitHub(_ sender: Any?) {
        select(.github)
    }

    @objc private func selectCodex(_ sender: Any?) {
        select(.codex)
    }

    @objc private func selectClaudeCode(_ sender: Any?) {
        select(.claudeCode)
    }

    @objc private func selectAugment(_ sender: Any?) { select(.augment) }

    @objc private func selectGrokBuild(_ sender: Any?) {
        guard GrokBuildFeatureGate.experimentalEnabled else { return }
        select(.grokBuild)
    }
    @objc private func selectOpenCode(_ sender: Any?) { select(.openCode) }

    @objc private func selectAntigravity(_ sender: Any?) {
        select(.antigravity)
    }

    @objc private func selectSearchConsole(_ sender: Any?) {
        select(.searchConsole)
    }
}

private struct DockMagicUITestWeatherProvider: WeatherSnapshotProviding {
    func fetchWeather() async throws -> WeatherSnapshot {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let forecast = (0 ..< 7).compactMap { dayOffset -> DailyWeatherForecast? in
            guard let date = Calendar.current.date(
                byAdding: .day,
                value: dayOffset,
                to: startOfToday
            ) else {
                return nil
            }
            return DailyWeatherForecast(
                date: date,
                conditionDescription: dayOffset == 0
                    ? "Partly cloudy"
                    : "Thunderstorm",
                condition: dayOffset == 0 ? .partlyCloudy : .thunderstorm,
                highCelsius: Double(33 - (dayOffset % 3)),
                lowCelsius: Double(25 + (dayOffset % 2)),
                precipitationChance: Double(20 + dayOffset * 10) / 100
            )
        }
        return WeatherSnapshot(
            location: "Ho Chi Minh City, Vietnam",
            temperatureCelsius: 29,
            feelsLikeCelsius: 32,
            conditionDescription: "Partly cloudy",
            condition: .partlyCloudy,
            highCelsius: 33,
            lowCelsius: 26,
            precipitationChance: 0.2,
            relativeHumidity: 0.76,
            windSpeedKPH: 13,
            forecast: forecast,
            isDaylight: true,
            observedAt: now,
            fetchedAt: now
        )
    }
}

private struct DockMagicUITestWeatherAuthorizationProvider:
    WeatherLocationAuthorizationProviding
{
    @MainActor
    func weatherLocationAuthorization() -> WeatherLocationAuthorization {
        .authorized
    }
}

private struct DockMagicUITestWeatherCache: WeatherSnapshotCaching {
    func load() -> WeatherSnapshot? {
        nil
    }

    func save(_ snapshot: WeatherSnapshot) {}
}

private struct DockMagicUITestBatterySampler: BatteryMetricsSampling {
    func sample() async throws -> BatteryMetricsSnapshot {
        let now = Date()
        return BatteryMetricsSnapshot(
            devices: [
                BatteryDeviceSnapshot(
                    id: "ui.macbook",
                    name: "MacBook Pro",
                    kind: .macBook,
                    level: 0.74,
                    isCharging: true,
                    observedAt: now
                ),
                BatteryDeviceSnapshot(
                    id: "ui.airpods",
                    name: "AirPods Pro",
                    kind: .airPods,
                    level: 0.81,
                    isCharging: true,
                    detail: "Connected",
                    observedAt: now
                ),
                BatteryDeviceSnapshot(
                    id: "ui.case",
                    name: "Charging Case",
                    kind: .chargingCase,
                    level: 0.62,
                    detail: "Updated just now",
                    observedAt: now
                ),
                BatteryDeviceSnapshot(
                    id: "ui.mouse",
                    name: "Magic Mouse",
                    kind: .magicMouse,
                    level: 0.39,
                    observedAt: now
                )
            ],
            sampledAt: now
        )
    }
}

private struct DockMagicUITestGitHubProvider:
    GitHubRepositoryAPIProviding
{
    func fetchRepository(
        _ reference: GitHubRepositoryReference,
        accessToken: String?,
        etag: String?
    ) async throws -> GitHubRepositoryFetchResult {
        let rateLimit = GitHubRateLimit(
            limit: accessToken == nil ? 60 : 5_000,
            remaining: accessToken == nil ? 59 : 4_999,
            resetAt: Date().addingTimeInterval(60 * 60)
        )
        if etag != nil {
            return .notModified(etag: "\"dockmagic-ui-test\"", rateLimit: rateLimit)
        }
        return .modified(
            snapshot: GitHubRepositorySnapshot(
                repository: reference.fullName,
                stars: 12_742,
                forks: 824,
                fetchedAt: Date()
            ),
            etag: "\"dockmagic-ui-test\"",
            rateLimit: rateLimit
        )
    }
}

private struct DockMagicUITestServiceStatusProvider:
    ServiceStatusProviding
{
    func fetchStatus(
        for provider: ServiceStatusProviderID
    ) async throws -> ServiceHealthSnapshot {
        .operational(provider: provider, fetchedAt: Date())
    }
}

private actor DockMagicUITestAntigravityProvider:
    AntigravityQuotaProviding, AntigravityAuthenticationProviding
{
    private var signedOut: Bool

    init(signedOut: Bool) {
        self.signedOut = signedOut
    }

    func fetchQuota(executableURL: URL) async throws
        -> AntigravityQuotaSnapshot {
        if signedOut { throw AntigravityUsageError.signedOut }
        return AntigravityQuotaSnapshot(
            buckets: [
                AntigravityQuotaBucket(
                    id: "gemini-weekly",
                    groupName: "Gemini Models",
                    title: "Weekly Limit Remaining",
                    description: nil,
                    windowDurationMinutes: 10_080,
                    remainingFraction: 0.64,
                    resetsAt: Date().addingTimeInterval(86_400)
                ),
                AntigravityQuotaBucket(
                    id: "3p-weekly",
                    groupName: "Claude and GPT models",
                    title: "Weekly Limit Remaining",
                    description: nil,
                    windowDurationMinutes: 10_080,
                    remainingFraction: 0.31,
                    resetsAt: Date().addingTimeInterval(43_200)
                )
            ],
            fetchedAt: Date(),
            cliVersion: "UI Test"
        )
    }

    func signOut(executableURL: URL) async throws {
        // Keep the processing state visible long enough for UI automation to
        // assert that sign-out never reveals a terminal surface.
        try await Task.sleep(for: .seconds(4))
        signedOut = true
    }
}

private struct DockMagicUITestAntigravityLocator:
    AntigravityExecutableLocating
{
    let executableURL: URL?

    func locate() throws -> URL {
        executableURL ?? URL(fileURLWithPath: "/usr/bin/true")
    }
}

@MainActor
private final class DockMagicUITestAntigravityBridge:
    AntigravityStatusLineBridging
{
    private var installed: Bool
    let sessionsDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("dockmagic-ui-test-antigravity-sessions")

    init(installed: Bool) {
        self.installed = installed
    }

    func isInstalled() -> Bool { installed }
    func install() throws { installed = true }
    func uninstall() throws { installed = false }
}

@MainActor
private final class DockMagicUITestDeveloperToolInstaller:
    DeveloperToolInstalling
{
    private var installedTools: Set<DeveloperTool>
    private let executableOverrides: [DeveloperTool: URL]

    init(
        installedTools: Set<DeveloperTool> = [],
        executableOverrides: [DeveloperTool: URL] = [:]
    ) {
        self.installedTools = installedTools
        self.executableOverrides = executableOverrides
    }

    func locate(
        _ tool: DeveloperTool,
        codexOverridePath: String?
    ) throws -> URL {
        guard installedTools.contains(tool) else {
            throw DeveloperToolInstallerError.installedExecutableMissing(tool)
        }
        return executableOverrides[tool]
            ?? URL(fileURLWithPath: "/usr/bin/true")
    }

    func install(_ tool: DeveloperTool) async throws -> URL {
        installedTools.insert(tool)
        return executableOverrides[tool]
            ?? URL(fileURLWithPath: "/usr/bin/true")
    }
}

private struct DockMagicUITestClaudeCodeProvider:
    ClaudeCodeRateLimitProviding
{
    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot {
        throw ClaudeCodeRateLimitProviderError.snapshotMissing
    }
}

private actor DockMagicUITestClaudeAuthProvider:
    ClaudeCodeAuthStatusProviding
{
    private var loggedIn: Bool
    let loginMarkerURL: URL?

    init(loggedIn: Bool, loginMarkerURL: URL?) {
        self.loggedIn = loggedIn
        self.loginMarkerURL = loginMarkerURL
    }

    func signOut(executableURL: URL) async throws {
        try await Task.sleep(for: .seconds(1))
        loggedIn = false
        if let loginMarkerURL, FileManager.default.fileExists(atPath: loginMarkerURL.path) {
            try FileManager.default.removeItem(at: loginMarkerURL)
        }
    }

    func status(executableURL: URL) async throws -> ClaudeCodeCLIStatus {
        let isLoggedIn = loggedIn || loginMarkerURL.map {
            FileManager.default.fileExists(atPath: $0.path)
        } == true
        return ClaudeCodeCLIStatus(
            loggedIn: isLoggedIn,
            authInfo: ClaudeCodeAuthInfo(
                authMethod: isLoggedIn ? "claude.ai" : nil,
                apiProvider: nil
            ),
            version: "2.1.268"
        )
    }
}

@MainActor
private final class DockMagicUITestClaudeUsageCollector:
    ClaudeCodeUsageCollecting
{
    private let providesQuota: Bool
    private let loginMarkerURL: URL?

    init(providesQuota: Bool, loginMarkerURL: URL?) {
        self.providesQuota = providesQuota
        self.loginMarkerURL = loginMarkerURL
    }

    func configure(executableURL: URL, cliVersion: String) {}
    func capture() async throws -> ClaudeCodeQuotaCapture {
        let canProvideQuota = providesQuota || loginMarkerURL.map {
            FileManager.default.fileExists(atPath: $0.path)
        } == true
        guard canProvideQuota else {
            throw ClaudeCodeUsageCaptureError.signedOut
        }
        return ClaudeCodeQuotaCapture(
            fiveHour: .init(
                kind: .fiveHour,
                usedPercent: 18,
                windowDurationMinutes: 300,
                resetsAt: nil
            ),
            weekly: .init(
                kind: .weekly,
                usedPercent: 59,
                windowDurationMinutes: 10_080,
                resetsAt: nil
            ),
            capturedAt: Date(),
            cliVersion: "2.1.268"
        )
    }
    func stop() {}
}

@MainActor
private final class DockMagicUITestClaudeCodeBridge:
    ClaudeCodeStatusLineBridging
{
    let snapshotURL = URL(fileURLWithPath: "/tmp/dockmagic-ui-claude.json")

    func isInstalled() -> Bool { true }
    func install() throws {}
    func uninstall() throws {}
}

@MainActor
private final class DockMagicUITestClaudeCodeActivityHookBridge:
    ClaudeCodeActivityHookBridging
{
    let eventsDirectoryURL = URL(
        fileURLWithPath: "/tmp/dockmagic-ui-claude-events",
        isDirectory: true
    )

    func isInstalled() -> Bool { false }
    func install() throws {}
    func uninstall() throws {}
}

@main
struct DockMagicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup(
            SettingsWindowRouter.windowTitle,
            id: SettingsWindowRouter.sceneID
        ) {
            SettingsSceneRoot(
                appModel: appDelegate.appModel,
                dockHoverPermissionController:
                    appDelegate.dockHoverPermissionController,
                windowRouter: appDelegate.settingsWindowRouter,
                softwareUpdateController: appDelegate.softwareUpdateController
            )
        }
        .defaultSize(width: 1_160, height: 620)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: [SettingsWindowRouter.sceneID])
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.softwareUpdateController.checkForUpdates()
                }
                .disabled(
                    !appDelegate.softwareUpdateController.canCheckForUpdates
                )
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.settingsWindowRouter.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor
private struct SettingsSceneRoot: View {
    let appModel: DockAppModel
    let dockHoverPermissionController: DockHoverPermissionController
    let windowRouter: SettingsWindowRouter?
    let softwareUpdateController: SoftwareUpdateController

    var body: some View {
#if DEBUG
        if ProcessInfo.processInfo.environment["DockMagicMaiaGallery"] == "1" {
            DSComponentGallery().defaultAppStorage(DockMagicRuntimeDefaults.current)
        } else {
            settings
        }
#else
        settings
#endif
    }

    private var settings: some View {
        DockMagicThemeRoot(
            content: SettingsView(
                appModel: appModel,
                dockHoverPermissionController: dockHoverPermissionController,
                windowRouter: windowRouter,
                softwareUpdateController: softwareUpdateController
            )
        )
        .defaultAppStorage(DockMagicRuntimeDefaults.current)
    }
}
