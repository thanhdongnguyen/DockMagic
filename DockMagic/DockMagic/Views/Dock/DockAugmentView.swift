import SwiftUI

struct DockAugmentView: View {
    let state: AugmentUsageState
    let appearance: AugmentDockAppearance
    @Environment(\.designTheme) private var theme
    private var latest: AugmentDailyBucket? { state.snapshot?.latest }

    var body: some View {
        DockTileSurface { side in
            VStack(spacing: side * 0.025) {
                ForEach(AugmentPresentation.dockMetrics(appearance)) { metric in
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: side * 0.035) {
                            Text(metric == .input ? "IN" : metric == .output ? "OUT" : "USD")
                                .dsFont(size: side * 0.095, weight: .semibold)
                            Text(AugmentFormatting.value(latest?.metrics.value(metric), metric: metric, compact: true))
                                .dsFont(size: side * (appearance.displayStyle == .chart ? 0.19 : 0.24), weight: .bold)
                                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if appearance.displayStyle == .chart {
                            AugmentDockSparkline(values: AugmentPresentation.trend(state.snapshot, metric: metric), appearance: appearance)
                                .frame(height: side * (appearance.metric == .tokens ? 0.12 : 0.30))
                        }
                    }
                }
                HStack(spacing: side * 0.025) {
                    if state.isRefreshing { DSIcon(systemName: "hourglass") }
                    else if state.observation == .stale { DSIcon(systemName: "clock") }
                    else if state.snapshot?.isPartial == true { Text("*") }
                    Text(latest.map { AugmentPresentation.dateLabel($0.date) + " UTC" } ?? "AUGMENT")
                        .lineLimit(1).minimumScaleFactor(0.6)
                }.dsFont(size: side * 0.085, weight: .medium)
            }.foregroundStyle(theme.dockForeground).padding(.horizontal, side * 0.12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Augment organization analytics")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.augment")
        .help(accessibilityValue)
    }
    private var accessibilityValue: String {
        let values = AugmentPresentation.dockMetrics(appearance).map {
            "\($0.title): \(AugmentFormatting.value(latest?.metrics.value($0), metric: $0)) \($0.unit)"
        }.joined(separator: "; ")
        let date = latest.map { AugmentUTC.string($0.date) + " UTC" } ?? "No reported date"
        let fetched = state.snapshot.map { ". Checked \($0.fetchedAt.formatted())" } ?? ""
        return "\(date). \(values). \(state.label)\(fetched)"
    }
}

private struct AugmentDockSparkline: View {
    let values: [Decimal?]
    let appearance: AugmentDockAppearance
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Canvas { context, size in
            let samples = values.map { $0.map { NSDecimalNumber(decimal: $0).doubleValue } }
            let maximum = max(1, samples.compactMap { $0 }.max() ?? 1)
            let minimum = min(0, samples.compactMap { $0 }.min() ?? 0)
            let width = max(0.7, min(4, max(1, appearance.lineWidth)) * size.width / 64) * (contrast == .increased ? 1.3 : 1)
            var segment: [CGPoint] = []
            func draw() {
                guard let first = segment.first else { return }
                if segment.count == 1 {
                    context.fill(Path(ellipseIn: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width)), with: .color(appearance.color.color))
                } else {
                    var path = Path(); path.addLines(segment)
                    context.stroke(path, with: .color(appearance.color.color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
                segment.removeAll()
            }
            for (index, sample) in samples.enumerated() {
                guard let sample else { draw(); continue }
                segment.append(CGPoint(x: width + CGFloat(index) / CGFloat(max(1, samples.count - 1)) * max(0, size.width - 2 * width),
                    y: width + CGFloat((maximum - sample) / (maximum - minimum)) * max(0, size.height - 2 * width)))
            }
            draw()
        }.accessibilityHidden(true)
    }
}
