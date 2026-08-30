import Foundation

struct ClaudeCodeParsedStatusLine {
    let fiveHour: ClaudeCodeRateLimitWindow?
    let weekly: ClaudeCodeRateLimitWindow?
    let session: ClaudeCodeSessionUsage?

    var hasUsefulData: Bool {
        fiveHour != nil || weekly != nil || session != nil
    }
}

enum ClaudeCodeStatusLineTelemetryParser {
    static func parse(
        _ data: Data,
        observedAt: Date
    ) throws -> ClaudeCodeParsedStatusLine {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any]
        else {
            throw ClaudeCodeRateLimitProviderError.invalidSnapshot
        }
        return parse(root, observedAt: observedAt)
    }

    static func parse(
        _ root: [String: Any],
        observedAt: Date
    ) -> ClaudeCodeParsedStatusLine {
        let rateLimits = root["rate_limits"] as? [String: Any] ?? root
        let fiveHour = parseWindow(
            rateLimits["five_hour"],
            kind: .fiveHour,
            durationMinutes: 300
        )
        let weekly = parseWindow(
            rateLimits["seven_day"],
            kind: .weekly,
            durationMinutes: 10_080
        )

        let model = root["model"] as? [String: Any]
        let cost = root["cost"] as? [String: Any]
        let context = root["context_window"] as? [String: Any]
        let agent = root["agent"] as? [String: Any]
        let parsedContext = parseContext(context)

        let sessionID = nonBlankString(root["session_id"])
        let sessionName = nonBlankString(root["session_name"])
        let modelID = nonBlankString(model?["id"])
        let modelDisplayName = nonBlankString(model?["display_name"])
        let agentName = nonBlankString(agent?["name"])
        let version = nonBlankString(root["version"])
        let estimatedCost = finiteDouble(cost?["total_cost_usd"])

        let hasSessionData = sessionID != nil
            || sessionName != nil
            || modelID != nil
            || modelDisplayName != nil
            || agentName != nil
            || version != nil
            || estimatedCost != nil
            || parsedContext != nil

        let session = hasSessionData
            ? ClaudeCodeSessionUsage(
                sessionID: sessionID,
                sessionName: sessionName,
                modelID: modelID,
                modelDisplayName: modelDisplayName,
                agentName: agentName,
                claudeCodeVersion: version,
                estimatedCostUSD: estimatedCost,
                totalDurationMilliseconds: nonnegativeInt64(
                    cost?["total_duration_ms"]
                ),
                totalAPIDurationMilliseconds: nonnegativeInt64(
                    cost?["total_api_duration_ms"]
                ),
                totalLinesAdded: nonnegativeInt64(cost?["total_lines_added"]),
                totalLinesRemoved: nonnegativeInt64(cost?["total_lines_removed"]),
                context: parsedContext,
                observedAt: observedAt
            )
            : nil

        return ClaudeCodeParsedStatusLine(
            fiveHour: fiveHour,
            weekly: weekly,
            session: session
        )
    }

    private static func parseWindow(
        _ value: Any?,
        kind: ClaudeCodeRateLimitWindowKind,
        durationMinutes: Int
    ) -> ClaudeCodeRateLimitWindow? {
        guard
            let dictionary = value as? [String: Any],
            let usedPercentage = finiteDouble(dictionary["used_percentage"])
        else {
            return nil
        }

        let normalized = min(max(usedPercentage, 0), 100)
        let resetsAt = finiteDouble(dictionary["resets_at"]).map {
            Date(timeIntervalSince1970: $0)
        }
        return ClaudeCodeRateLimitWindow(
            kind: kind,
            usedPercent: Int(normalized.rounded()),
            windowDurationMinutes: durationMinutes,
            resetsAt: resetsAt
        )
    }

    private static func parseContext(
        _ value: [String: Any]?
    ) -> ClaudeCodeContextUsage? {
        guard let value else { return nil }
        let current = value["current_usage"] as? [String: Any]
        let currentUsage: CodexTokenBreakdown?
        if let current {
            let input = nonnegativeInt64(current["input_tokens"]) ?? 0
            let output = nonnegativeInt64(current["output_tokens"]) ?? 0
            let cacheRead = nonnegativeInt64(
                current["cache_read_input_tokens"]
            ) ?? 0
            let cacheWrite = nonnegativeInt64(
                current["cache_creation_input_tokens"]
            ) ?? 0
            currentUsage = CodexTokenBreakdown(
                inputTokens: input,
                cachedInputTokens: cacheRead,
                cacheWriteInputTokens: cacheWrite,
                outputTokens: output,
                reasoningOutputTokens: 0,
                totalTokens: input + output + cacheRead + cacheWrite
            )
        } else {
            currentUsage = nil
        }

        let parsed = ClaudeCodeContextUsage(
            totalInputTokens: nonnegativeInt64(value["total_input_tokens"]),
            totalOutputTokens: nonnegativeInt64(value["total_output_tokens"]),
            contextWindowSize: nonnegativeInt64(value["context_window_size"]),
            usedPercent: finiteDouble(value["used_percentage"]).map {
                min(max($0, 0), 100)
            },
            remainingPercent: finiteDouble(value["remaining_percentage"]).map {
                min(max($0, 0), 100)
            },
            currentUsage: currentUsage
        )
        let hasValue = parsed.totalInputTokens != nil
            || parsed.totalOutputTokens != nil
            || parsed.contextWindowSize != nil
            || parsed.usedPercent != nil
            || parsed.remainingPercent != nil
            || parsed.currentUsage != nil
        return hasValue ? parsed : nil
    }

    static func finiteDouble(_ value: Any?) -> Double? {
        let result: Double?
        switch value {
        case let number as NSNumber:
            result = number.doubleValue
        case let string as String:
            result = Double(string)
        default:
            result = nil
        }
        guard let result, result.isFinite else { return nil }
        return result
    }

    static func nonnegativeInt64(_ value: Any?) -> Int64? {
        guard let number = finiteDouble(value), number >= 0 else { return nil }
        if number >= 9.0e18 {
            return Int64.max
        }
        return Int64(number.rounded())
    }

    static func nonBlankString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ClaudeCodeLocalTelemetryResult {
    let parsedStatus: ClaudeCodeParsedStatusLine?
    let currentSession: ClaudeCodeSessionUsage?
    let tokenUsage: CodexAccountTokenUsage?
    let recentTaskActivity: CodexRecentTaskActivity?
    let dailyCosts: [ClaudeCodeDailyCostUsage]
    let modelCosts: [ClaudeCodeModelCostUsage]
    let activeTasks: [ClaudeCodeActiveTask]
    let activeGoals: [ClaudeCodeActiveGoal]
    let activityObservedAt: Date?
    let observedSessionCount: Int
    let fetchedAt: Date
    let source: ClaudeCodeTelemetrySource

    var hasUsefulData: Bool {
        parsedStatus?.hasUsefulData == true
            || tokenUsage != nil
            || recentTaskActivity != nil
            || !activeTasks.isEmpty
            || !activeGoals.isEmpty
            || !dailyCosts.isEmpty
            || activityObservedAt != nil
    }
}

