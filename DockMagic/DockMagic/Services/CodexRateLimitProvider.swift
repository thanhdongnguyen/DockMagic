import Foundation

enum CodexRateLimitProviderError: LocalizedError, Equatable {
    case executableNotFound
    case executableNotRunnable(String)
    case launchFailed(String)
    case timedOut
    case serverError(String)
    case invalidResponse
    case supportedWindowsMissing

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Codex CLI was not found. Install Codex CLI, then activate Codex again so DockMagic can detect it automatically."
        case let .executableNotRunnable(path):
            "Codex is not executable at \(path)."
        case let .launchFailed(message):
            "Codex could not be launched: \(message)"
        case .timedOut:
            "Codex did not return usage limits in time."
        case let .serverError(message):
            "Codex returned an error: \(message)"
        case .invalidResponse:
            "Codex returned an unreadable usage response."
        case .supportedWindowsMissing:
            "Codex did not report a 5-hour or weekly usage window."
        }
    }
}

protocol CodexExecutableLocating {
    func locate(overridePath: String?) throws -> URL
}

struct CodexExecutableLocator: CodexExecutableLocating {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let homeDirectory: URL

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    func locate(overridePath: String?) throws -> URL {
        if let overridePath, !overridePath.isEmpty {
            let expanded = NSString(string: overridePath).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            guard fileManager.isExecutableFile(atPath: url.path) else {
                throw CodexRateLimitProviderError.executableNotRunnable(url.path)
            }
            return url
        }

        for candidate in automaticCandidates() {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw CodexRateLimitProviderError.executableNotFound
    }

    private func automaticCandidates() -> [URL] {
        var candidates: [URL] = []

        if let configuredPath = environment["CODEX_EXECUTABLE"],
           !configuredPath.isEmpty {
            candidates.append(URL(fileURLWithPath: configuredPath))
        }

        if let path = environment["PATH"] {
            candidates.append(contentsOf:
                contentsOfPath(path).map {
                    URL(fileURLWithPath: $0, isDirectory: true)
                        .appendingPathComponent("codex")
                }
            )
        }

        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
            homeDirectory.appendingPathComponent(".local/bin/codex")
        ])

        let nvmNodeVersions = homeDirectory
            .appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let versions = try? fileManager.contentsOfDirectory(
            at: nvmNodeVersions,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf:
                versions
                    .sorted { $0.lastPathComponent > $1.lastPathComponent }
                    .map { $0.appendingPathComponent("bin/codex") }
            )
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }

    private func contentsOfPath(_ path: String) -> [String] {
        path.split(separator: ":").map(String.init).filter { !$0.isEmpty }
    }
}

protocol CodexRateLimitProviding: Sendable {
    func fetchRateLimits(executableURL: URL) async throws
        -> CodexRateLimitSnapshot
}

struct CodexAppServerRateLimitProvider: CodexRateLimitProviding {
    private static let modelUsageResponseIDBase = 1_000

    let timeout: TimeInterval

    init(timeout: TimeInterval = 12) {
        self.timeout = timeout
    }

