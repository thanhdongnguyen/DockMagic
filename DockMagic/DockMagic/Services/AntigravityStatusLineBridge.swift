import Foundation

@MainActor
protocol AntigravityStatusLineBridging {
    var sessionsDirectoryURL: URL { get }
    func isInstalled() -> Bool
    func install() throws
    func uninstall() throws
    func refreshOwnedScriptIfNeeded() throws
    func pruneArchivedHistory(asOf date: Date) throws
}

extension AntigravityStatusLineBridging {
    func refreshOwnedScriptIfNeeded() throws {}
    func pruneArchivedHistory(asOf date: Date) throws {}
}

@MainActor
struct AntigravityStatusLineBridge: AntigravityStatusLineBridging {
    let rootDirectoryURL: URL
    let sessionsDirectoryURL: URL
    private let settingsURL: URL
    private let hooksURL: URL
    private var scriptURL: URL {
        rootDirectoryURL.appendingPathComponent("dockmagic-statusline.sh")
    }
    private var backupURL: URL {
        rootDirectoryURL.appendingPathComponent("statusline-backup.json")
    }

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        rootDirectoryURL = home.appendingPathComponent(
            ".gemini/dockmagic-antigravity",
            isDirectory: true
        )
        sessionsDirectoryURL = rootDirectoryURL.appendingPathComponent(
            "sessions",
            isDirectory: true
        )
        settingsURL = home.appendingPathComponent(
            ".gemini/antigravity-cli/settings.json"
        )
        hooksURL = home.appendingPathComponent(".gemini/config/hooks.json")
    }

    private var statusCommand: String {
        "\(Self.quote("/bin/sh")) \(Self.quote(scriptURL.path))"
    }

    func isInstalled() -> Bool {
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path),
              let settings = try? readDictionary(settingsURL),
              let statusLine = settings["statusLine"] as? [String: Any] else {
            return false
        }
        return statusLine["command"] as? String == statusCommand
            && statusLine["enabled"] as? Bool != false
    }

    func refreshOwnedScriptIfNeeded() throws {
        guard isInstalled() else { return }
        let current = try Data(contentsOf: scriptURL)
        let replacement = Data(Self.script.utf8)
        guard current != replacement else { return }
        try replacement.write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
    }

    func pruneArchivedHistory(asOf date: Date) throws {
        let historyURL = rootDirectoryURL.appendingPathComponent(
            "history", isDirectory: true
        )
        guard let values = try? historyURL.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ), values.isDirectory == true,
        values.isSymbolicLink != true else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let cutoff = calendar.date(
            byAdding: .day, value: -29, to: calendar.startOfDay(for: date)
        ) else { return }
        let cutoffKey = TokenUsageCalendarDay.containing(
            cutoff, calendar: calendar
        ).key.replacingOccurrences(of: "-", with: "")

        let directories = try FileManager.default.contentsOfDirectory(
            at: historyURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        for directory in directories {
            let key = directory.lastPathComponent
            guard key.count == 8,
                  key.utf8.allSatisfy({ (48...57).contains($0) }),
                  key < cutoffKey,
                  let directoryValues = try? directory.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                  ), directoryValues.isDirectory == true,
                  directoryValues.isSymbolicLink != true else { continue }
            try FileManager.default.removeItem(at: directory)
        }
    }

    func install() throws {
        var settings = try readDictionary(settingsURL)
        let existingStatusLine = settings["statusLine"]
        let existingCommand = (existingStatusLine as? [String: Any])?["command"]
            as? String
        let alreadyOwned = existingCommand == statusCommand
        let migratingLegacy = existingCommand.map(Self.isLegacyCommand) == true

        if !alreadyOwned, !migratingLegacy,
           FileManager.default.fileExists(atPath: backupURL.path) {
            throw AntigravityUsageError.bridgeConflict
        }

        try createPrivateDirectory(rootDirectoryURL)
        try createPrivateDirectory(sessionsDirectoryURL)

        if !alreadyOwned, !migratingLegacy {
            try writeDictionary(
                ["statusLine": existingStatusLine ?? NSNull()],
                to: backupURL
            )
        } else if migratingLegacy,
                  !FileManager.default.fileExists(atPath: backupURL.path) {
            throw AntigravityUsageError.bridgeConflict
        }

        try Data(Self.script.utf8).write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )

        var replacement = existingStatusLine as? [String: Any] ?? [:]
        replacement["type"] = "command"
        replacement["command"] = statusCommand
        replacement["enabled"] = true
        if backupContainsNoStatusLine() {
            replacement["stack_with_default"] = true
        }
        settings["statusLine"] = replacement
        try writeDictionary(settings, to: settingsURL)
        try removeLegacyHooksIfOwned()
    }

    func uninstall() throws {
        var settings = try readDictionary(settingsURL)
        guard let statusLine = settings["statusLine"] as? [String: Any],
              statusLine["command"] as? String == statusCommand else {
            if isInstalled() {
                throw AntigravityUsageError.bridgeConflict
            }
            return
        }
        let backup = try readDictionary(backupURL)
        guard let previous = backup["statusLine"] else {
            throw AntigravityUsageError.bridgeConflict
        }
        if previous is NSNull {
            settings.removeValue(forKey: "statusLine")
        } else {
            settings["statusLine"] = previous
        }
        try writeDictionary(settings, to: settingsURL)
        try? FileManager.default.removeItem(at: scriptURL)
        try? FileManager.default.removeItem(at: backupURL)
    }

    private func backupContainsNoStatusLine() -> Bool {
        guard let backup = try? readDictionary(backupURL) else { return false }
        return backup["statusLine"] is NSNull
    }

    private func removeLegacyHooksIfOwned() throws {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else {
            return
        }
        var hooks = try readDictionary(hooksURL)
        guard let owned = hooks["dockmagic-antigravity"] as? [String: Any],
              Self.isLegacyHookGroup(owned) else {
            return
        }
        hooks.removeValue(forKey: "dockmagic-antigravity")
        try writeDictionary(hooks, to: hooksURL)
    }

    private static func isLegacyHookGroup(_ group: [String: Any]) -> Bool {
        let expected = Set(["PreInvocation", "PostInvocation", "PostToolUse", "Stop"])
        guard Set(group.keys) == expected else { return false }
        let encoded = (try? JSONSerialization.data(withJSONObject: group))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return encoded.contains("dockmagic-antigravity/bridge.py")
    }

    private static func isLegacyCommand(_ command: String) -> Bool {
        command.contains("dockmagic-antigravity/bridge.py")
            && command.hasSuffix(" status")
    }

    private func readDictionary(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= 1_000_000,
              let value = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            throw AntigravityUsageError.invalidConfiguration
        }
        return value
    }

    private func writeDictionary(_ value: [String: Any], to url: URL) throws {
        try createPrivateDirectory(url.deletingLastPathComponent())
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private func createPrivateDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static let script = #"""
#!/bin/sh
set -u
umask 077

root=${0%/*}
sessions="$root/sessions"
history="$root/history"
backup="$root/statusline-backup.json"
payload=$(/usr/bin/head -c 1000001)

extract_raw() {
    /usr/bin/printf '%s' "$payload" \
        | /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null
}

add_string() {
    value=$(extract_raw "$1") || return 0
    [ -n "$value" ] || return 0
    [ ${#value} -le "$3" ] || value=$(/usr/bin/printf '%s' "$value" | /usr/bin/cut -c "1-$3")
    target=${4:-$capture}
    /usr/bin/plutil -insert "$2" -string "$value" "$target" >/dev/null 2>&1 || true
}

add_integer() {
    value=$(extract_raw "$1") || return 0
    target=${3:-$capture}
    /usr/bin/plutil -insert "$2" -integer "$value" "$target" >/dev/null 2>&1 || true
}

add_float() {
    value=$(extract_raw "$1") || return 0
    /usr/bin/plutil -insert "$2" -float "$value" "$capture" >/dev/null 2>&1 || true
}

add_bool() {
    value=$(extract_raw "$1") || return 0
    /usr/bin/plutil -insert "$2" -bool "$value" "$capture" >/dev/null 2>&1 || true
}

archive_usage() {
    [ ! -L "$history" ] || return 0
    input_total=$(extract_raw context_window.total_input_tokens) || return 0
    output_total=$(extract_raw context_window.total_output_tokens) || return 0
    case "$input_total:$output_total" in *[!0-9:]*|:*|*:) return 0 ;; esac
    [ "$input_total" -le 1000000000000 ] \
        && [ "$output_total" -le 1000000000000 ] || return 0
    observed_seconds=${observed_at%.*}
    archive_day=$(/bin/date -r "$observed_seconds" +%Y%m%d) || return 0
    day_directory="$history/$archive_day"
    /bin/mkdir -p "$day_directory" || return 0
    /bin/chmod 700 "$history" "$day_directory" 2>/dev/null || true
    history_capture=$(/usr/bin/mktemp "$day_directory/.usage.XXXXXX") || return 0
    if ! /usr/bin/plutil -create xml1 "$history_capture" >/dev/null 2>&1; then
        /bin/rm -f "$history_capture"
        return 0
    fi
    /usr/bin/plutil -insert schema_version -integer 1 "$history_capture" >/dev/null 2>&1 || true
    /usr/bin/plutil -insert observed_at -float "$observed_at" "$history_capture" >/dev/null 2>&1 || true
    /usr/bin/plutil -insert model -json '{}' "$history_capture" >/dev/null 2>&1 || true
    /usr/bin/plutil -insert context_window -json '{}' "$history_capture" >/dev/null 2>&1 || true
    add_string model.id model.id 160 "$history_capture"
    add_integer context_window.total_input_tokens context_window.total_input_tokens "$history_capture"
    add_integer context_window.total_output_tokens context_window.total_output_tokens "$history_capture"
    if ! /usr/bin/plutil -convert json "$history_capture" >/dev/null 2>&1; then
        /bin/rm -f "$history_capture"
        return 0
    fi
    /bin/chmod 600 "$history_capture" 2>/dev/null || true
    /bin/ln "$history_capture" "$day_directory/$session_key-first.json" 2>/dev/null || true
    last_capture=$(/usr/bin/mktemp "$day_directory/.last.XXXXXX")
    if [ -n "$last_capture" ]; then
        if /bin/cp "$history_capture" "$last_capture" \
            && /bin/chmod 600 "$last_capture" \
            && /bin/mv -f "$last_capture" "$day_directory/$session_key-last.json"; then
            :
        else
            /bin/rm -f "$last_capture"
        fi
    fi
    /bin/rm -f "$history_capture"
}

prune_history() {
    [ -d "$history" ] && [ ! -L "$history" ] || return 0
    cutoff=$(/bin/date -v-29d +%Y%m%d) || return 0
    for old_directory in "$history"/????????; do
        [ -d "$old_directory" ] && [ ! -L "$old_directory" ] || continue
        old_day=${old_directory##*/}
        case "$old_day" in *[!0-9]*|'') continue ;; esac
        [ "$old_day" -lt "$cutoff" ] || continue
        /bin/rm -rf "$old_directory"
    done
}

