import Foundation

struct OpenCodeHistoryCache: Sendable {
    private struct Envelope: Codable {
        let version: Int
        let snapshot: OpenCodeUsageSnapshot
    }
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DockMagic/OpenCode", isDirectory: true)
    }
    func file(sourceID: String, timezoneID: String) -> URL {
        directory.appendingPathComponent(OpenCodeSourceDiscovery.hash(sourceID + "|" + timezoneID) + ".json")
    }
    func load(sourceID: String, timezoneID: String) -> OpenCodeUsageSnapshot? {
        let path = file(sourceID: sourceID, timezoneID: timezoneID)
        guard let data = try? Data(contentsOf: path),
              let value = try? JSONDecoder().decode(Envelope.self, from: data), value.version == 1,
              value.snapshot.sourceID == sourceID, value.snapshot.timezoneID == timezoneID else { return nil }
        return value.snapshot
    }
    func save(_ snapshot: OpenCodeUsageSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(Envelope(version: 1, snapshot: snapshot))
        let path = file(sourceID: snapshot.sourceID, timezoneID: snapshot.timezoneID)
        try data.write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }
    func clear() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        // Only the dedicated DockMagic cache directory, never any OpenCode source file.
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where url.pathExtension == "json" { try FileManager.default.removeItem(at: url) }
    }
}
