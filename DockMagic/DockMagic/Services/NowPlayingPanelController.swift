import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class NowPlayingPanelState {
    var isPinned = false
}

/// Music owns an interactive host; the existing metric dashboards keep their policy.
@MainActor
final class NowPlayingPanelController {
    let state = NowPlayingPanelState()
    private var panel: NowPlayingPanel?
    private var hostingView: NSHostingView<AnyView>?
    private weak var appModel: DockAppModel?
    private var lastAnchor: DockHoverAnchor?
    private var showTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var localMonitor: Any?
    private var outsideMonitor: Any?
    private var menuObservers: [NSObjectProtocol] = []
    private var menuDepth = 0
    private var overlayLeases: Set<UUID> = []
    private var suspendedForDockMenu = false
    private var explicitOpen = false
    var isVisible: Bool { panel?.isVisible == true }

    func scheduleShow(anchor: DockHoverAnchor, appModel: DockAppModel) {
        lastAnchor = anchor
        self.appModel = appModel
        hideTask?.cancel()
        if isVisible { return }
        guard showTask == nil else { return }
        showTask = Task { [weak self, weak appModel] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, let appModel, appModel.preferences.activeFeature == .nowPlaying,
                  appModel.preferences.isDockHoverDashboardEnabled else { return }
            self.showTask = nil
            self.show(appModel: appModel, interactive: false)
        }
    }