    func fetchRateLimits(executableURL: URL) async throws
        -> CodexRateLimitSnapshot {
        let timeout = timeout
        let cancellation = CodexProcessCancellation()

        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                try Self.fetchSynchronously(
                    executableURL: executableURL,
                    timeout: timeout,
                    cancellation: cancellation
                )
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func fetchSynchronously(
        executableURL: URL,
        timeout: TimeInterval,
        cancellation: CodexProcessCancellation
    ) throws -> CodexRateLimitSnapshot {
        guard !cancellation.isCancelled else {
            throw CancellationError()
        }

        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        let timeoutState = ProcessTimeoutState()

        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        let executableDirectory = executableURL.deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(executableDirectory):\(existingPath)"
        process.environment = environment

        do {
            try process.run()
            cancellation.install(process)
        } catch {
            throw CodexRateLimitProviderError.launchFailed(
                error.localizedDescription
            )
        }

        defer {
            cancellation.clear(process)
        }

        let timeoutWork = DispatchWorkItem {
            timeoutState.markTimedOut()
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout,
            execute: timeoutWork
        )

        let fetchedAt = Date()
        do {
            let payload = try initialRequestPayload()
            try standardInput.fileHandleForWriting.write(contentsOf: payload)
        } catch {
            timeoutWork.cancel()
            if process.isRunning {
                process.terminate()
            }
            throw CodexRateLimitProviderError.launchFailed(
                error.localizedDescription
            )
        }

        var output = Data()
        while !timeoutState.didTimeOut, !cancellation.isCancelled {
            let chunk = standardOutput.fileHandleForReading.availableData
            if chunk.isEmpty {
                break
            }
            output.append(chunk)
            if CodexRateLimitParser.containsCompleteDashboardResponse(output) {
                break
            }
        }

        let hasCompleteDashboardResponse = CodexRateLimitParser
            .containsCompleteDashboardResponse(output)
        let localModelUsage = hasCompleteDashboardResponse
            ? CodexLocalModelUsageReader().read(fetchedAt: fetchedAt)
            : nil
        let alreadyHasLocalToday = localModelUsage?.dailyDetails?.contains {
            Calendar.current.isDate($0.startDate, inSameDayAs: fetchedAt)
        } == true
        let localDailyDetail: CodexDailyTokenDetail?
        if hasCompleteDashboardResponse, !alreadyHasLocalToday {
            let result = try? CodexLocalDailyTokenDetailReader()
                .readDetail(for: fetchedAt)
            localDailyDetail = result?.detail
        } else {
            localDailyDetail = nil
        }

        if localModelUsage == nil,
           !timeoutState.didTimeOut,
           !cancellation.isCancelled,
           hasCompleteDashboardResponse {
            let plan = CodexRateLimitParser.modelUsageRequestPlan(
                output,
                fetchedAt: fetchedAt
            )
            if !plan.threadIDs.isEmpty,
               let payload = try? modelUsageRequestPayload(
                   threadIDs: plan.threadIDs
               ),
               (try? standardInput.fileHandleForWriting.write(
                   contentsOf: payload
               )) != nil {
                let responseIDs = Set(plan.threadIDs.indices.map {
                    modelUsageResponseIDBase + $0
                })
                while !timeoutState.didTimeOut, !cancellation.isCancelled {
                    let chunk = standardOutput.fileHandleForReading.availableData
                    if chunk.isEmpty {
                        break
                    }
                    output.append(chunk)
                    if CodexRateLimitParser.containsResponses(
                        responseIDs,
                        in: output
                    ) {
                        break
                    }
                }
            }
        }

        timeoutWork.cancel()
        try? standardInput.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
        }

        if cancellation.isCancelled {
            throw CancellationError()
        }

        if timeoutState.didTimeOut,
           !CodexRateLimitParser.containsRateLimitResponse(output) {
            throw CodexRateLimitProviderError.timedOut
        }

        return try CodexRateLimitParser.parseJSONLines(
            output,
            fetchedAt: fetchedAt,
            localModelUsage: localModelUsage,
            localDailyDetail: localDailyDetail
        )
    }

    private static func initialRequestPayload() throws -> Data {
        let requests: [[String: Any]] = [
            [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "dockmagic",
                        "title": "DockMagic",
                        "version": "1.0"
                    ],
                    "capabilities": [
                        "experimentalApi": true,
                        "optOutNotificationMethods": []
                    ]
                ]
            ],
            [
                "method": "initialized"
            ],
            [
                "id": 2,
                "method": "account/rateLimits/read",
                "params": NSNull()
            ],
            [
                "id": 3,
                "method": "account/usage/read",
                "params": NSNull()
            ],
            [
                "id": 4,
                "method": "thread/list",
                "params": [
                    "limit": 500,
                    "sortKey": "created_at",
                    "sortDirection": "desc",
                    "archived": false,
                    "useStateDbOnly": true
                ]
            ],
            [
                "id": 5,
                "method": "thread/list",
                "params": [
                    "limit": 500,
                    "sortKey": "created_at",
                    "sortDirection": "desc",
                    "archived": true,
                    "useStateDbOnly": true
                ]
            ]
        ]

        var payload = Data()
        for request in requests {
            payload.append(
                try JSONSerialization.data(withJSONObject: request)
            )
            payload.append(0x0A)
        }
        return payload
    }

    private static func modelUsageRequestPayload(
        threadIDs: [String]
    ) throws -> Data {
        var payload = Data()
        for (index, threadID) in threadIDs.enumerated() {
            let request: [String: Any] = [
                "id": modelUsageResponseIDBase + index,
                "method": "account/usage/read",
                "params": ["threadId": threadID]
            ]
            payload.append(try JSONSerialization.data(withJSONObject: request))
            payload.append(0x0A)
        }
        return payload
    }
}

private struct CodexThreadListPage {
    let threads: [[String: Any]]
    let oldestCreatedAt: Date?
    let hasNextPage: Bool
}

