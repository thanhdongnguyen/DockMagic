import SwiftUI

/// Feature-owned values/actions; common structure, geometry and accessibility.
struct DSConnectionForm<Fields: View, Status: View, Actions: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let fields: () -> Fields
    @ViewBuilder let status: () -> Status
    @ViewBuilder let actions: () -> Actions
    var body: some View {
        DSSettingsSection(title: title, detail: detail) {
            VStack(alignment: .leading, spacing: DSSpacing.fieldGroup) {
                fields()
                status()
                HStack(spacing: DSSpacing.small, content: actions)
            }
        }
    }
}

struct DSRendererColorRow: View {
    let title: String
    @Binding var selection: DockColor
    let identifier: String
    var body: some View {
        DSSettingsRow(title: title) {
            DSColorPalettePicker(selection: Binding(get: { selection.color }, set: { selection = DockColor($0) }),
                selectionHex: selection.hex, options: ProjectTheme.rendererColorOptions,
                accessibilityLabel: title, identifier: identifier)
        }
    }
}

/// Rich select trigger variant for an identity plus a title and description.
struct DSSelectionSummary<Identity: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let identity: () -> Identity
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.medium) {
            identity()
                .frame(width: 34, height: 34)
                .dsSurface(RoundedRectangle(cornerRadius: DSRadius.keycap), kind: .inset)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary).lineLimit(1)
                Text(detail).font(DSTypography.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: DSSpacing.small)
            DSIcon(.chevronsVertical, size: 14).foregroundStyle(theme.textSecondary).accessibilityHidden(true)
        }
        .padding(.horizontal, DSSpacing.medium)
        .frame(height: 48)
        .dsSurface(Capsule(style: .circular), kind: .raised)
    }
}
