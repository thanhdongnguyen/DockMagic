import AppKit
import ApplicationServices
import Foundation

private struct FeatureSlot {
    let id = UUID()
    let name: String
}

private func handoffPortCallback(_ port: CFMessagePort?, _ messageID: Int32,
                                 _ data: CFData?, _ info: UnsafeMutableRawPointer?) -> Unmanaged<CFData>? {
    guard let info else { return nil }
    let delegate = Unmanaged<ReplacementDelegate>.fromOpaque(info).takeUnretainedValue()
    if messageID == 2 {
        delegate.preemptInput(reason: "external event tap")
        if let acknowledgment = CFDataCreate(nil, [1], 1) {
            return Unmanaged.passRetained(acknowledgment)
        }
    } else if messageID == 3 || messageID == 4 {
        delegate.applyFullScreen(messageID == 3)
    } else if messageID == 5 || messageID == 6 {
        delegate.applySystemSettings(messageID == 5)
    } else {
        delegate.applyDockVisibility(messageID == 1, source: "messagePort")
    }
    return nil
}

private func settingsInputCallback(_ proxy: CGEventTapProxy, _ type: CGEventType,
                                   _ event: CGEvent, _ info: UnsafeMutableRawPointer?)
    -> Unmanaged<CGEvent>? {
    guard let info else { return Unmanaged.passUnretained(event) }
    let delegate = Unmanaged<ReplacementDelegate>.fromOpaque(info).takeUnretainedValue()
    if type == .leftMouseDown {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier ==
            "com.apple.systempreferences" {
            delegate.preemptInput(reason: "Settings click")
        }
    } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        delegate.inputTapDisabled()
    }
    return Unmanaged.passUnretained(event)
}

private final class HoverButton: NSButton {
    var hoverChanged: ((Bool) -> Void)?
    var payload: String?
    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hoverChanged?(true) }
    override func mouseExited(with event: NSEvent) { hoverChanged?(false) }
}