    func show(appModel: DockAppModel, interactive: Bool) {
        self.appModel = appModel
        showTask?.cancel(); showTask = nil; hideTask?.cancel()
        if interactive { explicitOpen = true }
        if !isVisible {
            let screen = lastAnchor?.screen ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
            guard let screen else { return }
            let size = DockHoverPanelPlacement.nowPlayingPanelSize
            let edge = lastAnchor?.pointerEdge ?? .bottom
            let root = AnyView(NowPlayingPanelContent(store: appModel.nowPlayingStore, state: state, edge: edge, size: size,
                onPin: { [weak self] in self?.togglePin() }, onClose: { [weak self] in self?.hide() },
                onSettings: { [weak appModel] in appModel?.openNowPlayingSettings?() }))
            let panel: NowPlayingPanel
            if let existing = self.panel { panel = existing; hostingView?.rootView = root }
            else {
                panel = NowPlayingPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
                panel.level = .floating; panel.hidesOnDeactivate = false
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
                panel.isReleasedWhenClosed = false
                panel.title = "Now Playing"
                panel.identifier = NSUserInterfaceItemIdentifier("nowPlaying.panel")
                panel.onClose = { [weak self] in self?.hide() }
                let hosting = NSHostingView(rootView: root)
                panel.contentView = hosting; hostingView = hosting; self.panel = panel
            }
            let frame = lastAnchor.map { DockHoverPanelPlacement.frame(anchor: $0, panelSize: size) }
                ?? CGRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 24, width: size.width, height: size.height)
            panel.setFrame(frame, display: true)
            appModel.nowPlayingStore.setInterest(.panel, active: true)
            panel.orderFrontRegardless()
            installMonitors()
        }
        if interactive { panel?.makeKeyAndOrderFront(nil) }
    }

    func togglePin() {
        state.isPinned.toggle()
        if state.isPinned { hideTask?.cancel() }
        else { explicitOpen = false; scheduleHide() }
    }

    func scheduleHide() {
        showTask?.cancel(); showTask = nil
        hideTask?.cancel()
        guard isVisible, !state.isPinned, !explicitOpen, overlayLeases.isEmpty else { return }
        hideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(180))
                while let self, let panel = self.panel, panel.isVisible {
                    try Task.checkCancellation()
                    if self.state.isPinned || self.explicitOpen { return }
                    if !panel.frame.contains(NSEvent.mouseLocation), NSEvent.pressedMouseButtons == 0,
                       self.menuDepth == 0, self.overlayLeases.isEmpty {
                        try await Task.sleep(for: .milliseconds(150))
                        try Task.checkCancellation()
                        if !panel.frame.contains(NSEvent.mouseLocation), self.menuDepth == 0,
                           self.overlayLeases.isEmpty, NSEvent.pressedMouseButtons == 0 { self.hide(); return }
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
            } catch { return }
        }
    }

    func hideTransient() { if !state.isPinned && !explicitOpen { hide() } }
    func dockMenuWillOpen() {
        showTask?.cancel(); showTask = nil; hideTask?.cancel()
        suspendedForDockMenu = isVisible && (state.isPinned || explicitOpen)
        if suspendedForDockMenu { panel?.orderOut(nil) } else { hide() }
    }
    func dockMenuDidClose() {
        guard suspendedForDockMenu else { return }
        suspendedForDockMenu = false
        if appModel?.preferences.activeFeature == .nowPlaying { panel?.orderFrontRegardless() }
        else { hide() }
    }
    func hide() {
        showTask?.cancel(); showTask = nil; hideTask?.cancel(); hideTask = nil
        state.isPinned = false; explicitOpen = false; suspendedForDockMenu = false
        panel?.orderOut(nil)
        hostingView?.rootView = AnyView(EmptyView())
        appModel?.nowPlayingStore.setInterest(.panel, active: false)
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        localMonitor = nil; outsideMonitor = nil
        for observer in menuObservers { NotificationCenter.default.removeObserver(observer) }
        menuObservers.removeAll(); menuDepth = 0; overlayLeases.removeAll()
    }

    private func owns(_ window: NSWindow) -> Bool {
        var ancestor: NSWindow? = window
        while let current = ancestor {
            if current === panel { return true }
            ancestor = current.parent ?? current.sheetParent
        }
        return false
    }

    private func installMonitors() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.window === self.panel {
                if event.type == .keyDown, event.keyCode == 53 { self.hide(); return nil }
                if event.type == .leftMouseDown, self.panel?.isKeyWindow == false { self.panel?.makeKey() }
            } else if self.menuDepth == 0 && self.overlayLeases.isEmpty && !self.state.isPinned && !self.suspendedForDockMenu,
                      event.window.map({ !self.owns($0) }) ?? true {
                self.hide()
            }
            return event
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.state.isPinned, !self.suspendedForDockMenu, self.overlayLeases.isEmpty else { return }
                self.hide()
            }
        }
        menuObservers.append(NotificationCenter.default.addObserver(forName: DSOverlayActivity.began, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let window = note.object as? NSWindow, self.owns(window),
                      let id = note.userInfo?["id"] as? UUID else { return }
                self.overlayLeases.insert(id)
                self.hideTask?.cancel()
            }
        })
        menuObservers.append(NotificationCenter.default.addObserver(forName: DSOverlayActivity.ended, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let id = note.userInfo?["id"] as? UUID,
                      self.overlayLeases.remove(id) != nil else { return }
                self.scheduleHide()
            }
        })
        for (name, delta) in [(NSMenu.didBeginTrackingNotification, 1), (NSMenu.didEndTrackingNotification, -1)] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.menuDepth = max(0, self.menuDepth + delta) }
            })
        }
    }
}

private struct NowPlayingPanelContent: View {
    let store: NowPlayingStore
    let state: NowPlayingPanelState
    let edge: DockHoverPointerEdge
    let size: CGSize
    let onPin: () -> Void
    let onClose: () -> Void
    let onSettings: () -> Void
    var body: some View {
        DockMagicThemeRoot(content: DockHoverChrome(pointerEdge: edge, panelSize: size) {
            NowPlayingHoverDashboardView(store: store, isPinned: state.isPinned, onPin: onPin, onClose: onClose, onSettings: onSettings)
        })
        .frame(width: size.width, height: size.height)
    }
}

private final class NowPlayingPanel: NSPanel {
    var onClose: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onClose() }
}
