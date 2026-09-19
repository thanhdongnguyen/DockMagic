import AppKit
import SwiftUI

enum StreakServiceBrand: Sendable {
    case codex
    case claudeCode
    case antigravity
    case openCode
    case grokBuild
    case augment

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        case .antigravity: "Antigravity"
        case .grokBuild: "Grok Build"
        case .openCode: "OpenCode"
        case .augment: "Augment"
        }
    }

    var logoAssetName: String {
        switch self {
        case .codex: "CodexLogo"
        case .claudeCode: "ClaudeCodeLogo"
        case .antigravity: "AntigravityLogo"
        case .grokBuild: ""
        case .openCode: "OpenCodeLogo"
        case .augment: "AugmentLogo"
        }
    }
}

struct PreservedVectorAssetImage: View {
    let assetName: String

    private var artwork: Image {
        guard let source = NSImage(named: NSImage.Name(assetName)),
              let copy = source.copy() as? NSImage else {
            return Image(assetName)
        }
        // Asset-catalog SVGs share their named NSImage globally. Disable the
        // shared raster cache so one small presentation cannot degrade a
        // later larger presentation of the same vector artwork.
        copy.cacheMode = .never
        return Image(nsImage: copy)
    }

    var body: some View {
        artwork
            .resizable()
            .interpolation(.high)
    }
}

struct StreakBadgeView: View {
    let milestone: TokenUsageStreakMilestone
    let size: CGFloat
    var isUnlocked = true
    var showsLock = false

    @Environment(\.designTheme) private var theme

