import SwiftUI

@MainActor
struct ClaudeCodeHoverDashboardView: View {
    let state: ClaudeCodeUsageState
    var now: Date = .now

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 7) {
            header
            quotaRows
            overviewHeader
            overviewCard
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Claude Code usage dashboard")
        .accessibilityIdentifier("dockHover.claudeCode")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("ClaudeCodeLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)

            Text("Claude Code")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let statusTitle, let statusSystemImage {
                HStack(spacing: 3) {
                    Image(systemName: statusSystemImage)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)

                    Text(statusTitle)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(statusForeground)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 8, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Local")
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(theme.opaqueSurfaceInset)
            )
            .overlay {
                Capsule().strokeBorder(theme.outline, lineWidth: 0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Local usage snapshot")
        }
        .frame(height: 30)
    }

    private var quotaRows: some View {
        VStack(spacing: 6) {
            quotaRow(
                kind: .fiveHour,
                title: "5-hour",
                systemImage: "clock"
            )
            quotaRow(
                kind: .weekly,
                title: "Weekly",
                systemImage: "calendar"
            )
        }
    }

    @ViewBuilder
    private func quotaRow(
        kind: ClaudeCodeRateLimitWindowKind,
        title: String,
        systemImage: String
    ) -> some View {
        if let window = window(for: kind) {
            UsageLimitHoverRow(
                title: title,
                systemImage: systemImage,
                window: window,
                resetLabel: CodexHoverDashboardPresentation.resetLabel(
                    for: window
                )
            )
        } else {
            ClaudeCodeUnavailableLimitRow(
                title: title,
                systemImage: systemImage
            )
        }
    }

    private var overviewHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("Usage snapshot")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 4)

            Text("Claude Code statusLine")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(height: 16)
    }

    @ViewBuilder
    private var overviewCard: some View {
        if let snapshot {
            VStack(spacing: 7) {
                HStack(spacing: 12) {
                    metric(
                        systemImage: "clock",
                        title: "Next reset",
                        value: nextResetValue,
                        detail: nextResetDetail
                    )

                    Rectangle()
                        .fill(theme.outline)
                        .frame(width: 0.5, height: 52)
                        .accessibilityHidden(true)

                    metric(
                        systemImage: "arrow.triangle.2.circlepath",
                        title: "Last sync",
                        value: ClaudeCodeHoverDashboardPresentation.ageLabel(
                            since: snapshot.fetchedAt,
                            now: now
                        ),
                        detail: ClaudeCodeHoverDashboardPresentation.dateLabel(
                            snapshot.fetchedAt
                        )
                    )
                }

                Rectangle()
                    .fill(theme.outline)
                    .frame(height: 0.5)
                    .accessibilityHidden(true)

                statusMessage
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(theme.opaqueSurfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.outline, lineWidth: 0.5)
            }
        } else {
            emptyStateCard
        }
    }

    private func metric(
        systemImage: String,
        title: String,
        value: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 14)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value). \(detail)")
    }

    private var statusMessage: some View {
        HStack(spacing: 6) {
            Image(systemName: footerSystemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(footerForeground)
                .accessibilityHidden(true)

            Text(footerMessage)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 7) {
            Image(systemName: emptyStateSystemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusForeground)
                .accessibilityHidden(true)

            Text(emptyStateTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Text(emptyStateMessage)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private var snapshot: ClaudeCodeRateLimitSnapshot? { state.snapshot }

    private func window(
        for kind: ClaudeCodeRateLimitWindowKind
    ) -> ClaudeCodeRateLimitWindow? {
        switch kind {
        case .fiveHour:
            snapshot?.fiveHour
        case .weekly:
            snapshot?.weekly
        }
    }

    private var nextReset: ClaudeCodeHoverDashboardPresentation.Reset? {
        ClaudeCodeHoverDashboardPresentation.nextReset(
            in: snapshot,
            now: now
        )
    }

    private var nextResetValue: String {
        guard let nextReset else { return "Awaiting sync" }
        return ClaudeCodeHoverDashboardPresentation.countdownLabel(
            until: nextReset.date,
            now: now
        )
    }

    private var nextResetDetail: String {
        guard let nextReset else { return "No upcoming reset reported" }
        return "\(nextReset.title) · "
            + ClaudeCodeHoverDashboardPresentation.dateLabel(nextReset.date)
    }

    private var statusTitle: String? {
        switch state {
        case .idle:
            "Waiting"
        case .loading:
            "Loading"
        case .live:
            nil
        case .stale:
            "Stale"
        case .unavailable:
            "Unavailable"
        }
    }

    private var statusSystemImage: String? {
        switch state {
        case .idle:
            "minus.circle"
        case .loading:
            "ellipsis.circle"
        case .live:
            nil
        case .stale:
            "exclamationmark.triangle"
        case .unavailable:
            "xmark.circle"
        }
    }

    private var statusForeground: Color {
        switch state {
        case .loading:
            theme.processingForeground
        case .stale:
            theme.warningForeground
        case .unavailable:
            theme.dangerForeground
        case .idle, .live:
            theme.textTertiary
        }
    }

    private var footerSystemImage: String {
        if case .stale = state {
            return "exclamationmark.triangle"
        }
        return "arrow.triangle.2.circlepath"
    }

    private var footerForeground: Color {
        if case .stale = state {
            return theme.warningForeground
        }
        return theme.textTertiary
    }

    private var footerMessage: String {
        if case let .stale(_, message) = state {
            return message
        }
        return "Updates locally after Claude Code emits a new status line."
    }

    private var emptyStateSystemImage: String {
        switch state {
        case .loading:
            "ellipsis.circle"
        case .unavailable:
            "xmark.circle"
        case .idle, .live, .stale:
            "clock"
        }
    }

    private var emptyStateTitle: String {
        switch state {
        case .loading:
            "Loading usage limits"
        case .unavailable:
            "Usage limits unavailable"
        case .idle, .live, .stale:
            "Waiting for usage data"
        }
    }

    private var emptyStateMessage: String {
        switch state {
        case let .unavailable(message):
            message
        case .loading:
            "DockMagic is reading the latest local Claude Code snapshot."
        case .idle, .live, .stale:
            "Complete one Claude Code response to publish the first quota snapshot."
        }
    }
}

enum ClaudeCodeHoverDashboardPresentation {
    struct Reset: Equatable {
        let title: String
        let date: Date
    }

    static func nextReset(
        in snapshot: ClaudeCodeRateLimitSnapshot?,
        now: Date = .now
    ) -> Reset? {
        let resets = [
            snapshot?.fiveHour?.resetsAt.map {
                Reset(title: "5-hour", date: $0)
            },
            snapshot?.weekly?.resetsAt.map {
                Reset(title: "Weekly", date: $0)
            }
        ].compactMap { $0 }
        return resets
            .filter { $0.date > now }
            .min { $0.date < $1.date }
    }

    static func ageLabel(since date: Date, now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 {
            return "Just now"
        }
        if elapsed < 3_600 {
            return "\(Int(elapsed / 60))m ago"
        }
        if elapsed < 86_400 {
            let hours = Int(elapsed / 3_600)
            let minutes = Int(elapsed.truncatingRemainder(dividingBy: 3_600) / 60)
            return minutes == 0 ? "\(hours)h ago" : "\(hours)h \(minutes)m ago"
        }
        return "\(Int(elapsed / 86_400))d ago"
    }

    static func countdownLabel(until date: Date, now: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 {
            return "Time passed"
        }
        if remaining < 60 {
            return "<1m"
        }
        if remaining < 3_600 {
            return "\(Int(remaining / 60))m"
        }
        if remaining < 86_400 {
            let hours = Int(remaining / 3_600)
            let minutes = Int(
                remaining.truncatingRemainder(dividingBy: 3_600) / 60
            )
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        let days = Int(remaining / 86_400)
        let hours = Int(
            remaining.truncatingRemainder(dividingBy: 86_400) / 3_600
        )
        return hours == 0 ? "\(days)d" : "\(days)d \(hours)h"
    }

    static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

private struct ClaudeCodeUnavailableLimitRow: View {
    let title: String
    let systemImage: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 15)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 50, alignment: .leading)

            Text("—")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 67, alignment: .center)

            Capsule()
                .fill(theme.dockTrack)
                .frame(height: 6)

            Text("Not reported")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
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
        .accessibilityValue("Not reported by Claude Code")
    }
}

#if DEBUG
extension CodexRateLimitSnapshot {
    static func claudeCodeHoverDesignPreview(
        now: Date = .now
    ) -> Self {
        Self(
            planType: nil,
            limitID: "claude-code",
            fiveHour: ClaudeCodeRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 26,
                windowDurationMinutes: 300,
                resetsAt: now.addingTimeInterval(2 * 3_600 + 18 * 60)
            ),
            weekly: ClaudeCodeRateLimitWindow(
                kind: .weekly,
                usedPercent: 59,
                windowDurationMinutes: 10_080,
                resetsAt: now.addingTimeInterval(4 * 86_400 + 7 * 3_600)
            ),
            fetchedAt: now.addingTimeInterval(-4 * 60)
        )
    }
}
#endif
