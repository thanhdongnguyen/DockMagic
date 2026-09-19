import Foundation

struct GrokBuildSettings: Codable, Equatable, Sendable {
    enum Metric: String, Codable, CaseIterable, Identifiable {
        case quota, tokensToday
        var id: Self { self }
        var title: String { self == .quota ? "Quota remaining" : "Tokens observed today" }
    }
    enum Style: String, Codable, CaseIterable, Identifiable {
        case number, ring
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    var enabled = false
    var monitoring = true
    var executablePath = ""
    var homePath = ""
    var metric: Metric = .quota
    var style: Style = .number

    func configuration(userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> GrokBuildCLIConfiguration {
        let home = homePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [userHome.appendingPathComponent(".grok/bin/grok"),
                          userHome.appendingPathComponent(".local/bin/grok"),
                          URL(fileURLWithPath: "/opt/homebrew/bin/grok"), URL(fileURLWithPath: "/usr/local/bin/grok")]
        let resolved = candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) } ?? candidates[0]
        return .init(executable: executable.isEmpty ? resolved : URL(fileURLWithPath: (executable as NSString).expandingTildeInPath),
                     home: home.isEmpty ? userHome.appendingPathComponent(".grok") : URL(fileURLWithPath: (home as NSString).expandingTildeInPath))
    }
}

/// Explicit experimental allowlist. Quota is an unavailable explanation, never
/// a window or a value inferred from a screenshot/local token usage.
enum GrokBuildDashboardManifest {
    enum Module: String, CaseIterable {
        case identity, officialLink, quotaUnavailable, dailyTokens, continuity, badges, shipMomentum, dailyIntensity, topModels
    }
    enum Source: String { case localUsage, activityLedger, startupSafetyGate, officialWebsite }
    struct Entry { let module: Module; let source: Source }
    static let entries: [Entry] = [
        .init(module: .identity, source: .localUsage), .init(module: .officialLink, source: .officialWebsite),
        .init(module: .quotaUnavailable, source: .startupSafetyGate), .init(module: .dailyTokens, source: .localUsage),
        .init(module: .continuity, source: .activityLedger), .init(module: .badges, source: .activityLedger),
        .init(module: .shipMomentum, source: .localUsage), .init(module: .dailyIntensity, source: .localUsage),
        .init(module: .topModels, source: .localUsage)
    ]
    static func supports(_ module: Module) -> Bool { entries.contains { $0.module == module } }
    static let coverageNote = "Tokens observed locally from eligible root sessions. Forks, copies, subagents and ambiguous sources are excluded. Missing days are unknown, not zero."
    static let quotaNote = "Quota unavailable: automatic billing checks are blocked until Grok startup is verified safe. This does not mean you are signed out."
}