    var body: some View {
        ZStack {
            PreservedVectorAssetImage(assetName: milestone.assetName)
                .scaledToFit()
                .saturation(isUnlocked ? 1 : 0)
                .opacity(isUnlocked ? 1 : 0.34)

            if showsLock && !isUnlocked {
                DSIcon(systemName: "lock.fill")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: max(8, size * 0.13), weight: .bold)
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
                .dsFont(size: 9, weight: .bold)
                .tracking(1.7)
                .foregroundStyle(theme.textSecondary)
                .offset(y: -8)
                .zIndex(1)

            badgeHero
                .padding(.top, 7)

            Text("Streak secured")
                .dsFont(size: 28, weight: .bold)
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
            .dsFont(size: 12, weight: .semibold)
            .padding(.top, 2)

            recentDays
                .padding(.top, 12)

            Text(nextMilestoneLabel)
                .dsFont(size: 11, weight: .semibold)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .padding(.top, 9)

            Spacer(minLength: 7)

            Button(action: onViewBadges) {
                Text("View badges")
                    .dsFont(size: 10, weight: .semibold)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DSContentButtonStyle())
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
                .dsFont(size: 8.5, weight: .medium)
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
                .dsFont(size: 17, weight: .bold)
                .foregroundStyle(theme.textPrimary)

            if let planLabel, !planLabel.isEmpty {
                celebrationPlanBadge(planLabel)
            }

            Spacer(minLength: 4)

            if let trailingMetricValue, let trailingMetricLabel {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(trailingMetricValue)
                        .dsFont(size: 14, weight: .bold)
                        .foregroundStyle(theme.textPrimary)
                    Text(trailingMetricLabel)
                        .dsFont(size: 10, weight: .medium)
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
            PreservedVectorAssetImage(assetName: brand.logoAssetName)
                .scaledToFill()
                .frame(width: 42, height: 42)
                .frame(width: 26, height: 26)
                .clipShape(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)
        case .grokBuild:
            GrokBuildIdentityMark()
        case .claudeCode, .antigravity, .openCode, .augment:
            PreservedVectorAssetImage(assetName: brand.logoAssetName)
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
                DSIcon(systemName: "crown.fill")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 9, weight: .bold)
                    .accessibilityHidden(true)
            }

            Text(plan.localizedUppercase)
                .dsFont(size: 10, weight: .bold)
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

            DSIcon(systemName: "hexagon")
                .symbolRenderingMode(.monochrome)
                .dsFont(size: 12, weight: .semibold)
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

enum ContinuityStripPresentation: Sendable {
    case tokenStreak
    case organizationActivity
}

enum StreakUnknownDayStyle: Sendable {
    case questionMark
    case dash
}

struct StreakContinuityStrip: View {
    let summary: TokenUsageStreakSummary?
    let brand: StreakServiceBrand
    let accent: Color
    var currentDayIsUnknown = false
    var presentation: ContinuityStripPresentation = .tokenStreak
    var unknownDayStyle: StreakUnknownDayStyle = .questionMark
    let onOpen: () -> Void

    @Environment(\.designTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 9) {
                leadingMark

                VStack(alignment: .leading, spacing: 2) {
                    Text(streakTitle)
                        .dsFont(size: 11, weight: .bold)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(streakSubtitle)
                        .dsFont(size: 8.5, weight: .medium)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: presentation == .organizationActivity ? 92 : 78, alignment: .leading)

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
                        .dsFont(size: 9.5, weight: .bold)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text(progressSubtitle)
                        .dsFont(size: 8, weight: .medium)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: 60, alignment: .trailing)

                DSIcon(systemName: "chevron.right")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 9, weight: .bold)
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
        .buttonStyle(DSContentButtonStyle())
        .onHover { isHovered = $0 }
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var leadingMark: some View {
        switch presentation {
        case .tokenStreak:
            StreakBadgeView(
                milestone: summary?.earnedBadge ?? .firstPrompt,
                size: 48,
                isUnlocked: summary?.earnedBadge != nil
            )
        case .organizationActivity:
            DSIcon(.activity, size: 24)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.outline, lineWidth: 0.5)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
    }

    private var streakTitle: String {
        switch presentation {
        case .tokenStreak:
            guard let summary else { return "Streak unavailable" }
            return currentDayIsUnknown ? "Streak unknown" : "\(summary.currentDays)-day streak"
        case .organizationActivity:
            guard let summary else { return "Activity unavailable" }
            return currentDayIsUnknown ? "Activity unknown" : "\(summary.currentDays)-day activity"
        }
    }

    private var streakSubtitle: String {
        guard let summary else { return "Waiting for usage data" }
        switch presentation {
        case .tokenStreak:
            if let earned = summary.earnedBadge {
                return "\(earned.title) · best \(summary.bestDays)"
            }
            return "Use tokens to begin"
        case .organizationActivity:
            return "Organization · best \(summary.bestDays)"
        }
    }

    private var progressTitle: String {
        guard !currentDayIsUnknown else { return "—" }
        guard let summary else { return "—" }
        switch presentation {
        case .tokenStreak:
            guard let days = summary.daysUntilNextBadge else { return "Complete" }
            return "\(days)d"
        case .organizationActivity:
            return "\(summary.bestDays)d"
        }
    }

    private var progressSubtitle: String {
        guard let summary else { return "No data" }
        switch presentation {
        case .tokenStreak:
            return summary.nextBadge?.title ?? "All earned"
        case .organizationActivity:
            return "Best run"
        }
    }

    private var accessibilityValue: String {
        guard let summary else { return presentation == .tokenStreak ? "Streak data unavailable" : "Organization activity data unavailable" }
        switch presentation {
        case .tokenStreak:
            let badge = summary.earnedBadge?.title ?? "No badge earned"
            return currentDayIsUnknown ? "Current streak unknown, best \(summary.bestDays) verified days, \(badge)" : "\(summary.currentDays) day current streak, best \(summary.bestDays) days, \(badge)"
        case .organizationActivity:
            return currentDayIsUnknown ? "Current organization activity run unknown, best \(summary.bestDays) reported days" : "\(summary.currentDays) day organization activity run, best \(summary.bestDays) days"
        }
    }

    private var helpText: String {
        presentation == .tokenStreak ? "Open streak badges" : "Open organization activity continuity"
    }

    private var accessibilityLabel: String {
        presentation == .tokenStreak
            ? "Open \(brand.displayName) streak details"
            : "Open \(brand.displayName) organization activity details"
    }

    private var accessibilityHint: String {
        presentation == .tokenStreak
            ? "Shows the current badge and all streak milestones"
            : "Shows reported UTC activity continuity and output intensity"
    }

    private var accessibilityIdentifier: String {
        if brand == .grokBuild { return "grokBuild.streak.open" }
        if brand == .augment { return "augment.continuity.open" }
        return "dockHover.streak.open"
    }

    private func recentDayStrip(_ days: [TokenUsageStreakDay]) -> some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                StreakDayNode(
                    day: day,
                    accent: accent,
                    compact: true,
                    unknownDayStyle: unknownDayStyle
                )
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
    var currentDayIsUnknown = false
    var handlesEscape = false
    var unknownDayStyle: StreakUnknownDayStyle = .questionMark
    let onBack: () -> Void

    @Environment(\.designTheme) private var theme

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
        .accessibilityIdentifier(brand == .grokBuild ? "grokBuild.streak.detail" : "dockHover.streak.detail")
    }

