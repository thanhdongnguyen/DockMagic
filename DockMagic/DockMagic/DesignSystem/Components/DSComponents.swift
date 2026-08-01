import SwiftUI

struct DSIconPlate: View {
    let systemImage: String
    var role: DSSemanticRole = .neutral
    var size: CGFloat = 30

    @Environment(\.designTheme) private var theme

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.color(for: role) ?? theme.textPrimary)
            .frame(width: size, height: size)
            .dsSurface(
                RoundedRectangle(
                    cornerRadius: DSRadius.control,
                    style: .continuous
                ),
                kind: .chrome,
                role: role
            )
            .accessibilityHidden(true)
    }
}

struct DSStatusBadge: View {
    let title: String
    let systemImage: String
    var role: DSSemanticRole = .neutral

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.compact) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)

            Text(title)
                .lineLimit(1)
        }
        .font(DSTypography.metadata)
        .foregroundStyle(theme.color(for: role) ?? theme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.control,
                style: .continuous
            ),
            kind: .chrome,
            role: role
        )
    }
}

struct DSMetricCard: View {
    let title: String
    let systemImage: String
    let value: Double
    let tintRole: DSSemanticRole

    @Environment(\.designTheme) private var theme

    var body: some View {
        let normalizedValue = normalized(value)
        let tint = theme.color(for: tintRole) ?? theme.action

        VStack(alignment: .leading, spacing: DSSpacing.standard) {
            HStack(spacing: DSSpacing.compact) {
                DSIconPlate(
                    systemImage: systemImage,
                    role: tintRole,
                    size: 28
                )

                Text(title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: DSSpacing.compact)
            }

            Text(
                normalizedValue,
                format: .percent.precision(.fractionLength(0))
            )
            .font(DSTypography.metric)
            .monospacedDigit()
            .foregroundStyle(tint)

            ProgressView(value: normalizedValue)
            .progressViewStyle(.linear)
            .tint(tint)
            .accessibilityLabel(title)
            .accessibilityValue(
                normalizedValue.formatted(
                    .percent.precision(.fractionLength(0))
                )
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.row,
                style: .continuous
            ),
            kind: .raised
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(
            normalizedValue.formatted(
                .percent.precision(.fractionLength(0))
            )
        )
        .accessibilityIdentifier("metric.\(title.lowercased())")
    }

    private func normalized(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        return min(max(value, 0), 1)
    }
}

struct DSStatusCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let role: DSSemanticRole

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.standard) {
            DSIconPlate(systemImage: systemImage, role: role)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)

                Text(detail)
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.row,
                style: .continuous
            ),
            kind: .raised,
            role: role
        )
        .accessibilityElement(children: .combine)
    }
}

struct DSActionRow: View {
    let title: String
    let systemImage: String
    var detail: String? = nil
    var role: DSSemanticRole = .neutral
    var isSelected = false
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.designTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.standard) {
                DSIconPlate(
                    systemImage: systemImage,
                    role: role,
                    size: 28
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DSTypography.bodyEmphasis)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if let detail {
                        Text(detail)
                            .font(DSTypography.metadata)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: DSSpacing.compact)
            }
            .padding(.horizontal, DSSpacing.standard)
            .padding(.vertical, DSSpacing.compact)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .dsInteractiveRow(
                isActive: isSelected,
                isFocused: isFocused
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct DSSettingsLinkRow: View {
    let title: String
    let systemImage: String
    var detail: String? = nil
    var accessibilityIdentifier: String? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.designTheme) private var theme

    var body: some View {
        SettingsLink {
            HStack(spacing: DSSpacing.standard) {
                DSIconPlate(systemImage: systemImage, size: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DSTypography.bodyEmphasis)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if let detail {
                        Text(detail)
                            .font(DSTypography.metadata)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: DSSpacing.compact)
            }
            .padding(.horizontal, DSSpacing.standard)
            .padding(.vertical, DSSpacing.compact)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .dsInteractiveRow(isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct DSDivider: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.outline)
            .frame(height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct DSSettingsRow<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    var systemImage: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.standard) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)

                if let detail {
                    Text(detail)
                        .font(DSTypography.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: DSSpacing.section)
            trailing()
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
    }
}

struct DSSettingsSection<Content: View>: View {
    let title: String
    var detail: String? = nil
    var role: DSSemanticRole = .neutral
    @ViewBuilder let content: () -> Content

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.standard) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(theme.textPrimary)

                if let detail {
                    Text(detail)
                        .font(DSTypography.body)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: DSSpacing.section) {
                content()
            }
            .padding(DSSpacing.panel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface(
                RoundedRectangle(
                    cornerRadius: DSRadius.row,
                    style: .continuous
                ),
                kind: .raised,
                role: role
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
