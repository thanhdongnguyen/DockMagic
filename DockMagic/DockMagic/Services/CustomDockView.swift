import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct CustomDockLayout {
    let configuration: CustomDockConfiguration
    let screen: NSScreen
    let iconSize: CGFloat
    let itemGap: CGFloat
    let frame: CGRect
    let pinned: [CustomDockApplication]
    let running: [CustomDockApplication]
    let recent: [CustomDockApplication]
    let slots: [CustomDockSlot]
    let stacks: [CustomDockStack]
    let windows: [CustomDockMinimizedWindow]
    let overflowCount: Int

    var vertical: Bool { configuration.edge != .bottom }

    init(configuration: CustomDockConfiguration, runtime: CustomDockRuntime, screen: NSScreen) {
        self.configuration = configuration
        self.screen = screen
        let pinnedIDs = Set(configuration.pinnedApps.map(\.id))
        let running = runtime.runningApps.filter {
            !pinnedIDs.contains($0.id) && $0.id != "com.apple.finder"
        }
        let runningIDs = Set(running.map(\.id))
        let recent = configuration.recentApps.filter {
            !pinnedIDs.contains($0.id) && !runningIDs.contains($0.id)
        }
        let available = configuration.edge == .bottom ? screen.frame.width - 24 : screen.frame.height - 40
        var size = CGFloat(configuration.preferredIconSize)
        let allCount = 4 + configuration.pinnedApps.count + running.count + recent.count
            + configuration.slots.count + configuration.stacks.count + runtime.minimizedWindows.count
        size = max(16, min(size, (available - 70) / CGFloat(max(1, allCount)) - 4))
        let gap = 2 + max(0, size - 44) / 8
        itemGap = gap
        let capacity = max(4, Int((available - 70) / (size + max(gap, 4))))
        var remaining = max(0, capacity - 4)
        self.pinned = Array(configuration.pinnedApps.prefix(remaining)); remaining -= pinned.count
        self.running = Array(running.prefix(remaining)); remaining -= self.running.count
        self.slots = Array(configuration.slots.prefix(remaining)); remaining -= slots.count
        self.stacks = Array(configuration.stacks.prefix(remaining)); remaining -= stacks.count
        self.windows = Array(runtime.minimizedWindows.prefix(remaining)); remaining -= windows.count
        self.recent = Array(recent.prefix(remaining))
        overflowCount = allCount - 4 - pinned.count - self.running.count - slots.count
            - stacks.count - windows.count - self.recent.count
        iconSize = size
        let visibleCount = 4 + pinned.count + self.running.count + slots.count
            + stacks.count + windows.count + self.recent.count + (overflowCount > 0 ? 1 : 0)
        let length = min(available, CGFloat(visibleCount) * (size + gap) + 70
                         + CGFloat(slots.count) * max(0, 4 - gap))
        // Empirical macOS 26.2 AX baselines: 30→44, 44→58, 60→80 pt.
        let thickness = size + 14 + max(0, size - 44) * 0.375
        switch configuration.edge {
        case .bottom:
            frame = CGRect(x: screen.frame.midX - length / 2, y: screen.frame.minY + 10,
                           width: length, height: thickness)
        case .left:
            frame = CGRect(x: screen.frame.minX + 10, y: screen.visibleFrame.midY - length / 2,
                           width: thickness, height: length)
        case .right:
            frame = CGRect(x: screen.frame.maxX - thickness - 10, y: screen.visibleFrame.midY - length / 2,
                           width: thickness, height: length)
        }
    }
}

private let customDockMagnificationCoordinateSpace = "customDock.magnification"

private struct CustomDockMagnificationFramesKey: PreferenceKey {
    static var defaultValue: [CustomDockMagnificationItemID: CustomDockMagnificationItem] = [:]

    static func reduce(
        value: inout [CustomDockMagnificationItemID: CustomDockMagnificationItem],
        nextValue: () -> [CustomDockMagnificationItemID: CustomDockMagnificationItem]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct CustomDockShelfFrameKey: PreferenceKey {
    static var defaultValue: CGRect?

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

private struct CustomDockMagnificationFrameReporter: ViewModifier {
    let id: CustomDockMagnificationItemID
    let group: CustomDockMagnificationGroup

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: CustomDockMagnificationFramesKey.self,
                    value: [id: CustomDockMagnificationItem(
                        id: id,
                        frame: geometry.frame(
                            in: .named(customDockMagnificationCoordinateSpace)
                        ),
                        group: group
                    )]
                )
            }
        }
    }
}

