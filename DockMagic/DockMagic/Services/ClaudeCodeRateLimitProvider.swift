import Foundation

enum ClaudeCodeRateLimitProviderError: LocalizedError, Equatable {
    case bridgeNotInstalled
    case snapshotMissing
    case invalidSnapshot
    case supportedWindowsMissing

    var errorDescription: String? {
        switch self {
        case .bridgeNotInstalled:
            "Activate Claude Code in General so DockMagic can configure its status line bridge automatically."
        case .snapshotMissing:
            "Complete one Claude Code response after automatic setup finishes."
        case .invalidSnapshot:
            "Claude Code wrote an unreadable usage snapshot."
        case .supportedWindowsMissing:
            "Claude Code did not report a 5-hour or weekly usage window."
        }
    }
}

protocol ClaudeCodeRateLimitProviding: Sendable {
    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot
}

struct ClaudeCodeStatusLineRateLimitProvider: ClaudeCodeRateLimitProviding {
    let snapshotURL: URL
    let sessionSnapshotsDirectoryURL: URL
    let taskSnapshotURL: URL
    let taskSnapshotsDirectoryURL: URL
    let activityEventsDirectoryURL: URL
    let projectsDirectoryURL: URL
    let now: @Sendable () -> Date

    init(
        snapshotURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-usage.json"),
        sessionSnapshotsDirectoryURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-status-sessions"),
        taskSnapshotURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-subagents.json"),
        taskSnapshotsDirectoryURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-task-sessions"),
        activityEventsDirectoryURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-activity-events"),
        projectsDirectoryURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects"),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.snapshotURL = snapshotURL
        self.sessionSnapshotsDirectoryURL = sessionSnapshotsDirectoryURL
        self.taskSnapshotURL = taskSnapshotURL
        self.taskSnapshotsDirectoryURL = taskSnapshotsDirectoryURL
        self.activityEventsDirectoryURL = activityEventsDirectoryURL
        self.projectsDirectoryURL = projectsDirectoryURL
        self.now = now
    }

    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot {
        let reader = ClaudeCodeLocalTelemetryReader(
            snapshotURL: snapshotURL,
            sessionSnapshotsDirectoryURL: sessionSnapshotsDirectoryURL,
            taskSnapshotURL: taskSnapshotURL,
            taskSnapshotsDirectoryURL: taskSnapshotsDirectoryURL,
            activityEventsDirectoryURL: activityEventsDirectoryURL,
            projectsDirectoryURL: projectsDirectoryURL,
            now: now()
        )
        return try await Task.detached(priority: .utility) {
            let result = reader.read()
            guard result.hasUsefulData else {
                throw ClaudeCodeRateLimitProviderError.snapshotMissing
            }
            let telemetry = ClaudeCodeTelemetrySnapshot(
                source: result.source,
                currentSession: result.currentSession,
                observedSessionCount: result.observedSessionCount,
                dailyCosts: result.dailyCosts,
                modelCosts: result.modelCosts,
                activeTasks: result.activeTasks,
                activeGoals: result.activeGoals,
                historyIsPartial: true,
                costIsPartial: true
            )
            return ClaudeCodeRateLimitSnapshot(
                planType: nil,
                limitID: "claude-code-local",
                fiveHour: result.parsedStatus?.fiveHour,
                weekly: result.parsedStatus?.weekly,
                tokenUsage: result.tokenUsage,
                recentTaskActivity: result.recentTaskActivity,
                claudeTelemetry: telemetry,
                fetchedAt: result.fetchedAt
            )
        }.value
    }
}

enum ClaudeCodeActivityHookBridgeError: LocalizedError, Equatable {
    case invalidSettings
    case hooksDisabled
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            "Claude Code settings.json contains an unsupported hooks structure."
        case .hooksDisabled:
            "Claude Code has disableAllHooks enabled. Turn hooks back on before enabling realtime tracking."
        case let .fileOperationFailed(message):
            "DockMagic could not install Claude Code realtime tracking: \(message)"
        }
    }
}

@MainActor
protocol ClaudeCodeActivityHookBridging {
    var eventsDirectoryURL: URL { get }
    func isInstalled() -> Bool
    func install() throws
    func uninstall() throws
}

