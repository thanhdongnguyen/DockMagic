import Foundation
import Observation
import SwiftData

@MainActor
protocol TokenUsageStreakTracking: AnyObject {
    func observeToday(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar
    ) -> TokenUsageStreakSummary

    func observeHistory(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar
    ) -> TokenUsageStreakSummary
}

extension TokenUsageStreakTracking {
    func observeToday(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date
    ) -> TokenUsageStreakSummary {
        observeToday(
            provider: provider,
            tokenUsage: tokenUsage,
            at: observedAt,
            calendar: .current
        )
    }

    func observeHistory(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date
    ) -> TokenUsageStreakSummary {
        observeHistory(
            provider: provider,
            tokenUsage: tokenUsage,
            at: observedAt,
            calendar: .current
        )
    }

    func observeHistory(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar
    ) -> TokenUsageStreakSummary {
        observeToday(
            provider: provider,
            tokenUsage: tokenUsage,
            at: observedAt,
            calendar: calendar
        )
    }
}

@MainActor
@Observable
final class TokenUsageStreakStore: TokenUsageStreakTracking {
    private(set) var records: [TokenUsageStreakRecordValue]
    private(set) var persistenceErrorDescription: String?

    @ObservationIgnored
    private let modelContainer: ModelContainer
    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private var modelRecordsByIdentifier: [String: TokenUsageStreakDayRecord]

    init(modelContainer: ModelContainer? = nil) {
        let container = modelContainer ?? Self.makeDefaultContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TokenUsageStreakDayRecord>(
            sortBy: [SortDescriptor(\TokenUsageStreakDayRecord.dayIndex)]
        )
        let storedRecords = (try? context.fetch(descriptor)) ?? []

        self.modelContainer = container
        self.context = context
        self.modelRecordsByIdentifier = Dictionary(
            uniqueKeysWithValues: storedRecords.map { ($0.identifier, $0) }
        )
        self.records = storedRecords.compactMap(Self.value(from:))
    }

    func observeToday(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar = .current
    ) -> TokenUsageStreakSummary {
        let tokensToday = tokenUsage?.dailyUsageBuckets.reduce(
            into: Int64(0)
        ) { total, bucket in
            if calendar.isDate(bucket.startDate, inSameDayAs: observedAt) {
                total += max(0, bucket.tokens)
            }
        } ?? 0

        if tokensToday > 0 {
            persistActiveDay(
                provider: provider,
                tokens: tokensToday,
                observedAt: observedAt,
                calendar: calendar
            )
        }

        return summary(for: provider, at: observedAt, calendar: calendar)
    }

    func observeHistory(
        provider: TokenUsageProvider,
        tokenUsage: CodexAccountTokenUsage?,
        at observedAt: Date,
        calendar: Calendar = .current
    ) -> TokenUsageStreakSummary {
        for bucket in tokenUsage?.dailyUsageBuckets ?? [] where
            bucket.tokens > 0 && bucket.startDate <= observedAt
        {
            let sampleDate = calendar.isDate(
                bucket.startDate,
                inSameDayAs: observedAt
            ) ? observedAt : bucket.startDate
            persistActiveDay(
                provider: provider,
                tokens: bucket.tokens,
                observedAt: sampleDate,
                calendar: calendar
            )
        }
        return summary(for: provider, at: observedAt, calendar: calendar)
    }