final class ReplacementDelegate: NSObject, NSApplicationDelegate {
    private let handoffName = Notification.Name("DockMagicHandoffProbe")
    private var panel: NSPanel!
    private var dashboard: NSPanel?
    private var openSlotID: UUID?
    private var slots = [FeatureSlot(name: "CPU & RAM")]
    private var hoverWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var statusItem: NSStatusItem?
    private var settings: NSWindow?
    private var edgeMonitor: Any?
    private var edgeTimer: Timer?
    // A replacement must fail closed until the native Dock has been observed.
    private var nativeDockVisible = true
    private var fullScreenActive = false
    private var systemSettingsActive = false
    private var lastHandoffUptime: TimeInterval?
    private var handoffTimedOut = false
    private var lastEdgeYield: TimeInterval?
    private var handoffPort: CFMessagePort?
    private var handoffSource: CFRunLoopSource?
    private var inputTap: CFMachPort?
    private var inputSource: CFRunLoopSource?
    private var inputTapHealthy = false
    private var inputPreemptUntil: TimeInterval = 0
    private var inputPreemptEnabled: Bool {
        FileManager.default.fileExists(atPath:
            "/private/tmp/dockmagic-shelf-probe/input-preempt.txt")
    }
    private let logURL = URL(fileURLWithPath: "/private/tmp/dockmagic-shelf-probe/replacement.log")
    private var edge: String {
        (try? String(contentsOfFile: "/private/tmp/dockmagic-shelf-probe/placement.txt",
                     encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "bottom"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 58),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.animationBehavior = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.title = "DockMagic Custom Dock Probe"
        self.panel = panel
        edgeMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) {
            [weak self] event in
            guard let self else { return event }
            let pointer = self.panel.convertPoint(toScreen: event.locationInWindow)
            let atEdge = self.edge == "left" ? pointer.x <= self.panel.frame.minX + 4
                : self.edge == "right" ? pointer.x >= self.panel.frame.maxX - 4
                : pointer.y <= self.panel.frame.minY + 4
            if self.panel.isVisible && self.panel.frame.contains(pointer)
                && atEdge {
                self.panel.orderOut(nil)
                self.lastEdgeYield = ProcessInfo.processInfo.systemUptime
                self.log("edge yield pointer=\(pointer)")
            }
            return event
        }
        edgeTimer = Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if self.lastHandoffUptime.map({ now - $0 > 0.15 }) ?? true {
                if self.panel.isVisible {
                    self.closeDashboard()
                    self.panel.ignoresMouseEvents = true
                    self.panel.alphaValue = 0
                    self.panel.orderOut(nil)
                }
                self.nativeDockVisible = true
                if !self.handoffTimedOut {
                    self.handoffTimedOut = true
                    self.log("handoff heartbeat missing; custom dock hidden")
                }
                return
            }
            let pointer = NSEvent.mouseLocation
            guard let panelScreen = NSScreen.screens.first(where: {
                $0.frame.intersects(self.panel.frame)
            }) else { return }
            let pointerOnPanelScreen = panelScreen.frame.contains(pointer)
            let overDockSpan = self.edge == "bottom"
                ? self.panel.frame.minX <= pointer.x && pointer.x <= self.panel.frame.maxX
                : self.panel.frame.minY <= pointer.y && pointer.y <= self.panel.frame.maxY
            let approachDistance: CGFloat = overDockSpan ? 10 : 100
            let distance = self.edge == "left" ? pointer.x - panelScreen.frame.minX
                : self.edge == "right" ? panelScreen.frame.maxX - pointer.x
                : pointer.y - panelScreen.frame.minY
            if self.panel.isVisible && pointerOnPanelScreen && distance <= approachDistance {
                self.closeDashboard()
                self.panel.orderOut(nil)
                self.lastEdgeYield = ProcessInfo.processInfo.systemUptime
                self.log("global edge yield pointer=\(pointer) screen=\(panelScreen.frame) overDockSpan=\(overDockSpan)")
            } else if !self.panel.isVisible && !self.nativeDockVisible && !self.fullScreenActive
                      && !self.systemSettingsActive,
                      now >= self.inputPreemptUntil,
                      (!pointerOnPanelScreen || distance > 110),
                      let lastYield = self.lastEdgeYield,
                      ProcessInfo.processInfo.systemUptime - lastYield > 0.7 {
                self.panel.orderFrontRegardless()
                self.panel.alphaValue = 1
                self.panel.ignoresMouseEvents = false
                self.lastEdgeYield = nil
                self.log("edge restore pointer=\(pointer)")
            }
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(dockVisibilityChanged(_:)),
            name: handoffName, object: nil, suspensionBehavior: .deliverImmediately
        )
        var portContext = CFMessagePortContext(version: 0,
                                               info: Unmanaged.passUnretained(self).toOpaque(),
                                               retain: nil, release: nil, copyDescription: nil)
        handoffPort = CFMessagePortCreateLocal(nil, "DockMagicProbeHandoff" as CFString,
                                               handoffPortCallback, &portContext, nil)
        if let handoffPort {
            handoffSource = CFMessagePortCreateRunLoopSource(nil, handoffPort, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), handoffSource, .commonModes)
            log("handoff port ready")
        } else { log("handoff port unavailable") }
        if inputPreemptEnabled { installInputTap() }
        configureStatusItem()
        rebuild()
        log("launched hidden pending native Dock observation policy=\(NSApp.activationPolicy().rawValue)")
    }

    private func installInputTap() {
        log("input preflight listen=\(CGPreflightListenEventAccess()) ax=\(AXIsProcessTrusted())")
        let mask: CGEventMask = 1 << CGEventType.leftMouseDown.rawValue
        inputTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: mask,
                                     callback: settingsInputCallback,
                                     userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let inputTap else {
            log("input tap unavailable; fail closed")
            return
        }
        inputSource = CFMachPortCreateRunLoopSource(nil, inputTap, 0)
        if let inputSource { CFRunLoopAddSource(CFRunLoopGetMain(), inputSource, .commonModes) }
        CGEvent.tapEnable(tap: inputTap, enable: true)
        inputTapHealthy = true
        log("input tap ready")
    }

    fileprivate func preemptInput(reason: String) {
        inputPreemptUntil = ProcessInfo.processInfo.systemUptime + 0.8
        if panel.isVisible {
            closeDashboard()
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0
            panel.orderOut(nil)
        }
        log("input preempt \(reason) uptime=\(ProcessInfo.processInfo.systemUptime)")
    }

    fileprivate func inputTapDisabled() {
        inputTapHealthy = false
        if panel.isVisible {
            closeDashboard()
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0
            panel.orderOut(nil)
        }
        log("input tap disabled; fail closed")
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "DockMagic")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings Probe", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Probe", action: #selector(quitProbe), keyEquivalent: ""))
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        self.statusItem = item
    }

    private func rebuild() {
        let vertical = edge != "bottom"
        let tile: CGFloat = edge == "right" ? 38 : vertical ? 34 : 44
        let thickness: CGFloat = edge == "right" ? 50 : vertical ? 46 : 58
        let gap: CGFloat = 7
        let names = ["Finder", "Safari"]
        let count = names.count + slots.count + 3 // divider, plus, settings
        let length = 24 + CGFloat(count) * tile + CGFloat(count - 1) * gap
        let screen = edge == "left" ? NSScreen.screens.min(by: { $0.frame.minX < $1.frame.minX })!
            : edge == "right" ? NSScreen.screens.max(by: { $0.frame.maxX < $1.frame.maxX })!
            : NSScreen.main ?? NSScreen.screens[0]
        let frame = vertical
            ? NSRect(x: edge == "left" ? screen.frame.minX + 10 : screen.frame.maxX - thickness - 10,
                     y: screen.frame.midY - length / 2, width: thickness, height: length)
            : NSRect(x: screen.frame.midX - length / 2,
                     y: screen.frame.minY + 10, width: length, height: thickness)
        func itemFrame(_ offset: CGFloat) -> NSRect {
            vertical ? NSRect(x: (thickness - tile) / 2, y: length - offset - tile,
                              width: tile, height: tile)
                : NSRect(x: offset, y: (thickness - tile) / 2, width: tile, height: tile)
        }
        let surface = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        surface.material = .hudWindow
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.wantsLayer = true
        surface.layer?.cornerRadius = 14
        surface.layer?.masksToBounds = true

        var offset: CGFloat = 12
        for (bundle, name) in [("com.apple.finder", names[0]), ("com.apple.Safari", names[1])] {
            let button = HoverButton(frame: itemFrame(offset))
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.imagePosition = .imageOnly
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
                button.image = NSWorkspace.shared.icon(forFile: url.path)
            }
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = name
            button.setAccessibilityLabel("Open \(name)")
            button.identifier = NSUserInterfaceItemIdentifier("app.\(bundle)")
            button.target = self
            button.action = #selector(openApp(_:))
            button.payload = bundle
            surface.addSubview(button)
            offset += tile + gap
        }

        let line = NSView(frame: vertical
            ? NSRect(x: 6, y: length - offset - tile / 2, width: thickness - 12, height: 1)
            : NSRect(x: offset + tile / 2, y: 7, width: 1, height: thickness - 14))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        surface.addSubview(line)
        offset += tile + gap

        for (index, slot) in slots.enumerated() {
            let button = HoverButton(frame: itemFrame(offset))
            button.title = slot.name == "CPU & RAM" ? "CPU\n23%" : "☀︎\n24°"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 11
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.09).cgColor
            button.contentTintColor = .white
            button.identifier = NSUserInterfaceItemIdentifier("slot.\(slot.id.uuidString)")
            button.setAccessibilityLabel("\(slot.name), slot \(index + 1) of \(slots.count)")
            button.payload = slot.id.uuidString
            button.target = self
            button.action = #selector(toggleDashboard(_:))
            button.hoverChanged = { [weak self] entering in
                self?.scheduleHover(slotID: slot.id, entering: entering, button: button)
            }
            surface.addSubview(button)
            offset += tile + gap
        }

        let add = HoverButton(frame: itemFrame(offset))
        add.title = "+"
        add.font = NSFont.systemFont(ofSize: 26, weight: .light)
        add.isBordered = false
        add.wantsLayer = true
        add.layer?.cornerRadius = 11
        let border = CAShapeLayer()
        border.path = CGPath(roundedRect: add.bounds.insetBy(dx: 1.5, dy: 1.5),
                             cornerWidth: 10, cornerHeight: 10, transform: nil)
        border.fillColor = NSColor.clear.cgColor
        border.strokeColor = NSColor.white.withAlphaComponent(0.65).cgColor
        border.lineWidth = 1.5
        border.lineDashPattern = [4, 3]
        add.layer?.addSublayer(border)
        add.contentTintColor = .white
        add.setAccessibilityLabel("Add feature to DockMagic Shelf")
        add.identifier = NSUserInterfaceItemIdentifier("shelf.add")
        add.target = self
        add.action = #selector(showAddMenu(_:))
        surface.addSubview(add)
        offset += tile + gap

        let settingsButton = HoverButton(frame: itemFrame(offset))
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.isBordered = false
        settingsButton.setAccessibilityLabel("Open DockMagic Settings")
        settingsButton.identifier = NSUserInterfaceItemIdentifier("shelf.settings")
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        surface.addSubview(settingsButton)

        panel.setFrame(frame, display: true)
        panel.contentView = surface
        log("rebuild edge=\(edge) slots=\(slots.map { "\($0.name):\($0.id.uuidString.prefix(8))" }.joined(separator: ",")) frame=\(frame)")
    }

    @objc private func openApp(_ sender: HoverButton) {
        guard let bundle = sender.payload,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return }
        log("open app \(bundle)")
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error { self.log("open error \(error)") }
        }
    }

    @objc private func showAddMenu(_ sender: NSButton) {
        log("add menu opened")
        let menu = NSMenu(title: "Add feature")
        for name in ["CPU & RAM", "Weather"] {
            let item = NSMenuItem(title: name, action: #selector(addFeature(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    @objc private func addFeature(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        slots.append(FeatureSlot(name: name))
        rebuild()
        log("added \(name) count=\(slots.count)")
    }

    @objc private func toggleDashboard(_ sender: HoverButton) {
        guard let id = sender.payload.flatMap(UUID.init(uuidString:)) else { return }
        if openSlotID == id { closeDashboard(); return }
        showDashboard(for: id, anchor: sender)
    }

    private func scheduleHover(slotID: UUID, entering: Bool, button: NSButton) {
        hoverWork?.cancel()
        closeWork?.cancel()
        if entering {
            let work = DispatchWorkItem { [weak self, weak button] in
                guard let self, let button else { return }
                self.showDashboard(for: slotID, anchor: button)
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        } else {
            let work = DispatchWorkItem { [weak self] in self?.closeDashboard() }
            closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        }
    }

    private func showDashboard(for id: UUID, anchor: NSButton) {
        closeDashboard()
        guard let slot = slots.first(where: { $0.id == id }) else { return }
        let anchorScreen = anchor.convert(anchor.bounds, to: nil)
        let screenRect = panel.convertToScreen(anchorScreen)
        let popup = NSPanel(contentRect: NSRect(x: screenRect.midX - 100,
                                                 y: screenRect.maxY + 10,
                                                 width: 200, height: 86),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        popup.level = .statusBar
        popup.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1)
        popup.isOpaque = true
        popup.hasShadow = true
        popup.hidesOnDeactivate = false
        let label = NSTextField(labelWithString: "\(slot.name) Dashboard\nSlot \(id.uuidString.prefix(8))")
        label.frame = NSRect(x: 16, y: 18, width: 168, height: 50)
        label.textColor = .white
        label.alignment = .center
        label.maximumNumberOfLines = 2
        popup.contentView?.addSubview(label)
        popup.orderFrontRegardless()
        dashboard = popup
        openSlotID = id
        log("dashboard open slot=\(id.uuidString.prefix(8)) x=\(popup.frame.minX)")
    }

    private func closeDashboard() {
        dashboard?.orderOut(nil)
        dashboard = nil
        openSlotID = nil
    }

    @objc private func openSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 700, y: 300, width: 500, height: 320),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings?.title = "DockMagic Settings Probe"
        }
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        log("settings opened")
    }

    @objc private func quitProbe() { NSApp.terminate(nil) }

    @objc private func dockVisibilityChanged(_ notification: Notification) {
        let visible = (notification.object as? String) == "1"
        DispatchQueue.main.async { [weak self] in
            self?.applyDockVisibility(visible, source: "distributed")
        }
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else { return }
        applySystemSettings(app.bundleIdentifier == "com.apple.systempreferences")
    }

    fileprivate func applySystemSettings(_ active: Bool) {
        guard systemSettingsActive != active else { return }
        systemSettingsActive = active
        if active {
            closeDashboard()
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0
            panel.orderOut(nil)
        } else {
            // Wait for the native Dock's next settled observation before showing
            // a replacement after leaving the pane that can change Dock policy.
            inputPreemptUntil = max(inputPreemptUntil,
                                    ProcessInfo.processInfo.systemUptime + 0.3)
        }
        log("system settings active=\(active) custom visible=\(panel.isVisible)")
    }

    fileprivate func applyFullScreen(_ active: Bool) {
        guard fullScreenActive != active else { return }
        fullScreenActive = active
        if active {
            closeDashboard()
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0
            panel.orderOut(nil)
        } else if !nativeDockVisible && !systemSettingsActive && lastEdgeYield == nil,
                  ProcessInfo.processInfo.systemUptime >= inputPreemptUntil {
            panel.orderFrontRegardless()
            panel.alphaValue = 1
            panel.ignoresMouseEvents = false
        }
        log("full screen active=\(active) custom visible=\(panel.isVisible)")
    }

    fileprivate func applyDockVisibility(_ visible: Bool, source: String) {
        lastHandoffUptime = ProcessInfo.processInfo.systemUptime
        handoffTimedOut = false
        let changed = nativeDockVisible != visible
        nativeDockVisible = visible
        if visible {
            closeDashboard()
            panel.ignoresMouseEvents = true
            panel.alphaValue = 0
            panel.orderOut(nil)
        } else if !panel.isVisible && !fullScreenActive && !systemSettingsActive
                  && lastEdgeYield == nil,
                  ProcessInfo.processInfo.systemUptime >= inputPreemptUntil,
                  (!inputPreemptEnabled || inputTapHealthy) {
            let pointer = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            let pointerNearEdge = screen.map { screen in
                let distance = edge == "left" ? pointer.x - screen.frame.minX
                    : edge == "right" ? screen.frame.maxX - pointer.x
                    : pointer.y - screen.frame.minY
                return distance <= 110 && screen.frame.intersects(panel.frame)
            } ?? false
            if !pointerNearEdge {
                panel.orderFrontRegardless()
                panel.alphaValue = 1
                panel.ignoresMouseEvents = false
            }
        }
        if changed {
            log("native dock visible=\(visible) custom visible=\(panel.isVisible) source=\(source) uptime=\(ProcessInfo.processInfo.systemUptime)")
        }
    }

    private func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let data = Data(line.utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else { try? data.write(to: logURL) }
    }
}

let app = NSApplication.shared
let delegate = ReplacementDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
