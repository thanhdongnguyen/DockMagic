import SwiftUI

struct DockGrokBuildView: View {
    let local: GrokBuildObservation<GrokBuildHistorySnapshot>
    let settings: GrokBuildSettings
    var appearance: GrokBuildAppearance = .standard
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        DockTileSurface { side in
            VStack(spacing: side * 0.025) {
                if settings.metric == .quota {
                    // No fake window, percent, or token fallback when billing is blocked.
                    DSIcon(systemName: "minus.circle").dsFont(size: side * 0.34)
                    Text("QUOTA —").dsFont(size: side * 0.105, weight: .bold)
                } else {
                    Text(GrokBuildPresentation.compact(settings.enabled ? GrokBuildPresentation.today(local.value) : nil))
                        .dsFont(size: side * 0.30, weight: .bold)
                        .minimumScaleFactor(0.5).lineLimit(1).monospacedDigit()
                        .foregroundStyle(settings.enabled && GrokBuildPresentation.today(local.value) != nil
                            ? ProjectTheme.readableRendererColor(appearance.tokenColor, on: theme.dockBackgroundRaised,
                                colorScheme: colorScheme, minimumContrast: 4.5).color
                            : theme.dockForeground)
                    Text("TOKENS*").dsFont(size: side * 0.105, weight: .bold)
                    if local.status == .stale { DSIcon(systemName: "clock").dsFont(size: side * 0.1) }
                }
            }.foregroundStyle(theme.dockForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if settings.style == .ring {
                        Circle().strokeBorder(theme.dockOutline, style: StrokeStyle(lineWidth: side * 0.025, dash: [side * 0.05]))
                            .padding(side * 0.07).accessibilityHidden(true)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grok Build")
        .accessibilityValue(settings.metric == .quota ? GrokBuildDashboardManifest.quotaNote :
            "\(settings.enabled ? GrokBuildPresentation.today(local.value).map { $0.formatted() } ?? "Unknown" : "Disabled") tokens observed today. \(local.status.rawValue). Partial local history.")
        .accessibilityIdentifier("dock.grokBuild")
    }
}