    private var detailHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                DSIcon(systemName: "chevron.left")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 10, weight: .bold)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 26, height: 26)
                    .background(theme.opaqueSurfaceInset)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(theme.outline, lineWidth: 0.5)
                    }
            }
            .buttonStyle(DSContentButtonStyle())
            .help("Back to dashboard")
            .accessibilityLabel("Back to dashboard")
            .accessibilityIdentifier(brand == .grokBuild ? "grokBuild.streak.back" : "dockHover.streak.back")
            .keyboardShortcut(handlesEscape ? .cancelAction : nil)

            VStack(alignment: .leading, spacing: 1) {
                Text("Streak & badges")
                    .dsFont(size: 15, weight: .bold)
                    .foregroundStyle(theme.textPrimary)
                Text("Active token days · earned badges stay unlocked")
                    .dsFont(size: 8.5, weight: .medium)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 0)

            Group {
                if brand == .grokBuild { GrokBuildIdentityMark() }
                else { PreservedVectorAssetImage(assetName: brand.logoAssetName).scaledToFit() }
            }
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
                    .dsFont(size: 8, weight: .bold)
                    .tracking(0.8)
                    .foregroundStyle(theme.textTertiary)

                Text(summary?.earnedBadge?.title ?? "Ready to begin")
                    .dsFont(size: 17, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Text(currentBadgeDetail)
                    .dsFont(size: 9, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 13) {
                    heroMetric(value: currentDayIsUnknown ? "—" : summary.map { "\($0.currentDays)" } ?? "—", label: "CURRENT")
                    heroMetric(value: summary.flatMap { currentDayIsUnknown && $0.bestDays == 0 ? nil : "\($0.bestDays)" } ?? "—", label: "BEST")
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
                .dsFont(size: 14, weight: .bold)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .dsFont(size: 7, weight: .bold)
                .foregroundStyle(theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var currentBadgeDetail: String {
        if currentDayIsUnknown { return "Today's activity is unknown. Verified badges remain unlocked; unknown days do not bridge a streak." }
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
        guard !currentDayIsUnknown else { return "—" }
        guard let days = summary?.daysUntilNextBadge else { return "—" }
        return "\(days)d"
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent activity")
                    .dsFont(size: 10.5, weight: .bold)
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 4)
                Text("Token use marks an active day")
                    .dsFont(size: 8, weight: .medium)
                    .foregroundStyle(theme.textTertiary)
            }

            if let days = summary?.recentDays {
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        StreakDayNode(
                            day: day,
                            accent: theme.action,
                            compact: false,
                            unknownDayStyle: unknownDayStyle
                        )
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text("No recent-day data available")
                    .dsFont(size: 9, weight: .medium)
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Badge roadmap")
                        .dsFont(size: 11, weight: .bold)
                        .foregroundStyle(theme.textPrimary)

                    Text("Build momentum one active day at a time")
                        .dsFont(size: 8.5, weight: .medium)
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer(minLength: 4)

                Text(collectionCountLabel)
                    .dsFont(size: 8.5, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }

            StreakBadgeRoadmap(
                milestones: TokenUsageStreakMilestone.allCases,
                bestDays: summary?.bestDays,
                currentMilestone: summary?.earnedBadge,
                nextMilestone: summary?.nextBadge
            )
        }
    }

    private var collectionCountLabel: String {
        guard let summary else { return "Progress unavailable" }
        let count = summary.earnedMilestones.count
        return "\(count) of \(TokenUsageStreakMilestone.allCases.count) unlocked"
    }
}

