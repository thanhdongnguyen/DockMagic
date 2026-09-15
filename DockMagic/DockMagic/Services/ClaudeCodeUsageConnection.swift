import Darwin
import Foundation
import OSLog
import SwiftTerm

private let claudeUsageLogger = Logger(
    subsystem: "com.hypevibe.DockMagic",
    category: "ClaudeUsagePTY"
)

struct ClaudeCodeAuthInfo: Equatable, Sendable {
    let authMethod: String?
    let apiProvider: String?

    var displayName: String {
        if let authMethod, !authMethod.isEmpty {
            return authMethod
        }
        if let apiProvider, !apiProvider.isEmpty {
            return apiProvider
        }
        return "Claude account"
    }

    var isSubscriptionLogin: Bool {
        let method = authMethod?.lowercased() ?? ""
        let provider = apiProvider?.lowercased() ?? ""
        if method.contains("api") || method.contains("key") {
            return false
        }
        if provider.contains("bedrock") || provider.contains("vertex")
            || provider.contains("api") {
            return false
        }
        return true
    }
}

struct ClaudeCodeCLIStatus: Equatable, Sendable {
    let loggedIn: Bool
    let authInfo: ClaudeCodeAuthInfo
    let version: String
}

enum ClaudeCodeConnectionState: Equatable, Sendable {
    case cliMissing
    case cliOutdated(installed: String, required: String)
    case checking
    case signedOut
    case signingIn
    case signingOut
    case signedInWaitingForQuota(ClaudeCodeAuthInfo)
    case connected(ClaudeCodeAuthInfo, lastUpdated: Date)
    case quotaUnavailable(ClaudeCodeAuthInfo, reason: String)
    case stale(lastSnapshot: ClaudeCodeRateLimitSnapshot, message: String)
    case failed(message: String)
}

enum ClaudeCodeAuthStatusError: LocalizedError, Equatable {
    case malformedResponse
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            "Claude returned an unreadable authentication status."
        case let .commandFailed(message):
            message.isEmpty
                ? "Claude authentication status could not be checked."
                : message
        }
    }
}

protocol ClaudeCodeAuthStatusProviding: Sendable {
    func status(executableURL: URL) async throws -> ClaudeCodeCLIStatus
    func signOut(executableURL: URL) async throws
}

extension ClaudeCodeAuthStatusProviding {
    func signOut(executableURL: URL) async throws {
        throw ClaudeCodeAuthStatusError.commandFailed(
            "This Claude authentication provider cannot sign out."
        )
    }
}

struct ClaudeCodeAuthStatusProvider: ClaudeCodeAuthStatusProviding, @unchecked Sendable {
    static let minimumVersion = "2.1.181"

    private struct AuthPayload: Decodable {
        let loggedIn: Bool
        let authMethod: String?
        let apiProvider: String?
    }

    private let runner: any InstallerProcessRunning

    init(
        runner: any InstallerProcessRunning = FoundationInstallerProcessRunner()
    ) {
        self.runner = runner
    }

    func status(executableURL: URL) async throws -> ClaudeCodeCLIStatus {
        async let authResult = run(
            executableURL: executableURL,
            arguments: ["auth", "status", "--json"]
        )
        async let versionResult = run(
            executableURL: executableURL,
            arguments: ["--version"]
        )

        let (auth, version) = try await (authResult, versionResult)
        guard let data = auth.output.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AuthPayload.self, from: data)
        else {
            throw ClaudeCodeAuthStatusError.malformedResponse
        }

        // `auth status` intentionally exits 1 for signed-out users. The JSON is
        // the source of truth in both the 0 and 1 cases.
        guard auth.terminationStatus == 0 || auth.terminationStatus == 1 else {
            throw ClaudeCodeAuthStatusError.commandFailed(auth.output)
        }

