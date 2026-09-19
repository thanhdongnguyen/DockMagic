import Foundation
import SwiftUI

struct DockGitHubView: View {
    let history: [GitHubRepositorySnapshot]
    let appearance: DockGitHubAppearance
    let errorDescription: String?

    @ViewBuilder
    var body: some View {
        if appearance.displayStyle == .numeric {
            GitHubNumericTile(
                snapshot: history.last,
                appearance: appearance,
                errorDescription: errorDescription
            )
        } else {
            GitHubLineChartTile(
                history: history,
                appearance: appearance,
                errorDescription: errorDescription
            )
        }
    }
}

private struct GitHubLineChartTile: View {
    let history: [GitHubRepositorySnapshot]
    let appearance: DockGitHubAppearance
    let errorDescription: String?

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        DockTileSurface { side in
            ZStack {
                if history.isEmpty {
                    emptyState(side: side)
                } else {
                    chart(side: side)
                    legend(side: side)
                }

                if errorDescription != nil {
                    DSIcon(systemName: "exclamationmark.triangle.fill")
                        .dsFont(size: max(8, side * 0.11), weight: .bold)
                        .foregroundStyle(theme.dangerForeground)
                        .padding(max(3, side * 0.032))
                        .background(Circle().fill(theme.dockBackgroundInset.opacity(0.94)))
                        .position(x: side * 0.86, y: side * 0.16)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: side, height: side)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GitHub repository activity")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.github")
    }

    private func chart(side: CGFloat) -> some View {
        Canvas { context, size in
            let plot = CGRect(
                x: side * 0.10,
                y: side * 0.23,
                width: size.width - side * 0.20,
                height: size.height - side * 0.35
            )

            drawGrid(plot: plot, side: side, context: &context)
            drawSeries(
                history.map(\.stars),
                color: appearance.starColor.color,
                plot: plot,
                side: side,
                context: &context
            )
            drawSeries(
                history.map(\.forks),
                color: appearance.forkColor.color,
                plot: plot,
                side: side,
                context: &context
            )
        }
        .frame(width: side, height: side)
    }

    private func drawGrid(
        plot: CGRect,
        side: CGFloat,
        context: inout GraphicsContext
    ) {
        for fraction in [0.25, 0.5, 0.75] {
            let y = plot.minY + plot.height * fraction
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(
                line,
                with: .color(
                    theme.dockOutline.opacity(contrast == .increased ? 0.42 : 0.15)
                ),
                style: StrokeStyle(
                    lineWidth: max(0.75, side * 0.007),
                    dash: [side * 0.025, side * 0.035]
                )
            )
        }
    }

    private func drawSeries(
        _ values: [Int],
        color: Color,
        plot: CGRect,
        side: CGFloat,
        context: inout GraphicsContext
    ) {
        guard !values.isEmpty else {
            return
        }

        let minimum = values.min() ?? 0
        let maximum = values.max() ?? minimum
        let range = max(maximum - minimum, 1)
        let count = max(values.count - 1, 1)
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: plot.minX + plot.width * CGFloat(index) / CGFloat(count),
                y: plot.maxY
                    - plot.height * CGFloat(value - minimum) / CGFloat(range)
            )
        }
        guard let first = points.first, let last = points.last else {
            return
        }

        var area = Path()
        area.move(to: CGPoint(x: first.x, y: plot.maxY))
        area.addLine(to: first)
        for point in points.dropFirst() {
            area.addLine(to: point)
        }
        area.addLine(to: CGPoint(x: last.x, y: plot.maxY))
        area.closeSubpath()
        context.fill(
            area,
            with: .color(color.opacity(0.12))
        )

        var line = Path()
        line.move(to: first)
        for point in points.dropFirst() {
            line.addLine(to: point)
        }
        context.stroke(
            line,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: max(1.5, side * 0.019),
                lineCap: .round,
                lineJoin: .round
            )
        )

        let marker = Path(
            ellipseIn: CGRect(
                x: last.x - side * 0.025,
                y: last.y - side * 0.025,
                width: side * 0.05,
                height: side * 0.05
            )
        )
        context.fill(marker, with: .color(theme.dockBackgroundRaised))
        context.stroke(
            marker,
            with: .color(color),
            lineWidth: max(1.5, side * 0.014)
        )
    }

    private func legend(side: CGFloat) -> some View {
        HStack(spacing: side * 0.08) {
            DSIcon(systemName: "star.fill")
                .foregroundStyle(appearance.starColor.color)
            DSIcon(systemName: "arrow.triangle.branch")
                .foregroundStyle(appearance.forkColor.color)
        }
        .dsFont(size: max(7, side * 0.085), weight: .bold)
        .padding(.horizontal, side * 0.065)
        .padding(.vertical, side * 0.032)
        .background(Capsule().fill(theme.dockBackgroundInset.opacity(0.78)))
        .position(x: side * 0.28, y: side * 0.14)
        .accessibilityHidden(true)
    }

    private func emptyState(side: CGFloat) -> some View {
        VStack(spacing: side * 0.06) {
            DSIcon(systemName: "point.3.connected.trianglepath.dotted")
                .dsFont(size: max(12, side * 0.28), weight: .medium)
                .foregroundStyle(theme.dockOutline.opacity(0.78))

            Text("—")
                .dsFont(size: max(10, side * 0.18), weight: .bold)
                .foregroundStyle(theme.dockOutline)
        }
    }

    private var accessibilityValue: String {
        guard let snapshot = history.last else {
            return errorDescription.map { "Unavailable, \($0)" }
                ?? "Waiting for a repository"
        }
        var value = "\(snapshot.repository), \(snapshot.stars) stars, \(snapshot.forks) forks"
        if let errorDescription {
            value += ", last update error: \(errorDescription)"
        }
        return value
    }
}