struct CodexModelUsageRequestPlan: Equatable, Sendable {
    let threadIDs: [String]
    let isPartial: Bool
}

struct CodexLocalModelUsageResult: Equatable, Sendable {
    let rows: [CodexModelTokenUsage]
    let isPartial: Bool
    let dailyDetails: [CodexDailyTokenDetail]?

    init(
        rows: [CodexModelTokenUsage],
        isPartial: Bool,
        dailyDetails: [CodexDailyTokenDetail]? = nil
    ) {
        self.rows = rows
        self.isPartial = isPartial
        self.dailyDetails = dailyDetails
    }
}

struct CodexLocalModelUsageReader: Sendable {
    static let maximumFiles = 200
    static let maximumBytes: Int64 = 64 * 1_024 * 1_024

    let stateDatabaseURL: URL?
    let sessionsRoot: URL
    let maximumFiles: Int
    let maximumBytes: Int64

    init(
        sessionsRoot: URL? = nil,
        stateDatabaseURL: URL? = nil,
        maximumFiles: Int = Self.maximumFiles,
        maximumBytes: Int64 = Self.maximumBytes,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        if let sessionsRoot {
            self.sessionsRoot = sessionsRoot
            self.stateDatabaseURL = stateDatabaseURL
        } else {
            let configuredCodexHome = environment["CODEX_HOME"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let codexHome = configuredCodexHome.flatMap { value in
                value.isEmpty
                    ? nil
                    : URL(
                        fileURLWithPath: NSString(string: value)
                            .expandingTildeInPath
                    )
            } ?? homeDirectory.appendingPathComponent(".codex")
            self.stateDatabaseURL = stateDatabaseURL
                ?? codexHome.appendingPathComponent("state_5.sqlite")
            self.sessionsRoot = codexHome.appendingPathComponent(
                "sessions",
                isDirectory: true
            )
        }
        self.maximumFiles = maximumFiles
        self.maximumBytes = maximumBytes
    }

    func read(fetchedAt: Date = .now) -> CodexLocalModelUsageResult? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: fetchedAt)
        guard
            let windowStart = calendar.date(
                byAdding: .day,
                value: -(CodexRateLimitParser.modelUsageWindowDays - 1),
                to: today
            ),
            let nextDay = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            return CodexLocalModelUsageResult(rows: [], isPartial: true)
        }

        if let databaseResult = readStateDatabase(windowStart: windowStart) {
            return databaseResult
        }
        return readRolloutMetadata(
            windowStart: windowStart,
            nextDay: nextDay
        )
    }

    private func readStateDatabase(
        windowStart: Date
    ) -> CodexLocalModelUsageResult? {
        guard
            let stateDatabaseURL,
            FileManager.default.fileExists(atPath: stateDatabaseURL.path),
            FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3")
        else {
            return nil
        }

        let cutoff = Int64(windowStart.timeIntervalSince1970)
        let query = """
            SELECT model, SUM(tokens_used)
            FROM threads
            WHERE created_at >= \(cutoff)
              AND model IS NOT NULL
              AND TRIM(model) <> ''
              AND tokens_used > 0
            GROUP BY model
            ORDER BY SUM(tokens_used) DESC, model COLLATE NOCASE ASC;
            """
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-separator",
            "\t",
            stateDatabaseURL.path,
            query
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let rows: [CodexModelTokenUsage] = value
            .split(separator: "\n")
            .compactMap { line in
                let components = line.split(
                    separator: "\t",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )
                guard
                    components.count == 2,
                    let tokens = Int64(components[1]),
                    tokens > 0
                else {
                    return nil
                }
                let model = String(components[0])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !model.isEmpty else { return nil }
                return CodexModelTokenUsage(model: model, tokens: tokens)
            }
        return CodexLocalModelUsageResult(rows: rows, isPartial: false)
    }

    private func readRolloutMetadata(
        windowStart: Date,
        nextDay: Date
    ) -> CodexLocalModelUsageResult? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(
                atPath: sessionsRoot.path,
                isDirectory: &isDirectory
            ),
            isDirectory.boolValue
        else {
            return nil
        }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return CodexLocalModelUsageResult(rows: [], isPartial: true)
        }

        var candidates: [(
            url: URL,
            modifiedAt: Date,
            size: Int64
        )] = []
        var scanIsPartial = false
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                guard
                    values.isRegularFile == true,
                    let modifiedAt = values.contentModificationDate,
                    modifiedAt >= windowStart
                else {
                    continue
                }
                candidates.append((
                    url,
                    modifiedAt,
                    Int64(values.fileSize ?? 0)
                ))
            } catch {
                scanIsPartial = true
            }
        }
        candidates.sort {
            if $0.modifiedAt != $1.modifiedAt {
                return $0.modifiedAt > $1.modifiedAt
            }
            return $0.url.path < $1.url.path
        }

        if candidates.count > maximumFiles {
            scanIsPartial = true
        }
        var selected: [URL] = []
        var selectedBytes: Int64 = 0
        for candidate in candidates.prefix(maximumFiles) {
            guard selectedBytes + candidate.size <= maximumBytes else {
                scanIsPartial = true
                break
            }
            selected.append(candidate.url)
            selectedBytes += candidate.size
        }

        var tokensByModel: [String: Int64] = [:]
        var usageByDay: [Date: CodexTokenBreakdown] = [:]
        var usageByDayAndHour: [
            Date: [Date: CodexTokenBreakdown]
        ] = [:]
        var usageByDayAndModel: [
            Date: [String: CodexTokenBreakdown]
        ] = [:]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        let fallbackTimestampFormatter = ISO8601DateFormatter()
        fallbackTimestampFormatter.formatOptions = [.withInternetDateTime]

        for url in selected {
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                var currentModel: String?
                for line in data.split(separator: 0x0A) {
                    guard
                        let object = try? JSONSerialization.jsonObject(
                            with: Data(line)
                        ),
                        let dictionary = object as? [String: Any],
                        let payload = dictionary["payload"] as? [String: Any]
                    else {
                        continue
                    }

                    if dictionary["type"] as? String == "turn_context" {
                        currentModel = normalizedModel(payload["model"])
                        continue
                    }

                    guard
                        dictionary["type"] as? String == "event_msg",
                        payload["type"] as? String == "token_count",
                        let timestamp = dictionary["timestamp"] as? String,
                        let eventDate = timestampFormatter.date(from: timestamp)
                            ?? fallbackTimestampFormatter.date(from: timestamp),
                        eventDate >= windowStart,
                        eventDate < nextDay,
                        let model = currentModel,
                        let info = payload["info"] as? [String: Any],
                        let lastUsage = info["last_token_usage"]
                            as? [String: Any],
                        let breakdown = tokenBreakdown(from: lastUsage),
                        breakdown.totalTokens > 0,
                        let hour = calendar.dateInterval(
                            of: .hour,
                            for: eventDate
                        )?.start
                    else {
                        continue
                    }
                    let day = calendar.startOfDay(for: eventDate)
                    tokensByModel[model, default: 0] += breakdown.totalTokens
                    usageByDay[day] = usageByDay[day, default: .zero]
                        .adding(breakdown)
                    usageByDayAndHour[day, default: [:]][hour] =
                        usageByDayAndHour[day, default: [:]][hour, default: .zero]
                            .adding(breakdown)
                    usageByDayAndModel[day, default: [:]][model] =
                        usageByDayAndModel[day, default: [:]][
                            model,
                            default: .zero
                        ].adding(breakdown)
                }
            } catch {
                scanIsPartial = true
            }
        }

        let rows = tokensByModel
            .map { CodexModelTokenUsage(model: $0.key, tokens: $0.value) }
            .sorted {
                if $0.tokens != $1.tokens {
                    return $0.tokens > $1.tokens
                }
                return $0.model.localizedCaseInsensitiveCompare($1.model)
                    == .orderedAscending
            }
        let dailyDetails = usageByDay.keys.sorted().map { day in
            let hourlyUsage: [CodexHourlyTokenUsageBucket] =
                (0..<24).compactMap { hour in
                guard let startDate = calendar.date(
                    byAdding: .hour,
                    value: hour,
                    to: day
                ) else {
                    return nil
                }
                return CodexHourlyTokenUsageBucket(
                    startDate: startDate,
                    usage: usageByDayAndHour[day]?[startDate] ?? .zero
                )
            }
            let modelUsage = (usageByDayAndModel[day] ?? [:])
                .map {
                    CodexDailyModelTokenUsage(
                        model: $0.key,
                        usage: $0.value
                    )
                }
                .sorted {
                    if $0.usage.totalTokens != $1.usage.totalTokens {
                        return $0.usage.totalTokens > $1.usage.totalTokens
                    }
                    return $0.model.localizedCaseInsensitiveCompare($1.model)
                        == .orderedAscending
                }
            return CodexDailyTokenDetail(
                startDate: day,
                usage: usageByDay[day] ?? .zero,
                hourlyUsage: hourlyUsage,
                modelUsage: modelUsage,
                isPartial: scanIsPartial
            )
        }
        return CodexLocalModelUsageResult(
            rows: rows,
            isPartial: scanIsPartial,
            dailyDetails: dailyDetails
        )
    }

    private func tokenBreakdown(
        from lastUsage: [String: Any]
    ) -> CodexTokenBreakdown? {
        let input = max(0, int64(lastUsage["input_tokens"]) ?? 0)
        let cachedInput = min(
            input,
            max(0, int64(lastUsage["cached_input_tokens"]) ?? 0)
        )
        let cacheWriteInput = max(
            0,
            int64(lastUsage["cache_write_input_tokens"]) ?? 0
        )
        let output = max(0, int64(lastUsage["output_tokens"]) ?? 0)
        let reasoningOutput = min(
            output,
            max(0, int64(lastUsage["reasoning_output_tokens"]) ?? 0)
        )
        let total = max(
            0,
            int64(lastUsage["total_tokens"]) ?? input + output
        )
        guard total > 0 || input > 0 || output > 0 else { return nil }
        return CodexTokenBreakdown(
            inputTokens: input,
            cachedInputTokens: cachedInput,
            cacheWriteInputTokens: cacheWriteInput,
            outputTokens: output,
            reasoningOutputTokens: reasoningOutput,
            totalTokens: max(total, input + output)
        )
    }

    private func normalizedModel(_ value: Any?) -> String? {
        guard let rawValue = value as? String else { return nil }
        let model = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? nil : model
    }

    private func int64(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }
}

