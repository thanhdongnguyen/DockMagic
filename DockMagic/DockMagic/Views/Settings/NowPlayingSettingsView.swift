import SwiftUI

@MainActor
struct NowPlayingSettingsView: View {
    let store: NowPlayingStore
    let isActive: Bool
    let onOpen: () -> Void
    @Environment(\.designTheme) private var theme
    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Live Dock preview", detail: isActive ? "Now Playing is active in your Dock." : "Open the dashboard to activate Now Playing in your Dock.") {
                HStack(spacing: DSSpacing.xLarge) {
                    DockTileView(presentation: .nowPlaying(store.dockPresentation), animatesChanges: false)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.nowPlaying.preview")
                    VStack(alignment: .leading, spacing: DSSpacing.compact) {
                        Text(store.snapshot?.track?.title ?? "Your music, one glance away")
                            .font(DSTypography.panelTitle).foregroundStyle(theme.textPrimary)
                        Text("Album artwork in the Dock. Hover for playback, seeking and app volume, or open a dashboard you can use with the keyboard.")
                            .font(DSTypography.body).foregroundStyle(theme.textSecondary)
                        Button("Open Now Playing", action: onOpen).buttonStyle(DSButtonStyle())
                            .accessibilityIdentifier("settings.nowPlaying.open")
                    }
                }
            }
            DSSettingsSection(title: "Music apps", detail: "Connect each app separately. DockMagic controls the local desktop apps using macOS Automation.") {
                VStack(spacing: DSSpacing.standard) {
                    ForEach(NowPlayingSource.allCases) { source in
                        if source != NowPlayingSource.allCases.first { DSDivider() }
                        sourceRow(source)
                    }
                    Text("Dock hover uses Accessibility. Music controls use Automation. Opening this dashboard does not require Accessibility.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            DSSettingsSection(title: "Playback", detail: "Auto follows a playing app and keeps the current source when both apps are playing.") {
                VStack(spacing: DSSpacing.standard) {
                    DSSelect(title: "Source", selection: Binding(get: { store.configuration.selection }, set: store.select),
                             options: NowPlayingSelection.allCases.map { .init(value: $0, title: $0.title) }).accessibilityIdentifier("settings.nowPlaying.source")
                    DSDivider()
                    DSSelect(title: "Skip interval", selection: Binding(get: { store.configuration.skipSeconds }, set: { value in store.updateConfiguration { $0.skipSeconds = value } }),
                             options: NowPlayingConfiguration.skipIntervals.map { .init(value: $0, title: "\($0) seconds") }).accessibilityIdentifier("settings.nowPlaying.skip")
                    Text("Switching sources does not start or stop playback. Seeking is available only when the music app reports a usable duration and position.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear { store.setInterest(.settings, active: true) }
        .onDisappear { store.setInterest(.settings, active: false) }
    }
    private func sourceRow(_ source: NowPlayingSource) -> some View {
        let installed = NowPlayingStore.isInstalled(source)
        let access = installed ? store.observations[source]?.access ?? .notDetermined : .notInstalled
        return HStack(spacing: DSSpacing.standard) {
            Toggle(isOn: Binding(get: { store.configuration.enabledSources.contains(source) }, set: { store.setEnabled(source, enabled: $0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title).font(DSTypography.bodyEmphasis)
                    Text(store.connecting.contains(source) ? "Connecting…" : access.title)
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                }
            }.toggleStyle(DSCheckboxStyle()).disabled(!installed)
                .accessibilityIdentifier("settings.nowPlaying.enabled.\(source.rawValue)")
            Spacer()
            if store.connecting.contains(source) { ProgressView().controlSize(.small) }
            else if access == .denied {
                Button("Privacy Settings", action: NowPlayingStore.openAutomationSettings).buttonStyle(DSButtonStyle())
            } else if access == .notRunning {
                Button("Open App") { NowPlayingStore.openApp(source) }.buttonStyle(DSButtonStyle())
            } else if access == .authorized {
                Button("Open App") { NowPlayingStore.openApp(source) }.buttonStyle(DSButtonStyle())
            } else {
                Button("Connect") { store.connect(source) }.buttonStyle(DSButtonStyle())
                    .disabled(!installed).accessibilityIdentifier("settings.nowPlaying.connect.\(source.rawValue)")
            }
        }
    }
}
