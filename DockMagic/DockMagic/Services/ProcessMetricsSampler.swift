//
//  ProcessMetricsSampler.swift
//  DockMagic
//

import Darwin
import Foundation

protocol ProcessMetricsSampling: Sendable {
    func reset() async
    func sample() async throws -> ProcessMetricsSnapshot
}

extension ProcessMetricsSampling {
    func reset() async {}
}

enum ProcessMetricsSamplingError: Error, Equatable, LocalizedError {
    case processList(Int32)

    var errorDescription: String? {
        switch self {
        case .processList(let code):
            "Unable to list running processes (POSIX error \(code))."
        }
    }
}

struct ProcessResourceCounters: Equatable, Sendable {
    let id: ProcessMetricID
    let name: String
    let totalCPUTimeNanoseconds: UInt64
    let physicalFootprintBytes: UInt64
}

enum ProcessMetricsCalculation {
    static func snapshot(
        previous: [ProcessMetricID: ProcessResourceCounters]?,
        current: [ProcessMetricID: ProcessResourceCounters],
        elapsed: TimeInterval,
        activeProcessorCount: Int,
        timestamp: Date = .now,
        topLimit: Int = ProcessMetricsSnapshot.maximumVisibleProcesses
    ) -> ProcessMetricsSnapshot {
        let limit = max(topLimit, 1)
        let processorCount = max(activeProcessorCount, 1)
        let isCPUReady = previous != nil && elapsed.isFinite && elapsed > 0

        let cpuRows: [ProcessMetricRow]
        if isCPUReady, let previous {
            cpuRows = current.values.compactMap { counters in
                guard
                    let oldCounters = previous[counters.id],
                    counters.totalCPUTimeNanoseconds
                        >= oldCounters.totalCPUTimeNanoseconds
                else {
                    return nil
                }

                let delta = counters.totalCPUTimeNanoseconds
                    - oldCounters.totalCPUTimeNanoseconds
                let usage = Double(delta)
                    / 1_000_000_000
                    / elapsed
                    / Double(processorCount)

                return ProcessMetricRow(
                    id: counters.id,
                    name: counters.name,
                    cpuUsage: usage,
                    memoryBytes: counters.physicalFootprintBytes
                )
            }
            .sorted(by: cpuOrder)
        } else {
            cpuRows = []
        }

        let memoryRows = current.values.map { counters in
            ProcessMetricRow(
                id: counters.id,
                name: counters.name,
                cpuUsage: 0,
                memoryBytes: counters.physicalFootprintBytes
            )
        }
        .sorted(by: memoryOrder)

        return ProcessMetricsSnapshot(
            timestamp: timestamp,
            topCPU: Array(cpuRows.prefix(limit)),
            topMemory: Array(memoryRows.prefix(limit)),
            isCPUReady: isCPUReady,
            readableProcessCount: current.count
        )
    }

    private static func cpuOrder(
        _ lhs: ProcessMetricRow,
        _ rhs: ProcessMetricRow
    ) -> Bool {
        if lhs.cpuUsage != rhs.cpuUsage {
            return lhs.cpuUsage > rhs.cpuUsage
        }
        return stableNameOrder(lhs, rhs)
    }

    private static func memoryOrder(
        _ lhs: ProcessMetricRow,
        _ rhs: ProcessMetricRow
    ) -> Bool {
        if lhs.memoryBytes != rhs.memoryBytes {
            return lhs.memoryBytes > rhs.memoryBytes
        }
        return stableNameOrder(lhs, rhs)
    }

    private static func stableNameOrder(
        _ lhs: ProcessMetricRow,
        _ rhs: ProcessMetricRow
    ) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs.id.processID < rhs.id.processID
    }
}

enum ProcessListCalculation {
    static func processIDs(
        in buffer: [pid_t],
        returnedCount: Int
    ) -> [pid_t] {
        guard returnedCount > 0 else {
            return []
        }
        return Array(buffer.prefix(min(returnedCount, buffer.count)))
            .filter { $0 > 0 }
    }
}

protocol ProcessResourceReading: Sendable {
    func readProcesses() throws -> [ProcessResourceCounters]
}

struct LibprocProcessResourceReader: ProcessResourceReading {
    func readProcesses() throws -> [ProcessResourceCounters] {
        try processIDs().compactMap(readCounters(for:))
    }

