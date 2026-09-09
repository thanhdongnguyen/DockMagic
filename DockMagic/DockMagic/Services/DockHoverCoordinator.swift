import AppKit
import ApplicationServices
import Observation
import OSLog
import SwiftUI

private let dockHoverLogger = Logger(
    subsystem: "com.hypevibe.DockMagic",
    category: "DockHover"
)

enum DockHoverPermissionState: Equatable, Sendable {
    case disabled
    case needsPermission
    case awaitingUserAction
    case authorized

    var title: String {
        switch self {
        case .disabled:
            "Off"
        case .needsPermission:
            "Accessibility required"
        case .awaitingUserAction:
            "Waiting for permission"
        case .authorized:
            "Ready"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            "DockMagic does not inspect the Dock accessibility hierarchy."
        case .needsPermission:
            "Allow Accessibility so DockMagic can detect its own hovered Dock icon and read that icon's position."
        case .awaitingUserAction:
            "Turn on DockMagic in Privacy & Security → Accessibility, then return here."
        case .authorized:
            "DockMagic can detect its own Dock icon. It does not capture the screen or read keystrokes."
        }
    }
}

@MainActor
protocol DockHoverAccessibilityAuthorizing: AnyObject {
    func isTrusted() -> Bool
    @discardableResult func requestTrustPrompt() -> Bool
}

@MainActor
private final class SystemDockHoverAccessibilityAuthorizer:
    DockHoverAccessibilityAuthorizing
{
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestTrustPrompt() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([
            promptKey: true
        ] as CFDictionary)
    }
}

@MainActor
@Observable
final class DockHoverPermissionController {
    private(set) var state: DockHoverPermissionState = .disabled

    @ObservationIgnored
    private let authorizer: any DockHoverAccessibilityAuthorizing

    @ObservationIgnored
    private var isEnabled = false

    @ObservationIgnored
    private var recheckTask: Task<Void, Never>?

    init(
        authorizer: (any DockHoverAccessibilityAuthorizing)? = nil
    ) {
        self.authorizer = authorizer
            ?? SystemDockHoverAccessibilityAuthorizer()
    }

    func synchronize(isEnabled: Bool) {
        self.isEnabled = isEnabled
        guard isEnabled else {
            recheckTask?.cancel()
            recheckTask = nil
            state = .disabled
            return
        }

        if authorizer.isTrusted() {
            recheckTask?.cancel()
            recheckTask = nil
            state = .authorized
        } else if state != .awaitingUserAction {
            state = .needsPermission
        }
    }

    func refresh() {
        synchronize(isEnabled: isEnabled)
    }

    func requestAccess() {
        guard isEnabled else {
            return
        }

        if authorizer.requestTrustPrompt() || authorizer.isTrusted() {
            state = .authorized
            return
        }

        state = .awaitingUserAction
        beginPermissionRecheck()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func stop() {
        recheckTask?.cancel()
        recheckTask = nil
    }

    private func beginPermissionRecheck() {
        recheckTask?.cancel()
        recheckTask = Task { @MainActor [weak self] in
            for _ in 0..<45 {
                guard let self, !Task.isCancelled, self.isEnabled else {
                    return
                }

                if self.authorizer.isTrusted() {
                    self.state = .authorized
                    self.recheckTask = nil
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }

            guard let self, !Task.isCancelled, self.isEnabled else {
                return
            }
            self.state = .needsPermission
            self.recheckTask = nil
        }
    }
}

@MainActor
final class DockHoverCoordinator {
    let permissionController: DockHoverPermissionController

    private let appModel: DockAppModel
    private let dockObserver: DockAccessibilityObserver
    private let panelController: DockHoverPanelController
    private var isRunning = false
    private var configurationObservationActive = false
    private var isDockMenuPresented = false
    private var healthTask: Task<Void, Never>?

    init(
        appModel: DockAppModel,
        permissionController: DockHoverPermissionController,
        dockObserver: DockAccessibilityObserver? = nil,
        panelController: DockHoverPanelController? = nil
    ) {
        self.appModel = appModel
        self.permissionController = permissionController
        self.dockObserver = dockObserver ?? DockAccessibilityObserver()
        self.panelController = panelController ?? DockHoverPanelController()
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        applyConfiguration()
        observeConfiguration()
        startHealthChecks()
    }

    func stop() {
        isRunning = false
        configurationObservationActive = false
        isDockMenuPresented = false
        healthTask?.cancel()
        healthTask = nil
        dockObserver.stop()
        panelController.hide()
        permissionController.stop()
    }

    func applicationDidBecomeActive() {
        guard isRunning else {
            return
        }
        permissionController.synchronize(
            isEnabled: appModel.preferences.isDockHoverDashboardEnabled
        )
        applyConfiguration()
    }

    func dockMenuWillOpen() {
        isDockMenuPresented = true
        panelController.hide()
    }

    private func observeConfiguration() {
        guard isRunning, !configurationObservationActive else {
            return
        }

        configurationObservationActive = true
        withObservationTracking {
            _ = appModel.preferences.isDockHoverDashboardEnabled
            _ = appModel.preferences.activeFeature
            _ = permissionController.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else {
                    return
                }
                self.configurationObservationActive = false
                self.applyConfiguration()
                self.observeConfiguration()
            }
        }
    }

    private func applyConfiguration() {
        let isEnabled = appModel.preferences.isDockHoverDashboardEnabled
        let activeFeature = appModel.preferences.activeFeature
        permissionController.synchronize(isEnabled: isEnabled)

        guard isEnabled,
              permissionController.state == .authorized,
              activeFeature.hasHoverDashboard else {
            dockObserver.stop()
            panelController.hide()
            return
        }

        let attached = dockObserver.ensureAttached { [weak self] event in
            guard let self else {
                return
            }
            switch event {
            case let .hovered(anchor):
                guard !self.isDockMenuPresented else {
                    return
                }
                self.panelController.scheduleShow(
                    anchor: anchor,
                    appModel: self.appModel
                )
            case .exited:
                self.isDockMenuPresented = false
                self.panelController.scheduleHide()
            }
        }
        if !attached {
            panelController.hide()
        }
    }

    private func startHealthChecks() {
        healthTask?.cancel()
        healthTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.isRunning {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, self.isRunning else {
                    return
                }
                self.permissionController.synchronize(
                    isEnabled: self.appModel.preferences
                        .isDockHoverDashboardEnabled
                )
                self.applyConfiguration()
            }
        }
    }
}

