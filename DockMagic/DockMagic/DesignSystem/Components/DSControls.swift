import SwiftUI

struct DSButtonStyle: ButtonStyle {
    var kind: DSButtonKind = .neutral

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: DSRadius.control,
            style: .continuous
        )
        let pressed = configuration.isPressed && isEnabled

        configuration.label
            .font(DSTypography.bodyEmphasis)
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                ZStack {
                    if kind == .neutral, !reduceTransparency {
                        shape.fill(.thinMaterial)
                    }

                    shape.fill(fill)
                    shape.strokeBorder(
                        contrast == .increased
                            ? theme.outlineStrong
                            : theme.outline,
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(shape)
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
            reduceTransparency
                ? theme.opaqueSurfaceChrome
                : theme.surfaceChrome
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
                shape.fill(fill)
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
            theme.surfaceChrome
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
                        lineWidth: contrast == .increased
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
