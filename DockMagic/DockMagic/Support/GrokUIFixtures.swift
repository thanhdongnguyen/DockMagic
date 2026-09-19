#if DEBUG
import Foundation

/// Selected only inside the existing UI-testing composition. No CLI, home
/// discovery, credential access or disk-backed Grok cache is used here.
enum GrokUIFixtures {
    @MainActor
    static func store(mode: String, preferences: DockPreferencesStore) -> GrokBuildUsageStore {
        preferences.grokBuildSettings.monitoring = false
        preferences.grokBuildSettings.executablePath = "/fixture/grok"
        preferences.grokBuildSettings.homePath = "/fixture/grok-home"
        let auth = GrokBuildAuthenticationController(runner: Authentication(mode: mode),
            supportedVersions: mode.hasPrefix("auth-") ? ["1.0.30-fixture"] : [])
        return GrokBuildUsageStore(cli: FixtureCLI(), collector: Collector(mode: mode),
            repository: Cache(), monitor: Monitor(), authentication: auth)
    }

    private struct FixtureCLI: GrokBuildCLIProviding {
        func version(configuration: GrokBuildCLIConfiguration) async throws -> String { "1.0.30-fixture" }
        func usage(id: UUID, configuration: GrokBuildCLIConfiguration) async throws -> GrokBuildSessionUsage { throw GrokBuildError.commandFailed }
        func billing(configuration: GrokBuildCLIConfiguration, observedAt: Date) async throws -> GrokBuildQuotaSnapshot { throw GrokBuildError.billingStartupUnverified }
        func signOut(configuration: GrokBuildCLIConfiguration) async throws {
            try await Task.sleep(for: .milliseconds(300))
            throw GrokBuildError.signOutUnverified
        }
    }

    private struct Authentication: GrokBuildAuthenticationRunning {
        let mode: String
        func signIn(configuration: GrokBuildCLIConfiguration, deviceCode: Bool,
                    onOutput: @escaping @Sendable (Data) -> Void) async throws -> Int32 {
            onOutput(Data("Synthetic \(deviceCode ? "device-code" : "browser") sign-in. No real account is used.\r\n".utf8))
            try await Task.sleep(for: mode == "auth-cancel" ? .seconds(30) : .seconds(1))
            if mode == "auth-timeout" { throw GrokBuildError.timedOut }
            if mode == "auth-failed" { return 1 }
            return 0
        }
    }

    private actor Collector: GrokBuildLocalCollecting {
        let mode: String
        private var calls = 0
        init(mode: String) { self.mode = mode }

        func collect(configuration: GrokBuildCLIConfiguration, cache: GrokBuildHistoryCache, now: Date,
                     calendar: Calendar, force: Bool) async throws -> GrokBuildLocalCollection {
            calls += 1
            if mode == "loading" { try await Task.sleep(for: .seconds(30)) }
            if mode == "error" || (mode == "stale" && calls > 1) { throw GrokBuildError.commandFailed }
            var result = cache
            var activity = result.activity ?? .importing(result.ledger, at: now, calendar: calendar)
            activity.beginObservation(at: now, calendar: calendar)
            if mode != "empty" {
                let id = UUID(uuidString: "00000000-0000-0000-0000-000000000321")!
                let lineage = try JSONDecoder().decode(GrokBuildLineage.self, from: Data("{\"info\":{\"id\":\"\(id.uuidString)\"}}".utf8))
                let counts = GrokBuildTokenCounts(input: 35_879, output: 108, total: 35_987, cacheRead: 6_144, cacheWrite: nil, reasoning: 54)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                let recordedAt = mode == "celebration" && calls == 1 ? yesterday : now
                let usage = GrokBuildSessionUsage(id: id, sourceUpdatedAt: now, total: counts,
                    turns: [.init(number: 1, recordedAt: recordedAt, tokens: counts,
                        models: ["fixture-grok": counts], upstreamIncomplete: false)])
                _ = result.ledger.ingest(usage, lineage: lineage, observedAt: now, calendar: calendar)
                activity.recordAccepted(usage, lineage: lineage, at: now, calendar: calendar)
            }
            activity.finishObservation(at: now, calendar: calendar)
            result.activity = activity
            result.collectedAt = now
            return .init(cache: result, snapshot: result.ledger.snapshot(now: now, calendar: calendar), readableRootCount: mode == "empty" ? 0 : 1)
        }
    }

    private struct Cache: GrokBuildHistoryCaching {
        func load(home: URL) throws -> GrokBuildHistoryCache? { nil }
        func save(_ cache: GrokBuildHistoryCache) throws {}
    }
    private final class Monitor: GrokBuildFileMonitoring, @unchecked Sendable {
        func start(home: URL, onChange: @escaping @Sendable () -> Void) -> Bool { false }
        func stop() {}
    }
}
#endif