private struct StreakBadgeRoadmap: View {
    let milestones: [TokenUsageStreakMilestone]
    let bestDays: Int64?
    let currentMilestone: TokenUsageStreakMilestone?
    let nextMilestone: TokenUsageStreakMilestone?

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.designTheme) private var theme

    private let rowHeight: CGFloat = 98
    private let horizontalInset: CGFloat = 39

    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { _ in
                let path = StreakRoadmapPath(
                    milestoneCount: milestones.count,
                    rowHeight: rowHeight,
                    horizontalInset: horizontalInset
                )
                let completedPath = StreakRoadmapPath(
                    milestoneCount: milestones.count,
                    rowHeight: rowHeight,
                    horizontalInset: horizontalInset,
                    reachedMilestoneCount: unlockedCount
                )

                path
                    .stroke(
                        theme.outline,
                        style: StrokeStyle(
                            lineWidth: isIncreasedContrast ? 12 : 10,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                path
                    .stroke(
                        theme.outlineStrong,
                        style: StrokeStyle(
                            lineWidth: isIncreasedContrast ? 2 : 1.25,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [5, 7]
                        )
                    )

                completedPath
                    .stroke(
                        theme.action,
                        style: StrokeStyle(
                            lineWidth: isIncreasedContrast ? 5 : 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                ForEach(milestones.indices, id: \.self) { index in
                    milestoneRow(milestones[index], index: index)
                }
            }
        }
        .frame(height: rowHeight * CGFloat(milestones.count))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.opaqueSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.outline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Badge roadmap")
    }

    private var unlockedCount: Int {
        guard let bestDays else { return 0 }
        return milestones.filter { bestDays >= $0.requiredDays }.count
    }

    private var isIncreasedContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }

    private func milestoneRow(
        _ milestone: TokenUsageStreakMilestone,
        index: Int
    ) -> some View {
        let isLeading = index.isMultiple(of: 2)

        return HStack(spacing: 8) {
            if isLeading {
                badgeSlot(for: milestone)
                milestoneLabel(for: milestone, alignment: .leading)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                milestoneLabel(for: milestone, alignment: .trailing)
                badgeSlot(for: milestone)
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: milestone))
        .accessibilityIdentifier("dockHover.streak.badge.\(milestone.rawValue)")
    }

    private func badgeSlot(
        for milestone: TokenUsageStreakMilestone
    ) -> some View {
        let isUnlocked = bestDays.map { $0 >= milestone.requiredDays } ?? false
        let isCurrent = currentMilestone == milestone

        return ZStack {
            Circle()
                .fill(theme.opaqueSurfaceRaised)
                .overlay {
                    Circle().strokeBorder(theme.outline, lineWidth: 0.5)
                }
                .frame(
                    width: isCurrent ? 80 : 74,
                    height: isCurrent ? 80 : 74
                )

            StreakBadgeView(
                milestone: milestone,
                size: isCurrent ? 75 : 69,
                isUnlocked: isUnlocked,
                showsLock: bestDays != nil
            )
        }
        .frame(width: 78, height: rowHeight)
        .accessibilityHidden(true)
    }

    private func milestoneLabel(
        for milestone: TokenUsageStreakMilestone,
        alignment: HorizontalAlignment
    ) -> some View {
        let isCurrent = currentMilestone == milestone

        return VStack(alignment: alignment, spacing: 3) {
            Text("DAY \(milestone.requiredDays)")
                .dsFont(size: 7.5, weight: .bold)
                .tracking(0.65)
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()

            Text(milestone.title)
                .dsFont(size: 11, weight: .bold)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 3) {
                DSIcon(systemName: statusSymbol(for: milestone))
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 7, weight: .bold)
                    .accessibilityHidden(true)

                Text(statusLabel(for: milestone))
                    .dsFont(size: 8, weight: .semibold)
            }
            .foregroundStyle(isCurrent ? theme.action : theme.textSecondary)

            Text(milestone.detail)
                .dsFont(size: 7.5, weight: .medium)
                .foregroundStyle(theme.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(width: 146, alignment: frameAlignment(for: alignment))
        .frame(minHeight: 72, alignment: frameAlignment(for: alignment))
        .background(isCurrent ? theme.selectionFill : theme.opaqueSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isCurrent ? theme.selectionOutline : theme.outline,
                    lineWidth: isCurrent ? 1 : 0.5
                )
        }
    }

    private func statusLabel(
        for milestone: TokenUsageStreakMilestone
    ) -> String {
        guard let bestDays else {
            return "Progress unavailable"
        }
        if currentMilestone == milestone {
            return "Current badge"
        }
        if bestDays >= milestone.requiredDays {
            return "Earned"
        }
        if nextMilestone == milestone {
            return "Up next"
        }
        return "Locked"
    }

    private func statusSymbol(
        for milestone: TokenUsageStreakMilestone
    ) -> String {
        guard let bestDays else {
            return "questionmark.circle"
        }
        if currentMilestone == milestone {
            return "location.fill"
        }
        if bestDays >= milestone.requiredDays {
            return "checkmark.circle.fill"
        }
        if nextMilestone == milestone {
            return "flag.fill"
        }
        return "lock.fill"
    }

    private func accessibilityLabel(
        for milestone: TokenUsageStreakMilestone
    ) -> String {
        "\(milestone.title), day \(milestone.requiredDays), "
            + "\(statusLabel(for: milestone)). \(milestone.detail)"
    }

    private func frameAlignment(
        for alignment: HorizontalAlignment
    ) -> Alignment {
        alignment == .leading ? .leading : .trailing
    }
}

