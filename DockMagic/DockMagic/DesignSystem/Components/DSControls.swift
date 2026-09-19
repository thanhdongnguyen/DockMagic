import SwiftUI

enum DSButtonEmphasis: String, CaseIterable { case primary, secondary, outline, ghost, link }
enum DSControlIntent { case normal, destructive }
enum DSControlSize: String, CaseIterable {
    case extraSmall, small, regular, large
    var height: CGFloat { switch self { case .extraSmall: 24; case .small: 32; case .regular: 36; case .large: 40 } }
    var padding: CGFloat { switch self { case .extraSmall: 8; case .small: 10; case .regular: 12; case .large: 16 } }
}

struct DSButtonStyle: ButtonStyle {
    var emphasis: DSButtonEmphasis = .outline
    var intent: DSControlIntent = .normal
    var size: DSControlSize = .regular
    var surface: DSTypography.Surface = .settings

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, emphasis: emphasis, intent: intent, size: size)
    }
}

private struct DSButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let emphasis: DSButtonEmphasis
    let intent: DSControlIntent
    let size: DSControlSize
    var iconSide: CGFloat? = nil
    @State private var hovering = false
    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsAccessibilityOverrides) private var overrides
    @Environment(\.colorSchemeContrast) private var contrast

    private var foreground: Color {
        if intent == .destructive { return emphasis == .primary ? theme.onDanger : theme.dangerForeground }
        return emphasis == .primary ? theme.onAction : theme.textPrimary
    }
    private var fill: Color {
        if emphasis == .primary { return intent == .destructive ? theme.danger : theme.action }
        if emphasis == .secondary || (hovering && enabled && emphasis != .link) { return theme.surfaceInset }
        return emphasis == .outline ? theme.surfaceRaised : .clear
    }
    var body: some View {
        let shape = Capsule(style: .circular)
        let increasesContrast = overrides.increaseContrast ?? (contrast == .increased)
        configuration.label
            .font(DSTypography.bodyEmphasis)
            .foregroundStyle(foreground)
            .padding(.horizontal, iconSide == nil ? size.padding : 0)
            .frame(minWidth: iconSide, minHeight: size.height)
            .background(shape.fill(fill))
            .overlay {
                if emphasis == .outline {
                    shape.strokeBorder(increasesContrast ? theme.outlineStrong : theme.outline, lineWidth: 1)
                }
            }
            .overlay {
                if focused && enabled { shape.stroke(theme.focus, lineWidth: 3).padding(-2) }
            }
            .offset(y: configuration.isPressed && enabled && !(overrides.reduceMotion ?? reduceMotion) ? 1 : 0)
            .opacity(enabled ? 1 : 0.5)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation((overrides.reduceMotion ?? reduceMotion) ? nil : .easeOut(duration: 0.15), value: hovering)
    }
}

struct DSIconButtonStyle: ButtonStyle {
    var emphasis: DSButtonEmphasis = .ghost
    var intent: DSControlIntent = .normal
    var visualSize: CGFloat = 32
    var hitSize: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, emphasis: emphasis, intent: intent,
                     size: .small, iconSide: max(36, hitSize, visualSize))
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
    var currentColorTitle = "Current custom color"

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
                title: currentColorTitle,
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
                    DSIcon(systemName: "checkmark")
                        .dsFont(size: 10, weight: .bold)
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
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

/// Transparent variant for data marks, calendar/media content and navigation rows.
/// The content owns its geometry/selection; this style supplies shared interaction.
struct DSContentButtonStyle: ButtonStyle {
    var showsFocusRing = true
    var dimsWhenDisabled = true
    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(
                enabled
                    ? (configuration.isPressed ? 0.72 : 1)
                    : (dimsWhenDisabled ? 0.5 : 1)
            )
            .contentShape(Rectangle())
            .overlay {
                if showsFocusRing && focused && enabled {
                    RoundedRectangle(cornerRadius: DSRadius.medium)
                        .stroke(theme.focus, lineWidth: 3).padding(-2)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
    }
}
