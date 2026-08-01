import Foundation

struct StorageMetricsSnapshot: Equatable, Sendable {
    static let zero = StorageMetricsSnapshot(
        timestamp: .distantPast,
        volumeName: "Startup Disk",
        totalBytes: 0,
        availableBytes: 0
    )

    let timestamp: Date
    let volumeName: String
    let totalBytes: UInt64
    let availableBytes: UInt64

    init(
        timestamp: Date = .now,
        volumeName: String,
        totalBytes: UInt64,
        availableBytes: UInt64
    ) {
        self.timestamp = timestamp
        self.volumeName = volumeName.isEmpty ? "Startup Disk" : volumeName
        self.totalBytes = totalBytes
        self.availableBytes = min(availableBytes, totalBytes)
    }

    var usedBytes: UInt64 {
        totalBytes - availableBytes
    }

    var usage: Double {
        guard totalBytes > 0 else {
            return 0
        }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}
