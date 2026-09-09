import Foundation

@MainActor
protocol AntigravityTelemetryBridging {
    var directoryURL: URL { get }
    func isInstalled() -> Bool
    func install() throws
    func uninstall() throws
}

@MainActor
struct AntigravityTelemetryBridge: AntigravityTelemetryBridging {
    let directoryURL: URL
    private let settingsURL: URL
    private let hooksURL: URL
    private let pythonURL: URL
    private var scriptURL: URL { directoryURL.appendingPathComponent("bridge.py") }
    private var backupURL: URL { directoryURL.appendingPathComponent("statusline-backup.json") }
    private static let hookKey = "dockmagic-antigravity"

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
         pythonURL: URL = URL(fileURLWithPath: "/usr/bin/python3")) {
        directoryURL = home.appendingPathComponent(".gemini/dockmagic-antigravity", isDirectory: true)
        settingsURL = home.appendingPathComponent(".gemini/antigravity-cli/settings.json")
        hooksURL = home.appendingPathComponent(".gemini/config/hooks.json")
        self.pythonURL = pythonURL
    }

    private var statusCommand: String {
        "\(Self.quote(pythonURL.path)) \(Self.quote(scriptURL.path)) status"
    }

    private var hookConfiguration: [String: Any] {
        var hooks: [String: Any] = [:]
        for event in ["PreInvocation", "PostInvocation", "PostToolUse", "Stop"] {
            let command: [String: Any] = [
                "type": "command", "timeout": 3,
                "command": "\(Self.quote(pythonURL.path)) \(Self.quote(scriptURL.path)) \(event)"
            ]
            hooks[event] = event == "PostToolUse"
                ? [["matcher": ".*", "hooks": [command]]] : [command]
        }
        return hooks
    }

    func isInstalled() -> Bool {
        guard FileManager.default.fileExists(atPath: scriptURL.path),
              let settings = try? read(settingsURL),
              let status = settings["statusLine"] as? [String: Any],
              status["command"] as? String == statusCommand,
              status["enabled"] as? Bool != false,
              let hooks = try? read(hooksURL),
              let owned = hooks[Self.hookKey] as? NSDictionary else { return false }
        return owned.isEqual(to: hookConfiguration)
    }

    func install() throws {
        guard FileManager.default.isExecutableFile(atPath: pythonURL.path) else {
            throw AntigravityDataError.missingPython
        }
        // Read and validate both files before writing anything.
        var settings = try read(settingsURL)
        var hooks = try read(hooksURL)
        if let existing = hooks[Self.hookKey] {
            guard let existing = existing as? NSDictionary, existing.isEqual(to: hookConfiguration) else {
                throw AntigravityDataError.bridgeConflict
            }
        }
        let status = settings["statusLine"] as? [String: Any]
        let alreadyOwned = status?["command"] as? String == statusCommand
        if !alreadyOwned && FileManager.default.fileExists(atPath: backupURL.path) {
            throw AntigravityDataError.bridgeConflict
        }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        if !alreadyOwned {
            try write(["statusLine": settings["statusLine"] ?? NSNull()], to: backupURL)
        }
        try Data(Self.script.utf8).write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        var replacement = status ?? [:]
        replacement["type"] = "command"
        replacement["command"] = statusCommand
        replacement["enabled"] = true
        settings["statusLine"] = replacement
        hooks[Self.hookKey] = hookConfiguration
        let originalSettings = try read(settingsURL)
        do {
            try write(settings, to: settingsURL)
            try write(hooks, to: hooksURL)
        } catch {
            try? write(originalSettings, to: settingsURL)
            if !alreadyOwned { try? FileManager.default.removeItem(at: backupURL) }
            throw error
        }
    }

    func uninstall() throws {
        var settings = try read(settingsURL)
        var hooks = try read(hooksURL)
        if let status = settings["statusLine"] as? [String: Any],
           status["command"] as? String == statusCommand {
            let backup = try read(backupURL)
            guard let old = backup["statusLine"] else { throw AntigravityDataError.bridgeConflict }
            if old is NSNull { settings.removeValue(forKey: "statusLine") }
            else { settings["statusLine"] = old }
        }
        if let owned = hooks[Self.hookKey] as? NSDictionary,
           owned.isEqual(to: hookConfiguration) { hooks.removeValue(forKey: Self.hookKey) }
        try write(settings, to: settingsURL)
        try write(hooks, to: hooksURL)
        // Retain private observed history; remove only the owned integration.
        if let owned = hooks[Self.hookKey] { _ = owned; return }
        for url in [scriptURL, backupURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func read(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let value = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw AntigravityDataError.invalidConfiguration
        }
        return value
    }

    private func write(_ object: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    static let script = #"""
import sys, os, json, time, hashlib, tempfile, subprocess, math, fcntl
from pathlib import Path

root = Path(__file__).resolve().parent
os.umask(0o077)
raw = sys.stdin.buffer.read(2_000_001)
event = sys.argv[1] if len(sys.argv) > 1 else 'status'

def text(value, limit=160):
    if not isinstance(value, str): return None
    return ''.join(c for c in value if ord(c) >= 32 and ord(c) != 127)[:limit] or None

def number(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value >= 0 else None

def fields(value, keys, converter=number):
    if not isinstance(value, dict): return {}
    return {key: converter(value[key]) for key in keys if key in value and converter(value[key]) is not None}

def save(folder, name, value):
    directory = root / folder
    directory.mkdir(mode=0o700, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=directory)
    try:
        with os.fdopen(fd, 'w') as file: json.dump(value, file, separators=(',', ':'))
        os.replace(temp, directory / (name + '.json'))
    finally:
        if os.path.exists(temp): os.unlink(temp)

try:
    if len(raw) > 2_000_000: raise ValueError('payload too large')
    payload = json.loads(raw)
    sid = text(payload.get('conversation_id') or payload.get('session_id') or payload.get('conversationId'))
    if not sid: raise ValueError('missing session')
    key = hashlib.sha256(sid.encode()).hexdigest()
    sample = {'session_id': sid, 'observed_at': time.time(), 'event': event}
    if event == 'status':
        for field in ['agent_state', 'plan_tier', 'execution_mode', 'version']:
            value = text(payload.get(field))
            if value is not None: sample[field] = value
        sample['model'] = fields(payload.get('model'), ['id', 'display_name'], text)
        context = payload.get('context_window', {})
        sample['context_window'] = fields(context, ['total_input_tokens', 'total_output_tokens', 'context_window_size', 'used_percentage', 'remaining_percentage'])
        sample['context_window']['current_usage'] = fields(context.get('current_usage', {}), ['input_tokens', 'output_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens'])
        sample['cost'] = fields(payload.get('cost', {}), ['total_cost_usd'])
        sample.update(fields(payload, ['task_count', 'artifact_count', 'pending_input_count']))
        sample['tool_confirmation_pending'] = payload.get('tool_confirmation_pending') is True
        quotas = payload.get('quota', {})
        sample['quota'] = {}
        if isinstance(quotas, dict):
            for bucket, value in list(quotas.items())[:100]:
                if not isinstance(value, dict): continue
                clean = fields(value, ['remaining_fraction', 'reset_in_seconds'])
                if text(value.get('reset_time')): clean['reset_time'] = text(value['reset_time'])
                sample['quota'][text(bucket)] = clean
        # A cumulative counter is persisted once per change. Session locking
        # prevents concurrent statusline invocations from corrupting history.
        with open(root / (key + '.lock'), 'a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            previous_path = root / 'sessions' / (key + '.json')
            try: previous = json.loads(previous_path.read_text())
            except Exception: previous = {}
            compared = ['context_window', 'model', 'cost']
            if any(previous.get(k) != sample.get(k) for k in compared):
                save('observations', str(time.time_ns()) + '-' + key, sample)
            save('sessions', key, sample)
    else:
        sample['model_name'] = text(payload.get('modelName'))
        sample['tool_name'] = text((payload.get('toolCall') or {}).get('name'))
        sample['has_error'] = bool(payload.get('error'))
        sample['fully_idle'] = payload.get('fullyIdle') is True
        sample['termination_reason'] = text(payload.get('terminationReason'))
        save('events', key, sample)
    # Bound disk use. Old observations remain explicitly partial after pruning.
    for folder, limit, age in [('observations', 10000, 32*86400), ('sessions', 500, 32*86400), ('events', 500, 86400)]:
        directory = root / folder
        if not directory.exists(): continue
        files = sorted(directory.glob('*.json'), key=lambda p: p.stat().st_mtime, reverse=True)
        for index, path in enumerate(files):
            if index >= limit or time.time() - path.stat().st_mtime > age:
                try: path.unlink()
                except FileNotFoundError: pass
except Exception:
    pass

if event == 'status':
    try:
        original = json.loads((root / 'statusline-backup.json').read_text()).get('statusLine') or {}
        command = original.get('command')
        if original.get('enabled', True) is not False and isinstance(command, str) and command and str(root / 'bridge.py') not in command:
            subprocess.run(['/bin/sh', '-c', command], input=raw, timeout=2, check=False)
    except Exception:
        pass
else:
    # Observational hooks do not change permissions, inject messages or prevent
    # termination. In particular no PreToolUse permission hook is installed.
    print('{}')
"""#
}
