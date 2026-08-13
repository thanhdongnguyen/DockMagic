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

        do {
            let payload = try requestPayload()
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
            if CodexRateLimitParser.containsRateLimitResponse(output) {
                break
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

        if timeoutState.didTimeOut {
            throw CodexRateLimitProviderError.timedOut
        }

        return try CodexRateLimitParser.parseJSONLines(output)
    }

    private static func requestPayload() throws -> Data {
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
}

enum CodexRateLimitParser {
    static func containsRateLimitResponse(_ data: Data) -> Bool {
        data.split(separator: 0x0A).contains { line in
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let dictionary = object as? [String: Any]
            else {
                return false
            }
            return (dictionary["id"] as? NSNumber)?.intValue == 2
        }
    }

    static func parseJSONLines(
        _ data: Data,
        fetchedAt: Date = .now
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
                fetchedAt: fetchedAt
            )
        }

        throw CodexRateLimitProviderError.invalidResponse
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
