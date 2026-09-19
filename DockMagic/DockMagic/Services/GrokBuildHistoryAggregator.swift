import CryptoKit
import Foundation

/// A retained observation ledger, not a complete account bill. Only normalized
/// numeric metadata is encoded. No filesystem paths, titles or raw UUIDs.
struct GrokBuildHistoryLedger: Codable, Equatable, Sendable {
    struct SessionRecord: Codable, Equatable, Sendable {
        let total: GrokBuildTokenCounts
        let sourceUpdatedAt: Date
        let observedAt: Date
        let turns: [GrokBuildRecordedTurn]
    }

    let schemaVersion: Int
    let namespace: String
    private(set) var sessions: [String: SessionRecord] = [:]

    init(home: URL) {
        schemaVersion = 1
        namespace = Self.digest(home.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    enum Ingestion: Equatable { case accepted, excludedLineage, quarantined }

    mutating func ingest(
        _ usage: GrokBuildSessionUsage, lineage: GrokBuildLineage,
        observedAt: Date, calendar: Calendar
    ) -> Ingestion {
        guard usage.id == lineage.info.id else { return .quarantined }
        guard lineage.isUnambiguousRoot else { return .excludedLineage }
        // Source metadata may have a small clock skew, but a future recorded
        // turn is not eligible activity yet. Quarantine the revision and keep
        // the last good ledger; the collector retries even without file edits.
        guard usage.sourceUpdatedAt <= observedAt.addingTimeInterval(300),
              usage.turns.allSatisfy({ $0.recordedAt <= observedAt }) else { return .quarantined }
        let key = sessionKey(usage.id)
        if let old = sessions[key] {
            guard usage.sourceUpdatedAt >= old.sourceUpdatedAt,
                  usage.total.covers(old.total) else { return .quarantined }
            let incoming = Dictionary(uniqueKeysWithValues: usage.turns.map { ($0.number, $0) })
            for previous in old.turns {
                guard let revised = incoming[previous.number],
                      revised.tokens.covers(previous.tokens),
                      revised.recordedAt >= previous.recordedAt else { return .quarantined }
                for (model, tokens) in previous.models {
                    guard let newTokens = revised.models[model], newTokens.covers(tokens) else {
                        return .quarantined
                    }
                }
            }
        }
        let floor = Self.windowStart(now: observedAt, calendar: calendar)
        sessions[key] = .init(total: usage.total, sourceUpdatedAt: usage.sourceUpdatedAt,
                              observedAt: observedAt,
                              turns: usage.turns.filter { $0.recordedAt >= floor })
        prune(now: observedAt, calendar: calendar)
        return .accepted
    }

    mutating func prune(now: Date, calendar: Calendar) {
        let floor = Self.windowStart(now: now, calendar: calendar)
        sessions = sessions.compactMapValues { record in
            let turns = record.turns.filter { $0.recordedAt >= floor }
            guard !turns.isEmpty else { return nil }
            return .init(total: record.total, sourceUpdatedAt: record.sourceUpdatedAt,
                         observedAt: record.observedAt, turns: turns)
        }
    }

    func snapshot(now: Date, calendar: Calendar, coverage: GrokBuildHistoryCoverage = .init()) -> GrokBuildHistorySnapshot {
        var totals: [Date: Int64] = [:]
        var models: [Date: [String: Int64]] = [:]
        var partialModels = Set<Date>()
        let floor = Self.windowStart(now: now, calendar: calendar)
        for session in sessions.values {
            // A system-clock rollback can put a previously valid observation
            // ahead of now. Keep it in the ledger but do not expose it early.
            // Earlier premature cache rows also need a successful source reread
            // before they can be counted, even after wall-clock time catches up.
            for turn in session.turns where turn.recordedAt >= floor && turn.recordedAt <= now
                && turn.recordedAt <= session.observedAt {
                // Upstream can normalize missing counters into zero. Without
                // stronger provenance, zero rows cannot certify a known day.
                guard turn.tokens.total > 0 else { continue }
                let day = calendar.startOfDay(for: turn.recordedAt)
                totals[day] = GrokBuildNumbers.add(totals[day] ?? 0, turn.tokens.total)
                var modelTotal: Int64 = 0
                for (model, counts) in turn.models where counts.total > 0 {
                    models[day, default: [:]][model] = GrokBuildNumbers.add(
                        models[day]?[model] ?? 0, counts.total
                    )
                    modelTotal = GrokBuildNumbers.add(modelTotal, counts.total)
                }
                if modelTotal < turn.tokens.total { partialModels.insert(day) }
            }
        }
        let days = (0..<30).compactMap { offset -> GrokBuildDailyObservation? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: floor) else { return nil }
            return .init(startDate: day, tokens: totals[day], modelTokens: models[day] ?? [:],
                         modelCoverageIsPartial: totals[day] == nil || partialModels.contains(day))
        }
        return .init(days: days, coverage: coverage, observedAt: now,
                     sourceUpdatedAt: sessions.values.map(\.sourceUpdatedAt).max())
    }

    static func windowStart(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
    }

    func sessionKey(_ id: UUID) -> String {
        Self.digest(namespace + ":" + id.uuidString.lowercased())
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
