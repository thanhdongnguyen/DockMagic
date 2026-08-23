import Foundation
import IOKit
import IOKit.ps

protocol BatteryMetricsSampling: Sendable {
    func sample() async throws -> BatteryMetricsSnapshot
}

protocol BatteryDeviceReading: Sendable {
    func readDevices(observedAt: Date) throws -> [BatteryDeviceSnapshot]
}

actor BatteryMetricsSampler: BatteryMetricsSampling {
    private let readers: [any BatteryDeviceReading]
    private let now: @Sendable () -> Date

    init(
        readers: [any BatteryDeviceReading] = [
            SystemPowerSourceBatteryReader(),
            IORegistryAccessoryBatteryReader()
        ],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.readers = readers
        self.now = now
    }

    func sample() async throws -> BatteryMetricsSnapshot {
        try Task.checkCancellation()
        let sampledAt = now()
        var devices: [BatteryDeviceSnapshot] = []
        for reader in readers {
            devices.append(contentsOf: try reader.readDevices(observedAt: sampledAt))
        }

        var unique: [String: BatteryDeviceSnapshot] = [:]
        for device in devices {
            unique[device.id] = device
        }
        return BatteryMetricsSnapshot(
            devices: Array(unique.values),
            sampledAt: sampledAt
        )
    }
}

struct SystemPowerSourceBatteryReader: BatteryDeviceReading {
    func readDevices(observedAt: Date) throws -> [BatteryDeviceSnapshot] {
        let powerSourcesInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(powerSourcesInfo)
            .takeRetainedValue() as Array

        for powerSource in powerSources {
            guard
                let description = IOPSGetPowerSourceDescription(
                    powerSourcesInfo,
                    powerSource
                )?.takeUnretainedValue() as? [String: Any],
                (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                (description[kIOPSIsPresentKey] as? Bool) != false,
                let current = Self.number(description[kIOPSCurrentCapacityKey]),
                let maximum = Self.number(description[kIOPSMaxCapacityKey]),
                maximum > 0
            else {
                continue
            }

            return [
                BatteryDeviceSnapshot(
                    id: "system.internal-battery",
                    name: Self.macProductName,
                    kind: .macBook,
                    level: current / maximum,
                    isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                    isExternalPowerConnected: Self.isExternalPowerConnected(
                        powerSourceState: description[kIOPSPowerSourceStateKey] as? String
                    ),
                    observedAt: observedAt
                )
            ]
        }

        return []
    }

    static func isExternalPowerConnected(powerSourceState: String?) -> Bool {
        powerSourceState == kIOPSACPowerValue
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static var macProductName: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "MacBook"
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
            return "MacBook"
        }

        let model = String(cString: buffer).lowercased()
        if model.contains("macbookpro") {
            return "MacBook Pro"
        }
        if model.contains("macbookair") {
            return "MacBook Air"
        }
        return "MacBook"
    }
}

enum BatteryRegistryProperty: Equatable, Sendable {
    case number(Double)
    case string(String)
    case boolean(Bool)

    var number: Double? {
        switch self {
        case let .number(value):
            value
        case let .string(value):
            Double(value)
        case let .boolean(value):
            value ? 1 : 0
        }
    }

    var string: String? {
        switch self {
        case let .number(value):
            String(value)
        case let .string(value):
            value
        case let .boolean(value):
            value ? "true" : "false"
        }
    }

    var boolean: Bool? {
        switch self {
        case let .boolean(value):
            value
        case let .number(value):
            value != 0
        case let .string(value):
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "charging":
                true
            case "0", "false", "no", "discharging", "not charging":
                false
            default:
                nil
            }
        }
    }
}

struct BatteryRegistryRecord: Equatable, Sendable {
    let registryID: UInt64
    let properties: [String: BatteryRegistryProperty]

    init(registryID: UInt64, properties: [String: BatteryRegistryProperty]) {
        self.registryID = registryID
        self.properties = properties.reduce(into: [:]) { normalized, entry in
            // Drivers may publish the same logical field using spaced and
            // compact spellings. Last value wins without trapping the app.
            let key = BatteryAccessoryParser.normalizedKey(entry.key)
            normalized[key] = entry.value
        }
    }
}

struct IORegistryAccessoryBatteryReader: BatteryDeviceReading {
    private static let serviceClasses = [
        "IOHIDEventService",
        "IOHIDDevice",
        "IOHIDInterface",
        "AppleDeviceManagementHIDEventService",
        "AppleHSBluetoothDevice",
        "AppleBluetoothHIDDevice",
        "IOBluetoothHIDDriver",
        "IOBluetoothHIDDriverGen2"
    ]