/// Adds one isolated, asynchronous command hook to each Claude Code lifecycle
/// event DockMagic understands. Existing hook groups are retained verbatim.
@MainActor
struct ClaudeCodeActivityHookBridge: ClaudeCodeActivityHookBridging {
    private static let scriptVersionMarker =
        "# DockMagic Claude activity hook v1"
    private static let supportedEvents = [
        "SessionStart",
        "UserPromptSubmit",
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "PermissionRequest",
        "Notification",
        "PostCompact",
        "SubagentStart",
        "SubagentStop",
        "TaskCreated",
        "TaskCompleted",
        "Stop",
        "StopFailure",
        "TeammateIdle",
        "SessionEnd"
    ]

    let eventsDirectoryURL: URL

    private let fileManager: FileManager
    private let claudeDirectory: URL
    private let settingsURL: URL
    private let scriptURL: URL

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        claudeDirectory = homeDirectory.appendingPathComponent(
            ".claude",
            isDirectory: true
        )
        settingsURL = claudeDirectory.appendingPathComponent("settings.json")
        scriptURL = claudeDirectory.appendingPathComponent(
            "dockmagic-activity-hook.rb"
        )
        eventsDirectoryURL = claudeDirectory.appendingPathComponent(
            "dockmagic-activity-events",
            isDirectory: true
        )
    }

    func isInstalled() -> Bool {
        guard
            let settings = try? readSettings(),
            settings["disableAllHooks"] as? Bool != true,
            fileManager.isExecutableFile(atPath: scriptURL.path),
            scriptHasCurrentVersion()
        else {
            return false
        }

        return Self.supportedEvents.allSatisfy { event in
            containsOwnedHook(in: settings, event: event)
        }
    }

    func install() throws {
        do {
            try fileManager.createDirectory(
                at: claudeDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: eventsDirectoryURL,
                withIntermediateDirectories: true
            )
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: eventsDirectoryURL.path
            )

            var settings = try readSettings()
            if settings["disableAllHooks"] as? Bool == true {
                throw ClaudeCodeActivityHookBridgeError.hooksDisabled
            }

            try writeScript()
            var hooks = try hooksDictionary(from: settings["hooks"])
            for event in Self.supportedEvents {
                var groups = try hookGroups(from: hooks[event])
                groups = try groups.compactMap(removingOwnedHook)
                groups.append([
                    "hooks": [[
                        "type": "command",
                        "command": ownedCommand,
                        "async": true,
                        "timeout": 5
                    ]]
                ])
                hooks[event] = groups
            }
            settings["hooks"] = hooks
            try writeJSONObject(settings, to: settingsURL, permissions: 0o600)
        } catch let error as ClaudeCodeActivityHookBridgeError {
            throw error
        } catch {
            throw ClaudeCodeActivityHookBridgeError.fileOperationFailed(
                error.localizedDescription
            )
        }
    }

    func uninstall() throws {
        do {
            var settings = try readSettings()
            var hooks = try hooksDictionary(from: settings["hooks"])
            for event in Self.supportedEvents {
                let groups = try hookGroups(from: hooks[event])
                    .compactMap(removingOwnedHook)
                if groups.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = groups
                }
            }
            if hooks.isEmpty {
                settings.removeValue(forKey: "hooks")
            } else {
                settings["hooks"] = hooks
            }
            try writeJSONObject(settings, to: settingsURL, permissions: 0o600)

            for url in [scriptURL, eventsDirectoryURL]
                where fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch let error as ClaudeCodeActivityHookBridgeError {
            throw error
        } catch {
            throw ClaudeCodeActivityHookBridgeError.fileOperationFailed(
                error.localizedDescription
            )
        }
    }

    private var ownedCommand: String {
        Self.shellQuoted(scriptURL.path)
    }

    private func readSettings() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return [:]
        }
        guard
            let object = try? JSONSerialization.jsonObject(
                with: Data(contentsOf: settingsURL)
            ),
            let settings = object as? [String: Any]
        else {
            throw ClaudeCodeActivityHookBridgeError.invalidSettings
        }
        return settings
    }

    private func hooksDictionary(from value: Any?) throws -> [String: Any] {
        guard let value else { return [:] }
        guard let hooks = value as? [String: Any] else {
            throw ClaudeCodeActivityHookBridgeError.invalidSettings
        }
        return hooks
    }

    private func hookGroups(from value: Any?) throws -> [[String: Any]] {
        guard let value else { return [] }
        guard let groups = value as? [[String: Any]] else {
            throw ClaudeCodeActivityHookBridgeError.invalidSettings
        }
        return groups
    }

    private func containsOwnedHook(
        in settings: [String: Any],
        event: String
    ) -> Bool {
        guard
            let hooks = settings["hooks"] as? [String: Any],
            let groups = hooks[event] as? [[String: Any]]
        else {
            return false
        }
        return groups.contains { group in
            guard let handlers = group["hooks"] as? [[String: Any]] else {
                return false
            }
            return handlers.contains { isOwnedHandler($0) }
        }
    }

    private func removingOwnedHook(
        from group: [String: Any]
    ) throws -> [String: Any]? {
        guard let value = group["hooks"] else {
            throw ClaudeCodeActivityHookBridgeError.invalidSettings
        }
        guard let handlers = value as? [[String: Any]] else {
            throw ClaudeCodeActivityHookBridgeError.invalidSettings
        }
        let retainedHandlers = handlers.filter { !isOwnedHandler($0) }
        guard !retainedHandlers.isEmpty else { return nil }
        var retainedGroup = group
        retainedGroup["hooks"] = retainedHandlers
        return retainedGroup
    }

    private func isOwnedHandler(_ handler: [String: Any]) -> Bool {
        guard let command = handler["command"] as? String else {
            return false
        }
        return command == scriptURL.path || command == ownedCommand
    }

    private func writeScript() throws {
        let eventsDirectoryLiteral = try Self.quotedLiteral(
            eventsDirectoryURL.path
        )
        let supportedEventsLiteral = try Self.quotedLiteral(
            Self.supportedEvents.joined(separator: "|")
        )
        let script = """
        #!/usr/bin/ruby
        \(Self.scriptVersionMarker)
        require "json"
        require "fileutils"

        EVENT_DIRECTORY = \(eventsDirectoryLiteral)
        SUPPORTED_EVENTS = \(supportedEventsLiteral).split("|").freeze
        MAX_EVENT_FILES = 500

        def clean_text(value, limit)
          return nil unless value.is_a?(String)
          text = value.gsub(/[[:cntrl:]]+/, " ").strip
          return nil if text.empty?
          text[0, limit]
        end

        def safe_identifier(value)
          text = clean_text(value, 120)
          return nil unless text
          safe = text.gsub(/[^A-Za-z0-9_-]/, "")[0, 100]
          safe.empty? ? nil : safe
        end

        temporary_path = nil
        begin
          raw = JSON.parse(STDIN.read)
          event = clean_text(raw["hook_event_name"], 64)
          session_id = safe_identifier(raw["session_id"])
          exit 0 unless event && SUPPORTED_EVENTS.include?(event) && session_id

          observed_at_ms = (Time.now.to_f * 1_000).round
          record = {
            "schema_version" => 1,
            "observed_at_ms" => observed_at_ms,
            "hook_event_name" => event,
            "session_id" => session_id
          }
          {
            "agent_id" => [raw["agent_id"], 100, true],
            "agent_type" => [raw["agent_type"], 80, false],
            "task_id" => [raw["task_id"], 100, true],
            "task_subject" => [raw["task_subject"] || raw["active_form"], 120, false],
            "tool_name" => [raw["tool_name"], 80, false],
            "notification_type" => [raw["notification_type"], 80, false],
            "teammate_name" => [raw["teammate_name"], 80, false]
          }.each do |key, (value, limit, identifier)|
            cleaned = identifier ? safe_identifier(value) : clean_text(value, limit)
            record[key] = cleaned if cleaned
          end

          FileUtils.mkdir_p(EVENT_DIRECTORY, mode: 0700)
          File.chmod(0700, EVENT_DIRECTORY)
          suffix = "%020d-%d-%06d" % [observed_at_ms, Process.pid, rand(1_000_000)]
          final_path = File.join(EVENT_DIRECTORY, "event-#{suffix}.json")
          temporary_path = File.join(EVENT_DIRECTORY, ".event-#{suffix}.tmp")
          File.open(temporary_path, File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
            file.write(JSON.generate(record))
            file.flush
          end
          File.rename(temporary_path, final_path)
          temporary_path = nil

          files = Dir.glob(File.join(EVENT_DIRECTORY, "event-*.json")).sort
          files.first([files.length - MAX_EVENT_FILES, 0].max).each do |path|
            File.delete(path) rescue nil
          end
        rescue StandardError
          exit 0
        ensure
          File.delete(temporary_path) rescue nil if temporary_path
        end
        """

        try Data(script.utf8).write(to: scriptURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
    }

    private func scriptHasCurrentVersion() -> Bool {
        guard let contents = try? String(contentsOf: scriptURL, encoding: .utf8)
        else {
            return false
        }
        return contents.contains(Self.scriptVersionMarker)
    }

    private func writeJSONObject(
        _ object: Any,
        to url: URL,
        permissions: Int
    ) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.path
        )
    }

    private static func quotedLiteral(_ value: String) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.fragmentsAllowed, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\\"'\\\"'"))'"
    }
}

