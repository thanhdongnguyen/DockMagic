import AppKit
import Observation
import OSLog

@MainActor
@Observable
final class SettingsWindowRouter {
    static let sceneID = "settings"
    static let windowTitle = "DockMagic Settings"

    private(set) var destination: SettingsDestination

    private var openWindow: (() -> Void)?
    private var windowController: NSWindowController?
    private let logger = Logger(subsystem: "com.hypevibe.DockMagic", category: "Settings")
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
                $0.title == SettingsWindowRouter.windowTitle && $0.contentView != nil
            }) else {
                return false
            }
            if window.isMiniaturized { window.deminiaturize(nil) }
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

    /// Installed by the app delegate before any window has appeared. Keep the
    /// controller while open so repeated Dock clicks reuse one window.
    func installDefaultWindowFactory(_ makeWindow: @escaping () -> NSWindow) {
        guard openWindow == nil else { return }
        install { [weak self] in
            guard let self else { return }
            if self.windowController == nil {
                let window = makeWindow()
                window.isReleasedWhenClosed = false
                self.windowController = SettingsWindowController(window: window) { [weak self] in
                    self?.windowController = nil
                }
                self.logger.notice("Created Settings window on demand.")
            }
            guard let window = self.windowController?.window else { return }
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
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
            logger.error("Settings requested before a window opener was installed.")
            return false
        }

        openWindow()
        return true
    }

    func navigate(to destination: SettingsDestination) {
        self.destination = destination
    }
}

/// Closing releases the SwiftUI content, which observes the router, before
/// releasing its controller. This avoids a router → window → view retain cycle.
@MainActor
private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(window: NSWindow, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        onClose()
    }
}
