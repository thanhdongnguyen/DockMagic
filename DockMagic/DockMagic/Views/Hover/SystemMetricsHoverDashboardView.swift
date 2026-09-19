import Charts
import SwiftUI

@MainActor
struct SystemMetricsHoverDashboardView: View {
    let current: SystemMetricsSnapshot
    let history: [SystemMetricsSnapshot]
    let processes: ProcessMetricsSnapshot
    let appearance: DockRingAppearance
    let systemErrorDescription: String?
    let processErrorDescription: String?

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            header

            HStack(spacing: 10) {
                ProcessRankingCard(
                    title: "Top CPU",
                    systemImage: "cpu",
                    rows: processes.topCPU,
                    value: { Self.cpuLabel($0.cpuUsage) },
                    isLoading: !processes.isCPUReady,
                    emptyMessage: processErrorDescription
                        ?? "No readable CPU activity"
                )

                ProcessRankingCard(
                    title: "Top RAM",
                    systemImage: "memorychip",
                    rows: processes.topMemory,
                    value: { MetricsFormatting.byteCount($0.memoryBytes) },
                    isLoading: false,
                    emptyMessage: processErrorDescription
                        ?? "No readable memory activity"
                )
            }
            .frame(height: 242)

            SystemMetricsHistoryCard(
                history: history,
                appearance: appearance
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CPU and RAM dashboard")
    }

    private var header: some View {
        HStack(spacing: 9) {
            DSIcon(systemName: "gauge.with.dots.needle.50percent")
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 17, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .accessibilityHidden(true)

            Text("CPU & RAM")
                .dsFont(size: 17, weight: .bold)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            DSMetricInline(
                title: "CPU",
                value: Self.percentageLabel(current.cpuUsage),
                seriesColor: appearance.outerColor.color
            )
            DSMetricInline(
                title: "RAM",
                value: Self.percentageLabel(current.memoryUsage),
                seriesColor: appearance.innerColor.color
            )

            if let errorDescription = systemErrorDescription
                ?? processErrorDescription {
                DSIcon(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 11, weight: .semibold)
                    .foregroundStyle(theme.dangerForeground)
                    .help(errorDescription)
                    .accessibilityLabel("Last update error")
                    .accessibilityValue(errorDescription)
            }
        }
        .frame(height: 28)
    }

    private static func percentageLabel(_ usage: Double) -> String {
        usage.formatted(
            .percent
                .precision(.fractionLength(0))
        )
    }

    private static func cpuLabel(_ usage: Double) -> String {
        if usage > 0, usage < 0.001 {
            return "<0.1%"
        }
        return usage.formatted(
            .percent
                .precision(.fractionLength(0...1))
        )
    }
}

private struct ProcessRankingCard: View {
    let title: String
    let systemImage: String
    let rows: [ProcessMetricRow]
    let value: (ProcessMetricRow) -> String
    let isLoading: Bool
    let emptyMessage: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                DSIcon(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 10.5, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)

                Text(title)
                    .dsFont(size: 11.5, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 4)

                Text("TOP 10")
                    .dsFont(size: 8, weight: .bold)
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 9)
            .frame(height: 28)

            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            if isLoading {
                loadingState
            } else if rows.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) {
                        index,
                        row in
                        processRow(index: index, row: row)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.opaqueSurfaceInset)
        .clipShape(
            RoundedRectangle(cornerRadius: DSRadius.fixedSmall, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.fixedSmall, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func processRow(index: Int, row: ProcessMetricRow) -> some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .dsFont(size: 8.5, weight: .medium)
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(width: 14, alignment: .trailing)

            Text(row.name)
                .dsFont(size: 10, weight: .medium)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Text(value(row))
                .dsFont(size: 9.5, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .contentShape(Rectangle())
        .help("\(row.name) — PID \(row.id.processID)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(index + 1), \(row.name)")
        .accessibilityValue(value(row))
        .accessibilityIdentifier("dockHover.metrics.\(title).row.\(index + 1)")
    }

    private var loadingState: some View {
        DSLoadingState(title: "Measuring CPU activity…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        DSEmptyState(title: emptyMessage, icon: .chart)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct SystemMetricsHistoryCard: View {
    let history: [SystemMetricsSnapshot]
    let appearance: DockRingAppearance

    @Environment(\.designTheme) private var theme

    var body: some View {
        DSChartFrame {
            HStack(spacing: 8) {
                Text("Realtime usage")
                    .dsFont(size: 11.5, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Text("LAST 60 SECONDS")
                    .dsFont(size: 8, weight: .bold)
                    .foregroundStyle(theme.textTertiary)

                Spacer(minLength: 4)

                DSChartLegend(
                    title: "CPU",
                    color: appearance.outerColor.color,
                    isDashed: false
                )
                DSChartLegend(
                    title: "RAM",
                    color: appearance.innerColor.color,
                    isDashed: true
                )
            }
            .frame(height: 18)

            SystemMetricsHistoryChart(
                history: history,
                appearance: appearance
            )
        }
        .padding(.horizontal, 9)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.opaqueSurfaceInset)
        .clipShape(
            RoundedRectangle(cornerRadius: DSRadius.fixedSmall, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.fixedSmall, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
    }
}

struct SystemMetricsHistoryChart: View {
    let history: [SystemMetricsSnapshot]
    let appearance: DockRingAppearance

    @Environment(\.designTheme) private var theme

    var body: some View {
        ZStack {
            Chart {
                ForEach(history, id: \.timestamp) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("CPU", sample.cpuPercentage),
                        series: .value("Metric", "CPU")
                    )
                    .foregroundStyle(appearance.outerColor.color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.linear)

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("RAM", sample.memoryPercentage),
                        series: .value("Metric", "RAM")
                    )
                    .foregroundStyle(appearance.innerColor.color)
                    .lineStyle(StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        dash: [5, 3]
                    ))
                    .interpolationMethod(.linear)
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine()
                        .foregroundStyle(theme.outline.opacity(0.6))
                    AxisValueLabel {
                        if let percentage = value.as(Int.self) {
                            Text("\(percentage)%")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                        .foregroundStyle(theme.outline.opacity(0.35))
                    AxisValueLabel(format: .dateTime.minute().second())
                }
            }
            .accessibilityLabel("CPU and RAM usage over the last 60 seconds")
            .accessibilityValue(accessibilitySummary)

            if history.count < 2 {
                Text("Collecting realtime history…")
                    .dsFont(size: 9.5, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.opaqueSurfaceInset)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DSRadius.fixedSmall,
                            style: .continuous
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private var accessibilitySummary: String {
        guard let latest = history.last else {
            return "No samples"
        }
        return "Latest CPU \(latest.cpuPercentage.formatted(.number.precision(.fractionLength(0)))) percent, RAM \(latest.memoryPercentage.formatted(.number.precision(.fractionLength(0)))) percent, over \(history.count) samples"
    }
}
