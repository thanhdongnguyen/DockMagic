import SwiftUI

/// Bounds authored identity/media content without extracting its colors into UI.
struct DSIdentityContainer<Content: View>: View {
    let size: CGFloat
    var radius: CGFloat = DSRadius.medium
    @ViewBuilder let content: () -> Content
    var body: some View {
        content().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct DSDashboardHeader<Identity: View, Actions: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let identity: () -> Identity
    @ViewBuilder let actions: () -> Actions
    @Environment(\.designTheme) private var theme
    var body: some View {
        HStack(spacing: DSSpacing.field) {
            identity()
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(DSTypography.Dashboard.headline).foregroundStyle(theme.textPrimary)
                if let detail { Text(detail).font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
            }
            Spacer(minLength: 8)
            actions()
        }
    }
}
