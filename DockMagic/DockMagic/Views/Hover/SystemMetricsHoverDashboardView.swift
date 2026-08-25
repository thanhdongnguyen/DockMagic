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
            Image(systemName: "gauge.with.dots.needle.50percent")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .accessibilityHidden(true)

            Text("CPU & RAM")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            DashboardMetricLabel(
                title: "CPU",
                value: Self.percentageLabel(current.cpuUsage),
                color: appearance.outerColor.color
            )
            DashboardMetricLabel(
                title: "RAM",
                value: Self.percentageLabel(current.memoryUsage),
                color: appearance.innerColor.color
            )

            if let errorDescription = systemErrorDescription
                ?? processErrorDescription {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 11, weight: .semibold))
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

private struct DashboardMetricLabel: View {
    let title: String
    let value: String
    let color: Color

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 13, height: 3)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
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
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 4)

                Text("TOP 10")
                    .font(.system(size: 8, weight: .bold))
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
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(width: 14, alignment: .trailing)

            Text(row.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Text(value(row))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
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
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.small)
            Text("Measuring CPU activity…")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .accessibilityHidden(true)
            Text(emptyMessage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct SystemMetricsHistoryCard: View {
    let history: [SystemMetricsSnapshot]
    let appearance: DockRingAppearance

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("Realtime usage")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("LAST 60 SECONDS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textTertiary)

                Spacer(minLength: 4)

                ChartSeriesLegend(
                    title: "CPU",
                    color: appearance.outerColor.color,
                    isDashed: false
                )
                ChartSeriesLegend(
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

private struct ChartSeriesLegend: View {
    let title: String
    let color: Color
    let isDashed: Bool

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Capsule()
                .trim(from: isDashed ? 0 : 0, to: isDashed ? 0.42 : 1)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 14, height: 4)
                .overlay(alignment: .trailing) {
                    if isDashed {
                        Capsule()
                            .fill(color)
                            .frame(width: 5, height: 2)
                    }
                }
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isDashed ? "dashed" : "solid") line")
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
                    .font(.system(size: 9.5, weight: .medium))
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