    func readDevices(observedAt: Date) throws -> [BatteryDeviceSnapshot] {
        var records: [BatteryRegistryRecord] = []
        var seenRegistryIDs = Set<UInt64>()

        for serviceClass in Self.serviceClasses {
            guard let matching = IOServiceMatching(serviceClass) else {
                continue
            }

            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(
                kIOMainPortDefault,
                matching,
                &iterator
            ) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }

            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }

                var registryID: UInt64 = 0
                guard
                    IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS,
                    seenRegistryIDs.insert(registryID).inserted,
                    let properties = properties(for: service),
                    BatteryAccessoryParser.containsBatteryProperty(properties)
                else {
                    continue
                }

                records.append(
                    BatteryRegistryRecord(
                        registryID: registryID,
                        properties: properties
                    )
                )
            }
        }

        return BatteryAccessoryParser().devices(
            from: records,
            observedAt: observedAt
        )
    }

    private func properties(
        for service: io_registry_entry_t
    ) -> [String: BatteryRegistryProperty]? {
        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        guard
            IORegistryEntryCreateCFProperties(
                service,
                &unmanagedProperties,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
            let dictionary = unmanagedProperties?.takeRetainedValue()
                as? [String: Any]
        else {
            return nil
        }

        var flattened: [String: BatteryRegistryProperty] = [:]
        flatten(dictionary, into: &flattened)
        return flattened
    }

    private func flatten(
        _ dictionary: [String: Any],
        into result: inout [String: BatteryRegistryProperty]
    ) {
        for (key, value) in dictionary {
            if let nested = value as? [String: Any] {
                flatten(nested, into: &result)
            } else if CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID(),
                      let value = value as? Bool {
                result[key] = .boolean(value)
            } else if let value = value as? NSNumber {
                result[key] = .number(value.doubleValue)
            } else if let value = value as? String {
                result[key] = .string(value)
            }
        }
    }
}

struct BatteryAccessoryParser: Sendable {
    private static let overallLevelKeys = [
        "batterypercent",
        "batterypercentage",
        "batterylevel",
        "batterypercentsingle",
        "batterypercentcombined",
        "devicebatterypercent",
        "devicebatterypercentage"
    ]
    private static let leftLevelKeys = [
        "batterypercentleft",
        "leftbatterypercent",
        "batterypercentleftbud"
    ]
    private static let rightLevelKeys = [
        "batterypercentright",
        "rightbatterypercent",
        "batterypercentrightbud"
    ]
    private static let caseLevelKeys = [
        "batterypercentcase",
        "casebatterypercent",
        "chargingcasebatterypercent",
        "batterypercentchargingcase"
    ]
    private static let chargingKeys = [
        "ischarging",
        "batterycharging",
        "charging",
        "batteryischarging"
    ]
    private static let caseChargingKeys = [
        "caseischarging",
        "casecharging",
        "chargingcaseischarging",
        "batterycaseischarging"
    ]
    private static let nameKeys = [
        "product",
        "productname",
        "devicename",
        "btname",
        "name"
    ]
    private static let identityKeys = [
        "deviceaddress",
        "bluetoothdeviceaddress",
        "serialnumber",
        "serialnumberstring",
        "uniqueid"
    ]

    func devices(
        from records: [BatteryRegistryRecord],
        observedAt: Date
    ) -> [BatteryDeviceSnapshot] {
        let valid = records.filter(isConnectedAccessory)
        let grouped = Dictionary(grouping: valid, by: groupIdentity)
        var devices: [BatteryDeviceSnapshot] = []

        for (identity, records) in grouped {
            let properties = mergedProperties(records)
            let name = firstString(Self.nameKeys, in: properties) ?? "Connected Accessory"
            let kind = kind(for: name, properties: properties)
            let overall = firstLevel(Self.overallLevelKeys, in: properties)
            let left = firstLevel(Self.leftLevelKeys, in: properties)
            let right = firstLevel(Self.rightLevelKeys, in: properties)
            let caseLevel = firstLevel(Self.caseLevelKeys, in: properties)

            if kind == .airPods || left != nil || right != nil || caseLevel != nil {
                if let level = overall ?? Self.lowestKnown(left, right) {
                    devices.append(
                        BatteryDeviceSnapshot(
                            id: "accessory.\(identity).earbuds",
                            name: airPodsName(from: name),
                            kind: .airPods,
                            level: level,
                            isCharging: firstBoolean(Self.chargingKeys, in: properties) ?? false,
                            observedAt: observedAt
                        )
                    )
                }

                if let caseLevel {
                    devices.append(
                        BatteryDeviceSnapshot(
                            id: "accessory.\(identity).case",
                            name: "Charging Case",
                            kind: .chargingCase,
                            level: caseLevel,
                            isCharging: firstBoolean(Self.caseChargingKeys, in: properties) ?? false,
                            detail: "Updated just now",
                            observedAt: observedAt
                        )
                    )
                }
                continue
            }

            guard let level = overall else {
                continue
            }
            devices.append(
                BatteryDeviceSnapshot(
                    id: "accessory.\(identity)",
                    name: displayName(name, kind: kind),
                    kind: kind,
                    level: level,
                    isCharging: firstBoolean(Self.chargingKeys, in: properties) ?? false,
                    observedAt: observedAt
                )
            )
        }

        return devices
    }

