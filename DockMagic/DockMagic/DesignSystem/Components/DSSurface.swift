import SwiftUI

private struct DSSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let kind: DSSurfaceKind
    let role: DSSemanticRole
    let showsShadow: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(theme.opaqueSurface(for: kind))
                    } else {
                        if kind.usesThinMaterial {
                            shape.fill(.thinMaterial)
                        } else {
                            shape.fill(.regularMaterial)
                        }

                        shape.fill(theme.surface(for: kind))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay {
                ZStack {
                    shape.strokeBorder(
                        contrast == .increased
                            ? theme.outlineStrong
                            : theme.outline,
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )

                    if let semanticColor = theme.color(for: role) {
                        shape
                            .inset(by: 1)
                            .strokeBorder(
                                semanticColor,
                                lineWidth: contrast == .increased ? 1.5 : 1
                            )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .shadow(
                color: showsShadow ? theme.shadow : .clear,
                radius: showsShadow ? 20 : 0,
                x: 0,
                y: showsShadow ? 10 : 0
            )
            .contentShape(shape)
    }
}

extension View {
    func dsSurface<S: InsettableShape>(
        _ shape: S,
        kind: DSSurfaceKind = .panel,
        role: DSSemanticRole = .neutral,
        showsShadow: Bool = false
    ) -> some View {
        modifier(
            DSSurfaceModifier(
                shape: shape,
                kind: kind,
                role: role,
                showsShadow: showsShadow
            )
        )
    }
}
