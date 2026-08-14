import SwiftUI

struct DockSearchConsoleView: View {
    let state: SearchConsoleState
    let configuration: SearchConsoleConfiguration

    static let clicksColor = Color(red: 0.20, green: 0.79, blue: 0.96)
    static let impressionsColor = Color(red: 0.64, green: 0.36, blue: 1.00)

    var body: some View {
        Group {
            if let snapshot = state.snapshot {
                switch configuration.displayMode {
                case .chart:
                    chart(snapshot)
                case .numbers:
                    numbers(snapshot)
                case .focus:
                    focus(snapshot)
                }
            } else {
                empty
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Google Search Console performance")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.searchConsole")
    }

    private func focus(_ snapshot: SearchConsoleSnapshot) -> some View {
        DockTileSurface { side in
            let primary = configuration.primaryMetric
            let secondary: SearchConsoleMetric = primary == .clicks
                ? .impressions
                : .clicks

            VStack(alignment: .center, spacing: 0) {
                Text(SearchConsoleCountFormatting.compact(snapshot.total(for: primary)))
                    .font(.system(size: side * 0.31, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .foregroundStyle(color(for: primary))
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(primary.title.uppercased())
                    .font(.system(size: side * 0.075, weight: .bold, design: .rounded))
                    .tracking(side * 0.004)
                    .foregroundStyle(Color.white.opacity(0.62))

                SearchConsoleSparkline(
                    values: snapshot.points.map { $0.value(for: secondary) },
                    color: color(for: secondary),
                    lineWidth: side * 0.018,
                    showsFill: true
                )
                .frame(height: side * 0.24)
                .padding(.top, side * 0.045)

                (
                    Text(SearchConsoleCountFormatting.compact(snapshot.total(for: secondary)))
                        .foregroundStyle(color(for: secondary))
                    + Text(" \(secondary.title.lowercased())")
                        .foregroundStyle(Color.white.opacity(0.58))
                )
                .font(.system(size: side * 0.075, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, side * 0.025)
            }
            .padding(.horizontal, side * 0.10)
            .padding(.vertical, side * 0.095)
            .frame(width: side, height: side, alignment: .top)
            .overlay(alignment: .topTrailing) { statusIcon(side: side) }
        }
    }

    private func numbers(_ snapshot: SearchConsoleSnapshot) -> some View {
        DockTileSurface { side in
            VStack(alignment: .leading, spacing: side * 0.09) {
                numberRow(.clicks, snapshot: snapshot, side: side)
                numberRow(.impressions, snapshot: snapshot, side: side)
            }
            .padding(.horizontal, side * 0.105)
            .frame(width: side, height: side, alignment: .center)
            .overlay(alignment: .topTrailing) { statusIcon(side: side) }
        }
    }

    private func numberRow(
        _ metric: SearchConsoleMetric,
        snapshot: SearchConsoleSnapshot,
        side: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: side * 0.012) {
            Text(SearchConsoleCountFormatting.compact(snapshot.total(for: metric)))
                .font(.system(size: side * 0.24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color(for: metric))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(metric.title.uppercased())
                .font(.system(size: side * 0.061, weight: .bold, design: .rounded))
                .tracking(side * 0.003)
                .foregroundStyle(Color.white.opacity(0.58))
        }
    }

    private func chart(_ snapshot: SearchConsoleSnapshot) -> some View {
        DockTileSurface { side in
            VStack(spacing: side * 0.045) {
                ZStack {
                    SearchConsoleSparkline(
                        values: snapshot.points.map(\.impressions),
                        color: Self.impressionsColor,
                        lineWidth: side * 0.018,
                        showsFill: true
                    )
                    SearchConsoleSparkline(
                        values: snapshot.points.map(\.clicks),
                        color: Self.clicksColor,
                        lineWidth: side * 0.018
                    )
                }

                HStack(spacing: side * 0.08) {
                    chartLegend(.clicks, snapshot: snapshot, side: side)
                    chartLegend(.impressions, snapshot: snapshot, side: side)
                }
            }
            .padding(.horizontal, side * 0.10)
            .padding(.top, side * 0.16)
            .padding(.bottom, side * 0.09)
            .frame(width: side, height: side)
            .overlay(alignment: .topTrailing) { statusIcon(side: side) }
        }
    }

    private func chartLegend(
        _ metric: SearchConsoleMetric,
        snapshot: SearchConsoleSnapshot,
        side: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(SearchConsoleCountFormatting.compact(snapshot.total(for: metric)))
                .font(.system(size: side * 0.115, weight: .bold, design: .rounded))
                .foregroundStyle(color(for: metric))
                .lineLimit(1)
            Text(metric.title.uppercased())
                .font(.system(size: side * 0.052, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var empty: some View {
        DockTileSurface { side in
            VStack(spacing: side * 0.075) {
                Image(systemName: configuration.isConnected ? "arrow.triangle.2.circlepath" : "chart.xyaxis.line")
                    .font(.system(size: side * 0.24, weight: .semibold))
                    .foregroundStyle(Self.clicksColor)
                Text(configuration.isConnected ? "Loading" : "Connect")
                    .font(.system(size: side * 0.095, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private func statusIcon(side: CGFloat) -> some View {
        if state.errorDescription != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: side * 0.07, weight: .bold))
                .foregroundStyle(Color.orange)
                .padding(side * 0.075)
                .accessibilityHidden(true)
        }
    }

    private func color(for metric: SearchConsoleMetric) -> Color {
        metric == .clicks ? Self.clicksColor : Self.impressionsColor
    }

    private var accessibilityValue: String {
        guard let snapshot = state.snapshot else {
            return configuration.isConnected ? "Loading" : "Not connected"
        }
        var value = "\(SearchConsoleCountFormatting.full(snapshot.clicks)) clicks, \(SearchConsoleCountFormatting.full(snapshot.impressions)) impressions"
        if let error = state.errorDescription { value += ", last update error: \(error)" }
        return value
    }
}

private struct SearchConsoleSparkline: View {
    let values: [Double]
    let color: Color
    let lineWidth: CGFloat
    var showsFill = false

    var body: some View {
        Canvas { context, size in
            let points = normalizedPoints(in: size)
            guard let first = points.first, let last = points.last else { return }

            if showsFill {
                var fill = Path()
                fill.move(to: CGPoint(x: first.x, y: size.height))
                fill.addLine(to: first)
                for point in points.dropFirst() { fill.addLine(to: point) }
                fill.addLine(to: CGPoint(x: last.x, y: size.height))
                fill.closeSubpath()
                context.fill(
                    fill,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.28), color.opacity(0.01)]),
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    )
                )
            }

            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1.4, lineWidth), lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? minimum
        let range = max(maximum - minimum, 1)
        let divisor = max(values.count - 1, 1)
        return values.enumerated().map { index, value in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(divisor),
                y: size.height * (1 - CGFloat((value - minimum) / range) * 0.78) - size.height * 0.11
            )
        }
    }
}
