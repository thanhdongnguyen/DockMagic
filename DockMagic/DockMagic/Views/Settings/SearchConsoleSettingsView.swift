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

            Text("\(store.credentials.count) JSON \(store.credentials.count == 1 ? "key" : "keys")")
                .font(DSTypography.metadata)
                .foregroundStyle(theme.textTertiary)

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
            HStack(spacing: DSSpacing.medium) {
                Text("Data source & storage")
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button("Manage JSON Keys…") { showsManageSheet = true }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.searchConsole.manageKeys")
            }

            dataRow(
                title: "JSON keys",
                value: "\(store.credentials.count) saved",
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
                value: "Complete JSON files in SwiftData",
                valueColor: theme.textSecondary
            )
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
                    Text("Complete the setup below, then import a service-account JSON key to show clicks and impressions in the Dock.")
                        .font(DSTypography.body)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer(minLength: DSSpacing.large)

                Button("Add JSON Key…") { importsJSON = true }
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .accessibilityIdentifier("settings.searchConsole.import")
            }

            SearchConsoleSetupSteps()
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

    @State private var credentialPendingRemoval: SearchConsoleCredential?
    @State private var operationError: String?
    @Environment(\.designTheme) private var theme

    var body: some View {
        sheetContent
            .alert(
                "Remove JSON key?",
                isPresented: removalAlertIsPresented,
                presenting: credentialPendingRemoval,
                actions: removalAlertActions,
                message: removalAlertMessage
            )
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            sheetHeader
            DSDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.section) {
                    credentialSection
                    setupGuide
                    if let operationError {
                        Text(operationError)
                            .font(DSTypography.metadata)
                            .foregroundStyle(theme.dangerForeground)
                    }
                }
                .padding(DSSpacing.xxLarge)
            }
        }
        .frame(width: 760, height: 680)
        .background(theme.opaqueSurface)
        .task { if store.configuration.isConnected { await store.reloadSites() } }
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: DSSpacing.large) {
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text("Search Console connection")
                    .font(DSTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Add, select, and remove the service-account JSON keys available to DockMagic.")
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(DSIconButtonStyle(visualSize: 28, hitSize: 36))
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("settings.searchConsole.sheetClose")
        }
        .padding(.horizontal, DSSpacing.xxLarge)
        .padding(.vertical, DSSpacing.xLarge)
    }

    private var credentialSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            HStack(alignment: .center, spacing: DSSpacing.large) {
                VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                    Text("JSON keys")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(theme.textPrimary)
                    Text(credentialCountSummary)
                        .font(DSTypography.metadata)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Button("Add JSON Key…", action: importJSON)
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .accessibilityIdentifier("settings.searchConsole.sheetImport")
            }

            if store.credentials.isEmpty {
                emptyCredentialState
            } else {
                credentialList
            }
        }
        .padding(DSSpacing.xLarge)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.largePanel,
                style: .continuous
            ),
            kind: .raised,
            elevation: .primary
        )
    }

    private var credentialList: some View {
        VStack(spacing: DSSpacing.small) {
            ForEach(store.credentials) { credential in
                credentialRow(credential)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.searchConsole.credentialList")
    }

    private var setupGuide: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text("Setup guide")
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(theme.textPrimary)
                Text("Google Cloud and Search Console access steps")
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
            }
            SearchConsoleSetupSteps()
        }
        .padding(DSSpacing.xLarge)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.largePanel,
                style: .continuous
            ),
            kind: .raised,
            elevation: .secondary
        )
        .accessibilityIdentifier("settings.searchConsole.setupGuide")
    }

    private var credentialCountSummary: String {
        let noun = store.credentials.count == 1 ? "key" : "keys"
        return "\(store.credentials.count) \(noun) stored locally in SwiftData"
    }

    private var removalAlertIsPresented: Binding<Bool> {
        Binding(
            get: { credentialPendingRemoval != nil },
            set: { if !$0 { credentialPendingRemoval = nil } }
        )
    }

    @ViewBuilder
    private func removalAlertActions(
        _ credential: SearchConsoleCredential
    ) -> some View {
        Button("Remove", role: .destructive) {
            remove(credential)
        }
        Button("Cancel", role: .cancel) {
            credentialPendingRemoval = nil
        }
    }

    private func removalAlertMessage(
        _ credential: SearchConsoleCredential
    ) -> Text {
        Text("DockMagic will remove \(credential.clientEmail) and its complete JSON data from SwiftData.")
    }

    private func remove(_ credential: SearchConsoleCredential) {
        Task {
            do {
                try await store.removeCredential(credential.id)
            } catch {
                operationError = error.localizedDescription
            }
            credentialPendingRemoval = nil
        }
    }

    private var emptyCredentialState: some View {
        HStack(spacing: DSSpacing.medium) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text("No JSON keys yet")
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                Text("Add a service-account JSON file to connect a property.")
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(DSSpacing.large)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous),
            kind: .inset,
            elevation: .secondary
        )
    }

    private func credentialRow(
        _ credential: SearchConsoleCredential
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            HStack(spacing: DSSpacing.medium) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    )
                    .fill(
                        credential.isActive
                            ? theme.action.opacity(0.18)
                            : theme.surfaceRaised
                    )
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            credential.isActive
                                ? theme.actionForeground
                                : theme.textSecondary
                        )
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                    HStack(spacing: DSSpacing.small) {
                        Text(credential.clientEmail)
                            .font(DSTypography.bodyEmphasis)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if credential.isActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(DSTypography.metadata)
                                .foregroundStyle(theme.processingForeground)
                        }
                    }
                    Text("Project: \(credential.projectID)  ·  Key: \(credential.privateKeyID)")
                        .font(DSTypography.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DSSpacing.medium)

                if !credential.isActive {
                    Button("Use") {
                        Task { await store.selectCredential(credential.id) }
                    }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier(
                        "settings.searchConsole.credential.use.\(credential.privateKeyID)"
                    )
                }

                Button {
                    credentialPendingRemoval = credential
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(DSIconButtonStyle(visualSize: 26, hitSize: 34))
                .accessibilityLabel("Remove \(credential.clientEmail)")
                .accessibilityIdentifier(
                    "settings.searchConsole.credential.remove.\(credential.privateKeyID)"
                )
            }

            if credential.isActive {
                DSDivider()
                HStack(spacing: DSSpacing.large) {
                    Text("Property")
                        .font(DSTypography.bodyEmphasis)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: DSSpacing.large)
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
                    .labelsHidden()
                    .frame(maxWidth: 360)
                    .accessibilityIdentifier("settings.searchConsole.property")
                }
            }
        }
        .padding(DSSpacing.large)
        .dsSurface(
            RoundedRectangle(cornerRadius: DSRadius.panel, style: .continuous),
            kind: credential.isActive ? .chrome : .inset,
            elevation: credential.isActive ? .primary : .secondary
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "settings.searchConsole.credential.\(credential.privateKeyID)"
        )
    }
}