struct ClaudeCodeLocalTelemetryReader: Sendable {
    private typealias StatusObservation = (
        parsed: ClaudeCodeParsedStatusLine,
        observedAt: Date,
        identity: String
    )

    private static let rateLimitWithoutResetRetention: TimeInterval = 15 * 60

    let snapshotURL: URL
    let sessionSnapshotsDirectoryURL: URL
    let taskSnapshotURL: URL
    let taskSnapshotsDirectoryURL: URL
    let activityEventsDirectoryURL: URL
    let projectsDirectoryURL: URL
    let now: Date
    let calendar: Calendar

    init(
        snapshotURL: URL,
        sessionSnapshotsDirectoryURL: URL,
        taskSnapshotURL: URL,
        taskSnapshotsDirectoryURL: URL,
        activityEventsDirectoryURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-activity-events"),
        projectsDirectoryURL: URL,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.snapshotURL = snapshotURL
        self.sessionSnapshotsDirectoryURL = sessionSnapshotsDirectoryURL
        self.taskSnapshotURL = taskSnapshotURL
        self.taskSnapshotsDirectoryURL = taskSnapshotsDirectoryURL
        self.activityEventsDirectoryURL = activityEventsDirectoryURL
        self.projectsDirectoryURL = projectsDirectoryURL
        self.now = now
        var calendar = calendar
        calendar.timeZone = .current
        self.calendar = calendar
    }

