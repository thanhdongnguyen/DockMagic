import Foundation

enum AntigravityHistoryParser {
    static let cacheVersion = 2

    /// Whitelist generator metadata into the same usage shape as local
    /// transcripts. No prompt, answer, tool input, header, or credential survives.
    static func records(
        _ response: [String: Any], sessionID: String,
        summary: [String: Any] = [:], previousRecords: [[String: Any]] = [],
        calendar: Calendar = .current
    ) -> [[String: Any]] {
        let root = response["response"] as? [String: Any] ?? response
        let rows = root["generatorMetadata"] as? [[String: Any]] ?? []
        let previous = previousRecords.reduce(into: [String: [String: Any]]()) { result, record in
            guard record["session_id"] as? String == sessionID,
                  let id = record["id"] as? String else { return }
            result[id] = record
        }
        var seen = Set<String>()
        return rows.prefix(20_000).enumerated().compactMap { index, row in
            guard let model = row["chatModel"] as? [String: Any],
                  let usage = model["usage"] as? [String: Any] else { return nil }
            let start = model["chatStartMetadata"] as? [String: Any] ?? [:]
            let id = AntigravityJSON.text(usage["responseId"]) ?? "step-\(index)"
            let exactDate = AntigravityJSON.date(start["createdAt"])
            let prior = previous[id]
            let priorDate = AntigravityJSON.date(prior?["timestamp"])
            guard let date = exactDate ?? priorDate ?? usageDay(row: row, summary: summary, calendar: calendar) else { return nil }
            guard seen.insert(id).inserted else { return nil }
            let input: Int64? = count(usage["inputTokens"])
            let output: Int64 = count(usage["outputTokens"])
                ?? (count(usage["responseOutputTokens"]) ?? 0) + (count(usage["thinkingOutputTokens"]) ?? 0)
            guard input != nil || output > 0 else { return nil }
            let name = [model["modelDisplayName"], model["responseModel"], usage["model"], model["model"]]
                .compactMap { AntigravityJSON.text($0) }
                .first { !$0.hasPrefix("MODEL_PLACEHOLDER") } ?? "Unknown model"
            let tokenFields: [String: Int64] = [
                "input_tokens": input ?? 0, "output_tokens": output,
                "cache_read_input_tokens": count(usage["cacheReadTokens"]) ?? 0,
                "cache_creation_input_tokens": count(usage["cacheWriteTokens"]) ?? 0
            ]
            return [
                "id": id, "session_id": sessionID, "timestamp": date.timeIntervalSince1970,
                "date_precision": exactDate != nil ? "instant" : priorDate != nil ? prior?["date_precision"] as? String ?? "instant" : "day",
                "model": name,
                "usage": tokenFields
            ]
        }
    }

    /// New desktop versions omit per-generation createdAt. Attribute real token
    /// counts to a day only when the entire conversation or generating turn is
    /// bounded by reported timestamps on that same local day. Never use the
    /// polling time or move an ambiguous multi-day session into today's bucket.
    private static func usageDay(row: [String: Any], summary: [String: Any], calendar: Calendar) -> Date? {
        guard let end = AntigravityJSON.date(summary["lastModifiedTime"]) else { return nil }
        var beginnings: [Date] = []
        if let created = AntigravityJSON.date(summary["createdTime"]) { beginnings.append(created) }
        let indices = (row["stepIndices"] as? [Any] ?? []).compactMap(AntigravityJSON.count)
        if let firstStep = indices.min(),
           let lastInputStep = AntigravityJSON.count(summary["lastUserInputStepIndex"]),
           firstStep > lastInputStep,
           let inputTime = AntigravityJSON.date(summary["lastUserInputTime"]) {
            beginnings.append(inputTime)
        }
        guard beginnings.contains(where: { $0 <= end && calendar.isDate($0, inSameDayAs: end) }) else { return nil }
        return calendar.startOfDay(for: end)
    }

    static func canReuseCache(_ cached: [String: Any], modifiedAt: Date) -> Bool {
        AntigravityJSON.count(cached["schema_version"]) == Int64(cacheVersion)
            && AntigravityJSON.date(cached["modified_at"]) == modifiedAt
    }

    private static func count(_ raw: Any?) -> Int64? {
        let value = (raw as? String).flatMap(Int64.init) ?? AntigravityJSON.count(raw)
        guard let value, (0...1_000_000_000_000).contains(value) else { return nil }
        return value
    }
}