@MainActor
struct CustomDockView: View {
    let appModel: DockAppModel
    let runtime: CustomDockRuntime
    let layout: CustomDockLayout
    let onAddSlot: () -> Void
    let onSlotClick: (CustomDockSlot) -> Void
    let onSlotHover: (CustomDockSlot, Bool) -> Void
    let onShelfDragBegin: () -> Void
    let onResize: (Double) -> Void
    let onSettings: (DockFeature) -> Void
    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @State private var pointerLocation: CGPoint?
    @State private var magnificationItems: [
        CustomDockMagnificationItemID: CustomDockMagnificationItem
    ] = [:]
    @State private var shelfFrame: CGRect?
    @State private var draggingShelfSlotID: UUID?
    @State private var presentedStackID: UUID?

    /// The Dock and Shelf share one continuous system material. Its radius follows
    /// the actual panel thickness so each custom size keeps an uninterrupted outer
    /// rim rather than a fixed, card-like corner.
    private var chromeCornerRadius: CGFloat {
        min(layout.frame.width, layout.frame.height) * 0.30
    }

    private var resolvedReduceMotion: Bool {
        accessibilityOverrides.reduceMotion ?? reduceMotion
    }

    private var magnificationResult: CustomDockMagnificationResult {
        CustomDockMagnificationEngine.resolve(
            pointer: pointerLocation,
            items: Array(magnificationItems.values),
            shelfFrame: shelfFrame,
            panelBounds: CGRect(origin: .zero, size: layout.frame.size),
            iconSize: layout.iconSize,
            edge: layout.configuration.edge,
            enabled: appModel.preferences.customDockConfiguration.magnificationEnabled,
            reduceMotion: resolvedReduceMotion
        )
    }

