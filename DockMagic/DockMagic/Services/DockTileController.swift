import AppKit

@MainActor
protocol ApplicationIconDisplaying: AnyObject {
    var applicationIconImage: NSImage! { get set }
}

extension NSApplication: ApplicationIconDisplaying {}

@MainActor
final class DockTileController {
    private let dockTile: NSDockTile
    private let application: any ApplicationIconDisplaying
    private let appearanceStore: UserDefaults
    private let iconRenderer = DockApplicationIconRenderer()

    private(set) var currentPresentation: DockTilePresentation
    private(set) var currentAppearanceMode: DSAppearanceMode

    convenience init(initialPresentation: DockTilePresentation) {
        self.init(
            dockTile: NSApplication.shared.dockTile,
            application: NSApplication.shared,
            initialPresentation: initialPresentation,
            appearanceStore: DockMagicRuntimeDefaults.current
        )
    }

    init(
        dockTile: NSDockTile,
        application: (any ApplicationIconDisplaying)? = nil,
        initialPresentation: DockTilePresentation,
        appearanceStore: UserDefaults = DockMagicRuntimeDefaults.current
    ) {
        self.dockTile = dockTile
        self.application = application ?? NSApplication.shared
        self.appearanceStore = appearanceStore
        currentPresentation = initialPresentation
        currentAppearanceMode = DSAppearanceMode.stored(in: appearanceStore)

        // Use one canonical application icon for both the Dock and Command-Tab.
        // A custom Dock content view is flattened to the Dock backing-store
        // size, while DockIconRenderingRules preserves a 1024-pixel source.
        dockTile.contentView = nil
        render()
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
        if let image = iconRenderer.render(
            presentation: currentPresentation,
            appearanceMode: currentAppearanceMode
        ) {
            application.applicationIconImage = image
        }
        dockTile.display()
    }
}