    func read() -> ClaudeCodeLocalTelemetryResult {
        let history = ClaudeCodeLocalHistoryReader(
            projectsDirectoryURL: projectsDirectoryURL,
            now: now,
            calendar: calendar
        ).read()
        let status = readStatusObservations(
            sessionModels: history.sessionModels
        )
        let activity = ClaudeCodeActivitySnapshotReader(
            eventsDirectoryURL: activityEventsDirectoryURL,
            now: now
        ).read()

        let fetchedDates = [
            status.latestObservedAt,
            history.latestObservedAt,
            activity.latestObservedAt
        ].compactMap { $0 }
        let source: ClaudeCodeTelemetrySource
        switch (status.latestParsed != nil, history.hasAnyData) {
        case (true, true):
            source = .statusLineAndLocalHistory
        case (true, false):
            source = .statusLine
        case (false, true), (false, false):
            source = .localHistory
        }

        return ClaudeCodeLocalTelemetryResult(
            parsedStatus: status.latestParsed,
            currentSession: status.latestParsed?.session,
            tokenUsage: history.tokenUsage,
            recentTaskActivity: history.recentTaskActivity,
            dailyCosts: status.dailyCosts,
            modelCosts: status.modelCosts,
            activeTasks: activity.activeTasks,
            activeGoals: history.activeGoals,
            activityObservedAt: activity.latestObservedAt,
            observedSessionCount: status.observedSessionCount,
            fetchedAt: fetchedDates.max() ?? now,
            source: source
        )
    }

    private func readStatusObservations(
        sessionModels: [String: Set<String>]
    ) -> StatusAggregate {
        let urls = snapshotFiles(
            directory: sessionSnapshotsDirectoryURL,
            fallback: snapshotURL
        )
        var observations: [StatusObservation] = []
        for url in urls {
            guard
                let data = try? Data(contentsOf: url),
                let observedAt = modificationDate(of: url),
                let parsed = try? ClaudeCodeStatusLineTelemetryParser.parse(
                    data,
                    observedAt: observedAt
                ),
                parsed.hasUsefulData
            else {
                continue
            }
            let identity = parsed.session?.sessionID ?? url.lastPathComponent
            observations.append((parsed, observedAt, identity))
        }
        observations.sort { $0.observedAt < $1.observedAt }

        let cutoff = calendar.date(byAdding: .day, value: -29, to: day(now))
            ?? now.addingTimeInterval(-29 * 86_400)
        var costsByDay: [Date: Double] = [:]
        var costsByModel: [String: Double] = [:]
        var sessions = Set<String>()
        for (parsed, observedAt, identity) in observations where observedAt >= cutoff {
            sessions.insert(identity)
            guard let cost = parsed.session?.estimatedCostUSD, cost >= 0 else {
                continue
            }
            costsByDay[day(observedAt), default: 0] += cost
            if let models = sessionModels[identity],
               models.count == 1,
               let model = models.first,
               parsed.session?.modelID == nil || parsed.session?.modelID == model {
                costsByModel[model, default: 0] += cost
            }
        }

        return StatusAggregate(
            latestParsed: mergedLatestStatus(from: observations),
            latestObservedAt: observations.last?.observedAt,
            observedSessionCount: sessions.count,
            dailyCosts: costsByDay
                .map {
                    ClaudeCodeDailyCostUsage(
                        startDate: $0.key,
                        estimatedCostUSD: $0.value
                    )
                }
                .sorted { $0.startDate < $1.startDate },
            modelCosts: costsByModel
                .map {
                    ClaudeCodeModelCostUsage(
                        model: $0.key,
                        estimatedCostUSD: $0.value
                    )
                }
                .sorted {
                    if $0.estimatedCostUSD != $1.estimatedCostUSD {
                        return $0.estimatedCostUSD > $1.estimatedCostUSD
                    }
                    return $0.model.localizedCaseInsensitiveCompare($1.model)
                        == .orderedAscending
                }
        )
    }

    private func mergedLatestStatus(
        from observations: [StatusObservation]
    ) -> ClaudeCodeParsedStatusLine? {
        guard !observations.isEmpty else { return nil }
        let latestSession = observations.reversed().lazy.compactMap {
            $0.parsed.session
        }.first
        return ClaudeCodeParsedStatusLine(
            fiveHour: retainedRateLimitWindow(
                from: observations,
                keyPath: \.fiveHour
            ),
            weekly: retainedRateLimitWindow(
                from: observations,
                keyPath: \.weekly
            ),
            session: latestSession
        )
    }

    private func retainedRateLimitWindow(
        from observations: [StatusObservation],
        keyPath: KeyPath<
            ClaudeCodeParsedStatusLine,
            ClaudeCodeRateLimitWindow?
        >
    ) -> ClaudeCodeRateLimitWindow? {
        let fallbackCutoff = now.addingTimeInterval(
            -Self.rateLimitWithoutResetRetention
        )
        for observation in observations.reversed() {
            guard let window = observation.parsed[keyPath: keyPath] else {
                continue
            }
            if let resetsAt = window.resetsAt {
                if resetsAt > now {
                    return window
                }
            } else if observation.observedAt >= fallbackCutoff {
                return window
            }
        }
        return nil
    }