    func summary(
        for provider: TokenUsageProvider,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> TokenUsageStreakSummary {
        TokenUsageStreakCalculator.summary(
            from: records.filter { $0.provider == provider },
            now: date,
            calendar: calendar
        )
    }

    /// Returns today's celebration once for each provider and persists the
    /// claim in the same SwiftData record that owns the active streak day.
    func claimCelebration(
        for provider: TokenUsageProvider,
        at presentedAt: Date = .now,
        calendar: Calendar = .current
    ) -> TokenUsageStreakCelebration? {
        let day = TokenUsageCalendarDay.containing(
            presentedAt,
            calendar: calendar
        )
        let identifier = "\(provider.rawValue)|\(day.key)"
        guard
            let record = modelRecordsByIdentifier[identifier],
            record.tokenCount > 0,
            record.celebrationShownAt == nil
        else {
            return nil
        }

        let streakSummary = summary(
            for: provider,
            at: presentedAt,
            calendar: calendar
        )
        guard streakSummary.hasActivityToday else {
            return nil
        }

        record.celebrationShownAt = presentedAt
        do {
            try context.save()
            persistenceErrorDescription = nil
            reloadValues()
            return TokenUsageStreakCelebration(
                provider: provider,
                dayKey: day.key,
                achievedAt: record.firstObservedAt,
                presentedAt: presentedAt,
                summary: streakSummary
            )
        } catch {
            context.rollback()
            persistenceErrorDescription = error.localizedDescription
            reloadModelRecords()
            return nil
        }
    }

    static func inMemoryContainer() -> ModelContainer {
        let schema = Schema([TokenUsageStreakDayRecord.self])
        let configuration = ModelConfiguration(
            "TokenUsageStreakTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(
            for: schema,
            configurations: configuration
        )
    }

    private func persistActiveDay(
        provider: TokenUsageProvider,
        tokens: Int64,
        observedAt: Date,
        calendar: Calendar
    ) {
        let day = TokenUsageCalendarDay.containing(
            observedAt,
            calendar: calendar
        )
        let identifier = "\(provider.rawValue)|\(day.key)"

        if let record = modelRecordsByIdentifier[identifier] {
            record.tokenCount = max(record.tokenCount, tokens)
            record.lastObservedAt = observedAt
        } else {
            let record = TokenUsageStreakDayRecord(
                identifier: identifier,
                providerRawValue: provider.rawValue,
                dayKey: day.key,
                dayIndex: day.index,
                tokenCount: tokens,
                firstObservedAt: observedAt,
                lastObservedAt: observedAt
            )
            context.insert(record)
            modelRecordsByIdentifier[identifier] = record
        }

        do {
            try context.save()
            persistenceErrorDescription = nil
            reloadValues()
        } catch {
            context.rollback()
            persistenceErrorDescription = error.localizedDescription
            reloadModelRecords()
        }
    }

    private func reloadModelRecords() {
        let descriptor = FetchDescriptor<TokenUsageStreakDayRecord>(
            sortBy: [SortDescriptor(\TokenUsageStreakDayRecord.dayIndex)]
        )
        let storedRecords = (try? context.fetch(descriptor)) ?? []
        modelRecordsByIdentifier = Dictionary(
            uniqueKeysWithValues: storedRecords.map { ($0.identifier, $0) }
        )
        records = storedRecords.compactMap(Self.value(from:))
    }

    private func reloadValues() {
        records = modelRecordsByIdentifier.values
            .compactMap(Self.value(from:))
            .sorted {
                if $0.provider != $1.provider {
                    return $0.provider.rawValue < $1.provider.rawValue
                }
                return $0.dayIndex < $1.dayIndex
            }
    }

    private static func value(
        from record: TokenUsageStreakDayRecord
    ) -> TokenUsageStreakRecordValue? {
        guard let provider = TokenUsageProvider(
            rawValue: record.providerRawValue
        ) else {
            return nil
        }
        return TokenUsageStreakRecordValue(
            identifier: record.identifier,
            provider: provider,
            dayKey: record.dayKey,
            dayIndex: record.dayIndex,
            tokenCount: record.tokenCount,
            firstObservedAt: record.firstObservedAt,
            lastObservedAt: record.lastObservedAt,
            celebrationShownAt: record.celebrationShownAt
        )
    }

    private static func makeDefaultContainer() -> ModelContainer {
        let schema = Schema([TokenUsageStreakDayRecord.self])
        let configuration = ModelConfiguration(
            "TokenUsageStreak",
            schema: schema,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            let fallback = ModelConfiguration(
                "TokenUsageStreakFallback",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try! ModelContainer(
                for: schema,
                configurations: fallback
            )
        }
    }
}