        return ClaudeCodeCLIStatus(
            loggedIn: payload.loggedIn,
            authInfo: ClaudeCodeAuthInfo(
                authMethod: payload.authMethod,
                apiProvider: payload.apiProvider
            ),
            version: Self.semanticVersion(in: version.output) ?? version.output
        )
    }

    func signOut(executableURL: URL) async throws {
        let result = try await run(
            executableURL: executableURL,
            arguments: ["auth", "logout"]
        )
        guard result.terminationStatus == 0 else {
            throw ClaudeCodeAuthStatusError.commandFailed(result.output)
        }
    }

    static func isSupported(version: String) -> Bool {
        compareVersions(version, minimumVersion) != .orderedAscending
    }

    static func semanticVersion(in output: String) -> String? {
        let pattern = #"\b(\d+\.\d+\.\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: output,
                  range: NSRange(output.startIndex..., in: output)
              ),
              let range = Range(match.range(at: 1), in: output)
        else {
            return nil
        }
        return String(output[range])
    }

    private static func compareVersions(
        _ lhs: String,
        _ rhs: String
    ) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private func run(
        executableURL: URL,
        arguments: [String]
    ) async throws -> InstallerProcessResult {
        do {
            return try await runner.run(
                executableURL: executableURL,
                arguments: arguments,
                environment: ProcessInfo.processInfo.environment,
                timeout: 15
            )
        } catch {
            throw ClaudeCodeAuthStatusError.commandFailed(
                error.localizedDescription
            )
        }
    }
}

struct ClaudeCodeQuotaCapture: Equatable, Sendable {
    let fiveHour: ClaudeCodeRateLimitWindow
    let weekly: ClaudeCodeRateLimitWindow
    let capturedAt: Date
    let cliVersion: String
}

enum ClaudeCodeUsageCaptureError: LocalizedError, Equatable {
    case executableNotConfigured
    case processExited
    case timedOut
    case signedOut
    case outputFormatChanged

    var errorDescription: String? {
        switch self {
        case .executableNotConfigured:
            "Claude CLI is not installed."
        case .processExited:
            "The Claude usage process exited unexpectedly."
        case .timedOut:
            "Claude did not return usage within 15 seconds."
        case .signedOut:
            "Sign in to Claude before loading quota."
        case .outputFormatChanged:
            "Claude output format changed. Update DockMagic or retry after updating Claude Code."
        }
    }
}

