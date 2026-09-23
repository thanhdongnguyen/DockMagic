import AppKit
import ApplicationServices
import Observation
import SwiftUI

struct DockShelfConfiguration: Codable, Equatable, Sendable {
    var isEnabled = false
    var orderedFeatures: [DockFeature] = []
    /// Zero hugs the Dock; one moves to the far end of the same free segment.
    var positionFraction = 0.0
    var hidesSensitiveValues = false

    mutating func normalize() {
        var seen = Set<DockFeature>()
        orderedFeatures = orderedFeatures.filter {
            $0 != .dockMagic && $0.hasHoverDashboard
                && DockFeature.availableCases.contains($0) && seen.insert($0).inserted
        }
        positionFraction = positionFraction.isFinite
            ? min(max(positionFraction, 0), 1) : 0
    }
}

enum DockShelfVisibility: Equatable {
    case off
    case permissionRequired
    case dockHidden
    case notEnoughSpace
    case visible

    var title: String {
        switch self {
        case .off: "Off"
        case .permissionRequired: "Accessibility required"
        case .dockHidden: "Following the hidden Dock"
        case .notEnoughSpace: "Not enough room beside the Dock"
        case .visible: "Visible beside the Dock"
        }
    }

    var detail: String {
        switch self {
        case .off: "Turn on Shelf to place your selected dashboards beside the Dock."
        case .permissionRequired: "Allow Accessibility to read the Dock's position. Shelf stays hidden until access is restored."
        case .dockHidden: "Shelf will reappear when the Dock appears."
        case .notEnoughSpace: "The Dock fills this edge. Reduce Dock size or remove Dock items to make room; Shelf never covers Dock icons."
        case .visible: "Drag the handle to move Shelf within the free space beside the Dock."
        }
    }
}

struct DockShelfLayout: Equatable {
    enum Style: Equatable { case full, icon }
    enum Side: Equatable { case before, after }

    let frame: CGRect
    let dockFrame: CGRect
    let screenFrame: CGRect
    let edge: DockHoverPointerEdge
    let side: Side
    let style: Style
    let visibleFeatures: [DockFeature]
    let overflowFeatures: [DockFeature]
    let showsNowPlayingControls: Bool
    let travel: CGFloat

    static let thickness: CGFloat = 56
    static let padding: CGFloat = 8
    static let gap: CGFloat = 4
    static let controlLength: CGFloat = 36
    static let iconLength: CGFloat = 40
    static let fullLength: CGFloat = 110
    static let nowPlayingExtra: CGFloat = 72

    var isVertical: Bool { edge != .bottom }

    func cellFrame(for feature: DockFeature) -> CGRect? {
        guard let index = visibleFeatures.firstIndex(of: feature) else { return nil }
        if isVertical {
            let top = frame.maxY - Self.padding - Self.controlLength - Self.gap
                - CGFloat(index) * (Self.iconLength + Self.gap)
            return CGRect(x: frame.minX + Self.padding, y: top - Self.iconLength,
                          width: Self.iconLength, height: Self.iconLength)
        }
        let previous = visibleFeatures.prefix(index).reduce(CGFloat.zero) {
            $0 + cellLength(for: $1) + Self.gap
        }
        return CGRect(
            x: frame.minX + Self.padding + Self.controlLength + Self.gap + previous,
            y: frame.midY - Self.iconLength / 2,
            width: cellLength(for: feature), height: Self.iconLength
        )
    }

    func overflowFrame() -> CGRect? {
        guard !overflowFeatures.isEmpty else { return nil }
        if isVertical {
            let top = frame.maxY - Self.padding - Self.controlLength - Self.gap
                - CGFloat(visibleFeatures.count) * (Self.iconLength + Self.gap)
            return CGRect(x: frame.minX + Self.padding, y: top - Self.controlLength,
                          width: Self.controlLength, height: Self.controlLength)
        }
        let featureLengths = visibleFeatures.reduce(CGFloat.zero) {
            $0 + cellLength(for: $1) + Self.gap
        }
        return CGRect(x: frame.minX + Self.padding + Self.controlLength + Self.gap + featureLengths,
                      y: frame.midY - Self.controlLength / 2,
                      width: Self.controlLength, height: Self.controlLength)
    }

