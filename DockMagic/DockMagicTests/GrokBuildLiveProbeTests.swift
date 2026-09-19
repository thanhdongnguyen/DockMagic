import Foundation
import XCTest
@testable import DockMagic

/// Deliberately opt-in. A skipped probe is NOT release evidence. No session
/// or prompt is created. The auth-command audit uses only a disposable empty
/// home for logout; it does not log in or touch a user's account.
final class GrokBuildLiveProbeTests: XCTestCase {
    func testInstalledCLIAuthCommandsPreserveSyntheticHistoryAndWorktreeMarkers() async throws {
        guard ProcessInfo.processInfo.environment["GROK_PROBE_AUTH_COMMANDS"] == "1" else {
            throw XCTSkip("Opt in to auth command audit using a disposable unsigned home.")
        }
        let executable = try installedExecutable()
        let home = try temporaryDirectory(prefix: "grok-auth-command-probe")
        defer { try? FileManager.default.removeItem(at: home) }
        let pool = home.appendingPathComponent("worktree_pool/dead-owner/pool")
        let sessions = home.appendingPathComponent("sessions/synthetic")
        for directory in [pool, sessions] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("test-owned marker".utf8).write(to: directory.appendingPathComponent("marker"))
        }
        try Data("2147483647".utf8).write(to: pool.deletingLastPathComponent().appendingPathComponent(".pid"))
        let config = GrokBuildCLIConfiguration(executable: executable, home: home)
        let environment = config.environment(base: ["HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"])
        let runner = GrokBuildProcessRunner()
        let version = try await runner.run(.init(executable: executable, arguments: ["--version"],
                                                environment: environment, operation: .command))
        for arguments in [["login", "--help"], ["login", "--device-auth", "--help"], ["logout"]] {
            let result = try await runner.run(.init(executable: executable, arguments: arguments,
                                                    environment: environment, operation: .command, timeout: 15, maximumOutputBytes: 16_384))
            XCTAssertEqual(result.exitCode, 0)
            for directory in [pool, sessions] {
                XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("marker").path))
            }
        }
        try saveEvidence(report: ["probe": "auth-command-entrypoints", "cliVersion": try versionNumber(version.output),
            "passed": true, "accountKind": "unsigned-isolated-home", "realHomeTouched": false,
            "credentialsRead": false, "loginExecuted": false, "loginHelpExecuted": true,
            "emptyHomeLogoutExecuted": true, "historyAndStalePoolMarkersPreserved": true,
            "billingStarted": false, "releaseVerified": false,
            "observedAt": ISO8601DateFormatter().string(from: .now)],
            fixture: Data(#"{"browserCompletion":"not-tested","deviceCompletion":"not-tested"}"#.utf8))
    }
    /// Explicit user opt-in; never launches an agent or reads authentication.
    /// Uses the production discovery/parser/aggregator with an in-memory cache.
    func testInstalledCLIReadsAuthorizedRealLocalHistory() async throws {
        let executable = try installedExecutable()
        guard let path = ProcessInfo.processInfo.environment["GROK_PROBE_LOCAL_HOME"], path.hasPrefix("/") else {
            throw XCTSkip("Select the user-authorized real home with GROK_PROBE_LOCAL_HOME.")
        }
        let home = URL(fileURLWithPath: path, isDirectory: true)
        let configuration = GrokBuildCLIConfiguration(executable: executable, home: home)
        let runner = LocalHistoryAuditRunner(home: home)
        let cli = GrokBuildCLIProvider(runner: runner)
        let version = try await cli.version(configuration: configuration)
        let discovery = GrokBuildSessionDiscovery()
        let initial = try discovery.scan(home: home)
        let provider = GrokBuildLocalUsageProvider(cli: cli, discovery: discovery,
                                                 maximumCommandsPerScan: 100, maximumScanDuration: 30)
        let now = Date.now
        let calendar = Calendar.current
        let first = try await provider.collect(configuration: configuration, cache: .init(home: home),
                                               now: now, calendar: calendar)
        let firstCommands = await runner.usageCommands
        let second = try await provider.collect(configuration: configuration, cache: first.cache,
                                                now: now, calendar: calendar)
        let repeatedCommands = await runner.usageCommands - firstCommands
        // Exercise re-ingestion of actual CLI output as well as the unchanged
        // fingerprint/cache fast path. A cache-only repeat cannot prove this.
        let beforeForcedCommands = await runner.usageCommands
        let forced = try await provider.collect(configuration: configuration, cache: second.cache,
                                                now: now, calendar: calendar, force: true)
        let forcedCommands = await runner.usageCommands - beforeForcedCommands
        let final = try discovery.scan(home: home)
        let sourceSetStable = initial.sources == final.sources && !initial.limited && !final.limited
        let modelTotalsStable = second.snapshot.topModels.elementsEqual(forced.snapshot.topModels) {
            $0.model == $1.model && $0.tokens == $1.tokens
        }
        let eligibleDays = second.snapshot.days.filter { $0.tokens != nil }
        let total: Any = eligibleDays.isEmpty ? NSNull()
            : eligibleDays.reduce(Int64(0)) { GrokBuildNumbers.add($0, $1.tokens ?? 0) }
        if sourceSetStable && !first.snapshot.coverage.scanWasLimited {
            XCTAssertEqual(first.snapshot.days, second.snapshot.days, "Stable refresh changed daily totals")
            XCTAssertEqual(repeatedCommands, 0, "Stable cached sources should not rerun usage")
            XCTAssertEqual(second.snapshot.days, forced.snapshot.days, "Forced reread changed stable daily totals")
            XCTAssertTrue(modelTotalsStable, "Forced reread changed model totals")
            XCTAssertEqual(forcedCommands, final.sources.filter { $0.lineage.isUnambiguousRoot }.count)
        }
        let forcedRefreshVerified = sourceSetStable && forced.readableRootCount > 0
            && forced.snapshot.coverage.unavailableSources == 0
            && forced.snapshot.coverage.quarantinedSessions == 0
            && !forced.snapshot.coverage.scanWasLimited
            && second.snapshot.days == forced.snapshot.days
            && modelTotalsStable
        XCTAssertEqual(second.snapshot.days.count, 30)
        XCTAssertLessThanOrEqual(second.snapshot.topModels.count, 3)
        let formatter = ISO8601DateFormatter()
        let days: [[String: Any]] = second.snapshot.days.map { day in
            ["startUTC": formatter.string(from: day.startDate),
             "tokens": day.tokens.map { $0 as Any } ?? NSNull(),
             "modelCoverageIsPartial": day.modelCoverageIsPartial]
        }
        let report: [String: Any] = [
            "probe": "authorized-real-local-history", "auditCompleted": true, "releaseVerified": false,
            "fixtureOrigin": "real-local-normalized", "cliVersion": version,
            "observedAt": formatter.string(from: now), "timeZone": calendar.timeZone.identifier,
            "discoveredSessions": final.sources.count, "readableRoots": second.readableRootCount,
            "excludedSessions": second.snapshot.coverage.excludedSessions,
            "unavailableSources": second.snapshot.coverage.unavailableSources,
            "quarantinedSessions": second.snapshot.coverage.quarantinedSessions,
            "scanWasLimited": second.snapshot.coverage.scanWasLimited, "sourceSetStable": sourceSetStable,
            "initialUsageCommands": firstCommands, "repeatUsageCommands": repeatedCommands,
            "forcedUsageCommands": forcedCommands, "forcedRefreshVerified": forcedRefreshVerified,
            "forcedReadableRoots": forced.readableRootCount,
            "forcedUnavailableSources": forced.snapshot.coverage.unavailableSources,
            "forcedQuarantinedSessions": forced.snapshot.coverage.quarantinedSessions,
            "observedDays": eligibleDays.count, "unknownDays": second.snapshot.days.count - eligibleDays.count,
            "tokensObservedInWindow": total, "isPartial": second.snapshot.coverage.isPartial,
            "agentStarted": false, "credentialsRead": false, "sessionRequestsSent": 0, "promptsSent": 0,
        ]
        let fixture: [String: Any] = ["days": days,
            "topModels": second.snapshot.topModels.map { ["model": $0.model, "tokens": $0.tokens] as [String: Any] }]
        try saveEvidence(report: report, fixture: JSONSerialization.data(withJSONObject: fixture, options: [.sortedKeys, .prettyPrinted]))
    }

    func testInstalledCLIReadsSyntheticLocalUsageWithoutAuthentication() async throws {
        let executable = try installedExecutable()
        let home = try temporaryDirectory(prefix: "grok-unsigned-probe")
        defer { try? FileManager.default.removeItem(at: home) }
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let session = home.appendingPathComponent("sessions/probe/\(id.uuidString.lowercased())")
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: session.appendingPathComponent("summary.json"))
        let fixture = Data("""
        {"sessionId":"\(id.uuidString.lowercased())","updatedAt":"2026-09-16T12:00:00Z",
         "session":{"inputTokens":100,"outputTokens":20,"totalTokens":120},
         "turns":[{"turnNumber":1,"endedAt":"2026-09-16T12:00:00Z",
         "inputTokens":100,"outputTokens":20,"totalTokens":120}]}
        """.utf8)
        try fixture.write(to: session.appendingPathComponent("usage.json"))

        // A fresh HOME/GROK_HOME plus an environment allowlist, not an edit to
        // the user's credentials. No API key, external-auth command or token
        // is inherited into this unsigned local probe.
        let configuration = GrokBuildCLIConfiguration(executable: executable, home: home)
        let environment = configuration.environment(base: [
            "HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8",
        ])
        let runner = GrokBuildProcessRunner()
        let version = try await runner.run(.init(executable: executable, arguments: ["--version"],
            environment: environment, operation: .command, timeout: 10, maximumOutputBytes: 4_096))
        XCTAssertEqual(version.exitCode, 0)
        let result = try await runner.run(.init(executable: executable,
            arguments: ["usage", id.uuidString.lowercased()], environment: environment, operation: .command))
        XCTAssertEqual(result.exitCode, 0)
        let parsed = try GrokBuildUsageParser.parse(result.output, expectedID: id)
        XCTAssertEqual(parsed.total.total, 120)
        XCTAssertEqual(parsed.turns.count, 1)
        // All usage fields are synthetic. Do not save unfiltered CLI output.
        let report: [String: Any] = ["probe": "local-usage-with-empty-home", "passed": true,
            "cliVersion": try versionNumber(version.output), "fixtureOrigin": "synthetic",
            "accountKind": "unsigned-isolated-home", "observedAt": ISO8601DateFormatter().string(from: .now)]
        try saveEvidence(report: report, fixture: fixture)
    }

    func testInstalledCLIReportsSignedOutBillingWithEmptyHome() async throws {
        let executable = try installedExecutable()
        let home = try temporaryDirectory(prefix: "grok-unsigned-billing-probe")
        defer { try? FileManager.default.removeItem(at: home) }
        let configuration = GrokBuildCLIConfiguration(executable: executable, home: home)
        let environment = configuration.environment(base: [
            "HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8",
        ])
        let runner = GrokBuildProcessRunner()
        let version = try await runner.run(.init(executable: executable, arguments: ["--version"],
            environment: environment, operation: .command, timeout: 10, maximumOutputBytes: 4_096))
        let started = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await runner.run(.init(executable: executable, arguments: ["agent", "--no-leader", "stdio"],
                environment: environment, operation: .billing, timeout: 45, maximumOutputBytes: 512 * 1_024))
            XCTFail("An isolated unauthenticated home must not return connected account billing")
            return
        } catch GrokBuildError.authenticationRequired {
            // Only the exact first-party authentication diagnostic is proof.
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        XCTAssertLessThan(elapsed, 50)
        let report: [String: Any] = ["probe": "initialize-and-billing-signed-out", "passed": true,
            "cliVersion": try versionNumber(version.output), "accountKind": "unsigned-isolated-home",
            "durationSeconds": elapsed, "releaseVerified": false,
            "observedAt": ISO8601DateFormatter().string(from: .now),
            "remainingReview": ["signed-in-billing", "startup-side-effects", "detached-descendant-cleanup"]]
        try saveEvidence(report: report, fixture: Data(#"{"expectedError":"authenticationRequired"}"#.utf8))
    }

    func testInstalledCLIAccountBillingWithoutCreatingSession() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["GROK_PROBE_BILLING"] == "1" else {
            throw XCTSkip("Set GROK_PROBE_BILLING=1 to authorize the account billing probe.")
        }
        guard GrokBuildFeatureGate.billingStartupSafetyVerified else {
            throw XCTSkip("Billing startup safety is blocked: initialize can delete stale worktree pool data. Do not probe a real Grok home yet.")
        }
        let executable = try installedExecutable()
        guard let homePath = environment["GROK_PROBE_BILLING_HOME"], homePath.hasPrefix("/"),
              let accountKind = environment["GROK_PROBE_ACCOUNT_KIND"],
              ["consumer", "api-key", "sso", "other"].contains(accountKind) else {
            throw XCTSkip("Supply an absolute GROK_PROBE_BILLING_HOME and non-identifying GROK_PROBE_ACCOUNT_KIND.")
        }
        let home = URL(fileURLWithPath: homePath, isDirectory: true)
        guard (try? home.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            throw GrokBuildError.invalidHome
        }
        let configuration = GrokBuildCLIConfiguration(executable: executable, home: home)
        let version = try await GrokBuildCLIProvider().version(configuration: configuration)
        let started = ProcessInfo.processInfo.systemUptime
        let response = try await GrokBuildProcessRunner().run(.init(executable: executable,
            arguments: ["agent", "--no-leader", "stdio"], environment: configuration.environment(),
            operation: .billing, timeout: 45, maximumOutputBytes: 512 * 1_024))
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let quota = try GrokBuildBillingParser.parse(response.output, observedAt: .now)
        XCTAssertTrue((0...100).contains(quota.usedPercent))
        XCTAssertLessThan(elapsed, 55)
        let report: [String: Any] = ["probe": "initialize-and-billing-only", "parsed": true,
            "cliVersion": version, "accountKind": accountKind, "durationSeconds": elapsed,
            "observedAt": ISO8601DateFormatter().string(from: .now),
            "releaseVerified": false,
            "remainingReview": ["startup-side-effects", "descendant-cleanup", "account-UI-cross-check"]]
        try saveEvidence(report: report, fixture: sanitizedBilling(response.output))
    }

    /// Destructive-startup audit ONLY in fresh, test-owned homes. A passing
    /// test means the audit ran, not that startup is safe for a user's home.
    func testInstalledCLIStartupSideEffectsInSyntheticHomes() async throws {
        let executable = try installedExecutable()
        var cases: [[String: Any]] = []
        for disableAutoGC in [false, true] {
            let home = try temporaryDirectory(prefix: "grok-startup-audit")
            defer { try? FileManager.default.removeItem(at: home) }
            let deadPool = home.appendingPathComponent("worktree_pool/synthetic-dead/pool")
            let livePool = home.appendingPathComponent("worktree_pool/synthetic-live/pool")
            for directory in [deadPool, livePool] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try Data("synthetic audit marker, not user data".utf8)
                    .write(to: directory.appendingPathComponent("marker.txt"))
            }
            try Data("4000000000".utf8).write(to: deadPool.deletingLastPathComponent().appendingPathComponent(".pid"))
            try Data(String(ProcessInfo.processInfo.processIdentifier).utf8)
                .write(to: livePool.deletingLastPathComponent().appendingPathComponent(".pid"))
            let configuration = GrokBuildCLIConfiguration(executable: executable, home: home)
            var environment = configuration.environment(base: [
                "HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8",
            ])
            if disableAutoGC { environment["GROK_WORKTREE_AUTO_GC"] = "0" }
            let runner = GrokBuildProcessRunner()
            let version = try await runner.run(.init(executable: executable, arguments: ["--version"],
                environment: environment, operation: .command, timeout: 10, maximumOutputBytes: 4_096))
            let before = try syntheticInventory(home)
            let started = ProcessInfo.processInfo.systemUptime
            do {
                _ = try await runner.run(.init(executable: executable, arguments: ["agent", "--no-leader", "stdio"],
                    environment: environment, operation: .billing, timeout: 45, maximumOutputBytes: 512 * 1_024))
                XCTFail("Synthetic unsigned home unexpectedly returned billing")
                return
            } catch GrokBuildError.authenticationRequired { }
            let after = try syntheticInventory(home)
            let livePreserved = FileManager.default.fileExists(atPath: livePool.appendingPathComponent("marker.txt").path)
            XCTAssertTrue(livePreserved, "CLI startup removed a synthetic live-owner marker")
            // A session-search index directory is not a created conversation.
            let sessionLedgers = after.filter {
                $0.hasPrefix("sessions/") && ($0.hasSuffix("/summary.json")
                    || $0.hasSuffix("/usage.json") || $0.hasSuffix(".jsonl"))
            }
            XCTAssertTrue(sessionLedgers.isEmpty, "The billing-only probe created session records")
            cases.append([
                "cliVersion": try versionNumber(version.output), "autoGCEnvironmentDisabled": disableAutoGC,
                "durationSeconds": ProcessInfo.processInfo.systemUptime - started,
                "deadPoolMarkerRemoved": !FileManager.default.fileExists(atPath: deadPool.appendingPathComponent("marker.txt").path),
                "livePoolMarkerPreserved": livePreserved,
                "sessionLedgerCount": sessionLedgers.count,
                "addedPaths": Array(after.subtracting(before)).sorted(),
                "removedPaths": Array(before.subtracting(after)).sorted(),
            ])
        }
        let report: [String: Any] = [
            "probe": "billing-startup-side-effects", "auditCompleted": true, "releaseVerified": false,
            "accountKind": "unsigned-isolated-home", "fixtureOrigin": "synthetic-markers-only",
            "observedAt": ISO8601DateFormatter().string(from: .now), "cases": cases,
            "scope": "Metadata only inside test-owned homes; no file content or credentials read",
            "remainingReview": ["signed-in-billing", "configured-home-startup-safety", "detached-descendant-cleanup"],
        ]
        try saveEvidence(report: report, fixture: Data(#"{"sessionRequestsSent":0,"promptsSent":0}"#.utf8))
    }

    /// Opt-in candidate audit, never a production profile or safety override.
    /// Keep the home outside temp paths: those are writable even under strict.
    func testInstalledCLISandboxCandidatesInSyntheticHomes() async throws {
        let executable = try installedExecutable()
        guard let parentPath = ProcessInfo.processInfo.environment["GROK_PROBE_SANDBOX_PARENT"],
              parentPath.hasPrefix("/") else {
            throw XCTSkip("Select a test-output parent outside OS temp grants with GROK_PROBE_SANDBOX_PARENT.")
        }
        let parent = URL(fileURLWithPath: parentPath, isDirectory: true).resolvingSymlinksInPath()
        guard (try? parent.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
              parent.path != "/", parent.path != NSHomeDirectory(),
              !["/tmp", "/private/tmp", "/var/tmp", "/private/var/tmp", "/var/folders", "/private/var/folders"]
                .contains(where: { parent.path == $0 || parent.path.hasPrefix($0 + "/") }) else {
            throw GrokBuildError.invalidHome
        }
        var cases: [[String: Any]] = []
        // Off is the isolated control, never an acceptable production fallback.
        for profile in ["off", "read-only", "strict", "dockmagic-audit"] {
            let root = parent.appendingPathComponent("grok-sandbox-audit-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: root) }
            let home = root.appendingPathComponent("home", isDirectory: true)
            let workspace = root.appendingPathComponent("empty-workspace", isDirectory: true)
            let deadPool = home.appendingPathComponent("worktree_pool/synthetic-dead/pool")
            for directory in [workspace, deadPool] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let marker = deadPool.appendingPathComponent("marker.txt")
            try Data("synthetic sandbox audit marker".utf8).write(to: marker)
            try Data("4000000000".utf8).write(to: deadPool.deletingLastPathComponent().appendingPathComponent(".pid"))
            if profile == "dockmagic-audit" {
                // A documented custom profile, only in this fresh fake home.
                // TOML basic strings do not accept JSON's optional \/ escape.
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.withoutEscapingSlashes]
                let pathLiteral = String(decoding: try encoder.encode(home.appendingPathComponent("worktree_pool").path), as: UTF8.self)
                let config = "[profiles.dockmagic-audit]\nextends = \"strict\"\ndeny = [\(pathLiteral)]\n"
                try Data(config.utf8).write(to: home.appendingPathComponent("sandbox.toml"))
            }
            let environment = GrokBuildCLIConfiguration(executable: executable, home: home).environment(base: [
                "HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8",
                "GROK_WORKTREE_AUTO_GC": "0",
            ])
            let runner = GrokBuildProcessRunner()
            let version = try await runner.run(.init(executable: executable, arguments: ["--version"],
                environment: environment, operation: .command, timeout: 10, maximumOutputBytes: 4_096))
            let before = try syntheticInventory(home)
            let started = ProcessInfo.processInfo.systemUptime
            let outcome: String
            do {
                _ = try await runner.run(.init(executable: executable,
                    arguments: ["--cwd", workspace.path, "--sandbox", profile, "agent", "--no-leader", "stdio"],
                    environment: environment, operation: .billing, timeout: 20, maximumOutputBytes: 512 * 1_024))
                outcome = "unexpectedBilling"
                XCTFail("Synthetic unsigned home unexpectedly returned billing")
            } catch GrokBuildError.authenticationRequired {
                outcome = "authenticationRequired"
            } catch GrokBuildError.protocolError {
                outcome = "protocolErrorOrStartupExit"
            } catch GrokBuildError.timedOut {
                outcome = "timedOut"
            }
            if profile == "off" {
                XCTAssertEqual(outcome, "authenticationRequired", "Control must reach the billing auth gate")
            }
            var startupDiagnosticCategories: [String] = []
            var syntheticStartupFailure: String?
            if outcome == "protocolErrorOrStartupExit" {
                // Diagnostic rerun only in the same unsigned test-owned home.
                // A fixed shell redirect merges stderr into the bounded runner
                // buffer; arguments remain literal and no raw text is retained.
                let diagnostic = try await runner.run(.init(executable: URL(fileURLWithPath: "/bin/sh"),
                    arguments: ["-c", #"exec "$@" 2>&1"#, "grok-audit", executable.path,
                                "--cwd", workspace.path, "--sandbox", profile, "agent", "--no-leader", "stdio"],
                    environment: environment, operation: .command, timeout: 20, maximumOutputBytes: 512 * 1_024))
                let text = String(decoding: diagnostic.output, as: UTF8.self).lowercased()
                // Only the fixed sandbox-application diagnostic in a fake,
                // unsigned home; no arbitrary CLI log lines are retained.
                if let line = String(decoding: diagnostic.output, as: UTF8.self)
                    .split(separator: "\n").first(where: { $0.contains("warning: sandbox could not be applied:") }) {
                    syntheticStartupFailure = String(line.prefix(512))
                        .replacingOccurrences(of: root.path, with: "<synthetic-root>")
                        .replacingOccurrences(of: executable.path, with: "<executable>")
                }
                for (needle, category) in [
                    ("sandbox could not be applied", "sandboxApplyFailed"),
                    ("could not apply", "applyFailed"),
                    ("operation not permitted", "operationNotPermitted"),
                    ("permission denied", "permissionDenied"),
                    ("unexpected argument", "argumentRejected"),
                    ("invalid escape", "invalidConfigurationEscape"),
                    ("custom sandbox profile", "customProfileDiagnostic"),
                    ("refusing to start", "startupRefused"),
                    ("sandbox is not supported", "sandboxUnsupported"),
                    ("failed to initialize", "initializationFailed"),
                ] where text.contains(needle) {
                    startupDiagnosticCategories.append(category)
                }
                if startupDiagnosticCategories.isEmpty { startupDiagnosticCategories = ["unclassified"] }
            }
            let after = try syntheticInventory(home)
            let sessionLedgers = after.filter {
                $0.hasPrefix("sessions/") && ($0.hasSuffix("/summary.json")
                    || $0.hasSuffix("/usage.json") || ($0.hasSuffix(".jsonl") && !$0.hasSuffix("sandbox-events.jsonl")))
            }
            XCTAssertTrue(sessionLedgers.isEmpty, "Sandbox billing-only probe created session records")
            cases.append([
                "profile": profile, "cliVersion": try versionNumber(version.output), "outcome": outcome,
                "startupDiagnosticCategories": startupDiagnosticCategories,
                "syntheticStartupFailure": syntheticStartupFailure.map { $0 as Any } ?? NSNull(),
                "inventoryIncludesDiagnosticRerun": outcome == "protocolErrorOrStartupExit",
                "homeOutsideTempGrants": true, "workspaceIsSeparateEmptyDirectory": true,
                "durationSeconds": ProcessInfo.processInfo.systemUptime - started,
                "deadPoolMarkerRemoved": !FileManager.default.fileExists(atPath: marker.path),
                "sessionLedgerCount": sessionLedgers.count,
                "addedPaths": Array(after.subtracting(before)).sorted(),
                "removedPaths": Array(before.subtracting(after)).sorted(),
            ])
        }
        try saveEvidence(report: [
            "probe": "billing-sandbox-candidates", "auditCompleted": true, "releaseVerified": false,
            "accountKind": "unsigned-isolated-home", "fixtureOrigin": "synthetic-markers-only",
            "observedAt": ISO8601DateFormatter().string(from: .now), "cases": cases,
            "remainingReview": ["all-startup-side-effects", "sandbox-enforcement-fail-closed", "signed-in-billing", "detached-descendant-cleanup"],
        ], fixture: Data(#"{"sessionRequestsSent":0,"promptsSent":0,"realHomeTouched":false}"#.utf8))
    }

    private func syntheticInventory(_ home: URL) throws -> Set<String> {
        let root = home.resolvingSymlinksInPath()
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            throw GrokBuildError.invalidHome
        }
        var paths = Set<String>()
        for case let item as URL in enumerator {
            guard paths.count < 2_000 else { throw GrokBuildError.outputTooLarge }
            let values = try item.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true { enumerator.skipDescendants() }
            let canonical = item.deletingLastPathComponent().resolvingSymlinksInPath()
                .appendingPathComponent(item.lastPathComponent).standardizedFileURL
            guard canonical.path.hasPrefix(root.path + "/") else { throw GrokBuildError.unsafeSource }
            let path = canonical.pathComponents.dropFirst(root.pathComponents.count).joined(separator: "/")
                .replacingOccurrences(of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
                                      with: "<generated-id>", options: .regularExpression)
            paths.insert(path + (values.isDirectory == true ? "/" : ""))
        }
        return paths
    }

    private func installedExecutable() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["GROK_PROBE_EXECUTABLE"],
              path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else {
            throw XCTSkip("No installed CLI selected. Set GROK_PROBE_EXECUTABLE to its absolute path.")
        }
        return URL(fileURLWithPath: path)
    }

    private func versionNumber(_ data: Data) throws -> String {
        let string = String(decoding: data, as: UTF8.self)
        guard let range = string.range(of: #"\b\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?\b"#, options: .regularExpression) else {
            throw GrokBuildError.unsupportedSchema
        }
        return String(string[range])
    }

    private func sanitizedBilling(_ data: Data) throws -> Data {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = object["config"] as? [String: Any] else { throw GrokBuildError.invalidResponse }
        var allowedConfig: [String: Any] = [:]
        // Copy numeric/bool fields only. Never capture arbitrary nested objects,
        // account identifiers, monetary history, diagnostic text or secrets.
        for key in ["creditUsagePercent", "isUnifiedBillingUser"] {
            if let number = config[key] as? NSNumber { allowedConfig[key] = number }
        }
        for key in ["monthlyLimit", "used"] {
            if let cent = config[key] as? [String: Any] {
                allowedConfig[key] = (cent["val"] as? NSNumber).map { ["val": $0] } ?? [:]
            }
        }
        if let period = config["currentPeriod"] as? [String: Any] {
            var allowedPeriod: [String: String] = [:]
            if let type = period["type"] as? String,
               ["USAGE_PERIOD_TYPE_WEEKLY", "USAGE_PERIOD_TYPE_MONTHLY"].contains(type) {
                allowedPeriod["type"] = type
            }
            for key in ["start", "end"] {
                if let value = period[key] as? String, GrokBuildDates.parse(value) != nil { allowedPeriod[key] = value }
            }
            allowedConfig["currentPeriod"] = allowedPeriod
        }
        for key in ["billingPeriodStart", "billingPeriodEnd"] {
            if let value = config[key] as? String, GrokBuildDates.parse(value) != nil { allowedConfig[key] = value }
        }
        var allowed: [String: Any] = ["config": allowedConfig]
        if object["subscription_tier"] is String { allowed["subscription_tier"] = "REDACTED_PLAN" }
        if let enabled = object["on_demand_enabled"] as? Bool { allowed["on_demand_enabled"] = enabled }
        return try JSONSerialization.data(withJSONObject: allowed, options: [.prettyPrinted, .sortedKeys])
    }

    private func temporaryDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        return url
    }

    private func saveEvidence(report: [String: Any], fixture: Data) throws {
        let directory = try temporaryDirectory(prefix: "grok-live-evidence")
        let files = [("report.json", try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])),
                     ("fixture.json", fixture)]
        for (name, bytes) in files {
            let url = directory.appendingPathComponent(name)
            try bytes.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        print("Sanitized Grok probe evidence (review before committing): \(directory.path)")
    }
}

/// This real-home test cannot accidentally reach the unsafe ACP startup route.
/// Authentication-related environment is not inherited; local usage needs none.
private actor LocalHistoryAuditRunner: GrokBuildProcessRunning {
    let home: URL
    private(set) var usageCommands = 0
    init(home: URL) { self.home = home }

    func run(_ request: GrokBuildProcessRequest) async throws -> GrokBuildProcessResult {
        let usage = request.arguments.count == 2 && request.arguments.first == "usage"
            && UUID(uuidString: request.arguments[1]) != nil
        guard request.operation == .command, request.arguments == ["--version"] || usage else {
            throw GrokBuildError.unsafeSource
        }
        if usage { usageCommands += 1 }
        let safeEnvironment = GrokBuildCLIConfiguration(executable: request.executable, home: home).environment(base: [
            "HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8",
        ])
        return try await GrokBuildProcessRunner().run(.init(executable: request.executable, arguments: request.arguments,
            environment: safeEnvironment, operation: .command, timeout: request.timeout,
            maximumOutputBytes: request.maximumOutputBytes))
    }
}