struct StreakRoadmapPath: Shape {
    let milestoneCount: Int
    let rowHeight: CGFloat
    let horizontalInset: CGFloat
    let reachedMilestoneCount: Int?

    init(
        milestoneCount: Int,
        rowHeight: CGFloat,
        horizontalInset: CGFloat,
        reachedMilestoneCount: Int? = nil
    ) {
        self.milestoneCount = milestoneCount
        self.rowHeight = rowHeight
        self.horizontalInset = horizontalInset
        self.reachedMilestoneCount = reachedMilestoneCount
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let visibleMilestoneCount = min(
            max(reachedMilestoneCount ?? milestoneCount, 0),
            milestoneCount
        )
        guard visibleMilestoneCount > 0 else { return path }

        func point(for index: Int) -> CGPoint {
            CGPoint(
                x: index.isMultiple(of: 2)
                    ? horizontalInset
                    : rect.width - horizontalInset,
                y: rowHeight * (CGFloat(index) + 0.5)
            )
        }

        let firstPoint = point(for: 0)
        path.move(to: CGPoint(x: firstPoint.x, y: rect.minY))
        path.addLine(to: firstPoint)

        if visibleMilestoneCount > 1 {
            for index in 1..<visibleMilestoneCount {
                let previousPoint = point(for: index - 1)
                let nextPoint = point(for: index)
                let middleY = (previousPoint.y + nextPoint.y) / 2

                path.addCurve(
                    to: nextPoint,
                    control1: CGPoint(x: previousPoint.x, y: middleY),
                    control2: CGPoint(x: nextPoint.x, y: middleY)
                )
            }
        }

        guard reachedMilestoneCount == nil else { return path }
        let lastPoint = point(for: milestoneCount - 1)
        path.addLine(to: CGPoint(x: lastPoint.x, y: rect.maxY))
        return path
    }
}

private struct StreakDayNode: View {
    let day: TokenUsageStreakDay
    let accent: Color
    let compact: Bool
    var unknownDayStyle: StreakUnknownDayStyle = .questionMark

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            Text(weekdayInitial)
                .dsFont(
                    size: compact ? 8 : 9,
                    weight: .bold,
                    design: .rounded
                )
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
                .fill(theme.streakActive)
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    DSIcon(systemName: "checkmark")
                        .symbolRenderingMode(.monochrome)
                        .dsFont(size: compact ? 8 : 12, weight: .black)
                        .foregroundStyle(theme.onStreakActive)
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
            switch unknownDayStyle {
            case .questionMark:
                Circle()
                    .strokeBorder(theme.outline, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay {
                        Text("?")
                            .dsFont(size: compact ? 6 : 8, weight: .bold)
                            .foregroundStyle(theme.textTertiary)
                    }
            case .dash:
                Circle()
                    .strokeBorder(theme.outlineStrong, lineWidth: 1)
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay {
                        Rectangle()
                            .fill(theme.textTertiary)
                            .frame(width: nodeSize * 0.38, height: 1)
                    }
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