    static func containsBatteryProperty(
        _ properties: [String: BatteryRegistryProperty]
    ) -> Bool {
        let keys = Set(properties.keys.map(normalizedKey))
        return !keys.isDisjoint(with: Set(
            overallLevelKeys + leftLevelKeys + rightLevelKeys + caseLevelKeys
        ))
    }

    static func normalizedKey(_ key: String) -> String {
        String(key.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
            .lowercased()
    }

    private func isConnectedAccessory(_ record: BatteryRegistryRecord) -> Bool {
        let properties = record.properties
        if firstBoolean(["builtin"], in: properties) == true {
            return false
        }

        let name = firstString(Self.nameKeys, in: properties)?.lowercased() ?? ""
        if name.contains("internal") || name.contains("sensor") {
            return false
        }

        guard Self.containsBatteryProperty(properties) else {
            return false
        }

        let transport = firstString(
            ["transport", "devicetransport"],
            in: properties
        )?.lowercased() ?? ""
        return transport.contains("bluetooth")
            || transport.contains("usb")
            || !name.isEmpty
            || firstLevel(Self.leftLevelKeys + Self.rightLevelKeys, in: properties) != nil
    }

    private func groupIdentity(_ record: BatteryRegistryRecord) -> String {
        if let identity = firstString(Self.identityKeys, in: record.properties) {
            return Self.identifier(identity)
        }
        if let name = firstString(Self.nameKeys, in: record.properties) {
            return Self.identifier(name)
        }
        return String(record.registryID)
    }

    private func mergedProperties(
        _ records: [BatteryRegistryRecord]
    ) -> [String: BatteryRegistryProperty] {
        records.reduce(into: [:]) { merged, record in
            for (key, value) in record.properties where merged[key] == nil {
                merged[key] = value
            }
        }
    }

    private func firstLevel(
        _ keys: [String],
        in properties: [String: BatteryRegistryProperty]
    ) -> Double? {
        guard let raw = keys.lazy.compactMap({ properties[$0]?.number }).first else {
            return nil
        }
        guard raw.isFinite, raw >= 0 else {
            return nil
        }
        let fraction = raw > 1 ? raw / 100 : raw
        return min(fraction, 1)
    }

    private func firstString(
        _ keys: [String],
        in properties: [String: BatteryRegistryProperty]
    ) -> String? {
        keys.lazy.compactMap { key in
            guard let value = properties[key]?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !value.isEmpty
            else {
                return nil
            }
            return value
        }.first
    }

    private func firstBoolean(
        _ keys: [String],
        in properties: [String: BatteryRegistryProperty]
    ) -> Bool? {
        keys.lazy.compactMap { properties[$0]?.boolean }.first
    }

    private func kind(
        for name: String,
        properties: [String: BatteryRegistryProperty]
    ) -> BatteryDeviceKind {
        let lowered = name.lowercased()
        if lowered.contains("airpod") || lowered.contains("beats fit") {
            return .airPods
        }
        if lowered.contains("magic mouse") || lowered.contains("mouse") {
            return .magicMouse
        }
        if lowered.contains("magic trackpad") || lowered.contains("trackpad") {
            return .magicTrackpad
        }
        if lowered.contains("magic keyboard") || lowered.contains("keyboard") {
            return .magicKeyboard
        }
        if lowered.contains("headphone")
            || lowered.contains("headset")
            || lowered.contains("beats") {
            return .headphones
        }
        if firstLevel(Self.leftLevelKeys + Self.rightLevelKeys, in: properties) != nil {
            return .airPods
        }
        return .accessory
    }

    private func airPodsName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().contains("airpod") ? trimmed : "AirPods"
    }

    private func displayName(
        _ name: String,
        kind: BatteryDeviceKind
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return switch kind {
            case .magicMouse: "Magic Mouse"
            case .magicTrackpad: "Magic Trackpad"
            case .magicKeyboard: "Magic Keyboard"
            case .headphones: "Headphones"
            case .accessory: "Connected Accessory"
            case .macBook: "MacBook"
            case .airPods: "AirPods"
            case .chargingCase: "Charging Case"
            }
        }
        return trimmed
    }

    private static func lowestKnown(_ values: Double?...) -> Double? {
        values.compactMap { $0 }.min()
    }

    private static func identifier(_ value: String) -> String {
        let normalized = value.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        return String(normalized)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
