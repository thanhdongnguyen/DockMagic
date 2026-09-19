import Foundation

struct GrokBuildHistoryCache: Codable, Equatable, Sendable {
    struct Retry: Codable, Equatable, Sendable {
        let fingerprint: String
        let attempts: Int
        let retryAfter: Date
        var quarantined = false
    }
    var schemaVersion = 1
    var ledger: GrokBuildHistoryLedger
    /// Optional for decoding earlier experimental caches without losing data.
    var activity: GrokBuildActivityLedger?
    var fingerprints: [String: String] = [:]
    var retries: [String: Retry] = [:]
    var coverage = GrokBuildHistoryCoverage()
    var collectedAt: Date?
    var cliVersion: String?
    var calendarIdentifier: String?

    init(home: URL) { ledger = GrokBuildHistoryLedger(home: home) }
}

protocol GrokBuildHistoryCaching: Sendable {
    func load(home: URL) throws -> GrokBuildHistoryCache?
    func save(_ cache: GrokBuildHistoryCache) throws
}

/// Keep submissions ordered even across store cancellation/reconfiguration.
/// An atomic disk write already in progress cannot be cancelled; a subsequent
/// load must wait for it instead of restoring an older celebration claim.
final class GrokBuildHistoryPersistence: @unchecked Sendable {
    private let repository: any GrokBuildHistoryCaching
    private let queue = DispatchQueue(label: "com.hypevibe.DockMagic.grok-history", qos: .utility)

    init(repository: any GrokBuildHistoryCaching) { self.repository = repository }

    @MainActor
    func load(home: URL) async throws -> GrokBuildHistoryCache? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [repository] in
                continuation.resume(with: Result { try repository.load(home: home) })
            }
        }
    }

    @MainActor
    func save(_ cache: GrokBuildHistoryCache) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [repository] in
                continuation.resume(with: Result { try repository.save(cache) })
            }
        }
    }
}

/// Only DockMagic-owned, normalized local history is persisted. Account quota
/// is deliberately memory-only so restarting/switching accounts cannot bind a
/// cached account snapshot to this filesystem-scoped ledger.
struct GrokBuildHistoryCacheRepository: GrokBuildHistoryCaching {
    static let maximumBytes = 32 * 1_024 * 1_024
    let directory: URL

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DockMagic/GrokBuild", isDirectory: true)) {
        self.directory = directory.standardizedFileURL
    }

    func load(home: URL) throws -> GrokBuildHistoryCache? {
        let expected = GrokBuildHistoryLedger(home: home).namespace
        let url = directory.appendingPathComponent(expected + ".json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            try validateDirectory()
            let metadata = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard metadata.isRegularFile == true, metadata.isSymbolicLink != true,
                  let size = metadata.fileSize, size <= Self.maximumBytes else { throw GrokBuildError.cacheUnavailable }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
            guard data.count <= Self.maximumBytes else { throw GrokBuildError.cacheUnavailable }
            let value = try JSONDecoder().decode(GrokBuildHistoryCache.self, from: data)
            guard value.schemaVersion == 1, value.ledger.schemaVersion == 1,
                  value.ledger.namespace == expected, Self.isValid(value) else { throw GrokBuildError.cacheUnavailable }
            return value
        } catch { throw GrokBuildError.cacheUnavailable }
    }

    func save(_ cache: GrokBuildHistoryCache) throws {
        do {
            guard Self.isDigest(cache.ledger.namespace), Self.isValid(cache) else { throw GrokBuildError.cacheUnavailable }
            let manager = FileManager.default
            if !manager.fileExists(atPath: directory.path) {
                try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            }
            try validateDirectory()
            let destination = directory.appendingPathComponent(cache.ledger.namespace + ".json")
            if let properties = try? destination.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey]) {
                guard properties.isSymbolicLink != true, properties.isRegularFile == true else { throw GrokBuildError.cacheUnavailable }
            }
            let data = try JSONEncoder().encode(cache)
            guard data.count <= Self.maximumBytes else { throw GrokBuildError.cacheUnavailable }
            try data.write(to: destination, options: [.atomic])
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch { throw GrokBuildError.cacheUnavailable }
    }

    private func validateDirectory() throws {
        let metadata = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard metadata.isDirectory == true, metadata.isSymbolicLink != true,
              directory.resolvingSymlinksInPath() == directory else { throw GrokBuildError.cacheUnavailable }
    }

    private static func isDigest(_ string: String) -> Bool {
        string.count == 64 && string.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func isValid(_ cache: GrokBuildHistoryCache) -> Bool {
        guard cache.schemaVersion == 1, cache.ledger.schemaVersion == 1,
              cache.fingerprints.count <= 50_000, cache.retries.count <= 50_000,
              cache.fingerprints.keys.allSatisfy(isDigest), cache.retries.keys.allSatisfy(isDigest),
              cache.ledger.sessions.count <= 50_000,
              cache.ledger.sessions.keys.allSatisfy(isDigest),
              cache.retries.values.allSatisfy({ (1...10).contains($0.attempts) }),
              [cache.coverage.excludedSessions, cache.coverage.quarantinedSessions,
               cache.coverage.unavailableSources].allSatisfy({ $0 >= 0 }) else { return false }
        if let activity = cache.activity {
            guard activity.schemaVersion == 1, activity.namespace == cache.ledger.namespace,
                  activity.bestVerifiedDays >= 0, activity.bestVerifiedDays <= Int64(activity.witnesses.count),
                  activity.witnesses.keys.allSatisfy(isDigest),
                  activity.witnesses.isEmpty || activity.beganAt != nil,
                  activity.celebratedDays.allSatisfy({ $0.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil }),
                  (activity.pendingDay == nil) == (activity.pendingObservedAt == nil) else { return false }
        }
        func validCounts(_ counts: GrokBuildTokenCounts) -> Bool {
            let total = counts.input.addingReportingOverflow(counts.output)
            let cached = (counts.cacheRead ?? 0).addingReportingOverflow(counts.cacheWrite ?? 0)
            return counts.input >= 0 && counts.output >= 0 && !total.overflow && total.partialValue == counts.total
                && [counts.cacheRead, counts.cacheWrite, counts.reasoning].compactMap { $0 }.allSatisfy { $0 >= 0 }
                && !cached.overflow && cached.partialValue <= counts.input && (counts.reasoning ?? 0) <= counts.output
        }
        func fits(_ children: [GrokBuildTokenCounts], within parent: GrokBuildTokenCounts) -> Bool {
            var input: Int64 = 0
            var output: Int64 = 0
            for child in children {
                let nextInput = input.addingReportingOverflow(child.input)
                let nextOutput = output.addingReportingOverflow(child.output)
                guard validCounts(child), !nextInput.overflow, !nextOutput.overflow else { return false }
                input = nextInput.partialValue; output = nextOutput.partialValue
            }
            return input <= parent.input && output <= parent.output
        }
        return cache.ledger.sessions.values.allSatisfy { session in
            validCounts(session.total) && session.turns.count <= 100_000
                && Set(session.turns.map(\.number)).count == session.turns.count
                && fits(session.turns.map(\.tokens), within: session.total)
                && session.turns.allSatisfy { turn in
                    turn.number > 0 && turn.recordedAt <= session.sourceUpdatedAt
                        && validCounts(turn.tokens) && fits(Array(turn.models.values), within: turn.tokens)
                        && turn.models.keys.allSatisfy { model in
                            !model.isEmpty && model.utf8.count <= 256
                                && !model.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
                        }
                }
        }
    }
}
