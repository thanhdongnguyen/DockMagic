import AppKit
import SwiftUI

@MainActor
struct GrokBuildSettingsView: View {
    let store: GrokBuildUsageStore
    @Bindable var preferences: DockPreferencesStore
    @State private var executable = ""
    @State private var home = ""
    @State private var showsDashboard = false
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Experimental integration", detail: "Local usage and explicit CLI authentication are available for testing. Automatic quota remains blocked; this feature is not released.") {
                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    Toggle("Enable Grok Build", isOn: $preferences.grokBuildSettings.enabled)
                        .accessibilityIdentifier("settings.grokBuild.enabled")
                    Toggle("Monitor local usage in the background", isOn: $preferences.grokBuildSettings.monitoring)
                        .disabled(!preferences.grokBuildSettings.enabled).accessibilityIdentifier("settings.grokBuild.monitoring")
                    Text("Uses file events and a 15-second metadata scan, even when another Dock feature is active. Turn monitoring off for manual refresh only.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                }
            }
            DSSettingsSection(title: "Grok installation", detail: "Uses the selected executable and Grok home. DockMagic never reads or copies credentials.") {
                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    DSField(title: "Executable", helper: "Leave blank for auto-detect") {
                    HStack {
                        TextField("Executable", text: $executable)
                            .accessibilityIdentifier("settings.grokBuild.executable")
                        Button("Choose…") { choose(directory: false) }
                    }
                    }
                    DSField(title: "Grok home", helper: "Leave blank for ~/.grok") {
                    HStack {
                        TextField("Grok home", text: $home)
                            .accessibilityIdentifier("settings.grokBuild.home")
                        Button("Choose…") { choose(directory: true) }
                    }
                    }
                    HStack {
                        Button("Apply paths") {
                            preferences.grokBuildSettings.executablePath = executable
                            preferences.grokBuildSettings.homePath = home
                        }.accessibilityIdentifier("settings.grokBuild.applyPaths")
                        Button("Auto-detect") {
                            executable = ""; home = ""
                            preferences.grokBuildSettings.executablePath = ""
                            preferences.grokBuildSettings.homePath = ""
                        }
                        Spacer()
                        Text(store.cliVersion.map { "CLI \($0)" } ?? "CLI not checked").font(DSTypography.metadata)
                    }
                    Link("Official installation guide", destination: URL(string: "https://docs.x.ai/build/overview")!)
                }.buttonStyle(DSButtonStyle())
            }
            DSSettingsSection(title: "Local history", detail: GrokBuildDashboardManifest.coverageNote) {
                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    HStack {
                        Text("Local: \(store.local.status.rawValue)").font(DSTypography.bodyEmphasis)
                            .accessibilityIdentifier("settings.grokBuild.localStatus")
                        if store.isRefreshingLocal { ProgressView().controlSize(.small) }
                        Spacer()
                        Button("Refresh") { Task { await store.refresh(forceQuota: true, forceLocal: true) } }
                            .disabled(!store.isEnabled || store.isRefreshingLocal).accessibilityIdentifier("settings.grokBuild.refresh")
                    }
                    if let history = store.local.value { Text(GrokBuildPresentation.coverage(history)).font(DSTypography.metadata) }
                    if let date = store.local.collectedAt { Text("Collected: \(date.formatted())").font(DSTypography.metadata) }
                    if let date = store.local.sourceUpdatedAt { Text("Source updated: \(date.formatted())").font(DSTypography.metadata) }
                    if let error = store.local.error { Text(error.localizedDescription).font(DSTypography.body) }
                    if let warning = store.cacheWarning { Text(warning.localizedDescription).font(DSTypography.body) }
                }.buttonStyle(DSButtonStyle())
            }
            GrokBuildAuthenticationSection(store: store)
            DSSettingsSection(title: "Live Dock preview", detail: "Quota never falls back to tokens automatically. Choose Tokens observed today explicitly to test real local values.") {
                HStack(spacing: DSSpacing.xLarge) {
                    DockTileView(presentation: .grokBuild(local: store.local, settings: preferences.grokBuildSettings,
                        appearance: preferences.grokBuildAppearance), animatesChanges: false)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.grokBuild.preview")
                    VStack(alignment: .leading, spacing: DSSpacing.standard) {
                        DSSelect(title: "Metric", selection: $preferences.grokBuildSettings.metric,
                                 options: GrokBuildSettings.Metric.allCases.map { .init(value: $0, title: $0.title) }).accessibilityIdentifier("settings.grokBuild.metric")
                        DSSelect(title: "Appearance", selection: $preferences.grokBuildSettings.style,
                                 options: GrokBuildSettings.Style.allCases.map { .init(value: $0, title: $0.title) })
                        Button(preferences.activeFeature == .grokBuild ? "Active in Dock" : "Use Grok Build in Dock") { preferences.activeFeature = .grokBuild }
                            .disabled(!store.isEnabled || preferences.activeFeature == .grokBuild)
                            .accessibilityIdentifier("settings.grokBuild.activate")
                        Button("Preview dashboard") { showsDashboard = true }
                            .accessibilityIdentifier("settings.grokBuild.dashboard")
                    }.buttonStyle(DSButtonStyle())
                }
                if showsDashboard {
                    VStack(spacing: DSSpacing.standard) {
                        HStack {
                            Text("Grok Build preview").font(DSTypography.bodyEmphasis)
                            Spacer()
                            Button("Done") { showsDashboard = false }
                                .buttonStyle(DSButtonStyle())
                                .accessibilityIdentifier("settings.grokBuild.closePreview")
                        }
                        // The standard Settings content viewport is 620 pt.
                        // Leave room for Done and section padding; content still
                        // uses the production dashboard's own vertical scroll.
                        let height = min(520, (NSScreen.main?.visibleFrame.height ?? 800) - 160)
                        DockHoverChrome(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: height)) {
                            GrokBuildHoverDashboardView(store: store, appearance: preferences.grokBuildAppearance,
                                onOpenSettings: { showsDashboard = false })
                        }.frame(width: 440, height: height)
                    }.frame(width: 440).frame(maxWidth: .infinity)
                }
            }
            DSSettingsSection(title: "Token appearance", detail: "Color applies only to Dock token values and token charts. Low-contrast colors are adjusted for readability; unavailable values and status keep their semantic appearance.") {
                VStack(spacing: DSSpacing.standard) {
                    HStack(spacing: DSSpacing.standard) {
                        Text("Token data color").font(DSTypography.body).foregroundStyle(theme.textPrimary)
                        Spacer(minLength: DSSpacing.standard)
                        DSColorPalettePicker(selection: Binding(
                            get: { preferences.grokBuildAppearance.tokenColor.color },
                            set: { preferences.grokBuildAppearance.tokenColor = DockColor($0) }),
                            selectionHex: preferences.grokBuildAppearance.tokenColor.hex,
                            options: ProjectTheme.rendererColorOptions,
                            accessibilityLabel: "Grok token data color", identifier: "settings.grokBuild.tokenColor")
                    }.frame(minHeight: 40)
                    HStack {
                        Spacer()
                        Button {
                            preferences.grokBuildAppearance = .standard
                            preferences.grokBuildSettings.style = .number
                        } label: { DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(DSButtonStyle())
                        .accessibilityIdentifier("settings.grokBuild.resetAppearance")
                    }
                }
            }
        }
        .onAppear { executable = preferences.grokBuildSettings.executablePath; home = preferences.grokBuildSettings.homePath }
    }

    private func choose(directory: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directory; panel.canChooseFiles = !directory
        panel.allowsMultipleSelection = false
        panel.message = directory ? "Choose your Grok home; no credential file is read." : "Choose the official Grok executable."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in if directory { home = url.path } else { executable = url.path } }
        }
    }
}
