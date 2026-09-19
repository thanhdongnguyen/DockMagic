import SwiftUI

struct DSExportButton: View {
    let isPresented: Bool
    let identifier: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { DSIcon(.share, size: 16) }
            .buttonStyle(DSIconButtonStyle(emphasis: isPresented ? .secondary : .ghost))
            .help("Export activity card")
            .accessibilityLabel("Export activity card")
            .accessibilityHint("Opens 1200 by 1200 PNG export options")
            .accessibilityIdentifier(identifier)
    }
}

@MainActor
struct DSExportActions: View {
    let identifier: String
    let pixelSizeLabel: String
    var layoutCaption: String? = nil
    var error: String? = nil
    var pointerTrailing: CGFloat = 7
    let save: () -> Void
    let copy: () -> Void
    let share: () -> Void
    private enum Action: CaseIterable { case save, copy, share }
    @FocusState private var focused: Action?
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            DSExportMenuArrow().fill(theme.surfaceRaised)
                .frame(width: 12, height: 7).padding(.trailing, pointerTrailing)
            VStack(alignment: .leading, spacing: 2) {
                if let layoutCaption { Text(layoutCaption).font(DSTypography.caption).foregroundStyle(theme.textSecondary).padding(8) }
                row(.save, title: "Save 4× PNG", detail: pixelSizeLabel, icon: .image, action: save)
                    .accessibilityHint("Opens a save panel for the high-resolution PNG")
                row(.copy, title: "Copy image", icon: .copy, action: copy)
                row(.share, title: "Share…", icon: .share, action: share)
                if let error {
                    Text(error).font(DSTypography.metadata).foregroundStyle(theme.dangerForeground)
                        .fixedSize(horizontal: false, vertical: true).padding(8)
                        .accessibilityIdentifier("\(identifier).error")
                }
            }
            .padding(6).frame(width: 208)
            .dsSurface(RoundedRectangle(cornerRadius: DSRadius.extraLarge), kind: .raised, elevation: .secondary)
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Activity card export options")
        .accessibilityIdentifier("\(identifier).menu")
        .onAppear { focused = .save }
        .onMoveCommand { direction in
            guard direction == .up || direction == .down else { return }
            let index = Action.allCases.firstIndex(of: focused ?? .save) ?? 0
            focused = Action.allCases[min(max(index + (direction == .down ? 1 : -1), 0), 2)]
        }
    }

    private func row(_ item: Action, title: String, detail: String? = nil,
                     icon: DSIconName, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                DSIcon(icon).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let detail { Text(detail).font(DSTypography.caption).foregroundStyle(theme.textSecondary) }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(DSButtonStyle(emphasis: .ghost, size: .small))
        .focused($focused, equals: item)
        .accessibilityLabel(title).accessibilityValue(detail ?? "")
    }
}

/// This attaches the export menu to its own toolbar trigger. It is distinct
/// from the removed Dock-facing hover-dashboard callout.
private struct DSExportMenuArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