enum ClaudeCodeRateLimitParser {
    static func parse(
        _ data: Data,
        fetchedAt: Date = .now
    ) throws -> ClaudeCodeRateLimitSnapshot {
        let parsed = try ClaudeCodeStatusLineTelemetryParser.parse(
            data,
            observedAt: fetchedAt
        )
        guard parsed.hasUsefulData else {
            throw ClaudeCodeRateLimitProviderError.supportedWindowsMissing
        }

        let telemetry = parsed.session.map { session in
            ClaudeCodeTelemetrySnapshot(
                source: .statusLine,
                currentSession: session,
                observedSessionCount: session.sessionID == nil ? 0 : 1,
                dailyCosts: session.estimatedCostUSD.map {
                    [ClaudeCodeDailyCostUsage(
                        startDate: Calendar.current.startOfDay(for: fetchedAt),
                        estimatedCostUSD: $0
                    )]
                } ?? [],
                modelCosts: session.estimatedCostUSD.map { cost in
                    [ClaudeCodeModelCostUsage(
                        model: session.modelDisplayName
                            ?? session.modelID
                            ?? "Unknown model",
                        estimatedCostUSD: cost
                    )]
                } ?? [],
                activeTasks: [],
                activeGoals: [],
                historyIsPartial: true,
                costIsPartial: true
            )
        }

        return ClaudeCodeRateLimitSnapshot(
            planType: nil,
            limitID: "claude-code",
            fiveHour: parsed.fiveHour,
            weekly: parsed.weekly,
            claudeTelemetry: telemetry,
            fetchedAt: fetchedAt
        )
    }
}

