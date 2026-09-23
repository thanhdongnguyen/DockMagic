import AppKit
import ApplicationServices
import SwiftUI

/// The app-owned replacement surface. It deliberately does not modify Dock tiles.
@MainActor
final class CustomDockController: NSObject {
    private let appModel: DockAppModel
    private let settings: SettingsWindowRouter
    private let runtime: CustomDockRuntime
    private var panel: CustomDockPanel?
    private var hostingView: NSHostingView<DockMagicThemeRoot<CustomDockView>>?
    private var dashboard: NSPanel?
    private var picker: NSPanel?
    private var statusItem: NSStatusItem?
    private var hoverTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var activeSlotID: UUID?
    private var observationToken: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var handoffTimer: Timer?
    private var lastRuntimeSignature = ""
    private var lastEdgeExit = Date.distantPast
    private var escapeMonitor: Any?
    private var pausedForAppleDock = false
    private(set) var errorMessage: String?

    init(appModel: DockAppModel, settings: SettingsWindowRouter) {
        self.appModel = appModel
        self.settings = settings
        runtime = CustomDockRuntime(preferences: appModel.preferences)
        super.init()
    }

    func start() {
        installStatusItem()
        // A previous process may have crashed after changing the system Dock.
        if DockAutoHideLease.hasUnrestoredChange {
            DockAutoHideLease.restore()
            appModel.preferences.dockMode = .dockActive
        }
        observeConfiguration()
        observeRuntime()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.showPanel() }
        }
        if appModel.preferences.dockMode == .shelfDock { enable() }
    }

    func stop() {
        hoverTask?.cancel()
        hideTask?.cancel()
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        picker?.close()
        dashboard?.close()
        panel?.close()
        hostingView = nil
        runtime.stop()
        handoffTimer?.invalidate()
        handoffTimer = nil
        appModel.setShelfVisibleFeatures([])
        DockAutoHideLease.restore()
        if let observationToken { NotificationCenter.default.removeObserver(observationToken) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    func setMode(_ mode: DockMode) {
        if mode == .shelfDock {
            enable()
        } else {
            disable()
        }
    }

    private func enable() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let isUITest = environment["DockMagicUITesting"] == "1"
        let forcedDenial = isUITest && environment[
            "DockMagicUITestDenyShelfAccessibility"
        ] == "1"
        let assumesAccessibility = isUITest && environment[
            "DockMagicUITestAssumeShelfAccessibility"
        ] == "1"
        let skipsDockLease = isUITest && environment[
            "DockMagicUITestSkipAppleDockLease"
        ] == "1"
        let disablesHandoff = isUITest && environment[
            "DockMagicUITestDisableDockHandoff"
        ] == "1"
        #else
        let forcedDenial = false
        let assumesAccessibility = false
        let skipsDockLease = false
        let disablesHandoff = false
        #endif
        guard !forcedDenial && (assumesAccessibility || AXIsProcessTrusted()) else {
            errorMessage = "Allow DockMagic in Privacy & Security → Accessibility, then try Shelf Dock again."
            appModel.preferences.customDockStatusMessage = errorMessage
            appModel.preferences.dockMode = .dockActive
            return
        }
        guard skipsDockLease || DockAutoHideLease.acquire() else {
            errorMessage = "macOS did not allow DockMagic to turn on Dock auto-hide. Check Automation access for System Events."
            appModel.preferences.customDockStatusMessage = errorMessage
            appModel.preferences.dockMode = .dockActive
            return
        }
        appModel.preferences.initializeCustomDockIfNeeded()
        errorMessage = nil
        appModel.preferences.customDockStatusMessage = nil
        appModel.preferences.dockMode = .shelfDock
        pausedForAppleDock = false
        runtime.start()
        appModel.setShelfVisibleFeatures(Set(
            appModel.preferences.customDockConfiguration.slots.map(\.feature)
        ))
        showPanel()
        if !disablesHandoff { startHandoffMonitor() }
        NSApplication.shared.setActivationPolicy(.accessory)
        updateStatusMenu()
    }

    private func disable() {
        closeDashboard()
        picker?.close()
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        runtime.stop()
        handoffTimer?.invalidate()
        handoffTimer = nil
        appModel.setShelfVisibleFeatures([])
        DockAutoHideLease.restore()
        appModel.preferences.dockMode = .dockActive
        pausedForAppleDock = false
        NSApplication.shared.setActivationPolicy(.regular)
        updateStatusMenu()
    }

    private func observeConfiguration() {
        withObservationTracking {
            _ = appModel.preferences.customDockConfiguration
            _ = appModel.preferences.dockMode
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.appModel.preferences.dockMode == .shelfDock && self.panel == nil {
                    self.enable()
                } else if self.appModel.preferences.dockMode == .shelfDock {
                    self.appModel.setShelfVisibleFeatures(Set(
                        self.appModel.preferences.customDockConfiguration.slots.map(\.feature)
                    ))
                    self.showPanel()
                } else if self.panel != nil { self.disable() }
                self.observeConfiguration()
            }
        }
    }

    private func observeRuntime() {
        withObservationTracking {
            _ = runtime.runningApps
            _ = runtime.minimizedWindows
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let signature = self.runtime.runningApps.map(\.id).joined(separator: "|")
                    + "#" + self.runtime.minimizedWindows.map(\.id).joined(separator: "|")
                if signature != self.lastRuntimeSignature {
                    self.lastRuntimeSignature = signature
                    self.showPanel()
                }
                self.observeRuntime()
            }
        }
    }

    private func startHandoffMonitor() {
        guard handoffTimer == nil else { return }
        handoffTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in self?.checkAppleDockHandoff() }
        }
    }

    private func checkAppleDockHandoff() {
        guard appModel.preferences.dockMode == .shelfDock,
              !pausedForAppleDock, let panel, let screen = panel.screen else { return }
        let point = NSEvent.mouseLocation
        let edge = appModel.preferences.customDockConfiguration.edge
        let atEdge: Bool = switch edge {
        case .bottom: point.y <= screen.frame.minY + 3
        case .left: point.x <= screen.frame.minX + 3
        case .right: point.x >= screen.frame.maxX - 3
        }
        if atEdge {
            lastEdgeExit = .now
            panel.orderOut(nil)
            closeDashboard()
            return
        }
        if NativeDockVisibility.isOverlapping(panel.frame) {
            panel.orderOut(nil)
            closeDashboard()
            lastEdgeExit = .now
            return
        }
        guard Date().timeIntervalSince(lastEdgeExit) > 0.8 else { return }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockMagic")
        statusItem = item
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let showItem = NSMenuItem(title: pausedForAppleDock ? "Resume Shelf Dock" : "Show Apple Dock", action: #selector(toggleAppleDock), keyEquivalent: "")
        showItem.target = self
        showItem.isEnabled = appModel.preferences.dockMode == .shelfDock
        menu.addItem(showItem)
        let exitItem = NSMenuItem(title: "Exit Shelf Dock", action: #selector(exitShelfDock), keyEquivalent: "")
        exitItem.target = self
        exitItem.isEnabled = appModel.preferences.dockMode == .shelfDock
        menu.addItem(exitItem)
        statusItem?.menu = menu
    }

    @objc private func openSettings() { _ = settings.showSettings(destination: .general) }
    @objc private func exitShelfDock() { disable() }
    @objc private func toggleAppleDock() {
        if pausedForAppleDock {
            guard DockAutoHideLease.acquire() else { return }
            pausedForAppleDock = false
            showPanel()
        } else {
            panel?.orderOut(nil)
            closeDashboard()
            DockAutoHideLease.restore()
            pausedForAppleDock = true
        }
        updateStatusMenu()
    }

    private func showPanel() {
        guard appModel.preferences.dockMode == .shelfDock, !pausedForAppleDock else { return }
        let config = appModel.preferences.customDockConfiguration
        guard let screen = Self.screen(for: config) else { return }
        let layout = CustomDockLayout(configuration: config, runtime: runtime, screen: screen)
        let root = DockMagicThemeRoot(content: CustomDockView(
            appModel: appModel, runtime: runtime, layout: layout,
            onAddSlot: { [weak self] in self?.openPicker() },
            onSlotClick: { [weak self] slot in self?.click(slot) },
            onSlotHover: { [weak self] slot, entered in self?.hover(slot, entered: entered) },
            onShelfDragBegin: { [weak self] in self?.closeDashboard() },
            onResize: { [weak self] value in
                guard let self else { return }
                self.appModel.preferences.updateCustomDock {
                    $0.preferredIconSize = value
                }
                // Pointer tracking runs in AppKit's event-tracking mode, so
                // render the new geometry synchronously for live feedback.
                self.showPanel()
            },
            onSettings: { [weak self] feature in
                guard let self else { return }
                _ = self.settings.showSettings(destination: SettingsDestination(activeFeature: feature))
            }
        ))
        let frame = layout.frame
        if panel == nil {
            let new = CustomDockPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            new.level = .floating
            new.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            new.isOpaque = false
            new.backgroundColor = .clear
            new.hasShadow = true
            new.title = "DockMagic Shelf Dock"
            new.setAccessibilityIdentifier("customDock.panel")
            panel = new
        }
        if let hostingView {
            // Keep the AppKit host stable while SwiftUI processes a pointer drag.
            // Replacing the content view here cancels the active resize gesture
            // after its first update.
            hostingView.rootView = root
        } else {
            let hostingView = NSHostingView(rootView: root)
            hostingView.setAccessibilityRole(.group)
            hostingView.setAccessibilityLabel("DockMagic Shelf Dock")
            self.hostingView = hostingView
            panel?.contentView = hostingView
        }
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
    }

    private static func screen(for config: CustomDockConfiguration) -> NSScreen? {
        if let id = config.displayID,
           let match = NSScreen.screens.first(where: {
               ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
           }) { return match }
        switch config.edge {
        case .left:
            return NSScreen.screens.min { $0.frame.minX < $1.frame.minX }
        case .right:
            return NSScreen.screens.max { $0.frame.maxX < $1.frame.maxX }
        case .bottom:
            return NSScreen.main ?? NSScreen.screens.first
        }
    }

    private func openPicker() {
        picker?.close()
        let size = CGSize(width: 300, height: 420)
        let screen = panel?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        guard let screen else { return }
        let dockFrame = panel?.frame ?? .zero
        let visibleFrame = screen.visibleFrame
        let preferredOrigin = switch appModel.preferences.customDockConfiguration.edge {
        case .bottom:
            CGPoint(x: NSEvent.mouseLocation.x - size.width / 2,
                    y: dockFrame.maxY + 12)
        case .left:
            CGPoint(x: dockFrame.maxX + 12,
                    y: NSEvent.mouseLocation.y - size.height / 2)
        case .right:
            CGPoint(x: dockFrame.minX - size.width - 12,
                    y: NSEvent.mouseLocation.y - size.height / 2)
        }
        let origin = CGPoint(
            x: min(max(preferredOrigin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(preferredOrigin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
        let frame = CGRect(origin: origin, size: size)
        let new = CustomDockPickerPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        new.title = "Add Shelf feature"
        new.isFloatingPanel = true
        new.level = .floating
        new.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        new.contentView = NSHostingView(rootView: DockMagicThemeRoot(content: CustomDockFeaturePicker(appModel: appModel) { [weak self] in
            self?.picker?.close()
            self?.picker = nil
        }))
        picker = new
        NSApplication.shared.activate(ignoringOtherApps: true)
        new.makeKeyAndOrderFront(nil)
    }

    private func click(_ slot: CustomDockSlot) {
        guard slot.feature.hasHoverDashboard else {
            _ = settings.showSettings(destination: SettingsDestination(activeFeature: slot.feature))
            return
        }
        if activeSlotID == slot.id { closeDashboard() }
        else { showDashboard(slot) }
    }

    private func hover(_ slot: CustomDockSlot, entered: Bool) {
        hoverTask?.cancel()
        if entered {
            hideTask?.cancel()
            guard slot.feature.hasHoverDashboard else { return }
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                self?.showDashboard(slot)
            }
        } else {
            hideTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                self?.closeDashboard()
            }
        }
    }

    private func showDashboard(_ slot: CustomDockSlot) {
        guard let screen = panel?.screen, slot.feature.hasHoverDashboard else { return }
        dashboard?.close()
        let size = DockHoverPanelPlacement.panelSize(for: slot.feature)
        let edge = appModel.preferences.customDockConfiguration.edge
        let pointerEdge: DockHoverPointerEdge = switch edge {
        case .bottom: .bottom
        case .left: .left
        case .right: .right
        }
        let point = NSEvent.mouseLocation
        let iconFrame = CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)
        let frame = DockHoverPanelPlacement.frame(iconFrame: iconFrame, pointerEdge: pointerEdge,
                                                   visibleFrame: screen.visibleFrame, screenFrame: screen.frame, panelSize: size)
        let new = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        new.level = .floating
        new.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        new.isOpaque = false
        new.backgroundColor = .clear
        new.hasShadow = false
        new.contentView = NSHostingView(rootView: DockHoverDashboardRoot(
            appModel: appModel, feature: slot.feature, pointerEdge: pointerEdge, panelSize: size
        ).onHover { [weak self] inside in
            if inside { self?.hideTask?.cancel() }
            else {
                self?.hideTask?.cancel()
                self?.hideTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    self?.closeDashboard()
                }
            }
        }.accessibilityIdentifier("customDock.dashboard.\(slot.id.uuidString)"))
        dashboard = new
        activeSlotID = slot.id
        new.orderFrontRegardless()
        if escapeMonitor == nil {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { Task { @MainActor in self?.closeDashboard() }; return nil }
                return event
            }
        }
    }

    private func closeDashboard() {
        hoverTask?.cancel()
        dashboard?.close()
        dashboard = nil
        activeSlotID = nil
    }
}

