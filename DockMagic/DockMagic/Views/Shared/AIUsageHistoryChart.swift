import SwiftUI

struct AIUsageHistoryPoint: Identifiable {
    let date: Date
    let value: Decimal?
    var partial = false
    var accessibilityValue: String? = nil
    var id: Date { date }
}

enum AIUsageHistoryChartStyle {
    case bars
    case area
}

/// Shared daily chart input keeps currency exact and missing values absent.
/// Floating-point conversion happens only when calculating drawing coordinates.
@MainActor
struct AIUsageHistoryChart: View {
    let points: [AIUsageHistoryPoint]
    @Binding var hoveredDate: Date?
    let plotHeight: CGFloat
    var footerSpace: CGFloat = 38
    var timezone: TimeZone = .current
    var metricLabel = "tokens"
    var allowsZeroSelection = false
    var isSelectionEnabled = true
    var selectableDates: Set<Date>? = nil
    var chartStyle: AIUsageHistoryChartStyle = .bars
    var dataColor: Color? = nil
    var strokeWidth: CGFloat = 2
    var emptyMessage: String? = nil
    var viewportHeight: CGFloat? = nil
    var documentSize: CGSize? = nil
    var accessibilityValueFormatter: ((Decimal) -> String)? = nil
    let formatValue: (Decimal) -> String
    let onSelect: @MainActor (Date) -> Void
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focusedDate: Date?

    private var domain: (Double, Double) {
        let values = points.compactMap(\.value).map { NSDecimalNumber(decimal: $0).doubleValue }
        let lower = min(0, values.min() ?? 0), upper = max(0, values.max() ?? 0)
        return lower == upper ? (0, 1) : (lower < 0 ? lower * 1.1 : 0, upper > 0 ? upper * 1.1 : 0)
    }
    var body: some View {
        Group {
            if let emptyMessage {
                HStack(spacing: DSSpacing.small) {
                    DSIcon(.chart)
                        .accessibilityHidden(true)
                    Text(emptyMessage)
                        .font(DSTypography.metadata)
                }
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: plotHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(emptyMessage)
            } else {
                HStack(alignment: .top, spacing: 7) {
                    VStack(alignment: .trailing) {
                        Text(axisValue(domain.1))
                        Spacer()
                        Text(axisValue((domain.0 + domain.1) / 2))
                        Spacer()
                        Text(axisValue(domain.0))
                    }
                    .font(DSTypography.caption).foregroundStyle(theme.textTertiary)
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .frame(width: 46, height: plotHeight).accessibilityHidden(true)
                    DashboardHistoryViewport(
                        latestID: points.last?.id,
                        viewportHeight: viewportHeight,
                        documentSize: documentSize
                    ) {
                        chartContent
                    }
                }
            }
        }
        .frame(height: plotHeight + footerSpace)
        .onChange(of: focusedDate) { _, value in if let value { hoveredDate = value } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily \(metricLabel), \(points.count) days, \(timezone.identifier)")
    }
    private var grid: some View { Rectangle().fill(theme.outline).frame(height: contrast == .increased ? 1 : 0.5) }
    private func axisValue(_ value: Double) -> String { formatValue(Decimal(value)) }
    private func y(_ value: Double) -> CGFloat { CGFloat((domain.1 - value) / (domain.1 - domain.0)) * plotHeight }

    @ViewBuilder
    private var chartContent: some View {
        switch chartStyle {
        case .bars:
            HStack(alignment: .top, spacing: 8) {
                ForEach(points) { point in column(point).id(point.id) }
            }
            .padding(.horizontal, 4)
            .background(alignment: .top) {
                VStack { grid; Spacer(); grid; Spacer(); grid }.frame(height: plotHeight)
            }
        case .area:
            HStack(alignment: .top, spacing: 8) {
                ForEach(points) { point in areaColumn(point).id(point.id) }
            }
            .padding(.horizontal, 4)
            .background(alignment: .topLeading) {
                GeometryReader { geometry in
                    VStack { grid; Spacer(); grid; Spacer(); grid }
                        .frame(width: geometry.size.width, height: plotHeight)
                    areaPlot
                        .frame(width: geometry.size.width, height: plotHeight)
                }
            }
        }
    }

    private var areaPlot: some View {
        Canvas { context, size in
            let color = dataColor ?? theme.action
            let baseline = y(0)
            let lineWidth = max(0.8, min(4, strokeWidth))
            let increasedContrast = contrast == .increased
            var segment: [CGPoint] = []

            func draw(_ points: [CGPoint]) {
                guard let first = points.first, let last = points.last else { return }
                if points.count == 1 {
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: first.x - lineWidth,
                            y: first.y - lineWidth,
                            width: lineWidth * 2,
                            height: lineWidth * 2
                        )),
                        with: .color(color)
                    )
                    return
                }

                var line = Path()
                line.addLines(points)
                var fill = line
                fill.addLine(to: CGPoint(x: last.x, y: baseline))
                fill.addLine(to: CGPoint(x: first.x, y: baseline))
                fill.closeSubpath()
                context.fill(fill, with: .color(color.opacity(increasedContrast ? 0.34 : 0.22)))
                context.stroke(
                    line,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: increasedContrast ? lineWidth * 1.4 : lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            for (index, point) in points.enumerated() {
                guard let value = point.value else {
                    draw(segment)
                    segment = []
                    continue
                }
                let x = 27 + CGFloat(index) * 54
                segment.append(CGPoint(
                    x: x,
                    y: y(NSDecimalNumber(decimal: value).doubleValue)
                ))
            }
            draw(segment)
        }
        .accessibilityHidden(true)
    }

