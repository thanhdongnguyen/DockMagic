import Foundation

enum DeveloperToolInstallerError: LocalizedError, Equatable {
    case invalidInstallerResponse
    case installerScriptTooLarge
    case installerScriptInvalid
    case installerLaunchFailed(String)
    case installerTimedOut
    case installerFailed(tool: DeveloperTool, detail: String)
    case installedExecutableMissing(DeveloperTool)
    case executableValidationFailed(tool: DeveloperTool, detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidInstallerResponse:
            "The official installer could not be downloaded securely. Check your internet connection and try again."
        case .installerScriptTooLarge:
            "The downloaded installer was larger than expected, so DockMagic stopped before running it."
        case .installerScriptInvalid:
            "The downloaded installer was not a valid shell script, so DockMagic did not run it."
        case let .installerLaunchFailed(message):
            "The installer could not be started: \(message)"
        case .installerTimedOut:
            "The installer took too long and was stopped. Check your internet connection and try again."
        case let .installerFailed(tool, detail):
            "\(tool.title) could not be installed. \(detail)"
        case let .installedExecutableMissing(tool):
            "The \(tool.title) installer finished, but its executable was not found."
        case let .executableValidationFailed(tool, detail):
            "\(tool.title) was installed but could not be verified. \(detail)"
        }
    }
}

protocol ClaudeCodeExecutableLocating {
    func locate() throws -> URL
}

struct ClaudeCodeExecutableLocator: ClaudeCodeExecutableLocating {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let homeDirectory: URL
    private let standardExecutableDirectories: [URL]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        standardExecutableDirectories: [URL]? = nil
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.standardExecutableDirectories = standardExecutableDirectories ?? [
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
        ]
    }

    func locate() throws -> URL {
        for candidate in automaticCandidates() {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        throw DeveloperToolInstallerError.installedExecutableMissing(.claudeCode)
    }

    private func automaticCandidates() -> [URL] {
        var candidates: [URL] = []

        if let configuredPath = environment["CLAUDE_EXECUTABLE"],
           !configuredPath.isEmpty {
            candidates.append(URL(fileURLWithPath: configuredPath))
        }

        if let path = environment["PATH"] {
            candidates.append(contentsOf: pathDirectories(path).map {
                URL(fileURLWithPath: $0, isDirectory: true)
                    .appendingPathComponent("claude")
            })
        }

        candidates.append(
            homeDirectory.appendingPathComponent(".local/bin/claude")
        )
        candidates.append(contentsOf: standardExecutableDirectories.map {
            $0.appendingPathComponent("claude")
        })

        let nvmNodeVersions = homeDirectory
            .appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let versions = try? fileManager.contentsOfDirectory(
            at: nvmNodeVersions,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: versions
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
                .map { $0.appendingPathComponent("bin/claude") })
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }

    private func pathDirectories(_ path: String) -> [String] {
        path.split(separator: ":").map(String.init).filter { !$0.isEmpty }
    }
}

protocol InstallerScriptDownloading {
    func downloadScript(
        from url: URL,
        allowedHosts: Set<String>
    ) async throws -> Data
}

struct URLSessionInstallerScriptDownloader: InstallerScriptDownloading {
    private static let maximumScriptSize = 2 * 1_024 * 1_024

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func downloadScript(
        from url: URL,
        allowedHosts: Set<String>
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200 ..< 300).contains(httpResponse.statusCode),
            httpResponse.url?.scheme?.lowercased() == "https",
            (httpResponse.url?.host.map {
                allowedHosts.contains($0.lowercased())
            } ?? false)
        else {
            throw DeveloperToolInstallerError.invalidInstallerResponse
        }
        guard data.count <= Self.maximumScriptSize else {
            throw DeveloperToolInstallerError.installerScriptTooLarge
        }
        guard
            !data.isEmpty,
            String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .hasPrefix("#!") == true
        else {
            throw DeveloperToolInstallerError.installerScriptInvalid
        }
        return data
    }
}

