import Foundation

protocol AntigravityExecutableLocating {
    func locate() throws -> URL
}

struct AntigravityExecutableLocator: AntigravityExecutableLocating {
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
        for candidate in candidates() where fileManager.isExecutableFile(
            atPath: candidate.path
        ) {
            return candidate
        }
        throw AntigravityUsageError.executableNotFound
    }

    private func candidates() -> [URL] {
        var candidates: [URL] = []
        for key in ["ANTIGRAVITY_EXECUTABLE", "AGY_EXECUTABLE"] {
            if let path = environment[key], !path.isEmpty {
                candidates.append(URL(fileURLWithPath: path))
            }
        }
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0), isDirectory: true)
                    .appendingPathComponent("agy")
            })
        }
        candidates.append(homeDirectory.appendingPathComponent(".local/bin/agy"))
        candidates.append(contentsOf: standardExecutableDirectories.map {
            $0.appendingPathComponent("agy")
        })

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

protocol AntigravityQuotaProviding {
    func fetchQuota(executableURL: URL) async throws -> AntigravityQuotaSnapshot
}

protocol AntigravityAuthenticationProviding {
    func signOut(executableURL: URL) async throws
}

struct AntigravityCLIUsageProvider: AntigravityQuotaProviding {
    private let processRunner: any InstallerProcessRunning
    private let environment: [String: String]
    private let now: @Sendable () -> Date

