import SwiftUI

@MainActor
struct CodexDailyTokenDetailView: View {
    let accountBucket: CodexTokenUsageDailyBucket
    let detail: CodexDailyTokenDetail?
    let loadState: CodexDailyTokenDetailLoadState
    var providerName: String = "Codex"
    let onBack: @MainActor () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            header
            summary
            divider
            hourlySection
            tokenBreakdown
            divider
            modelsSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(providerName) token detail for \(Self.fullDateLabel(accountBucket.startDate))"
        )
        .accessibilityIdentifier("\(providerID).dailyDetail")
    }

    private var header: some View {
        ZStack {
            Text(Self.fullDateLabel(accountBucket.startDate))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: 10, weight: .bold))
                            .accessibilityHidden(true)

                        Text("Daily tokens")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 5)
                    .frame(height: 26)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to Daily tokens")
                .accessibilityLabel("Back to Daily tokens")
                .accessibilityIdentifier("\(providerID).dailyDetail.back")

                Spacer(minLength: 0)
            }
        }
        .frame(height: 28)
    }

    private var summary: some View {
        HStack {
            Text(Self.tokenLabel(accountBucket.tokens))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Token usage")
        .accessibilityValue(summaryAccessibilityValue)
    }

    private var hourlySection: some View {
        ZStack {
            CodexHourlyTokenUsageChart(buckets: hourlyBuckets)
                .opacity(isLoading ? 0.32 : 1)

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Scanning selected day…")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading token detail")
            } else if let detailErrorMessage {
                VStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(theme.warningForeground)
                        .accessibilityHidden(true)
                    Text(detailErrorMessage)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(detailErrorMessage)
            }
        }
        .frame(height: 142)
    }

    private var tokenBreakdown: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Token breakdown")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                metric(
                    title: "Input",
                    value: localUsage.map { Self.tokenLabel($0.inputTokens) }
                        ?? "—"
                )

                Spacer(minLength: 4)

                metric(
                    title: "Output",
                    value: localUsage.map { Self.tokenLabel($0.outputTokens) }
                        ?? "—"
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                compactMetric(
                    title: "Cached input",
                    value: localUsage.map {
                        Self.tokenLabel($0.cachedInputTokens)
                    } ?? "—"
                )
                Spacer(minLength: 2)
                compactMetric(
                    title: "Reasoning",
                    value: localUsage.map {
                        Self.tokenLabel($0.reasoningOutputTokens)
                    } ?? "—"
                )
                Spacer(minLength: 2)
                compactMetric(
                    title: "Tool",
                    value: localUsage.map {
                        Self.tokenLabel($0.toolTokens)
                    } ?? "—"
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Models")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                if !models.isEmpty {
                    Text("\(models.count)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Text("Tokens · cached input")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }

            if models.isEmpty {
                Text(modelsEmptyMessage)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .multilineTextAlignment(.center)
            } else {
                ScrollView(.vertical, showsIndicators: models.count > 3) {
                    LazyVStack(spacing: 0) {
                        ForEach(models) { model in
                            modelRow(model)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Models used on selected day")
    }

    private func metric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
    }

    private func compactMetric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func modelRow(_ model: CodexDailyModelTokenUsage) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.model)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Text(Self.tokenLabel(model.usage.totalTokens))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()

                Text(Self.cachedPercentLabel(model.usage))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .frame(width: 55, alignment: .trailing)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.opaqueSurfaceInset)
                    Capsule()
                        .fill(theme.action)
                        .frame(
                            width: geometry.size.width
                                * modelFraction(model.usage.totalTokens)
                        )
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.outline)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.model)
        .accessibilityValue(
            "\(model.usage.totalTokens.formatted()) tokens, "
                + "\(model.usage.cachedInputTokens.formatted()) cached input tokens"
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.outline)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }

    private var localUsage: CodexTokenBreakdown? {
        detail?.usage
    }

    private var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    private var modelsEmptyMessage: String {
        switch loadState {
        case .loading:
            "Loading model detail…"
        case let .failed(message):
            message.isEmpty
                ? "\(providerName) sessions could not be read."
                : "Token detail unavailable: \(message)"
        case .idle, .loaded:
            "No model detail was found in \(providerName) sessions."
        }
    }

    private var detailErrorMessage: String? {
        switch loadState {
        case let .failed(message):
            return message.isEmpty
                ? "Token detail is unavailable."
                : "Token detail unavailable: \(message)"
        case .loaded(nil):
            return "No matching local detail was found for this day."
        case .idle where detail == nil:
            return "No matching local detail was found for this day."
        case .idle, .loading, .loaded:
            return nil
        }
    }

    private var providerID: String {
        providerName.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    private var hourlyBuckets: [CodexHourlyTokenUsageBucket] {
        guard let detail else {
            return Self.emptyHourlyBuckets(for: accountBucket.startDate)
        }
        return detail.hourlyUsage
    }

    private var models: [CodexDailyModelTokenUsage] {
        detail?.modelUsage ?? []
    }

    private var summaryAccessibilityValue: String {
        if isLoading {
            return "\(accountBucket.tokens.formatted()) tokens. Loading detail for the selected day."
        }
        return "\(accountBucket.tokens.formatted()) tokens."
    }

    private func modelFraction(_ tokens: Int64) -> CGFloat {
        let maximum = max(1, models.map(\.usage.totalTokens).max() ?? 1)
        return CGFloat(min(1, max(0, Double(tokens) / Double(maximum))))
    }

    private static func emptyHourlyBuckets(
        for date: Date
    ) -> [CodexHourlyTokenUsageBucket] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.startOfDay(for: date)
        return (0..<24).compactMap { hour in
            calendar.date(byAdding: .hour, value: hour, to: day).map {
                CodexHourlyTokenUsageBucket(startDate: $0, usage: .zero)
            }
        }
    }

    private static func cachedPercentLabel(
        _ usage: CodexTokenBreakdown
    ) -> String {
        guard let fraction = usage.cachedInputFraction else { return "0%" }
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }

    private static func fullDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