private final class CustomDockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class CustomDockPickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private enum NativeDockVisibility {
    static func isOverlapping(_ replacementFrame: CGRect) -> Bool {
        _ = CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        if (CFPreferencesCopyAppValue("autohide" as CFString,
                                      "com.apple.dock" as CFString) as? Bool) == false {
            return true
        }
        guard let dock = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else { return false }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        guard let list = findList(root, depth: 0),
              let nativeFrame = frame(of: list) else { return false }
        return nativeFrame.intersection(replacementFrame).width > 2
            && nativeFrame.intersection(replacementFrame).height > 2
    }

    private static func findList(_ element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth <= 5 else { return nil }
        var role: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if (role as? String) == (kAXListRole as String) { return element }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString,
                                           &value) == .success,
              let children = value as? [AXUIElement] else { return nil }
        for child in children {
            if let list = findList(child, depth: depth + 1) { return list }
        }
        return nil
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString,
                                           &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString,
                                            &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: point.x, y: mainTop - point.y - dimensions.height,
                      width: dimensions.width, height: dimensions.height)
    }
}

@MainActor
private enum DockAutoHideLease {
    private static let originalKey = "DockMagicOriginalAppleDockAutoHide"
    private static let leaseKey = "DockMagicChangedAppleDockAutoHide"
    private static var defaults: UserDefaults { DockMagicRuntimeDefaults.current }
    static var hasUnrestoredChange: Bool { defaults.bool(forKey: leaseKey) }

    static func acquire() -> Bool {
        _ = CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        guard let original = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool else { return false }
        if original { return true }
        defaults.set(original, forKey: originalKey)
        defaults.set(true, forKey: leaseKey)
        guard setAutoHide(true) else {
            restore()
            return false
        }
        return true
    }

    static func restore() {
        guard hasUnrestoredChange else { return }
        let original = defaults.bool(forKey: originalKey)
        if setAutoHide(original) {
            defaults.removeObject(forKey: leaseKey)
            defaults.removeObject(forKey: originalKey)
        }
    }

    private static func setAutoHide(_ enabled: Bool) -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"System Events\" to set autohide of dock preferences to \(enabled)")?
            .executeAndReturnError(&error)
        guard error == nil else { return false }
        for _ in 0..<12 {
            _ = CFPreferencesAppSynchronize("com.apple.dock" as CFString)
            if (CFPreferencesCopyAppValue("autohide" as CFString,
                                          "com.apple.dock" as CFString) as? Bool) == enabled {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
}
