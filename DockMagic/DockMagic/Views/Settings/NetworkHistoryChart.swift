import Charts
import SwiftUI

struct NetworkHistoryChart: View {
    let history: [NetworkMetricsSnapshot]
    let appearance: DockNetworkAppearance

    @Environment(\.designTheme) private var theme

    var body: some View {
        ZStack {
            Chart {
                ForEach(history) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Upload", sample.uploadBytesPerSecond)
                    )
                    .foregroundStyle(appearance.uploadColor.color.opacity(0.16))

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Upload", sample.uploadBytesPerSecond),
                        series: .value("Direction", "Upload")
                    )
                    .foregroundStyle(appearance.uploadColor.color)
                    .interpolationMethod(.linear)

                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        yStart: .value("Baseline", 0),
                        yEnd: .value("Download", -sample.downloadBytesPerSecond)
                    )
                    .foregroundStyle(appearance.downloadColor.color.opacity(0.16))

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Download", -sample.downloadBytesPerSecond),
                        series: .value("Direction", "Download")
                    )
                    .foregroundStyle(appearance.downloadColor.color)
                    .interpolationMethod(.linear)
                }

                RuleMark(y: .value("Baseline", 0))
                    .foregroundStyle(theme.outlineStrong.opacity(0.55))
            }
            .chartLegend(.hidden)
            .chartYScale(domain: -ceiling...ceiling)
            .chartYAxis {
                AxisMarks(values: [-ceiling, 0, ceiling]) { value in
                    AxisGridLine()
                        .foregroundStyle(theme.outline.opacity(0.55))
                    AxisValueLabel {
                        if let rate = value.as(Double.self) {
                            Text(rate == 0 ? "0" : MetricsFormatting.byteRate(abs(rate)))
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
            .accessibilityLabel("Network throughput history")
            .accessibilityValue(accessibilitySummary)

            if history.count < 2 {
                Text("Waiting for network samples")
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textTertiary)
                    .padding(DSSpacing.standard)
                    .background(theme.opaqueSurfaceInset.opacity(0.92))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DSRadius.control,
                            style: .continuous
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 190)
    }

    private var ceiling: Double {
        NetworkChartScale.ceiling(for: history)
    }

    private var accessibilitySummary: String {
        guard let latest = history.last else {
            return "No samples"
        }
        return "Latest download \(MetricsFormatting.byteRate(latest.downloadBytesPerSecond)), latest upload \(MetricsFormatting.byteRate(latest.uploadBytesPerSecond)), over \(history.count) samples"
    }
}
