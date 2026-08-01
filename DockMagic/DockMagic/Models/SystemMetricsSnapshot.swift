//
//  SystemMetricsSnapshot.swift
//  DockMagic
//

import Foundation

/// A point-in-time view of the system metrics rendered by DockMagic.
///
/// Usage values are normalized to `0...1` at the model boundary so renderers
/// never need to defend against invalid progress values.
struct SystemMetricsSnapshot: Equatable, Sendable {
    static let zero = SystemMetricsSnapshot(
        timestamp: .distantPast,
        cpuUsage: 0,
        memoryUsage: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0
    )

    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let memoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64

    init(
        timestamp: Date = .now,
        cpuUsage: Double,
        memoryUsage: Double,
        memoryUsedBytes: UInt64,
        memoryTotalBytes: UInt64
    ) {
        self.timestamp = timestamp
        self.cpuUsage = Self.normalized(cpuUsage)
        self.memoryUsage = Self.normalized(memoryUsage)
        self.memoryTotalBytes = memoryTotalBytes
        self.memoryUsedBytes = min(memoryUsedBytes, memoryTotalBytes)
    }

    var cpuPercentage: Double {
        cpuUsage * 100
    }

    var memoryPercentage: Double {
        memoryUsage * 100
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        return min(max(value, 0), 1)
    }
}
