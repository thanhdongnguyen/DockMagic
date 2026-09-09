import Foundation

struct AntigravityLocalTelemetry: Sendable {
    let quota: AntigravityQuotaSnapshot?
    let tokens: CodexAccountTokenUsage?
    let telemetry: ClaudeCodeTelemetrySnapshot?
    let observedAt: Date?
}

struct AntigravityTelemetryReader: Sendable {
    let directoryURL: URL
    let home: URL
    var now: Date = .now
    var calendar: Calendar = .current

    private struct Observation {
        let session: String
        let model: String?
        let date: Date
        let tokens: Int64
    }

    func read() -> AntigravityLocalTelemetry {
        let sessions = records(in: directoryURL.appendingPathComponent("sessions"), limit: 500)
            .sorted { date($0) < date($1) }
        let observations = records(in: directoryURL.appendingPathComponent("observations"), limit: 10_000)
            .sorted { date($0) < date($1) }
        let rpc = records(in: directoryURL.appendingPathComponent("rpc"), limit: 501)
        let rpcIndex = rpc.first { $0["known_sessions"] != nil }
        let rpcTasks = rpcIndex?["tasks"] as? [[String: Any]] ?? []
        let events = records(in: directoryURL.appendingPathComponent("events"), limit: 500) + rpcTasks
        let rpcRecords = rpc.flatMap { $0["records"] as? [[String: Any]] ?? [] }.compactMap { record -> Observation? in
            guard let session = AntigravityJSON.text(record["session_id"]),
                  let timestamp = AntigravityJSON.date(record["timestamp"]),
                  let counters = record["usage"] as? [String: Any], let value = breakdown(counters) else { return nil }
            return .init(session: session, model: AntigravityJSON.text(record["model"]), date: timestamp, tokens: value.totalTokens)
        }
        let rpcSessions = Set(rpcRecords.map(\.session))
        let transcripts = readTranscripts().filter { !rpcSessions.contains($0.session) } + rpcRecords
        let transcriptSessions = Set(transcripts.map(\.session))
        var usage = transcripts
        var previous: [String: (input: Int64, output: Int64, model: String?)] = [:]
        for record in observations {
            guard let session = AntigravityJSON.text(record["session_id"]),
                  !transcriptSessions.contains(session),
                  let context = record["context_window"] as? [String: Any],
                  let input = counter(context["total_input_tokens"]),
                  let output = counter(context["total_output_tokens"]) else { continue }
            let model = (record["model"] as? [String: Any]).flatMap { AntigravityJSON.text($0["id"]) }
            defer { previous[session] = (input, output, model) }
            // The first sample is a baseline. Never charge pre-installation
            // cumulative usage to today; decreases establish a new baseline.
            guard let last = previous[session], input >= last.input, output >= last.output else { continue }
            let delta = input - last.input + output - last.output
            if delta > 0 {
                usage.append(Observation(session: session, model: model == last.model ? model : nil,
                                         date: date(record), tokens: delta))
            }
        }
        let cutoff = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? .distantPast
        let hasHistory = !usage.isEmpty || rpcIndex?["has_usage_history"] as? Bool == true
        usage = usage.filter { $0.date >= cutoff && $0.date <= now.addingTimeInterval(60) }
        var daily: [Date: Int64] = [:]
        var models: [String: Int64] = [:]
        for item in usage {
            let day = calendar.startOfDay(for: item.date)
            daily[day] = Self.add(daily[day] ?? 0, item.tokens)
            if let model = item.model { models[model] = Self.add(models[model] ?? 0, item.tokens) }
        }
        let tokens: CodexAccountTokenUsage? = !hasHistory ? nil : CodexAccountTokenUsage(
            lifetimeTokens: nil, peakDailyTokens: daily.values.max(), longestRunningTurnSeconds: nil,
            dailyUsageBuckets: daily.map { .init(startDate: $0.key, tokens: $0.value) }.sorted { $0.startDate < $1.startDate },
            modelUsage: models.map { .init(model: $0.key, tokens: $0.value) }.sorted { $0.tokens > $1.tokens },
            isModelUsagePartial: true
        )
        let latest = sessions.last
        let latestDate = latest.map(date)
        let quota = sessions.reversed().compactMap { record in
            AntigravityQuotaParser.parse(record, source: "CLI status line", now: date(record))
        }.first
        var taskRecords: [String: [String: Any]] = [:]
        for record in sessions + events {
            guard let id = AntigravityJSON.text(record["session_id"]), now.timeIntervalSince(date(record)) < 30 * 60,
                  date(record) <= now.addingTimeInterval(60) else { continue }
            if let current = taskRecords[id], date(current) > date(record) { continue }
            taskRecords[id] = record
        }
        let tasks = taskRecords.compactMap { id, record -> ClaudeCodeActiveTask? in
            let event = record["event"] as? String ?? "status"
            let agentState = record["agent_state"] as? String ?? ""
            let count = counter(record["task_count"]) ?? 0
            if event == "Stop", record["fully_idle"] as? Bool == true { return nil }
            if event == "status", agentState == "idle", count == 0 { return nil }
            let state: ClaudeCodeTaskState = record["tool_confirmation_pending"] as? Bool == true ? .paused : .running
            let model = (record["model"] as? [String: Any]).flatMap { AntigravityJSON.text($0["display_name"] ?? $0["id"]) }
                ?? AntigravityJSON.text(record["model_name"])
            let tool = AntigravityJSON.text(record["tool_name"])
            let name = state == .paused ? "Waiting for approval" : count > 0 ? "\(count) background tasks" : tool ?? model ?? "Antigravity session"
            return ClaudeCodeActiveTask(id: id, sessionID: id, name: name, kind: model,
                                       state: state, description: nil, label: nil, startedAt: nil,
                                       tokenCount: nil, lastToolName: tool, observedAt: date(record))
        }.sorted { $0.observedAt > $1.observedAt }
        var costs: [Date: Double] = [:]
        for record in sessions {
            guard date(record) >= cutoff,
                  let cost = record["cost"] as? [String: Any],
                  let amount = AntigravityJSON.number(cost["total_cost_usd"]), (0...1_000_000).contains(amount) else { continue }
            costs[calendar.startOfDay(for: date(record)), default: 0] += amount
        }
        let local: ClaudeCodeTelemetrySnapshot? = sessions.isEmpty && events.isEmpty && usage.isEmpty && rpcIndex == nil ? nil : .init(
            source: usage.isEmpty ? .statusLine : sessions.isEmpty ? .localHistory : .statusLineAndLocalHistory,
            currentSession: latest.flatMap(sessionUsage),
            observedSessionCount: Set(sessions.compactMap { $0["session_id"] as? String }).union(transcriptSessions).count,
            dailyCosts: costs.map { .init(startDate: $0.key, estimatedCostUSD: $0.value) }.sorted { $0.startDate < $1.startDate },
            modelCosts: [], activeTasks: tasks, activeGoals: [], historyIsPartial: true, costIsPartial: true
        )
        let observedAt = ([latestDate, rpcIndex.map(date)].compactMap { $0 } + events.map(date) + usage.map(\.date)).max()
        return AntigravityLocalTelemetry(quota: quota, tokens: tokens, telemetry: local, observedAt: observedAt)
    }