    init(
        processRunner: any InstallerProcessRunning =
            FoundationInstallerProcessRunner(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.processRunner = processRunner
        self.environment = environment
        self.now = now
    }

    func fetchQuota(executableURL: URL) async throws -> AntigravityQuotaSnapshot {
        let result = try await processRunner.run(
            executableURL: executableURL,
            arguments: [
                "-p", "/usage",
                "--output-format", "json",
                "--print-timeout", "30s"
            ],
            environment: AntigravityCLIEnvironment.make(
                base: environment,
                executableURL: executableURL
            ),
            timeout: 45
        )
        guard result.terminationStatus == 0 else {
            let normalized = result.output.lowercased()
            if normalized.contains("authentication required")
                || normalized.contains("not authenticated")
                || normalized.contains("sign in") {
                throw AntigravityUsageError.signedOut
            }
            throw AntigravityUsageError.commandFailed
        }

        return try AntigravityUsageResponseParser.parse(
            output: result.output,
            fetchedAt: now()
        )
    }
}

struct AntigravityCLIAuthenticationProvider:
    AntigravityAuthenticationProviding
{
    private let processRunner: any InstallerProcessRunning
    private let environment: [String: String]

    init(
        processRunner: any InstallerProcessRunning =
            FoundationInstallerProcessRunner(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.processRunner = processRunner
        self.environment = environment
    }

    func signOut(executableURL: URL) async throws {
        let result = try await processRunner.run(
            executableURL: executableURL,
            arguments: [
                "-p", "/logout",
                "--output-format", "json",
                "--print-timeout", "30s"
            ],
            environment: AntigravityCLIEnvironment.make(
                base: environment,
                executableURL: executableURL
            ),
            timeout: 45
        )
        try AntigravityAuthenticationResponseParser.validateSignOut(
            output: result.output,
            terminationStatus: result.terminationStatus
        )
    }
}

enum AntigravityAuthenticationResponseParser {
    private struct Envelope: Decodable {
        let status: String
    }

    static func validateSignOut(
        output: String,
        terminationStatus: Int32
    ) throws {
        if indicatesSignedOut(output) { return }
        guard terminationStatus == 0,
              let data = JSONEnvelopeExtractor.lastJSONObject(in: output),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.status.uppercased() == "SUCCESS" else {
            throw AntigravityUsageError.signOutFailed
        }
    }

    private static func indicatesSignedOut(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("authentication required")
            || normalized.contains("not authenticated")
            || normalized.contains("sign in first")
    }
}

private enum AntigravityCLIEnvironment {
    static func make(
        base: [String: String],
        executableURL: URL
    ) -> [String: String] {
        var result = base
        result["AGY_CLI_DISABLE_AUTO_UPDATE"] = "true"
        result["NO_COLOR"] = "1"
        let parent = executableURL.deletingLastPathComponent().path
        let existingPath = result["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        result["PATH"] = "\(parent):\(existingPath)"
        return result
    }
}

enum AntigravityUsageResponseParser {
    private struct Envelope: Decodable {
        let status: String
        let error: String?
        let command: Command?
    }

    private struct Command: Decodable {
        let name: String?
        let data: CommandData?
    }

    private struct CommandData: Decodable {
        let groups: [Group]?
    }

    private struct Group: Decodable {
        let name: String?
        let buckets: [Bucket]?
    }

    private struct Bucket: Decodable {
        let id: String?
        let name: String?
        let description: String?
        let window: String?
        let remainingFraction: Double?
        let resetTime: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case window
            case remainingFraction = "remaining_fraction"
            case resetTime = "reset_time"
        }
    }

    static func parse(output: String, fetchedAt: Date) throws
        -> AntigravityQuotaSnapshot {
        guard let data = JSONEnvelopeExtractor.lastJSONObject(in: output) else {
            throw AntigravityUsageError.invalidResponse
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw AntigravityUsageError.invalidResponse
        }
        guard envelope.status.uppercased() == "SUCCESS" else {
            let error = envelope.error?.lowercased() ?? ""
            if error.contains("authentication") || error.contains("sign in") {
                throw AntigravityUsageError.signedOut
            }
            throw AntigravityUsageError.commandFailed
        }
        guard envelope.command?.name?.lowercased() == "usage",
              let groups = envelope.command?.data?.groups else {
            throw AntigravityUsageError.unsupportedResponse
        }

        var parsed: [AntigravityQuotaBucket] = []
        var seen = Set<String>()
        for (groupIndex, group) in groups.prefix(20).enumerated() {
            let groupName = clean(group.name, fallback: "Model group \(groupIndex + 1)")
            for (bucketIndex, bucket) in (group.buckets ?? []).prefix(20)
                .enumerated() {
                guard let rawFraction = bucket.remainingFraction,
                      rawFraction.isFinite else {
                    continue
                }
                let baseID = clean(
                    bucket.id,
                    fallback: "group-\(groupIndex)-bucket-\(bucketIndex)"
                )
                let id = seen.insert(baseID).inserted
                    ? baseID
                    : "\(baseID)-\(bucketIndex)"
                parsed.append(AntigravityQuotaBucket(
                    id: id,
                    groupName: groupName,
                    title: clean(bucket.name, fallback: "Model quota"),
                    description: cleanOptional(bucket.description, limit: 320),
                    windowDurationMinutes: windowDuration(bucket.window),
                    remainingFraction: min(max(rawFraction, 0), 1),
                    resetsAt: parseDate(bucket.resetTime)
                ))
            }
        }
        guard !parsed.isEmpty else {
            throw AntigravityUsageError.unsupportedResponse
        }
        return AntigravityQuotaSnapshot(
            buckets: parsed,
            fetchedAt: fetchedAt,
            cliVersion: nil
        )
    }

    private static func windowDuration(_ value: String?) -> Int? {
        switch value?.lowercased() {
        case "weekly", "week", "7d": 10_080
        case "five_hour", "five-hour", "5h": 300
        default: nil
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func clean(
        _ value: String?,
        fallback: String,
        limit: Int = 120
    ) -> String {
        cleanOptional(value, limit: limit) ?? fallback
    }

    private static func cleanOptional(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let scalars = value.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        let cleaned = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(limit))
    }
}

private enum JSONEnvelopeExtractor {
    static func lastJSONObject(in output: String) -> Data? {
        for line in output.split(whereSeparator: { $0.isNewline }).reversed() {
            let candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidate.first == "{", candidate.last == "}",
                  let data = candidate.data(using: .utf8), data.count <= 1_000_000,
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                continue
            }
            return data
        }
        return nil
    }
}