    private var magnificationAnchor: UnitPoint {
        switch layout.configuration.edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var magnificationAnimation: Animation? {
        resolvedReduceMotion
            ? nil
            : .interactiveSpring(
                response: 0.16,
                dampingFraction: 0.88,
                blendDuration: 0.04
            )
    }

    var body: some View {
        Group {
            if layout.vertical { VStack(spacing: layout.itemGap) { contents } }
            else { HStack(spacing: layout.itemGap) { contents } }
        }
        .padding(6)
        // The frame must precede the chrome. The material, its mask, and the
        // outer rim then share the exact panel bounds at every Dock size.
        .frame(width: layout.frame.width, height: layout.frame.height)
        .background {
            CustomDockChrome(cornerRadius: chromeCornerRadius)
        }
        .coordinateSpace(name: customDockMagnificationCoordinateSpace)
        .onPreferenceChange(CustomDockMagnificationFramesKey.self) {
            magnificationItems = $0
        }
        .onPreferenceChange(CustomDockShelfFrameKey.self) { shelfFrame = $0 }
        .onChange(of: appModel.preferences.customDockConfiguration.magnificationEnabled) {
            _, enabled in
            if !enabled { pointerLocation = nil }
        }
        .onChange(of: resolvedReduceMotion) {
            _, isReduced in
            if isReduced { pointerLocation = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("DockMagic Shelf Dock")
        .accessibilityIdentifier("customDock.root")
#if DEBUG
        .accessibilityValue(debugMagnificationValue)
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.environment["DockMagicUITesting"] == "1" {
                Text(debugMagnificationValue)
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Magnification state")
                    .accessibilityValue(debugMagnificationValue)
                    .accessibilityIdentifier(debugMagnificationIdentifier)
                    .id(debugMagnificationValue)
            }
        }
#endif
    }

    @ViewBuilder private var contents: some View {
        systemButton("Finder", path: "/System/Library/CoreServices/Finder.app")
        systemButton(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 ? "Apps" : "Launchpad",
                     path: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
                        ? "/System/Applications/Apps.app" : "/System/Applications/Launchpad.app")
        ForEach(layout.pinned) { appButton($0, pinned: true) }
        ForEach(layout.running) { appButton($0, pinned: false) }
        ForEach(layout.recent) { appButton($0, pinned: false) }
        shelfGroup
        if layout.overflowCount > 0 {
            overflowButton
        }
        ForEach(layout.stacks) { stackButton($0) }
        ForEach(layout.windows) { windowButton($0) }
        resizeDivider
        trashButton
    }

    private var overflowButton: some View {
        let id = CustomDockMagnificationItemID.overflow
        return Menu {
            ForEach(Array(appModel.preferences.customDockConfiguration.pinnedApps.dropFirst(layout.pinned.count))) { app in
                Button(app.title) { NSWorkspace.shared.open(app.url) }
            }
            ForEach(runtime.runningApps.filter {
                !layout.pinned.contains($0) && !layout.running.contains($0)
                    && $0.id != "com.apple.finder"
            }) { app in
                Button(app.title) { NSWorkspace.shared.open(app.url) }
            }
            ForEach(appModel.preferences.customDockConfiguration.recentApps.filter {
                !layout.recent.contains($0) && !layout.pinned.contains($0)
                    && !layout.running.contains($0)
            }) { app in
                Button(app.title) { NSWorkspace.shared.open(app.url) }
            }
            ForEach(Array(appModel.preferences.customDockConfiguration.slots.dropFirst(layout.slots.count))) { slot in
                Button(slot.feature.title) { onSlotClick(slot) }
            }
            ForEach(Array(appModel.preferences.customDockConfiguration.stacks.dropFirst(layout.stacks.count))) { stack in
                Button(stack.title) { NSWorkspace.shared.open(stack.url) }
            }
            ForEach(Array(runtime.minimizedWindows.dropFirst(layout.windows.count))) { window in
                Button(window.title) { runtime.restore(window) }
            }
        } label: {
            Color.clear
                .frame(width: layout.iconSize, height: layout.iconSize)
                .background {
                    magnifiedVisual(id) {
                        DSIcon(.more, size: layout.iconSize * 0.45)
                            .frame(width: layout.iconSize, height: layout.iconSize)
                    }
                }
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("More Dock items")
        .modifier(CustomDockMagnificationFrameReporter(
            id: id, group: .afterShelf
        ))
        .onContinuousHover { updatePointer($0, for: id) }
        .zIndex(magnificationResult.transform(for: id).zIndex)
        .accessibilityLabel("More Dock items")
        .accessibilityIdentifier("customDock.overflow")
    }

    private func systemButton(_ title: String, path: String) -> some View {
        let id = CustomDockMagnificationItemID.system(title.lowercased())
        return Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: {
            Color.clear
                .frame(width: layout.iconSize, height: layout.iconSize)
                .background {
                    magnifiedVisual(id) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable().interpolation(.high)
                            .frame(width: layout.iconSize, height: layout.iconSize)
                    }
                }
                .overlay {
                    if title == "Finder" {
                        Circle().fill(theme.textPrimary).frame(width: 4, height: 4)
                            .offset(x: layout.vertical ? layout.iconSize / 2 + 2 : 0,
                                    y: layout.vertical ? 0 : layout.iconSize / 2 + 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(title)
        .modifier(CustomDockMagnificationFrameReporter(
            id: id, group: .beforeShelf
        ))
        .onContinuousHover { updatePointer($0, for: id) }
        .zIndex(magnificationResult.transform(for: id).zIndex)
        .accessibilityLabel(title)
        .accessibilityIdentifier("customDock.system.\(title.lowercased())")
    }

    private func appButton(_ app: CustomDockApplication, pinned: Bool) -> some View {
        let id = CustomDockMagnificationItemID.application(app.id)
        return Button { NSWorkspace.shared.open(app.url) } label: {
            Color.clear
                .frame(width: layout.iconSize, height: layout.iconSize)
                .background {
                    magnifiedVisual(id) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                            .resizable().interpolation(.high)
                            .frame(width: layout.iconSize, height: layout.iconSize)
                    }
                }
                .overlay {
                    if runtime.runningApps.contains(where: { $0.id == app.id }) {
                        Circle().fill(theme.textPrimary).frame(width: 4, height: 4)
                            .offset(x: layout.vertical ? layout.iconSize / 2 + 2 : 0,
                                    y: layout.vertical ? 0 : layout.iconSize / 2 + 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(app.title)
        .modifier(CustomDockMagnificationFrameReporter(
            id: id, group: .beforeShelf
        ))
        .onContinuousHover { updatePointer($0, for: id) }
        .zIndex(magnificationResult.transform(for: id).zIndex)
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(app.url) }
            Button("Show in Finder") { NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "") }
            if pinned {
                Button("Remove from Dock") { appModel.preferences.removeCustomDockApplication(app.id) }
                Button("Move Left") { appModel.preferences.moveCustomDockApplication(app.id, by: -1) }
                Button("Move Right") { appModel.preferences.moveCustomDockApplication(app.id, by: 1) }
            } else {
                Button("Keep in Dock") { appModel.preferences.addCustomDockApplication(app) }
            }
            if let bundleID = app.bundleIdentifier,
               let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                Button("Hide") { running.hide() }
                Button("Quit") { running.terminate() }
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            let fileProviders = providers.filter {
                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }
            for provider in fileProviders {
                provider.loadFileURL { url in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(
                            [url],
                            withApplicationAt: app.url,
                            configuration: .init()
                        ) { _, error in
                            #if DEBUG
                            let environment = ProcessInfo.processInfo.environment
                            if environment["DockMagicUITesting"] == "1",
                               let resultPath = environment["DockMagicUITestAppDropResult"] {
                                let status = error.map { "error\n\($0.localizedDescription)" }
                                    ?? "success\n\(url.path)"
                                try? Data(status.utf8).write(
                                    to: URL(fileURLWithPath: resultPath),
                                    options: .atomic
                                )
                            }
                            #endif
                        }
                    }
                }
            }
            return !fileProviders.isEmpty
        }
        .onDrag { NSItemProvider(object: app.id as NSString) }
        .onDrop(of: [UTType.utf8PlainText], isTargeted: nil) { providers in
            guard pinned, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                guard let source = value as? String else { return }
                DispatchQueue.main.async {
                    let pins = appModel.preferences.customDockConfiguration.pinnedApps
                    guard let from = pins.firstIndex(where: { $0.id == source }),
                          let to = pins.firstIndex(where: { $0.id == app.id }) else { return }
                    appModel.preferences.moveCustomDockApplication(source, by: to - from)
                }
            }
            return true
        }
        .accessibilityLabel(app.title)
        .accessibilityIdentifier("customDock.app.\(app.id)")
    }

    private var shelfGroup: some View {
        Group {
            if layout.vertical {
                VStack(spacing: 4) {
                    shelfBoundaryDivider
                    VStack(spacing: 4) { shelfContents }
                    shelfBoundaryDivider
                }
            } else {
                HStack(spacing: 4) {
                    shelfBoundaryDivider
                    HStack(spacing: 4) { shelfContents }
                    shelfBoundaryDivider
                }
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: CustomDockShelfFrameKey.self,
                    value: geometry.frame(
                        in: .named(customDockMagnificationCoordinateSpace)
                    )
                )
            }
        }
        .zIndex(100)
        .onContinuousHover { phase in
            if case .active = phase {
                pointerLocation = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shelf features")
        .accessibilityIdentifier("customDock.shelf")
    }

    private var shelfBoundaryDivider: some View {
        Rectangle()
            .fill(theme.outlineStrong.opacity(0.62))
            .frame(
                width: layout.vertical ? layout.iconSize * 0.68 : 1,
                height: layout.vertical ? 1 : layout.iconSize * 0.68
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var shelfContents: some View {
        ForEach(layout.slots) { slot in
            Button { onSlotClick(slot) } label: {
                DockTileView(
                    presentation: appModel.presentation(for: slot.feature),
                    animatesChanges: false,
                    showsOuterBorder: false
                )
                    .frame(width: layout.iconSize, height: layout.iconSize)
            }
            .buttonStyle(.plain)
            .onHover { entered in
                if draggingShelfSlotID == nil {
                    onSlotHover(slot, entered)
                } else if entered {
                    onSlotHover(slot, false)
                }
            }
            .help(slot.feature.title)
            .contextMenu {
                Button("Settings…") { onSettings(slot.feature) }
                Button("Move Left") { appModel.preferences.moveCustomDockSlot(slot.id, by: -1) }
                Button("Move Right") { appModel.preferences.moveCustomDockSlot(slot.id, by: 1) }
                Button("Remove from Shelf") { appModel.preferences.removeCustomDockSlot(slot.id) }
            }
            .accessibilityLabel(slot.feature.title)
            .accessibilityIdentifier("customDock.slot.\(slot.id.uuidString)")
            .onDrag {
                draggingShelfSlotID = slot.id
                onSlotHover(slot, false)
                onShelfDragBegin()
                let draggedID = slot.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if draggingShelfSlotID == draggedID {
                        draggingShelfSlotID = nil
                    }
                }
                return NSItemProvider(object: slot.id.uuidString as NSString)
            }
            .onDrop(of: [UTType.utf8PlainText], isTargeted: nil) { providers in
                draggingShelfSlotID = nil
                onSlotHover(slot, false)
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                    guard let source = value as? String, let id = UUID(uuidString: source) else { return }
                    DispatchQueue.main.async {
                        let slots = appModel.preferences.customDockConfiguration.slots
                        guard let from = slots.firstIndex(where: { $0.id == id }),
                              let to = slots.firstIndex(where: { $0.id == slot.id }) else { return }
                        appModel.preferences.moveCustomDockSlot(id, by: to - from)
                    }
                }
                return true
            }
        }
        Button(action: onAddSlot) {
            DSIcon(.plus, size: max(12, layout.iconSize * 0.38))
                .frame(width: layout.iconSize, height: layout.iconSize)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.outlineStrong, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        }
        .buttonStyle(.plain).help("Add feature")
        .accessibilityLabel("Add Shelf feature")
        .accessibilityIdentifier("customDock.addFeature")
    }

    private func stackButton(_ stack: CustomDockStack) -> some View {
        let id = CustomDockMagnificationItemID.stack(stack.id)
        return Button { presentedStackID = stack.id } label: {
            Color.clear
                .frame(width: layout.iconSize, height: layout.iconSize)
                .background {
                    magnifiedVisual(id) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: stack.path))
                            .resizable().frame(width: layout.iconSize, height: layout.iconSize)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(stack.title)
        .modifier(CustomDockMagnificationFrameReporter(
            id: id, group: .afterShelf
        ))
        .onContinuousHover { updatePointer($0, for: id) }
        .zIndex(magnificationResult.transform(for: id).zIndex)
        .popover(isPresented: Binding(
            get: { presentedStackID == stack.id },
            set: { if !$0 { presentedStackID = nil } }
        )) { CustomDockStackContents(stack: stack) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(stack.url) }
            Button("Remove from Dock") {
                appModel.preferences.updateCustomDock { $0.stacks.removeAll { $0.id == stack.id } }
            }
        }
        .accessibilityLabel(stack.title)
        .accessibilityIdentifier("customDock.stack.\(stack.id.uuidString)")
    }

    private func windowButton(_ window: CustomDockMinimizedWindow) -> some View {
        let id = CustomDockMagnificationItemID.window(window.id)
        return Button { runtime.restore(window) } label: {
            Color.clear
                .frame(width: layout.iconSize, height: layout.iconSize)
                .background {
                    magnifiedVisual(id) {
                        Image(nsImage: window.appPath.map(NSWorkspace.shared.icon(forFile:)) ?? NSImage())
                            .resizable().frame(width: layout.iconSize, height: layout.iconSize)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(window.title)
        .modifier(CustomDockMagnificationFrameReporter(
            id: id, group: .afterShelf
        ))
        .onContinuousHover { updatePointer($0, for: id) }
        .zIndex(magnificationResult.transform(for: id).zIndex)
        .accessibilityLabel("Restore \(window.title)")
        .accessibilityIdentifier("customDock.window.\(window.id)")
    }

    private var resizeDivider: some View {
        ZStack {
            Rectangle().fill(theme.outlineStrong)
                .frame(width: layout.vertical ? layout.iconSize * 0.65 : 1,
                       height: layout.vertical ? 1 : layout.iconSize * 0.65)
                .allowsHitTesting(false)
            CustomDockResizeHandle(
                vertical: layout.vertical,
                value: appModel.preferences.customDockConfiguration
                    .preferredIconSize,
                onResize: onResize
            )
        }
            .frame(width: layout.vertical ? layout.iconSize : 36,
                   height: layout.vertical ? 36 : layout.iconSize)
            .zIndex(100)
            .accessibilityLabel("Resize Dock")
            .accessibilityIdentifier("customDock.resize")
            .accessibilityRepresentation {
                Slider(
                    value: Binding(
                        get: {
                            appModel.preferences.customDockConfiguration
                                .preferredIconSize
                        },
                        set: { value in onResize(value) }
                    ),
                    in: 16...128,
                    step: 2
                ) {
                    Text("Resize Dock")
                }
                .accessibilityIdentifier("customDock.resize")
            }
    }

    private var trashButton: some View {
        let id = CustomDockMagnificationItemID.trash
        return Button { runtime.openTrash() } label: {
            Color.clear
                .frame(width: layout.iconSize, height: layout.iconSize)
                .background {
                    magnifiedVisual(id) {
                        Group {
                            if runtime.trashState == .unknown {
                                DSIcon(.trash, size: layout.iconSize * 0.7)
                                    .frame(width: layout.iconSize, height: layout.iconSize)
                            } else {
                                Image(nsImage: trashImage)
                                    .resizable().frame(width: layout.iconSize, height: layout.iconSize)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(runtime.trashState == .unknown ? "Open Trash (status unavailable)" : "Trash")
        .modifier(CustomDockMagnificationFrameReporter(
            id: id, group: .afterShelf
        ))
        .onContinuousHover { updatePointer($0, for: id) }
        .zIndex(magnificationResult.transform(for: id).zIndex)
        .contextMenu {
            Button("Open Trash") { runtime.openTrash() }
            Button("Empty Trash in Finder…") { runtime.openTrash() }
        }
        .accessibilityLabel("Trash")
        .accessibilityIdentifier("customDock.trash")
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            let fileProviders = providers.filter {
                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }
            for provider in fileProviders {
                provider.loadFileURL { url in
                    guard let url else { return }
                    DispatchQueue.main.async { runtime.recycle([url]) }
                }
            }
            return !fileProviders.isEmpty
        }
    }

    private var trashImage: NSImage {
        switch runtime.trashState {
        case .empty: NSImage(named: NSImage.trashEmptyName) ?? NSImage()
        case .full: NSImage(named: NSImage.trashFullName) ?? NSImage()
        case .unknown: NSImage()
        }
    }

    private func updatePointer(
        _ phase: HoverPhase,
        for id: CustomDockMagnificationItemID
    ) {
        guard appModel.preferences.customDockConfiguration.magnificationEnabled,
              !resolvedReduceMotion else {
            pointerLocation = nil
            return
        }

        switch phase {
        case .active(let location):
            guard let item = magnificationItems[id] else { return }
            pointerLocation = CGPoint(
                x: item.frame.minX + location.x,
                y: item.frame.minY + location.y
            )
        case .ended:
            pointerLocation = nil
        }
    }

    private func magnifiedVisual<Content: View>(
        _ id: CustomDockMagnificationItemID,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let transform = magnificationResult.transform(for: id)
        return content()
            .scaleEffect(transform.scale, anchor: magnificationAnchor)
            .offset(x: transform.xOffset, y: transform.yOffset)
            .animation(magnificationAnimation, value: transform)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

#if DEBUG
    private var debugMagnificationIdentifier: String {
        guard let id = magnificationResult.activeItemID else {
            return "customDock.magnificationProbe.idle"
        }
        return "customDock.magnificationProbe.\(id.rawValue)"
    }

    private var debugMagnificationValue: String {
        guard ProcessInfo.processInfo.environment["DockMagicUITesting"] == "1",
              let id = magnificationResult.activeItemID else {
            return "magnification.idle"
        }
        let transform = magnificationResult.transform(for: id)
        return "magnification.\(id.rawValue).\(String(format: "%.3f", transform.scale))"
    }
#endif
}

/// AppKit keeps ownership of the mouse tracking sequence because Shelf lives in
/// a non-activating panel. SwiftUI remains the source of truth for the current
/// size and redraws the Dock after each reported value.
@MainActor
private struct CustomDockResizeHandle: NSViewRepresentable {
    let vertical: Bool
    let value: Double
    let onResize: (Double) -> Void

    func makeNSView(context: Context) -> CustomDockResizeTrackingView {
        let view = CustomDockResizeTrackingView()
        configure(view)
        return view
    }

    func updateNSView(
        _ view: CustomDockResizeTrackingView,
        context: Context
    ) {
        configure(view)
    }

    private func configure(_ view: CustomDockResizeTrackingView) {
        let orientationChanged = view.vertical != vertical
        view.vertical = vertical
        view.value = value
        view.onResize = onResize
        if orientationChanged, let window = view.window {
            window.invalidateCursorRects(for: view)
        }
    }
}

@MainActor
private final class CustomDockResizeTrackingView: NSView {
    var vertical = false
    var value = 44.0
    var onResize: (Double) -> Void = { _ in }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(
            bounds,
            cursor: vertical ? .resizeUpDown : .resizeLeftRight
        )
    }

    override func mouseDown(with event: NSEvent) {
        guard let trackingWindow = window else { return }
        let start = NSEvent.mouseLocation
        let baseline = value
        var lastReported = baseline
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]

        while let next = trackingWindow.nextEvent(
            matching: mask,
            until: .distantFuture,
            inMode: .eventTracking,
            dequeue: true
        ) {
            let pointer = NSEvent.mouseLocation
            let delta = vertical
                ? pointer.y - start.y
                : pointer.x - start.x
            let resized = min(128, max(16, baseline + Double(delta)))
            if abs(resized - lastReported) >= 0.25 {
                lastReported = resized
                onResize(resized)
            }
            if next.type == .leftMouseUp { break }
        }
    }
}

/// AppKit owns the public material; SwiftUI still owns layout and state.
/// Native Liquid Glass on macOS 26, or the public visual-effect fallback on older
/// releases, supplies one wallpaper-responsive surface without a simulated gradient.
private struct CustomDockChrome: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.designTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if reduceTransparency {
                shape.fill(theme.opaqueSurfaceChrome)
                    .overlay {
                        shape.strokeBorder(theme.outline.opacity(0.46), lineWidth: 0.5)
                    }
            } else {
                CustomDockMaterial(
                    cornerRadius: cornerRadius,
                    borderColor: NSColor(theme.outline.opacity(0.46))
                )
            }
        }
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// SwiftUI has no public Dock material. This narrow bridge uses Apple's public
/// adaptive window material and lets AppKit sample the desktop behind
/// this floating panel. It intentionally has no independent source of state.
private struct CustomDockMaterial: NSViewRepresentable {
    let cornerRadius: CGFloat
    let borderColor: NSColor

    func makeNSView(context: Context) -> CustomDockMaterialView {
        let view = CustomDockMaterialView()
        configure(view)
        return view
    }

    func updateNSView(_ view: CustomDockMaterialView, context: Context) {
        configure(view)
    }

    private func configure(_ view: CustomDockMaterialView) {
        view.configure(cornerRadius: cornerRadius, borderColor: borderColor)
    }
}

/// A single AppKit host owns the adaptive material and the one-pixel rim.
/// macOS 26 gets native Liquid Glass; older releases use a public HUD material
/// with behind-window blending. Both paths keep the same uninterrupted surface.
private final class CustomDockMaterialView: NSView {
    private let rimLayer = CAShapeLayer()
    private var rimCornerRadius: CGFloat = 0
    private var rimColor = NSColor.clear
    private let materialView: NSView

    override init(frame frameRect: NSRect) {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: frameRect)
            glass.style = .regular
            materialView = glass
        } else {
            let effect = NSVisualEffectView(frame: frameRect)
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            materialView = effect
        }
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        materialView.frame = bounds
        materialView.autoresizingMask = [.width, .height]
        addSubview(materialView)
        rimLayer.fillColor = NSColor.clear.cgColor
        rimLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer?.addSublayer(rimLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(cornerRadius: CGFloat, borderColor: NSColor) {
        rimCornerRadius = cornerRadius
        rimColor = borderColor
        layer?.cornerRadius = cornerRadius
        if #available(macOS 26.0, *), let glass = materialView as? NSGlassEffectView {
            glass.cornerRadius = cornerRadius
        } else {
            materialView.wantsLayer = true
            materialView.layer?.cornerCurve = .continuous
            materialView.layer?.cornerRadius = cornerRadius
            materialView.layer?.masksToBounds = true
        }
        refreshRim()
    }

    override func layout() {
        super.layout()
        refreshRim()
    }

    private func refreshRim() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let hairline = 1 / scale
        let insetBounds = bounds.insetBy(dx: hairline / 2, dy: hairline / 2)
        rimLayer.frame = bounds
        rimLayer.contentsScale = scale
        rimLayer.lineWidth = hairline
        rimLayer.strokeColor = rimColor.cgColor
        rimLayer.path = CGPath(
            roundedRect: insetBounds,
            cornerWidth: max(0, rimCornerRadius - hairline / 2),
            cornerHeight: max(0, rimCornerRadius - hairline / 2),
            transform: nil
        )
    }
}

private extension NSItemProvider {
    func loadFileURL(completion: @escaping (URL?) -> Void) {
        loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { item, _ in
            let url: URL?
            if let item = item as? URL {
                url = item
            } else if let item = item as? NSURL {
                url = item as URL
            } else if let item = item as? Data {
                url = URL(dataRepresentation: item, relativeTo: nil)
            } else if let item = item as? String {
                url = URL(string: item)
            } else if let item = item as? NSString {
                url = URL(string: item as String)
            } else {
                url = nil
            }
            completion(url?.isFileURL == true ? url : nil)
        }
    }
}

@MainActor
private struct CustomDockStackContents: View {
    let stack: CustomDockStack
    @State private var grid = true
    private var items: [URL] {
        (try? FileManager.default.contentsOfDirectory(at: stack.url,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stack.title).font(DSTypography.bodyEmphasis)
                Spacer()
                DSSegmentedControl(title: "Stack layout", selection: $grid,
                    options: [.init(value: true, title: "Grid"),
                              .init(value: false, title: "List")])
                    .frame(width: 140)
            }
            ScrollView {
                if grid {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(62)), count: 4)) {
                        ForEach(items, id: \.path) { item in fileButton(item, grid: true) }
                    }
                } else {
                    LazyVStack(alignment: .leading) {
                        ForEach(items, id: \.path) { item in fileButton(item, grid: false) }
                    }
                }
            }
            Button("Open in Finder") { NSWorkspace.shared.open(stack.url) }
        }
        .padding(14)
        .frame(width: 290, height: 340)
    }

    private func fileButton(_ url: URL, grid: Bool) -> some View {
        Button { NSWorkspace.shared.open(url) } label: {
            if grid {
                VStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable().frame(width: 42, height: 42)
                    Text(url.lastPathComponent).font(DSTypography.caption).lineLimit(1)
                }
            } else {
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable().frame(width: 20, height: 20)
                    Text(url.lastPathComponent).font(DSTypography.body)
                }
            }
        }
        .buttonStyle(.plain)
        .help(url.lastPathComponent)
    }
}

@MainActor
struct CustomDockFeaturePicker: View {
    let appModel: DockAppModel
    let close: () -> Void
    @State private var selection: DockFeature?

    var body: some View {
        DSSelectList(
            title: "Shelf feature", selection: $selection,
            options: DockFeature.availableCases.filter { $0 != .dockMagic }.map {
                DSSelectOption<DockFeature?>(value: $0, title: $0.title,
                                             icon: $0.shelfIcon, detail: $0.detail,
                                             accessibilityIdentifier:
                                                "customDock.picker.\($0.rawValue)")
            },
            searchable: true, width: 280, optionIdentity: nil,
            close: {
                if let selection { appModel.preferences.addCustomDockSlot(selection) }
                close()
            }
        )
        .padding(10)
        .accessibilityIdentifier("customDock.picker")
    }
}