capture_payload() {
    [ ${#payload} -le 1000000 ] || return 0
    session_id=$(extract_raw conversation_id) || session_id=$(extract_raw session_id) || return 0
    case "$session_id" in
        ''|*[!A-Za-z0-9-]*) return 0 ;;
    esac
    [ ${#session_id} -le 160 ] || return 0
    session_key=$(/usr/bin/printf '%s' "$session_id" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')
    [ -n "$session_key" ] || return 0

    /bin/mkdir -p "$sessions" || return 0
    /bin/chmod 700 "$root" "$sessions" 2>/dev/null || true
    capture=$(/usr/bin/mktemp "$root/.capture.XXXXXX") || return 0
    trap '/bin/rm -f "$capture"' EXIT HUP INT TERM
    /usr/bin/plutil -create xml1 "$capture" >/dev/null 2>&1 || return 0
    /usr/bin/plutil -insert schema_version -integer 1 "$capture" >/dev/null 2>&1 || return 0
    observed_at=$(/usr/bin/perl -MTime::HiRes=time -e 'printf "%.6f", time' 2>/dev/null || /bin/date +%s)
    /usr/bin/plutil -insert observed_at -float "$observed_at" "$capture" >/dev/null 2>&1 || return 0
    /usr/bin/plutil -insert model -json '{}' "$capture" >/dev/null 2>&1 || true
    /usr/bin/plutil -insert context_window -json '{}' "$capture" >/dev/null 2>&1 || true
    /usr/bin/plutil -insert context_window.current_usage -json '{}' "$capture" >/dev/null 2>&1 || true

    add_string model.id model.id 160
    add_string model.display_name model.display_name 160
    add_string version version 80
    add_string plan_tier plan_tier 80
    add_string agent_state agent_state 40
    add_string execution_mode execution_mode 40
    add_integer task_count task_count
    add_integer artifact_count artifact_count
    add_integer pending_input_count pending_input_count
    add_bool tool_confirmation_pending tool_confirmation_pending
    add_integer context_window.total_input_tokens context_window.total_input_tokens
    add_integer context_window.total_output_tokens context_window.total_output_tokens
    add_integer context_window.context_window_size context_window.context_window_size
    add_float context_window.used_percentage context_window.used_percentage
    add_float context_window.remaining_percentage context_window.remaining_percentage
    add_integer context_window.current_usage.input_tokens context_window.current_usage.input_tokens
    add_integer context_window.current_usage.output_tokens context_window.current_usage.output_tokens
    add_integer context_window.current_usage.cache_creation_input_tokens context_window.current_usage.cache_creation_input_tokens
    add_integer context_window.current_usage.cache_read_input_tokens context_window.current_usage.cache_read_input_tokens

    /usr/bin/plutil -convert json "$capture" >/dev/null 2>&1 || return 0
    /bin/chmod 600 "$capture" 2>/dev/null || true
    archive_usage
    /bin/mv -f "$capture" "$sessions/$session_key.json"
    trap - EXIT HUP INT TERM
    prune_history
}

capture_payload || true

if [ -f "$backup" ]; then
    previous_enabled=$(/usr/bin/plutil -extract statusLine.enabled raw -o - "$backup" 2>/dev/null || /usr/bin/printf 'true')
    previous_command=$(/usr/bin/plutil -extract statusLine.command raw -o - "$backup" 2>/dev/null || true)
    case "$previous_command" in
        *dockmagic-statusline.sh*|*dockmagic-antigravity/bridge.py*) previous_command='' ;;
    esac
    if [ "$previous_enabled" != "false" ] && [ -n "$previous_command" ]; then
        /usr/bin/printf '%s' "$payload" | /bin/sh -c "$previous_command"
    fi
fi

exit 0
"""#
}