private struct CodexHourlyTokenUsageChart: View {
    let buckets: [CodexHourlyTokenUsageBucket]

    @Environment(\.designTheme) private var theme
    @State private var selectedBucketID: Date?
    @State private var hoveredBucketID: Date?

    private let plotHeight: CGFloat = 78

    init(buckets: [CodexHourlyTokenUsageBucket]) {
        self.buckets = buckets
        _selectedBucketID = State(
            initialValue: buckets.max {
                $0.usage.totalTokens < $1.usage.totalTokens
            }?.id
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Hourly usage")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 4)

                if let activeBucket, activeBucket.usage.totalTokens > 0 {
                    Text(Self.hourLabel(activeBucket.startDate))
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)

                    Text(Self.tokenLabel(activeBucket.usage.totalTokens))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                }
            }

            HStack(alignment: .top, spacing: 6) {
                yAxis

                VStack(spacing: 3) {
                    chart
                    xAxis
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hourly token usage")
    }

    private var yAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(Self.tokenAxisLabel(axisMaximum))
            Spacer()
            Text(Self.tokenAxisLabel(axisMaximum / 2))
            Spacer()
            Text("0")
        }
        .font(.system(size: 7, weight: .medium))
        .foregroundStyle(theme.textTertiary)
        .monospacedDigit()
        .frame(width: 27, height: plotHeight, alignment: .trailing)
    }

    private var chart: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(theme.outline).frame(height: 0.5)
                Spacer()
                Rectangle().fill(theme.outline).frame(height: 0.5)
                Spacer()
                Rectangle().fill(theme.outline).frame(height: 0.5)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(buckets) { bucket in
                    hourButton(bucket)
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(height: plotHeight)
    }

    private var xAxis: some View {
        HStack(spacing: 0) {
            Text("00")
            Spacer()
            Text("06")
            Spacer()
            Text("12")
            Spacer()
            Text("18")
            Spacer()
            Text("23")
        }
        .font(.system(size: 7.5, weight: .medium))
        .foregroundStyle(theme.textTertiary)
        .monospacedDigit()
    }

    private func hourButton(
        _ bucket: CodexHourlyTokenUsageBucket
    ) -> some View {
        let isActive = bucket.id == activeBucket?.id
        let height = barHeight(bucket.usage.totalTokens)
        return Button {
            selectedBucketID = bucket.id
        } label: {
            ZStack(alignment: .bottom) {
                Color.clear

                if height > 0 {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(theme.action)
                        .opacity(isActive ? 1 : 0.68)
                        .frame(height: height)
                        .overlay {
                            if isActive {
                                RoundedRectangle(
                                    cornerRadius: 2,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    theme.textPrimary,
                                    lineWidth: 0.75
                                )
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, minHeight: plotHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                hoveredBucketID = bucket.id
            } else if hoveredBucketID == bucket.id {
                hoveredBucketID = nil
            }
        }
        .help(
            "\(Self.hourLabel(bucket.startDate)): "
                + "\(bucket.usage.totalTokens.formatted()) tokens"
        )
        .accessibilityLabel(Self.hourLabel(bucket.startDate))
        .accessibilityValue("\(bucket.usage.totalTokens.formatted()) tokens")
    }

    private var activeBucket: CodexHourlyTokenUsageBucket? {
        let id = hoveredBucketID ?? selectedBucketID
        return buckets.first { $0.id == id }
    }

    private var axisMaximum: Int64 {
        let peak = buckets.map(\.usage.totalTokens).max() ?? 0
        guard peak > 0 else { return 1 }
        return max(1, Int64((Double(peak) * 1.1).rounded(.up)))
    }

    private func barHeight(_ tokens: Int64) -> CGFloat {
        guard tokens > 0 else { return 0 }
        let fraction = min(1, Double(tokens) / Double(axisMaximum))
        return max(2, plotHeight * CGFloat(fraction))
    }

    private static func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:00"
        return formatter.string(from: date)
    }

    private static func tokenAxisLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        tokens.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }
}
