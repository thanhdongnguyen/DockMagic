import SwiftUI

@MainActor
struct DockOpenCodeView: View {
    let state: OpenCodeUsageState
    let appearance: OpenCodeDockAppearance
    var now: Date = .now
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dsAccessibilityOverrides) private var overrides

    var body: some View {
        DockTileSurface { side in
            VStack(spacing: 0) {
                HStack(spacing: 1) {
                    Text(OpenCodePresentation.compact(state.snapshot?.day(now)?.tokens.total))
                        .dsFont(size: side * 0.36, weight: .bold)
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    if state.isStale || state.snapshot?.isPartial == true {
                        Text(state.isStale ? "◷" : "*")
                            .dsFont(size: side * 0.13, weight: .bold)
                    }
                }
                .foregroundStyle(state.snapshot?.day(now)?.tokens.total == nil ? theme.dockForeground : resolvedTokenColor)
                .frame(height: side * 0.46)
                if state.snapshot != nil {
                    areaChart.frame(height: side * 0.29)
                } else {
                    DSIcon(systemName: state.isRefreshing ? "hourglass" : "minus.circle")
                        .dsFont(size: side * 0.20).foregroundStyle(theme.dockForeground)
                        .frame(height: side * 0.34)
                }
            }
            .padding(.horizontal, side * 0.10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("OpenCode local token history")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.openCode")
    }

    private var samples: [Int64?] {
        guard let snapshot = state.snapshot else { return Array(repeating: nil, count: 7) }
        return snapshot.trailingDays(7, now: now).map { snapshot.day($0)?.tokens.total }
    }
    private var resolvedChartColor: Color {
        ProjectTheme.readableRendererColor(
            appearance.chartColor,
            on: theme.dockBackgroundRaised,
            colorScheme: colorScheme,
            minimumContrast: 3
        ).color
    }
    private var resolvedTokenColor: Color {
        ProjectTheme.readableRendererColor(
            appearance.tokenColor,
            on: theme.dockBackgroundRaised,
            colorScheme: colorScheme,
            minimumContrast: 4.5
        ).color
    }
    private var areaChart: some View {
        Canvas { context, size in
            let peak = max(1, samples.compactMap { $0 }.max() ?? 1)
            let lineWidth = max(0.8, min(4, appearance.lineWidth) * size.width / 64)
            let baseline = size.height - lineWidth
            let chartColor = resolvedChartColor
            let usesOpaqueArea = overrides.reduceTransparency ?? reduceTransparency
            let increasedContrast = overrides.increaseContrast ?? (contrast == .increased)
            var segment: [CGPoint] = []
            func draw(_ points: [CGPoint]) {
                guard let first = points.first, let last = points.last else { return }
                if points.count == 1 {
                    context.fill(Path(ellipseIn: CGRect(x: first.x - lineWidth, y: first.y - lineWidth,
                        width: lineWidth * 2, height: lineWidth * 2)), with: .color(chartColor))
                    return
                }
                var line = Path(); line.addLines(points)
                var area = line
                area.addLine(to: CGPoint(x: last.x, y: baseline))
                area.addLine(to: CGPoint(x: first.x, y: baseline)); area.closeSubpath()
                context.fill(area, with: .color(chartColor.opacity(usesOpaqueArea ? 1 : 0.35)))
                context.stroke(line, with: .color(chartColor), style: StrokeStyle(lineWidth: increasedContrast ? lineWidth * 1.4 : lineWidth, lineCap: .round, lineJoin: .round))
            }
            for (index, value) in samples.enumerated() {
                guard let value else { draw(segment); segment = []; continue }
                let x = lineWidth + CGFloat(index) / 6 * max(0, size.width - lineWidth * 2)
                let y = baseline - CGFloat(Double(value) / Double(peak)) * max(1, baseline - lineWidth)
                segment.append(CGPoint(x: x, y: y))
            }
            draw(segment)
        }
        .accessibilityHidden(true)
    }
    private var accessibilityValue: String {
        guard let snapshot = state.snapshot else { return state.label }
        let points = snapshot.trailingDays(7, now: now).map { day in
            "\(day.formatted(date: .abbreviated, time: .omitted)): \(snapshot.day(day)?.tokens.total.map { $0.formatted() } ?? "not observed")"
        }.joined(separator: "; ")
        return "Today: \(snapshot.day(now)?.tokens.total.map { $0.formatted() } ?? "unavailable") tokens. \(state.label). Updated \(snapshot.readAt.formatted()). Seven days: \(points). \(OpenCodeUsageSnapshot.coverageNote)"
    }
}
