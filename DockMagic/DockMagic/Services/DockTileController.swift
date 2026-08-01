import AppKit
import SwiftUI

@MainActor
final class DockTileController {
    private let dockTile: NSDockTile
    private let hostingView: NSHostingView<DockMagicThemeRoot<DockTileView>>

    private(set) var currentPresentation: DockTilePresentation

    convenience init(initialPresentation: DockTilePresentation) {
        self.init(
            dockTile: NSApplication.shared.dockTile,
            initialPresentation: initialPresentation
        )
    }

    init(
        dockTile: NSDockTile,
        initialPresentation: DockTilePresentation
    ) {
        self.dockTile = dockTile
        currentPresentation = initialPresentation

        let hostingView = NSHostingView(
            rootView: DockMagicThemeRoot(
                content: DockTileView(
                    presentation: initialPresentation,
                    animatesChanges: false
                )
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

    private func render() {
        hostingView.rootView = DockMagicThemeRoot(
            content: DockTileView(
                presentation: currentPresentation,
                animatesChanges: false
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: dockTile.size)
        hostingView.needsLayout = true
        hostingView.needsDisplay = true
        dockTile.display()
    }
}