    private func sessionUsage(_ record: [String: Any]) -> ClaudeCodeSessionUsage {
        let model = record["model"] as? [String: Any] ?? [:]
        let context = record["context_window"] as? [String: Any] ?? [:]
        let rawUsage = context["current_usage"] as? [String: Any] ?? [:]
        let cost = record["cost"] as? [String: Any] ?? [:]
        return ClaudeCodeSessionUsage(
            sessionID: AntigravityJSON.text(record["session_id"]), sessionName: nil,
            modelID: AntigravityJSON.text(model["id"]), modelDisplayName: AntigravityJSON.text(model["display_name"]),
            agentName: nil, claudeCodeVersion: AntigravityJSON.text(record["version"]),
            estimatedCostUSD: AntigravityJSON.number(cost["total_cost_usd"]),
            totalDurationMilliseconds: nil, totalAPIDurationMilliseconds: nil, totalLinesAdded: nil, totalLinesRemoved: nil,
            context: context.isEmpty ? nil : .init(
                totalInputTokens: counter(context["total_input_tokens"]), totalOutputTokens: counter(context["total_output_tokens"]),
                contextWindowSize: counter(context["context_window_size"]),
                usedPercent: AntigravityJSON.number(context["used_percentage"]), remainingPercent: AntigravityJSON.number(context["remaining_percentage"]),
                currentUsage: breakdown(rawUsage)
            ), observedAt: date(record)
        )
    }

