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
            appModel: DockAppModel(),
            settingsWindowRouter: SettingsWindowRouter(),
            dockTile: NSApplication.shared.dockTile,
            appearanceStore: DockMagicRuntimeDefaults.current,
            notificationCenter: .default,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
        )
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
            }
        }
        workspaceSessionActiveObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.appModel.refreshActiveWeatherAfterResume()
            }
        }
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
        .defaultSize(width: 1_020, height: 740)
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
