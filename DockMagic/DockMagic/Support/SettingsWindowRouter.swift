import AppKit
import Observation

@MainActor
@Observable
final class SettingsWindowRouter {
    static let sceneID = "settings"
    static let windowTitle = "DockMagic Settings"

    private(set) var destination: SettingsDestination

    private var openWindow: (() -> Void)?
    private let showExistingWindow: () -> Bool
    private let activateApplication: () -> Void

    init(
        initialDestination: SettingsDestination = .general,
        showExistingWindow: (() -> Bool)? = nil,
        activateApplication: (() -> Void)? = nil
    ) {
        destination = initialDestination
        self.showExistingWindow = showExistingWindow ?? {
            guard let window = NSApplication.shared.windows.first(where: {
                $0.title == SettingsWindowRouter.windowTitle
            }) else {
                return false
            }
            window.makeKeyAndOrderFront(nil)
            return true
        }
        self.activateApplication = activateApplication ?? {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func install(openWindow: @escaping () -> Void) {
        self.openWindow = openWindow
    }

    @discardableResult
    func showSettings(destination: SettingsDestination? = nil) -> Bool {
        if let destination {
            self.destination = destination
        }
        activateApplication()

        if showExistingWindow() {
            return true
        }

        guard let openWindow else {
            return false
        }

        openWindow()
        return true
    }

    func navigate(to destination: SettingsDestination) {
        self.destination = destination
    }
}
