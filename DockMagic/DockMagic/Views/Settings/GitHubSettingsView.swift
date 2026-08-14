import SwiftUI

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
    let disconnectRepository: () -> Void

    @Environment(\.designTheme) private var theme
    @State private var repositoryURL: String
    @State private var accessToken = ""
    @State private var credentialActionError: String?

    init(
        store: GitHubRepositoryStore,
        savedRepositoryURL: String,
        isActive: Bool,
        appearance: DockGitHubAppearance,
        displayStyle: Binding<DockDisplayStyle>,
        starColor: Binding<Color>,
        forkColor: Binding<Color>,
        resetAppearance: @escaping () -> Void,
        connectRepository: @escaping (String) async -> Void,
        disconnectRepository: @escaping () -> Void
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
        self.disconnectRepository = disconnectRepository
        _repositoryURL = State(initialValue: savedRepositoryURL)
    }

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            dockPreviewSection
            repositorySection
            authenticationSection
            displaySection
            appearanceSection
            refreshStatus
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
            HStack(spacing: DSSpacing.standard) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)

                TextField(
                    "https://github.com/owner/repository",
                    text: $repositoryURL
                )
                .textFieldStyle(.plain)
                .font(DSTypography.body)
                .accessibilityLabel("GitHub repository URL")
                .accessibilityIdentifier("settings.github.repositoryURL")

                if !repositoryURL.isEmpty {
                    Button {
                        repositoryURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear repository URL")
                    .accessibilityIdentifier("settings.github.repositoryClear")
                }
            }
            .padding(.horizontal, DSSpacing.standard)
            .frame(minHeight: 38)
            .dsSurface(
                RoundedRectangle(
                    cornerRadius: DSRadius.control,
                    style: .continuous
                ),
                kind: .inset,
                role: repositoryFieldRole
            )

            repositoryStatus

            HStack(spacing: DSSpacing.standard) {
                Button {
                    Task { await connectRepository(repositoryURL) }
                } label: {
                    Label(
                        savedRepositoryReference == nil
                            ? "Connect Repository"
                            : "Apply Repository",
                        systemImage: "link.badge.plus"
                    )
                }
                .buttonStyle(DSButtonStyle(kind: .primary))
                .disabled(repositoryReference == nil || store.isRefreshing)
                .accessibilityIdentifier("settings.github.repositoryConnect")

                Button {
                    Task { await store.refresh() }
                } label: {
                    Label(
                        store.isRefreshing ? "Refreshing…" : "Refresh Now",
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(DSButtonStyle())
                .disabled(savedRepositoryReference == nil || store.isRefreshing)
                .accessibilityIdentifier("settings.github.refreshNow")

                Spacer()

                if savedRepositoryReference != nil {
                    Button("Disconnect", role: .destructive) {
                        disconnectRepository()
                        repositoryURL = ""
                    }
                    .buttonStyle(DSButtonStyle(kind: .destructive))
                    .accessibilityIdentifier("settings.github.repositoryDisconnect")
                }
            }
        }
        .onChange(of: savedRepositoryURL) { _, newValue in
            repositoryURL = newValue
        }
    }

    @ViewBuilder
    private var repositoryStatus: some View {
        if repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(spacing: DSSpacing.compact) {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)

                Text("Public repositories work without a GitHub token.")
            }
            .font(DSTypography.metadata)
            .foregroundStyle(theme.textSecondary)
            .accessibilityIdentifier("settings.github.repositoryHint")
        } else if let repositoryReference {
            DSStatusCard(
                title: repositoryReference.fullName,
                detail: repositoryReference == savedRepositoryReference
                    ? repositoryConnectionDetail
                    : "Valid link · Select Apply Repository to start fetching data.",
                systemImage: "checkmark.circle.fill",
                role: .processing
            )
            .accessibilityIdentifier("settings.github.repositoryValid")
        } else {
            DSStatusCard(
                title: "Enter a GitHub repository link",
                detail: "Use https://github.com/owner/repository or a GitHub SSH URL.",
                systemImage: "exclamationmark.triangle.fill",
                role: .warning
            )
            .accessibilityIdentifier("settings.github.repositoryInvalid")
        }
    }

    private var authenticationSection: some View {
        DSSettingsSection(
            title: "Authentication",
            detail: "Optional for public repositories. Add a fine-grained personal access token for private repositories and a higher API limit. The token stays in macOS Keychain."
        ) {
            if store.hasAccessToken {
                DSStatusCard(
                    title: "Access token saved",
                    detail: "Authenticated GitHub requests are enabled. The token is never stored in preferences or history.",
                    systemImage: "key.fill",
                    role: .processing
                )
                .accessibilityIdentifier("settings.github.tokenSaved")

                HStack {
                    Spacer()
                    Button("Remove Token", role: .destructive) {
                        do {
                            try store.removeAccessToken()
                            credentialActionError = nil
                            Task { await store.refresh() }
                        } catch {
                            credentialActionError = error.localizedDescription
                        }
                    }
                    .buttonStyle(DSButtonStyle(kind: .destructive))
                    .accessibilityIdentifier("settings.github.tokenRemove")
                }
            } else {
                HStack(spacing: DSSpacing.standard) {
                    Image(systemName: "key")
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)

                    SecureField("github_pat_… or ghp_…", text: $accessToken)
                        .textFieldStyle(.plain)
                        .font(DSTypography.body)
                        .accessibilityLabel("GitHub access token")
                        .accessibilityIdentifier("settings.github.token")
                }
                .padding(.horizontal, DSSpacing.standard)
                .frame(minHeight: 38)
                .dsSurface(
                    RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    ),
                    kind: .inset
                )

                HStack {
                    Text("Use minimum read-only Metadata access for the selected repository.")
                        .font(DSTypography.metadata)
                        .foregroundStyle(theme.textSecondary)

                    Spacer()

                    Button("Save to Keychain") {
                        do {
                            try store.saveAccessToken(accessToken)
                            accessToken = ""
                            credentialActionError = nil
                            Task { await store.refresh() }
                        } catch {
                            credentialActionError = error.localizedDescription
                        }
                    }
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .disabled(
                        accessToken.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                    .accessibilityIdentifier("settings.github.tokenSave")
                }
            }

            if let error = credentialActionError
                ?? store.credentialErrorDescription {
                DSStatusCard(
                    title: "Keychain error",
                    detail: error,
                    systemImage: "exclamationmark.triangle.fill",
                    role: .danger
                )
            }
        }
    }

    private var displaySection: some View {
        DSSettingsSection(
            title: "Dock display",
            detail: "Use a compact trend view or make the latest star and fork counts the focus."
        ) {
            Picker("GitHub Dock display style", selection: displayStyle) {
                Label("Line chart", systemImage: "chart.xyaxis.line")
                    .tag(DockDisplayStyle.chart)
                    .accessibilityIdentifier(
                        "settings.github.displayStyleOption.chart"
                    )

                Label("Numbers", systemImage: "number")
                    .tag(DockDisplayStyle.numeric)
                    .accessibilityIdentifier(
                        "settings.github.displayStyleOption.numeric"
                    )
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .accessibilityLabel("GitHub Dock display style")
            .accessibilityValue(
                appearance.displayStyle == .chart ? "Line chart" : "Numbers"
            )
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
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(DSButtonStyle())
                .accessibilityIdentifier("settings.github.appearanceReset")
            }
        }
    }

    private var refreshStatus: some View {
        DSStatusCard(
            title: refreshTitle,
            detail: refreshDetail,
            systemImage: "clock.arrow.circlepath",
            role: store.lastErrorDescription == nil
                ? (isActive ? .processing : .information)
                : .warning
        )
        .accessibilityIdentifier("settings.github.refreshCadence")
    }

    private func colorRow(
        title: String,
        systemImage: String,
        color: Binding<Color>,
        hex: String,
        identifier: String
    ) -> some View {
        HStack(spacing: DSSpacing.standard) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color.wrappedValue)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: DSSpacing.standard)

            Text(hex)
                .font(DSTypography.keycap)
                .foregroundStyle(theme.textSecondary)

            ColorPicker(title, selection: color, supportsOpacity: false)
                .labelsHidden()
                .accessibilityLabel("\(title) color")
                .accessibilityValue(hex)
                .accessibilityIdentifier(
                    "settings.github.color.\(identifier)"
                )
        }
        .frame(minHeight: 28)
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

    private var repositoryConnectionDetail: String {
        guard let latest = store.history.last else {
            return store.isRefreshing
                ? "Connecting to GitHub…"
                : "Connected · Waiting for the first update"
        }
        return "Connected · Last updated \(latest.fetchedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var refreshTitle: String {
        if store.isRefreshing {
            return "Refreshing GitHub now"
        }
        if let rateLimit = store.rateLimit {
            return "Updates every 15 minutes · \(rateLimit.remaining)/\(rateLimit.limit) requests left"
        }
        return "Updates every 15 minutes"
    }

    private var refreshDetail: String {
        if let error = store.lastErrorDescription {
            return error
        }
        if isActive, let nextRefreshAt = store.nextRefreshAt {
            return "Next automatic update \(nextRefreshAt.formatted(date: .omitted, time: .shortened))."
        }
        if isActive {
            return "GitHub metadata refreshes automatically while this is the active Dock feature."
        }
        return "Automatic updates pause until GitHub is selected as the active Dock feature. Refresh Now remains available."
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
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
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
