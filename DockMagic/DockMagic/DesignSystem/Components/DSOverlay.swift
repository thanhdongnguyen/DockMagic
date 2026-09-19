import AppKit
import SwiftUI

/// Window-scoped leases keep Dock hover hosts alive through nested popups.
enum DSOverlayActivity {
    static let began = Notification.Name("DockMagicOverlayBegan")
    static let ended = Notification.Name("DockMagicOverlayEnded")
}

private final class DSWeakWindow { weak var window: NSWindow? }

private struct DSWindowReader: NSViewRepresentable {
    let reference: DSWeakWindow
    func makeNSView(context: Context) -> Reader {
        let view = Reader()
        view.reference = reference
        return view
    }
    func updateNSView(_ view: Reader, context: Context) { view.reference = reference }
    final class Reader: NSView {
        var reference: DSWeakWindow?
        override func viewDidMoveToWindow() { reference?.window = window }
    }
}

private struct DSOverlayLease: ViewModifier {
    let presented: Bool
    @State private var reference = DSWeakWindow()
    @State private var id = UUID()
    @State private var active = false
    @State private var previousResponder: NSResponder? = nil

    func body(content: Content) -> some View {
        content.background(DSWindowReader(reference: reference).frame(width: 0, height: 0))
            .onChange(of: presented) { _, value in update(value) }
            .onAppear { update(presented) }
            .onDisappear { update(false) }
    }

    private func update(_ value: Bool) {
        guard active != value else { return }
        active = value
        if value { previousResponder = reference.window?.firstResponder }
        else if let previousResponder {
            reference.window?.makeFirstResponder(previousResponder)
            self.previousResponder = nil
        }
        NotificationCenter.default.post(name: value ? DSOverlayActivity.began : DSOverlayActivity.ended,
            object: reference.window, userInfo: ["id": id])
    }
}


private struct DSOverlayPresentation<Popup: View>: ViewModifier {
    @Binding var isPresented: Bool
    let arrowEdge: Edge
    let isDialog: Bool
    @ViewBuilder let popup: () -> Popup
    @Environment(\.dsAppearanceMode) private var appearance
    @ViewBuilder func body(content: Content) -> some View {
        if isDialog {
            content.modifier(DSOverlayLease(presented: isPresented))
                .sheet(isPresented: $isPresented) {
                    DockMagicThemeRoot(content: popup(), appearanceMode: appearance)
                }
        } else {
            content.modifier(DSOverlayLease(presented: isPresented))
                .popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                    DockMagicThemeRoot(content: popup().onExitCommand { isPresented = false }, appearanceMode: appearance)
                }
        }
    }
}

extension View {
    /// Inline dashboard overlays participate in the same window/focus lifecycle.
    func dsOverlayInteraction(isPresented: Bool) -> some View {
        modifier(DSOverlayLease(presented: isPresented))
    }

    func dsPopover<Content: View>(isPresented: Binding<Bool>, arrowEdge: Edge = .top,
                                 @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(DSOverlayPresentation(isPresented: isPresented, arrowEdge: arrowEdge, isDialog: false, popup: content))
    }

    func dsDialog<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(DSOverlayPresentation(isPresented: isPresented, arrowEdge: .top, isDialog: true, popup: content))
    }

    func dsAlert<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping () -> Actions, @ViewBuilder message: @escaping () -> Message) -> some View {
        dsDialog(isPresented: isPresented) {
            DSAlertContent(title: title, isPresented: isPresented, actions: actions, message: message)
        }
    }

    func dsAlert<Value, Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, presenting value: Value?,
        @ViewBuilder actions: @escaping (Value) -> Actions, @ViewBuilder message: @escaping (Value) -> Message) -> some View {
        dsAlert(title, isPresented: isPresented) {
            if let value { actions(value) }
        } message: {
            if let value { message(value) }
        }
    }
}

private struct DSAlertContent<Actions: View, Message: View>: View {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let message: () -> Message
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(DSTypography.headline).foregroundStyle(theme.textPrimary)
            message().font(DSTypography.body).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) { Spacer(); actions() }
                .environment(\.dsDismissPopup, { isPresented = false })
        }
        .padding(24).frame(width: 440)
        .background(theme.surfaceRaised)
        .onExitCommand { isPresented = false }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct DSPopupDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
extension EnvironmentValues {
    var dsDismissPopup: () -> Void {
        get { self[DSPopupDismissKey.self] }
        set { self[DSPopupDismissKey.self] = newValue }
    }
}

/// Dismissal belongs to the button's action, so mouse, keyboard and AXPress
/// execute the same path. A PrimitiveButtonStyle can be bypassed by AXPress.
struct DSDialogButton: View {
    let title: String
    let role: ButtonRole?
    let action: () -> Void
    @Environment(\.dsDismissPopup) private var dismissPopup

    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title; self.role = role; self.action = action
    }
    var body: some View {
        Button(title, role: role) { action(); dismissPopup() }
            .buttonStyle(DSButtonStyle(emphasis: role == .cancel ? .outline : .primary,
                                      intent: role == .destructive ? .destructive : .normal))
            .keyboardShortcut(role == .cancel ? .cancelAction : .defaultAction)
            .accessibilityLabel(title)
    }
}

struct DSMenu<Content: View, Label: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label
    @State private var presented = false
    @FocusState private var focused: Bool

    var body: some View {
        Button { presented.toggle() } label: { label() }
            .buttonStyle(DSButtonStyle(emphasis: .ghost, size: .small))
            .focused($focused)
            .dsPopover(isPresented: $presented) {
                DSMenuContent { content() }
            }
            .onChange(of: presented) { old, new in if old && !new { focused = true } }
    }
}

struct DSMenuContent<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.designTheme) private var theme
    @State private var window = DSWeakWindow()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 2, content: content)
            .environment(\.dsDismissPopup, { dismiss() })
            .font(DSTypography.body)
            .padding(6).frame(minWidth: 180)
            .background(theme.surfaceRaised)
            .background(DSWindowReader(reference: window).frame(width: 0, height: 0))
            .onMoveCommand { direction in
                if direction == .down { window.window?.selectNextKeyView(nil) }
                if direction == .up { window.window?.selectPreviousKeyView(nil) }
            }
    }
}

struct DSMenuButton<Label: View>: View {
    var role: ButtonRole?
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.dsDismissPopup) private var dismissPopup

    init(role: ButtonRole? = nil, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.role = role; self.action = action; self.label = label
    }
    var body: some View {
        Button(role: role) { action(); dismissPopup() } label: {
            label().frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DSButtonStyle(emphasis: .ghost,
            intent: role == .destructive ? .destructive : .normal, size: .small))
    }
}
extension DSMenuButton where Label == Text {
    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}
