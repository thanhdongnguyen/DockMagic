import AppKit
import SwiftUI

@MainActor
struct OpenCodeSettingsView: View {
    let store: OpenCodeUsageStore
    @Bindable var preferences: DockPreferencesStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Local history", detail: OpenCodeUsageSnapshot.coverageNote) {
                VStack(alignment: .leading, spacing: DSSpacing.standard) {
                    if let database = store.database {
                        Text(database.path).font(DSTypography.metadata).foregroundStyle(theme.textSecondary).textSelection(.enabled)
                    }
                    if let message = store.state.message { Text(message).font(DSTypography.body).foregroundStyle(theme.textSecondary) }
                    if store.candidates.count > 1 {
                        ForEach(store.candidates, id: \.path) { url in
                            Button(url.path) { store.chooseDatabase(url) }.lineLimit(2)
                        }
                    }
                    HStack {
                        Button("Choose database…", action: chooseDatabase).accessibilityIdentifier("settings.openCode.chooseDatabase")
                        Button("Auto-detect") { store.chooseDatabase(nil) }
                        Button("Refresh", action: store.refresh).disabled(store.state.isRefreshing)
                            .accessibilityIdentifier("settings.openCode.refresh")
                        if store.state.isRefreshing { ProgressView().controlSize(.small) }
                        Spacer()
                    }
                    if store.database == nil {
                        Text("Run OpenCode to create local history, then auto-detect or select its database. The CLI is optional once a database exists.")
                            .font(DSTypography.body).foregroundStyle(theme.textSecondary)
                        Link("OpenCode setup guide", destination: URL(string: "https://opencode.ai/docs/")!)
                    }
                }.buttonStyle(DSButtonStyle())
            }
            DSSettingsSection(title: "Live Dock preview", detail: "Today's recorded tokens and a fixed 7-day area chart. Missing days remain gaps.") {
                HStack {
                    Spacer()
                    DockTileView(presentation: .openCode(state: store.state, appearance: preferences.openCodeAppearance), animatesChanges: false)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.openCode.preview")
                    Spacer()
                }
            }
            DSSettingsSection(title: "Appearance", detail: "Chart and token colors are customized independently for the Dock renderer and dashboard data.") {
                VStack(spacing: DSSpacing.standard) {
                    DSRendererColorRow(
                        title: "Chart color",
                        selection: $preferences.openCodeAppearance.chartColor,
                        identifier: "settings.openCode.chartColor"
                    )
                    DSRendererColorRow(
                        title: "Token number color",
                        selection: $preferences.openCodeAppearance.tokenColor,
                        identifier: "settings.openCode.tokenColor"
                    )

                    HStack(spacing: DSSpacing.standard) {
                        Text("Line thickness")
                            .font(DSTypography.body)
                            .foregroundStyle(theme.textPrimary)
                        Spacer(minLength: DSSpacing.standard)
                        DSSlider(value: $preferences.openCodeAppearance.lineWidth, in: 1...4, step: 0.2)
                            .frame(maxWidth: DSLayout.sliderMaximumWidth)
                            .accessibilityLabel("OpenCode chart line thickness")
                            .accessibilityValue("\(preferences.openCodeAppearance.lineWidth.formatted(.number.precision(.fractionLength(1)))) points")
                            .accessibilityIdentifier("settings.openCode.lineWidth")
                        Text(preferences.openCodeAppearance.lineWidth.formatted(.number.precision(.fractionLength(1))))
                            .font(DSTypography.keycap)
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 28, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                    HStack {
                        Spacer()
                        Button { preferences.openCodeAppearance = .standard } label: {
                            DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(DSButtonStyle())
                        .accessibilityIdentifier("settings.openCode.resetAppearance")
                    }
                }
            }
        }
        .onAppear { store.setSettingsVisible(true) }
        .onDisappear { store.setSettingsVisible(false) }
    }
    private func chooseDatabase() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.message = "Select one OpenCode SQLite database. DockMagic opens it read-only."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in store.chooseDatabase(url) }
        }
    }
}
