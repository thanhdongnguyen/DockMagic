import Foundation

enum BatteryDeviceKind: String, Codable, CaseIterable, Sendable {
    case macBook
    case airPods
    case chargingCase
    case magicMouse
    case magicTrackpad
    case magicKeyboard
    case headphones
    case accessory

    var systemImage: String {
        switch self {
        case .macBook:
            "laptopcomputer"
        case .airPods:
            "airpodspro"
        case .chargingCase:
            "airpodspro.chargingcase.wireless.fill"
        case .magicMouse:
            "computermouse.fill"
        case .magicTrackpad:
            "magictrackpad"
        case .magicKeyboard:
            "keyboard"
        case .headphones:
            "headphones"
        case .accessory:
            "battery.100percent"
        }
    }

    var sortPriority: Int {
        switch self {
        case .macBook:
            0
        case .airPods:
            10
        case .chargingCase:
            20
        case .magicMouse:
            30
        case .magicTrackpad:
            40
        case .magicKeyboard:
            50
        case .headphones:
            60
        case .accessory:
            70
        }
    }
}

struct BatteryDeviceSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: BatteryDeviceKind
    let level: Double
    let isCharging: Bool
    let isExternalPowerConnected: Bool
    let detail: String
    let observedAt: Date

    init(
        id: String,
        name: String,
        kind: BatteryDeviceKind,
        level: Double,
        isCharging: Bool = false,
        isExternalPowerConnected: Bool = false,
        detail: String? = nil,
        observedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.level = Self.normalized(level)
        self.isCharging = isCharging
        self.isExternalPowerConnected = isExternalPowerConnected
        self.detail = detail ?? (isCharging ? "Charging" : "Connected")
        self.observedAt = observedAt
    }

    var percentage: Int {
        Int((level * 100).rounded())
    }

    var showsPowerIndicator: Bool {
        kind == .macBook ? isExternalPowerConnected : isCharging
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 1)
    }
}

struct BatteryMetricsSnapshot: Equatable, Sendable {
    let devices: [BatteryDeviceSnapshot]
    let sampledAt: Date

    init(devices: [BatteryDeviceSnapshot], sampledAt: Date = Date()) {
        self.devices = devices.sorted {
            if $0.kind.sortPriority != $1.kind.sortPriority {
                return $0.kind.sortPriority < $1.kind.sortPriority
            }
            if $0.name != $1.name {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.id < $1.id
        }
        self.sampledAt = sampledAt
    }

    static let empty = BatteryMetricsSnapshot(
        devices: [],
        sampledAt: .distantPast
    )

    var dockDevices: [BatteryDeviceSnapshot] {
        Array(devices.prefix(4))
    }
}
