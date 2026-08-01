import Darwin
import Foundation
import SystemConfiguration

protocol NetworkCounterReading: Sendable {
    func readCounters() async throws -> NetworkInterfaceCounters
}

protocol NetworkMetricsSampling: Sendable {
    func reset() async
    func sample() async throws -> NetworkMetricsSnapshot
}

enum NetworkMetricsSamplingError: Error, Equatable, LocalizedError {
    case dynamicStoreUnavailable
    case primaryInterfaceUnavailable
    case interfaceUnavailable(String)
    case systemCall(String, Int32)

    var errorDescription: String? {
        switch self {
        case .dynamicStoreUnavailable:
            "Unable to read the current network configuration."
        case .primaryInterfaceUnavailable:
            "No primary network interface is currently available."
        case .interfaceUnavailable(let name):
            "Network counters are unavailable for interface \(name)."
        case let .systemCall(name, code):
            "Unable to read network counters (\(name) error \(code))."
        }
    }
}

struct DarwinNetworkCounterReader: NetworkCounterReading {
    func readCounters() async throws -> NetworkInterfaceCounters {
        let interfaceName = try Self.primaryInterfaceName()
        return try Self.readInterfaceCounters(named: interfaceName)
    }

    private static func primaryInterfaceName() throws -> String {
        guard let store = SCDynamicStoreCreate(
            nil,
            "DockMagic.NetworkMetrics" as CFString,
            nil,
            nil
        ) else {
            throw NetworkMetricsSamplingError.dynamicStoreUnavailable
        }

        for entity in [kSCEntNetIPv4, kSCEntNetIPv6] {
            let key = SCDynamicStoreKeyCreateNetworkGlobalEntity(
                nil,
                kSCDynamicStoreDomainState,
                entity
            )
            guard
                let value = SCDynamicStoreCopyValue(store, key),
                let dictionary = value as? [String: Any],
                let interfaceName = dictionary[
                    kSCDynamicStorePropNetPrimaryInterface as String
                ] as? String,
                !interfaceName.isEmpty
            else {
                continue
            }
            return interfaceName
        }

        throw NetworkMetricsSamplingError.primaryInterfaceUnavailable
    }

    private static func readInterfaceCounters(
        named interfaceName: String
    ) throws -> NetworkInterfaceCounters {
        let interfaceIndex = if_nametoindex(interfaceName)
        guard interfaceIndex != 0 else {
            throw NetworkMetricsSamplingError.interfaceUnavailable(interfaceName)
        }

        var mib = [
            Int32(CTL_NET),
            Int32(PF_ROUTE),
            0,
            0,
            Int32(NET_RT_IFLIST2),
            0
        ]
        var byteCount = 0

        let sizeResult = mib.withUnsafeMutableBufferPointer { pointer in
            sysctl(
                pointer.baseAddress,
                u_int(pointer.count),
                nil,
                &byteCount,
                nil,
                0
            )
        }
        guard sizeResult == 0 else {
            throw NetworkMetricsSamplingError.systemCall("sysctl", errno)
        }

        var buffer = [UInt8](repeating: 0, count: byteCount)
        let readResult = mib.withUnsafeMutableBufferPointer { mibPointer in
            buffer.withUnsafeMutableBytes { dataPointer in
                sysctl(
                    mibPointer.baseAddress,
                    u_int(mibPointer.count),
                    dataPointer.baseAddress,
                    &byteCount,
                    nil,
                    0
                )
            }
        }
        guard readResult == 0 else {
            throw NetworkMetricsSamplingError.systemCall("sysctl", errno)
        }

        return try buffer.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= byteCount {
                let messagePointer = rawBuffer.baseAddress!
                    .advanced(by: offset)
                    .assumingMemoryBound(to: if_msghdr2.self)
                let message = messagePointer.pointee
                let messageLength = Int(message.ifm_msglen)

                guard messageLength > 0, offset + messageLength <= byteCount else {
                    break
                }

                if
                    message.ifm_type == RTM_IFINFO2,
                    UInt32(message.ifm_index) == interfaceIndex
                {
                    return NetworkInterfaceCounters(
                        interfaceName: interfaceName,
                        receivedBytes: message.ifm_data.ifi_ibytes,
                        sentBytes: message.ifm_data.ifi_obytes
                    )
                }

                offset += messageLength
            }

            throw NetworkMetricsSamplingError.interfaceUnavailable(interfaceName)
        }
    }
}

actor NetworkMetricsSampler: NetworkMetricsSampling {
    private let reader: any NetworkCounterReading
    private let now: @Sendable () -> Date
    private var previousCounters: NetworkInterfaceCounters?
    private var previousTimestamp: Date?

    init(
        reader: any NetworkCounterReading = DarwinNetworkCounterReader(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.reader = reader
        self.now = now
    }

    func reset() {
        previousCounters = nil
        previousTimestamp = nil
    }

    func sample() async throws -> NetworkMetricsSnapshot {
        let counters = try await reader.readCounters()
        let timestamp = now()
        let elapsed = previousTimestamp.map { timestamp.timeIntervalSince($0) } ?? 0
        let rates = NetworkMetricsCalculation.rates(
            previous: previousCounters,
            current: counters,
            elapsed: elapsed
        )

        previousCounters = counters
        previousTimestamp = timestamp

        return NetworkMetricsSnapshot(
            timestamp: timestamp,
            interfaceName: counters.interfaceName,
            downloadBytesPerSecond: rates.download,
            uploadBytesPerSecond: rates.upload
        )
    }
}