struct InstallerProcessResult: Equatable, Sendable {
    let terminationStatus: Int32
    let output: String
}

protocol InstallerProcessRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> InstallerProcessResult
}

struct FoundationInstallerProcessRunner: InstallerProcessRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> InstallerProcessResult {
        let cancellation = InstallerProcessCancellation()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                guard !cancellation.isCancelled else {
                    throw CancellationError()
                }

                let process = Process()
                let outputPipe = try ProcessPipe()
                defer { outputPipe.close() }
                let timeoutState = InstallerProcessTimeoutState()

                process.executableURL = executableURL
                process.arguments = arguments
                process.environment = environment
                process.standardOutput = outputPipe.fileHandleForWriting
                process.standardError = outputPipe.fileHandleForWriting

                do {
                    try process.run()
                    outputPipe.closeWriteEnd()
                    cancellation.install(process)
                } catch {
                    throw DeveloperToolInstallerError.installerLaunchFailed(
                        error.localizedDescription
                    )
                }
                defer { cancellation.clear(process) }

                // Create the timer only after launch succeeds. Releasing a
                // suspended dispatch source on a failed launch can itself crash.
                let timeoutTimer = DispatchSource.makeTimerSource(
                    queue: DispatchQueue.global(qos: .utility)
                )
                timeoutTimer.schedule(deadline: .now() + timeout)
                timeoutTimer.setEventHandler {
                    timeoutState.markTimedOut()
                    if process.isRunning {
                        process.terminate()
                    }
                }

                timeoutTimer.resume()
                defer { timeoutTimer.cancel() }

                let outputData = outputPipe.fileHandleForReading
                    .readDataToEndOfFile()
                process.waitUntilExit()
                timeoutTimer.cancel()

                if timeoutState.didTimeOut {
                    throw DeveloperToolInstallerError.installerTimedOut
                }
                if cancellation.isCancelled {
                    throw CancellationError()
                }

                return InstallerProcessResult(
                    terminationStatus: process.terminationStatus,
                    output: Self.normalizedOutput(outputData)
                )
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func normalizedOutput(_ data: Data) -> String {
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.count > 2_000 else {
            return output
        }
        return String(output.suffix(2_000))
    }
}

private final class InstallerProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func install(_ process: Process) {
        lock.lock()
        let shouldTerminate = cancelled
        if !shouldTerminate {
            self.process = process
        }
        lock.unlock()

        if shouldTerminate, process.isRunning {
            process.terminate()
        }
    }

    func clear(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = process
        self.process = nil
        lock.unlock()

        if let process, process.isRunning {
            process.terminate()
        }
    }
}

private final class InstallerProcessTimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private var timedOut = false

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }
}

@MainActor
protocol DeveloperToolInstalling {
    func locate(
        _ tool: DeveloperTool,
        codexOverridePath: String?
    ) throws -> URL

    func install(_ tool: DeveloperTool) async throws -> URL
}

struct DeveloperToolInstaller: DeveloperToolInstalling {
    private struct InstallerDefinition {
        let url: URL
        let allowedHosts: Set<String>
        let shellURL: URL
        let arguments: [String]
    }

    private let codexLocator: any CodexExecutableLocating
    private let claudeCodeLocator: any ClaudeCodeExecutableLocating
    private let antigravityLocator: any AntigravityExecutableLocating
    private let downloader: any InstallerScriptDownloading
    private let processRunner: any InstallerProcessRunning
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let environment: [String: String]

    init(
        codexLocator: any CodexExecutableLocating = CodexExecutableLocator(),
        claudeCodeLocator: any ClaudeCodeExecutableLocating =
            ClaudeCodeExecutableLocator(),
        antigravityLocator: any AntigravityExecutableLocating =
            AntigravityExecutableLocator(),
        downloader: any InstallerScriptDownloading =
            URLSessionInstallerScriptDownloader(),
        processRunner: any InstallerProcessRunning =
            FoundationInstallerProcessRunner(),
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.codexLocator = codexLocator
        self.claudeCodeLocator = claudeCodeLocator
        self.antigravityLocator = antigravityLocator
        self.downloader = downloader
        self.processRunner = processRunner
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.environment = environment
    }

