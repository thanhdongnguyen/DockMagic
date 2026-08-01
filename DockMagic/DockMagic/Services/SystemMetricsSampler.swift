//
//  SystemMetricsSampler.swift
//  DockMagic
//

import Darwin
import Foundation

protocol SystemMetricsSampling: Sendable {
    func reset() async
    func sample() async throws -> SystemMetricsSnapshot
}

extension SystemMetricsSampling {
    func reset() async {}
}

enum SystemMetricsSamplingError: Error, Equatable, LocalizedError {
    case cpuStatistics(kern_return_t)
    case virtualMemoryStatistics(kern_return_t)
    case hostPageSize(kern_return_t)

    var errorDescription: String? {
        switch self {
        case .cpuStatistics(let code):
            return "Unable to read CPU statistics (Mach error \(code))."
        case .virtualMemoryStatistics(let code):
            return "Unable to read memory statistics (Mach error \(code))."
        case .hostPageSize(let code):
            return "Unable to read the host page size (Mach error \(code))."
        }
    }
}

struct CPUTicks: Equatable, Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

struct MemoryUsage: Equatable, Sendable {
    let usedBytes: UInt64
    let utilization: Double
}

enum SystemMetricsCalculation {
    static func cpuUtilization(previous: CPUTicks?, current: CPUTicks) -> Double {
        guard let previous else {
            return 0
        }

        guard
            current.user >= previous.user,
            current.system >= previous.system,
            current.idle >= previous.idle,
            current.nice >= previous.nice
        else {
            // The kernel counters can wrap or reset. Dropping one sample is
            // safer than briefly showing a false 100% spike.
            return 0
        }

        let user = Double(current.user - previous.user)
        let system = Double(current.system - previous.system)
        let idle = Double(current.idle - previous.idle)
        let nice = Double(current.nice - previous.nice)
        let total = user + system + idle + nice

        guard total > 0, total.isFinite else {
            return 0
        }

        return min(max((user + system + nice) / total, 0), 1)
    }

    static func memoryUsage(
        activePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        pageSize: UInt64,
        physicalMemory: UInt64
    ) -> MemoryUsage {
        guard physicalMemory > 0, pageSize > 0 else {
            return MemoryUsage(usedBytes: 0, utilization: 0)
        }

        let usedPages = saturatedAdd(
            saturatedAdd(activePages, wiredPages),
            compressedPages
        )
        let rawUsedBytes = saturatedMultiply(usedPages, pageSize)
        let usedBytes = min(rawUsedBytes, physicalMemory)
        let utilization = min(
            max(Double(usedBytes) / Double(physicalMemory), 0),
            1
        )

        return MemoryUsage(usedBytes: usedBytes, utilization: utilization)
    }

    private static func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : result
    }

    private static func saturatedMultiply(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? .max : result
    }
}

/// Reads host-wide metrics through public Mach APIs.
///
/// The actor owns the previous CPU counters, ensuring delta calculations are
/// serialized and that the synchronous Mach calls do not execute on the main
/// actor when sampled from the UI store.
actor SystemMetricsSampler: SystemMetricsSampling {
    private let physicalMemoryBytes: UInt64
    private var previousCPUTicks: CPUTicks?

    init(physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.physicalMemoryBytes = physicalMemoryBytes
    }

    func reset() {
        previousCPUTicks = nil
    }

    func sample() async throws -> SystemMetricsSnapshot {
        let currentCPUTicks = try Self.readCPUTicks()
        let cpuUsage = SystemMetricsCalculation.cpuUtilization(
            previous: previousCPUTicks,
            current: currentCPUTicks
        )
        previousCPUTicks = currentCPUTicks

        let memoryUsage = try Self.readMemoryUsage(
            physicalMemoryBytes: physicalMemoryBytes
        )

        return SystemMetricsSnapshot(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage.utilization,
            memoryUsedBytes: memoryUsage.usedBytes,
            memoryTotalBytes: physicalMemoryBytes
        )
    }

    private static func readCPUTicks() throws -> CPUTicks {
        let host = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        var statistics = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size
                / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { reboundPointer in
                host_statistics(
                    host,
                    HOST_CPU_LOAD_INFO,
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw SystemMetricsSamplingError.cpuStatistics(result)
        }

        return CPUTicks(
            user: UInt64(statistics.cpu_ticks.0),
            system: UInt64(statistics.cpu_ticks.1),
            idle: UInt64(statistics.cpu_ticks.2),
            nice: UInt64(statistics.cpu_ticks.3)
        )
    }

    private static func readMemoryUsage(
        physicalMemoryBytes: UInt64
    ) throws -> MemoryUsage {
        let host = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size
                / MemoryLayout<integer_t>.size
        )

        let statisticsResult = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { reboundPointer in
                host_statistics64(
                    host,
                    HOST_VM_INFO64,
                    reboundPointer,
                    &count
                )
            }
        }

        guard statisticsResult == KERN_SUCCESS else {
            throw SystemMetricsSamplingError.virtualMemoryStatistics(
                statisticsResult
            )
        }

        var pageSize = vm_size_t()
        let pageSizeResult = host_page_size(host, &pageSize)

        guard pageSizeResult == KERN_SUCCESS else {
            throw SystemMetricsSamplingError.hostPageSize(pageSizeResult)
        }

        return SystemMetricsCalculation.memoryUsage(
            activePages: UInt64(statistics.active_count),
            wiredPages: UInt64(statistics.wire_count),
            compressedPages: UInt64(statistics.compressor_page_count),
            pageSize: UInt64(pageSize),
            physicalMemory: physicalMemoryBytes
        )
    }
}
