import Foundation
import SQLite3
import CryptoKit

protocol OpenCodeHistoryReading: Sendable {
    func read(database: URL, timezone: TimeZone, now: Date) async throws -> OpenCodeUsageSnapshot
    func detail(day: Date, snapshot: OpenCodeUsageSnapshot) async throws -> OpenCodeDailyDetail
}

extension OpenCodeHistoryReading {
    func detail(day: Date, snapshot: OpenCodeUsageSnapshot) async throws -> OpenCodeDailyDetail {
        guard let result = snapshot.day(day) else { throw OpenCodeReadError.dayUnavailable }
        return result
    }
}

enum OpenCodeReadError: Error, LocalizedError, Equatable {
    case unavailable, unsupportedSchema, malformedDatabase, dayUnavailable, cancelled
    var errorDescription: String? {
        switch self {
        case .unavailable: "The selected database cannot be opened. Check the file and its read permissions."
        case .unsupportedSchema: "This database schema is not supported. The OpenCode database has not been changed."
        case .malformedDatabase: "The database could not be read consistently. Refresh after OpenCode finishes writing."
        case .dayUnavailable: "No observed usage detail is available for this day."
        case .cancelled: "The read was cancelled."
        }
    }
}

enum OpenCodeSourceDiscovery {
    static func identifier(for database: URL) -> String {
        hash(database.standardizedFileURL.resolvingSymlinksInPath().path)
    }
    static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func candidates(selectedPath: String?, environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        func url(_ path: String) -> URL { URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL }
        // Explicit selection and OPENCODE_DB are authoritative, including when missing.
        if let selectedPath, !selectedPath.isEmpty { return [url(selectedPath)] }
        if let path = environment["OPENCODE_DB"], !path.isEmpty, path != ":memory:" { return [url(path)] }
        var paths = [home.appendingPathComponent(".local/share/opencode/opencode.db")]
        if let xdg = environment["XDG_DATA_HOME"], xdg.hasPrefix("/") {
            paths.insert(url(xdg).appendingPathComponent("opencode/opencode.db"), at: 0)
        }
        var seen = Set<String>()
        return paths.filter { FileManager.default.fileExists(atPath: $0.path) && seen.insert(identifier(for: $0)).inserted }
    }
}

struct OpenCodeHistoryReader: OpenCodeHistoryReading {
    func read(database: URL, timezone: TimeZone, now: Date) async throws -> OpenCodeUsageSnapshot {
        let task = Task.detached(priority: .utility) { try Self.readSync(database: database, timezone: timezone, now: now) }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }

    private struct Row {
        let key: String
        let session: String
        let date: Date?
        let tokens: OpenCodeTokens
        let provider: String
        let model: String
        let cost: Double?
    }