enum CodexRateLimitParser {
    static let modelUsageWindowDays = 30
    static let maximumModelUsageThreads = 100

    static func containsRateLimitResponse(_ data: Data) -> Bool {
        containsResponse(id: 2, in: data)
    }

    static func containsCompleteUsageResponse(_ data: Data) -> Bool {
        containsResponse(id: 2, in: data)
            && containsResponse(id: 3, in: data)
    }

    static func containsCompleteDashboardResponse(_ data: Data) -> Bool {
        containsCompleteUsageResponse(data)
            && containsResponse(id: 4, in: data)
            && containsResponse(id: 5, in: data)
    }

    static func containsResponses(_ ids: Set<Int>, in data: Data) -> Bool {
        ids.allSatisfy { containsResponse(id: $0, in: data) }
    }

    static func modelUsageRequestPlan(
        _ data: Data,
        fetchedAt: Date = .now
    ) -> CodexModelUsageRequestPlan {
        modelUsageRequestPlan(
            from: data.split(separator: 0x0A),
            fetchedAt: fetchedAt
        )
    }

    private static func containsResponse(id: Int, in data: Data) -> Bool {
        data.split(separator: 0x0A).contains { line in
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let dictionary = object as? [String: Any]
            else {
                return false
            }
            return (dictionary["id"] as? NSNumber)?.intValue == id
        }
    }

