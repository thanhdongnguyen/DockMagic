import Foundation

struct GrokBuildSessionSource: Equatable, Sendable {
    let id: UUID
    let directory: URL
    let lineage: GrokBuildLineage
    let fingerprint: String
}

struct GrokBuildDiscoveryResult: Sendable {
    let sources: [GrokBuildSessionSource]
    let excludedCount: Int
    let limited: Bool
}

/// Metadata only: file bytes may contain additional fields, but only lineage
/// fields are decoded, returned or retained. Never opens transcript files.
protocol GrokBuildSessionDiscovering: Sendable {
    func scan(home: URL) throws -> GrokBuildDiscoveryResult
    func fingerprint(directory: URL) throws -> String
}

struct GrokBuildSessionDiscovery: GrokBuildSessionDiscovering {
    let maximumEntries: Int
    let maximumSummaryBytes: Int
    init(maximumEntries: Int = 50_000, maximumSummaryBytes: Int = 1_024 * 1_024) {
        self.maximumEntries = maximumEntries
        self.maximumSummaryBytes = maximumSummaryBytes
    }

    func scan(home: URL) throws -> GrokBuildDiscoveryResult {
        let manager = FileManager.default
        let home = home.standardizedFileURL.resolvingSymlinksInPath()
        let root = home.appendingPathComponent("sessions", isDirectory: true)
        guard (try? home.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
              manager.isReadableFile(atPath: home.path) else { throw GrokBuildError.invalidHome }
        guard manager.fileExists(atPath: root.path) else {
            return .init(sources: [], excludedCount: 0, limited: false)
        }
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw GrokBuildError.unsafeSource
        }
        var scanFailed = false
        guard let iterator = manager.enumerator(
            at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey],
            options: [.skipsHiddenFiles], errorHandler: { _, _ in scanFailed = true; return true }
        ) else { throw GrokBuildError.invalidHome }
        var sources: [GrokBuildSessionSource] = []
        var excluded = 0
        var entries = 0
        var limited = false
        for case let url as URL in iterator {
            try Task.checkCancellation()
            entries += 1
            if entries > maximumEntries { limited = true; break }
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            if values?.isSymbolicLink == true { iterator.skipDescendants(); excluded += 1; continue }
            guard url.lastPathComponent == "usage.json", values?.isRegularFile == true else { continue }
            do {
                let directory = url.deletingLastPathComponent()
                // Match the CLI resolver's exact sessions/<cwd>/<id> layout.
                // Nested backup/export folders must not enter the same scope.
                guard directory.deletingLastPathComponent().deletingLastPathComponent() == root,
                      let id = UUID(uuidString: directory.lastPathComponent) else { throw GrokBuildError.unsafeSource }
                let summary = directory.appendingPathComponent("summary.json")
                let data = try readSummary(summary, root: root)
                let lineage = try JSONDecoder().decode(GrokBuildLineage.self, from: data)
                guard lineage.info.id == id else { throw GrokBuildError.unsafeSource }
                sources.append(.init(id: id, directory: directory, lineage: lineage,
                                     fingerprint: try fingerprint(directory: directory)))
            } catch { excluded += 1 }
        }
        let counts = Dictionary(grouping: sources, by: \.id)
        // Duplicate UUIDs make the CLI's resolver ambiguous. Exclude every copy.
        let unique = sources.filter { counts[$0.id]?.count == 1 }
        excluded += sources.count - unique.count
        return .init(sources: unique.sorted { $0.id.uuidString < $1.id.uuidString },
                     excludedCount: excluded, limited: limited || scanFailed)
    }

    func fingerprint(directory: URL) throws -> String {
        try ["usage.json", "summary.json"].map { name in
            let url = directory.appendingPathComponent(name)
            let value = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey])
            guard value.isRegularFile == true, value.isSymbolicLink != true else { throw GrokBuildError.unsafeSource }
            return "\(name):\(value.fileSize ?? -1):\(value.contentModificationDate?.timeIntervalSince1970 ?? -1):\(String(describing: value.fileResourceIdentifier))"
        }.joined(separator: "|")
    }

    private func readSummary(_ url: URL, root: URL) throws -> Data {
        guard url.standardizedFileURL.resolvingSymlinksInPath().path == url.standardizedFileURL.path,
              url.path.hasPrefix(root.path + "/") else { throw GrokBuildError.unsafeSource }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= maximumSummaryBytes else { throw GrokBuildError.unsafeSource }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumSummaryBytes + 1) ?? Data()
        guard data.count <= maximumSummaryBytes else { throw GrokBuildError.outputTooLarge }
        return data
    }
}
