import Foundation

struct GrokBuildContinuitySnapshot: Equatable, Sendable {
    let summary: TokenUsageStreakSummary
    /// The shared summary uses numeric fields for legacy providers. Grok UI
    /// must use this optional value: unknown today does NOT mean a broken run.
    var currentDays: Int64? { summary.hasActivityToday ? summary.currentDays : nil }
    var bestDays: Int64? { summary.bestDays > 0 ? summary.bestDays : nil }
}

struct GrokBuildStreakCelebration: Equatable, Identifiable, Sendable {
    let namespace: String
    let dayKey: String
    let observedAt: Date
    let presentedAt: Date
    let summary: TokenUsageStreakSummary
    var id: String { "\(TokenUsageProvider.grokBuild.rawValue)|\(namespace)|\(dayKey)" }
}

/// Durable activity-only witnesses. Keeping a UTC timestamp per hashed turn
/// (not its tokens, model, raw ID or content) permits exact day rebucketing and
/// replacing a delayed-fold timestamp after the 30-day detailed cache expires.
/// Missing/deleted sources cannot erase previously verified observations.
struct GrokBuildActivityLedger: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let namespace: String
    private(set) var beganAt: Date?
    private(set) var timeZoneIdentifier: String?
    private(set) var initialImportCompleted = false
    private(set) var witnesses: [String: Date] = [:]
    private(set) var bestVerifiedDays: Int64 = 0
    private(set) var celebratedDays: Set<String> = []
    private(set) var pendingDay: String?
    private(set) var pendingObservedAt: Date?

    init(namespace: String) { schemaVersion = 1; self.namespace = namespace }

    static func importing(_ history: GrokBuildHistoryLedger, at now: Date, calendar: Calendar) -> Self {
        var result = Self(namespace: history.namespace)
        result.beginObservation(at: now, calendar: calendar)
        let floor = GrokBuildHistoryLedger.windowStart(now: now, calendar: calendar)
        for (sessionKey, session) in history.sessions {
            // Match token eligibility when importing an older experimental
            // cache: a premature record must be revalidated at the source.
            for turn in session.turns where turn.tokens.total > 0 && turn.recordedAt >= floor
                && turn.recordedAt <= now && turn.recordedAt <= session.observedAt {
                result.witnesses[witnessKey(sessionKey: sessionKey, turn: turn.number)] = turn.recordedAt
            }
        }
        result.finishObservation(at: now, calendar: calendar)
        result.initialImportCompleted = !history.sessions.isEmpty
        return result
    }

    mutating func beginObservation(at now: Date, calendar: Calendar) {
        if beganAt == nil { beganAt = now }
        let today = TokenUsageCalendarDay.containing(now, calendar: calendar).key
        if timeZoneIdentifier != calendar.timeZone.identifier || pendingDay != today {
            pendingDay = nil; pendingObservedAt = nil
        }
        timeZoneIdentifier = calendar.timeZone.identifier
    }

    /// Caller must first pass the revision/lineage checks in the token ledger.
    mutating func recordAccepted(_ usage: GrokBuildSessionUsage, lineage: GrokBuildLineage,
                                 at now: Date, calendar: Calendar) {
        guard lineage.isUnambiguousRoot, lineage.info.id == usage.id, let beganAt else { return }
        let floor = GrokBuildHistoryLedger.windowStart(now: now, calendar: calendar)
        let hadActivityToday = witnesses.values.contains { calendar.isDate($0, inSameDayAs: now) }
        var observedNewToday = false
        for turn in usage.turns where turn.tokens.total > 0 && turn.recordedAt <= now {
            let sessionKey = GrokBuildHistoryLedger.digest(namespace + ":" + usage.id.uuidString.lowercased())
            let key = Self.witnessKey(sessionKey: sessionKey, turn: turn.number)
            let previous = witnesses[key]
            // Backfill is strictly 30 days. Already observed witnesses may be
            // revised outside that window, but never regress to an older date.
            guard previous != nil || turn.recordedAt >= floor,
                  previous.map({ turn.recordedAt >= $0 }) ?? true else { continue }
            witnesses[key] = turn.recordedAt
            if previous != turn.recordedAt, turn.recordedAt > beganAt,
               calendar.isDate(turn.recordedAt, inSameDayAs: now) { observedNewToday = true }
        }
        let today = TokenUsageCalendarDay.containing(now, calendar: calendar).key
        if initialImportCompleted, !hadActivityToday, observedNewToday, !celebratedDays.contains(today) {
            pendingDay = today
            pendingObservedAt = now
        }
    }

    mutating func finishObservation(at now: Date, calendar: Calendar) {
        bestVerifiedDays = max(bestVerifiedDays, snapshot(at: now, calendar: calendar).summary.bestDays)
        initialImportCompleted = true
    }

    /// Calendar-only changes are not a completed source observation. In
    /// particular, app startup must not turn the first import into a new day.
    mutating func reproject(at now: Date, calendar: Calendar) {
        beginObservation(at: now, calendar: calendar)
        bestVerifiedDays = max(bestVerifiedDays, snapshot(at: now, calendar: calendar).summary.bestDays)
    }

    func snapshot(at now: Date, calendar: Calendar) -> GrokBuildContinuitySnapshot {
        // Many turns share a calendar day. Construct the canonical day/index
        // once per distinct local day, not once per historical turn. Keep the
        // timestamp filter before bucketing for same-day clock rollback.
        let localDays = Set(witnesses.values.lazy.filter { $0 <= now }.map {
            calendar.startOfDay(for: $0)
        })
        let days = Set(localDays.map { TokenUsageCalendarDay.containing($0, calendar: calendar).index })
        return .init(summary: TokenUsageStreakCalculator.summary(activeDayIndices: days,
            now: now, calendar: calendar, coverage: .observedOnly, retainedBestDays: bestVerifiedDays))
    }

    /// Persist this mutation successfully BEFORE returning the celebration to
    /// presentation; a failed disk write must never cause repeated claims.
    mutating func claimCelebration(at now: Date, calendar: Calendar) -> GrokBuildStreakCelebration? {
        let today = TokenUsageCalendarDay.containing(now, calendar: calendar).key
        guard timeZoneIdentifier == calendar.timeZone.identifier, pendingDay == today,
              let observedAt = pendingObservedAt, !celebratedDays.contains(today) else { return nil }
        let summary = snapshot(at: now, calendar: calendar).summary
        guard summary.hasActivityToday else { return nil }
        celebratedDays.insert(today)
        pendingDay = nil; pendingObservedAt = nil
        return .init(namespace: namespace, dayKey: today, observedAt: observedAt, presentedAt: now, summary: summary)
    }

    private static func witnessKey(sessionKey: String, turn: UInt32) -> String {
        GrokBuildHistoryLedger.digest("\(sessionKey):\(turn)")
    }
}
