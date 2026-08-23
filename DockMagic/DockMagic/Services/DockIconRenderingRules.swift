import AppKit
import SwiftUI

/// The single rendering contract for every dynamic DockMagic application icon.
///
/// AppKit normalizes `NSApplication.applicationIconImage` from the image's
/// logical point size. Supplying a 128-point image therefore collapses the
/// installed icon to 256 pixels on a 2x display, even when the source `NSImage`
/// contains larger representations. A 512-point canvas preserves a 1024-pixel
/// representation and gives Command-Tab enough downsampling headroom.
enum DockIconRenderingRules {
    static let canvasDimension: CGFloat = 512
    static let rasterScale: CGFloat = 2

    static let canvasSize = NSSize(
        width: canvasDimension,
        height: canvasDimension
    )

    static let rasterPixelDimension = Int(canvasDimension * rasterScale)

    static func maximumPixelDimension(of image: NSImage) -> Int {
        image.representations.reduce(0) { currentMaximum, representation in
            max(
                currentMaximum,
                representation.pixelsWide,
                representation.pixelsHigh
            )
        }
    }

    static func satisfiesSourceContract(_ image: NSImage) -> Bool {
        image.size == canvasSize
            && maximumPixelDimension(of: image) >= rasterPixelDimension
    }

    static func satisfiesInstalledContract(
        _ image: NSImage,
        backingScale: CGFloat
    ) -> Bool {
        let normalizedScale = max(1, backingScale)
        let requiredPixels = Int((canvasDimension * normalizedScale).rounded(.up))

        return image.size == canvasSize
            && maximumPixelDimension(of: image) >= requiredPixels
    }
}

@MainActor
struct DockApplicationIconRenderer {
    func render(
        presentation: DockTilePresentation,
        appearanceMode: DSAppearanceMode
    ) -> NSImage? {
        let renderer = ImageRenderer(
            content: DockMagicThemeRoot(
                content: DockTileView(
                    presentation: presentation,
                    animatesChanges: false
                )
                .environment(\.displayScale, DockIconRenderingRules.rasterScale),
                appearanceMode: appearanceMode
            )
            .frame(
                width: DockIconRenderingRules.canvasDimension,
                height: DockIconRenderingRules.canvasDimension
            )
        )
        renderer.proposedSize = ProposedViewSize(
            width: DockIconRenderingRules.canvasDimension,
            height: DockIconRenderingRules.canvasDimension
        )
        renderer.scale = DockIconRenderingRules.rasterScale
        renderer.colorMode = .nonLinear
        renderer.isOpaque = false

        guard let cgImage = renderer.cgImage else {
            return nil
        }

        let image = NSImage(
            cgImage: cgImage,
            size: DockIconRenderingRules.canvasSize
        )
        image.isTemplate = false

        guard DockIconRenderingRules.satisfiesSourceContract(image) else {
            assertionFailure("Rendered application icon violated the Command-Tab contract.")
            return nil
        }
        return image
    }
}
