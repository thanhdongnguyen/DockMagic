import SwiftUI

enum StreakServiceBrand: Sendable {
    case codex
    case claudeCode

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }

    var logoAssetName: String {
        switch self {
        case .codex: "CodexLogo"
        case .claudeCode: "ClaudeCodeLogo"
        }
    }
}

struct StreakBadgeView: View {
    let milestone: TokenUsageStreakMilestone
    let size: CGFloat
    var isUnlocked = true
    var showsLock = false

    @Environment(\.designTheme) private var theme
    @Environment(\.displayScale) private var displayScale

    private var interpolation: Image.Interpolation {
        guard size <= 60 else { return .high }
        return displayScale >= 2 ? .none : .medium
    }

    var body: some View {
        ZStack {
            Image(milestone.assetName)
                .resizable()
                .interpolation(interpolation)
                .scaledToFit()
                .saturation(isUnlocked ? 1 : 0)
                .opacity(isUnlocked ? 1 : 0.34)

            if showsLock && !isUnlocked {
                Image(systemName: "lock.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: max(8, size * 0.13), weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .padding(max(3, size * 0.055))
                    .background(theme.opaqueSurfaceRaised)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(theme.outlineStrong, lineWidth: 0.75)
                    }
                    .offset(x: size * 0.26, y: size * 0.25)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(milestone.title)
        .accessibilityValue(
            isUnlocked
                ? "Unlocked at \(milestone.requiredDays) days"
                : "Locked, requires \(milestone.requiredDays) days"
        )
    }
}

struct StreakCelebrationView: View {
    let celebration: TokenUsageStreakCelebration
    let brand: StreakServiceBrand
    let accent: Color
    let planLabel: String?
    let trailingMetricValue: String?
    let trailingMetricLabel: String?
    let onViewBadges: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 7)

            Text("TODAY'S STREAK")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(theme.textSecondary)
                .offset(y: -8)
                .zIndex(1)

            badgeHero
                .padding(.top, 7)

            Text("Streak secured")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.top, 2)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(dayLabel)
                    .foregroundStyle(accent)
                Text("·")
                    .foregroundStyle(theme.textTertiary)
                Text(milestoneLabel)
                    .foregroundStyle(theme.textSecondary)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.top, 2)

            recentDays
                .padding(.top, 12)

            Text(nextMilestoneLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .padding(.top, 9)

            Spacer(minLength: 7)

            Button(action: onViewBadges) {
                Text("View badges")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open streak badges")
            .accessibilityIdentifier("dockHover.streak.celebration.viewBadges")

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.outline)
                    Capsule()
                        .fill(accent)
                        .frame(width: geometry.size.width * 0.78)
                }
            }
                .frame(maxWidth: 260)
                .frame(height: 3)
                .accessibilityHidden(true)
                .padding(.top, 8)

            Text("Returning to dashboard in a moment…")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(brand.displayName) streak secured")
        .accessibilityValue(
            "\(dayLabel), \(milestoneLabel), \(nextMilestoneLabel)"
        )
        .accessibilityIdentifier("dockHover.streak.celebration")
    }

    private var header: some View {
        HStack(spacing: 8) {
            brandLogo

            Text(brand.displayName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let planLabel, !planLabel.isEmpty {
                celebrationPlanBadge(planLabel)
            }

            Spacer(minLength: 4)

            if let trailingMetricValue, let trailingMetricLabel {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(trailingMetricValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text(trailingMetricLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
            }
        }
        .frame(height: 30)
    }

    @ViewBuilder
    private var brandLogo: some View {
        switch brand {
        case .codex:
            Image(brand.logoAssetName)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 42, height: 42)
                .frame(width: 26, height: 26)
                .clipShape(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)
        case .claudeCode:
            Image(brand.logoAssetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)
        }
    }

    private func celebrationPlanBadge(_ plan: String) -> some View {
        HStack(spacing: 4) {
            if plan.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == "pro" {
                Image(systemName: "crown.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 9, weight: .bold))
                    .accessibilityHidden(true)
            }

            Text(plan.localizedUppercase)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.25)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(theme.opaqueSurfaceInset))
        .overlay {
            Capsule().strokeBorder(theme.outlineStrong, lineWidth: 1.25)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(brand.displayName) \(plan) plan")
    }

    private var badgeHero: some View {
        ZStack {
            ForEach(Array(neutralRayAngles.enumerated()), id: \.offset) {
                _, angle in
                Capsule()
                    .fill(theme.outlineStrong)
                    .frame(width: 22, height: 1)
                    .offset(x: 92)
                    .rotationEffect(.degrees(angle))
            }

            ForEach(Array(accentRayAngles.enumerated()), id: \.offset) {
                _, angle in
                Capsule()
                    .fill(accent)
                    .frame(width: 17, height: 1.5)
                    .offset(x: 94)
                    .rotationEffect(.degrees(angle))
            }

            Image(systemName: "hexagon")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .offset(x: -102, y: -34)
                .accessibilityHidden(true)

            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .offset(x: -112, y: 37)
                .accessibilityHidden(true)

            StreakBadgeView(
                milestone: currentMilestone,
                size: 185,
                isUnlocked: true
            )
        }
        .frame(maxWidth: .infinity, minHeight: 172, maxHeight: 172)
        .accessibilityHidden(true)
    }

    private var recentDays: some View {
        HStack(spacing: 12) {
            ForEach(celebration.summary.recentDays) { day in
                StreakDayNode(day: day, accent: accent, compact: false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Last seven days")
    }

    private var currentMilestone: TokenUsageStreakMilestone {
        celebration.summary.earnedBadge ?? .firstPrompt
    }

    private var dayLabel: String {
        let day = max(1, celebration.summary.currentDays)
        return "Day \(day)"
    }

    private var milestoneLabel: String {
        let summary = celebration.summary
        if summary.currentDays == currentMilestone.requiredDays,
           summary.bestDays == summary.currentDays {
            return "\(currentMilestone.title) unlocked"
        }
        return "\(currentMilestone.title) badge active"
    }

    private var nextMilestoneLabel: String {
        guard
            let nextBadge = celebration.summary.nextBadge,
            let remainingDays = celebration.summary.daysUntilNextBadge
        else {
            return "All badges earned"
        }
        let unit = remainingDays == 1 ? "day" : "days"
        return "\(remainingDays) \(unit) to \(nextBadge.title)"
    }

    private var neutralRayAngles: [Double] {
        [-160, -139, -41, -20, 20, 41, 61, 119, 139, 160]
    }

    private var accentRayAngles: [Double] {
        [-178, 48]
    }
}

struct StreakContinuityStrip: View {
    let summary: TokenUsageStreakSummary?
    let brand: StreakServiceBrand
    let accent: Color
    let onOpen: () -> Void

    @Environment(\.designTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 9) {
                badge

                VStack(alignment: .leading, spacing: 2) {
                    Text(streakTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(streakSubtitle)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: 78, alignment: .leading)

                Rectangle()
                    .fill(theme.outline)
                    .frame(width: 0.5, height: 36)
                    .accessibilityHidden(true)

                if let summary {
                    recentDayStrip(summary.recentDays)
                } else {
                    unavailableDays
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(progressTitle)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text(progressSubtitle)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: 60, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(isHovered ? theme.opaqueSurfaceRaised : theme.opaqueSurfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isHovered ? theme.outlineStrong : theme.outline,
                        lineWidth: isHovered ? 1 : 0.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Open streak badges")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open \(brand.displayName) streak details")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Shows the current badge and all streak milestones")
        .accessibilityIdentifier("dockHover.streak.open")
    }

    private var badge: some View {
        StreakBadgeView(
            milestone: summary?.earnedBadge ?? .firstPrompt,
            size: 48,
            isUnlocked: summary?.earnedBadge != nil
        )
    }

    private var streakTitle: String {
        guard let summary else { return "Streak unavailable" }
        return "\(summary.currentDays)-day streak"
    }

    private var streakSubtitle: String {
        guard let summary else { return "Waiting for usage data" }
        if let earned = summary.earnedBadge {
            return "\(earned.title) · best \(summary.bestDays)"
        }
        return "Use tokens to begin"
    }

    private var progressTitle: String {
        guard let summary else { return "—" }
        guard let days = summary.daysUntilNextBadge else { return "Complete" }
        return "\(days)d"
    }

    private var progressSubtitle: String {
        guard let summary else { return "No data" }
        return summary.nextBadge?.title ?? "All earned"
    }

    private var accessibilityValue: String {
        guard let summary else { return "Streak data unavailable" }
        let badge = summary.earnedBadge?.title ?? "No badge earned"
        return "\(summary.currentDays) day current streak, best \(summary.bestDays) days, \(badge)"
    }

    private func recentDayStrip(_ days: [TokenUsageStreakDay]) -> some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                StreakDayNode(day: day, accent: accent, compact: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Last seven days")
    }

    private var unavailableDays: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { _ in
                Circle()
                    .strokeBorder(theme.outline, lineWidth: 0.75)
                    .frame(width: 14, height: 14)
            }
        }
        .accessibilityHidden(true)
    }
}

struct StreakDetailView: View {
    let summary: TokenUsageStreakSummary?
    let brand: StreakServiceBrand
    let accent: Color
    let onBack: () -> Void

    @Environment(\.designTheme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    var body: some View {
        VStack(spacing: 8) {
            detailHeader

            ScrollView(.vertical) {
                VStack(spacing: 10) {
                    currentBadgeCard
                    recentActivityCard
                    collection
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(brand.displayName) streak details")
        .accessibilityIdentifier("dockHover.streak.detail")
    }

    private var detailHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 26, height: 26)
                    .background(theme.opaqueSurfaceInset)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(theme.outline, lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .help("Back to dashboard")
            .accessibilityLabel("Back to dashboard")
            .accessibilityIdentifier("dockHover.streak.back")

            VStack(alignment: .leading, spacing: 1) {
                Text("Streak & badges")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Text("Active token days · earned badges stay unlocked")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 0)

            Image(brand.logoAssetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
        }
        .frame(height: 34)
    }

    private var currentBadgeCard: some View {
        HStack(spacing: 15) {
            StreakBadgeView(
                milestone: summary?.earnedBadge ?? .firstPrompt,
                size: 112,
                isUnlocked: summary?.earnedBadge != nil
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("CURRENT BADGE")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(theme.textTertiary)

                Text(summary?.earnedBadge?.title ?? "Ready to begin")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text(currentBadgeDetail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 13) {
                    heroMetric(value: summary.map { "\($0.currentDays)" } ?? "—", label: "CURRENT")
                    heroMetric(value: summary.map { "\($0.bestDays)" } ?? "—", label: "BEST")
                    heroMetric(value: nextMetricValue, label: "TO NEXT")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
    }

    private func heroMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var currentBadgeDetail: String {
        guard let summary else {
            return "Streak data will appear after local usage is available."
        }
        guard let badge = summary.earnedBadge else {
            return "Use tokens today to unlock First Prompt."
        }
        if summary.currentDays == 0 {
            return "\(badge.detail) Start a new streak today; earned badges are safe."
        }
        return badge.detail
    }

    private var nextMetricValue: String {
        guard let days = summary?.daysUntilNextBadge else { return "—" }
        return "\(days)d"
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 4)
                Text("Token use marks an active day")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }

            if let days = summary?.recentDays {
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        StreakDayNode(day: day, accent: accent, compact: false)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text("No recent-day data available")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            }
        }
        .padding(10)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("Badge collection")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 4)
                Text(collectionCountLabel)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(TokenUsageStreakMilestone.allCases) { milestone in
                    collectionCell(milestone)
                }
            }
        }
    }

    private var collectionCountLabel: String {
        let count = summary?.earnedMilestones.count ?? 0
        return "\(count) of \(TokenUsageStreakMilestone.allCases.count) unlocked"
    }

    private func collectionCell(
        _ milestone: TokenUsageStreakMilestone
    ) -> some View {
        let isUnlocked = (summary?.bestDays ?? 0) >= milestone.requiredDays
        let isCurrent = summary?.earnedBadge == milestone

        return HStack(spacing: 8) {
            StreakBadgeView(
                milestone: milestone,
                size: 58,
                isUnlocked: isUnlocked,
                showsLock: true
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(
                        isUnlocked ? theme.textPrimary : theme.textSecondary
                    )
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 7, weight: .bold))
                        .accessibilityHidden(true)
                    Text("\(milestone.requiredDays) days")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(isUnlocked ? accent : theme.textTertiary)

                if isCurrent {
                    Text("Current")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(isCurrent ? theme.selectionFill : theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isCurrent ? theme.selectionOutline : theme.outline,
                    lineWidth: isCurrent ? 1 : 0.5
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dockHover.streak.badge.\(milestone.rawValue)")
    }
}

private struct StreakDayNode: View {
    let day: TokenUsageStreakDay
    let accent: Color
    let compact: Bool

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            Text(weekdayInitial)
                .font(.system(
                    size: compact ? 8 : 9,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(theme.textSecondary)
                .frame(
                    width: nodeSize,
                    height: compact ? 10 : 12,
                    alignment: .center
                )

            node
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
        .accessibilityValue(stateLabel)
    }

    private var nodeSize: CGFloat { compact ? 14 : 22 }

    private var weekdayInitial: String {
        String(
            day.date
                .formatted(.dateTime.weekday(.narrow))
                .prefix(1)
        ).uppercased()
    }

    @ViewBuilder
    private var node: some View {
        switch day.state {
        case .active:
            Circle()
                .fill(accent)
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    Image(systemName: "checkmark")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: compact ? 5 : 8, weight: .black))
                        .foregroundStyle(theme.onAction)
                }
        case .inactive:
            Circle()
                .strokeBorder(theme.outlineStrong, lineWidth: 1)
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    Rectangle()
                        .fill(theme.textTertiary)
                        .frame(width: nodeSize * 0.38, height: 1)
                }
        case .unknown:
            Circle()
                .strokeBorder(theme.outline, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    Text("?")
                        .font(.system(size: compact ? 6 : 8, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                }
        case .todayPending:
            Circle()
                .strokeBorder(accent, lineWidth: 1.5)
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    Circle()
                        .fill(accent)
                        .frame(width: compact ? 3 : 5, height: compact ? 3 : 5)
                }
        }
    }

    private var stateLabel: String {
        switch day.state {
        case .active: "Active"
        case .inactive: "No token activity"
        case .unknown: "Activity unknown"
        case .todayPending: "Today, not active yet"
        }
    }
}