enum ClaudeCodeStatusLineBridgeError: LocalizedError, Equatable {
    case invalidSettings
    case hooksDisabled
    case unsupportedStatusLine
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            "Claude Code settings.json is not valid JSON."
        case .hooksDisabled:
            "Claude Code has disableAllHooks enabled, which also disables status lines."
        case .unsupportedStatusLine:
            "The existing Claude Code status line is not a command and cannot be wrapped safely."
        case let .fileOperationFailed(message):
            "The Claude Code bridge could not be configured: \(message)"
        }
    }
}

@MainActor
protocol ClaudeCodeStatusLineBridging {
    var snapshotURL: URL { get }
    func isInstalled() -> Bool
    func install() throws
    func uninstall() throws
}

@MainActor
struct ClaudeCodeStatusLineBridge: ClaudeCodeStatusLineBridging {
    private static let scriptVersionMarker =
        "# DockMagic Claude status-line bridge v2"

    let snapshotURL: URL

    private let fileManager: FileManager
    private let claudeDirectory: URL
    private let settingsURL: URL
    private let scriptURL: URL
    private let subagentScriptURL: URL
    private let sessionSnapshotsDirectoryURL: URL
    private let taskSnapshotURL: URL
    private let taskSnapshotsDirectoryURL: URL
    private let backupURL: URL

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        claudeDirectory = homeDirectory.appendingPathComponent(
            ".claude",
            isDirectory: true
        )
        settingsURL = claudeDirectory.appendingPathComponent("settings.json")
        scriptURL = claudeDirectory.appendingPathComponent(
            "dockmagic-statusline.sh"
        )
        subagentScriptURL = claudeDirectory.appendingPathComponent(
            "dockmagic-subagent-statusline.sh"
        )
        snapshotURL = claudeDirectory.appendingPathComponent(
            "dockmagic-usage.json"
        )
        sessionSnapshotsDirectoryURL = claudeDirectory.appendingPathComponent(
            "dockmagic-status-sessions",
            isDirectory: true
        )
        taskSnapshotURL = claudeDirectory.appendingPathComponent(
            "dockmagic-subagents.json"
        )
        taskSnapshotsDirectoryURL = claudeDirectory.appendingPathComponent(
            "dockmagic-task-sessions",
            isDirectory: true
        )
        backupURL = claudeDirectory.appendingPathComponent(
            "dockmagic-statusline-backup.json"
        )
    }

    func isInstalled() -> Bool {
        guard
            let settings = try? readSettings(),
            let statusLine = settings["statusLine"] as? [String: Any],
            let statusCommand = statusLine["command"] as? String,
            let subagentStatusLine = settings["subagentStatusLine"]
                as? [String: Any],
            let subagentCommand = subagentStatusLine["command"] as? String
        else {
            return false
        }

        return isBridgeCommand(statusCommand, scriptURL: scriptURL)
            && isBridgeCommand(
                subagentCommand,
                scriptURL: subagentScriptURL
            )
            && fileManager.isExecutableFile(atPath: scriptURL.path)
            && fileManager.isExecutableFile(atPath: subagentScriptURL.path)
            && scriptHasCurrentVersion(at: scriptURL)
            && scriptHasCurrentVersion(at: subagentScriptURL)
    }

    func install() throws {
        do {
            try fileManager.createDirectory(
                at: claudeDirectory,
                withIntermediateDirectories: true
            )
            for directory in [
                sessionSnapshotsDirectoryURL,
                taskSnapshotsDirectoryURL
            ] {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                try fileManager.setAttributes(
                    [.posixPermissions: 0o700],
                    ofItemAtPath: directory.path
                )
            }

            var settings = try readSettings()
            if settings["disableAllHooks"] as? Bool == true {
                throw ClaudeCodeStatusLineBridgeError.hooksDisabled
            }

            let existingStatusLine = settings["statusLine"]
            let existingSubagentStatusLine = settings["subagentStatusLine"]
            let existingStatusCommand = try statusLineCommand(
                from: existingStatusLine
            )
            let existingSubagentCommand = try statusLineCommand(
                from: existingSubagentStatusLine
            )
            let statusWasInstalled = existingStatusCommand.map {
                isBridgeCommand($0, scriptURL: scriptURL)
            } ?? false
            let subagentWasInstalled = existingSubagentCommand.map {
                isBridgeCommand($0, scriptURL: subagentScriptURL)
            } ?? false
            let backup = try readBackup()
            let originalStatusLine = statusWasInstalled
                ? backup.statusLine
                : existingStatusLine
            let originalSubagentStatusLine = subagentWasInstalled
                ? backup.subagentStatusLine
                : existingSubagentStatusLine
            try writeBackup(
                statusLine: originalStatusLine,
                subagentStatusLine: originalSubagentStatusLine
            )

            let originalStatusCommand = try statusLineCommand(
                from: originalStatusLine
            )
            let originalSubagentCommand = try statusLineCommand(
                from: originalSubagentStatusLine
            )
            try writeBridgeScript(originalCommand: originalStatusCommand)
            try writeSubagentBridgeScript(
                originalCommand: originalSubagentCommand
            )

            var statusLine = existingStatusLine as? [String: Any] ?? [:]
            statusLine["type"] = "command"
            statusLine["command"] = Self.shellQuoted(scriptURL.path)
            settings["statusLine"] = statusLine
            var subagentStatusLine = existingSubagentStatusLine
                as? [String: Any] ?? [:]
            subagentStatusLine["type"] = "command"
            subagentStatusLine["command"] = Self.shellQuoted(
                subagentScriptURL.path
            )
            settings["subagentStatusLine"] = subagentStatusLine
            try writeJSONObject(settings, to: settingsURL, permissions: 0o600)
        } catch let error as ClaudeCodeStatusLineBridgeError {
            throw error
        } catch {
            throw ClaudeCodeStatusLineBridgeError.fileOperationFailed(
                error.localizedDescription
            )
        }
    }

    func uninstall() throws {
        do {
            var settings = try readSettings()
            let backup = try readBackup()
            if
                let statusLine = settings["statusLine"] as? [String: Any],
                let command = statusLine["command"] as? String,
                isBridgeCommand(command, scriptURL: scriptURL)
            {
                if let originalStatusLine = backup.statusLine {
                    settings["statusLine"] = originalStatusLine
                } else {
                    settings.removeValue(forKey: "statusLine")
                }
            }
            if
                let statusLine = settings["subagentStatusLine"]
                    as? [String: Any],
                let command = statusLine["command"] as? String,
                isBridgeCommand(command, scriptURL: subagentScriptURL)
            {
                if let originalStatusLine = backup.subagentStatusLine {
                    settings["subagentStatusLine"] = originalStatusLine
                } else {
                    settings.removeValue(forKey: "subagentStatusLine")
                }
            }
            try writeJSONObject(
                settings,
                to: settingsURL,
                permissions: 0o600
            )

            for url in [
                scriptURL,
                subagentScriptURL,
                snapshotURL,
                taskSnapshotURL,
                sessionSnapshotsDirectoryURL,
                taskSnapshotsDirectoryURL,
                backupURL
            ] {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }
        } catch let error as ClaudeCodeStatusLineBridgeError {
            throw error
        } catch {
            throw ClaudeCodeStatusLineBridgeError.fileOperationFailed(
                error.localizedDescription
            )
        }
    }

    private func readSettings() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return [:]
        }

        guard
            let object = try? JSONSerialization.jsonObject(
                with: Data(contentsOf: settingsURL)
            ),
            let settings = object as? [String: Any]
        else {
            throw ClaudeCodeStatusLineBridgeError.invalidSettings
        }
        return settings
    }

    private func statusLineCommand(from value: Any?) throws -> String? {
        guard let value else {
            return nil
        }
        guard
            let statusLine = value as? [String: Any],
            statusLine["type"] as? String == "command",
            let command = statusLine["command"] as? String
        else {
            throw ClaudeCodeStatusLineBridgeError.unsupportedStatusLine
        }
        return command
    }

    private func isBridgeCommand(_ command: String, scriptURL: URL) -> Bool {
        command == scriptURL.path
            || command == Self.shellQuoted(scriptURL.path)
    }

    private func writeBackup(
        statusLine: Any?,
        subagentStatusLine: Any?
    ) throws {
        try writeJSONObject(
            [
                "statusLine": statusLine ?? NSNull(),
                "subagentStatusLine": subagentStatusLine ?? NSNull()
            ],
            to: backupURL,
            permissions: 0o600
        )
    }

    private func readBackup() throws -> BridgeBackup {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            return BridgeBackup(statusLine: nil, subagentStatusLine: nil)
        }
        guard
            let object = try? JSONSerialization.jsonObject(
                with: Data(contentsOf: backupURL)
            ),
            let backup = object as? [String: Any]
        else {
            throw ClaudeCodeStatusLineBridgeError.invalidSettings
        }
        let statusLine = backup["statusLine"]
        let subagentStatusLine = backup["subagentStatusLine"]
        return BridgeBackup(
            statusLine: statusLine is NSNull ? nil : statusLine,
            subagentStatusLine: subagentStatusLine is NSNull
                ? nil
                : subagentStatusLine
        )
    }

    private func writeBridgeScript(originalCommand: String?) throws {
        let original = Self.shellQuoted(originalCommand ?? "")
        let script = """
        #!/bin/sh
        \(Self.scriptVersionMarker)
        set -u
        umask 077

        CACHE=\(Self.shellQuoted(snapshotURL.path))
        CACHE_DIRECTORY=\(Self.shellQuoted(sessionSnapshotsDirectoryURL.path))
        ORIGINAL_COMMAND=\(original)
        INPUT_FILE=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/dockmagic-statusline.XXXXXX") || exit 1
        VALIDATED_FILE="${INPUT_FILE}.validated"
        CACHE_TEMP="${CACHE}.tmp.$$"
        SESSION_TEMP=""

        cleanup() {
          /bin/rm -f "$INPUT_FILE" "$VALIDATED_FILE" "$CACHE_TEMP"
          if [ -n "$SESSION_TEMP" ]; then
            /bin/rm -f "$SESSION_TEMP"
          fi
        }
        trap cleanup EXIT HUP INT TERM

        /bin/cat > "$INPUT_FILE"
        # Claude's documented status-line JSON contains legitimate null values,
        # which plutil rejects because property lists cannot represent null.
        if /usr/bin/json_pp < "$INPUT_FILE" > "$VALIDATED_FILE" 2>/dev/null; then
          /bin/cp "$INPUT_FILE" "$CACHE_TEMP"
          /bin/chmod 600 "$CACHE_TEMP"
          /bin/mv -f "$CACHE_TEMP" "$CACHE"

          SESSION_ID=$(/usr/bin/awk -F'"' '$2 == "session_id" { print $4; exit }' "$VALIDATED_FILE")
          case "$SESSION_ID" in
            ''|*[!A-Za-z0-9_-]*) SESSION_ID='' ;;
          esac
          if [ -n "$SESSION_ID" ]; then
            SESSION_CACHE="${CACHE_DIRECTORY}/${SESSION_ID}.json"
            SESSION_TEMP="${SESSION_CACHE}.tmp.$$"
            /bin/cp "$INPUT_FILE" "$SESSION_TEMP"
            /bin/chmod 600 "$SESSION_TEMP"
            /bin/mv -f "$SESSION_TEMP" "$SESSION_CACHE"
            SESSION_TEMP=""
          fi
        fi

        if [ -n "$ORIGINAL_COMMAND" ]; then
          /bin/sh -c "$ORIGINAL_COMMAND" < "$INPUT_FILE"
        fi
        """

        try Data(script.utf8).write(to: scriptURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
    }

    private func writeSubagentBridgeScript(
        originalCommand: String?
    ) throws {
        let original = Self.shellQuoted(originalCommand ?? "")
        let script = """
        #!/bin/sh
        \(Self.scriptVersionMarker)
        set -u
        umask 077

        CACHE=\(Self.shellQuoted(taskSnapshotURL.path))
        CACHE_DIRECTORY=\(Self.shellQuoted(taskSnapshotsDirectoryURL.path))
        ORIGINAL_COMMAND=\(original)
        INPUT_FILE=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/dockmagic-subagent-statusline.XXXXXX") || exit 1
        VALIDATED_FILE="${INPUT_FILE}.validated"
        CACHE_TEMP="${CACHE}.tmp.$$"
        SESSION_TEMP=""

        cleanup() {
          /bin/rm -f "$INPUT_FILE" "$VALIDATED_FILE" "$CACHE_TEMP"
          if [ -n "$SESSION_TEMP" ]; then
            /bin/rm -f "$SESSION_TEMP"
          fi
        }
        trap cleanup EXIT HUP INT TERM

        /bin/cat > "$INPUT_FILE"
        # Subagent payloads may also contain JSON nulls for optional fields.
        if /usr/bin/json_pp < "$INPUT_FILE" > "$VALIDATED_FILE" 2>/dev/null; then
          /bin/cp "$INPUT_FILE" "$CACHE_TEMP"
          /bin/chmod 600 "$CACHE_TEMP"
          /bin/mv -f "$CACHE_TEMP" "$CACHE"

          SESSION_ID=$(/usr/bin/awk -F'"' '$2 == "session_id" { print $4; exit }' "$VALIDATED_FILE")
          case "$SESSION_ID" in
            ''|*[!A-Za-z0-9_-]*) SESSION_ID='' ;;
          esac
          if [ -n "$SESSION_ID" ]; then
            SESSION_CACHE="${CACHE_DIRECTORY}/${SESSION_ID}.json"
            SESSION_TEMP="${SESSION_CACHE}.tmp.$$"
            /bin/cp "$INPUT_FILE" "$SESSION_TEMP"
            /bin/chmod 600 "$SESSION_TEMP"
            /bin/mv -f "$SESSION_TEMP" "$SESSION_CACHE"
            SESSION_TEMP=""
          fi
        fi

        if [ -n "$ORIGINAL_COMMAND" ]; then
          /bin/sh -c "$ORIGINAL_COMMAND" < "$INPUT_FILE"
        fi
        """

        try Data(script.utf8).write(
            to: subagentScriptURL,
            options: .atomic
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: subagentScriptURL.path
        )
    }

    private func scriptHasCurrentVersion(at url: URL) -> Bool {
        guard
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return false
        }
        return contents.contains(Self.scriptVersionMarker)
    }

    private func writeJSONObject(
        _ object: Any,
        to url: URL,
        permissions: Int
    ) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.path
        )
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\\"'\\\"'"))'"
    }

    private struct BridgeBackup {
        let statusLine: Any?
        let subagentStatusLine: Any?
    }
}
