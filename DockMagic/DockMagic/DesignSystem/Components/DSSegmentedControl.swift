import SwiftUI

/// Maia's inset tab list adapted to a single-choice macOS control.
/// Features own the binding; arrows skip unavailable options and never wrap.
struct DSSegmentedControl<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [DSSelectOption<Value>]
    var size: DSControlSize = .regular
    @FocusState private var focused: Value?
    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                Button { focused = option.value; selection = option.value } label: {
                    HStack(spacing: 4) {
                        if let icon = option.icon { DSIcon(icon, size: 14).accessibilityHidden(true) }
                        Text(option.title).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSSegmentStyle(selected: selection == option.value, size: size))
                .disabled(option.disabled)
                .focusable(enabled && !option.disabled, interactions: .edit)
                .focused($focused, equals: option.value)
                .focusEffectDisabled()
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
                .accessibilityIdentifier(option.accessibilityIdentifier ?? "segment.\(String(describing: option.value))")
                .help(option.title)
            }
        }
        .padding(.horizontal, 4)
        .background(Capsule(style: .circular).fill(theme.surfaceInset))
        .frame(minHeight: 36)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue(options.first(where: { $0.value == selection })?.title ?? "No selection")
        .onKeyPress(.return) {
            guard enabled, let focused, options.contains(where: { $0.value == focused && !$0.disabled }) else { return .ignored }
            selection = focused
            return .handled
        }
        .onMoveCommand { move in
            guard enabled, [.left, .right, .up, .down].contains(move) else { return }
            let forward = move == .down || (direction == .leftToRight ? move == .right : move == .left)
            if let value = DSSelectionNavigation.next(from: focused ?? selection, options: options, forward: forward) {
                selection = value
                focused = value
            }
        }
    }
}

enum DSSelectionNavigation {
    static func next<Value: Hashable>(from value: Value?, options: [DSSelectOption<Value>], forward: Bool) -> Value? {
        let enabled = options.filter { !$0.disabled }
        guard !enabled.isEmpty else { return nil }
        guard let index = enabled.firstIndex(where: { $0.value == value }) else {
            return forward ? enabled.first?.value : enabled.last?.value
        }
        return enabled[min(max(index + (forward ? 1 : -1), 0), enabled.count - 1)].value
    }
}

private struct DSSegmentStyle: ButtonStyle {
    let selected: Bool
    let size: DSControlSize
    func makeBody(configuration: Configuration) -> some View {
        DSSegmentBody(configuration: configuration, selected: selected, size: size)
    }
}

private struct DSSegmentBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    let size: DSControlSize
    @State private var hovering = false
    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var overrides

    var body: some View {
        let shape = Capsule(style: .circular)
        configuration.label
            .font(size == .regular || size == .large ? DSTypography.bodyEmphasis : DSTypography.metadata)
            .foregroundStyle(selected || hovering ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, size.padding)
            .frame(minHeight: max(24, size.height - 8))
            .background(shape.fill(selected ? theme.surfaceRaised : hovering && enabled ? theme.selectionFill : .clear))
            .overlay {
                if selected {
                    shape.strokeBorder((overrides.increaseContrast ?? (contrast == .increased)) ? theme.outlineStrong : theme.outline, lineWidth: 1)
                }
                if focused && enabled { shape.strokeBorder(theme.focus, lineWidth: 2) }
            }
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
            .padding(.vertical, max(4, (36 - max(24, size.height - 8)) / 2))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
