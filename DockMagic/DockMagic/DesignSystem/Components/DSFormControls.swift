import SwiftUI

struct DSField<Content: View>: View {
    let title: String
    var helper: String? = nil
    var error: String? = nil
    @ViewBuilder let content: () -> Content
    @Namespace private var labelScope
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.field) {
            Text(title).font(DSTypography.bodyEmphasis)
                .accessibilityLabeledPair(role: .label, id: title, in: labelScope)
            content()
                .environment(\.dsFieldInvalid, error != nil)
                .accessibilityHint(error ?? helper ?? "")
                .accessibilityLabeledPair(role: .content, id: title, in: labelScope)
            if let message = error ?? helper {
                Text(message).font(DSTypography.metadata)
                    .foregroundStyle(error == nil ? theme.textSecondary : theme.dangerForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(theme.textPrimary)
        .accessibilityElement(children: .contain)
    }
}

private struct DSFieldInvalidKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var dsFieldInvalid: Bool {
        get { self[DSFieldInvalidKey.self] }
        set { self[DSFieldInvalidKey.self] = newValue }
    }
}

struct DSInputStyle: TextFieldStyle {
    var multiline = false
    func _body(configuration: TextField<_Label>) -> some View {
        configuration.textFieldStyle(.plain)
            .modifier(DSInputChrome(multiline: multiline))
    }
}

struct DSInputChrome: ViewModifier {
    var multiline = false
    var isFocused: Bool? = nil
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.dsFieldInvalid) private var invalid
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var overrides

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: multiline ? DSRadius.extraLarge : 18, style: .circular)
        content
            .font(DSTypography.body)
            .foregroundStyle(theme.textPrimary)
            .focused($focused)
            .padding(.horizontal, 12).padding(.vertical, multiline ? 12 : 8)
            .frame(minHeight: 36)
            .background(shape.fill(theme.surfaceRaised))
            .overlay {
                shape.strokeBorder(invalid ? theme.dangerForeground :
                    ((overrides.increaseContrast ?? (contrast == .increased)) ? theme.outlineStrong : theme.inputOutline), lineWidth: 1)
            }
            .overlay {
                if isFocused ?? focused { shape.stroke(invalid ? theme.dangerForeground : theme.focus, lineWidth: 3).padding(-2) }
            }
            .opacity(enabled ? 1 : 0.5)
    }
}

struct DSTextInput: View {
    let title: String
    @Binding var text: String
    var body: some View { TextField(title, text: $text).textFieldStyle(DSInputStyle()) }
}

struct DSSecureInput: View {
    let title: String
    @Binding var text: String
    var body: some View { SecureField(title, text: $text).textFieldStyle(DSInputStyle()) }
}

struct DSTextArea: View {
    let title: String
    @Binding var text: String
    var body: some View {
        TextField(title, text: $text, axis: .vertical)
            .lineLimit(3...8).textFieldStyle(DSInputStyle(multiline: true))
    }
}

struct DSSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        DSToggleBody(configuration: configuration, checkbox: false)
    }
}

struct DSCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        DSToggleBody(configuration: configuration, checkbox: true)
    }
}

private struct DSToggleBody: View {
    let configuration: ToggleStyleConfiguration
    let checkbox: Bool
    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsAccessibilityOverrides) private var overrides
    @FocusState private var focused: Bool

    var body: some View {
        Button { configuration.isOn.toggle() } label: {
            LabeledContent {
                indicator
                    .overlay {
                        if focused {
                            RoundedRectangle(cornerRadius: checkbox ? DSRadius.small : DSRadius.control)
                                .stroke(theme.focus, lineWidth: 3).padding(-3)
                        }
                    }
            } label: {
                configuration.label.font(DSTypography.body)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .foregroundStyle(theme.textPrimary)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
            .toggleStyle(.checkbox)
        }
    }

    @ViewBuilder private var indicator: some View {
        if checkbox {
            RoundedRectangle(cornerRadius: DSRadius.small)
                .fill(configuration.isOn ? theme.action : theme.surfaceRaised)
                .overlay { RoundedRectangle(cornerRadius: DSRadius.small).strokeBorder(theme.outlineStrong, lineWidth: 1) }
                .overlay { if configuration.isOn { DSIcon(.check, size: 12).foregroundStyle(theme.onAction) } }
                .frame(width: 16, height: 16)
        } else {
            Capsule(style: .circular).fill(configuration.isOn ? theme.switchActive : theme.surfaceInset)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(configuration.isOn ? theme.onSwitchActive : theme.surfaceRaised)
                        .frame(width: 16, height: 16).padding(1.2)
                }
                .overlay {
                    Capsule(style: .circular).strokeBorder(
                        configuration.isOn ? theme.switchActive : theme.outlineStrong.opacity(0.5),
                        lineWidth: 1
                    )
                }
                .frame(width: 32, height: 18.4)
                .animation((overrides.reduceMotion ?? reduceMotion) ? nil : .easeOut(duration: 0.15), value: configuration.isOn)
        }
    }
}
