import AppKit

@MainActor
final class SettingsWindowRouter {
    static let sceneID = "settings"
    static let windowTitle = "DockMagic Settings"

    private var openWindow: (() -> Void)?
    private let showExistingWindow: () -> Bool
    private let activateApplication: () -> Void

    init(
        showExistingWindow: (() -> Bool)? = nil,
        activateApplication: (() -> Void)? = nil
    ) {
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
    func showSettings() -> Bool {
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
}
