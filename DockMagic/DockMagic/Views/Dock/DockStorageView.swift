import SwiftUI

struct DockStorageView: View {
    let snapshot: StorageMetricsSnapshot
    let appearance: DockSingleRingAppearance
    let errorDescription: String?
    let animatesChanges: Bool

    @ViewBuilder
    var body: some View {
        if appearance.displayStyle == .numeric {
            DockNumericTileView(
                values: [
                    DockNumericValue(
                        label: "USED",
                        value: snapshot.totalBytes > 0
                            ? snapshot.usage.formatted(
                                .percent.precision(.fractionLength(0))
                            )
                            : "—",
                        color: appearance.color.color
                    )
                ]
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Storage usage")
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("dock.storage")
        } else {
            DockRingTileView(
                outerRing: DockRingDescriptor(
                    progress: snapshot.totalBytes > 0 ? snapshot.usage : nil,
                    color: appearance.color.color,
                    width: appearance.width,
                    usesSingleRingLayout: true
                ),
                innerRing: nil,
                stateSymbol: errorDescription == nil
                    ? nil
                    : "exclamationmark.triangle.fill",
                stateRole: errorDescription == nil ? .neutral : .danger,
                animatesChanges: animatesChanges
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Storage usage")
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("dock.storage")
        }
    }

    private var accessibilityValue: String {
        guard snapshot.totalBytes > 0 else {
            if let errorDescription {
                return "Unavailable, \(errorDescription)"
            }
            return "Loading"
        }

        var value = "\(snapshot.usage.formatted(.percent.precision(.fractionLength(0)))) used, \(MetricsFormatting.byteCount(snapshot.availableBytes)) available on \(snapshot.volumeName)"
        if let errorDescription {
            value += ", last update error: \(errorDescription)"
        }
        return value
    }
}