    static func parseJSONLines(
        _ data: Data,
        fetchedAt: Date = .now,
        localModelUsage: CodexLocalModelUsageResult? = nil,
        localDailyDetail: CodexDailyTokenDetail? = nil
    ) throws -> CodexRateLimitSnapshot {
        let lines = data.split(separator: 0x0A)

        for line in lines {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let dictionary = object as? [String: Any],
                (dictionary["id"] as? NSNumber)?.intValue == 2
            else {
                continue
            }

            if let error = dictionary["error"] as? [String: Any] {
                let message = error["message"] as? String
                    ?? "Unknown app-server error"
                throw CodexRateLimitProviderError.serverError(message)
            }

            guard let result = dictionary["result"] as? [String: Any] else {
                throw CodexRateLimitProviderError.invalidResponse
            }

            let aggregate = aggregateRateLimits(from: result)
            guard let aggregate else {
                throw CodexRateLimitProviderError.invalidResponse
            }

            let windows = [aggregate["primary"], aggregate["secondary"]]
                .compactMap { $0 as? [String: Any] }
                .compactMap(parseWindow)

            let fiveHour = windows.first { $0.kind == .fiveHour }
            let weekly = windows.first { $0.kind == .weekly }
            guard fiveHour != nil || weekly != nil else {
                throw CodexRateLimitProviderError.supportedWindowsMissing
            }

            return CodexRateLimitSnapshot(
                planType: aggregate["planType"] as? String,
                limitID: aggregate["limitId"] as? String,
                fiveHour: fiveHour,
                weekly: weekly,
                tokenUsage: parseTokenUsage(
                    from: lines,
                    fetchedAt: fetchedAt,
                    localModelUsage: localModelUsage,
                    localDailyDetail: localDailyDetail
                ),
                recentTaskActivity: parseRecentTaskActivity(
                    from: lines,
                    fetchedAt: fetchedAt
                ),
                fetchedAt: fetchedAt
            )
        }

        throw CodexRateLimitProviderError.invalidResponse
    }