    func cellLength(for feature: DockFeature) -> CGFloat {
        guard !isVertical, style == .full else { return Self.iconLength }
        return Self.fullLength
            + (feature == .nowPlaying && showsNowPlayingControls ? Self.nowPlayingExtra : 0)
    }

    func positionFraction(after translation: CGSize, current: Double) -> Double {
        guard travel > 0 else { return current }
        let axisDelta: CGFloat = isVertical ? -translation.height : translation.width
        let signed = side == .before ? -axisDelta : axisDelta
        return min(max(current + Double(signed / travel), 0), 1)
    }
}

enum DockShelfPlacementEngine {
    private static let screenMargin: CGFloat = 8
    private static let dockGap: CGFloat = 12

    static func place(
        dockFrame: CGRect,
        screenFrame: CGRect,
        edge: DockHoverPointerEdge,
        features: [DockFeature],
        positionFraction: Double
    ) -> DockShelfLayout? {
        guard screenFrame.intersects(dockFrame) else { return nil }
        let vertical = edge != .bottom
        let beforeLength: CGFloat
        let afterLength: CGFloat
        if vertical {
            beforeLength = dockFrame.minY - dockGap - (screenFrame.minY + screenMargin)
            afterLength = screenFrame.maxY - screenMargin - (dockFrame.maxY + dockGap)
        } else {
            beforeLength = dockFrame.minX - dockGap - (screenFrame.minX + screenMargin)
            afterLength = screenFrame.maxX - screenMargin - (dockFrame.maxX + dockGap)
        }

        let candidates: [(DockShelfLayout.Side, CGFloat)] = [
            (.before, beforeLength), (.after, afterLength)
        ]
        let options = candidates.compactMap { side, available -> DockShelfLayout? in
            guard let sizing = sizing(available: available, features: features, vertical: vertical) else {
                return nil
            }
            let length = sizing.length
            let travel = max(0, available - length)
            let fraction = CGFloat(min(max(positionFraction.isFinite ? positionFraction : 0, 0), 1))
            let axisOrigin: CGFloat
            if vertical {
                axisOrigin = side == .before
                    ? dockFrame.minY - dockGap - length - fraction * travel
                    : dockFrame.maxY + dockGap + fraction * travel
            } else {
                axisOrigin = side == .before
                    ? dockFrame.minX - dockGap - length - fraction * travel
                    : dockFrame.maxX + dockGap + fraction * travel
            }
            let verticalX = min(max(dockFrame.midX - DockShelfLayout.thickness / 2,
                                    screenFrame.minX + screenMargin),
                                screenFrame.maxX - screenMargin - DockShelfLayout.thickness)
            let frame = vertical
                ? CGRect(x: verticalX,
                         y: axisOrigin, width: DockShelfLayout.thickness, height: length)
                : CGRect(x: axisOrigin,
                         y: dockFrame.midY - DockShelfLayout.thickness / 2,
                         width: length, height: DockShelfLayout.thickness)
            guard screenFrame.insetBy(dx: screenMargin, dy: screenMargin)
                .contains(frame) else { return nil }
            return DockShelfLayout(
                frame: frame, dockFrame: dockFrame, screenFrame: screenFrame,
                edge: edge, side: side, style: sizing.style,
                visibleFeatures: sizing.visible, overflowFeatures: sizing.overflow,
                showsNowPlayingControls: sizing.nowPlayingControls,
                travel: travel
            )
        }
        return options.max { lhs, rhs in
            if lhs.visibleFeatures.count != rhs.visibleFeatures.count {
                return lhs.visibleFeatures.count < rhs.visibleFeatures.count
            }
            if lhs.style != rhs.style { return lhs.style == .icon }
            if lhs.showsNowPlayingControls != rhs.showsNowPlayingControls {
                return !lhs.showsNowPlayingControls
            }
            return lhs.side == .after && rhs.side == .before
        }
    }

