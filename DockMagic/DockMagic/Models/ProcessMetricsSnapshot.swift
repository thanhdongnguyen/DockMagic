//
//  ProcessMetricsSnapshot.swift
//  DockMagic
//

import Foundation

/// Stable identity for one process lifetime. macOS can reuse a PID after a
/// process exits, so the kernel start time is part of the identity.
struct ProcessMetricID: Hashable, Sendable {
    let processID: Int32
    let startTime: UInt64
}

/// One row rendered by the CPU or memory process rankings.
struct ProcessMetricRow: Identifiable, Equatable, Sendable {
    let id: ProcessMetricID
    let name: String
    let cpuUsage: Double
    let memoryBytes: UInt64

    init(
        id: ProcessMetricID,
        name: String,
        cpuUsage: Double,
        memoryBytes: UInt64
    ) {
        self.id = id
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmedName.isEmpty
            ? "Process \(id.processID)"
            : trimmedName
        self.cpuUsage = Self.normalized(cpuUsage)
        self.memoryBytes = memoryBytes
    }

    var cpuPercentage: Double {
        cpuUsage * 100
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 1)
    }
}

/// A bounded, local-only snapshot for the CPU & RAM hover dashboard.
struct ProcessMetricsSnapshot: Equatable, Sendable {
    static let maximumVisibleProcesses = 10

    static let zero = ProcessMetricsSnapshot(
        timestamp: .distantPast,
        topCPU: [],
        topMemory: [],
        isCPUReady: false,
        readableProcessCount: 0
    )

    let timestamp: Date
    let topCPU: [ProcessMetricRow]
    let topMemory: [ProcessMetricRow]
    let isCPUReady: Bool
    let readableProcessCount: Int

    init(
        timestamp: Date = .now,
        topCPU: [ProcessMetricRow],
        topMemory: [ProcessMetricRow],
        isCPUReady: Bool,
        readableProcessCount: Int
    ) {
        self.timestamp = timestamp
        self.topCPU = Array(topCPU.prefix(Self.maximumVisibleProcesses))
        self.topMemory = Array(topMemory.prefix(Self.maximumVisibleProcesses))
        self.isCPUReady = isCPUReady
        self.readableProcessCount = max(readableProcessCount, 0)
    }
}

extension ProcessMetricsSnapshot {
    static let designPreview: ProcessMetricsSnapshot = {
        let names = [
            "WindowServer",
            "Xcode",
            "Safari",
            "DockMagic",
            "com.apple.WebKit.WebContent",
            "kernel_task",
            "Finder",
            "Terminal",
            "Spotlight",
            "ControlCenter"
        ]
        let cpu = [0.184, 0.142, 0.086, 0.052, 0.041, 0.029, 0.018, 0.013, 0.009, 0.006]
        let memory: [UInt64] = [
            1_420_000_000,
            3_680_000_000,
            1_180_000_000,
            184_000_000,
            872_000_000,
            690_000_000,
            412_000_000,
            238_000_000,
            196_000_000,
            164_000_000
        ]
        let rows = names.indices.map { index in
            ProcessMetricRow(
                id: ProcessMetricID(
                    processID: Int32(500 + index),
                    startTime: UInt64(10_000 + index)
                ),
                name: names[index],
                cpuUsage: cpu[index],
                memoryBytes: memory[index]
            )
        }
        return ProcessMetricsSnapshot(
            timestamp: .now,
            topCPU: rows.sorted { $0.cpuUsage > $1.cpuUsage },
            topMemory: rows.sorted { $0.memoryBytes > $1.memoryBytes },
            isCPUReady: true,
            readableProcessCount: 184
        )
    }()
}
