import Foundation

protocol StorageMetricsSampling: Sendable {
    func sample() async throws -> StorageMetricsSnapshot
}

enum StorageMetricsSamplingError: Error, Equatable, LocalizedError {
    case capacityUnavailable

    var errorDescription: String? {
        switch self {
        case .capacityUnavailable:
            "Startup disk capacity is unavailable."
        }
    }
}

actor StorageMetricsSampler: StorageMetricsSampling {
    private let volumeURL: URL

    init(volumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true)) {
        self.volumeURL = volumeURL
    }

    func sample() async throws -> StorageMetricsSnapshot {
        let values = try volumeURL.resourceValues(forKeys: [
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        // Match the capacity shown by macOS. This value includes space the
        // system can reclaim when an important operation needs it.
        let availableCapacity: Int64?
        if let importantUsageCapacity = values.volumeAvailableCapacityForImportantUsage,
           importantUsageCapacity >= 0 {
            availableCapacity = importantUsageCapacity
        } else {
            availableCapacity = values.volumeAvailableCapacity.map(Int64.init)
        }

        guard
            let totalCapacity = values.volumeTotalCapacity,
            let availableCapacity,
            totalCapacity > 0,
            availableCapacity >= 0
        else {
            throw StorageMetricsSamplingError.capacityUnavailable
        }

        return StorageMetricsSnapshot(
            volumeName: values.volumeLocalizedName ?? "Startup Disk",
            totalBytes: UInt64(totalCapacity),
            availableBytes: UInt64(availableCapacity)
        )
    }
}
