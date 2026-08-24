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

struct DSColorSwatchOption: Identifiable {
    let id: String
    let title: String
    let color: Color
    let hex: String
}

/// A compact, direct-selection color control for renderer preferences.
///
/// Unlike `ColorPicker`, every available value remains visible in context and
/// selecting a swatch never presents a separate system panel. The selected
/// color is reinforced with a focus-colored ring and checkmark so state is not
/// communicated by color alone.
struct DSColorPalettePicker: View {
    let selection: Binding<Color>
    let selectionHex: String
    let options: [DSColorSwatchOption]
    let accessibilityLabel: String
    let identifier: String

    @FocusState private var focusedOptionID: String?
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.small) {
            ForEach(displayedOptions) { option in
                swatchButton(option)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(accessibilityLabel), selected \(selectionHex)"
        )
        .accessibilityValue(selectionHex)
        .accessibilityIdentifier(identifier)
    }

    private var displayedOptions: [DSColorSwatchOption] {
        guard !options.contains(where: isSelected) else {
            return options
        }

        return [
            DSColorSwatchOption(
                id: "current",
                title: "Current custom color",
                color: selection.wrappedValue,
                hex: selectionHex
            )
        ] + options
    }

    private func swatchButton(_ option: DSColorSwatchOption) -> some View {
        let selected = isSelected(option)
        let focused = focusedOptionID == option.id

        return Button {
            selection.wrappedValue = option.color
            focusedOptionID = option.id
        } label: {
            ZStack {
                if selected {
                    Circle()
                        .strokeBorder(
                            theme.opaqueSurfaceRaised,
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)

                    Circle()
                        .strokeBorder(theme.focus, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }

                Circle()
                    .fill(option.color)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    }

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(checkmarkColor(for: option.hex))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(
            DSColorSwatchButtonStyle(
                isSelected: selected,
                isFocused: focused
            )
        )
        .focused($focusedOptionID, equals: option.id)
        .onMoveCommand { direction in
            moveFocus(from: option.id, direction: direction)
        }
        .help("\(option.title) (\(option.hex))")
        .accessibilityLabel("\(accessibilityLabel), \(option.title)")
        .accessibilityValue(option.hex)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("\(identifier).\(option.id)")
    }

    private func isSelected(_ option: DSColorSwatchOption) -> Bool {
        option.hex.caseInsensitiveCompare(selectionHex) == .orderedSame
    }

    private func moveFocus(
        from optionID: String,
        direction: MoveCommandDirection
    ) {
        let options = displayedOptions
        guard let currentIndex = options.firstIndex(where: { $0.id == optionID }) else {
            return
        }

        let offset: Int
        switch direction {
        case .left, .up:
            offset = -1
        case .right, .down:
            offset = 1
        @unknown default:
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), options.count - 1)
        focusedOptionID = options[nextIndex].id
    }

    private func checkmarkColor(for hex: String) -> Color {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalized.count == 6,
              let value = UInt64(normalized, radix: 16) else {
            return .white
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.56 ? .black : .white
    }
}

private struct DSColorSwatchButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.designTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .shadow(
                color: isSelected ? Color.black.opacity(0.18) : .clear,
                radius: isSelected ? 2 : 0,
                x: 0,
                y: 1
            )
            .overlay {
                if isFocused {
                    Circle()
                        .strokeBorder(theme.focus, lineWidth: 2)
                        .padding(1)
                        .accessibilityHidden(true)
                }
            }
            .animation(
                reduceMotion ? nil : DSMotion.buttonPress,
                value: configuration.isPressed
            )
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
