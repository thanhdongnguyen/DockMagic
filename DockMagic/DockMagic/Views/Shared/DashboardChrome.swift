import AppKit
import SwiftUI

enum DockHoverCardLayout {
    // Keep the rounded surface fully inside the transparent NSPanel. Explicit
    // placement prevents AppKit from clipping its top outline at the host edge.
    static let panelInset: CGFloat = 6

    static func size(
        panelSize: CGSize,
        pointerEdge: DockHoverPointerEdge
    ) -> CGSize {
        switch pointerEdge {
        case .bottom:
            CGSize(
                width: panelSize.width - panelInset * 2,
                height: panelSize.height
                    - DockHoverPanelPlacement.pointerExtent - panelInset
            )
        case .left, .right:
            CGSize(
                width: panelSize.width
                    - DockHoverPanelPlacement.pointerExtent - panelInset,
                height: panelSize.height - panelInset * 2
            )
        }
    }

    /// The panel's transparent host keeps the same size, so moving the card
    /// toward the Dock replaces the former pointer tip without reflowing any
    /// dashboard content.
    static func cardOffset(
        for dockEdge: DockHoverPointerEdge
    ) -> CGSize {
        switch dockEdge {
        case .bottom:
            CGSize(
                width: panelInset,
                height: panelInset + DockHoverPanelPlacement.pointerExtent
            )
        case .left:
            CGSize(width: 0, height: panelInset)
        case .right:
            CGSize(
                width: panelInset + DockHoverPanelPlacement.pointerExtent,
                height: panelInset
            )
        }
    }
}

/// The dashboard surface shared by the live popup and PNG export. The popup
/// owns its external inset; neither belongs in an image.
struct DockHoverDashboardCard<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(width: size.width, height: size.height)
            .dsSurface(
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous),
                kind: .raised
            )
    }
}

struct DockHoverChrome<Content: View>: View {

    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        let offset = DockHoverCardLayout.cardOffset(for: pointerEdge)
        card.offset(x: offset.width, y: offset.height)
    }

    private var card: some View {
        DockHoverDashboardCard(
            size: DockHoverCardLayout.size(
                panelSize: panelSize,
                pointerEdge: pointerEdge
            ),
            content: content
        )
    }
}