enum ClaudeCodeUsageOutputParser {
    static func parse(
        _ output: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> (fiveHour: ClaudeCodeRateLimitWindow, weekly: ClaudeCodeRateLimitWindow) {
        let text = normalized(output)
        if text.localizedCaseInsensitiveContains("not logged in")
            || text.localizedCaseInsensitiveContains("please log in") {
            throw ClaudeCodeUsageCaptureError.signedOut
        }

        guard let session = section(
            named: "Current session",
            in: text,
            now: now,
            calendar: calendar
        ), let cachedWeekly = section(
            named: "Current week (all models)",
            in: text,
            now: now,
            calendar: calendar
        ) else {
            throw ClaudeCodeUsageCaptureError.outputFormatChanged
        }

        // The screen-reader stream does not always repeat the weekly header
        // after its network refresh. Claude can repaint only the changed
        // percentage/reset rows after the first "Esc to cancel" marker. Use
        // that final redraw when present; otherwise retain the named section.
        let weekly = refreshedWeeklySection(
            in: text,
            fallback: cachedWeekly,
            now: now,
            calendar: calendar
        )

        return (
            ClaudeCodeRateLimitWindow(
                kind: .fiveHour,
                usedPercent: min(max(session.percent, 0), 100),
                windowDurationMinutes: 300,
                resetsAt: session.resetsAt
            ),
            ClaudeCodeRateLimitWindow(
                kind: .weekly,
                usedPercent: min(max(weekly.percent, 0), 100),
                windowDurationMinutes: 10_080,
                resetsAt: weekly.resetsAt
            )
        )
    }

    static func normalized(_ output: String) -> String {
        var text = output.replacingOccurrences(of: "\r", with: "\n")
        let patterns = [
            #"\u001B\][^\u0007]*(?:\u0007|\u001B\\)"#,
            #"\u001B\[[0-?]*[ -/]*[@-~]"#,
            #"\u001B[@-_]"#
        ]
        for pattern in patterns {
            text = text.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        return text
    }

    private static func section(
        named name: String,
        in text: String,
        now: Date,
        calendar: Calendar
    ) -> (percent: Int, resetsAt: Date?)? {
        guard let headerRange = text.range(of: name, options: .backwards) else {
            return nil
        }
        let tail = String(text[headerRange.upperBound...])
        let endCandidates = [
            tail.range(of: "\nCurrent "),
            tail.range(of: "\nEsc to cancel"),
            tail.range(of: "\nPress Esc")
        ].compactMap { $0?.lowerBound }
        let end = endCandidates.min() ?? tail.endIndex
        let body = String(tail[..<end])

        guard let percent = firstInteger(
            pattern: #"(?i)\b(\d{1,3})\s*%\s*used\b"#,
            in: body
        ) else {
            return nil
        }

        let resetText = firstCapture(
            pattern: #"(?im)^\s*Resets?\s+(.+?)\s*$"#,
            in: body
        )
        return (
            percent,
            resetText.flatMap {
                resetDate(from: $0, now: now, calendar: calendar)
            }
        )
    }

    private static func refreshedWeeklySection(
        in text: String,
        fallback: (percent: Int, resetsAt: Date?),
        now: Date,
        calendar: Calendar
    ) -> (percent: Int, resetsAt: Date?) {
        guard text.localizedCaseInsensitiveContains("Refreshing") else {
            return fallback
        }

        let markerNames = ["Esc to cancel", "Press Esc"]
        let firstMarker = markerNames.compactMap {
            text.range(of: $0, options: .caseInsensitive)
        }.min { $0.lowerBound < $1.lowerBound }
        guard let firstMarker else { return fallback }

        var redraw = String(text[firstMarker.upperBound...])
        guard markerNames.contains(where: {
            redraw.range(of: $0, options: .caseInsensitive) != nil
        }) else {
            return fallback
        }

        // Usage credits are a separate percentage section. The last quota
        // percentage before that heading is the all-model weekly row in the
        // `/usage` layout, including layouts with model-specific rows above it.
        if let credits = redraw.range(
            of: "Usage credits",
            options: .caseInsensitive
        ) {
            redraw = String(redraw[..<credits.lowerBound])
        } else if let finalMarker = markerNames.compactMap({
            redraw.range(of: $0, options: .caseInsensitive)
        }).min(by: { $0.lowerBound < $1.lowerBound }) {
            redraw = String(redraw[..<finalMarker.lowerBound])
        }

        guard let percent = allIntegers(
            pattern: #"(?i)\b(\d{1,3})\s*%\s*used\b"#,
            in: redraw
        ).last else {
            return fallback
        }
        let resetText = allCaptures(
            pattern: #"(?im)^\s*Resets?\s+(.+?)\s*$"#,
            in: redraw
        ).last
        return (
            percent,
            resetText.flatMap {
                resetDate(from: $0, now: now, calendar: calendar)
            } ?? fallback.resetsAt
        )
    }

    private static func resetDate(
        from input: String,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let value = input
            .replacingOccurrences(
                of: #"\s*\([^)]*\)\s*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if value.lowercased().hasPrefix("in ") {
            var seconds: TimeInterval = 0
            let units: [(String, TimeInterval)] = [
                (#"(?i)(\d+)\s*d(?:ay)?s?"#, 86_400),
                (#"(?i)(\d+)\s*h(?:r|our)?s?"#, 3_600),
                (#"(?i)(\d+)\s*m(?:in|inute)?s?"#, 60)
            ]
            for (pattern, multiplier) in units {
                if let amount = firstInteger(pattern: pattern, in: value) {
                    seconds += Double(amount) * multiplier
                }
            }
            return seconds > 0 ? now.addingTimeInterval(seconds) : nil
        }

        let locale = Locale(identifier: "en_US_POSIX")
        let timezone = calendar.timeZone
        let formats = [
            "MMM d, yyyy 'at' h:mma", "MMMM d, yyyy 'at' h:mma",
            "MMM d, yyyy 'at' h:mm a", "MMMM d, yyyy 'at' h:mm a",
            "MMM d 'at' h:mma", "MMMM d 'at' h:mma",
            "MMM d 'at' h:mm a", "MMMM d 'at' h:mm a",
            "MMM d, h:mm a", "MMMM d, h:mm a",
            "MMM d 'at' ha", "MMMM d 'at' ha"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timezone
            formatter.dateFormat = format
            if var date = formatter.date(from: value) {
                if !format.contains("yyyy") {
                    var components = calendar.dateComponents(
                        [.month, .day, .hour, .minute],
                        from: date
                    )
                    components.year = calendar.component(.year, from: now)
                    date = calendar.date(from: components) ?? date
                    if date < now.addingTimeInterval(-86_400) {
                        date = calendar.date(byAdding: .year, value: 1, to: date)
                            ?? date
                    }
                }
                return date
            }
        }

        for format in ["h:mma", "h:mm a", "ha"] {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timezone
            formatter.dateFormat = format
            if let time = formatter.date(from: value) {
                let parts = calendar.dateComponents([.hour, .minute], from: time)
                var date = calendar.date(
                    bySettingHour: parts.hour ?? 0,
                    minute: parts.minute ?? 0,
                    second: 0,
                    of: now
                )
                if let candidate = date, candidate <= now {
                    date = calendar.date(byAdding: .day, value: 1, to: candidate)
                }
                return date
            }
        }
        return nil
    }

    private static func firstInteger(pattern: String, in text: String) -> Int? {
        firstCapture(pattern: pattern, in: text).flatMap(Int.init)
    }

    private static func allIntegers(pattern: String, in text: String) -> [Int] {
        allCaptures(pattern: pattern, in: text).compactMap(Int.init)
    }

    private static func allCaptures(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        return regex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text)
            else {
                return nil
            }
            return String(text[range])
        }
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: text,
                  range: NSRange(text.startIndex..., in: text)
              ), match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }
}

@MainActor
protocol ClaudeCodeUsageCollecting: AnyObject {
    func configure(executableURL: URL, cliVersion: String)
    func capture() async throws -> ClaudeCodeQuotaCapture
    func stop()
}

@MainActor
protocol ClaudeCodeUsageTerminalSession: AnyObject {
    var isRunning: Bool { get }
    var bufferText: String { get }

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String],
        currentDirectory: URL
    )
    func send(_ text: String)
    func send(bytes: [UInt8])
    func clearScrollback()
    func terminate()
}

