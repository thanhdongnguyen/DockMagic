import Foundation

struct AugmentHistoryCache: Sendable {
    private struct Envelope: Codable {
        let version: Int
        let connectionID: String
        let snapshot: AugmentUsageSnapshot
    }
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DockMagic/Augment", isDirectory: true)
    }
    private var file: URL { directory.appendingPathComponent("organization-v1.json") }
    func load(connectionID: String) -> AugmentUsageSnapshot? {
        guard let data = try? Data(contentsOf: file), data.count <= 2_000_000,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == 1, envelope.connectionID == connectionID else { return nil }
        return envelope.snapshot
    }
    func save(_ snapshot: AugmentUsageSnapshot, connectionID: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(Envelope(version: 1, connectionID: connectionID, snapshot: snapshot)).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}
