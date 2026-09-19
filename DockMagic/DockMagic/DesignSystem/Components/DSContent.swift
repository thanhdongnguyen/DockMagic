import SwiftUI

enum DSCardDensity { case regular, small
    var padding: CGFloat { self == .regular ? 24 : 16 }
}

struct DSCard<Header: View, Content: View, Footer: View>: View {
    var density: DSCardDensity = .regular
    var role: DSSemanticRole = .neutral
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: density.padding) {
            header()
            content()
            footer()
        }
        .padding(density.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(RoundedRectangle(cornerRadius: DSRadius.card), kind: .raised, role: role)
    }
}

extension View {
    /// Shared card chrome for feature compositions that already own their content.
    func dsCard(density: DSCardDensity = .regular, role: DSSemanticRole = .neutral) -> some View {
        DSCard(density: density, role: role, header: { EmptyView() }, content: { self }, footer: { EmptyView() })
    }
}

struct DSLoadingState: View {
    var title = "Loading…"
    @Environment(\.designTheme) private var theme
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).accessibilityHidden(true)
            Text(title).font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct DSEmptyState: View {
    let title: String
    var detail: String? = nil
    var icon: DSIconName = .info
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.designTheme) private var theme
    var body: some View {
        VStack(spacing: 12) {
            DSIcon(icon, size: 24).foregroundStyle(theme.textSecondary).accessibilityHidden(true)
            Text(title).font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary)
            if let detail { Text(detail).font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(DSButtonStyle(size: .small))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity).padding(16)
    }
}

struct DSProgress: View {
    let value: Double?
    var title: String = "Progress"
    var color: Color? = nil
    var height: CGFloat = 8
    @Environment(\.designTheme) private var theme
    private var normalized: Double? { DSProgressValue.normalized(value) }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .circular).fill(theme.surfaceInset)
                if let normalized {
                    Capsule(style: .circular).fill(color ?? theme.action).frame(width: proxy.size.width * normalized)
                } else {
                    Text("—").font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore).accessibilityLabel(title)
        .accessibilityValue(normalized.map { $0.formatted(.percent) } ?? "Unavailable")
    }
}

struct DSMetricInline: View {
    let title: String
    let value: String
    var seriesColor: Color? = nil
    @Environment(\.designTheme) private var theme
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let seriesColor {
                Capsule(style: .circular).fill(seriesColor).frame(width: 13, height: 3).accessibilityHidden(true)
            }
            Text(title).font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            Text(value).font(DSTypography.metadata).foregroundStyle(theme.textPrimary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

struct DSChartLegend: View {
    let title: String
    let color: Color
    var isDashed = false
    @Environment(\.designTheme) private var theme
    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                Capsule(style: .circular).fill(color)
                if isDashed { Capsule(style: .circular).fill(color) }
            }.frame(width: 13, height: 3).accessibilityHidden(true)
            Text(title).font(DSTypography.caption).foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isDashed ? "dashed" : "solid") line")
    }
}

struct DSChartFrame<Content: View>: View {
    var title: String? = nil
    var detail: String? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.designTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary) }
            if let detail { Text(detail).font(DSTypography.caption).foregroundStyle(theme.textSecondary) }
            content()
        }
        .accessibilityElement(children: .contain)
    }
}

struct DSChartTooltip<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4, content: content)
            .font(DSTypography.metadata).padding(12)
            .dsSurface(RoundedRectangle(cornerRadius: DSRadius.extraLarge), kind: .raised, elevation: .secondary)
    }
}