private struct GitHubNumericTile: View {
    let snapshot: GitHubRepositorySnapshot?
    let appearance: DockGitHubAppearance
    let errorDescription: String?

    @Environment(\.designTheme) private var theme

    var body: some View {
        DockTileSurface { side in
            VStack(spacing: max(2, side * 0.04)) {
                metricRow(
                    systemImage: "star.fill",
                    value: snapshot.map { GitHubCountFormatting.compact($0.stars) } ?? "—",
                    color: appearance.starColor.color,
                    side: side
                )

                metricRow(
                    systemImage: "arrow.triangle.branch",
                    value: snapshot.map { GitHubCountFormatting.compact($0.forks) } ?? "—",
                    color: appearance.forkColor.color,
                    side: side
                )
            }
            .padding(.horizontal, side * 0.03)
            .overlay(alignment: .topTrailing) {
                if errorDescription != nil {
                    DSIcon(systemName: "exclamationmark.triangle.fill")
                        .dsFont(size: max(7, side * 0.09), weight: .bold)
                        .foregroundStyle(theme.dangerForeground)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, side * 0.06)
            .padding(.horizontal, side * 0.04)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GitHub repository counts")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.github")
    }

    private func metricRow(
        systemImage: String,
        value: String,
        color: Color,
        side: CGFloat
    ) -> some View {
        HStack(spacing: side * 0.045) {
            DSIcon(systemName: systemImage)
                .dsFont(size: max(9, side * 0.18), weight: .bold)
                .foregroundStyle(color)
                .frame(width: side * 0.20)

            Text(value)
                .dsFont(size: max(12, side * 0.28), weight: .bold)
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .lineLimit(1)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
    }

    private var accessibilityValue: String {
        guard let snapshot else {
            return errorDescription.map { "Unavailable, \($0)" }
                ?? "Waiting for a repository"
        }
        var value = "\(snapshot.repository), \(snapshot.stars) stars, \(snapshot.forks) forks"
        if let errorDescription {
            value += ", last update error: \(errorDescription)"
        }
        return value
    }
}

enum GitHubCountFormatting {
    static func compact(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            compact(value, divisor: 1_000_000, suffix: "M")
        case 1_000...:
            compact(value, divisor: 1_000, suffix: "K")
        default:
            value.formatted()
        }
    }

    private static func compact(
        _ value: Int,
        divisor: Double,
        suffix: String
    ) -> String {
        let scaled = Double(value) / divisor
        let precision = scaled >= 100 ? 0 : 1
        if precision == 0 {
            return "\(Int(scaled.rounded()))\(suffix)"
        }
        let rounded = (scaled * 10).rounded(.toNearestOrAwayFromZero) / 10
        return String(
            format: "%.1f%@",
            locale: Locale(identifier: "en_US_POSIX"),
            rounded,
            suffix
        )
    }
}

#Preview("GitHub line chart") {
    DockMagicThemeRoot(
        content: DockGitHubView(
            history: GitHubRepositorySnapshot.designPreviewHistory,
            appearance: DockFeatureDefaults.githubAppearance,
            errorDescription: nil
        )
        .frame(width: 160, height: 160)
    )
}

#Preview("GitHub numbers") {
    var appearance = DockFeatureDefaults.githubAppearance
    appearance.setDisplayStyle(.numeric)
    return DockMagicThemeRoot(
        content: DockGitHubView(
            history: GitHubRepositorySnapshot.designPreviewHistory,
            appearance: appearance,
            errorDescription: nil
        )
        .frame(width: 160, height: 160)
    )
}