    func locate(
        _ tool: DeveloperTool,
        codexOverridePath: String?
    ) throws -> URL {
        switch tool {
        case .codex:
            do {
                return try codexLocator.locate(overridePath: codexOverridePath)
            } catch CodexRateLimitProviderError.executableNotRunnable
                where codexOverridePath != nil {
                return try codexLocator.locate(overridePath: nil)
            }
        case .claudeCode:
            return try claudeCodeLocator.locate()
        case .antigravity:
            return try antigravityLocator.locate()
        }
    }

    func install(_ tool: DeveloperTool) async throws -> URL {
        if let installed = try? locate(tool, codexOverridePath: nil) {
            return installed
        }

        let definition = installerDefinition(for: tool)
        let script = try await downloader.downloadScript(
            from: definition.url,
            allowedHosts: definition.allowedHosts
        )
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(
                "DockMagicInstaller-\(UUID().uuidString)",
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let scriptURL = temporaryDirectory.appendingPathComponent("install.sh")
        try script.write(to: scriptURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )

        var installEnvironment = environment
        installEnvironment["HOME"] = homeDirectory.path
        installEnvironment["PATH"] = installationPath
        if tool == .codex {
            installEnvironment["CODEX_NON_INTERACTIVE"] = "1"
            installEnvironment["CODEX_INSTALL_DIR"] = homeDirectory
                .appendingPathComponent(".local/bin", isDirectory: true).path
        }

        let result = try await processRunner.run(
            executableURL: definition.shellURL,
            arguments: [scriptURL.path] + definition.arguments,
            environment: installEnvironment,
            timeout: 5 * 60
        )
        guard result.terminationStatus == 0 else {
            throw DeveloperToolInstallerError.installerFailed(
                tool: tool,
                detail: failureDetail(from: result.output)
            )
        }

        guard let executableURL = try? locate(tool, codexOverridePath: nil) else {
            throw DeveloperToolInstallerError.installedExecutableMissing(tool)
        }
        let validation = try await processRunner.run(
            executableURL: executableURL,
            arguments: ["--version"],
            environment: installEnvironment,
            timeout: 20
        )
        guard validation.terminationStatus == 0 else {
            throw DeveloperToolInstallerError.executableValidationFailed(
                tool: tool,
                detail: failureDetail(from: validation.output)
            )
        }
        return executableURL
    }

    private var installationPath: String {
        let userLocalBin = homeDirectory
            .appendingPathComponent(".local/bin", isDirectory: true).path
        let existingPath = environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        return "\(userLocalBin):/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
    }

    private func installerDefinition(
        for tool: DeveloperTool
    ) -> InstallerDefinition {
        switch tool {
        case .codex:
            InstallerDefinition(
                url: URL(string: "https://chatgpt.com/codex/install.sh")!,
                allowedHosts: ["chatgpt.com", "releases.openai.com"],
                shellURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: []
            )
        case .claudeCode:
            InstallerDefinition(
                url: URL(string: "https://claude.ai/install.sh")!,
                allowedHosts: ["claude.ai", "downloads.claude.ai"],
                shellURL: URL(fileURLWithPath: "/bin/bash"),
                arguments: []
            )
        case .antigravity:
            InstallerDefinition(
                url: URL(string: "https://antigravity.google/cli/install.sh")!,
                allowedHosts: ["antigravity.google"],
                shellURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: []
            )
        }
    }

    private func failureDetail(from output: String) -> String {
        guard !output.isEmpty else {
            return "The installer exited without an error message."
        }
        return output
    }
}
