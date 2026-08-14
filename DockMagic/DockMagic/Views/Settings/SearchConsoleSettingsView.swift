import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct SearchConsoleSettingsView: View {
    let store: SearchConsoleStore
    let isActive: Bool

    @State private var showsManageSheet = false
    @State private var importsJSON = false
    @State private var importError: String?
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            if store.configuration.isConnected {
                connectedStrip
                livePreview
                dataSource
                preliminaryNotice
            } else {
                setupCard
            }
        }
        .fileImporter(
            isPresented: $importsJSON,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importJSON
        )
        .sheet(isPresented: $showsManageSheet) {
            SearchConsoleConnectionSheet(
                store: store,
                importJSON: { importsJSON = true },
                dismiss: { showsManageSheet = false }
            )
            .environment(\.designTheme, theme)
        }
        .alert(
            "Service account could not be connected",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
        .task {
            if store.configuration.isConnected && store.availableSites.isEmpty {
                await store.reloadSites()
            }
        }
    }

    private var connectedStrip: some View {
        HStack(spacing: DSSpacing.medium) {
            Circle()
                .fill(Color(red: 0.32, green: 0.82, blue: 0.46))
                .frame(width: 8, height: 8)
                .shadow(color: theme.processingForeground.opacity(0.45), radius: 4)

            Text(store.configuration.selectedProperty)
                .font(DSTypography.body)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .accessibilityIdentifier("settings.searchConsole.connection")

            Rectangle()
                .fill(theme.outline)
                .frame(width: 1, height: 18)
                .accessibilityHidden(true)

            Text(store.configuration.metadata?.clientEmail ?? "")
                .font(DSTypography.body)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: DSSpacing.medium)

            Button("Manage…") { showsManageSheet = true }
                .buttonStyle(DSButtonStyle())
                .accessibilityIdentifier("settings.searchConsole.manage")
        }
        .padding(.horizontal, DSSpacing.large)
        .frame(height: 45)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.panel, style: .continuous),
            kind: .chrome,
            elevation: .secondary
        )
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            Text("Live Dock preview")
                .font(DSTypography.sectionTitle)
                .foregroundStyle(theme.textPrimary)

            HStack(alignment: .center, spacing: 38) {
                DockSearchConsoleView(
                    state: store.state,
                    configuration: store.configuration
                )
                .frame(width: 176, height: 176)
                .accessibilityIdentifier("settings.searchConsole.dockPreview")

                VStack(spacing: DSSpacing.medium) {
                    controlRow(title: "Primary metric") {
                        segmented(
                            SearchConsoleMetric.allCases,
                            selection: store.configuration.primaryMetric,
                            id: "primaryMetric",
                            title: \.title,
                            set: { store.setPrimaryMetric($0) }
                        )
                    }
                    controlRow(title: "Time range") {
                        segmented(
                            SearchConsoleTimeRange.allCases,
                            selection: store.configuration.timeRange,
                            id: "timeRange",
                            title: \.title,
                            set: { store.setTimeRange($0) }
                        )
                    }
                    controlRow(title: "Display mode") {
                        segmented(
                            SearchConsoleDisplayMode.allCases,
                            selection: store.configuration.displayMode,
                            id: "displayMode",
                            title: \.title,
                            set: { store.setDisplayMode($0) }
                        )
                    }

                    HStack(spacing: DSSpacing.small) {
                        Text(refreshSummary)
                            .font(DSTypography.metadata)
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(DSIconButtonStyle(visualSize: 25, hitSize: 32))
                        .disabled(store.isRefreshing)
                        .accessibilityLabel("Refresh Search Console now")
                        .accessibilityIdentifier("settings.searchConsole.refresh")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DSSpacing.xLarge)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.largePanel, style: .continuous),
            kind: .raised,
            elevation: .primary
        )
    }

    private var dataSource: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            Text("Data source & security")
                .font(DSTypography.sectionTitle)
                .foregroundStyle(theme.textPrimary)

            dataRow(
                title: "Service account JSON",
                value: "Connected",
                valueColor: Color(red: 0.32, green: 0.82, blue: 0.46)
            )
            DSDivider()
            dataRow(
                title: "Property",
                value: store.configuration.selectedProperty,
                valueColor: theme.textSecondary
            )
            DSDivider()
            dataRow(
                title: "Credential storage",
                value: "Private key in macOS Keychain",
                valueColor: theme.textSecondary
            )

            HStack {
                Spacer()
                Button("Replace JSON Key…") { importsJSON = true }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.searchConsole.replaceKey")
            }
        }
        .padding(DSSpacing.xLarge)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.largePanel, style: .continuous),
            kind: .raised,
            elevation: .primary
        )
    }

    private var preliminaryNotice: some View {
        HStack(alignment: .top, spacing: DSSpacing.small) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(theme.actionForeground)
            Text("Recent data may be preliminary and subject to change as Google finalizes results.")
                .font(DSTypography.metadata)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, DSSpacing.small)
        .accessibilityIdentifier("settings.searchConsole.preliminaryNotice")
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xLarge) {
            HStack(spacing: DSSpacing.large) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.panel, style: .continuous)
                        .fill(theme.action.opacity(0.18))
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.actionForeground)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                    Text("Connect Google Search Console")
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text("Import a service-account JSON key to show clicks and impressions in the Dock.")
                        .font(DSTypography.body)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            SearchConsoleSetupSteps()

            HStack {
                Button("Connect Service Account…") { importsJSON = true }
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .accessibilityIdentifier("settings.searchConsole.import")
                Button("Setup guide…") { showsManageSheet = true }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.searchConsole.guide")
            }
        }
        .padding(DSSpacing.xLarge)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.largePanel, style: .continuous),
            kind: .raised,
            elevation: .primary
        )
    }

    private func controlRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: DSSpacing.large) {
            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)
                .frame(width: 104, alignment: .leading)
            content()
        }
        .frame(minHeight: 54)
        .padding(.horizontal, DSSpacing.large)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous),
            kind: .inset,
            elevation: .secondary
        )
    }

    private func segmented<Value: CaseIterable & Hashable & Identifiable>(
        _ values: Value.AllCases,
        selection: Value,
        id: String,
        title: KeyPath<Value, String>,
        set: @escaping @MainActor @Sendable (Value) -> Void
    ) -> some View where Value.AllCases: RandomAccessCollection {
        Picker(
            id,
            selection: Binding(get: { selection }, set: set)
        ) {
            ForEach(values) { value in
                Text(value[keyPath: title])
                    .tag(value)
                    .accessibilityIdentifier(
                        "settings.searchConsole.\(id).\(String(describing: value))"
                    )
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .accessibilityLabel(id)
        .accessibilityValue(selection[keyPath: title])
        .accessibilityIdentifier("settings.searchConsole.\(id)")
    }

    private func dataRow(
        title: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(spacing: DSSpacing.medium) {
            Text(title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)
            Spacer(minLength: DSSpacing.large)
            Text(value)
                .font(DSTypography.body)
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(minHeight: 30)
    }

    private var refreshSummary: String {
        if store.isRefreshing { return "Updating… · refreshes every 5 min" }
        guard let fetchedAt = store.state.snapshot?.fetchedAt else {
            return "Waiting for data · refreshes every 5 min"
        }
        return "Updated \(fetchedAt.formatted(.relative(presentation: .named))) · refreshes every 5 min"
    }

    private func importJSON(_ result: Result<[URL], Error>) {
        Task {
            do {
                let url = try result.get().first
                    .unwrap(or: CocoaError(.fileNoSuchFile))
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                try await store.importServiceAccountJSON(data)
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

private struct SearchConsoleConnectionSheet: View {
    let store: SearchConsoleStore
    let importJSON: () -> Void
    let dismiss: () -> Void

    @State private var disconnectError: String?
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xLarge) {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                    Text("Search Console connection")
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text("Create the JSON key in Google Cloud, then grant its email access to your Search Console property.")
                        .font(DSTypography.body)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Button("Done", action: dismiss)
                    .buttonStyle(DSButtonStyle(kind: .primary))
            }

            SearchConsoleSetupSteps()

            HStack(spacing: DSSpacing.medium) {
                Link(
                    "Open Google Cloud IAM",
                    destination: URL(string: "https://console.cloud.google.com/iam-admin/serviceaccounts")!
                )
                .accessibilityIdentifier("settings.searchConsole.guide.googleCloud")
                Link(
                    "Open Search Console",
                    destination: URL(string: "https://search.google.com/search-console")!
                )
                .accessibilityIdentifier("settings.searchConsole.guide.searchConsole")
            }
            .font(DSTypography.bodyEmphasis)

            if store.configuration.isConnected {
                DSDivider()
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Connected account")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(theme.textPrimary)
                    Text(store.configuration.metadata?.clientEmail ?? "")
                        .font(DSTypography.body)
                        .textSelection(.enabled)
                        .foregroundStyle(theme.textSecondary)

                    Picker(
                        "Property",
                        selection: Binding(
                            get: { store.configuration.selectedProperty },
                            set: store.setSelectedProperty
                        )
                    ) {
                        if store.availableSites.isEmpty {
                            Text(store.configuration.selectedProperty)
                                .tag(store.configuration.selectedProperty)
                        } else {
                            ForEach(store.availableSites) { site in
                                Text(site.siteURL).tag(site.siteURL)
                            }
                        }
                    }
                    .accessibilityIdentifier("settings.searchConsole.property")

                    HStack {
                        Button("Replace JSON Key…", action: importJSON)
                            .buttonStyle(DSButtonStyle())
                        Button("Disconnect", role: .destructive) {
                            do {
                                try store.disconnect()
                                dismiss()
                            } catch {
                                disconnectError = error.localizedDescription
                            }
                        }
                        .buttonStyle(DSButtonStyle(kind: .destructive))
                        Spacer()
                    }
                }
            } else {
                Button("Choose JSON Key…", action: importJSON)
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .accessibilityIdentifier("settings.searchConsole.sheetImport")
            }

            if let disconnectError {
                Text(disconnectError)
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.dangerForeground)
            }
        }
        .padding(DSSpacing.xxLarge)
        .frame(width: 650)
        .frame(minHeight: 560, alignment: .topLeading)
        .background(theme.opaqueSurface)
        .task { if store.configuration.isConnected { await store.reloadSites() } }
    }
}

private struct SearchConsoleSetupSteps: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            step(1, "Enable the Google Search Console API in your Google Cloud project.")
            step(2, "Open IAM & Admin → Service Accounts, create or select an account, then open Keys → Add key → Create new key → JSON.")
            step(3, "In Search Console open Settings → Users and permissions → Add user. Add the service-account email with Full permission.")
            step(4, "Import the downloaded JSON file here. DockMagic keeps its private key in macOS Keychain; SwiftData stores only non-secret settings and cached metrics.")
        }
        .accessibilityIdentifier("settings.searchConsole.setupSteps")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.medium) {
            Text("\(number)")
                .font(DSTypography.metadata.weight(.bold))
                .foregroundStyle(theme.onAction)
                .frame(width: 23, height: 23)
                .background(Circle().fill(theme.action))
            Text(text)
                .font(DSTypography.body)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}
