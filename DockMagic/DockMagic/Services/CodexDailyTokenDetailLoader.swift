import Foundation

protocol CodexDailyTokenDetailLoading: Sendable {
    func loadDetail(for date: Date) async throws -> CodexDailyTokenDetail?
}

struct CodexDailyTokenDetailReadResult: Equatable, Sendable {
    let detail: CodexDailyTokenDetail?
    let candidateFileCount: Int
    let scannedFileCount: Int
    let scannedBytes: Int64
    let usedStateDatabaseIndex: Bool
}

/// Reads only rollout files whose thread lifetime can overlap the requested
/// calendar day. The state database is the primary index; filesystem discovery
/// is a fallback for older Codex installations and isolated test fixtures.
struct CodexLocalDailyTokenDetailReader: Sendable {
    private struct CandidateSet {
        let urls: [URL]
        let isPartial: Bool
        let usedStateDatabaseIndex: Bool
    }

    private struct Accumulator {
        var usage = CodexTokenBreakdown.zero
        var usageByHour: [Date: CodexTokenBreakdown] = [:]
        var usageByModel: [String: CodexTokenBreakdown] = [:]

        mutating func add(
            _ breakdown: CodexTokenBreakdown,
            at hour: Date,
            model: String
        ) {
            usage = usage.adding(breakdown)
            usageByHour[hour] = usageByHour[hour, default: .zero]
                .adding(breakdown)
            usageByModel[model] = usageByModel[model, default: .zero]
                .adding(breakdown)
        }
    }

    private let stateDatabaseURL: URL?
    private let sessionRoots: [URL]
    private let readChunkSize: Int

    private var fileManager: FileManager { .default }

    init(
        sessionRoots: [URL]? = nil,
        stateDatabaseURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        readChunkSize: Int = 256 * 1_024
    ) {
        precondition(readChunkSize > 0, "Read chunk size must be positive.")
        self.readChunkSize = readChunkSize

        if let sessionRoots {
            self.sessionRoots = sessionRoots
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
            self.sessionRoots = [
                codexHome.appendingPathComponent("sessions", isDirectory: true),
                codexHome.appendingPathComponent(
                    "archived_sessions",
                    isDirectory: true
                )
            ]
        }
    }

