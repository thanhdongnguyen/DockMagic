import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel: DockAppModel
    let settingsWindowRouter: SettingsWindowRouter

    private let dockTile: NSDockTile
    private let appearanceStore: UserDefaults
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var dockTileController: DockTileController?
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
            appearanceStore: DockMagicRuntimeDefaults.current,
            notificationCenter: .default,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
        )
    }

    private static func makeAppModel(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DockAppModel {
        guard environment["DockMagicUITesting"] != "1" else {
            return DockAppModel(
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
                searchConsoleStore: SearchConsoleStore.uiTestFixture()
            )
        }

        return DockAppModel()
    }

    init(
        appModel: DockAppModel,
        settingsWindowRouter: SettingsWindowRouter,
        dockTile: NSDockTile? = nil,
        appearanceStore: UserDefaults = DockMagicRuntimeDefaults.current,
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        self.appModel = appModel
        self.settingsWindowRouter = settingsWindowRouter
        self.dockTile = dockTile ?? NSApplication.shared.dockTile
        self.appearanceStore = appearanceStore
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        dockTileController = DockTileController(
            dockTile: dockTile,
            initialPresentation: appModel.dockPresentation,
            appearanceStore: appearanceStore
        )
        observeAppearance()
        observeEffectiveAppearance()
        observeAccessibilityDisplayOptions()
        observeSystemResume()
        observeDockPresentation()
        appModel.start()
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
        _ = settingsWindowRouter.showSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
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
                await self?.appModel.refreshActiveWeatherAfterResume()
                await self?.appModel.refreshActiveBatteriesAfterResume()
                await self?.appModel.refreshActiveGitHubAfterResume()
            }
        }
        workspaceSessionActiveObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.appModel.refreshActiveWeatherAfterResume()
                await self?.appModel.refreshActiveBatteriesAfterResume()
                await self?.appModel.refreshActiveGitHubAfterResume()
            }
        }
    }
}

private struct DockMagicUITestWeatherProvider: WeatherSnapshotProviding {
    func fetchWeather() async throws -> WeatherSnapshot {
        let now = Date()
        return WeatherSnapshot(
            location: "Ho Chi Minh City, Vietnam",
            temperatureCelsius: 29,
            feelsLikeCelsius: 32,
            conditionDescription: "Partly cloudy",
            condition: .partlyCloudy,
            highCelsius: 33,
            lowCelsius: 26,
            precipitationChance: 0.2,
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
                windowRouter: appDelegate.settingsWindowRouter
            )
        }
        .defaultSize(width: 1_160, height: 620)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: [SettingsWindowRouter.sceneID])
        .commands {
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
    let windowRouter: SettingsWindowRouter

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        DockMagicThemeRoot(
            content: SettingsView(appModel: appModel)
        )
        .defaultAppStorage(DockMagicRuntimeDefaults.current)
        .onAppear {
            windowRouter.install {
                openWindow(id: SettingsWindowRouter.sceneID)
            }
        }
    }
}