    static func readSync(database: URL, timezone: TimeZone, now: Date) throws -> OpenCodeUsageSnapshot {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(database.path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db = handle else {
            if let handle { sqlite3_close(handle) }
            throw OpenCodeReadError.unavailable
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1500)
        // One read transaction sees a coherent WAL snapshot. No source DDL/DML or CLI migrations.
        guard sqlite3_exec(db, "BEGIN", nil, nil, nil) == SQLITE_OK else { throw OpenCodeReadError.malformedDatabase }
        defer { sqlite3_exec(db, "ROLLBACK", nil, nil, nil) }
        let tables = try query(db, "SELECT name FROM sqlite_master WHERE type = 'table'").compactMap { $0.first ?? nil }
        var schemas: [String] = []
        var records: [String: Row] = [:]
        let sourceID = OpenCodeSourceDiscovery.identifier(for: database)
        for table in ["message", "session_message"] where tables.contains(table) {
            let columns = try query(db, "PRAGMA table_info(\(table))").compactMap { $0.count > 1 ? $0[1] : nil }
            guard Set(["id", "session_id", "time_created", "data"]).isSubset(of: Set(columns)),
                  table != "session_message" || columns.contains("type") else { throw OpenCodeReadError.unsupportedSchema }
            schemas.append(table)
            let v2 = table == "session_message"
            let role = v2 ? "type" : "json_extract(j, '$.role')"
            let model = v2 ? "$.model.id" : "$.modelID"
            let provider = v2 ? "$.model.providerID" : "$.providerID"
            // Projection is an allowlist: never return data, text, parts, credentials, paths or titles.
            let sql = """
            WITH metadata AS (SELECT id, session_id, time_created, \(v2 ? "type," : "")
                CASE WHEN json_valid(data) THEN data ELSE '{}' END AS j FROM \(table))
            SELECT id, session_id, time_created,
                json_object('role', \(role), 'created', CASE WHEN json_type(j, '$.time.created') IN ('integer', 'real') THEN json_extract(j, '$.time.created') END,
                'input', CASE WHEN json_type(j, '$.tokens.input') IN ('integer', 'real') THEN json_extract(j, '$.tokens.input') END, 'output', CASE WHEN json_type(j, '$.tokens.output') IN ('integer', 'real') THEN json_extract(j, '$.tokens.output') END,
                'reasoning', CASE WHEN json_type(j, '$.tokens.reasoning') IN ('integer', 'real') THEN json_extract(j, '$.tokens.reasoning') END,
                'cacheRead', CASE WHEN json_type(j, '$.tokens.cache.read') IN ('integer', 'real') THEN json_extract(j, '$.tokens.cache.read') END, 'cacheWrite', CASE WHEN json_type(j, '$.tokens.cache.write') IN ('integer', 'real') THEN json_extract(j, '$.tokens.cache.write') END,
                'provider', json_extract(j, '\(provider)'), 'model', json_extract(j, '\(model)'),
                'cost', CASE WHEN json_type(j, '$.cost') IN ('integer', 'real') THEN json_extract(j, '$.cost') END)
            FROM metadata WHERE \(role) = 'assistant' \(v2 ? "" : "OR json_extract(j, '$.role') IS NULL")
            """
            for fields in try query(db, sql) {
                try Task.checkCancellation()
                guard fields.count == 4, let id = fields[0], let session = fields[1], let projection = fields[3],
                      let json = try? JSONSerialization.jsonObject(with: Data(projection.utf8)) as? [String: Any] else { continue }
                let key = OpenCodeSourceDiscovery.hash("\(sourceID)|\(session)|\(id)")
                func number(_ key: String) -> Double? {
                    guard let n = json[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
                          n.doubleValue.isFinite, n.doubleValue >= 0 else { return nil }
                    return n.doubleValue
                }
                func token(_ key: String) -> Int64? {
                    guard json["role"] as? String == "assistant" else { return nil }
                    guard let n = number(key), n < Double(Int64.max), n.rounded(.down) == n else { return nil }
                    return Int64(n)
                }
                let millis = number("created") ?? fields[2].flatMap(Double.init)
                let date = millis.flatMap { $0.isFinite && $0 > 0 && $0 / 1000 <= now.timeIntervalSince1970 + 86_400 ? Date(timeIntervalSince1970: $0 / 1000) : nil }
                // V2 overwrites legacy by canonical identity even when its usage is missing.
                records[key] = Row(key: key, session: OpenCodeSourceDiscovery.hash(session), date: date,
                    tokens: OpenCodeTokens(input: token("input"), output: token("output"), reasoning: token("reasoning"),
                                           cacheRead: token("cacheRead"), cacheWrite: token("cacheWrite")),
                    provider: safeLabel(json["provider"]), model: safeLabel(json["model"]),
                    cost: !v2 ? number("cost").flatMap { $0 > 0 ? $0 : nil } : nil)
            }
        }
        guard !schemas.isEmpty else { throw OpenCodeReadError.unsupportedSchema }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let today = calendar.startOfDay(for: now)
        var days: [Date: OpenCodeDailyDetail] = [:]
        var sessions: [Date: Set<String>] = [:]
        var skipped = 0
        var unlocated = 0
        var lifetime: Int64?
        var totalCost = OpenCodeCost()
        totalCost.usageMessages = records.count
        func empty(_ day: Date, tokens: OpenCodeTokens = .zero) -> OpenCodeDailyDetail {
            OpenCodeDailyDetail(startDate: day, tokens: tokens, cost: OpenCodeCost(), hourly: [], models: [],
                               sessionCount: 0, messageCount: 0, isPartial: false)
        }
        for row in records.values.sorted(by: { $0.key < $1.key }) {
            guard let date = row.date else { skipped += 1; unlocated += 1; continue }
            let day = calendar.startOfDay(for: date)
            guard day <= today else { skipped += 1; continue }
            var detail = days[day] ?? empty(day, tokens: OpenCodeTokens())
            detail.cost.usageMessages += 1
            if let total = row.tokens.total {
                lifetime = OpenCodeTokens.sum(lifetime ?? 0, total)
                detail.tokens = detail.tokens.adding(row.tokens)
                detail.messageCount += 1
                sessions[day, default: []].insert(row.session)
                if let cost = row.cost {
                    detail.cost.recordedUSD += cost
                    detail.cost.eligibleMessages += 1
                    totalCost.recordedUSD += cost
                    totalCost.eligibleMessages += 1
                }
                let hour = calendar.dateInterval(of: .hour, for: date)!.start
                if let i = detail.hourly.firstIndex(where: { $0.startDate == hour }) {
                    detail.hourly[i].tokens = detail.hourly[i].tokens.adding(row.tokens)
                    detail.hourly[i].isPartial = detail.hourly[i].isPartial || row.tokens.isPartial
                } else {
                    detail.hourly.append(OpenCodeHourlyUsage(startDate: hour, tokens: row.tokens, isPartial: row.tokens.isPartial))
                }
                if let i = detail.models.firstIndex(where: { $0.provider == row.provider && $0.model == row.model }) {
                    detail.models[i].tokens = detail.models[i].tokens.adding(row.tokens)
                    detail.models[i].isPartial = detail.models[i].isPartial || row.tokens.isPartial
                } else {
                    detail.models.append(OpenCodeModelUsage(provider: row.provider, model: row.model, tokens: row.tokens, isPartial: row.tokens.isPartial))
                }
            } else { skipped += 1 }
            detail.isPartial = detail.isPartial || row.tokens.isPartial
            detail.sessionCount = sessions[day]?.count ?? 0
            days[day] = detail
        }
        // Only confirmed empty days within the retained metadata span are zero. Earlier days stay unobserved.
        let earliest = days.keys.min() ?? today
        for offset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today), date >= earliest else { continue }
            if days[date] == nil { days[date] = empty(date, tokens: unlocated > 0 ? OpenCodeTokens() : .zero) }
        }
        let sorted = days.values.sorted { $0.startDate < $1.startDate }.map { value -> OpenCodeDailyDetail in
            var result = value
            result.hourly.sort { $0.startDate < $1.startDate }
            result.models.sort { left, right in
                let a = left.tokens.total ?? 0
                let b = right.tokens.total ?? 0
                return a == b ? left.id < right.id : a > b
            }
            if skipped > 0 { result.isPartial = true }
            return result
        }
        return OpenCodeUsageSnapshot(sourceID: sourceID, timezoneID: timezone.identifier, readAt: now,
            schema: schemas.joined(separator: " + "), days: sorted, recordKeys: records.keys.sorted(),
            skippedRecords: skipped, lifetimeTokens: lifetime ?? (records.isEmpty ? 0 : nil), cost: totalCost)
    }

    private static func safeLabel(_ value: Any?) -> String {
        guard let value = value as? String, !value.isEmpty else { return "Unknown" }
        return String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(160))
    }

    private static func query(_ db: OpaquePointer, _ sql: String) throws -> [[String?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw OpenCodeReadError.malformedDatabase }
        defer { sqlite3_finalize(statement) }
        var result: [[String?]] = []
        while true {
            try Task.checkCancellation()
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW else { throw OpenCodeReadError.malformedDatabase }
            result.append((0..<sqlite3_column_count(statement)).map { index in
                guard let text = sqlite3_column_text(statement, index) else { return nil }
                return String(cString: text)
            })
        }
    }
}