@MainActor
protocol ClaudeCodeUsageTerminalSessionBuilding {
    func makeSession(
        onExit: @escaping (Int32?) -> Void
    ) -> any ClaudeCodeUsageTerminalSession
}

@MainActor
private struct SwiftTermClaudeCodeUsageSessionBuilder:
    ClaudeCodeUsageTerminalSessionBuilding
{
    func makeSession(
        onExit: @escaping (Int32?) -> Void
    ) -> any ClaudeCodeUsageTerminalSession {
        SwiftTermClaudeCodeUsageSession(onExit: onExit)
    }
}

@MainActor
private final class SwiftTermClaudeCodeUsageSession:
    ClaudeCodeUsageTerminalSession,
    @preconcurrency LocalProcessDelegate
{
    private static let maximumBufferBytes = 256 * 1_024

    private let onExit: (Int32?) -> Void
    private var rawBuffer = Data()
    private lazy var process = LocalProcess(
        delegate: self,
        dispatchQueue: .main
    )

    init(onExit: @escaping (Int32?) -> Void) {
        self.onExit = onExit
    }

    var isRunning: Bool { process.running }

    var bufferText: String {
        String(decoding: rawBuffer, as: UTF8.self)
    }

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String],
        currentDirectory: URL
    ) {
        process.startProcess(
            executable: executableURL.path,
            args: arguments,
            environment: environment,
            execName: "claude",
            currentDirectory: currentDirectory.path
        )
    }

    func send(_ text: String) {
        process.send(data: [UInt8](text.utf8)[...])
    }

    func send(bytes: [UInt8]) {
        process.send(data: bytes[...])
    }

    func clearScrollback() {
        rawBuffer.removeAll(keepingCapacity: true)
    }

    func terminate() {
        process.terminate()
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        onExit(exitCode)
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        rawBuffer.append(contentsOf: slice)
        let overflow = rawBuffer.count - Self.maximumBufferBytes
        if overflow > 0 {
            rawBuffer.removeFirst(overflow)
        }
    }

    func getWindowSize() -> winsize {
        winsize(
            ws_row: 50,
            ws_col: 132,
            ws_xpixel: 16,
            ws_ypixel: 16
        )
    }
}

@MainActor
final class ClaudeCodeUsageTerminalCollector: ClaudeCodeUsageCollecting {
    private var executableURL: URL?
    private var cliVersion = ""
    private var terminal: (any ClaudeCodeUsageTerminalSession)?
    private var captureTask: Task<ClaudeCodeQuotaCapture, Error>?
    private var processGeneration = UUID()
    private let now: () -> Date
    private let sessionBuilder: any ClaudeCodeUsageTerminalSessionBuilding
    private let readyTimeout: Duration
    private let captureTimeout: Duration
    private let pollInterval: Duration
    private let settleDelay: Duration
    private let stopGracePeriod: Duration

    init(
        now: @escaping () -> Date = Date.init,
        sessionBuilder: (any ClaudeCodeUsageTerminalSessionBuilding)? = nil,
        readyTimeout: Duration = .seconds(5),
        captureTimeout: Duration = .seconds(15),
        pollInterval: Duration = .milliseconds(125),
        settleDelay: Duration = .milliseconds(100),
        stopGracePeriod: Duration = .milliseconds(350)
    ) {
        self.now = now
        self.sessionBuilder = sessionBuilder
            ?? SwiftTermClaudeCodeUsageSessionBuilder()
        self.readyTimeout = readyTimeout
        self.captureTimeout = captureTimeout
        self.pollInterval = pollInterval
        self.settleDelay = settleDelay
        self.stopGracePeriod = stopGracePeriod
    }

