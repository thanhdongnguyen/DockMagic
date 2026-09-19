import AppKit
import SwiftUI

struct CodexShipMomentumCard: View {
    let momentum: CodexShipMomentum?
    var accent: Color? = nil
    var accentForeground: Color? = nil
    var isPartial = false
    var showsPartialIndicator = true

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        isPartial && showsPartialIndicator
                            ? "Ship momentum*"
                            : "Ship momentum"
                    )
                        .dsFont(size: 10.5, weight: .bold)
                        .foregroundStyle(theme.textPrimary)

                    ShipMomentumGauge(
                        score: momentum?.score,
                        rank: momentum?.rank,
                        accent: resolvedAccent,
                        valueForeground: accentForeground
                    )
                    .frame(width: 132, height: 56)
                }
                .frame(width: 136, alignment: .leading)

                Rectangle()
                    .fill(theme.outline)
                    .frame(width: 0.5, height: 68)
                    .accessibilityHidden(true)

                CodexShipRankLadder(
                    activeRank: momentum?.rank,
                    accent: resolvedAccent,
                    accentForeground: accentForeground
                )
            }

            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            if let momentum {
                metric(
                    value: Self.tokenLabel(momentum.todayTokens),
                    label: "tokens today"
                )
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                unavailableDetails
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ship momentum")
        .accessibilityValue(accessibilityValue)
    }

    private var unavailableDetails: some View {
        Text("Today's token usage is unavailable")
            .dsFont(size: 8.5, weight: .medium)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var resolvedAccent: Color {
        accent ?? theme.action
    }

    private func metric(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .dsFont(size: 15, weight: .bold)
                .foregroundStyle(accentForeground ?? theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .dsFont(size: 8.5, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var helpText: String {
        let coverage = isPartial
            ? " For this provider, it includes only token activity observed locally by DockMagic."
            : ""
        return "Ship momentum uses only today's token activity and resets each local "
            + "calendar day. The ladder progresses from Starter to Legend. "
            + "It is an activity indicator, not a productivity rating."
            + coverage
    }

    private var accessibilityValue: String {
        guard let momentum else {
            return "Today's token usage is unavailable."
        }
        let coverage = isPartial ? " Locally observed activity only." : ""
        return "\(momentum.score) out of 100, rank \(momentum.rank.title), "
            + "\(momentum.rank.rawValue + 1) of \(CodexShipRank.allCases.count). "
            + "Today: \(momentum.todayTokens.formatted()) tokens."
            + coverage
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

struct AIUsageDailyIntensityCard: View {
    let buckets: [CodexTokenUsageDailyBucket]
    let accent: Color?
    let unavailableBucketIDs: Set<Date>
    let isPartial: Bool
    let showsPartialIndicator: Bool
    /// Opt-in for providers where unobserved days must differ from measured zero.
    let marksUnknownDays: Bool
    let title: String
    let metricLabel: String
    let timeZone: TimeZone
    let scopeDescription: String?
    @State private var hoveredBucketID: Date?

    @Environment(\.designTheme) private var theme

    init(
        buckets: [CodexTokenUsageDailyBucket],
        accent: Color? = nil,
        unavailableBucketIDs: Set<Date> = [],
        isPartial: Bool = false,
        showsPartialIndicator: Bool = true,
        marksUnknownDays: Bool = false,
        title: String = "Daily intensity",
        metricLabel: String = "tokens",
        timeZone: TimeZone = .current,
        scopeDescription: String? = nil,
        initialHoveredBucketID: Date? = nil
    ) {
        self.buckets = buckets
        self.accent = accent
        self.unavailableBucketIDs = unavailableBucketIDs
        self.isPartial = isPartial
        self.showsPartialIndicator = showsPartialIndicator
        self.marksUnknownDays = marksUnknownDays
        self.title = title
        self.metricLabel = metricLabel
        self.timeZone = timeZone
        self.scopeDescription = scopeDescription
        _hoveredBucketID = State(initialValue: initialHoveredBucketID)
    }

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 5), spacing: 3),
        count: 15
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                cardContent

                if let hoveredBucket {
                    hoverTooltip(
                        for: hoveredBucket,
                        in: geometry.size
                    )
                }
            }
        }
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .help(helpText)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(metricLabel)")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(
                    isPartial && showsPartialIndicator
                        ? "\(title)*"
                        : title
                )
                    .dsFont(size: 10.5, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 2)

                if let bestDay {
                    Text("Best \(shortDateLabel(bestDay.startDate))")
                        .dsFont(size: 8, weight: .semibold)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .circular).fill(theme.opaqueSurfaceRaised)
                        )
                        .overlay {
                            Capsule(style: .circular).strokeBorder(
                                theme.outline,
                                lineWidth: 0.5
                            )
                        }
                        .lineLimit(1)
                }
            }

            if buckets.isEmpty {
                Text("No intensity data")
                    .dsFont(size: 8.5, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(buckets) { bucket in
                        intensityCell(for: bucket)
                    }
                }

                HStack(spacing: 4) {
                    Text(shortDateLabel(buckets.first!.startDate))

                    Spacer(minLength: 1)

                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { level in
                            RoundedRectangle(
                                cornerRadius: 1.5,
                                style: .continuous
                            )
                            .fill(fill(for: level))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 1.5,
                                    style: .continuous
                                )
                                .strokeBorder(theme.outline, lineWidth: 0.5)
                            }
                            .frame(width: 7, height: 6)
                        }
                    }
                    .accessibilityHidden(true)

                    Spacer(minLength: 1)

                    Text(shortDateLabel(buckets.last!.startDate))
                }
                .dsFont(size: 7.5, weight: .medium)
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                if marksUnknownDays, !unavailableBucketIDs.isEmpty {
                    Text("? Not observed")
                        .dsFont(size: 7.5, weight: .medium)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bestDay: CodexTokenUsageDailyBucket? {
        buckets
            .filter { !unavailableBucketIDs.contains($0.id) }
            .max { $0.tokens < $1.tokens }
    }

    private var hoveredBucket: CodexTokenUsageDailyBucket? {
        guard let hoveredBucketID else { return nil }
        return buckets.first { $0.id == hoveredBucketID }
    }

    private var maximumTokens: Int64 {
        max(
            1,
            buckets
                .filter { !unavailableBucketIDs.contains($0.id) }
                .map(\.tokens)
                .max() ?? 1
        )
    }

    private func intensityCell(
        for bucket: CodexTokenUsageDailyBucket
    ) -> some View {
        let isAvailable = !unavailableBucketIDs.contains(bucket.id)
        let level = intensityLevel(for: bucket.tokens)
        let isHovered = bucket.id == hoveredBucketID
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(marksUnknownDays && !isAvailable ? theme.opaqueSurfaceRaised : fill(for: level))
            .overlay {
                if marksUnknownDays && !isAvailable {
                    Text("?").dsFont(size: 7, weight: .bold)
                        .foregroundStyle(theme.textSecondary).accessibilityHidden(true)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(
                        isHovered
                            ? theme.actionForeground
                            : bucket.id == buckets.last?.id
                            ? theme.textPrimary
                            : theme.outline,
                        lineWidth: isHovered
                            || bucket.id == buckets.last?.id
                            ? 1
                            : 0.5
                    )
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering {
                    hoveredBucketID = bucket.id
                } else if hoveredBucketID == bucket.id {
                    hoveredBucketID = nil
                }
            }
            .accessibilityLabel(fullDateLabel(bucket.startDate))
            .accessibilityValue(
                isAvailable
                    ? "\(bucket.tokens.formatted()) \(metricLabel)"
                    : "Not observed"
            )
    }

    private func hoverTooltip(
        for bucket: CodexTokenUsageDailyBucket,
        in size: CGSize
    ) -> some View {
        Text(tooltipLabel(for: bucket))
            .dsFont(size: 7.5, weight: .semibold)
            .foregroundStyle(theme.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.opaqueSurfaceRaised)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.outlineStrong, lineWidth: 0.5)
            }
            .position(
                x: tooltipCenterX(for: bucket, cardWidth: size.width),
                y: max(12, size.height - 12)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func tooltipCenterX(
        for bucket: CodexTokenUsageDailyBucket,
        cardWidth: CGFloat
    ) -> CGFloat {
        guard let index = buckets.firstIndex(where: { $0.id == bucket.id })
        else {
            return cardWidth / 2
        }

        let column = index % columns.count
        let horizontalPadding: CGFloat = 9
        let usableWidth = max(0, cardWidth - horizontalPadding * 2)
        let cellCenter = horizontalPadding
            + usableWidth * (CGFloat(column) + 0.5) / CGFloat(columns.count)
        let tooltipHalfWidth: CGFloat = 36
        return min(
            max(tooltipHalfWidth, cellCenter),
            max(tooltipHalfWidth, cardWidth - tooltipHalfWidth)
        )
    }

    private func intensityLevel(for tokens: Int64) -> Int {
        guard tokens > 0 else { return 0 }
        return min(
            4,
            max(1, Int(ceil(Double(tokens) / Double(maximumTokens) * 4)))
        )
    }

    private func fill(for level: Int) -> Color {
        (accent ?? theme.action).opacity(0.10 + Double(level) * 0.19)
    }

    private var helpText: String {
        guard let bestDay else {
            let unavailable = isPartial
                ? "No observed daily \(metricLabel) intensity is available."
                : "Daily \(metricLabel) intensity is unavailable."
            return [unavailable, scopeDescription].compactMap { $0 }.joined(separator: " ")
        }
        let coverage = isPartial
            ? " Unobserved days remain unavailable and are excluded from Best calculations."
            : ""
        let summary = "Daily \(metricLabel) intensity for up to 30 days. Best day: "
            + "\(fullDateLabel(bestDay.startDate)), "
            + "\(bestDay.tokens.formatted()) \(metricLabel)."
            + coverage
        return [summary, scopeDescription].compactMap { $0 }.joined(separator: " ")
    }

    private func tooltipLabel(
        for bucket: CodexTokenUsageDailyBucket
    ) -> String {
        let date = fullDateLabel(bucket.startDate)
        guard !unavailableBucketIDs.contains(bucket.id) else {
            return "\(date) · Not observed"
        }
        return "\(date) · \(bucket.tokens.formatted()) \(metricLabel)"
    }

    private func shortDateLabel(_ date: Date) -> String {
        formatter("MMM d").string(from: date)
    }

    private func fullDateLabel(_ date: Date) -> String {
        formatter("MMM d, yyyy").string(from: date)
    }

    private func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}

/// Transitional source compatibility for callers outside the production dashboard set.
typealias CodexDailyIntensityCard = AIUsageDailyIntensityCard

struct CodexTopModelsCard: View {
    let models: [CodexModelTokenUsage]
    let isPartial: Bool
    var accent: Color? = nil
    var providerName: String = "Codex"
    var showsPartialIndicator = true

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Top models")
                    .dsFont(size: 10.5, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 2)

                Text(
                    isPartial && showsPartialIndicator
                        ? "30d*"
                        : "30d"
                )
                    .dsFont(size: 8, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }

            if models.isEmpty {
                Text("No model token data")
                    .dsFont(size: 8.5, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 3) {
                    ForEach(Array(models.enumerated()), id: \.element.id) {
                        index, model in
                        modelRow(model, rank: index + 1)
                    }
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .help(helpText)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Top models by token usage")
    }

    private func modelRow(
        _ model: CodexModelTokenUsage,
        rank: Int
    ) -> some View {
        HStack(spacing: 5) {
            Text("\(rank)")
                .dsFont(size: 8, weight: .bold)
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
                .frame(width: 8, alignment: .trailing)

            Text(model.model)
                .dsFont(size: 9, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 2)

            Capsule(style: .circular)
                .fill(accent ?? theme.action)
                .frame(width: modelBarWidth(model.tokens), height: 4)
                .accessibilityHidden(true)

            Text(Self.tokenLabel(model.tokens))
                .dsFont(size: 9, weight: .bold)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank), \(model.model)")
        .accessibilityValue("\(model.tokens.formatted()) tokens")
    }

    private func modelBarWidth(_ tokens: Int64) -> CGFloat {
        let maximum = max(1, models.map(\.tokens).max() ?? 1)
        return max(3, 13 * CGFloat(Double(tokens) / Double(maximum)))
    }

    private var helpText: String {
        let coverage = isPartial
            ? " Coverage is partial; only token activity available to DockMagic is included."
            : ""
        return "Models ranked by tokens observed for \(providerName) during "
            + "the last 30 days. Prompt and response content is not used."
            + coverage
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

private struct CodexShipRankLadder: View {
    let activeRank: CodexShipRank?
    let accent: Color
    var accentForeground: Color? = nil

    @Environment(\.designTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let columnWidth = max(
                0,
                (proxy.size.width
                    - spacing * CGFloat(CodexShipRank.allCases.count - 1))
                    / CGFloat(CodexShipRank.allCases.count)
            )

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(CodexShipRank.allCases) { rank in
                    VStack(spacing: 3) {
                        ZStack {
                            CodexRankStepShape()
                                .fill(stepFill(for: rank))
                            CodexRankStepShape()
                                .stroke(
                                    stepOutline(for: rank),
                                    lineWidth: rank == activeRank ? 1 : 0.5
                                )

                            Text("\(rank.rawValue + 1)")
                                .dsFont(
                                    size: 9,
                                    weight: .bold,
                                    design: .rounded
                                )
                                .foregroundStyle(stepNumber(for: rank))
                                .monospacedDigit()
                        }
                        .frame(
                            width: columnWidth,
                            height: 23 + CGFloat(rank.rawValue * 3)
                        )

                        Text(rank.title)
                            .dsFont(
                                size: 7,
                                weight: rank == activeRank ? .bold : .medium
                            )
                            .foregroundStyle(
                                rank == activeRank
                                    ? (accentForeground ?? accent)
                                    : theme.textSecondary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(
                                width: columnWidth,
                                height: 9,
                                alignment: .top
                            )
                    }
                    .frame(width: columnWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 61)
        .accessibilityHidden(true)
    }

    private func stepFill(for rank: CodexShipRank) -> Color {
        if rank == activeRank {
            return accent
        }
        if let activeRank, rank.rawValue < activeRank.rawValue {
            return theme.outlineStrong
        }
        return theme.dockTrack
    }

    private func stepOutline(for rank: CodexShipRank) -> Color {
        rank == activeRank ? accent : theme.outline
    }

    private func stepNumber(for rank: CodexShipRank) -> Color {
        rank == activeRank ? theme.onAction : theme.textPrimary
    }
}

private struct CodexRankStepShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(6, rect.width * 0.2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct UsageLimitHoverRow: View {
    let title: String
    let systemImage: String
    let remainingFraction: Double?
    let resetLabel: String
    var usageAccent: Color? = nil

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            DSIcon(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 10, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 15)
                .accessibilityHidden(true)

            Text(title)
                .dsFont(size: 10.5, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .frame(width: 50, alignment: .leading)

            Text(remainingLabel)
                .dsFont(size: 11.5, weight: .bold)
                .foregroundStyle(valueForeground)
                .monospacedDigit()
                .frame(width: 43, alignment: .trailing)

            Text("left")
                .dsFont(size: 9, weight: .medium)
                .foregroundStyle(theme.textSecondary)

            DSProgress(value: remainingFraction, title: title, color: progressFill, height: 6)

            Text(resetLabel)
                .dsFont(size: 9, weight: .medium)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 126, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(remainingLabel) left. \(resetLabel).")
    }

    private var remainingLabel: String {
        guard let remainingFraction = DSProgressValue.normalized(remainingFraction) else { return "—" }
        return "\(Int((remainingFraction * 100).rounded()))%"
    }

    private var progressFill: Color {
        guard let remainingFraction else { return theme.action }
        switch remainingFraction {
        case ...0.05:
            return theme.danger
        case ...0.2:
            return theme.warning
        default:
            return usageAccent ?? theme.action
        }
    }

    private var valueForeground: Color {
        guard let remainingFraction else { return theme.textSecondary }
        switch remainingFraction {
        case ...0.05:
            return theme.dangerForeground
        case ...0.2:
            return theme.warningForeground
        default:
            return theme.textPrimary
        }
    }
}
