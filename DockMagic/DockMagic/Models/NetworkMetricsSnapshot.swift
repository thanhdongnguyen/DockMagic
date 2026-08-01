import Foundation

struct NetworkInterfaceCounters: Equatable, Sendable {
    let interfaceName: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

struct NetworkMetricsSnapshot: Equatable, Identifiable, Sendable {
    static let zero = NetworkMetricsSnapshot(
        timestamp: .distantPast,
        interfaceName: nil,
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0
    )

    let timestamp: Date
    let interfaceName: String?
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double

    var id: Date { timestamp }

    init(
        timestamp: Date = .now,
        interfaceName: String?,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double
    ) {
        self.timestamp = timestamp
        self.interfaceName = interfaceName
        self.downloadBytesPerSecond = Self.normalized(downloadBytesPerSecond)
        self.uploadBytesPerSecond = Self.normalized(uploadBytesPerSecond)
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite, value >= 0 else {
            return 0
        }
        return value
    }
}

enum NetworkMetricsCalculation {
    static func rates(
        previous: NetworkInterfaceCounters?,
        current: NetworkInterfaceCounters,
        elapsed: TimeInterval
    ) -> (download: Double, upload: Double) {
        guard
            let previous,
            previous.interfaceName == current.interfaceName,
            elapsed.isFinite,
            elapsed > 0,
            current.receivedBytes >= previous.receivedBytes,
            current.sentBytes >= previous.sentBytes
        else {
            return (0, 0)
        }

        return (
            Double(current.receivedBytes - previous.receivedBytes) / elapsed,
            Double(current.sentBytes - previous.sentBytes) / elapsed
        )
    }
}

enum NetworkChartScale {
    private static let ceilings: [Double] = [
        64 * 1_024,
        256 * 1_024,
        1 * 1_024 * 1_024,
        4 * 1_024 * 1_024,
        16 * 1_024 * 1_024,
        64 * 1_024 * 1_024,
        256 * 1_024 * 1_024,
        1_024 * 1_024 * 1_024
    ]

    static func ceiling(for samples: [NetworkMetricsSnapshot]) -> Double {
        let peak = samples.reduce(0) { partial, sample in
            max(
                partial,
                sample.downloadBytesPerSecond,
                sample.uploadBytesPerSecond
            )
        }

        if let ceiling = ceilings.first(where: { peak <= $0 }) {
            return ceiling
        }

        guard peak.isFinite, peak > 0 else {
            return ceilings[0]
        }
        return pow(2, ceil(log2(peak)))
    }
}

enum MetricsFormatting {
    static func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(min(bytes, UInt64(Int64.max))),
            countStyle: .file
        )
    }

    static func byteRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "0 KB/s"
        }
        let bounded = min(bytesPerSecond.rounded(), Double(Int64.max))
        return ByteCountFormatter.string(
            fromByteCount: Int64(bounded),
            countStyle: .file
        ) + "/s"
    }
}
