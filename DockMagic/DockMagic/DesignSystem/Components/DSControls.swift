import SwiftUI

struct DSButtonStyle: ButtonStyle {
    var kind: DSButtonKind = .neutral

    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: DSRadius.control,
            style: .continuous
        )
        let pressed = configuration.isPressed && isEnabled

        configuration.label
            .font(DSTypography.bodyEmphasis)
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background {
                ZStack {
                    shape.fill(fill)
                    shape.strokeBorder(
                        effectivelyIncreasesContrast
                            ? theme.outlineStrong
                            : theme.outline,
                        lineWidth: effectivelyIncreasesContrast ? 1.5 : 1
                    )

                    shape
                        .inset(by: 1)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(
                                        kind == .neutral ? 0.28 : 0.22
                                    ),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .shadow(
                color: pressed ? .clear : theme.shadow.opacity(0.42),
                radius: kind == .neutral ? 2 : 4,
                x: 0,
                y: kind == .neutral ? 1 : 2
            )
            .contentShape(shape)
            .buttonBorderShape(.roundedRectangle(radius: DSRadius.control))
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .brightness(pressed ? -0.05 : 0)
            .opacity(isEnabled ? 1 : 0.42)
            .animation(
                reduceMotion ? nil : DSMotion.buttonPress,
                value: configuration.isPressed
            )
    }

    private var fill: Color {
        switch kind {
        case .neutral:
            theme.opaqueSurfaceRaised
        case .primary:
            theme.action
        case .destructive:
            theme.danger
        }
    }

    private var foreground: Color {
        switch kind {
        case .neutral:
            theme.textPrimary
        case .primary:
            theme.onAction
        case .destructive:
            theme.onDanger
        }
    }

    private var effectivelyIncreasesContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }
}

struct DSIconButtonStyle: ButtonStyle {
    var kind: DSButtonKind = .neutral
    var visualSize: CGFloat = 26
    var hitSize: CGFloat = 36

    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let radius = max(7, visualSize * 0.32)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let pressed = configuration.isPressed && isEnabled

        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: visualSize, height: visualSize)
            .background {
                ZStack {
                    shape.fill(fill)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(
                width: max(hitSize, visualSize),
                height: max(hitSize, visualSize)
            )
            .contentShape(Rectangle())
            .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.38)
            .animation(
                reduceMotion ? nil : DSMotion.buttonPress,
                value: configuration.isPressed
            )
    }

    private var fill: Color {
        switch kind {
        case .neutral:
            theme.opaqueSurfaceChrome
        case .primary:
            theme.action
        case .destructive:
            theme.danger
        }
    }

    private var foreground: Color {
        switch kind {
        case .neutral:
            theme.textPrimary
        case .primary:
            theme.onAction
        case .destructive:
            theme.onDanger
        }
    }

}

private struct DSInteractiveRowModifier: ViewModifier {
    let isActive: Bool
    let isFocused: Bool
    let isEnabled: Bool

    @State private var isHovering = false
    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: DSRadius.row,
            style: .continuous
        )
        let focused = isEnabled && isFocused

        content
            .background {
                if isEnabled && (isActive || isHovering) {
                    shape.fill(
                        isActive
                            ? theme.selectionFill
                            : theme.surfaceChrome
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .overlay {
                if focused || (isEnabled && isActive) {
                    shape.strokeBorder(
                        focused ? theme.focus : theme.selectionOutline,
                        lineWidth: effectivelyIncreasesContrast
                            ? 2
                            : (focused ? 1.5 : 1)
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .contentShape(shape)
            .onHover { isHovering = isEnabled && $0 }
            .animation(
                reduceMotion ? nil : DSMotion.rowHover,
                value: isHovering
            )
    }

    private var effectivelyIncreasesContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }
}

extension View {
    func dsInteractiveRow(
        isActive: Bool = false,
        isFocused: Bool,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            DSInteractiveRowModifier(
                isActive: isActive,
                isFocused: isFocused,
                isEnabled: isEnabled
            )
        )
    }
}
