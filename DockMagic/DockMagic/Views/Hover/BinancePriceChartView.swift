import Charts
import SwiftUI

@MainActor
struct BinancePriceChartView: View {
    let candles: [BinanceCandle]
    let type: BinanceChartType
    let range: BinanceTimeRange
    let showsVolume: Bool
    let compact: Bool
    var appearance: BinanceAppearance = .standard
    @State private var hoveredDate: Date?
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var selected: BinanceCandle? {
        guard let hoveredDate else { return nil }
        return candles.min { abs($0.openTime.timeIntervalSince(hoveredDate)) < abs($1.openTime.timeIntervalSince(hoveredDate)) }
    }
    private var yDomain: ClosedRange<Double> {
        let low = candles.map { value(type == .line ? $0.close : $0.low) }.min() ?? 0
        let high = candles.map { value(type == .line ? $0.close : $0.high) }.max() ?? 1
        let padding = high == 0 ? 1 : max((high - low) * 0.12, abs(high) * 0.0001)
        return max(0, low - padding)...(high + padding)
    }
    private var xDomain: ClosedRange<Date> {
        let last = candles.last?.openTime ?? Date()
        let first = candles.first?.openTime ?? last.addingTimeInterval(-range.seconds)
        return first...max(last, first.addingTimeInterval(range.candleSeconds))
    }
    var body: some View {
        let priceColor = ProjectTheme.rendererColor(appearance.priceSeriesColor, automatic: theme.marketPriceSeries,
            on: theme.opaqueSurfaceRaised, colorScheme: colorScheme, minimumContrast: 3)
        let volumeColor = ProjectTheme.rendererColor(appearance.volumeColor, automatic: theme.textTertiary,
            on: theme.opaqueSurfaceRaised, colorScheme: colorScheme, minimumContrast: 3)
        return VStack(spacing: 4) {
            Chart {
                ForEach(candles) { candle in
                    if type == .line {
                        LineMark(x: .value("Time", candle.openTime), y: .value("Price", value(candle.close)))
                            .foregroundStyle(priceColor)
                            .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2, lineCap: .round, lineJoin: .round))
                    } else {
                        RuleMark(x: .value("Time", candle.openTime), yStart: .value("Low", value(candle.low)), yEnd: .value("High", value(candle.high)))
                            .foregroundStyle(priceColor)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        RectangleMark(xStart: .value("Body start", candle.openTime.addingTimeInterval(-range.candleSeconds * 0.34)),
                                      xEnd: .value("Body end", candle.openTime.addingTimeInterval(range.candleSeconds * 0.34)),
                                      yStart: .value("Open", value(min(candle.open, candle.close))),
                                      yEnd: .value("Close", max(value(max(candle.open, candle.close)), value(min(candle.open, candle.close)) + bodyMinimum)))
                            .foregroundStyle(priceColor)
                        if candle.rising, value(candle.close - candle.open) > bodyMinimum * 3 {
                            RectangleMark(xStart: .value("Hollow start", candle.openTime.addingTimeInterval(-range.candleSeconds * 0.18)),
                                          xEnd: .value("Hollow end", candle.openTime.addingTimeInterval(range.candleSeconds * 0.18)),
                                          yStart: .value("Open", value(candle.open) + bodyMinimum),
                                          yEnd: .value("Close", value(candle.close) - bodyMinimum))
                                .foregroundStyle(theme.opaqueSurfaceRaised)
                        }
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected", selected.openTime))
                        .foregroundStyle(theme.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    PointMark(x: .value("Time", selected.openTime), y: .value("Close", value(selected.close)))
                        .foregroundStyle(priceColor).symbolSize(20)
                }
            }
            .chartYScale(domain: yDomain)
            .chartXScale(domain: xDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: compact ? 3 : 4)) { axis in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(theme.outlineStrong)
                    AxisValueLabel {
                        if let number = axis.as(Double.self) {
                            Text(BinancePriceFormat.price(Decimal(number), compact: true))
                                .dsFont(size: 10).foregroundStyle(theme.textSecondary)
                                .frame(width: axisLabelWidth, alignment: .trailing)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { axis in
                    AxisValueLabel(anchor: axis.index == 0 ? .topLeading : axis.index == axis.count - 1 ? .topTrailing : .top) {
                        if let date = axis.as(Date.self) {
                            Text(date.formatted(range == .hour || range == .day ? .dateTime.hour().minute() : .dateTime.month(.abbreviated).day()))
                                .dsFont(size: 10).foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
            .chartOverlay { chart in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let point):
                                guard let frame = chart.plotFrame else { return }
                                let plot = geometry[frame]
                                hoveredDate = plot.contains(point) ? chart.value(atX: point.x - plot.minX) : nil
                            case .ended: hoveredDate = nil
                            }
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if let selected { tooltip(selected).allowsHitTesting(false) }
            }
            if showsVolume {
                Chart(candles) { candle in
                    BarMark(xStart: .value("Start", candle.openTime.addingTimeInterval(-range.candleSeconds * 0.38)),
                            xEnd: .value("End", candle.openTime.addingTimeInterval(range.candleSeconds * 0.38)),
                            y: .value("Base volume", value(candle.volume)))
                        .foregroundStyle(volumeColor)
                }
                .chartXScale(domain: xDomain).chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0]) { _ in
                        AxisValueLabel { Color.clear.frame(width: axisLabelWidth, height: 1) }
                    }
                }
                .frame(height: 28)
                .accessibilityLabel("Base asset volume")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(type.title) price chart, \(range.rawValue)")
        .accessibilityValue(candles.last.map { "Latest close \(BinancePriceFormat.price($0.close)). \(candles.count) candles. " + (type == .candlestick ? "Hollow candles rise; filled candles fall." : "") } ?? "No chart data")
    }
    private var axisLabelWidth: CGFloat { compact ? 30 : 40 }
    private var bodyMinimum: Double { (yDomain.upperBound - yDomain.lowerBound) / 250 }
    private func value(_ decimal: Decimal) -> Double { NSDecimalNumber(decimal: decimal).doubleValue }
    private func tooltip(_ candle: BinanceCandle) -> some View {
        DSChartTooltip {
            Text(candle.openTime.formatted(.dateTime.month(.abbreviated).day().hour().minute().timeZone()))
            if type == .line { Text("Close \(BinancePriceFormat.price(candle.close))") }
            else {
                Text("O \(BinancePriceFormat.price(candle.open)) · H \(BinancePriceFormat.price(candle.high))")
                Text("L \(BinancePriceFormat.price(candle.low)) · C \(BinancePriceFormat.price(candle.close))")
            }
            if showsVolume { Text("Volume \(BinancePriceFormat.price(candle.volume, compact: true))") }
        }
        .dsFont(size: 10, weight: .medium).monospacedDigit()
        .foregroundStyle(theme.textPrimary)
        .padding(.leading, compact ? 36 : 44)
    }
}
