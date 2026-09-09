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
            return DockAppModel(
                preferences: DockPreferencesStore(
                    defaults: DockMagicRuntimeDefaults.current
                ),
                weatherStore: WeatherStore(
                    provider: DockMagicUITestWeatherProvider(),
                    authorizationProvider: DockMagicUITestWeatherAuthorizationProvider(),
                    cache: DockMagicUITestWeatherCache()
                ),
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
                    pollingInterval: .seconds(60)
                ),
                developerToolInstallationStore:
                    DeveloperToolInstallationStore(
                        installer: DockMagicUITestDeveloperToolInstaller()
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
        dockFeatureMenuController = DockFeatureMenuController(
            appModel: appModel,
            settingsWindowRouter: settingsWindowRouter
        )
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
        // Allow AppKit/SwiftUI to handle the request if our route cannot open it.
        return !settingsWindowRouter.showSettings()
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
private final class DockFeatureMenuController: NSObject {
    private let appModel: DockAppModel
    private let settingsWindowRouter: SettingsWindowRouter

    init(
        appModel: DockAppModel,
        settingsWindowRouter: SettingsWindowRouter
    ) {
        self.appModel = appModel
        self.settingsWindowRouter = settingsWindowRouter
        super.init()
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "DockMagic")
        menu.autoenablesItems = false

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

        for feature in DockFeature.allCases {
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
        case .clock:
            #selector(selectClock(_:))
        case .batteries:
            #selector(selectBatteries(_:))
        case .github:
            #selector(selectGitHub(_:))
        case .codex:
            #selector(selectCodex(_:))
        case .antigravity:
            #selector(selectAntigravity(_:))
        case .claudeCode:
            #selector(selectClaudeCode(_:))
        case .searchConsole:
            #selector(selectSearchConsole(_:))
        }
    }

    private func select(_ feature: DockFeature) {
        appModel.activateFeature(feature)
        switch feature {
        case .codex:
            _ = settingsWindowRouter.showSettings(destination: .codex)
        case .antigravity:
            _ = settingsWindowRouter.showSettings(destination: .antigravity)
        case .claudeCode:
            _ = settingsWindowRouter.showSettings(destination: .claudeCode)
        case .dockMagic, .systemMetrics, .network, .storage, .weather, .clock,
             .batteries, .github, .searchConsole:
            break
        }
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

    @objc private func selectAntigravity(_ sender: Any?) { select(.antigravity) }

    @objc private func selectClaudeCode(_ sender: Any?) {
        select(.claudeCode)
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

@MainActor
private final class DockMagicUITestDeveloperToolInstaller:
    DeveloperToolInstalling
{
    private var installedTools = Set<DeveloperTool>()

    func locate(
        _ tool: DeveloperTool,
        codexOverridePath: String?
    ) throws -> URL {
        guard installedTools.contains(tool) else {
            throw DeveloperToolInstallerError.installedExecutableMissing(tool)
        }
        return URL(fileURLWithPath: "/usr/bin/true")
    }

    func install(_ tool: DeveloperTool) async throws -> URL {
        installedTools.insert(tool)
        return URL(fileURLWithPath: "/usr/bin/true")
    }
}

private struct DockMagicUITestClaudeCodeProvider:
    ClaudeCodeRateLimitProviding
{
    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot {
        throw ClaudeCodeRateLimitProviderError.snapshotMissing
    }
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

private struct SettingsSceneRoot: View {
    let appModel: DockAppModel
    let dockHoverPermissionController: DockHoverPermissionController
    let windowRouter: SettingsWindowRouter?
    let softwareUpdateController: SoftwareUpdateController

    var body: some View {
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