    private func column(_ point: AIUsageHistoryPoint) -> some View {
        let selectable = isSelectionEnabled && (selectableDates?.contains(point.date)
            ?? (point.value.map { allowsZeroSelection || $0 > 0 } == true))
        return Button { Task { @MainActor in onSelect(point.date) } } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .top) {
                    Rectangle().fill(theme.surfaceInset.opacity(hoveredDate == point.date ? 1 : 0))
                    if let value = point.value {
                        let position = y(NSDecimalNumber(decimal: value).doubleValue)
                        let baseline = y(0)
                        RoundedRectangle(cornerRadius: 3)
                            // An explicit data color has already been resolved
                            // for contrast. Partialness still has its * marker;
                            // legacy callers keep the existing opacity behavior.
                            .fill((dataColor ?? theme.action).opacity(point.partial && dataColor == nil ? 0.55 : 1))
                            .frame(width: 27, height: max(2, abs(position - baseline)))
                            .offset(y: min(position, baseline))
                        if point.partial { Text("*").font(DSTypography.caption).foregroundStyle(theme.textPrimary) }
                    } else {
                        Text("—").font(DSTypography.caption).foregroundStyle(theme.textTertiary).offset(y: plotHeight / 2)
                    }
                }.frame(height: plotHeight)
                Text(dateLabel(point.date, format: "EEE")).foregroundStyle(theme.textSecondary)
                Text(dateLabel(point.date, format: "d")).foregroundStyle(theme.textPrimary)
            }
            .font(DSTypography.caption).frame(width: 46)
            .contentShape(Rectangle())
        }
        // A read-only chart is non-activatable, but its data marks are not in a
        // disabled data state and must retain their resolved series color.
        .buttonStyle(
            DSContentButtonStyle(dimsWhenDisabled: isSelectionEnabled)
        )
        .disabled(!selectable)
        .focused($focusedDate, equals: point.date)
        .onHover { inside in if inside { hoveredDate = point.date } }
        .help(accessibility(point))
        .accessibilityLabel(dateLabel(point.date, format: "yyyy-MM-dd") + " " + timezone.identifier)
        .accessibilityValue(accessibility(point))
    }

    private func areaColumn(_ point: AIUsageHistoryPoint) -> some View {
        let selectable = isSelectionEnabled && (selectableDates?.contains(point.date)
            ?? (point.value.map { allowsZeroSelection || $0 > 0 } == true))
        return Button { Task { @MainActor in onSelect(point.date) } } label: {
            VStack(spacing: 4) {
                ZStack {
                    if hoveredDate == point.date {
                        RoundedRectangle(cornerRadius: DSRadius.keycap)
                            .strokeBorder(theme.outlineStrong, lineWidth: contrast == .increased ? 2 : 1)
                    }
                    if let value = point.value {
                        if point.partial {
                            Text("*")
                                .font(DSTypography.caption)
                                .foregroundStyle(theme.textPrimary)
                                .offset(y: min(plotHeight / 2, y(NSDecimalNumber(decimal: value).doubleValue) - plotHeight / 2))
                        }
                    } else {
                        Text("—").font(DSTypography.caption).foregroundStyle(theme.textTertiary)
                    }
                }
                .frame(height: plotHeight)
                Text(dateLabel(point.date, format: "EEE")).foregroundStyle(theme.textSecondary)
                Text(dateLabel(point.date, format: "d")).foregroundStyle(theme.textPrimary)
            }
            .font(DSTypography.caption).frame(width: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSContentButtonStyle(dimsWhenDisabled: isSelectionEnabled))
        .disabled(!selectable)
        .focused($focusedDate, equals: point.date)
        .onHover { inside in if inside { hoveredDate = point.date } }
        .help(accessibility(point))
        .accessibilityLabel(dateLabel(point.date, format: "yyyy-MM-dd") + " " + timezone.identifier)
        .accessibilityValue(accessibility(point))
    }
    private func accessibility(_ point: AIUsageHistoryPoint) -> String {
        if let accessibilityValue = point.accessibilityValue {
            return "\(dateLabel(point.date, format: "yyyy-MM-dd")): \(accessibilityValue)\(point.partial ? ", partial" : "")"
        }
        let value = point.value.map {
            accessibilityValueFormatter?($0) ?? formatValue($0)
        } ?? "Not reported"
        return "\(dateLabel(point.date, format: "yyyy-MM-dd")): \(value) \(metricLabel)\(point.partial ? ", partial" : "")"
    }
    private func dateLabel(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone; formatter.locale = .current; formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

/// Provider-neutral adapter for token and cost histories that still use the
/// legacy integer daily-bucket model. It owns data normalization only; all
/// chart drawing, focus, hover and accessibility live in
/// `AIUsageHistoryChart`.
@MainActor
struct AIUsageTokenHistoryChart: View {
    let buckets: [CodexTokenUsageDailyBucket]
    @Binding var hoveredBucketID: Date?
    let plotHeight: CGFloat
    var unavailableBucketIDs: Set<Date> = []
    var isSelectionEnabled = true
    var allowsZeroSelection = false
    var partialBucketIDs: Set<Date> = []
    var metricLabel = "tokens"
    var valueFormatter: ((Int64) -> String)? = nil
    var chartStyle: AIUsageHistoryChartStyle = .bars
    var dataColor: Color? = nil
    var strokeWidth: CGFloat = 2
    let onSelectBucket: @MainActor (Date) -> Void

    var body: some View {
        AIUsageHistoryChart(
            points: buckets.map {
                AIUsageHistoryPoint(
                    date: $0.startDate,
                    value: unavailableBucketIDs.contains($0.id)
                        ? nil
                        : Decimal($0.tokens),
                    partial: partialBucketIDs.contains($0.id)
                )
            },
            hoveredDate: $hoveredBucketID,
            plotHeight: plotHeight,
            metricLabel: metricLabel,
            allowsZeroSelection: allowsZeroSelection,
            isSelectionEnabled: isSelectionEnabled,
            chartStyle: chartStyle,
            dataColor: dataColor,
            strokeWidth: strokeWidth,
            accessibilityValueFormatter: { value in
                let integer = NSDecimalNumber(decimal: value).int64Value
                return valueFormatter?(integer) ?? integer.formatted()
            },
            formatValue: { value in
                let integer = NSDecimalNumber(decimal: value).int64Value
                return valueFormatter?(integer)
                    ?? integer.formatted(
                        .number.notation(.compactName)
                            .precision(.fractionLength(0...1))
                    )
            },
            onSelect: onSelectBucket
        )
    }
}
