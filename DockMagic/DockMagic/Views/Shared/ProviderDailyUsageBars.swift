import SwiftUI

struct ProviderDailyUsageChartBucket: Identifiable, Equatable, Sendable {
    let startDate: Date
    let value: Double
    let accessibilityValue: String
    var isAvailable = true

    var id: Date { startDate }
}

struct ProviderDailyUsageBars: View {
    let buckets: [ProviderDailyUsageChartBucket]
    let metric: String
    let accent: Color
    let providerID: String
    let hasData: Bool

    private let plotHeight: CGFloat = 88
    private let columnWidth: CGFloat = 46
    private let columnSpacing: CGFloat = 8
    private let viewportHeight: CGFloat = 132
    @State private var hoveredDate: Date?

    var body: some View {
        AIUsageHistoryChart(
            points: buckets.map { bucket in
                AIUsageHistoryPoint(
                    date: bucket.startDate,
                    value: bucket.isAvailable ? Decimal(bucket.value) : nil,
                    accessibilityValue: bucket.accessibilityValue
                )
            },
            hoveredDate: $hoveredDate,
            plotHeight: plotHeight,
            footerSpace: 44,
            metricLabel: metric.lowercased(),
            isSelectionEnabled: false,
            dataColor: accent,
            emptyMessage: hasData
                ? nil
                : "Waiting for real \(metric.lowercased()) data",
            viewportHeight: viewportHeight,
            documentSize: CGSize(
                width: CGFloat(buckets.count) * columnWidth
                    + CGFloat(max(0, buckets.count - 1)) * columnSpacing + 8,
                height: plotHeight + 27
            ),
            formatValue: { value in
                let number = NSDecimalNumber(decimal: value).doubleValue
                if metric == "Cost" {
                    return ClaudeCodeHoverDashboardPresentation.costLabel(number)
                }
                return Int64(number).formatted(
                    .number.notation(.compactName)
                        .precision(.fractionLength(0...1))
                )
            },
            onSelect: { _ in }
        )
        .frame(height: viewportHeight)
        .accessibilityIdentifier("dockHover.\(providerID).usageHistory")
    }
}