    func readDetail(for date: Date) throws -> CodexDailyTokenDetailReadResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)
        else {
            return CodexDailyTokenDetailReadResult(
                detail: nil,
                candidateFileCount: 0,
                scannedFileCount: 0,
                scannedBytes: 0,
                usedStateDatabaseIndex: false
            )
        }

        let candidates = candidateFiles(
            dayStart: dayStart,
            nextDay: nextDay,
            calendar: calendar
        )
        let timestampParser = CodexRolloutTimestampParser()
        var accumulator = Accumulator()
        var scanIsPartial = candidates.isPartial
        var scannedFileCount = 0
        var scannedBytes: Int64 = 0

        for url in candidates.urls {
            try Task.checkCancellation()
            do {
                let bytes = try scan(
                    url: url,
                    dayStart: dayStart,
                    nextDay: nextDay,
                    calendar: calendar,
                    timestampParser: timestampParser,
                    accumulator: &accumulator
                )
                scannedFileCount += 1
                scannedBytes += bytes
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                scanIsPartial = true
            }
        }

        let detail = makeDetail(
            dayStart: dayStart,
            calendar: calendar,
            accumulator: accumulator,
            isPartial: scanIsPartial
        )
        return CodexDailyTokenDetailReadResult(
            detail: detail,
            candidateFileCount: candidates.urls.count,
            scannedFileCount: scannedFileCount,
            scannedBytes: scannedBytes,
            usedStateDatabaseIndex: candidates.usedStateDatabaseIndex
        )
    }

    private func candidateFiles(
        dayStart: Date,
        nextDay: Date,
        calendar: Calendar
    ) -> CandidateSet {
        if let indexed = indexedCandidateFiles(
            dayStart: dayStart,
            nextDay: nextDay
        ) {
            return indexed
        }
        return filesystemCandidateFiles(
            dayStart: dayStart,
            nextDay: nextDay,
            calendar: calendar
        )
    }

    private func indexedCandidateFiles(
        dayStart: Date,
        nextDay: Date
    ) -> CandidateSet? {
        guard
            let stateDatabaseURL,
            fileManager.fileExists(atPath: stateDatabaseURL.path),
            fileManager.isExecutableFile(atPath: "/usr/bin/sqlite3")
        else {
            return nil
        }

        let startTimestamp = Int64(dayStart.timeIntervalSince1970)
        let endTimestamp = Int64(nextDay.timeIntervalSince1970)
        let query = """
            SELECT rollout_path
            FROM threads
            WHERE created_at < \(endTimestamp)
              AND updated_at >= \(startTimestamp)
              AND rollout_path IS NOT NULL
              AND TRIM(rollout_path) <> ''
            ORDER BY created_at ASC, id ASC;
            """
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-noheader",
            stateDatabaseURL.path,
            query
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Drain stdout before waiting so a large history cannot fill the
            // pipe buffer and block sqlite3 from terminating.
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }

            guard let value = String(data: data, encoding: .utf8) else {
                return nil
            }
            let urls = deduplicatedURLs(
                value.split(whereSeparator: { $0.isNewline }).map {
                    URL(fileURLWithPath: String($0))
                }
            )
            let missingFile = urls.contains {
                !fileManager.fileExists(atPath: $0.path)
            }
            return CandidateSet(
                urls: urls.filter { fileManager.fileExists(atPath: $0.path) },
                isPartial: missingFile,
                usedStateDatabaseIndex: true
            )
        } catch {
            return nil
        }
    }

    private func filesystemCandidateFiles(
        dayStart: Date,
        nextDay: Date,
        calendar: Calendar
    ) -> CandidateSet {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .creationDateKey
        ]
        var urls: [URL] = []
        var isPartial = false

        for root in sessionRoots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(
                atPath: root.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                continue
            }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                isPartial = true
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "jsonl" else { continue }
                do {
                    let values = try url.resourceValues(forKeys: keys)
                    guard
                        values.isRegularFile == true,
                        let modifiedAt = values.contentModificationDate,
                        modifiedAt >= dayStart
                    else {
                        continue
                    }
                    let startedAt = sessionStartDate(
                        for: url,
                        fallback: values.creationDate,
                        calendar: calendar
                    )
                    guard startedAt == nil || startedAt! < nextDay else {
                        continue
                    }
                    urls.append(url)
                } catch {
                    isPartial = true
                }
            }
        }

        return CandidateSet(
            urls: deduplicatedURLs(urls).sorted { $0.path < $1.path },
            isPartial: isPartial,
            usedStateDatabaseIndex: false
        )
    }

    private func sessionStartDate(
        for url: URL,
        fallback: Date?,
        calendar: Calendar
    ) -> Date? {
        let filename = url.deletingPathExtension().lastPathComponent
        let prefix = "rollout-"
        guard filename.hasPrefix(prefix) else { return fallback }
        let start = filename.index(filename.startIndex, offsetBy: prefix.count)
        guard let end = filename.index(start, offsetBy: 19, limitedBy: filename.endIndex)
        else {
            return fallback
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        return formatter.date(from: String(filename[start..<end])) ?? fallback
    }

    private func deduplicatedURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private func scan(
        url: URL,
        dayStart: Date,
        nextDay: Date,
        calendar: Calendar,
        timestampParser: CodexRolloutTimestampParser,
        accumulator: inout Accumulator
    ) throws -> Int64 {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var currentModel: String?
        var buffer = Data()
        var bytesRead: Int64 = 0
        var reachedNextDay = false

        while !reachedNextDay {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: readChunkSize),
                  !chunk.isEmpty else {
                break
            }
            bytesRead += Int64(chunk.count)
            buffer.append(chunk)

            var lineStart = buffer.startIndex
            while let newline = buffer[lineStart...].firstIndex(of: 0x0A) {
                if newline > lineStart {
                    reachedNextDay = process(
                        line: buffer[lineStart..<newline],
                        dayStart: dayStart,
                        nextDay: nextDay,
                        calendar: calendar,
                        timestampParser: timestampParser,
                        currentModel: &currentModel,
                        accumulator: &accumulator
                    )
                }
                lineStart = buffer.index(after: newline)
                if reachedNextDay { break }
            }
            if lineStart > buffer.startIndex {
                buffer.removeSubrange(buffer.startIndex..<lineStart)
            }
        }

        if !reachedNextDay, !buffer.isEmpty {
            _ = process(
                line: buffer[buffer.startIndex..<buffer.endIndex],
                dayStart: dayStart,
                nextDay: nextDay,
                calendar: calendar,
                timestampParser: timestampParser,
                currentModel: &currentModel,
                accumulator: &accumulator
            )
        }
        return bytesRead
    }

    private func process(
        line: Data.SubSequence,
        dayStart: Date,
        nextDay: Date,
        calendar: Calendar,
        timestampParser: CodexRolloutTimestampParser,
        currentModel: inout String?,
        accumulator: inout Accumulator
    ) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: Data(line)),
            let dictionary = object as? [String: Any],
            let payload = dictionary["payload"] as? [String: Any]
        else {
            return false
        }

        let eventDate = (dictionary["timestamp"] as? String)
            .flatMap(timestampParser.date)
        if let eventDate, eventDate >= nextDay {
            return true
        }

        if dictionary["type"] as? String == "turn_context" {
            currentModel = normalizedModel(payload["model"])
            return false
        }

        guard
            dictionary["type"] as? String == "event_msg",
            payload["type"] as? String == "token_count",
            let eventDate,
            eventDate >= dayStart,
            let model = currentModel,
            let info = payload["info"] as? [String: Any],
            let lastUsage = info["last_token_usage"] as? [String: Any],
            let breakdown = tokenBreakdown(from: lastUsage),
            breakdown.totalTokens > 0,
            let hour = calendar.dateInterval(of: .hour, for: eventDate)?.start
        else {
            return false
        }

        accumulator.add(breakdown, at: hour, model: model)
        return false
    }

    private func makeDetail(
        dayStart: Date,
        calendar: Calendar,
        accumulator: Accumulator,
        isPartial: Bool
    ) -> CodexDailyTokenDetail? {
        guard accumulator.usage.totalTokens > 0 else { return nil }
        let hourlyUsage = (0..<24).compactMap { hour -> CodexHourlyTokenUsageBucket? in
            guard let startDate = calendar.date(
                byAdding: .hour,
                value: hour,
                to: dayStart
            ) else {
                return nil
            }
            return CodexHourlyTokenUsageBucket(
                startDate: startDate,
                usage: accumulator.usageByHour[startDate] ?? .zero
            )
        }
        let modelUsage = accumulator.usageByModel.map {
            CodexDailyModelTokenUsage(model: $0.key, usage: $0.value)
        }.sorted {
            if $0.usage.totalTokens != $1.usage.totalTokens {
                return $0.usage.totalTokens > $1.usage.totalTokens
            }
            return $0.model.localizedCaseInsensitiveCompare($1.model)
                == .orderedAscending
        }
        return CodexDailyTokenDetail(
            startDate: dayStart,
            usage: accumulator.usage,
            hourlyUsage: hourlyUsage,
            modelUsage: modelUsage,
            isPartial: isPartial
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

private final class CodexRolloutTimestampParser: @unchecked Sendable {
    private let fractional = ISO8601DateFormatter()
    private let fallback = ISO8601DateFormatter()

    init() {
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        fallback.formatOptions = [.withInternetDateTime]
    }

    func date(from value: String) -> Date? {
        fractional.date(from: value) ?? fallback.date(from: value)
    }
}

actor CodexDailyTokenDetailLoader: CodexDailyTokenDetailLoading {
    typealias LoadOperation = @Sendable (Date) async throws
        -> CodexDailyTokenDetail?

    private struct CacheEntry {
        let detail: CodexDailyTokenDetail?
        let loadedAt: Date
    }

    private let loadOperation: LoadOperation
    private let now: @Sendable () -> Date
    private let recentCacheLifetime: TimeInterval
    private let maximumCacheEntries: Int
    private var cache: [Date: CacheEntry] = [:]
    private var inFlight: [
        Date: Task<CodexDailyTokenDetail?, any Error>
    ] = [:]

    init(
        reader: CodexLocalDailyTokenDetailReader = .init(),
        recentCacheLifetime: TimeInterval = 30,
        maximumCacheEntries: Int = 32,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(recentCacheLifetime >= 0)
        precondition(maximumCacheEntries > 0)
        self.recentCacheLifetime = recentCacheLifetime
        self.maximumCacheEntries = maximumCacheEntries
        self.now = now
        self.loadOperation = { date in
            try await Task.detached(priority: .utility) {
                try reader.readDetail(for: date).detail
            }.value
        }
    }

    init(
        recentCacheLifetime: TimeInterval = 30,
        maximumCacheEntries: Int = 32,
        now: @escaping @Sendable () -> Date = { Date() },
        loadOperation: @escaping LoadOperation
    ) {
        precondition(recentCacheLifetime >= 0)
        precondition(maximumCacheEntries > 0)
        self.recentCacheLifetime = recentCacheLifetime
        self.maximumCacheEntries = maximumCacheEntries
        self.now = now
        self.loadOperation = loadOperation
    }

    func loadDetail(for date: Date) async throws -> CodexDailyTokenDetail? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.startOfDay(for: date)
        let requestDate = now()

        if let cached = cache[day], isFresh(
            cached,
            day: day,
            requestDate: requestDate,
            calendar: calendar
        ) {
            return cached.detail
        }
        if let task = inFlight[day] {
            return try await task.value
        }

        let loadOperation = loadOperation
        let task = Task<CodexDailyTokenDetail?, any Error> {
            try await loadOperation(day)
        }
        inFlight[day] = task
        do {
            let detail = try await task.value
            inFlight[day] = nil
            cache[day] = CacheEntry(detail: detail, loadedAt: now())
            trimCacheIfNeeded()
            return detail
        } catch {
            inFlight[day] = nil
            throw error
        }
    }

    func clearCache() {
        cache.removeAll(keepingCapacity: true)
    }

    private func isFresh(
        _ entry: CacheEntry,
        day: Date,
        requestDate: Date,
        calendar: Calendar
    ) -> Bool {
        let today = calendar.startOfDay(for: requestDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            ?? today
        guard day >= yesterday else { return true }
        return requestDate.timeIntervalSince(entry.loadedAt)
            < recentCacheLifetime
    }

    private func trimCacheIfNeeded() {
        guard cache.count > maximumCacheEntries else { return }
        let overflow = cache.count - maximumCacheEntries
        for key in cache.sorted(by: { $0.value.loadedAt < $1.value.loadedAt })
            .prefix(overflow)
            .map(\.key) {
            cache[key] = nil
        }
    }
}
