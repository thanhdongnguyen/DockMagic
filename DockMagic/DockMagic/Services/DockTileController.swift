import AppKit
import SwiftUI

@MainActor
final class DockTileController {
    private let dockTile: NSDockTile
    private let appearanceStore: UserDefaults
    private let hostingView: NSHostingView<DockMagicThemeRoot<DockTileView>>

    private(set) var currentPresentation: DockTilePresentation
    private(set) var currentAppearanceMode: DSAppearanceMode

    convenience init(initialPresentation: DockTilePresentation) {
        self.init(
            dockTile: NSApplication.shared.dockTile,
            initialPresentation: initialPresentation,
            appearanceStore: DockMagicRuntimeDefaults.current
        )
    }

    init(
        dockTile: NSDockTile,
        initialPresentation: DockTilePresentation,
        appearanceStore: UserDefaults = DockMagicRuntimeDefaults.current
    ) {
        self.dockTile = dockTile
        self.appearanceStore = appearanceStore
        currentPresentation = initialPresentation
        currentAppearanceMode = DSAppearanceMode.stored(in: appearanceStore)

        let hostingView = NSHostingView(
            rootView: DockMagicThemeRoot(
                content: DockTileView(
                    presentation: initialPresentation,
                    animatesChanges: false
                ),
                appearanceMode: currentAppearanceMode
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: dockTile.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingView = hostingView

        dockTile.contentView = hostingView
        dockTile.display()
    }

    func update(presentation: DockTilePresentation) {
        guard presentation != currentPresentation else {
            return
        }

        currentPresentation = presentation
        render()
    }

    func updateAppearance() {
        currentAppearanceMode = DSAppearanceMode.stored(in: appearanceStore)
        render()
    }

    private func render() {
        hostingView.rootView = DockMagicThemeRoot(
            content: DockTileView(
                presentation: currentPresentation,
                animatesChanges: false
            ),
            appearanceMode: currentAppearanceMode
        )
        hostingView.frame = NSRect(origin: .zero, size: dockTile.size)
        hostingView.needsLayout = true
        hostingView.needsDisplay = true
        dockTile.display()
    }
}