    private func readTaskSnapshots() -> [ClaudeCodeActiveTask] {
        let urls = snapshotFiles(
            directory: taskSnapshotsDirectoryURL,
            fallback: taskSnapshotURL
        )
        let freshnessCutoff = now.addingTimeInterval(-5 * 60)
        return urls.flatMap { url -> [ClaudeCodeActiveTask] in
            guard
                let observedAt = modificationDate(of: url),
                observedAt >= freshnessCutoff,
                let data = try? Data(contentsOf: url)
            else {
                return []
            }
            return ClaudeCodeTaskSnapshotParser.parse(
                data,
                observedAt: observedAt
            )
        }
    }

    private func mergeTasks(
        _ statusTasks: [ClaudeCodeActiveTask],
        _ historyTasks: [ClaudeCodeActiveTask]
    ) -> [ClaudeCodeActiveTask] {
        var tasks: [String: ClaudeCodeActiveTask] = [:]
        for task in historyTasks + statusTasks {
            if let current = tasks[task.id], current.observedAt > task.observedAt {
                continue
            }
            tasks[task.id] = task
        }
        return tasks.values
            .filter { $0.state.isActive }
            .sorted {
                ($0.startedAt ?? $0.observedAt) < ($1.startedAt ?? $1.observedAt)
            }
    }

    private func snapshotFiles(directory: URL, fallback: URL) -> [URL] {
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            let jsonFiles = files.filter {
                $0.pathExtension.lowercased() == "json"
            }
            if !jsonFiles.isEmpty {
                return jsonFiles
            }
        }
        return fileManager.fileExists(atPath: fallback.path) ? [fallback] : []
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
    }

    private func day(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private struct StatusAggregate {
        let latestParsed: ClaudeCodeParsedStatusLine?
        let latestObservedAt: Date?
        let observedSessionCount: Int
        let dailyCosts: [ClaudeCodeDailyCostUsage]
        let modelCosts: [ClaudeCodeModelCostUsage]
    }
}

struct ClaudeCodeActivitySnapshotReader: Sendable {
    struct Result: Equatable, Sendable {
        let activeTasks: [ClaudeCodeActiveTask]
        let latestObservedAt: Date?
    }

    private struct Event: Sendable {
        let name: String
        let sessionID: String
        let agentID: String?
        let agentType: String?
        let taskID: String?
        let taskSubject: String?
        let toolName: String?
        let teammateName: String?
        let observedAt: Date
    }

    private static let activeFreshness: TimeInterval = 30 * 60

    let eventsDirectoryURL: URL
    let now: Date

    func read() -> Result {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: eventsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return Result(activeTasks: [], latestObservedAt: nil)
        }

        let events = urls
            .filter {
                $0.lastPathComponent.hasPrefix("event-")
                    && $0.pathExtension.lowercased() == "json"
            }
            .compactMap(parseEvent)
            .sorted {
                if $0.observedAt != $1.observedAt {
                    return $0.observedAt < $1.observedAt
                }
                return $0.name < $1.name
            }

        var sessions: [String: ClaudeCodeActiveTask] = [:]
        var agents: [String: ClaudeCodeActiveTask] = [:]
        var tasks: [String: ClaudeCodeActiveTask] = [:]

        for event in events {
            reduce(
                event,
                sessions: &sessions,
                agents: &agents,
                tasks: &tasks
            )
        }

