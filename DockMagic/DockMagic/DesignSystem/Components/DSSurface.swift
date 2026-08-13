import SwiftUI

private struct DSSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let kind: DSSurfaceKind
    let role: DSSemanticRole
    let elevation: DSElevation

    @Environment(\.designTheme) private var theme
    @Environment(\.dsAppearanceMode) private var appearanceMode
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    surfaceFill

                    if usesGlassMaterial && !effectivelyReducesTransparency {
                        shape.fill(theme.surface(for: kind))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay {
                ZStack {
                    shape.strokeBorder(
                        effectivelyIncreasesContrast
                            ? theme.outlineStrong
                            : theme.outline,
                        lineWidth: effectivelyIncreasesContrast ? 1.5 : 1
                    )

                    if usesGlassMaterial && !effectivelyReducesTransparency {
                        shape
                            .inset(by: 1)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(
                                            effectivelyIncreasesContrast ? 0.82 : 0.62
                                        ),
                                        theme.outline.opacity(0.14),
                                        theme.outlineStrong.opacity(0.42)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: effectivelyIncreasesContrast ? 1.5 : 1
                            )
                    }

                    if let semanticColor = theme.color(for: role) {
                        shape
                            .inset(by: 1)
                            .strokeBorder(
                                semanticColor,
                                lineWidth: effectivelyIncreasesContrast ? 1.5 : 1
                            )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .shadow(
                color: elevation == .none ? .clear : theme.shadow,
                radius: elevation.radius,
                x: 0,
                y: elevation.yOffset
            )
            .contentShape(shape)
    }

    @ViewBuilder
    private var surfaceFill: some View {
        if effectivelyReducesTransparency || !usesGlassMaterial {
            shape.fill(theme.opaqueSurface(for: kind))
        } else {
            nativeOrFallbackGlass
        }
    }

    @ViewBuilder
    private var nativeOrFallbackGlass: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            shape
                .fill(Color.clear)
                .glassEffect(.regular, in: shape)
        } else {
            shape.fill(kind.material)
        }
#else
        shape.fill(kind.material)
#endif
    }

    private var usesGlassMaterial: Bool {
        appearanceMode.usesGlassMaterials && kind.isGlassEligible
    }

    private var effectivelyReducesTransparency: Bool {
        accessibilityOverrides.reduceTransparency ?? reduceTransparency
    }

    private var effectivelyIncreasesContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }
}

extension View {
    func dsSurface<S: InsettableShape>(
        _ shape: S,
        kind: DSSurfaceKind = .panel,
        role: DSSemanticRole = .neutral,
        elevation: DSElevation = .none
    ) -> some View {
        modifier(
            DSSurfaceModifier(
                shape: shape,
                kind: kind,
                role: role,
                elevation: elevation
            )
        )
    }
}
