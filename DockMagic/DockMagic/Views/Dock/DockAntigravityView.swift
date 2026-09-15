import SwiftUI

struct DockAntigravityView: View {
    let state: AntigravityUsageState
    let appearance: DockRingAppearance
    let animatesChanges: Bool

    @Environment(\.designTheme) private var theme

    var body: some View {
        Group {
            if appearance.displayStyle == .numeric {
                DockUsageNumericTileView(values: numericValues)
            } else {
                DockRingTileView(
                    outerRing: ring(at: 0),
                    innerRing: ring(at: 1),
                    stateSymbol: stateSymbol,
                    stateRole: stateRole,
                    animatesChanges: animatesChanges
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Antigravity quota remaining")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.antigravity")
    }

    private var buckets: [AntigravityQuotaBucket] {
        state.snapshot?.dockBuckets ?? []
    }

    private var numericValues: [DockNumericValue] {
        guard !buckets.isEmpty else {
            return [DockNumericValue(
                label: "QUOTA",
                value: "—",
                color: theme.dockOutline
            )]
        }
        return buckets.enumerated().map { index, bucket in
            DockNumericValue(
                label: bucket.shortTitle,
                value: Self.percentage(bucket.remainingFraction),
                color: color(at: index)
            )
        }
    }

    private func ring(at index: Int) -> DockRingDescriptor? {
        guard buckets.indices.contains(index) else { return nil }
        return DockRingDescriptor(
            progress: buckets[index].remainingFraction,
            color: color(at: index),
            width: index == 0 ? appearance.outerWidth : appearance.innerWidth,
            usesSingleRingLayout: buckets.count == 1
        )
    }

    private func color(at index: Int) -> Color {
        index == 0 ? appearance.outerColor.color : appearance.innerColor.color
    }

    private var stateSymbol: String? {
        switch state {
        case .stale: "clock.badge.exclamationmark"
        case .unavailable: "exclamationmark.triangle.fill"
        case .idle, .loading, .live: nil
        }
    }

    private var stateRole: DSSemanticRole {
        switch state {
        case .unavailable: .danger
        case .stale: .warning
        case .idle, .loading, .live: .processing
        }
    }

    private var accessibilityValue: String {
        let quota = buckets.map {
            "\($0.groupName) \(Self.percentage($0.remainingFraction))"
        }.joined(separator: ", ")
        return quota.isEmpty ? state.statusTitle : "\(quota), \(state.statusTitle)"
    }

    private static func percentage(_ value: Double) -> String {
        min(max(value, 0), 1).formatted(
            .percent.precision(.fractionLength(0))
        )
    }
}
