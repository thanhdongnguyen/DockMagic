import SwiftUI

@MainActor
struct GitHubSettingsView: View {
    let store: GitHubRepositoryStore
    let savedRepositoryURL: String
    let isActive: Bool
    let appearance: DockGitHubAppearance
    let displayStyle: Binding<DockDisplayStyle>
    let starColor: Binding<Color>
    let forkColor: Binding<Color>
    let resetAppearance: () -> Void
    let connectRepository: (String) async -> Void

    @FocusState private var repositoryFocused: Bool
    @Environment(\.designTheme) private var theme
    @State private var repositoryURL: String

    init(
        store: GitHubRepositoryStore,
        savedRepositoryURL: String,
        isActive: Bool,
        appearance: DockGitHubAppearance,
        displayStyle: Binding<DockDisplayStyle>,
        starColor: Binding<Color>,
        forkColor: Binding<Color>,
        resetAppearance: @escaping () -> Void,
        connectRepository: @escaping (String) async -> Void
    ) {
        self.store = store
        self.savedRepositoryURL = savedRepositoryURL
        self.isActive = isActive
        self.appearance = appearance
        self.displayStyle = displayStyle
        self.starColor = starColor
        self.forkColor = forkColor
        self.resetAppearance = resetAppearance
        self.connectRepository = connectRepository
        _repositoryURL = State(initialValue: savedRepositoryURL)
    }

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            dockPreviewSection
            repositorySection
            displaySection
            appearanceSection
        }
    }

    private var dockPreviewSection: some View {
        DSSettingsSection(
            title: "GitHub Dock preview",
            detail: previewDetail
        ) {
            HStack(spacing: DSSpacing.xLarge) {
                DockGitHubView(
                    history: previewHistory,
                    appearance: appearance,
                    errorDescription: store.lastErrorDescription
                )
                .frame(
                    width: DSLayout.dockPreviewSize,
                    height: DSLayout.dockPreviewSize
                )
                .accessibilityIdentifier("settings.github.dockPreview")

                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    HStack {
                        Text(previewRepositoryName)
                            .font(DSTypography.bodyEmphasis)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: DSSpacing.small)

                        previewStatusBadge
                    }

                    GitHubPreviewMetric(
                        title: "Stars",
                        value: previewHistory.last?.stars,
                        systemImage: "star.fill",
                        color: appearance.starColor.color,
                        identifier: "stars"
                    )

                    GitHubPreviewMetric(
                        title: "Forks",
                        value: previewHistory.last?.forks,
                        systemImage: "arrow.triangle.branch",
                        color: appearance.forkColor.color,
                        identifier: "forks"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var repositorySection: some View {
        DSSettingsSection(
            title: "Repository",
            detail: "Paste a GitHub repository link. DockMagic reads repository metadata only."
        ) {
            DSField(title: "Repository URL") {
            HStack(spacing: DSSpacing.standard) {
                DSIcon(systemName: "link")
                    .dsFont(size: 14, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)

                TextField(
                    "https://github.com/owner/repository",
                    text: $repositoryURL
                )
                .textFieldStyle(.plain)
                .focused($repositoryFocused)
                .font(DSTypography.body)
                .accessibilityLabel("GitHub repository URL")
                .accessibilityIdentifier("settings.github.repositoryURL")

                if !repositoryURL.isEmpty {
                    Button {
                        repositoryURL = ""
                    } label: {
                        DSIcon(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(DSContentButtonStyle())
                    .accessibilityLabel("Clear repository URL")
                    .accessibilityIdentifier("settings.github.repositoryClear")
                }
            }
            .modifier(DSInputChrome(isFocused: repositoryFocused))
            .environment(\.dsFieldInvalid, repositoryFieldRole == .danger)

            }

            Button {
                Task { await connectRepository(repositoryURL) }
            } label: {
                DSLabel("Apply Repository", systemImage: "link.badge.plus")
            }
            .buttonStyle(DSButtonStyle(emphasis: .primary))
            .disabled(repositoryReference == nil || store.isRefreshing)
            .accessibilityIdentifier("settings.github.repositoryConnect")
        }
        .onChange(of: savedRepositoryURL) { _, newValue in
            repositoryURL = newValue
        }
    }

    private var displaySection: some View {
        DSSettingsSection(
            title: "Dock display",
            detail: "Use a compact trend view or make the latest star and fork counts the focus."
        ) {
            DSSegmentedControl(title: "GitHub Dock display style", selection: displayStyle, options: [
                .init(value: .chart, title: "Line chart", icon: .chart,
                      accessibilityIdentifier: "settings.github.displayStyleOption.chart"),
                .init(value: .numeric, title: "Numbers", icon: DSIconName.fromLegacySymbol("number"),
                      accessibilityIdentifier: "settings.github.displayStyleOption.numeric")
            ])
            .accessibilityIdentifier("settings.github.displayStyle")
        }
    }

    private var appearanceSection: some View {
        DSSettingsSection(
            title: appearance.displayStyle == .chart
                ? "Line appearance"
                : "Number appearance",
            detail: "Stars and forks keep distinct colors in both display styles."
        ) {
            colorRow(
                title: "Stars",
                systemImage: "star.fill",
                color: starColor,
                hex: appearance.starColor.hex,
                identifier: "stars"
            )

            DSDivider()

            colorRow(
                title: "Forks",
                systemImage: "arrow.triangle.branch",
                color: forkColor,
                hex: appearance.forkColor.hex,
                identifier: "forks"
            )

            HStack {
                Spacer()

                Button(action: resetAppearance) {
                    DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(DSButtonStyle())
                .accessibilityIdentifier("settings.github.appearanceReset")
            }
        }
    }

    private func colorRow(
        title: String,
        systemImage: String,
        color: Binding<Color>,
        hex: String,
        identifier: String
    ) -> some View {
        HStack(spacing: DSSpacing.standard) {
            DSIcon(systemName: systemImage)
                .dsFont(size: 13, weight: .semibold)
                .foregroundStyle(color.wrappedValue)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            DSColorPalettePicker(
                selection: color,
                selectionHex: hex,
                options: ProjectTheme.rendererColorOptions,
                accessibilityLabel: "\(title) color",
                identifier: "settings.github.color.\(identifier)"
            )
        }
        .frame(minHeight: 40)
    }

    private var repositoryReference: GitHubRepositoryReference? {
        GitHubRepositoryReference(urlString: repositoryURL)
    }

    private var savedRepositoryReference: GitHubRepositoryReference? {
        GitHubRepositoryReference(urlString: savedRepositoryURL)
    }

    private var repositoryFieldRole: DSSemanticRole {
        guard !repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .neutral
        }
        return repositoryReference == nil ? .warning : .processing
    }

    private var previewRepositoryName: String {
        previewHistory.last?.repository
            ?? repositoryReference?.fullName
            ?? "owner/repository"
    }

    private var previewHistory: [GitHubRepositorySnapshot] {
        store.history.isEmpty
            ? GitHubRepositorySnapshot.designPreviewHistory
            : store.history
    }

    private var previewDetail: String {
        if store.history.isEmpty {
            return savedRepositoryReference == nil
                ? "Connect a repository to replace this sample with live star and fork data."
                : "Sample data is shown until the first GitHub request succeeds."
        }
        return isActive
            ? "Live GitHub data is applied to the Dock immediately."
            : "Latest saved GitHub data. Select GitHub as the active Dock feature to display it."
    }

    @ViewBuilder
    private var previewStatusBadge: some View {
        if store.isRefreshing {
            DSStatusBadge(
                title: "Refreshing",
                systemImage: "arrow.clockwise",
                role: .processing
            )
        } else if store.history.isEmpty {
            DSStatusBadge(
                title: "Sample",
                systemImage: "sparkles",
                role: .information
            )
        } else {
            DSStatusBadge(
                title: "Live",
                systemImage: "checkmark.circle.fill",
                role: .processing
            )
        }
    }

}

private struct GitHubPreviewMetric: View {
    let title: String
    let value: Int?
    let systemImage: String
    let color: Color
    let identifier: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.standard) {
            DSIcon(systemName: systemImage)
                .dsFont(size: 12, weight: .bold)
                .foregroundStyle(color)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text(value.map(GitHubCountFormatting.compact) ?? "—")
                .font(DSTypography.metric)
                .monospacedDigit()
                .foregroundStyle(value == nil ? theme.textTertiary : color)
        }
        .padding(DSSpacing.standard)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.row,
                style: .continuous
            ),
            kind: .inset
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value.map(String.init) ?? "Unavailable")
        .accessibilityIdentifier("settings.github.metric.\(identifier)")
    }
}