enum DockHoverObservationEvent {
    case hovered(DockHoverAnchor)
    case exited
}

struct DockHoverAnchor {
    let iconFrame: CGRect
    let screen: NSScreen
    let pointerEdge: DockHoverPointerEdge
}

@MainActor
final class DockAccessibilityObserver {
    typealias EventHandler = @MainActor (DockHoverObservationEvent) -> Void

    private static let dockBundleIdentifier = "com.apple.dock"
    private static let dockMagicBundleIdentifier = "com.hypevibe.DockMagic"

    private var observer: AXObserver?
    private var dockList: AXUIElement?
    private var observedPID: pid_t?
    private var handler: EventHandler?

    @discardableResult
    func ensureAttached(handler: @escaping EventHandler) -> Bool {
        guard AXIsProcessTrusted() else {
            dockHoverLogger.error(
                "Cannot attach Dock observer because Accessibility is not trusted."
            )
            stop()
            return false
        }
        guard let dockApplication = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.dockBundleIdentifier
        ).first else {
            dockHoverLogger.error("Cannot find the running Dock application.")
            stop()
            return false
        }

        if observedPID == dockApplication.processIdentifier,
           let dockList,
           copyString(kAXRoleAttribute as CFString, from: dockList)
                == (kAXListRole as String) {
            self.handler = handler
            dockHoverLogger.debug(
                "Reusing Dock observer for pid \(dockApplication.processIdentifier)."
            )
            handleSelectionChanged()
            return true
        }

        stop()
        self.handler = handler
        let dockElement = AXUIElementCreateApplication(
            dockApplication.processIdentifier
        )
        AXUIElementSetMessagingTimeout(dockElement, 0.25)

        guard let list = findDockList(in: dockElement) else {
            dockHoverLogger.error(
                "Could not find an AXList containing application Dock items."
            )
            return false
        }
        AXUIElementSetMessagingTimeout(list, 0.25)

        var createdObserver: AXObserver?
        let createResult = AXObserverCreate(
            dockApplication.processIdentifier,
            dockHoverAXObserverCallback,
            &createdObserver
        )
        guard createResult == .success, let createdObserver else {
            dockHoverLogger.error(
                "AXObserverCreate failed with code \(createResult.rawValue)."
            )
            return false
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let notificationResult = AXObserverAddNotification(
            createdObserver,
            list,
            kAXSelectedChildrenChangedNotification as CFString,
            context
        )
        guard notificationResult == .success else {
            dockHoverLogger.error(
                "Adding the Dock selection notification failed with code \(notificationResult.rawValue)."
            )
            return false
        }

        let runLoopSource = AXObserverGetRunLoopSource(createdObserver)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        observer = createdObserver
        dockList = list
        observedPID = dockApplication.processIdentifier
        dockHoverLogger.notice(
            "Attached Dock hover observer to pid \(dockApplication.processIdentifier)."
        )
        handleSelectionChanged()
        return true
    }