    private static func parseTokenUsage(
        from lines: [Data.SubSequence],
        fetchedAt: Date,
        localModelUsage: CodexLocalModelUsageResult?,
        localDailyDetail: CodexDailyTokenDetail?
    ) -> CodexAccountTokenUsage? {
        for line in lines {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let dictionary = object as? [String: Any],
                (dictionary["id"] as? NSNumber)?.intValue == 3,
                dictionary["error"] == nil,
                let result = dictionary["result"] as? [String: Any],
                let summary = result["summary"] as? [String: Any]
            else {
                continue
            }

            let buckets = (result["dailyUsageBuckets"] as? [[String: Any]])?
                .compactMap(parseDailyUsageBucket)
                .sorted { $0.startDate < $1.startDate }
                ?? []
            let hasThreadPages = [4, 5].allSatisfy { responseID in
                threadListPage(responseID: responseID, from: lines) != nil
            }
            let appServerModelUsage: (
                rows: [CodexModelTokenUsage],
                isPartial: Bool
            )? = localModelUsage == nil && hasThreadPages
                ? parseModelUsage(
                    from: lines,
                    plan: modelUsageRequestPlan(
                        from: lines,
                        fetchedAt: fetchedAt
                    )
                )
                : nil
            let modelUsage = localModelUsage.map {
                (rows: $0.rows, isPartial: $0.isPartial)
            } ?? appServerModelUsage
            let localDailyDetails = mergedLocalDailyDetails(
                localModelUsage?.dailyDetails,
                additional: localDailyDetail
            )
            let dailyUsageBuckets = mergedDailyUsageBuckets(
                appServerBuckets: buckets,
                localDailyDetails: localDailyDetails,
                fetchedAt: fetchedAt
            )

            return CodexAccountTokenUsage(
                lifetimeTokens: int64(summary["lifetimeTokens"]),
                peakDailyTokens: int64(summary["peakDailyTokens"]),
                longestRunningTurnSeconds: int64(
                    summary["longestRunningTurnSec"]
                ),
                dailyUsageBuckets: dailyUsageBuckets,
                modelUsage: modelUsage?.rows,
                isModelUsagePartial: modelUsage?.isPartial,
                localDailyDetails: localDailyDetails
            )
        }

        return nil
    }

    private static func mergedLocalDailyDetails(
        _ existing: [CodexDailyTokenDetail]?,
        additional: CodexDailyTokenDetail?
    ) -> [CodexDailyTokenDetail]? {
        var details = existing ?? []
        if let additional {
            if let index = details.firstIndex(where: {
                Calendar.current.isDate(
                    $0.startDate,
                    inSameDayAs: additional.startDate
                )
            }) {
                details[index] = additional
            } else {
                details.append(additional)
            }
        }
        guard !details.isEmpty else { return nil }
        return details.sorted { $0.startDate < $1.startDate }
    }