    private func readTranscripts() -> [Observation] {
        var usage: [Observation] = []
        var seen = Set<String>()
        let fm = FileManager.default
        for name in ["antigravity", "antigravity-cli", "antigravity-ide"] {
            let brain = home.appendingPathComponent(".gemini/\(name)/brain")
            let directories = (try? fm.contentsOfDirectory(at: brain, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []
            for directory in directories.prefix(500) {
                if (try? directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { continue }
                let url = directory.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                guard let bytes = safeData(url, maxBytes: 32_000_000), let text = String(data: bytes, encoding: .utf8) else { continue }
                for (index, line) in text.split(separator: "\n").enumerated() {
                    guard let data = line.data(using: .utf8),
                          let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    let message = record["message"] as? [String: Any] ?? record
                    let type = record["type"] as? String ?? message["role"] as? String ?? ""
                    guard ["assistant", "model"].contains(type),
                          let timestamp = AntigravityJSON.date(record["timestamp"] ?? record["createdAt"]),
                          let counters = message["usage"] as? [String: Any] ?? message["usageMetadata"] as? [String: Any],
                          let value = breakdown(counters) else { continue }
                    let session = AntigravityJSON.text(record["conversationId"] ?? record["session_id"]) ?? directory.lastPathComponent
                    let messageID = AntigravityJSON.text(record["uuid"] ?? record["id"] ?? message["id"])
                        ?? "\(name)-\(directory.lastPathComponent)-\(index)"
                    guard seen.insert("\(session)|\(messageID)").inserted else { continue }
                    usage.append(.init(session: session, model: AntigravityJSON.text(message["model"] ?? record["modelName"]),
                                       date: timestamp, tokens: value.totalTokens))
                }
            }
        }
        return usage
    }

    private func breakdown(_ record: [String: Any]) -> CodexTokenBreakdown? {
        let input = counter(record["input_tokens"] ?? record["promptTokenCount"])
        let output = counter(record["output_tokens"] ?? record["candidatesTokenCount"])
        let cache = counter(record["cache_read_input_tokens"] ?? record["cachedContentTokenCount"]) ?? 0
        let write = counter(record["cache_creation_input_tokens"]) ?? 0
        let reasoning = counter(record["thoughtsTokenCount"]) ?? 0
        guard input != nil || output != nil else { return nil }
        // Gemini prompt counts include cached content; Claude-style counters
        // report cache reads and writes separately. Never count a cache twice.
        let total = counter(record["totalTokenCount"])
            ?? ((input ?? 0) + (output ?? 0) + reasoning + (record["promptTokenCount"] == nil ? cache + write : 0))
        return .init(inputTokens: input ?? 0, cachedInputTokens: cache, cacheWriteInputTokens: write,
                     outputTokens: output ?? 0, reasoningOutputTokens: reasoning, totalTokens: total)
    }

    private func records(in directory: URL, limit: Int) -> [[String: Any]] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }.prefix(limit).compactMap {
            guard let data = safeData($0, maxBytes: 1_000_000) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
    }

    private func safeData(_ url: URL, maxBytes: Int) -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= maxBytes else { return nil }
        return try? Data(contentsOf: url)
    }

    private func counter(_ value: Any?) -> Int64? {
        guard let value = AntigravityJSON.count(value), value <= 1_000_000_000_000 else { return nil }
        return value
    }

    private func date(_ record: [String: Any]) -> Date {
        AntigravityJSON.date(record["observed_at"]) ?? .distantPast
    }

    private static func add(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }
}
