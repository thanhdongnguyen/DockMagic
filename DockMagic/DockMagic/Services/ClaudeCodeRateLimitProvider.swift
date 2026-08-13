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

    init(
        snapshotURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/dockmagic-usage.json")
    ) {
        self.snapshotURL = snapshotURL
    }

    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot {
        let snapshotURL = snapshotURL
        return try await Task.detached(priority: .utility) {
            let data: Data
            do {
                data = try Data(contentsOf: snapshotURL)
            } catch let error as CocoaError
                where error.code == .fileReadNoSuchFile {
                throw ClaudeCodeRateLimitProviderError.snapshotMissing
            } catch {
                throw ClaudeCodeRateLimitProviderError.invalidSnapshot
            }

            let attributes = try? FileManager.default.attributesOfItem(
                atPath: snapshotURL.path
            )
            let fetchedAt = attributes?[.modificationDate] as? Date ?? .now
            return try ClaudeCodeRateLimitParser.parse(
                data,
                fetchedAt: fetchedAt
            )
        }.value
    }
}

enum ClaudeCodeRateLimitParser {
    static func parse(
        _ data: Data,
        fetchedAt: Date = .now
    ) throws -> ClaudeCodeRateLimitSnapshot {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any]
        else {
            throw ClaudeCodeRateLimitProviderError.invalidSnapshot
        }

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

        guard fiveHour != nil || weekly != nil else {
            throw ClaudeCodeRateLimitProviderError.supportedWindowsMissing
        }

        return ClaudeCodeRateLimitSnapshot(
            planType: nil,
            limitID: "claude-code",
            fiveHour: fiveHour,
            weekly: weekly,
            fetchedAt: fetchedAt
        )
    }

    private static func parseWindow(
        _ value: Any?,
        kind: ClaudeCodeRateLimitWindowKind,
        durationMinutes: Int
    ) -> ClaudeCodeRateLimitWindow? {
        guard
            let dictionary = value as? [String: Any],
            let usedPercentage = dictionary["used_percentage"] as? NSNumber
        else {
            return nil
        }

        let normalized = min(max(usedPercentage.doubleValue, 0), 100)
        let resetsAt = (dictionary["resets_at"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue)
        }

        return ClaudeCodeRateLimitWindow(
            kind: kind,
            usedPercent: Int(normalized.rounded()),
            windowDurationMinutes: durationMinutes,
            resetsAt: resetsAt
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
    let snapshotURL: URL

    private let fileManager: FileManager
    private let claudeDirectory: URL
    private let settingsURL: URL
    private let scriptURL: URL
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
        snapshotURL = claudeDirectory.appendingPathComponent(
            "dockmagic-usage.json"
        )
        backupURL = claudeDirectory.appendingPathComponent(
            "dockmagic-statusline-backup.json"
        )
    }

    func isInstalled() -> Bool {
        guard
            let settings = try? readSettings(),
            let statusLine = settings["statusLine"] as? [String: Any],
            let command = statusLine["command"] as? String
        else {
            return false
        }

        return isBridgeCommand(command)
            && fileManager.isExecutableFile(atPath: scriptURL.path)
    }

    func install() throws {
        do {
            try fileManager.createDirectory(
                at: claudeDirectory,
                withIntermediateDirectories: true
            )

            var settings = try readSettings()
            if settings["disableAllHooks"] as? Bool == true {
                throw ClaudeCodeStatusLineBridgeError.hooksDisabled
            }

            let existingStatusLine = settings["statusLine"]
            let existingCommand = try statusLineCommand(
                from: existingStatusLine
            )
            let wasInstalled = existingCommand.map(isBridgeCommand) ?? false
            let originalStatusLine: Any?

            if wasInstalled {
                originalStatusLine = try readBackupStatusLine()
            } else {
                originalStatusLine = existingStatusLine
                try writeBackup(statusLine: existingStatusLine)
            }

            let originalCommand = try statusLineCommand(
                from: originalStatusLine
            )
            try writeBridgeScript(originalCommand: originalCommand)

            var statusLine = existingStatusLine as? [String: Any] ?? [:]
            statusLine["type"] = "command"
            statusLine["command"] = Self.shellQuoted(scriptURL.path)
            settings["statusLine"] = statusLine
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
            if
                let statusLine = settings["statusLine"] as? [String: Any],
                let command = statusLine["command"] as? String,
                isBridgeCommand(command)
            {
                if let originalStatusLine = try readBackupStatusLine() {
                    settings["statusLine"] = originalStatusLine
                } else {
                    settings.removeValue(forKey: "statusLine")
                }
                try writeJSONObject(
                    settings,
                    to: settingsURL,
                    permissions: 0o600
                )
            }

            for url in [scriptURL, snapshotURL, backupURL] {
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

    private func isBridgeCommand(_ command: String) -> Bool {
        command == scriptURL.path
            || command == Self.shellQuoted(scriptURL.path)
    }

    private func writeBackup(statusLine: Any?) throws {
        try writeJSONObject(
            ["statusLine": statusLine ?? NSNull()],
            to: backupURL,
            permissions: 0o600
        )
    }

    private func readBackupStatusLine() throws -> Any? {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            return nil
        }
        guard
            let object = try? JSONSerialization.jsonObject(
                with: Data(contentsOf: backupURL)
            ),
            let backup = object as? [String: Any]
        else {
            throw ClaudeCodeStatusLineBridgeError.invalidSettings
        }
        let value = backup["statusLine"]
        return value is NSNull ? nil : value
    }

    private func writeBridgeScript(originalCommand: String?) throws {
        let original = Self.shellQuoted(originalCommand ?? "")
        let script = """
        #!/bin/sh
        set -u
        umask 077

        CACHE=\(Self.shellQuoted(snapshotURL.path))
        ORIGINAL_COMMAND=\(original)
        INPUT_FILE=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/dockmagic-statusline.XXXXXX") || exit 1
        CACHE_TEMP="${CACHE}.tmp.$$"

        cleanup() {
          /bin/rm -f "$INPUT_FILE" "$CACHE_TEMP"
        }
        trap cleanup EXIT HUP INT TERM

        /bin/cat > "$INPUT_FILE"
        if /usr/bin/plutil -extract rate_limits json -o "$CACHE_TEMP" "$INPUT_FILE" >/dev/null 2>&1; then
          /bin/mv -f "$CACHE_TEMP" "$CACHE"
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
}
