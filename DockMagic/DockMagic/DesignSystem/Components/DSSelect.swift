import SwiftUI

struct DSSelectOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var disabled = false
    var icon: DSIconName? = nil
    var detail: String? = nil
    var accessibilityIdentifier: String? = nil
    var id: Value { value }
}

/// One presentation/focus path for plain and rich selection triggers.
struct DSSelect<Value: Hashable, Label: View>: View {
    let title: String
    @Binding var selection: Value
    let options: [DSSelectOption<Value>]
    var searchable = false
    var popupWidth: CGFloat = 260
    var optionIdentity: ((Value) -> AnyView)? = nil
    var initiallyPresented = false
    @ViewBuilder var label: () -> Label
    @State private var presented = false
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        LabeledContent {
            Button { focused = true; presented.toggle() } label: { label() }
                .buttonStyle(DSContentButtonStyle())
                .focusable(enabled, interactions: .edit)
                .focused($focused)
                .focusEffectDisabled()
                .accessibilityLabel(title)
                .accessibilityValue(options.first { $0.value == selection }?.title ?? "No selection")
                .dsPopover(isPresented: $presented) {
                    DSSelectList(title: title, selection: $selection, options: options, searchable: searchable,
                                 width: popupWidth, optionIdentity: optionIdentity,
                                 close: { presented = false })
                }
                .onKeyPress(.return) {
                    guard enabled else { return .ignored }
                    presented.toggle(); return .handled
                }
                .onMoveCommand { if enabled && ($0 == .down || $0 == .up) { presented = true } }
                .onChange(of: presented) { old, new in if old && !new { focused = true } }
        } label: {
            Text(title)
                .font(DSTypography.body)
        }
        .onAppear {
            if initiallyPresented {
                presented = true
            }
        }
    }
}

extension DSSelect where Label == DSSelectTrigger {
    init(title: String, selection: Binding<Value>, options: [DSSelectOption<Value>],
         searchable: Bool = false, size: DSControlSize = .regular, popupWidth: CGFloat = 260, placeholder: String? = nil) {
        self.title = title
        _selection = selection
        self.options = options
        self.searchable = searchable
        self.popupWidth = popupWidth
        optionIdentity = nil
        initiallyPresented = false
        label = { DSSelectTrigger(title: options.first { $0.value == selection.wrappedValue }?.title ?? placeholder ?? title, size: size) }
    }
}

struct DSSelectTrigger: View {
    let title: String
    let size: DSControlSize
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.designTheme) private var theme
    var body: some View {
        HStack(spacing: 6) {
            Text(title).lineLimit(1)
            Spacer(minLength: 8)
            DSIcon(.chevronsVertical, size: 14).foregroundStyle(theme.textSecondary).accessibilityHidden(true)
        }
        .font(size == .regular || size == .large ? DSTypography.bodyEmphasis : DSTypography.metadata)
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, size.padding)
        .frame(minHeight: size.height)
        .dsSurface(Capsule(style: .circular), kind: hovering && enabled ? .inset : .raised)
        .onHover { hovering = $0 }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}

private struct DSSelectList<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [DSSelectOption<Value>]
    let searchable: Bool
    let width: CGFloat
    let optionIdentity: ((Value) -> AnyView)?
    let close: () -> Void
    @State private var query = ""
    @FocusState private var active: Value?
    @FocusState private var searchFocused: Bool
    @Environment(\.designTheme) private var theme
    private var visible: [DSSelectOption<Value>] {
        options.filter { query.isEmpty || $0.title.localizedStandardContains(query) || ($0.detail?.localizedStandardContains(query) ?? false) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if searchable {
                TextField("Search \(title)", text: $query).textFieldStyle(DSInputStyle())
                    .focused($searchFocused)
                    .onMoveCommand { direction in if direction == .down { active = visible.first(where: { !$0.disabled })?.value } }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(visible) { option in
                            Button {
                                selection = option.value
                                close()
                            } label: {
                                HStack(spacing: 8) {
                                    if let optionIdentity {
                                        optionIdentity(option.value)
                                            .accessibilityHidden(true)
                                    } else if let icon = option.icon {
                                        DSIcon(icon, size: 18)
                                            .accessibilityHidden(true)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title).lineLimit(2)
                                        if let detail = option.detail {
                                            Text(detail).font(DSTypography.caption).foregroundStyle(theme.textSecondary).lineLimit(2)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    if option.value == selection { DSIcon(.check, size: 14).accessibilityHidden(true) }
                                }
                            }
                            .buttonStyle(DSButtonStyle(emphasis: option.value == selection ? .secondary : .ghost, size: .small))
                            .disabled(option.disabled)
                            .focusable(!option.disabled, interactions: .edit)
                            .focused($active, equals: option.value)
                            .focusEffectDisabled()
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(option.value == selection ? .isSelected : [])
                            .accessibilityIdentifier(option.accessibilityIdentifier ?? "select.\(String(describing: option.value))")
                            .id(option.value)
                        }
                        if visible.isEmpty { Text("No results").foregroundStyle(theme.textSecondary).padding(12) }
                    }
                }
                .frame(height: min(360, CGFloat(max(1, visible.count)) * (options.contains { $0.detail != nil } ? 58 : 38)))
                .onChange(of: active) { _, value in if let value { proxy.scrollTo(value) } }
                .onAppear { proxy.scrollTo(selection) }
            }
        }
        .padding(6).frame(width: width)
        .font(DSTypography.body).background(theme.surfaceRaised)
        .onMoveCommand(perform: move)
        .onAppear {
            if searchable { searchFocused = true }
            else { active = options.first { $0.value == selection && !$0.disabled }?.value ?? options.first { !$0.disabled }?.value }
        }
        .onKeyPress(.return) {
            guard !searchFocused, let active, visible.contains(where: { $0.value == active && !$0.disabled }) else { return .ignored }
            selection = active
            close()
            return .handled
        }
        .onExitCommand(perform: close)
    }

    private func move(_ direction: MoveCommandDirection) {
        guard direction == .up || direction == .down else { return }
        active = DSSelectionNavigation.next(from: active, options: visible, forward: direction == .down)
    }
}

struct DSRadioGroup<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [DSSelectOption<Value>]
    @Environment(\.designTheme) private var theme
    @FocusState private var focused: Value?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(DSTypography.bodyEmphasis)
            ForEach(options) { option in
                Button { selection = option.value } label: {
                    HStack(spacing: 8) {
                        Circle().strokeBorder(theme.outlineStrong, lineWidth: 1)
                            .overlay { if selection == option.value { Circle().fill(theme.action).padding(4) } }
                            .frame(width: 16, height: 16)
                        Text(option.title)
                    }
                }
                .buttonStyle(DSButtonStyle(emphasis: .ghost, size: .small))
                .disabled(option.disabled)
                .focused($focused, equals: option.value)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
        .onMoveCommand { direction in
            let available = options.filter { !$0.disabled }
            guard !available.isEmpty, [.up, .down, .left, .right].contains(direction) else { return }
            let index = available.firstIndex { $0.value == (focused ?? selection) } ?? 0
            let step = direction == .up || direction == .left ? -1 : 1
            let next = available[min(max(index + step, 0), available.count - 1)].value
            selection = next
            focused = next
        }
        .accessibilityRepresentation {
            Picker(title, selection: $selection) {
                ForEach(options) { option in Text(option.title).tag(option.value).disabled(option.disabled) }
            }.pickerStyle(.radioGroup)
        }
    }
}
