import SwiftUI

struct AugmentDockAppearance: Codable, Equatable, Sendable {
    enum Metric: String, CaseIterable, Identifiable, Codable { case tokens, billedUSD; var id: Self { self } }
    var metric: Metric = .tokens
    var displayStyle: DockDisplayStyle = .numeric
    var color: DockColor = ProjectTheme.defaultUsageRingColor
    var lineWidth: Double = 1.8
    static let standard = Self()
}

enum AugmentPresentation {
    static func dockMetrics(_ appearance: AugmentDockAppearance) -> [AugmentMetric] {
        appearance.metric == .tokens ? [.input, .output] : [.billedUSD]
    }
    static func trend(_ snapshot: AugmentUsageSnapshot?, metric: AugmentMetric) -> [Decimal?] {
        guard let snapshot else { return Array(repeating: nil, count: 7) }
        return snapshot.range.dates.suffix(7).map { snapshot.day($0)?.metrics.value(metric) }
    }
    static func dateLabel(_ date: Date?) -> String {
        guard let date else { return "No date" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = .current; formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func intensityBuckets(_ snapshot: AugmentUsageSnapshot) -> [CodexTokenUsageDailyBucket] {
        snapshot.range.dates.suffix(30).map { date in
            CodexTokenUsageDailyBucket(
                startDate: date,
                tokens: snapshot.day(date)?.metrics.output ?? 0
            )
        }
    }

    static func unavailableIntensityBucketIDs(_ snapshot: AugmentUsageSnapshot) -> Set<Date> {
        Set(snapshot.range.dates.suffix(30).filter { snapshot.day($0)?.metrics.output == nil })
    }

    static func organizationContinuity(_ snapshot: AugmentUsageSnapshot) -> TokenUsageStreakSummary {
        let dates = snapshot.range.dates
        let states = Dictionary(uniqueKeysWithValues: dates.map { date in
            (date, organizationActivityState(snapshot.day(date)))
        })

        var currentDays: Int64 = 0
        for date in dates.reversed() {
            guard states[date] == .active else { break }
            currentDays += 1
        }

        var bestDays: Int64 = 0
        var runningDays: Int64 = 0
        for date in dates {
            if states[date] == .active {
                runningDays += 1
                bestDays = max(bestDays, runningDays)
            } else {
                runningDays = 0
            }
        }

        let earnedBadge = TokenUsageStreakMilestone.highestUnlocked(for: bestDays)
        let nextBadge = TokenUsageStreakMilestone.nextLocked(after: bestDays)
        let previousBadge = earnedBadge.flatMap { earned -> TokenUsageStreakMilestone? in
            guard let index = TokenUsageStreakMilestone.allCases.firstIndex(of: earned), index > 0 else {
                return nil
            }
            return TokenUsageStreakMilestone.allCases[index - 1]
        }
        let recentDays = dates.suffix(TokenUsageStreakCalculator.recentDayCount).map { date in
            TokenUsageStreakDay(date: date, state: states[date] ?? .unknown)
        }

        return TokenUsageStreakSummary(
            currentDays: currentDays,
            bestDays: bestDays,
            earnedBadge: earnedBadge,
            previousBadge: previousBadge,
            nextBadge: nextBadge,
            daysUntilNextBadge: nextBadge.map { max(0, $0.requiredDays - currentDays) },
            recentDays: recentDays
        )
    }

    static func organizationEndpointIsUnknown(_ snapshot: AugmentUsageSnapshot) -> Bool {
        organizationActivityState(snapshot.day(snapshot.range.end)) == .unknown
    }

    private static func organizationActivityState(_ day: AugmentDailyBucket?) -> TokenUsageStreakDay.State {
        guard let metrics = day?.metrics else { return .unknown }
        let values: [Decimal?] = [
            metrics.input.map(Decimal.init),
            metrics.output.map(Decimal.init),
            metrics.cacheRead.map(Decimal.init),
            metrics.cacheWrite.map(Decimal.init),
            metrics.billedUSD,
            metrics.estimatedUSD,
        ]
        let reported = values.compactMap { $0 }
        guard !reported.isEmpty else { return .unknown }
        return reported.contains(where: { $0 > 0 }) ? .active : .inactive
    }
}
