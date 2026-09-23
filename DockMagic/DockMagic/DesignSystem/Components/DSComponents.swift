import SwiftUI

struct DSIconPlate: View {
    let icon: DSIconName
    var role: DSSemanticRole = .neutral
    var size: CGFloat = 30

    @Environment(\.designTheme) private var theme

    init(
        _ icon: DSIconName,
        role: DSSemanticRole = .neutral,
        size: CGFloat = 30
    ) {
        self.icon = icon
        self.role = role
        self.size = size
    }

    init(
        systemImage: String,
        role: DSSemanticRole = .neutral,
        size: CGFloat = 30
    ) {
        let resolved = DSIconName.fromLegacySymbol(systemImage)
        assert(resolved != nil, "Unmapped Maia icon: \(systemImage)")
        self.init(resolved ?? .help, role: role, size: size)
    }

    var body: some View {
        DSIcon(icon)
            .dsFont(size: 13, weight: .semibold)
            .foregroundStyle(theme.accentForeground(for: role))
            .frame(width: size, height: size)
            .dsSurface(
                Capsule(style: .circular),
                kind: .inset,
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
            DSIcon(systemName: systemImage)
                .accessibilityHidden(true)

            Text(title)
                .lineLimit(1)
        }
        .font(DSTypography.metadata)
        .foregroundStyle(
            role == .neutral
                ? theme.textSecondary
                : theme.accentForeground(for: role)
        )
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .dsSurface(
            Capsule(style: .circular),
            kind: .inset,
            role: role
        )
    }
}

struct DSMetricCard: View {
    let title: String
    var icon: DSIconName? = nil
    let state: DSDataState<DSMetricValue>
    var role: DSSemanticRole = .neutral
    @Environment(\.designTheme) private var theme

    var body: some View {
        DSCard(density: .small, role: role) {
            HStack(spacing: 8) {
                if let icon { DSIcon(icon).accessibilityHidden(true) }
                Text(title).font(DSTypography.bodyEmphasis)
                Spacer(minLength: 0)
            }.foregroundStyle(theme.textPrimary)
        } content: {
            if state.isLoading { DSLoadingState() }
            else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(state.value?.formatted ?? "—").font(DSTypography.metric).monospacedDigit()
                    if let unit = state.value?.unit { Text(unit).font(DSTypography.metadata) }
                }.foregroundStyle(theme.accentForeground(for: role))
                if let fraction = state.value?.fraction {
                    DSProgress(value: fraction, title: title)
                }
            }
        } footer: {
            if let detail = state.detail { Text(detail).font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue([state.value?.formatted, state.detail].compactMap { $0 }.joined(separator: ". "))
    }
}

struct DSStatusCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let role: DSSemanticRole

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.medium) {
            DSIconPlate(systemImage: systemImage, role: role)

            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
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
        .padding(DSSpacing.medium)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.row,
                style: .continuous
            ),
            kind: .inset,
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
                DSIcon(systemName: systemImage)
                    .dsFont(size: 15, weight: .medium)
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
        DSCard(role: role) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(DSTypography.panelTitle).foregroundStyle(theme.textPrimary)
                if let detail {
                    Text(detail).font(DSTypography.body).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: DSSpacing.large, content: content)
        } footer: { EmptyView() }
    }
}
