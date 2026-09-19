import SwiftUI

struct DockNetworkView: View {
    let history: [NetworkMetricsSnapshot]
    let appearance: DockNetworkAppearance
    let errorDescription: String?

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    private let windowSize = 30

    var body: some View {
        DockTileSurface { side in
            ZStack {
                networkChart(side: side)

                if samples.allSatisfy({
                    $0.downloadBytesPerSecond == 0 && $0.uploadBytesPerSecond == 0
                }) {
                    DSIcon(systemName: "arrow.up.arrow.down")
                        .dsFont(size: max(8, side * 0.13), weight: .bold)
                        .foregroundStyle(theme.dockOutline.opacity(0.82))
                        .accessibilityHidden(true)
                }

                if errorDescription != nil {
                    DSIcon(systemName: "exclamationmark.triangle.fill")
                        .dsFont(size: max(8, side * 0.12), weight: .bold)
                        .foregroundStyle(theme.danger)
                        .padding(max(3, side * 0.035))
                        .background {
                            Circle().fill(theme.dockBackgroundInset.opacity(0.92))
                        }
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Network throughput")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.network")
    }

    private var samples: [NetworkMetricsSnapshot] {
        Array(history.suffix(windowSize))
    }

    private func networkChart(side: CGFloat) -> some View {
        Canvas { context, size in
            let inset = max(3, side * 0.09)
            let plot = CGRect(
                x: inset,
                y: side * 0.12,
                width: max(1, size.width - inset * 2),
                height: max(1, size.height - side * 0.24)
            )
            let baselineY = plot.midY
            let halfHeight = max(1, plot.height / 2 - side * 0.035)
            let ceiling = NetworkChartScale.ceiling(for: samples)

            var baseline = Path()
            baseline.move(to: CGPoint(x: plot.minX, y: baselineY))
            baseline.addLine(to: CGPoint(x: plot.maxX, y: baselineY))
            context.stroke(
                baseline,
                with: .color(theme.dockOutline.opacity(contrast == .increased ? 0.9 : 0.58)),
                lineWidth: max(1, side * 0.012)
            )

            drawSeries(
                samples.map(\.uploadBytesPerSecond),
                direction: -1,
                color: appearance.uploadColor.color,
                ceiling: ceiling,
                plot: plot,
                baselineY: baselineY,
                halfHeight: halfHeight,
                side: side,
                context: &context
            )
            drawSeries(
                samples.map(\.downloadBytesPerSecond),
                direction: 1,
                color: appearance.downloadColor.color,
                ceiling: ceiling,
                plot: plot,
                baselineY: baselineY,
                halfHeight: halfHeight,
                side: side,
                context: &context
            )
        }
        .frame(width: side, height: side)
    }

    private func drawSeries(
        _ values: [Double],
        direction: CGFloat,
        color: Color,
        ceiling: Double,
        plot: CGRect,
        baselineY: CGFloat,
        halfHeight: CGFloat,
        side: CGFloat,
        context: inout GraphicsContext
    ) {
        guard !values.isEmpty else {
            return
        }

        let slots = max(windowSize - 1, 1)
        let leadingEmptySlots = windowSize - values.count
        var points: [CGPoint] = []
        points.reserveCapacity(values.count)

        for (index, value) in values.enumerated() {
            let slot = leadingEmptySlots + index
            let x = plot.minX + plot.width * CGFloat(slot) / CGFloat(slots)
            let normalized = min(max(value / ceiling, 0), 1)
            let y = baselineY + direction * halfHeight * CGFloat(normalized)
            points.append(CGPoint(x: x, y: y))
        }

        guard let first = points.first, let last = points.last else {
            return
        }

        var area = Path()
        area.move(to: CGPoint(x: first.x, y: baselineY))
        area.addLine(to: first)
        for point in points.dropFirst() {
            area.addLine(to: point)
        }
        area.addLine(to: CGPoint(x: last.x, y: baselineY))
        area.closeSubpath()
        context.fill(area, with: .color(color.opacity(contrast == .increased ? 0.42 : 0.28)))

        var line = Path()
        line.move(to: first)
        for point in points.dropFirst() {
            line.addLine(to: point)
        }
        context.stroke(
            line,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: max(1.25, side * 0.018),
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private var accessibilityValue: String {
        guard let current = history.last else {
            if let errorDescription {
                return "Unavailable, \(errorDescription)"
            }
            return "Loading"
        }

        var value = "Download \(MetricsFormatting.byteRate(current.downloadBytesPerSecond)), upload \(MetricsFormatting.byteRate(current.uploadBytesPerSecond))"
        if let interfaceName = current.interfaceName {
            value += ", interface \(interfaceName)"
        }
        if let errorDescription {
            value += ", last update error: \(errorDescription)"
        }
        return value
    }
}