    func stop() {
        if let observer, let dockList {
            AXObserverRemoveNotification(
                observer,
                dockList,
                kAXSelectedChildrenChangedNotification as CFString
            )
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }

        observer = nil
        dockList = nil
        observedPID = nil
        handler?(.exited)
        handler = nil
    }

    fileprivate func handleSelectionChanged() {
        guard AXIsProcessTrusted(), let dockList else {
            handler?(.exited)
            return
        }

        guard let selected = copyElements(
            kAXSelectedChildrenAttribute as CFString,
            from: dockList
        )?.first else {
            handler?(.exited)
            return
        }

        let subrole = copyString(kAXSubroleAttribute as CFString, from: selected)
        let url = copyURL(kAXURLAttribute as CFString, from: selected)
        let selectedBundleIdentifier = url.flatMap {
            Bundle(url: $0)?.bundleIdentifier
        }
        dockHoverLogger.debug(
            "Selected Dock item subrole=\(subrole ?? "<none>", privacy: .public) bundle=\(selectedBundleIdentifier ?? "<none>", privacy: .public)."
        )

        guard subrole == (kAXApplicationDockItemSubrole as String),
              selectedBundleIdentifier == Self.dockMagicBundleIdentifier,
              let quartzFrame = copyFrame(from: selected),
              let converted = DockHoverScreenGeometry.convert(
                  quartzFrame: quartzFrame
              ) else {
            handler?(.exited)
            return
        }

        dockHoverLogger.notice(
            "Hovering DockMagic at x=\(quartzFrame.minX) y=\(quartzFrame.minY) width=\(quartzFrame.width) height=\(quartzFrame.height)."
        )

        handler?(.hovered(DockHoverAnchor(
            iconFrame: converted.frame,
            screen: converted.screen,
            pointerEdge: DockHoverScreenGeometry.pointerEdge(
                for: converted.frame,
                in: converted.screen.frame
            )
        )))
    }

