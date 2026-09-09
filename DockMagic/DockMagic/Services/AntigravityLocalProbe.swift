import Foundation
import Security

protocol AntigravityQuotaProviding: Sendable {
    func fetchQuota() async throws -> AntigravityQuotaSnapshot
    func captureHistory() async throws
}

extension AntigravityQuotaProviding {
    func captureHistory() async throws {}
}

/// Compatibility adapter for the installed app/IDE/CLI's local language server.
/// No Google credentials, remote endpoints, model requests, or terminal scraping.
actor AntigravityLocalProbe: AntigravityQuotaProviding {
    private var connection: (baseURL: URL, csrf: String?)?
    let historyDirectory: URL

    init(historyDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".gemini/dockmagic-antigravity/rpc")) {
        self.historyDirectory = historyDirectory
    }
    struct Server: Equatable, Sendable {
        let pid: String
        let csrf: String?
    }

    static func servers(from processList: String, userID: UInt32) -> [Server] {
        processList.split(separator: "\n").compactMap { line in
            let parts = line.split(maxSplits: 2, whereSeparator: \.isWhitespace)
            guard parts.count == 3, UInt32(parts[1]) == userID,
                  Int32(parts[0]) != nil else { return nil }
            let command = String(parts[2])
            let lower = command.lowercased()
            let executable = lower.split(whereSeparator: \.isWhitespace).first ?? ""
            let isCLI = executable.hasSuffix("/agy") || executable.contains("/antigravity-cli/")
            let isServer = (lower.contains("language_server") || lower.contains("language-server"))
                && lower.contains("antigravity")
            guard isServer || isCLI else { return nil }
            let pattern = #"--csrf_token(?:=|\s+)([^\s]+)"#
            let expression = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(command.startIndex..., in: command)
            let match = expression?.firstMatch(in: command, range: range)
            let csrf = match.flatMap { Range($0.range(at: 1), in: command) }.map { String(command[$0]) }
            guard isCLI || csrf != nil else { return nil }
            return Server(pid: String(parts[0]), csrf: csrf)
        }
    }

    static func ports(from output: String) -> [Int] {
        let pattern = #":([0-9]+)(?:\s|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = expression.matches(in: output, range: NSRange(output.startIndex..., in: output))
        return Set(matches.compactMap { match -> Int? in
            guard let range = Range(match.range(at: 1), in: output),
                  let port = Int(output[range]), (1...65535).contains(port) else { return nil }
            return port
        }).sorted()
    }

    func fetchQuota() async throws -> AntigravityQuotaSnapshot {
        let processList = try await AntigravityProcess.read("/bin/ps", ["-axo", "pid=,uid=,command="])
        let candidates = Self.servers(from: processList, userID: getuid())
        guard !candidates.isEmpty else { throw AntigravityDataError.notRunning }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 2
        config.connectionProxyDictionary = [:]
        config.httpCookieStorage = nil
        let session = URLSession(configuration: config, delegate: AntigravityLoopbackDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let deadline = Date().addingTimeInterval(12)
        var legacy: AntigravityQuotaSnapshot?
        for server in candidates.prefix(8) {
            try Task.checkCancellation()
            let output = try await AntigravityProcess.read(
                "/usr/sbin/lsof", ["-nP", "-a", "-p", server.pid, "-iTCP", "-sTCP:LISTEN", "-Fn"]
            )
            for port in Self.ports(from: output).prefix(6) {
                for scheme in ["https", "http"] {
                    for method in ["RetrieveUserQuotaSummary", "GetUserStatus", "GetCommandModelConfigs"] {
                        try Task.checkCancellation()
                        if Date() > deadline {
                            if let legacy { return legacy }
                            throw AntigravityDataError.unavailable
                        }
                        let url = URL(string: "\(scheme)://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/\(method)")!
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.httpBody = Data("{}".utf8)
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                        if let csrf = server.csrf {
                            request.setValue(csrf, forHTTPHeaderField: "X-Codeium-Csrf-Token")
                        }
                        do {
                            let (data, response) = try await session.data(for: request)
                            guard (response as? HTTPURLResponse)?.statusCode == 200,
                                  data.count <= 2_000_000,
                                  let quota = try AntigravityQuotaParser.parse(data, source: "Local Antigravity", now: .now)
                            else { continue }
                            connection = (url.deletingLastPathComponent(), server.csrf)
                            if quota.groups.contains(where: { $0.buckets.contains { $0.kind != nil } }) {
                                return quota
                            }
                            legacy = legacy ?? quota
                            break
                        } catch is CancellationError { throw CancellationError() }
                        catch { continue }
                    }
                    if legacy != nil { break }
                }
                if legacy != nil { break }
            }
        }
        if let legacy { return legacy }
        throw AntigravityDataError.unavailable
    }

    func captureHistory() async throws {
        guard let connection else { return }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 4
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config, delegate: AntigravityLoopbackDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        func read(_ method: String, _ body: [String: Any]) async throws -> [String: Any] {
            var request = URLRequest(url: connection.baseURL.appendingPathComponent(method))
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.setValue(connection.csrf, forHTTPHeaderField: "X-Codeium-Csrf-Token")
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 16_000_000,
                  let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AntigravityDataError.unavailable
            }
            return result["response"] as? [String: Any] ?? result
        }
        let response = try await read("GetAllCascadeTrajectories", [:])
        guard let summaries = response["trajectorySummaries"] as? [String: [String: Any]] else { return }
        let now = Date()
        let cutoff = now.addingTimeInterval(-32 * 86400)
        var tasks: [[String: Any]] = []
        var knownCount = 0
        var retainedFiles = Set<String>()
        let deadline = now.addingTimeInterval(10)
        let rows = summaries.sorted {
            (AntigravityJSON.date($0.value["lastModifiedTime"]) ?? .distantPast)
                > (AntigravityJSON.date($1.value["lastModifiedTime"]) ?? .distantPast)
        }
        for (id, summary) in rows.prefix(500) {
            try Task.checkCancellation()
            guard id.count <= 160, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { continue }
            let status = summary["status"] as? String ?? ""
            if status.contains("RUNNING") || status.contains("IDLE") || status.contains("COMPLETED") {
                tasks.append(["session_id": id, "event": "status", "agent_state": status.contains("RUNNING") ? "working" : "idle", "observed_at": now.timeIntervalSince1970])
            }
            guard let modified = AntigravityJSON.date(summary["lastModifiedTime"]), modified >= cutoff else { continue }
            let file = historyDirectory.appendingPathComponent(id + ".json")
            retainedFiles.insert(file.lastPathComponent)
            let cached = (try? Data(contentsOf: file)).flatMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }
            if let cached,
               AntigravityHistoryParser.canReuseCache(cached, modifiedAt: modified) {
                if cached["has_usage_history"] as? Bool == true { knownCount += 1 }
                continue
            }
            if Date() > deadline { continue }
            do {
                let metadata = try await read("GetCascadeTrajectoryGeneratorMetadata", ["cascadeId": id, "includeMessages": false])
                guard let generators = metadata["generatorMetadata"] as? [[String: Any]] else { continue }
                let records = AntigravityHistoryParser.records(metadata, sessionID: id, summary: summary,
                    previousRecords: cached?["records"] as? [[String: Any]] ?? [])
                let hasHistory = !records.isEmpty || generators.isEmpty
                try saveHistory(["schema_version": AntigravityHistoryParser.cacheVersion,
                                 "session_id": id, "modified_at": modified.timeIntervalSince1970,
                                 "has_usage_history": hasHistory, "records": records], to: file)
                if hasHistory { knownCount += 1 }
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
        }
        let knownEmptyWindow = summaries.values.allSatisfy { summary in
            guard let date = AntigravityJSON.date(summary["lastModifiedTime"]) else { return false }
            return date < cutoff
        }
        try saveHistory(["observed_at": now.timeIntervalSince1970, "known_sessions": summaries.count,
                         "has_usage_history": knownEmptyWindow || knownCount > 0, "tasks": tasks],
                        to: historyDirectory.appendingPathComponent("index.json"))
        // Only retain recent session metadata; never accumulate an unbounded
        // copy of the user's conversation history.
        for file in (try? FileManager.default.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil)) ?? [] {
            if file.pathExtension == "json", file.lastPathComponent != "index.json", !retainedFiles.contains(file.lastPathComponent) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func saveHistory(_ value: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try JSONSerialization.data(withJSONObject: value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

private final class AntigravityLoopbackDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Antigravity uses a self-signed cert. The exception cannot apply to a
        // hostname, public address, or redirect outside this loopback endpoint.
        guard challenge.protectionSpace.host == "127.0.0.1",
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum AntigravityProcess {
    static func read(_ executable: String, _ arguments: [String]) async throws -> String {
        let operation = AntigravityProcessOperation(executable: executable, arguments: arguments)
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) { try operation.run() }.value
        } onCancel: { operation.cancel() }
    }
}

private final class AntigravityProcessOperation: @unchecked Sendable {
    private let process = Process()
    private let lock = NSLock()
    private var cancelled = false

    init(executable: String, arguments: [String]) {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
        if process.isRunning { process.terminate() }
    }

    func run() throws -> String {
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        do { try process.run() } catch { lock.unlock(); throw error }
        lock.unlock()
        let timeout = DispatchWorkItem { [weak self] in self?.cancel() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3, execute: timeout)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        lock.lock()
        let wasCancelled = cancelled
        lock.unlock()
        if wasCancelled { throw CancellationError() }
        return String(decoding: data.prefix(4_000_000), as: UTF8.self)
    }
}
