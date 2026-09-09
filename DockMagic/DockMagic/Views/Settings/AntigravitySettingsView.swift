import AppKit
import SwiftUI

@MainActor
struct AntigravitySettingsView: View {
    let appModel: DockAppModel
    @Environment(\.designTheme) private var theme

    private var store: AntigravityUsageStore { appModel.antigravityStore }
    private var appearance: DockRingAppearance { appModel.preferences.antigravityAppearance }
    private var quota: AntigravityQuotaSnapshot? { store.state.snapshot?.antigravityTelemetry?.quota }
    private var buckets: [AntigravityQuotaBucket] { store.state.snapshot?.antigravityTelemetry?.selectedGroup?.buckets ?? [] }

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Antigravity Dock preview", detail: "Remaining Antigravity quota.") {
                HStack(spacing: DSSpacing.xLarge) {
                    DockAntigravityView(state: store.state, appearance: appearance, animatesChanges: true)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.dockPreview")
                    VStack(alignment: .leading, spacing: DSSpacing.standard) {
                        if buckets.isEmpty {
                            Text("Open Antigravity to see your quota here.").foregroundStyle(theme.textSecondary)
                        } else {
                            ForEach(Array(buckets.prefix(2).enumerated()), id: \.element.id) { index, bucket in
                                PreviewMetric(title: "\(bucket.title) left", value: bucket.remainingFraction,
                                              color: index == 0 ? appearance.outerColor.color : appearance.innerColor.color)
                            }
                        }
                        if appModel.preferences.activeFeature != .antigravity {
                            Button("Show in Dock") { appModel.activateFeature(.antigravity) }
                                .buttonStyle(DSButtonStyle(kind: .primary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .overlay(alignment: .topTrailing) {
                connectionIndicator
                    .padding(DSSpacing.xLarge)
            }

            DockDisplayStyleEditor(featureTitle: "Antigravity", selection: Binding(
                get: { appearance.displayStyle }, set: { appModel.preferences.setAntigravityDisplayStyle($0) }
            ))
            RingAppearanceEditor(
                outerTitle: buckets.first?.title ?? "Primary quota",
                innerTitle: buckets.dropFirst().first?.title ?? "Second quota",
                appearance: appearance,
                outerColor: Binding(get: { appearance.outerColor.color }, set: { appModel.preferences.setAntigravityOuterColor(DockColor($0)) }),
                innerColor: Binding(get: { appearance.innerColor.color }, set: { appModel.preferences.setAntigravityInnerColor(DockColor($0)) }),
                outerWidth: Binding(get: { appearance.outerWidth }, set: { appModel.preferences.setAntigravityOuterWidth($0) }),
                innerWidth: Binding(get: { appearance.innerWidth }, set: { appModel.preferences.setAntigravityInnerWidth($0) }),
                reset: appModel.preferences.resetAntigravityAppearance
            )
        }
        .task { store.start() }
    }

    private var connectionIndicator: some View {
        let presentation = connectionPresentation
        return Button {
            if case .unavailable = store.state { openAntigravity() }
            Task { await appModel.prepareDeveloperToolIntegration(for: .antigravity) }
        } label: {
            DSIconPlate(
                systemImage: presentation.systemImage,
                role: presentation.role,
                size: 32
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isInstallingBridge || store.isRefreshing)
        .help("\(presentation.title). \(presentation.detail)")
        .accessibilityIdentifier("settings.antigravity.installationIndicator")
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.detail)
        .accessibilityHint("Connect or check the Antigravity connection")
    }

    private var connectionPresentation: (
        title: String, detail: String, systemImage: String, role: DSSemanticRole
    ) {
        if store.isInstallingBridge {
            return ("Connecting Antigravity", "Setting up local activity. Keep DockMagic open until this finishes.",
                    "arrow.down.circle.fill", .processing)
        }
        if store.isRefreshing {
            return ("Checking Antigravity", "Reading the latest local usage.",
                    "magnifyingglass", .processing)
        }
        if let error = store.bridgeError {
            return ("Antigravity setup failed", "\(error) Click to retry.",
                    "exclamationmark.triangle.fill", .danger)
        }
        if !store.isBridgeInstalled {
            return ("Connect Antigravity", "Click to connect local activity and check usage.",
                    "link", .warning)
        }
        switch store.state {
        case .idle, .loading:
            return ("Checking Antigravity", "Waiting for local usage.", "magnifyingglass", .processing)
        case .live:
            return ("Antigravity connected", "\(connectionDetail) Click to check the connection.",
                    "checkmark.circle.fill", .information)
        case .stale:
            return ("Antigravity needs attention", "\(connectionDetail) Click to retry.",
                    "clock.badge.exclamationmark", .warning)
        case .unavailable:
            return ("Antigravity unavailable", "\(connectionDetail) Click to open Antigravity and reconnect.",
                    "exclamationmark.triangle.fill", .warning)
        }
    }

    private var connectionDetail: String {
        switch store.state {
        case .unavailable(let message), .stale(_, let message): message
        case .idle, .loading: "Waiting for Antigravity usage."
        case .live:
            quota.map { "\($0.source) · Updated \($0.observedAt.formatted(date: .omitted, time: .shortened))" }
                ?? "Receiving local Antigravity activity. Quota has not been reported yet."
        }
    }

    private func openAntigravity() {
        let candidates = [URL(fileURLWithPath: "/Applications/Antigravity.app"),
                          FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Antigravity.app")]
        if let app = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.openApplication(at: app, configuration: .init())
        } else if let url = URL(string: "https://antigravity.google/download") { NSWorkspace.shared.open(url) }
    }
}
