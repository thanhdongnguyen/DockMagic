import AppKit
import SwiftUI

enum DockHoverCardLayout {
    // Keep the rounded surface fully inside the transparent NSPanel. Explicit
    // placement prevents AppKit from clipping any outline at the host edge.
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

    /// The panel's transparent host keeps the same size. The card occupies most
    /// of the former pointer space while retaining `panelInset` on the Dock-facing
    /// edge, so its rounded outline never lands on the NSPanel boundary.
    static func cardOffset(
        for dockEdge: DockHoverPointerEdge
    ) -> CGSize {
        switch dockEdge {
        case .bottom:
            CGSize(
                width: panelInset,
                height: DockHoverPanelPlacement.pointerExtent
            )
        case .left:
            CGSize(width: panelInset, height: panelInset)
        case .right:
            CGSize(
                width: DockHoverPanelPlacement.pointerExtent,
                height: panelInset
            )
        }
    }
}

/// The dashboard surface shared by the live popup and PNG export. The popup
/// owns its external inset; neither belongs in an image.
struct DockHoverDashboardCard<Content: View>: View {
    let size: CGSize
    var surfaceColor: Color? = nil
    var weatherSceneBackdrop: WeatherSceneBackdrop? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: DSRadius.card,
            style: .continuous
        )

        ZStack {
            if let weatherSceneBackdrop {
                weatherSceneBackdrop
                    .clipShape(shape)
            }

            content()
                .padding(12)
        }
        .frame(width: size.width, height: size.height)
        .dsSurface(
            shape,
            kind: .raised,
            fill: surfaceColor
        )
    }
}

struct DockHoverChrome<Content: View>: View {

    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    var surfaceColor: Color? = nil
    var weatherSceneBackdrop: WeatherSceneBackdrop? = nil
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
            surfaceColor: surfaceColor,
            weatherSceneBackdrop: weatherSceneBackdrop,
            content: content
        )
    }
}
