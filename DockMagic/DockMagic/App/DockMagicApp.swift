import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel: DockAppModel
    let settingsWindowRouter: SettingsWindowRouter

    private var dockTileController: DockTileController?

    override convenience init() {
        self.init(
            appModel: DockAppModel(),
            settingsWindowRouter: SettingsWindowRouter()
        )
    }

    init(
        appModel: DockAppModel,
        settingsWindowRouter: SettingsWindowRouter
    ) {
        self.appModel = appModel
        self.settingsWindowRouter = settingsWindowRouter
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        dockTileController = DockTileController(
            initialPresentation: appModel.dockPresentation
        )
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
        .defaultSize(width: 980, height: 720)
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
        .onAppear {
            windowRouter.install {
                openWindow(id: SettingsWindowRouter.sceneID)
            }
        }
    }
}
