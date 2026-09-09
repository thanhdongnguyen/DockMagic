import SwiftUI

struct DockAntigravityView: View {
    let state: CodexUsageState
    let appearance: DockRingAppearance
    let animatesChanges: Bool
    @Environment(\.designTheme) private var theme

    private var group: AntigravityQuotaGroup? { state.snapshot?.antigravityTelemetry?.selectedGroup }
    private var buckets: [AntigravityQuotaBucket] { Array((group?.buckets ?? []).prefix(2)) }

    var body: some View {
        Group {
            if appearance.displayStyle == .numeric {
                DockUsageNumericTileView(values: numericValues)
                    .overlay {
                        if let stateSymbol {
                            GeometryReader { proxy in
                                let side = min(proxy.size.width, proxy.size.height)
                                Image(systemName: stateSymbol)
                                    .symbolRenderingMode(.monochrome)
                                    .font(.system(size: side * 0.16, weight: .bold))
                                    .foregroundStyle(theme.color(for: stateRole) ?? theme.dockOutline)
                                    .padding(side * 0.04)
                                    .background(theme.dockBackgroundInset, in: Circle())
                                    .position(x: side * 0.82, y: side * 0.18)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
            } else {
                DockRingTileView(
                    outerRing: .init(progress: buckets.first?.remainingFraction,
                                     color: appearance.outerColor.color, width: appearance.outerWidth,
                                     usesSingleRingLayout: buckets.count == 1),
                    innerRing: buckets.count == 1 ? nil : .init(
                        progress: buckets.dropFirst().first?.remainingFraction,
                        color: appearance.innerColor.color, width: appearance.innerWidth
                    ), stateSymbol: stateSymbol, stateRole: stateRole, animatesChanges: animatesChanges
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Antigravity usage remaining")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.antigravity")
    }

    private var numericValues: [DockNumericValue] {
        if buckets.isEmpty { return [.init(label: "QUOTA", value: "—", color: appearance.outerColor.color)] }
        return buckets.enumerated().map { index, bucket in
            .init(label: bucket.shortTitle, value: bucket.remainingFraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                  color: index == 0 ? appearance.outerColor.color : appearance.innerColor.color)
        }
    }

    private var stateSymbol: String? {
        switch state {
        case .unavailable: "exclamationmark.triangle.fill"
        case .stale: "clock.badge.exclamationmark"
        case .idle, .loading, .live: nil
        }
    }

    private var stateRole: DSSemanticRole {
        switch state {
        case .unavailable: .danger
        case .stale: .warning
        case .idle, .loading, .live: .neutral
        }
    }

    private var accessibilityValue: String {
        let values = buckets.map { "\($0.title) \($0.remainingFraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "unavailable")" }
        return ([state.statusTitle, group?.title].compactMap { $0 } + values).joined(separator: ", ")
    }
}