    private static func mergedDailyUsageBuckets(
        appServerBuckets: [CodexTokenUsageDailyBucket],
        localDailyDetails: [CodexDailyTokenDetail]?,
        fetchedAt: Date
    ) -> [CodexTokenUsageDailyBucket] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: fetchedAt)

        guard !appServerBuckets.contains(where: {
            calendar.isDate($0.startDate, inSameDayAs: today)
        }) else {
            return appServerBuckets
        }

        let localTodayTokens = (localDailyDetails ?? [])
            .filter {
                calendar.isDate($0.startDate, inSameDayAs: today)
            }
            .reduce(Int64(0)) { $0 + $1.usage.totalTokens }
        guard localTodayTokens > 0 else { return appServerBuckets }

        var merged = appServerBuckets
        merged.append(
            CodexTokenUsageDailyBucket(
                startDate: today,
                tokens: localTodayTokens
            )
        )
        return merged.sorted { $0.startDate < $1.startDate }
    }

    private static func modelUsageRequestPlan(
        from lines: [Data.SubSequence],
        fetchedAt: Date
    ) -> CodexModelUsageRequestPlan {
        let pages = [4, 5].compactMap { responseID in
            threadListPage(responseID: responseID, from: lines)
        }
        guard pages.count == 2 else {
            return CodexModelUsageRequestPlan(
                threadIDs: [],
                isPartial: true
            )
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: fetchedAt)
        guard
            let windowStart = calendar.date(
                byAdding: .day,
                value: -(modelUsageWindowDays - 1),
                to: today
            ),
            let nextDay = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            return CodexModelUsageRequestPlan(
                threadIDs: [],
                isPartial: true
            )
        }

        let candidates = pages
            .flatMap(\.threads)
            .compactMap { thread -> (id: String, createdAt: Date)? in
                if let parent = thread["parentThreadId"], !(parent is NSNull) {
                    return nil
                }
                guard
                    (thread["ephemeral"] as? Bool) != true,
                    let id = thread["id"] as? String,
                    !id.isEmpty,
                    let timestamp = int64(thread["createdAt"])
                else {
                    return nil
                }
                let createdAt = Date(
                    timeIntervalSince1970: TimeInterval(timestamp)
                )
                guard createdAt >= windowStart, createdAt < nextDay else {
                    return nil
                }
                return (id, createdAt)
            }
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.id < $1.id
            }

        var seen = Set<String>()
        let uniqueThreadIDs = candidates.compactMap { candidate in
            seen.insert(candidate.id).inserted ? candidate.id : nil
        }
        let pageCoverageIsPartial = pages.contains { page in
            guard page.hasNextPage else { return false }
            guard let oldestDate = page.oldestCreatedAt else { return true }
            return oldestDate >= windowStart
        }

        return CodexModelUsageRequestPlan(
            threadIDs: Array(
                uniqueThreadIDs.prefix(maximumModelUsageThreads)
            ),
            isPartial: pageCoverageIsPartial
                || uniqueThreadIDs.count > maximumModelUsageThreads
        )
    }

    private static func parseModelUsage(
        from lines: [Data.SubSequence],
        plan: CodexModelUsageRequestPlan
    ) -> (rows: [CodexModelTokenUsage], isPartial: Bool) {
        let requestedThreadIDs = Set(plan.threadIDs)
        var successfulThreadIDs = Set<String>()
        var tokensByModel: [String: Int64] = [:]
        var hasUnattributedTokens = false

        for line in lines {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let dictionary = object as? [String: Any],
                dictionary["error"] == nil,
                let result = dictionary["result"] as? [String: Any],
                let threadUsage = result["threadUsage"] as? [String: Any],
                let threadID = threadUsage["threadId"] as? String,
                requestedThreadIDs.contains(threadID),
                let groups = threadUsage["groups"] as? [[String: Any]]
            else {
                continue
            }

            successfulThreadIDs.insert(threadID)
            for group in groups {
                let tokens = int64(group["totalTokens"])
                    ?? ((int64(group["inputTokens"]) ?? 0)
                        + (int64(group["outputTokens"]) ?? 0))
                guard tokens > 0 else { continue }

                guard
                    let rawModel = group["model"] as? String,
                    !rawModel.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                else {
                    hasUnattributedTokens = true
                    continue
                }
                let model = rawModel.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                tokensByModel[model, default: 0] += tokens
            }
        }

        let rows = tokensByModel
            .map { CodexModelTokenUsage(model: $0.key, tokens: $0.value) }
            .sorted {
                if $0.tokens != $1.tokens {
                    return $0.tokens > $1.tokens
                }
                return $0.model.localizedCaseInsensitiveCompare($1.model)
                    == .orderedAscending
            }
        let missingThreadUsage = !Set(plan.threadIDs).isSubset(
            of: successfulThreadIDs
        )
        return (
            rows,
            plan.isPartial || missingThreadUsage || hasUnattributedTokens
        )
    }

    private static func parseRecentTaskActivity(
        from lines: [Data.SubSequence],
        fetchedAt: Date
    ) -> CodexRecentTaskActivity? {
        let pages = [4, 5].compactMap { responseID in
            threadListPage(responseID: responseID, from: lines)
        }
        guard pages.count == 2 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: fetchedAt)
        guard
            let currentStart = calendar.date(
                byAdding: .day,
                value: -6,
                to: today
            ),
            let previousStart = calendar.date(
                byAdding: .day,
                value: -13,
                to: today
            ),
            let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: today
            )
        else {
            return nil
        }

        let threads = pages.flatMap(\.threads)
        let rootTaskDates = threads.compactMap { thread -> Date? in
            if let parent = thread["parentThreadId"], !(parent is NSNull) {
                return nil
            }
            if (thread["ephemeral"] as? Bool) == true {
                return nil
            }
            guard let timestamp = int64(thread["createdAt"]) else {
                return nil
            }
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        let currentCount = rootTaskDates.filter {
            $0 >= currentStart && $0 < nextDay
        }.count
        let previousCount = rootTaskDates.filter {
            $0 >= previousStart && $0 < currentStart
        }.count
        let isPartial = pages.contains { page in
            guard page.hasNextPage else { return false }
            guard let oldestDate = page.oldestCreatedAt else { return true }
            return oldestDate >= previousStart
        }

        return CodexRecentTaskActivity(
            currentWeekCount: currentCount,
            previousWeekCount: previousCount,
            isPartial: isPartial
        )
    }

    private static func threadListPage(
        responseID: Int,
        from lines: [Data.SubSequence]
    ) -> CodexThreadListPage? {
        for line in lines {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let dictionary = object as? [String: Any],
                (dictionary["id"] as? NSNumber)?.intValue == responseID,
                dictionary["error"] == nil,
                let result = dictionary["result"] as? [String: Any],
                let threads = result["data"] as? [[String: Any]]
            else {
                continue
            }

            let oldestCreatedAt = threads
                .compactMap { int64($0["createdAt"]) }
                .min()
                .map { Date(timeIntervalSince1970: TimeInterval($0)) }
            let hasNextPage = (result["nextCursor"] as? String)?.isEmpty == false
            return CodexThreadListPage(
                threads: threads,
                oldestCreatedAt: oldestCreatedAt,
                hasNextPage: hasNextPage
            )
        }
        return nil
    }

    private static func parseDailyUsageBucket(
        _ dictionary: [String: Any]
    ) -> CodexTokenUsageDailyBucket? {
        guard
            let startDate = dictionary["startDate"] as? String,
            let date = usageDate(from: startDate),
            let tokens = int64(dictionary["tokens"])
        else {
            return nil
        }

        return CodexTokenUsageDailyBucket(startDate: date, tokens: tokens)
    }

    private static func usageDate(from value: String) -> Date? {
        let components = value.split(separator: "-")
        guard
            components.count == 3,
            let year = Int(components[0]),
            let month = Int(components[1]),
            let day = Int(components[2])
        else {
            return nil
        }

        // App Server returns a calendar day, not an instant. Resolving it at
        // local noon keeps the chart label on that same day across time zones.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: 12
            )
        )
    }

    private static func int64(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }

    private static func aggregateRateLimits(
        from result: [String: Any]
    ) -> [String: Any]? {
        if
            let buckets = result["rateLimitsByLimitId"] as? [String: Any],
            let codex = buckets["codex"] as? [String: Any]
        {
            return codex
        }

        return result["rateLimits"] as? [String: Any]
    }

    private static func parseWindow(
        _ dictionary: [String: Any]
    ) -> CodexRateLimitWindow? {
        guard
            let duration = (dictionary["windowDurationMins"] as? NSNumber)?.intValue,
            let usedPercent = (dictionary["usedPercent"] as? NSNumber)?.intValue
        else {
            return nil
        }

        let kind: CodexRateLimitWindowKind
        switch duration {
        case 300:
            kind = .fiveHour
        case 10_080:
            kind = .weekly
        default:
            return nil
        }

        let resetsAt = (dictionary["resetsAt"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue)
        }

        return CodexRateLimitWindow(
            kind: kind,
            usedPercent: min(max(usedPercent, 0), 100),
            windowDurationMinutes: duration,
            resetsAt: resetsAt
        )
    }
}

private final class CodexProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func install(_ process: Process) {
        let shouldTerminate = lock.withLock {
            self.process = process
            return cancelled
        }

        if shouldTerminate, process.isRunning {
            process.terminate()
        }
    }

    func clear(_ process: Process) {
        lock.withLock {
            if self.process === process {
                self.process = nil
            }
        }
    }

    func cancel() {
        let process = lock.withLock {
            cancelled = true
            return self.process
        }

        if let process, process.isRunning {
            process.terminate()
        }
    }
}

private final class ProcessTimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var didTimeOut: Bool {
        lock.withLock { value }
    }

    func markTimedOut() {
        lock.withLock {
            value = true
        }
    }
}
