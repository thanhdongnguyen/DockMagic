import Foundation
import SwiftData

enum TokenUsageProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claudeCode
    case antigravity
    case grokBuild
    case openCode

    init?(rawValue: String) {
        switch rawValue {
        case "codex": self = .codex
        case "claudeCode": self = .claudeCode
        case "antigravity": self = .antigravity
        case "grokBuild": self = .grokBuild
        case "openCode": self = .openCode
        default: return nil
        }
    }
}

@Model
final class TokenUsageStreakDayRecord {
    @Attribute(.unique) var identifier: String
    var providerRawValue: String
    var dayKey: String
    var dayIndex: Int
    var tokenCount: Int64
    var firstObservedAt: Date
    var lastObservedAt: Date
    var celebrationShownAt: Date?

    init(
        identifier: String,
        providerRawValue: String,
        dayKey: String,
        dayIndex: Int,
        tokenCount: Int64,
        firstObservedAt: Date,
        lastObservedAt: Date,
        celebrationShownAt: Date? = nil
    ) {
        self.identifier = identifier
        self.providerRawValue = providerRawValue
        self.dayKey = dayKey
        self.dayIndex = dayIndex
        self.tokenCount = tokenCount
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.celebrationShownAt = celebrationShownAt
    }
}

struct TokenUsageStreakRecordValue: Equatable, Sendable {
    let identifier: String
    let provider: TokenUsageProvider
    let dayKey: String
    let dayIndex: Int
    let tokenCount: Int64
    let firstObservedAt: Date
    let lastObservedAt: Date
    let celebrationShownAt: Date?

    init(
        identifier: String,
        provider: TokenUsageProvider,
        dayKey: String,
        dayIndex: Int,
        tokenCount: Int64,
        firstObservedAt: Date,
        lastObservedAt: Date,
        celebrationShownAt: Date? = nil
    ) {
        self.identifier = identifier
        self.provider = provider
        self.dayKey = dayKey
        self.dayIndex = dayIndex
        self.tokenCount = tokenCount
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.celebrationShownAt = celebrationShownAt
    }
}

struct TokenUsageStreakCelebration: Equatable, Identifiable, Sendable {
    let provider: TokenUsageProvider
    let dayKey: String
    let achievedAt: Date
    let presentedAt: Date
    let summary: TokenUsageStreakSummary

    var id: String { "\(provider.rawValue)|\(dayKey)" }
}

struct TokenUsageCalendarDay: Equatable, Sendable {
    let key: String
    let index: Int
    let startDate: Date

    static func containing(
        _ date: Date,
        calendar inputCalendar: Calendar = .current
    ) -> Self {
        let components = inputCalendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let key = String(format: "%04d-%02d-%02d", year, month, day)

        var canonicalCalendar = Calendar(identifier: .gregorian)
        canonicalCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let canonicalDate = canonicalCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )) ?? Date(timeIntervalSince1970: 0)
        let index = Int(
            floor(canonicalDate.timeIntervalSince1970 / 86_400)
        )
        let startDate = inputCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )) ?? inputCalendar.startOfDay(for: date)

        return Self(key: key, index: index, startDate: startDate)
    }
}

enum TokenUsageStreakCalculator {
    static let recentDayCount = 7

    enum Coverage: Sendable {
        /// Preserve the original provider behavior, including todayPending.
        case legacy
        /// Positive observations prove activity, not inactivity between them.
        case observedOnly
    }

    static func summary(
        from records: [TokenUsageStreakRecordValue],
        now: Date = .now,
        calendar: Calendar = .current,
        coverage: Coverage = .legacy
    ) -> TokenUsageStreakSummary {
        let activeDayIndices = Set(
            records.filter { $0.tokenCount > 0 }.map(\.dayIndex)
        )
        return summary(activeDayIndices: activeDayIndices, now: now, calendar: calendar, coverage: coverage)
    }

    static func summary(
        activeDayIndices: Set<Int>, now: Date = .now,
        calendar: Calendar = .current, coverage: Coverage,
        retainedBestDays: Int64 = 0
    ) -> TokenUsageStreakSummary {
        let sortedDays = activeDayIndices.sorted()
        let today = TokenUsageCalendarDay.containing(
            now,
            calendar: calendar
        )

        let currentEndpoint = coverage == .observedOnly || activeDayIndices.contains(today.index)
            ? today.index
            : today.index - 1
        var currentDays: Int64 = 0
        var cursor = currentEndpoint
        while activeDayIndices.contains(cursor) {
            currentDays += 1
            cursor -= 1
        }

        var longestDays: Int64 = 0
        var runningDays: Int64 = 0
        var previousDay: Int?
        for dayIndex in sortedDays {
            if let previousDay, dayIndex == previousDay + 1 {
                runningDays += 1
            } else {
                runningDays = 1
            }
            longestDays = max(longestDays, runningDays)
            previousDay = dayIndex
        }

        // A verified achievement survives retention and calendar changes.
        // Existing providers keep the default zero and their original formula.
        longestDays = max(longestDays, retainedBestDays)
        let earnedBadge = TokenUsageStreakMilestone.highestUnlocked(
            for: longestDays
        )
        let nextBadge = TokenUsageStreakMilestone.nextLocked(
            after: longestDays
        )
        let previousBadge: TokenUsageStreakMilestone? = earnedBadge.flatMap {
            earned in
            guard
                let index = TokenUsageStreakMilestone.allCases.firstIndex(
                    of: earned
                ),
                index > TokenUsageStreakMilestone.allCases.startIndex
            else {
                return nil
            }
            return TokenUsageStreakMilestone.allCases[
                TokenUsageStreakMilestone.allCases.index(before: index)
            ]
        }
        let firstTrackedDay = sortedDays.first

        let recentDays: [TokenUsageStreakDay] = (0..<recentDayCount)
            .compactMap { offset -> TokenUsageStreakDay? in
                guard let date = calendar.date(
                    byAdding: .day,
                    value: offset - (recentDayCount - 1),
                    to: today.startDate
                ) else {
                    return nil
                }
                let day = TokenUsageCalendarDay.containing(
                    date,
                    calendar: calendar
                )
                let state: TokenUsageStreakDay.State
                if activeDayIndices.contains(day.index) {
                    state = .active
                } else if coverage == .observedOnly {
                    state = .unknown
                } else if day.index == today.index {
                    state = .todayPending
                } else if let firstTrackedDay, day.index >= firstTrackedDay {
                    state = .inactive
                } else {
                    state = .unknown
                }
                return TokenUsageStreakDay(
                    date: day.startDate,
                    state: state
                )
            }

        return TokenUsageStreakSummary(
            currentDays: currentDays,
            bestDays: longestDays,
            earnedBadge: earnedBadge,
            previousBadge: previousBadge,
            nextBadge: nextBadge,
            daysUntilNextBadge: nextBadge.map {
                max(0, $0.requiredDays - currentDays)
            },
            recentDays: recentDays
        )
    }
}
