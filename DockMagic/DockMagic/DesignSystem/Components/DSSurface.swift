import SwiftUI

private struct DSSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let kind: DSSurfaceKind
    let role: DSSemanticRole
    let elevation: DSElevation
    let fill: Color?
    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var overrides
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let increased = overrides.increaseContrast ?? (contrast == .increased)
        content
            .background(shape.fill(fill ?? theme.opaqueSurface(for: kind)))
            .overlay {
                shape.strokeBorder(
                    role == .neutral ? (increased ? theme.outlineStrong : theme.outline) : theme.accentForeground(for: role),
                    lineWidth: increased ? 1.5 : 1
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .shadow(color: elevation == .none ? .clear : theme.shadow,
                    radius: elevation.radius, x: 0, y: elevation.yOffset)
            .contentShape(shape)
    }
}

extension View {
    func dsSurface<S: InsettableShape>(
        _ shape: S, kind: DSSurfaceKind = .panel,
        role: DSSemanticRole = .neutral, elevation: DSElevation = .none,
        fill: Color? = nil
    ) -> some View {
        modifier(DSSurfaceModifier(shape: shape, kind: kind, role: role, elevation: elevation, fill: fill))
    }
}