    private func findDockList(
        in element: AXUIElement,
        depth: Int = 0
    ) -> AXUIElement? {
        guard depth <= 5 else {
            return nil
        }

        let role = copyString(kAXRoleAttribute as CFString, from: element)
        if role == (kAXListRole as String), containsApplicationDockItem(element) {
            return element
        }

        for child in copyElements(kAXChildrenAttribute as CFString, from: element)
            ?? [] {
            if let match = findDockList(in: child, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    private func containsApplicationDockItem(_ element: AXUIElement) -> Bool {
        (copyElements(kAXChildrenAttribute as CFString, from: element) ?? [])
            .contains { child in
                copyString(kAXSubroleAttribute as CFString, from: child)
                    == (kAXApplicationDockItemSubrole as String)
            }
    }

    private func copyElements(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> [AXUIElement]? {
        copyAttribute(attribute, from: element) as? [AXUIElement]
    }

    private func copyString(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> String? {
        copyAttribute(attribute, from: element) as? String
    }

    private func copyURL(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> URL? {
        copyAttribute(attribute, from: element) as? URL
    }

    private func copyAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        ) == .success else {
            return nil
        }
        return value
    }

    private func copyFrame(from element: AXUIElement) -> CGRect? {
        guard let positionValue = copyAttribute(
            kAXPositionAttribute as CFString,
            from: element
        ), let sizeValue = copyAttribute(
            kAXSizeAttribute as CFString,
            from: element
        ), CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(
            positionValue as! AXValue,
            .cgPoint,
            &position
        ), AXValueGetValue(
            sizeValue as! AXValue,
            .cgSize,
            &size
        ) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }
}

private func dockHoverAXObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else {
        return
    }
    let controller = Unmanaged<DockAccessibilityObserver>
        .fromOpaque(context)
        .takeUnretainedValue()
    Task { @MainActor [weak controller] in
        controller?.handleSelectionChanged()
    }
}

enum DockHoverScreenGeometry {
    struct Conversion {
        let frame: CGRect
        let screen: NSScreen
    }

    static func convert(
        quartzFrame: CGRect,
        screens: [NSScreen] = NSScreen.screens
    ) -> Conversion? {
        let midpoint = CGPoint(x: quartzFrame.midX, y: quartzFrame.midY)

        for screen in screens {
            guard let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ]
                as? NSNumber else {
                continue
            }
            let quartzBounds = CGDisplayBounds(CGDirectDisplayID(
                displayID.uint32Value
            ))
            guard quartzBounds.contains(midpoint) else {
                continue
            }

            let x = screen.frame.minX
                + quartzFrame.minX
                - quartzBounds.minX
            let y = screen.frame.minY
                + quartzBounds.maxY
                - quartzFrame.maxY
            return Conversion(
                frame: CGRect(
                    x: x,
                    y: y,
                    width: quartzFrame.width,
                    height: quartzFrame.height
                ),
                screen: screen
            )
        }

        return nil
    }

    static func pointerEdge(
        for iconFrame: CGRect,
        in screenFrame: CGRect
    ) -> DockHoverPointerEdge {
        let bottomDistance = abs(iconFrame.minY - screenFrame.minY)
        let leftDistance = abs(iconFrame.minX - screenFrame.minX)
        let rightDistance = abs(screenFrame.maxX - iconFrame.maxX)
        let minimum = min(bottomDistance, leftDistance, rightDistance)

        if minimum == leftDistance {
            return .left
        }
        if minimum == rightDistance {
            return .right
        }
        return .bottom
    }
}

enum DockHoverPanelPlacement {
    static let standardPanelSize = CGSize(width: 440, height: 304)
    static let systemMetricsPanelSize = CGSize(width: 620, height: 474)
    static let weatherPanelSize = CGSize(width: 440, height: 420)
    static let codexPanelSize = CGSize(width: 440, height: 556)
    static let claudeCodePanelSize = CGSize(width: 440, height: 740)
    static let pointerExtent: CGFloat = 10
    static let iconClearance: CGFloat = 2
    static let windowLevel = NSWindow.Level(
        rawValue: NSWindow.Level.popUpMenu.rawValue + 1
    )
    // System share UI is presented above a normal-level source window. The
    // hover panel temporarily uses this level while sharing so it cannot cover
    // the picker or the selected sharing service's window.
    static let sharePresentationWindowLevel = NSWindow.Level.normal

    static func panelSize(for feature: DockFeature) -> CGSize {
        switch feature {
        case .systemMetrics:
            systemMetricsPanelSize
        case .weather:
            weatherPanelSize
        case .codex:
            codexPanelSize
        case .claudeCode, .antigravity:
            claudeCodePanelSize
        default:
            standardPanelSize
        }
    }

    static func frame(
        anchor: DockHoverAnchor,
        panelSize: CGSize = standardPanelSize
    ) -> CGRect {
        frame(
            iconFrame: anchor.iconFrame,
            pointerEdge: anchor.pointerEdge,
            visibleFrame: anchor.screen.visibleFrame,
            screenFrame: anchor.screen.frame,
            panelSize: panelSize
        )
    }

    static func frame(
        iconFrame: CGRect,
        pointerEdge: DockHoverPointerEdge,
        visibleFrame: CGRect,
        screenFrame: CGRect? = nil,
        panelSize: CGSize = standardPanelSize
    ) -> CGRect {
        var origin: CGPoint
        switch pointerEdge {
        case .bottom:
            origin = CGPoint(
                x: iconFrame.midX - panelSize.width / 2,
                y: iconFrame.maxY + iconClearance
            )
        case .left:
            origin = CGPoint(
                x: iconFrame.maxX + iconClearance,
                y: iconFrame.midY - panelSize.height / 2
            )
        case .right:
            origin = CGPoint(
                x: iconFrame.minX - panelSize.width - iconClearance,
                y: iconFrame.midY - panelSize.height / 2
            )
        }

        let visible = visibleFrame.insetBy(dx: 8, dy: 8)
        let screen = (screenFrame ?? visibleFrame).insetBy(dx: 8, dy: 8)
        let minimumX = pointerEdge == .left
            ? screen.minX
            : visible.minX
        let maximumX = pointerEdge == .right
            ? screen.maxX - panelSize.width
            : visible.maxX - panelSize.width
        let minimumY = pointerEdge == .bottom
            ? screen.minY
            : visible.minY
        let maximumY = visible.maxY - panelSize.height
        origin.x = min(
            max(origin.x, minimumX),
            max(minimumX, maximumX)
        )
        origin.y = min(
            max(origin.y, minimumY),
            max(minimumY, maximumY)
        )
        return CGRect(origin: origin, size: panelSize)
    }
}

@MainActor
final class DockHoverPanelController {
    private var panel: DockHoverPanel?
    private var hostingView: NSHostingView<AnyView>?
    private let showDelay: Duration
    private var pendingShowTask: Task<Void, Never>?
    private var latestHoverAnchor: DockHoverAnchor?
    private var pendingHideTask: Task<Void, Never>?
    private var activeStreakCelebration: TokenUsageStreakCelebration?

    init(showDelay: Duration = .seconds(1)) {
        self.showDelay = showDelay
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func scheduleShow(anchor: DockHoverAnchor, appModel: DockAppModel) {
        guard appModel.preferences.isDockHoverDashboardEnabled,
              appModel.preferences.activeFeature.hasHoverDashboard else {
            hide()
            return
        }

        // Returning from the dashboard to the icon keeps an open panel alive.
        if isVisible {
            show(anchor: anchor, appModel: appModel)
            return
        }

        // Dock can repeat selection notifications while the icon magnifies.
        // Update placement without restarting the continuous hover countdown.
        latestHoverAnchor = anchor
        guard pendingShowTask == nil else { return }
        let delay = showDelay
        pendingShowTask = Task { @MainActor [weak self, weak appModel] in
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                guard let self else { return }
                self.pendingShowTask = nil
                let anchor = self.latestHoverAnchor
                self.latestHoverAnchor = nil
                guard let appModel, let anchor,
                      appModel.preferences.isDockHoverDashboardEnabled else {
                    return
                }
                self.show(anchor: anchor, appModel: appModel)
            } catch {
                return
            }
        }
    }

    private func cancelPendingShow() {
        pendingShowTask?.cancel()
        pendingShowTask = nil
        latestHoverAnchor = nil
    }

    private func show(anchor: DockHoverAnchor, appModel: DockAppModel) {
        guard appModel.preferences.activeFeature.hasHoverDashboard else {
            hide()
            return
        }

        pendingHideTask?.cancel()
        pendingHideTask = nil
        let panelSize = DockHoverPanelPlacement.panelSize(
            for: appModel.preferences.activeFeature
        )
        let provider = streakProvider(
            for: appModel.preferences.activeFeature
        )
        if activeStreakCelebration?.provider != provider {
            activeStreakCelebration = provider.flatMap {
                appModel.streakStore.claimCelebration(for: $0)
            }
        } else if activeStreakCelebration == nil, let provider {
            activeStreakCelebration = appModel.streakStore
                .claimCelebration(for: provider)
        }
        let celebration = activeStreakCelebration
        let rootView = AnyView(
            DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: anchor.pointerEdge,
                panelSize: panelSize,
                initialStreakCelebration: celebration,
                onStreakCelebrationDismissed: { [weak self] celebrationID in
                    guard self?.activeStreakCelebration?.id == celebrationID else {
                        return
                    }
                    self?.activeStreakCelebration = nil
                }
            )
        )
        let panel = panel ?? makePanel(
            rootView: rootView,
            panelSize: panelSize
        )
        hostingView?.rootView = rootView
        panel.setFrame(
            DockHoverPanelPlacement.frame(
                anchor: anchor,
                panelSize: panelSize
            ),
            display: true
        )
        panel.orderFrontRegardless()
        dockHoverLogger.notice(
            "Presented hover dashboard at x=\(panel.frame.minX) y=\(panel.frame.minY)."
        )
    }

    func hide() {
        cancelPendingShow()
        pendingHideTask?.cancel()
        pendingHideTask = nil
        panel?.orderOut(nil)
    }

    func scheduleHide() {
        cancelPendingShow()
        pendingHideTask?.cancel()
        pendingHideTask = nil
        guard isVisible else { return }
        pendingHideTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(160))
                guard let self, let panel = self.panel else { return }

                while panel.isVisible,
                      panel.frame.contains(NSEvent.mouseLocation) {
                    try await Task.sleep(for: .milliseconds(100))
                }

                try await Task.sleep(for: .milliseconds(120))
                try Task.checkCancellation()
                panel.orderOut(nil)
                self.pendingHideTask = nil
            } catch {
                return
            }
        }
    }

    private func streakProvider(
        for feature: DockFeature
    ) -> TokenUsageProvider? {
        switch feature {
        case .codex:
            .codex
        case .antigravity:
            .antigravity
        case .claudeCode:
            .claudeCode
        case .dockMagic, .systemMetrics, .network, .storage, .weather,
             .clock, .batteries, .github, .searchConsole:
            nil
        }
    }

    private func makePanel(
        rootView: AnyView,
        panelSize: CGSize
    ) -> DockHoverPanel {
        let panel = DockHoverPanel(
            contentRect: CGRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = panel.contentView?.bounds
            ?? CGRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.level = DockHoverPanelPlacement.windowLevel
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.animationBehavior = .utilityWindow

        self.panel = panel
        self.hostingView = hostingView
        return panel
    }
}

private final class DockHoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