    func configure(executableURL: URL, cliVersion: String) {
        guard self.executableURL != executableURL || self.cliVersion != cliVersion else {
            return
        }
        stop()
        self.executableURL = executableURL
        self.cliVersion = cliVersion
    }

    func capture() async throws -> ClaudeCodeQuotaCapture {
        if let captureTask {
            return try await captureTask.value
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.capture(restartRemaining: 1)
        }
        captureTask = task
        defer { captureTask = nil }
        return try await task.value
    }

    func stop() {
        captureTask?.cancel()
        captureTask = nil
        guard let terminal else { return }
        terminal.send(bytes: [0x03])
        Task { @MainActor in
            try? await Task.sleep(for: stopGracePeriod)
            if terminal.isRunning {
                terminal.terminate()
            }
        }
        self.terminal = nil
        processGeneration = UUID()
    }

    private func capture(restartRemaining: Int) async throws -> ClaudeCodeQuotaCapture {
        do {
            let terminal = try ensureTerminal()
            try await waitUntilReady(terminal)
            // A successful capture already dismisses `/usage` with Esc. Do
            // not send another Esc here: Claude's prompt uses an INSERT/NORMAL
            // editor, and an extra Esc would make `/usage` keystrokes get
            // interpreted as editor commands instead of submitted text.
            terminal.clearScrollback()
            terminal.send("/usage\r")
            let deadline = ContinuousClock.now + captureTimeout

            while ContinuousClock.now < deadline {
                try Task.checkCancellation()
                let text = terminal.bufferText
                let hasNewCommand = text.localizedCaseInsensitiveContains(
                    "Current session"
                )
                let complete = Self.isCompleteUsageResponse(text)
                if hasNewCommand && complete {
                    // `/usage` first paints cached values and then refreshes
                    // them in-place. The screen-reader stream can therefore
                    // contain more than one weekly section. Give the final
                    // cursor update a short quiet window; the parser selects
                    // the last matching all-models section.
                    try await Task.sleep(for: settleDelay)
                    let settledText = terminal.bufferText
                    do {
                        let parsed = try ClaudeCodeUsageOutputParser.parse(
                            settledText,
                            now: now()
                        )
                        terminal.send(bytes: [0x1b])
                        return ClaudeCodeQuotaCapture(
                            fiveHour: parsed.fiveHour,
                            weekly: parsed.weekly,
                            capturedAt: now(),
                            cliVersion: cliVersion
                        )
                    } catch ClaudeCodeUsageCaptureError.signedOut {
                        terminal.send(bytes: [0x1b])
                        throw ClaudeCodeUsageCaptureError.signedOut
                    } catch {
                        terminal.send(bytes: [0x1b])
                        throw ClaudeCodeUsageCaptureError.outputFormatChanged
                    }
                }
                try await Task.sleep(for: pollInterval)
            }
            let timeoutText = terminal.bufferText
            let hasSession = timeoutText.localizedCaseInsensitiveContains(
                "Current session"
            )
            let hasWeekly = timeoutText.localizedCaseInsensitiveContains(
                "Current week (all models)"
            )
            let hasCompletion = timeoutText.localizedCaseInsensitiveContains(
                "Esc to cancel"
            ) || timeoutText.localizedCaseInsensitiveContains("Press Esc")
            claudeUsageLogger.error(
                "Usage response timed out: bytes=\(timeoutText.utf8.count, privacy: .public) session=\(hasSession, privacy: .public) weekly=\(hasWeekly, privacy: .public) complete=\(hasCompletion, privacy: .public)"
            )
            throw ClaudeCodeUsageCaptureError.timedOut
        } catch {
            guard restartRemaining > 0,
                  !(error is CancellationError),
                  error as? ClaudeCodeUsageCaptureError != .signedOut,
                  error as? ClaudeCodeUsageCaptureError != .outputFormatChanged
            else {
                throw error
            }
            stopProcessOnly()
            return try await capture(restartRemaining: restartRemaining - 1)
        }
    }