    private func processIDs() throws -> [pid_t] {
        var capacity = 1_024

        for _ in 0..<4 {
            var buffer = [pid_t](repeating: 0, count: capacity)
            Darwin.errno = 0
            let processCount = buffer.withUnsafeMutableBytes { rawBuffer in
                proc_listallpids(rawBuffer.baseAddress, Int32(rawBuffer.count))
            }

            guard processCount > 0 else {
                throw ProcessMetricsSamplingError.processList(
                    Darwin.errno == 0 ? EIO : Darwin.errno
                )
            }

            if processCount < capacity {
                return ProcessListCalculation.processIDs(
                    in: buffer,
                    returnedCount: Int(processCount)
                )
            }
            capacity *= 2
        }

        var buffer = [pid_t](repeating: 0, count: capacity)
        Darwin.errno = 0
        let processCount = buffer.withUnsafeMutableBytes { rawBuffer in
            proc_listallpids(rawBuffer.baseAddress, Int32(rawBuffer.count))
        }
        guard processCount > 0 else {
            throw ProcessMetricsSamplingError.processList(
                Darwin.errno == 0 ? EIO : Darwin.errno
            )
        }
        return ProcessListCalculation.processIDs(
            in: buffer,
            returnedCount: Int(processCount)
        )
    }

    private func readCounters(for processID: pid_t) -> ProcessResourceCounters? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(
                to: rusage_info_t?.self,
                capacity: 1
            ) { reboundPointer in
                proc_pid_rusage(
                    processID,
                    RUSAGE_INFO_V4,
                    reboundPointer
                )
            }
        }
        guard result == 0 else {
            // Processes can exit or become unreadable while the list is being
            // traversed. One inaccessible PID must not fail the dashboard.
            return nil
        }

        let totalCPUTime: UInt64
        let (sum, overflow) = usage.ri_user_time.addingReportingOverflow(
            usage.ri_system_time
        )
        totalCPUTime = overflow ? .max : sum

        return ProcessResourceCounters(
            id: ProcessMetricID(
                processID: processID,
                startTime: usage.ri_proc_start_abstime
            ),
            name: processName(processID),
            totalCPUTimeNanoseconds: totalCPUTime,
            physicalFootprintBytes: usage.ri_phys_footprint
        )
    }

    private func processName(_ processID: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_name(
                processID,
                pointer.baseAddress,
                UInt32(pointer.count)
            )
        }
        guard length > 0 else {
            return "Process \(processID)"
        }
        return String(cString: buffer)
    }
}

/// Samples per-process CPU and memory without invoking `ps`, `top`, or a helper
/// process. The actor owns the previous counters required for CPU deltas.
actor SystemProcessMetricsSampler: ProcessMetricsSampling {
    private let reader: any ProcessResourceReading
    private let activeProcessorCount: Int
    private let uptime: @Sendable () -> TimeInterval
    private let now: @Sendable () -> Date

    private var previousCounters: [
        ProcessMetricID: ProcessResourceCounters
    ]?
    private var previousUptime: TimeInterval?

    init(
        reader: any ProcessResourceReading = LibprocProcessResourceReader(),
        activeProcessorCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        uptime: @escaping @Sendable () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.reader = reader
        self.activeProcessorCount = max(activeProcessorCount, 1)
        self.uptime = uptime
        self.now = now
    }

    func reset() {
        previousCounters = nil
        previousUptime = nil
    }

    func sample() async throws -> ProcessMetricsSnapshot {
        let sampledAt = now()
        let sampledUptime = uptime()
        let processCounters = try reader.readProcesses()
        var current: [ProcessMetricID: ProcessResourceCounters] = [:]
        current.reserveCapacity(processCounters.count)
        for counters in processCounters {
            current[counters.id] = counters
        }

        let elapsed = previousUptime.map { sampledUptime - $0 } ?? 0
        let snapshot = ProcessMetricsCalculation.snapshot(
            previous: previousCounters,
            current: current,
            elapsed: elapsed,
            activeProcessorCount: activeProcessorCount,
            timestamp: sampledAt
        )
        previousCounters = current
        previousUptime = sampledUptime
        return snapshot
    }
}