        let cutoff = now.addingTimeInterval(-Self.activeFreshness)
        let activeTasks = Array(sessions.values)
            + Array(agents.values)
            + Array(tasks.values)
        return Result(
            activeTasks: activeTasks
                .filter { $0.state.isActive && $0.observedAt >= cutoff }
                .sorted {
                    if $0.observedAt != $1.observedAt {
                        return $0.observedAt > $1.observedAt
                    }
                    return $0.id < $1.id
                },
            latestObservedAt: events.last?.observedAt
        )
    }

    private func parseEvent(_ url: URL) -> Event? {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            (root["schema_version"] as? NSNumber)?.intValue == 1,
            let name = text(root["hook_event_name"]),
            let sessionID = identifier(root["session_id"])
        else {
            return nil
        }
        let observedAt = ClaudeCodeStatusLineTelemetryParser.finiteDouble(
            root["observed_at_ms"]
        ).map { Date(timeIntervalSince1970: $0 / 1_000) }
            ?? modificationDate(of: url)
        guard let observedAt else { return nil }

        return Event(
            name: name,
            sessionID: sessionID,
            agentID: identifier(root["agent_id"]),
            agentType: text(root["agent_type"]),
            taskID: identifier(root["task_id"]),
            taskSubject: text(root["task_subject"]),
            toolName: text(root["tool_name"]),
            teammateName: text(root["teammate_name"]),
            observedAt: observedAt
        )
    }

    private func reduce(
        _ event: Event,
        sessions: inout [String: ClaudeCodeActiveTask],
        agents: inout [String: ClaudeCodeActiveTask],
        tasks: inout [String: ClaudeCodeActiveTask]
    ) {
        if event.name == "TaskCreated" || event.name == "TaskCompleted",
           let taskID = event.taskID {
            let key = "task:\(event.sessionID):\(taskID)"
            let previous = tasks[key]
            tasks[key] = ClaudeCodeActiveTask(
                id: key,
                sessionID: event.sessionID,
                name: event.taskSubject ?? previous?.name ?? "Claude task",
                kind: "Task",
                state: event.name == "TaskCreated" ? .pending : .completed,
                description: nil,
                label: nil,
                startedAt: previous?.startedAt ?? event.observedAt,
                tokenCount: nil,
                lastToolName: previous?.lastToolName,
                observedAt: event.observedAt
            )
            return
        }

        let agentID = event.agentID
            ?? (event.name == "TeammateIdle"
                ? identifier(event.teammateName)
                : nil)
        if let agentID {
            let key = "agent:\(event.sessionID):\(agentID)"
            let previous = agents[key]
            let state: ClaudeCodeTaskState
            switch event.name {
            case "SubagentStop": state = .stopped
            case "TeammateIdle", "PermissionRequest", "Notification":
                state = .paused
            default: state = .running
            }
            agents[key] = ClaudeCodeActiveTask(
                id: key,
                sessionID: event.sessionID,
                name: event.agentType
                    ?? event.teammateName
                    ?? previous?.name
                    ?? "Claude subagent",
                kind: "Subagent",
                state: state,
                description: nil,
                label: nil,
                startedAt: previous?.startedAt ?? event.observedAt,
                tokenCount: nil,
                lastToolName: event.toolName ?? previous?.lastToolName,
                observedAt: event.observedAt
            )
            return
        }

        let key = "session:\(event.sessionID)"
        let previous = sessions[key]
        let state: ClaudeCodeTaskState
        switch event.name {
        case "SessionEnd": state = .stopped
        case "StopFailure": state = .failed
        case "SessionStart", "Stop", "PermissionRequest", "Notification",
             "TeammateIdle":
            state = .paused
        default:
            state = .running
        }
        sessions[key] = ClaudeCodeActiveTask(
            id: key,
            sessionID: event.sessionID,
            name: previous?.name ?? "Claude Code session",
            kind: "Main session",
            state: state,
            description: nil,
            label: nil,
            startedAt: previous?.startedAt ?? event.observedAt,
            tokenCount: nil,
            lastToolName: event.toolName ?? previous?.lastToolName,
            observedAt: event.observedAt
        )
    }

    private func text(_ value: Any?) -> String? {
        ClaudeCodeStatusLineTelemetryParser.nonBlankString(value)
    }

    private func identifier(_ value: Any?) -> String? {
        guard let value = text(value), value.count <= 100 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "_-")
        )
        return value.unicodeScalars.allSatisfy(allowed.contains) ? value : nil
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
    }
}

enum ClaudeCodeTaskSnapshotParser {
    static func parse(
        _ data: Data,
        observedAt: Date
    ) -> [ClaudeCodeActiveTask] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let rows = root["tasks"] as? [[String: Any]]
        else {
            return []
        }
        let sessionID = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
            root["session_id"]
        )
        return rows.compactMap { row in
            guard
                let id = ClaudeCodeStatusLineTelemetryParser.nonBlankString(row["id"])
            else {
                return nil
            }
            let state = taskState(row["status"])
            guard state.isActive else { return nil }
            let description = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                row["description"]
            )
            let label = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                row["label"]
            )
            let name = ClaudeCodeStatusLineTelemetryParser.nonBlankString(row["name"])
                ?? label
                ?? description
                ?? "Background task"
            return ClaudeCodeActiveTask(
                id: id,
                sessionID: sessionID,
                name: name,
                kind: ClaudeCodeStatusLineTelemetryParser.nonBlankString(row["type"]),
                state: state,
                description: description,
                label: label,
                startedAt: date(row["startTime"] ?? row["started_at"]),
                tokenCount: tokenCount(row),
                lastToolName: ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                    row["lastToolName"] ?? row["last_tool_name"]
                ),
                observedAt: observedAt
            )
        }
    }

    private static func taskState(_ value: Any?) -> ClaudeCodeTaskState {
        let raw = ClaudeCodeStatusLineTelemetryParser.nonBlankString(value)?
            .lowercased()
        switch raw {
        case "pending": return .pending
        case "running", "in_progress": return .running
        case "paused": return .paused
        case "completed": return .completed
        case "failed": return .failed
        case "stopped", "killed": return .stopped
        default: return .unknown
        }
    }

    private static func tokenCount(_ row: [String: Any]) -> Int64? {
        if let direct = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
            row["tokenCount"] ?? row["token_count"]
        ) {
            return direct
        }
        guard let samples = row["tokenSamples"] as? [Any] else { return nil }
        for sample in samples.reversed() {
            if let value = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(sample) {
                return value
            }
            if let dictionary = sample as? [String: Any],
               let value = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
                   dictionary["tokenCount"] ?? dictionary["token_count"]
               ) {
                return value
            }
        }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        if let milliseconds = ClaudeCodeStatusLineTelemetryParser.finiteDouble(value) {
            let seconds = milliseconds > 10_000_000_000
                ? milliseconds / 1_000
                : milliseconds
            return Date(timeIntervalSince1970: seconds)
        }
        guard let string = value as? String else { return nil }
        return ClaudeCodeDateParser.date(from: string)
    }
}