    private static func sizing(
        available: CGFloat, features: [DockFeature], vertical: Bool
    ) -> (length: CGFloat, style: DockShelfLayout.Style, visible: [DockFeature],
          overflow: [DockFeature], nowPlayingControls: Bool)? {
        let padding = DockShelfLayout.padding
        let gap = DockShelfLayout.gap
        let control = DockShelfLayout.controlLength
        let base = 2 * padding + 2 * control + gap
        guard available >= base else { return nil }
        guard !features.isEmpty else {
            return (base, .icon, [], [], false)
        }

        if !vertical {
            for controls in [true, false] {
                let widths = features.reduce(CGFloat.zero) {
                    $0 + DockShelfLayout.fullLength
                        + ($1 == .nowPlaying && controls ? DockShelfLayout.nowPlayingExtra : 0)
                }
                let length = base + widths + CGFloat(features.count) * gap
                if length <= available {
                    return (length, .full, features, [], controls)
                }
            }
        }

        let iconLength = DockShelfLayout.iconLength
        let allIcons = base + CGFloat(features.count) * (iconLength + gap)
        if allIcons <= available { return (allIcons, .icon, features, [], false) }

        let overflowCost = control + gap
        let visibleCount = Int(floor((available - base - overflowCost) / (iconLength + gap)))
        guard visibleCount >= 0 else { return nil }
        let visible = Array(features.prefix(visibleCount))
        let overflow = Array(features.dropFirst(visibleCount))
        let length = base + CGFloat(visibleCount) * (iconLength + gap) + overflowCost
        return (length, .icon, visible, overflow, false)
    }
}

extension DockFeature {
    var shelfIcon: DSIconName {
        switch self {
        case .systemMetrics: .cpu
        case .weather: .cloudSun
        case .calendar: .calendar
        case .nowPlaying: .music
        case .codex: .sparkles
        case .claudeCode: .code
        case .antigravity: .activity
        case .openCode: .terminal
        case .binance: .chart
        case .grokBuild: .bolt
        default: .app
        }
    }
}

@MainActor
private struct DockShelfView: View {
    let appModel: DockAppModel
    let layout: DockShelfLayout
    let onFeature: (DockFeature, Bool) -> Void

    @Environment(\.designTheme) private var theme
    @State private var isPickerOpen = false
    @State private var isOverflowOpen = false
    @State private var dragBase: Double?

    var body: some View {
        DockMagicThemeRoot(content: shelfContent,
                           appearanceMode: DSAppearanceMode.stored(in: DockMagicRuntimeDefaults.current))
    }

    private var shelfContent: some View {
        Group {
            if layout.isVertical {
                VStack(spacing: DockShelfLayout.gap) { shelfItems }
            } else {
                HStack(spacing: DockShelfLayout.gap) { shelfItems }
            }
        }
        .padding(DockShelfLayout.padding)
        .frame(width: layout.frame.width, height: layout.frame.height)
        .background(theme.opaqueSurfaceChrome)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.outline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("DockMagic Shelf")
    }

