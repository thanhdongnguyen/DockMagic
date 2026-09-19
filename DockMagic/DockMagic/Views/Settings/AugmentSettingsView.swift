import AppKit
import SwiftUI

@MainActor
struct AugmentSettingsView: View {
    let store: AugmentUsageStore
    @Bindable var preferences: DockPreferencesStore
    @Environment(\.designTheme) private var theme
    @Environment(\.dsAppearanceMode) private var appearanceMode
    @State private var token = ""
    @State private var showsDashboard = false

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            connection
            preview
            display
            dataSection
        }
        .buttonStyle(DSButtonStyle())
        .dsDialog(isPresented: $showsDashboard) {
            VStack(spacing: DSSpacing.small) {
                HStack {
                    Text("Augment preview").font(DSTypography.bodyEmphasis)
                    Spacer()
                    Button("Done") { showsDashboard = false }
                        .buttonStyle(DSButtonStyle()).accessibilityIdentifier("settings.augment.closePreview")
                }.padding(.horizontal, DSSpacing.standard)
                let height = min(650, (NSScreen.main?.visibleFrame.height ?? 800) - 120)
                DockHoverChrome(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: height)) {
                    AugmentHoverDashboardView(
                        store: store,
                        chartColor: preferences.augmentAppearance.color,
                        onOpenSettings: { showsDashboard = false }
                    )
                }.frame(width: 440, height: height)
            }.padding(DSSpacing.small).interactiveDismissDisabled()
        }
        .onAppear { store.setSettingsVisible(true) }
        .onDisappear { token = ""; store.setSettingsVisible(false) }
    }

    private var connection: some View {
        DSConnectionForm(title: "Connection", detail: "Enterprise Analytics access is required. This token reads usage for the entire organization.") {
            DSField(title: store.isConfigured ? "Replacement API token" : "Service-account API token") {
            HStack {
                SecureField(store.isConfigured ? "Replacement API token" : "Service-account API token", text: $token)
                    .textFieldStyle(DSInputStyle())
                    .accessibilityIdentifier("settings.augment.token")
                    .onSubmit(connect)
                Button(store.isConfigured ? "Replace token" : "Connect", action: connect)
                    .buttonStyle(DSButtonStyle(emphasis: .primary))
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isConnecting)
                    .accessibilityIdentifier("settings.augment.connect")
            }
            }
        } status: {
            HStack {
                if store.isConnecting { ProgressView().controlSize(.small) }
                Text(store.isConfigured ? "Token saved in macOS Keychain" : "No token saved").font(DSTypography.metadata)
                Spacer()
                Button("Test connection") { Task { await store.testConnection() } }
                    .disabled(!store.isConfigured || store.isConnecting).accessibilityIdentifier("settings.augment.test")
                Button("Disconnect", action: store.disconnect)
                    .disabled(!store.isConfigured || store.isConnecting).accessibilityIdentifier("settings.augment.disconnect")
            }
            if let message = store.connectionMessage { Text(message).font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
        } actions: {
            VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack {
                Link("How to get a token", destination: URL(string: "https://docs.augmentcode.com/analytics/analytics-api")!)
                Link("Manage service-account tokens", destination: URL(string: "https://docs.augmentcode.com/cli/automation/service-accounts")!)
            }.font(DSTypography.metadata)
            Text("Disconnect removes the token from this Mac. Delete it in Augment to revoke access.")
                .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var preview: some View {
        DSSettingsSection(title: "Augment Dock preview", detail: "Latest reported organization usage, grouped by UTC day.") {
            HStack(spacing: DSSpacing.xLarge) {
                DockTileView(presentation: .augment(state: store.state, appearance: preferences.augmentAppearance), animatesChanges: false)
                    .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                    .accessibilityIdentifier("settings.augment.preview")
                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    Text(store.state.label).font(DSTypography.bodyEmphasis)
                    if let day = store.state.snapshot?.latest {
                        Text(AugmentUTC.string(day.date) + " UTC").font(DSTypography.metadata)
                        ForEach(AugmentPresentation.dockMetrics(preferences.augmentAppearance)) { metric in
                            LabeledContent(metric.title, value: AugmentFormatting.value(day.metrics.value(metric), metric: metric))
                                .font(DSTypography.body)
                        }
                    }
                    HStack {
                        Button(preferences.activeFeature == .augment ? "Active in Dock" : "Use Augment in Dock") { preferences.activeFeature = .augment }
                            .disabled(preferences.activeFeature == .augment).accessibilityIdentifier("settings.augment.activate")
                        Button("Preview dashboard") { showsDashboard = true }.accessibilityIdentifier("settings.augment.dashboard")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var display: some View {
        DSSettingsSection(title: "Dock display", detail: "Input and Output remain separate. Data color is shared by the Dock chart and dashboard history.") {
            DSSegmentedControl(title: "Metric", selection: $preferences.augmentAppearance.metric, options: [
                .init(value: .tokens, title: "Input / Output"), .init(value: .billedUSD, title: "Billed USD")
            ]).accessibilityIdentifier("settings.augment.metric")
            DSSegmentedControl(title: "Style", selection: $preferences.augmentAppearance.displayStyle, options: [
                .init(value: .numeric, title: "Numbers"), .init(value: .chart, title: "Trend")
            ]).accessibilityIdentifier("settings.augment.style")
            DSRendererColorRow(title: "Data color", selection: $preferences.augmentAppearance.color,
                identifier: "settings.augment.color")
            if preferences.augmentAppearance.displayStyle == .chart {
                HStack {
                    Text("Line thickness")
                    DSSlider(value: $preferences.augmentAppearance.lineWidth, in: 1...4, step: 0.2)
                }
            }
            HStack { Spacer(); Button("Reset appearance") { preferences.augmentAppearance = .standard } }
        }
    }

    private var dataSection: some View {
        DSSettingsSection(title: "Data", detail: "Organization totals · UTC · reported analytics, not realtime.") {
            if let snapshot = store.state.snapshot {
                LabeledContent("Period", value: snapshot.range.label)
                LabeledContent("Last successful download", value: snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))
            }
            Text("Refreshes at most every 6 hours while Augment is active or visible. Manual refresh has a 30-second cooldown. Queries end at yesterday UTC. Missing dates and fields are not treated as zero.")
                .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
            if let message = store.state.message { Text(message).font(DSTypography.metadata) }
            HStack {
                Button("Refresh", action: store.refreshManually).disabled(!store.isConfigured || store.state.isRefreshing)
                    .accessibilityIdentifier("settings.augment.refresh")
                if store.state.isRefreshing { ProgressView().controlSize(.small) }
                Spacer()
                Button("Clear local history", action: store.clearHistory).accessibilityIdentifier("settings.augment.clearHistory")
            }
            if let message = store.cacheMessage { Text(message).font(DSTypography.metadata) }
        }
    }
    private func connect() {
        let input = token
        Task { if await store.connect(token: input) { token = "" } }
    }
}