struct ClaudeCodeLocalHistoryReader: Sendable {
    struct Result {
        let tokenUsage: CodexAccountTokenUsage?
        let recentTaskActivity: CodexRecentTaskActivity?
        let activeTasks: [ClaudeCodeActiveTask]
        let activeGoals: [ClaudeCodeActiveGoal]
        let latestObservedAt: Date?
        let sessionModels: [String: Set<String>]

        var hasAnyData: Bool {
            tokenUsage != nil
                || recentTaskActivity != nil
                || !activeTasks.isEmpty
                || !activeGoals.isEmpty
        }
    }

    let projectsDirectoryURL: URL
    let now: Date
    let calendar: Calendar

    init(
        projectsDirectoryURL: URL,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.projectsDirectoryURL = projectsDirectoryURL
        self.now = now
        var calendar = calendar
        calendar.timeZone = .current
        self.calendar = calendar
    }

    func read() -> Result {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: projectsDirectoryURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .contentModificationDateKey,
                .fileSizeKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return Result(
                tokenUsage: nil,
                recentTaskActivity: nil,
                activeTasks: [],
                activeGoals: [],
                latestObservedAt: nil,
                sessionModels: [:]
            )
        }

        let today = calendar.startOfDay(for: now)
        let usageCutoff = calendar.date(byAdding: .day, value: -29, to: today)
            ?? now.addingTimeInterval(-29 * 86_400)
        let previousWeekCutoff = calendar.date(byAdding: .day, value: -13, to: today)
            ?? now.addingTimeInterval(-13 * 86_400)
        let goalFileCutoff = calendar.date(byAdding: .day, value: -120, to: today)
            ?? now.addingTimeInterval(-120 * 86_400)
        let activeTaskCutoff = now.addingTimeInterval(-5 * 60)