    @ViewBuilder
    private var shelfItems: some View {
        Button {
            adjustShelfPosition(by: 0.1)
        } label: {
            DSIcon(.more, size: 17)
                .foregroundStyle(theme.textSecondary)
                .frame(width: DockShelfLayout.controlLength,
                       height: DockShelfLayout.controlLength)
                .contentShape(Rectangle())
        }
            .buttonStyle(.plain)
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if dragBase == nil { dragBase = appModel.preferences.shelfConfiguration.positionFraction }
                    guard let dragBase else { return }
                    appModel.preferences.setShelfPositionFraction(
                        layout.positionFraction(after: value.translation, current: dragBase))
                }
                .onEnded { _ in dragBase = nil })
            .onMoveCommand { direction in
                switch direction {
                case .left, .down: adjustShelfPosition(by: -0.1)
                case .right, .up: adjustShelfPosition(by: 0.1)
                default: break
                }
            }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjustShelfPosition(by: 0.1)
                case .decrement: adjustShelfPosition(by: -0.1)
                @unknown default: break
                }
            }
            .accessibilityLabel("Move Shelf within free Dock space")
            .accessibilityHint("Drag, use arrow keys, or adjust with VoiceOver")
            .accessibilityIdentifier("shelf.handle")

        ForEach(layout.visibleFeatures) { feature in
            featureCell(feature)
        }

        if !layout.overflowFeatures.isEmpty {
            Button { isOverflowOpen.toggle() } label: {
                DSIcon(.more, size: 18)
                    .frame(width: DockShelfLayout.controlLength,
                           height: DockShelfLayout.controlLength)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary)
            .accessibilityLabel("More Shelf features")
            .accessibilityIdentifier("shelf.overflow")
            .popover(isPresented: $isOverflowOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(layout.overflowFeatures) { feature in
                        Button {
                            isOverflowOpen = false
                            onFeature(feature, true)
                        } label: {
                            DSLabel(feature.title, icon: feature.shelfIcon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(DSButtonStyle(emphasis: .ghost, size: .small))
                    }
                }
                .padding(8)
                .frame(width: 220)
                .background(theme.opaqueSurfaceRaised)
            }
        }

        Button { isPickerOpen.toggle() } label: {
            DSIcon(.plus, size: 18)
                .frame(width: DockShelfLayout.controlLength,
                       height: DockShelfLayout.controlLength)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .accessibilityLabel("Add a feature to Shelf")
        .accessibilityIdentifier("shelf.add")
        .popover(isPresented: $isPickerOpen) {
            DockShelfFeaturePickerView(appModel: appModel) { isPickerOpen = false }
        }
    }

    private func featureCell(_ feature: DockFeature) -> some View {
        let width = layout.cellLength(for: feature)
        return HStack(spacing: 5) {
            Button { onFeature(feature, true) } label: {
                HStack(spacing: 5) {
                    DSIcon(feature.shelfIcon, size: 18)
                    if layout.style == .full && !layout.isVertical {
                        Text(cellTitle(for: feature)).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(feature.title) dashboard")
            .accessibilityIdentifier("shelf.feature.\(feature.rawValue)")

            if feature == .nowPlaying && layout.showsNowPlayingControls
                && layout.style == .full && !layout.isVertical {
                Button { appModel.nowPlayingStore.togglePlayback() } label: {
                    DSIcon(appModel.nowPlayingStore.snapshot?.state == .playing ? .pause : .play, size: 16)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!appModel.nowPlayingStore.canPerform(
                    appModel.nowPlayingStore.snapshot?.state == .playing ? .pause : .play))
                .accessibilityLabel("Play or pause")
                .accessibilityIdentifier("shelf.nowPlaying.playPause")
                Button { appModel.nowPlayingStore.perform(.next) } label: {
                    DSIcon(.skipForward, size: 16).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!appModel.nowPlayingStore.canPerform(.next))
                .accessibilityLabel("Next track")
                .accessibilityIdentifier("shelf.nowPlaying.next")
            }
        }
        .font(DSTypography.metadata)
        .foregroundStyle(theme.textPrimary)
        .frame(width: width, height: DockShelfLayout.iconLength)
        .background(theme.opaqueSurfaceRaised, in: RoundedRectangle(cornerRadius: 9))
    }

    private func cellTitle(for feature: DockFeature) -> String {
        guard !appModel.preferences.shelfConfiguration.hidesSensitiveValues else {
            return feature.title
        }
        switch feature {
        case .systemMetrics:
            let sample = appModel.metricsStore.current
            return sample.timestamp == .distantPast
                ? feature.title : "CPU \(Int(sample.cpuPercentage.rounded()))%"
        case .nowPlaying:
            return appModel.nowPlayingStore.snapshot?.track?.title ?? feature.title
        case .weather:
            if case let .live(snapshot) = appModel.weatherStore.state {
                return "\(Int(snapshot.temperatureCelsius.rounded()))° · Weather"
            }
            return feature.title
        default:
            return feature.title
        }
    }

    private func adjustShelfPosition(by change: Double) {
        appModel.preferences.setShelfPositionFraction(
            appModel.preferences.shelfConfiguration.positionFraction + change)
    }
}

@MainActor
struct DockShelfFeaturePickerView: View {
    let appModel: DockAppModel
    let onSelect: () -> Void
    @State private var selection: DockFeature?

    private var available: [DockFeature] {
        DockFeature.availableCases.filter {
            $0 != .dockMagic && $0.hasHoverDashboard
                && !appModel.preferences.shelfConfiguration.orderedFeatures.contains($0)
        }
    }

    var body: some View {
        DSSelectList(
            title: "Shelf feature",
            selection: $selection,
            options: available.map {
                DSSelectOption<DockFeature?>(
                    value: $0, title: $0.title, icon: $0.shelfIcon,
                    detail: $0.detail,
                    accessibilityIdentifier: "shelf.picker.\($0.rawValue)")
            },
            searchable: true,
            width: 260,
            optionIdentity: nil,
            close: {
                if let selection { appModel.preferences.addShelfFeature(selection) }
                onSelect()
            }
        )
    }
}

@MainActor
final class DockShelfCoordinator {
    var onDashboardWillShow: (() -> Void)?

    private let appModel: DockAppModel
    private let permissionController: DockHoverPermissionController
    private var timer: Timer?
    private var pointerTimer: Timer?
    private var shelfPanel: NSPanel?
    private var shelfHost: NSHostingView<AnyView>?
    private var dashboardPanel: NSPanel?
    private var dashboardHost: NSHostingView<AnyView>?
    private var layout: DockShelfLayout?
    private var openFeature: DockFeature?
    private var pendingShow: Task<Void, Never>?
    private var outsideSince: Date?
    private var pointedFeature: DockFeature?
    private var suppressedHoverFeature: DockFeature?
    private var globalClick: Any?
    private var localEvents: Any?

    init(appModel: DockAppModel, permissionController: DockHoverPermissionController) {
        self.appModel = appModel
        self.permissionController = permissionController
    }

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pointerTimer?.invalidate()
        pointerTimer = nil
        hideShelf(status: .off)
    }

    func dismissDashboard() { hideDashboard() }

    private func sample() {
        let configuration = appModel.preferences.shelfConfiguration
        guard configuration.isEnabled else { hideShelf(status: .off); return }
        permissionController.synchronize(isEnabled: true)
        guard permissionController.state == .authorized else {
            hideShelf(status: .permissionRequired)
            return
        }

        guard let dock = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock").first else {
            hideShelf(status: .dockHidden)
            return
        }
        let application = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard let list = findDockList(application, depth: 0),
              let listFrame = frame(of: list) else {
            hideShelf(status: .dockHidden)
            return
        }
        // The AX list can lag magnified icons. Reserve their complete bounds
        // before deciding whether a free segment can hold Shelf.
        let children = (attribute(kAXChildrenAttribute as CFString, from: list) as? [AXUIElement]) ?? []
        let quartzFrame = children.reduce(listFrame) { bounds, child in
            guard let childFrame = frame(of: child) else { return bounds }
            return bounds.union(childFrame)
        }
        guard let converted = DockHoverScreenGeometry.convert(quartzFrame: quartzFrame) else {
            hideShelf(status: .dockHidden)
            return
        }
        let edge = DockHoverScreenGeometry.pointerEdge(for: converted.frame,
                                                      in: converted.screen.frame)
        guard let layout = DockShelfPlacementEngine.place(
            dockFrame: converted.frame, screenFrame: converted.screen.frame,
            edge: edge, features: configuration.orderedFeatures,
            positionFraction: configuration.positionFraction) else {
            hideShelf(status: .notEnoughSpace)
            return
        }
        appModel.shelfVisibility = .visible
        appModel.setShelfVisibleFeatures(Set(configuration.orderedFeatures))
        if self.layout != layout || shelfPanel?.isVisible != true {
            self.layout = layout
            showShelf(layout)
            if let openFeature { positionDashboard(for: openFeature, layout: layout) }
        }
        trackPointer()
    }

    private func showShelf(_ layout: DockShelfLayout) {
        let root = AnyView(DockShelfView(appModel: appModel, layout: layout,
            onFeature: { [weak self] feature, clicked in self?.select(feature, clicked: clicked) }))
        let panel = shelfPanel ?? makePanel(identifier: "dockmagic.shelf")
        if shelfHost == nil {
            let host = NSHostingView(rootView: root)
            panel.contentView = host
            shelfHost = host
        } else { shelfHost?.rootView = root }
        panel.setFrame(layout.frame, display: true)
        panel.orderFrontRegardless()
        shelfPanel = panel
        if pointerTimer == nil {
            pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.trackPointer() }
            }
        }
    }

    private func select(_ feature: DockFeature, clicked: Bool) {
        pendingShow?.cancel()
        guard feature.hasHoverDashboard else { return }
        if clicked && openFeature == feature {
            suppressedHoverFeature = feature
            hideDashboard()
            return
        }
        if clicked { showDashboard(feature); return }
        pendingShow = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.showDashboard(feature)
        }
    }

    private func showDashboard(_ feature: DockFeature) {
        guard let layout, let iconFrame = layout.cellFrame(for: feature)
            ?? (layout.overflowFeatures.contains(feature) ? layout.overflowFrame() : nil),
              let screen = NSScreen.screens.first(where: { $0.frame == layout.screenFrame }) else { return }
        onDashboardWillShow?()
        if openFeature != feature { hideDashboard() }
        openFeature = feature
        outsideSince = nil
        let panelSize = DockHoverPanelPlacement.panelSize(for: feature)
        let root = AnyView(DockHoverDashboardRoot(
            appModel: appModel, feature: feature, pointerEdge: layout.edge,
            panelSize: panelSize,
            appearanceMode: DSAppearanceMode.stored(in: DockMagicRuntimeDefaults.current),
            onBinanceClose: { [weak self] in self?.hideDashboard() }
        ))
        let panel = dashboardPanel ?? makePanel(identifier: "dockmagic.shelf.dashboard")
        panel.level = DockHoverPanelPlacement.windowLevel
        if dashboardHost == nil {
            let host = NSHostingView(rootView: root)
            panel.contentView = host
            dashboardHost = host
        } else { dashboardHost?.rootView = root }
        panel.setFrame(DockHoverPanelPlacement.frame(
            iconFrame: dashboardAnchor(cell: iconFrame, layout: layout), pointerEdge: layout.edge,
            visibleFrame: screen.visibleFrame, screenFrame: screen.frame,
            panelSize: panelSize), display: true)
        panel.orderFrontRegardless()
        dashboardPanel = panel
        installEventMonitors()
    }

    private func positionDashboard(for feature: DockFeature, layout: DockShelfLayout) {
        guard let panel = dashboardPanel, panel.isVisible,
              let iconFrame = layout.cellFrame(for: feature)
                ?? (layout.overflowFeatures.contains(feature) ? layout.overflowFrame() : nil),
              let screen = NSScreen.screens.first(where: { $0.frame == layout.screenFrame }) else {
            hideDashboard(); return
        }
        panel.setFrame(DockHoverPanelPlacement.frame(
            iconFrame: dashboardAnchor(cell: iconFrame, layout: layout), pointerEdge: layout.edge,
            visibleFrame: screen.visibleFrame, screenFrame: screen.frame,
            panelSize: panel.frame.size), display: true)
    }

    private func dashboardAnchor(cell: CGRect, layout: DockShelfLayout) -> CGRect {
        switch layout.edge {
        case .bottom:
            CGRect(x: cell.minX, y: layout.frame.maxY,
                   width: cell.width, height: 0)
        case .left:
            CGRect(x: layout.frame.maxX, y: cell.minY,
                   width: 0, height: cell.height)
        case .right:
            CGRect(x: layout.frame.minX, y: cell.minY,
                   width: 0, height: cell.height)
        }
    }

    private func trackPointer() {
        guard let layout, shelfPanel?.isVisible == true else { return }
        let pointer = NSEvent.mouseLocation
        let current = layout.visibleFeatures.first { feature in
            guard var hoverFrame = layout.cellFrame(for: feature) else { return false }
            if feature == .nowPlaying && layout.showsNowPlayingControls {
                hoverFrame.size.width -= DockShelfLayout.nowPlayingExtra
            }
            return hoverFrame.contains(pointer)
        }
        if current != pointedFeature {
            if current == nil || current != suppressedHoverFeature {
                suppressedHoverFeature = nil
            }
            pointedFeature = current
            pendingShow?.cancel()
            if let current, current != suppressedHoverFeature,
               current != openFeature {
                select(current, clicked: false)
            }
        }
        checkDashboardPointer()
    }

    private func checkDashboardPointer() {
        guard let panel = dashboardPanel, panel.isVisible else { return }
        let pointer = NSEvent.mouseLocation
        if panel.frame.insetBy(dx: -8, dy: -8).contains(pointer)
            || (shelfPanel?.frame.insetBy(dx: -8, dy: -8).contains(pointer) == true) {
            outsideSince = nil
        } else {
            if outsideSince == nil { outsideSince = Date() }
            if let outsideSince, Date().timeIntervalSince(outsideSince) > 0.35 {
                hideDashboard()
            }
        }
    }

    private func hideDashboard() {
        pendingShow?.cancel()
        pendingShow = nil
        dashboardPanel?.childWindows?.forEach { $0.orderOut(nil) }
        dashboardPanel?.orderOut(nil)
        dashboardHost?.rootView = AnyView(EmptyView())
        openFeature = nil
        outsideSince = nil
        if let globalClick { NSEvent.removeMonitor(globalClick) }
        if let localEvents { NSEvent.removeMonitor(localEvents) }
        globalClick = nil
        localEvents = nil
    }

    private func hideShelf(status: DockShelfVisibility) {
        if appModel.shelfVisibility != status { appModel.shelfVisibility = status }
        if !appModel.shelfVisibleFeatures.isEmpty { appModel.setShelfVisibleFeatures([]) }
        layout = nil
        pointerTimer?.invalidate()
        pointerTimer = nil
        pointedFeature = nil
        suppressedHoverFeature = nil
        shelfPanel?.orderOut(nil)
        hideDashboard()
    }

    private func installEventMonitors() {
        guard globalClick == nil, localEvents == nil else { return }
        globalClick = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, let layout = self.layout else { return }
                let point = NSEvent.mouseLocation
                if !layout.frame.contains(point)
                    && self.dashboardPanel?.frame.contains(point) != true {
                    self.hideDashboard()
                }
            }
        }
        localEvents = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            if event.type == .keyDown && event.keyCode == 53 {
                self?.hideDashboard()
                return nil
            }
            if event.type == .leftMouseDown, let self,
               self.layout?.frame.contains(NSEvent.mouseLocation) != true,
               self.dashboardPanel?.frame.contains(NSEvent.mouseLocation) != true {
                self.hideDashboard()
            }
            return event
        }
    }

    private func makePanel(identifier: String) -> NSPanel {
        let panel = DockShelfPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier(identifier)
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = true
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }

    private func findDockList(_ element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth <= 5 else { return nil }
        let role = attribute(kAXRoleAttribute as CFString, from: element) as? String
        let children = (attribute(kAXChildrenAttribute as CFString, from: element) as? [AXUIElement]) ?? []
        if role == (kAXListRole as String), children.contains(where: {
            (attribute(kAXSubroleAttribute as CFString, from: $0) as? String)
                == (kAXApplicationDockItemSubrole as String)
        }) { return element }
        for child in children {
            if let found = findDockList(child, depth: depth + 1) { return found }
        }
        return nil
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = attribute(kAXPositionAttribute as CFString, from: element),
              let size = attribute(kAXSizeAttribute as CFString, from: element),
              CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private func attribute(_ name: CFString, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }
}

private final class DockShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