private struct SearchConsoleSetupSteps: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            step(
                1,
                title: "Verify your website property",
                detail: "Open Search Console, add or select your website, and complete ownership verification. Your Google account must be a property Owner to add users.",
                linkTitle: "Open Search Console",
                linkDestination: URL(string: "https://search.google.com/search-console")!,
                linkID: "settings.searchConsole.guide.searchConsole"
            )
            step(
                2,
                title: "Enable the Search Console API",
                detail: "In the Google Cloud project that owns the service account, open APIs & Services → Library, search for “Google Search Console API,” then click Enable.",
                linkTitle: "Enable API",
                linkDestination: URL(string: "https://console.cloud.google.com/apis/library/searchconsole.googleapis.com")!,
                linkID: "settings.searchConsole.guide.api"
            )
            step(
                3,
                title: "Create and download the JSON key",
                detail: "Open IAM & Admin → Service Accounts, create or select the account, then open Keys → Add key → Create new key → JSON. Keep the downloaded file private.",
                linkTitle: "Service accounts",
                linkDestination: URL(string: "https://console.cloud.google.com/iam-admin/serviceaccounts")!,
                linkID: "settings.searchConsole.guide.googleCloud"
            )
            step(
                4,
                title: "Grant the service account access",
                detail: "Copy client_email from the JSON. In Search Console, select the property, then open Settings at the bottom left → Users and permissions → Add user. Paste the email, choose Restricted, and click Add."
            )
            step(
                5,
                title: "Connect DockMagic",
                detail: "Return here, click Add JSON Key…, and choose the JSON file. DockMagic stores the complete key in SwiftData on this Mac and requests Search Console data with read-only access."
            )

            Label {
                Text("Search Console collects data automatically—no tracking script is required. New data usually appears after 2–3 days, and a new property can take up to a week.")
            } icon: {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
            }
            .font(DSTypography.metadata)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.searchConsole.dataDelayNote")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.searchConsole.setupSteps")
    }

    private func step(
        _ number: Int,
        title: String,
        detail: String,
        linkTitle: String? = nil,
        linkDestination: URL? = nil,
        linkID: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.medium) {
            Text("\(number)")
                .font(DSTypography.metadata.weight(.bold))
                .foregroundStyle(theme.onAction)
                .frame(width: 23, height: 23)
                .background(Circle().fill(theme.action))

            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.medium) {
                    Text(title)
                        .font(DSTypography.bodyEmphasis)
                        .foregroundStyle(theme.textPrimary)

                    Spacer(minLength: DSSpacing.medium)

                    if let linkTitle, let linkDestination, let linkID {
                        Link(linkTitle, destination: linkDestination)
                            .font(DSTypography.metadata.weight(.semibold))
                            .accessibilityIdentifier(linkID)
                    }
                }
                Text(detail)
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.searchConsole.setupStep.\(number)")
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}