        var daily: [Date: CodexTokenBreakdown] = [:]
        var models: [String: CodexTokenBreakdown] = [:]
        var seenAssistantMessages = Set<String>()
        var rootSessionStart: [String: Date] = [:]
        var sessionModels: [String: Set<String>] = [:]
        var goals: [String: ClaudeCodeActiveGoal] = [:]
        var tasks: [String: MutableTask] = [:]
        var latestObservedAt: Date?
        var foundUsage = false

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "jsonl" else { continue }
            guard
                let values = try? url.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey,
                    .fileSizeKey
                ]),
                values.isRegularFile == true,
                let modifiedAt = values.contentModificationDate,
                modifiedAt >= goalFileCutoff,
                (values.fileSize ?? 0) <= 64 * 1_024 * 1_024,
                let content = try? String(contentsOf: url, encoding: .utf8)
            else {
                continue
            }
            latestObservedAt = maxDate(latestObservedAt, modifiedAt)
            let isSubagentFile = url.pathComponents.contains("subagents")

            for line in content.split(whereSeparator: \.isNewline) {
                guard
                    let data = String(line).data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data),
                    let record = object as? [String: Any]
                else {
                    continue
                }
                let timestamp = ClaudeCodeDateParser.date(
                    from: record["timestamp"]
                ) ?? modifiedAt
                let sessionID = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                    record["sessionId"] ?? record["session_id"]
                ) ?? url.deletingPathExtension().lastPathComponent

                if !isSubagentFile {
                    rootSessionStart[sessionID] = minDate(
                        rootSessionStart[sessionID],
                        timestamp
                    )
                }
                parseGoal(
                    record,
                    sessionID: sessionID,
                    timestamp: timestamp,
                    goals: &goals
                )
                parseTask(
                    record,
                    sessionID: sessionID,
                    timestamp: timestamp,
                    tasks: &tasks
                )

                guard record["type"] as? String == "assistant",
                      let message = record["message"] as? [String: Any],
                      let model = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                          message["model"]
                      ),
                      model != "<synthetic>",
                      let usage = message["usage"] as? [String: Any]
                else {
                    continue
                }
                sessionModels[sessionID, default: []].insert(model)
                guard timestamp >= usageCutoff else { continue }
                let identity = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                    record["uuid"]
                ) ?? "\(sessionID):\(timestamp.timeIntervalSince1970):\(model)"
                guard seenAssistantMessages.insert(identity).inserted else {
                    continue
                }
                let breakdown = tokenBreakdown(usage)
                guard breakdown.totalTokens > 0 else { continue }
                foundUsage = true
                let startDate = calendar.startOfDay(for: timestamp)
                daily[startDate] = (daily[startDate] ?? .zero).adding(breakdown)
                models[model] = (models[model] ?? .zero).adding(breakdown)
            }
        }

        let buckets: [CodexTokenUsageDailyBucket]
        if foundUsage {
            buckets = (0..<30).compactMap { offset in
                guard let date = calendar.date(
                    byAdding: .day,
                    value: offset - 29,
                    to: today
                ) else { return nil }
                return CodexTokenUsageDailyBucket(
                    startDate: date,
                    tokens: daily[date]?.totalTokens ?? 0
                )
            }
        } else {
            buckets = []
        }

        let modelUsage = models.map {
            CodexModelTokenUsage(model: $0.key, tokens: $0.value.totalTokens)
        }.sorted {
            if $0.tokens != $1.tokens { return $0.tokens > $1.tokens }
            return $0.model.localizedCaseInsensitiveCompare($1.model)
                == .orderedAscending
        }
        let tokenUsage = foundUsage
            ? CodexAccountTokenUsage(
                lifetimeTokens: nil,
                peakDailyTokens: buckets.map(\.tokens).max(),
                longestRunningTurnSeconds: nil,
                dailyUsageBuckets: buckets,
                modelUsage: modelUsage,
                isModelUsagePartial: true,
                localDailyDetails: nil
            )
            : nil

        let currentWeekStart = calendar.date(byAdding: .day, value: -6, to: today)
            ?? now.addingTimeInterval(-6 * 86_400)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let currentCount = rootSessionStart.values.filter {
            $0 >= currentWeekStart && $0 < nextDay
        }.count
        let previousCount = rootSessionStart.values.filter {
            $0 >= previousWeekCutoff && $0 < currentWeekStart
        }.count
        let recentTaskActivity = currentCount + previousCount > 0
            ? CodexRecentTaskActivity(
                currentWeekCount: currentCount,
                previousWeekCount: previousCount,
                isPartial: true
            )
            : nil

        return Result(
            tokenUsage: tokenUsage,
            recentTaskActivity: recentTaskActivity,
            activeTasks: tasks.values.compactMap { task in
                guard task.state.isActive, task.updatedAt >= activeTaskCutoff else {
                    return nil
                }
                return task.snapshot
            },
            activeGoals: goals.values.sorted { $0.updatedAt > $1.updatedAt },
            latestObservedAt: latestObservedAt,
            sessionModels: sessionModels
        )
    }

    private func parseGoal(
        _ record: [String: Any],
        sessionID: String,
        timestamp: Date,
        goals: inout [String: ClaudeCodeActiveGoal]
    ) {
        let isGoal = record["type"] as? String == "active_goal"
            || (record["type"] as? String == "system"
                && record["subtype"] as? String == "active_goal")
        guard isGoal else { return }
        guard let rawValue = record["value"] else { return }
        if rawValue is NSNull {
            goals.removeValue(forKey: sessionID)
            return
        }
        guard
            let value = rawValue as? [String: Any],
            let objective = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                value["condition"] ?? value["objective"]
            )
        else {
            return
        }
        let createdAt = ClaudeCodeDateParser.date(from: value["set_at"])
            ?? ClaudeCodeDateParser.date(from: value["createdAt"])
        goals[sessionID] = ClaudeCodeActiveGoal(
            sessionID: sessionID,
            objective: objective,
            state: goalState(value["status"]),
            iterations: ClaudeCodeStatusLineTelemetryParser
                .nonnegativeInt64(value["iterations"]).map(Int.init),
            lastReason: ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                value["last_reason"] ?? value["lastReason"]
            ),
            createdAt: createdAt,
            updatedAt: timestamp,
            tokenBudget: ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
                value["tokenBudget"]
            ),
            tokensUsed: ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
                value["tokensUsed"]
            ),
            timeUsedSeconds: ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
                value["timeUsedSeconds"]
            )
        )
    }

    private func parseTask(
        _ record: [String: Any],
        sessionID: String,
        timestamp: Date,
        tasks: inout [String: MutableTask]
    ) {
        guard record["type"] as? String == "system",
              let subtype = record["subtype"] as? String,
              ["task_started", "task_progress", "task_updated", "task_notification"]
                .contains(subtype),
              let id = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
                  record["task_id"] ?? record["taskId"]
              )
        else {
            return
        }
        var task = tasks[id] ?? MutableTask(
            id: id,
            sessionID: sessionID,
            name: "Background task",
            kind: nil,
            state: .pending,
            description: nil,
            label: nil,
            startedAt: timestamp,
            tokenCount: nil,
            lastToolName: nil,
            updatedAt: timestamp
        )
        task.updatedAt = timestamp
        if let description = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
            record["description"]
        ) {
            task.description = description
            task.name = description
        }
        task.kind = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
            record["subagent_type"] ?? record["task_type"]
        ) ?? task.kind
        task.lastToolName = ClaudeCodeStatusLineTelemetryParser.nonBlankString(
            record["last_tool_name"]
        ) ?? task.lastToolName
        if let usage = record["usage"] as? [String: Any] {
            task.tokenCount = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
                usage["total_tokens"]
            ) ?? task.tokenCount
        }

        switch subtype {
        case "task_started":
            task.state = .running
        case "task_updated":
            if let patch = record["patch"] as? [String: Any],
               let state = taskState(patch["status"]) {
                task.state = state
            }
        case "task_notification":
            task.state = taskState(record["status"]) ?? .stopped
        default:
            break
        }
        tasks[id] = task
    }

    private func tokenBreakdown(
        _ usage: [String: Any]
    ) -> CodexTokenBreakdown {
        let input = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
            usage["input_tokens"]
        ) ?? 0
        let output = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
            usage["output_tokens"]
        ) ?? 0
        let cacheRead = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
            usage["cache_read_input_tokens"]
        ) ?? 0
        let cacheWrite = ClaudeCodeStatusLineTelemetryParser.nonnegativeInt64(
            usage["cache_creation_input_tokens"]
        ) ?? 0
        return CodexTokenBreakdown(
            inputTokens: input,
            cachedInputTokens: cacheRead,
            cacheWriteInputTokens: cacheWrite,
            outputTokens: output,
            reasoningOutputTokens: 0,
            totalTokens: input + output + cacheRead + cacheWrite
        )
    }

    private func goalState(_ value: Any?) -> ClaudeCodeGoalState {
        switch ClaudeCodeStatusLineTelemetryParser.nonBlankString(value)?
            .lowercased() {
        case "paused": return .paused
        case "blocked": return .blocked
        case "limited": return .limited
        case "complete", "completed": return .complete
        default: return .active
        }
    }

    private func taskState(_ value: Any?) -> ClaudeCodeTaskState? {
        switch ClaudeCodeStatusLineTelemetryParser.nonBlankString(value)?
            .lowercased() {
        case "pending": return .pending
        case "running", "in_progress": return .running
        case "paused": return .paused
        case "completed": return .completed
        case "failed": return .failed
        case "stopped", "killed": return .stopped
        default: return nil
        }
    }

    private func minDate(_ lhs: Date?, _ rhs: Date) -> Date {
        guard let lhs else { return rhs }
        return min(lhs, rhs)
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date) -> Date {
        guard let lhs else { return rhs }
        return max(lhs, rhs)
    }

    private struct MutableTask {
        let id: String
        let sessionID: String?
        var name: String
        var kind: String?
        var state: ClaudeCodeTaskState
        var description: String?
        var label: String?
        var startedAt: Date?
        var tokenCount: Int64?
        var lastToolName: String?
        var updatedAt: Date

        var snapshot: ClaudeCodeActiveTask {
            ClaudeCodeActiveTask(
                id: id,
                sessionID: sessionID,
                name: name,
                kind: kind,
                state: state,
                description: description,
                label: label,
                startedAt: startedAt,
                tokenCount: tokenCount,
                lastToolName: lastToolName,
                observedAt: updatedAt
            )
        }
    }
}

enum ClaudeCodeDateParser {
    static func date(from value: Any?) -> Date? {
        if let milliseconds = ClaudeCodeStatusLineTelemetryParser.finiteDouble(value) {
            let seconds = milliseconds > 10_000_000_000
                ? milliseconds / 1_000
                : milliseconds
            return Date(timeIntervalSince1970: seconds)
        }
        guard let string = value as? String else { return nil }
        return date(from: string)
    }

    static func date(from string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }
}