    private func ensureTerminal() throws -> any ClaudeCodeUsageTerminalSession {
        if let terminal, terminal.isRunning {
            return terminal
        }
        guard let executableURL else {
            throw ClaudeCodeUsageCaptureError.executableNotConfigured
        }

        let generation = UUID()
        processGeneration = generation
        let terminal = sessionBuilder.makeSession { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.processGeneration == generation else { return }
                self?.terminal = nil
            }
        }
        let environment = Self.workerEnvironment()
        terminal.start(
            executableURL: executableURL,
            arguments: ["--safe-mode", "--ax-screen-reader", "--no-chrome"],
            environment: environment,
            currentDirectory: Self.neutralWorkingDirectory()
        )
        self.terminal = terminal
        return terminal
    }

    private func waitUntilReady(
        _ terminal: any ClaudeCodeUsageTerminalSession
    ) async throws {
        let deadline = ContinuousClock.now + readyTimeout
        var acceptedOwnedDirectoryTrust = false
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard terminal.isRunning else {
                throw ClaudeCodeUsageCaptureError.processExited
            }
            let text = terminal.bufferText
            if Self.isOwnedDirectoryTrustPrompt(text) {
                guard !acceptedOwnedDirectoryTrust else {
                    try await Task.sleep(for: pollInterval)
                    continue
                }
                acceptedOwnedDirectoryTrust = true
                terminal.clearScrollback()
                terminal.send("y\r")
                try await Task.sleep(for: settleDelay)
                continue
            }
            if Self.isReadyPrompt(text) {
                return
            }
            try await Task.sleep(for: pollInterval)
        }
        guard terminal.isRunning else {
            throw ClaudeCodeUsageCaptureError.processExited
        }
        let timeoutText = terminal.bufferText
        let hasVersion = timeoutText.localizedCaseInsensitiveContains(
            "Claude Code v"
        )
        let hasInsert = timeoutText.localizedCaseInsensitiveContains(
            "-- INSERT --"
        )
        claudeUsageLogger.error(
            "Claude prompt timed out: bytes=\(timeoutText.utf8.count, privacy: .public) trust=\(Self.isOwnedDirectoryTrustPrompt(timeoutText), privacy: .public) version=\(hasVersion, privacy: .public) insert=\(hasInsert, privacy: .public)"
        )
        throw ClaudeCodeUsageCaptureError.timedOut
    }

    private static func isOwnedDirectoryTrustPrompt(_ output: String) -> Bool {
        let text = ClaudeCodeUsageOutputParser.normalized(output)
        return text.localizedCaseInsensitiveContains(
            "Permission Required: Accessing workspace:"
        )
            && text.localizedCaseInsensitiveContains("Yes, I trust this folder")
            && text.localizedCaseInsensitiveContains("DockMagic-ClaudeCode")
    }

    private static func isCompleteUsageResponse(_ output: String) -> Bool {
        let text = ClaudeCodeUsageOutputParser.normalized(output).lowercased()
        guard text.contains("current session"),
              text.contains("current week (all models)")
        else {
            return false
        }

        let completionCount = occurrenceCount(of: "esc to cancel", in: text)
            + occurrenceCount(of: "press esc", in: text)
        guard completionCount > 0 else { return false }

        // Claude first paints cached quota followed by "Refreshing…" and a
        // temporary completion hint. In the raw screen-reader stream, the
        // refreshed redraw appends a second hint. Waiting for it prevents a
        // stale cached percentage from being published as the new snapshot.
        if text.contains("refreshing") {
            return completionCount >= 2
        }
        return true
    }

    private static func occurrenceCount(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return text.components(separatedBy: needle).count - 1
    }

    private static func isReadyPrompt(_ output: String) -> Bool {
        let text = ClaudeCodeUsageOutputParser.normalized(output)
        guard !text.localizedCaseInsensitiveContains(
            "Permission Required: Accessing workspace:"
        ) else {
            return false
        }
        return text.localizedCaseInsensitiveContains("What can I help")
            || text.localizedCaseInsensitiveContains("-- INSERT --")
            || text.localizedCaseInsensitiveContains("Claude Code v")
            || text.localizedCaseInsensitiveContains("Try \"")
    }

    private func stopProcessOnly() {
        terminal?.send(bytes: [0x03])
        terminal?.terminate()
        terminal = nil
        processGeneration = UUID()
    }

    private static func workerEnvironment() -> [String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CLAUDE_CODE_SKIP_PROMPT_HISTORY"] = "1"
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        return environment.map { "\($0.key)=\($0.value)" }
    }

    private static func neutralWorkingDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DockMagic-ClaudeCode",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
        return url
    }
}
