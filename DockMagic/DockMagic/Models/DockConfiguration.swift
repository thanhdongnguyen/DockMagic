import AppKit
import SwiftUI

enum DockFeature: String, CaseIterable, Codable, Identifiable, Sendable {
    case dockMagic
    case systemMetrics
    case network
    case storage
    case weather
    case clock
    case batteries
    case github
    case codex
    case claudeCode
    case searchConsole

    static let storageKey = "DockMagicActiveFeature"

    var id: Self { self }

    var title: String {
        switch self {
        case .dockMagic:
            "DockMagic"
        case .systemMetrics:
            "CPU & RAM"
        case .network:
            "Network"
        case .storage:
            "Storage"
        case .weather:
            "Weather"
        case .clock:
            "Clock"
        case .batteries:
            "Batteries"
        case .github:
            "GitHub"
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
        case .searchConsole:
            "Search Console"
        }
    }

    var detail: String {
        switch self {
        case .dockMagic:
            "DockMagic logo"
        case .systemMetrics:
            "Live system usage"
        case .network:
            "Live download and upload throughput"
        case .storage:
            "Startup disk usage"
        case .weather:
            "Current conditions from Open-Meteo"
        case .clock:
            "Local time or another location"
        case .batteries:
            "Battery levels for your Mac and connected devices"
        case .github:
            "Repository stars and forks"
        case .codex:
            "Remaining usage limits"
        case .claudeCode:
            "Remaining usage limits"
        case .searchConsole:
            "Google Search clicks and impressions"
        }
    }

    var systemImage: String {
        switch self {
        case .dockMagic:
            "app.fill"
        case .systemMetrics:
            "cpu"
        case .network:
            "network"
        case .storage:
            "internaldrive.fill"
        case .weather:
            "cloud.sun.fill"
        case .clock:
            "clock.fill"
        case .batteries:
            "battery.75percent"
        case .github:
            "point.3.connected.trianglepath.dotted"
        case .codex:
            "sparkles"
        case .claudeCode:
            "chevron.left.forwardslash.chevron.right"
        case .searchConsole:
            "magnifyingglass"
        }
    }

    var hasHoverDashboard: Bool {
        switch self {
        case .systemMetrics, .weather, .codex, .claudeCode:
            true
        case .dockMagic, .network, .storage, .clock, .batteries,
             .github, .searchConsole:
            false
        }
    }
}

enum DockClockDisplayStyle: String, CaseIterable, Codable, Identifiable,
    Sendable
{
    case analog
    case digital
    case splitFlap

    var id: Self { self }

    var title: String {
        switch self {
        case .analog:
            "Analog"
        case .digital:
            "Digital"
        case .splitFlap:
            "Split-flap"
        }
    }

    var detail: String {
        switch self {
        case .analog:
            "Show hour, minute, and second hands."
        case .digital:
            "Show large stacked 24-hour digits."
        case .splitFlap:
            "Show four flat mechanical-style digit cells."
        }
    }

    var systemImage: String {
        switch self {
        case .analog:
            "clock"
        case .digital:
            "textformat.123"
        case .splitFlap:
            "rectangle.split.2x2"
        }
    }
}

struct DockClockConfiguration: Codable, Equatable, Sendable {
    private(set) var displayStyle: DockClockDisplayStyle
    private(set) var followsSystemTimeZone: Bool
    private(set) var timeZoneIdentifier: String

    init(
        displayStyle: DockClockDisplayStyle = .digital,
        followsSystemTimeZone: Bool = true,
        timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) {
        self.displayStyle = displayStyle
        self.followsSystemTimeZone = followsSystemTimeZone
        self.timeZoneIdentifier = Self.normalizedTimeZoneIdentifier(
            timeZoneIdentifier
        )
    }

    var resolvedTimeZone: TimeZone {
        if followsSystemTimeZone {
            return .autoupdatingCurrent
        }
        return TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
    }

    var effectiveTimeZoneIdentifier: String {
        resolvedTimeZone.identifier
    }

    mutating func setDisplayStyle(_ value: DockClockDisplayStyle) {
        displayStyle = value
    }

    mutating func setFollowsSystemTimeZone(_ value: Bool) {
        followsSystemTimeZone = value
    }

    mutating func setTimeZoneIdentifier(_ value: String) {
        timeZoneIdentifier = Self.normalizedTimeZoneIdentifier(value)
    }

    func presentationDate(for date: Date) -> Date {
        let interval = date.timeIntervalSince1970
        let unit: TimeInterval = displayStyle == .analog ? 1 : 60
        return Date(timeIntervalSince1970: floor(interval / unit) * unit)
    }

    private static func normalizedTimeZoneIdentifier(_ value: String) -> String {
        guard TimeZone(identifier: value) != nil else {
            return TimeZone.autoupdatingCurrent.identifier
        }
        return value
    }

    private enum CodingKeys: String, CodingKey {
        case displayStyle
        case followsSystemTimeZone
        case timeZoneIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayStyle: try container.decodeIfPresent(
                DockClockDisplayStyle.self,
                forKey: .displayStyle
            ) ?? .digital,
            followsSystemTimeZone: try container.decodeIfPresent(
                Bool.self,
                forKey: .followsSystemTimeZone
            ) ?? true,
            timeZoneIdentifier: try container.decodeIfPresent(
                String.self,
                forKey: .timeZoneIdentifier
            ) ?? TimeZone.autoupdatingCurrent.identifier
        )
    }
}

enum DockClockFormatting {
    static func locationTitle(for timeZone: TimeZone) -> String {
        locationTitle(for: timeZone.identifier)
    }

    static func locationTitle(for identifier: String) -> String {
        let components = identifier.split(separator: "/")
        let city = components.last.map(String.init) ?? identifier
        return city.replacingOccurrences(of: "_", with: " ")
    }

    static func regionTitle(for identifier: String) -> String? {
        let components = identifier.split(separator: "/")
        guard components.count > 1 else {
            return nil
        }
        return String(components.first!).replacingOccurrences(of: "_", with: " ")
    }

    static func offsetTitle(for timeZone: TimeZone, at date: Date) -> String {
        let totalMinutes = timeZone.secondsFromGMT(for: date) / 60
        let sign = totalMinutes >= 0 ? "+" : "−"
        let absoluteMinutes = abs(totalMinutes)
        return String(
            format: "UTC%@%02d:%02d",
            sign,
            absoluteMinutes / 60,
            absoluteMinutes % 60
        )
    }
}

enum DockDisplayStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case chart
    case numeric

    var id: Self { self }

    var title: String {
        switch self {
        case .chart:
            "Chart"
        case .numeric:
            "Numbers"
        }
    }

    var detail: String {
        switch self {
        case .chart:
            "Show progress as rings."
        case .numeric:
            "Show the current values as large numbers."
        }
    }

    var systemImage: String {
        switch self {
        case .chart:
            "chart.pie"
        case .numeric:
            "number"
        }
    }
}

struct DockColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.normalized(red)
        self.green = Self.normalized(green)
        self.blue = Self.normalized(blue)
        self.alpha = Self.normalized(alpha)
    }

    @MainActor
    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(
            red: resolved.redComponent,
            green: resolved.greenComponent,
            blue: resolved.blueComponent,
            alpha: resolved.alphaComponent
        )
    }

    var color: Color {
        Color(
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }

    var hex: String {
        let red = Int((red * 255).rounded())
        let green = Int((green * 255).rounded())
        let blue = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        return min(max(value, 0), 1)
    }
}

struct DockRingAppearance: Codable, Equatable, Sendable {
    static let minimumOuterWidth = 0.06
    static let maximumOuterWidth = 0.16
    static let minimumInnerWidth = 0.08
    static let maximumInnerWidth = 0.22
    static let maximumCombinedWidth = 0.30

    var outerColor: DockColor
    var innerColor: DockColor
    private(set) var displayStyle: DockDisplayStyle
    private(set) var outerWidth: Double
    private(set) var innerWidth: Double

    init(
        outerColor: DockColor,
        innerColor: DockColor,
        outerWidth: Double,
        innerWidth: Double,
        displayStyle: DockDisplayStyle = .chart
    ) {
        self.outerColor = outerColor
        self.innerColor = innerColor
        self.displayStyle = displayStyle
        self.outerWidth = Self.clamp(
            outerWidth,
            minimum: Self.minimumOuterWidth,
            maximum: Self.maximumOuterWidth
        )
        self.innerWidth = Self.clamp(
            innerWidth,
            minimum: Self.minimumInnerWidth,
            maximum: Self.maximumInnerWidth
        )
        normalizeCombinedWidth(preferOuter: true)
    }

    mutating func setDisplayStyle(_ value: DockDisplayStyle) {
        displayStyle = value
    }

    mutating func setOuterWidth(_ value: Double) {
        outerWidth = Self.clamp(
            value,
            minimum: Self.minimumOuterWidth,
            maximum: Self.maximumOuterWidth
        )
        normalizeCombinedWidth(preferOuter: true)
    }

    mutating func setInnerWidth(_ value: Double) {
        innerWidth = Self.clamp(
            value,
            minimum: Self.minimumInnerWidth,
            maximum: Self.maximumInnerWidth
        )
        normalizeCombinedWidth(preferOuter: false)
    }

    private mutating func normalizeCombinedWidth(preferOuter: Bool) {
        let overflow = outerWidth + innerWidth - Self.maximumCombinedWidth
        guard overflow > 0 else {
            return
        }

        if preferOuter {
            innerWidth = max(Self.minimumInnerWidth, innerWidth - overflow)
        } else {
            outerWidth = max(Self.minimumOuterWidth, outerWidth - overflow)
        }
    }

    private static func clamp(
        _ value: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        guard value.isFinite else {
            return minimum
        }

        return min(max(value, minimum), maximum)
    }

    private enum CodingKeys: String, CodingKey {
        case outerColor
        case innerColor
        case outerWidth
        case innerWidth
        case displayStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            outerColor: try container.decode(DockColor.self, forKey: .outerColor),
            innerColor: try container.decode(DockColor.self, forKey: .innerColor),
            outerWidth: try container.decode(Double.self, forKey: .outerWidth),
            innerWidth: try container.decode(Double.self, forKey: .innerWidth),
            displayStyle: try container.decodeIfPresent(
                DockDisplayStyle.self,
                forKey: .displayStyle
            ) ?? .chart
        )
    }
}

struct DockSingleRingAppearance: Codable, Equatable, Sendable {
    static let minimumWidth = 0.08
    static let maximumWidth = 0.22

    var color: DockColor
    private(set) var displayStyle: DockDisplayStyle
    private(set) var width: Double

    init(
        color: DockColor,
        width: Double,
        displayStyle: DockDisplayStyle = .chart
    ) {
        self.color = color
        self.displayStyle = displayStyle
        self.width = Self.clamped(width)
    }

    mutating func setDisplayStyle(_ value: DockDisplayStyle) {
        displayStyle = value
    }

    mutating func setWidth(_ value: Double) {
        width = Self.clamped(value)
    }

    private static func clamped(_ value: Double) -> Double {
        guard value.isFinite else {
            return minimumWidth
        }
        return min(max(value, minimumWidth), maximumWidth)
    }

    private enum CodingKeys: String, CodingKey {
        case color
        case width
        case displayStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            color: try container.decode(DockColor.self, forKey: .color),
            width: try container.decode(Double.self, forKey: .width),
            displayStyle: try container.decodeIfPresent(
                DockDisplayStyle.self,
                forKey: .displayStyle
            ) ?? .chart
        )
    }
}

struct DockNetworkAppearance: Codable, Equatable, Sendable {
    var downloadColor: DockColor
    var uploadColor: DockColor
}

struct DockGitHubAppearance: Codable, Equatable, Sendable {
    var starColor: DockColor
    var forkColor: DockColor
    private(set) var displayStyle: DockDisplayStyle

    init(
        starColor: DockColor,
        forkColor: DockColor,
        displayStyle: DockDisplayStyle = .chart
    ) {
        self.starColor = starColor
        self.forkColor = forkColor
        self.displayStyle = displayStyle
    }

    mutating func setDisplayStyle(_ value: DockDisplayStyle) {
        displayStyle = value
    }
}

enum DockFeatureDefaults {
    static let clockConfiguration = DockClockConfiguration()

    static let systemMetricsAppearance = DockRingAppearance(
        outerColor: DockColor(red: 1, green: 0.552_941, blue: 0.156_863),
        innerColor: DockColor(red: 0, green: 0.752_941, blue: 0.909_804),
        outerWidth: 0.12,
        innerWidth: 0.18
    )

    static let networkAppearance = DockNetworkAppearance(
        downloadColor: DockColor(red: 0, green: 0.752_941, blue: 0.909_804),
        uploadColor: DockColor(red: 1, green: 0.552_941, blue: 0.156_863)
    )

    static let storageAppearance = DockSingleRingAppearance(
        color: DockColor(red: 0.796_078, green: 0.188_235, blue: 0.878_431),
        width: 0.16
    )

    static let githubAppearance = DockGitHubAppearance(
        starColor: DockColor(red: 1, green: 0.729_412, blue: 0.196_078),
        forkColor: DockColor(red: 0.258_824, green: 0.776_471, blue: 0.968_627)
    )

    static let codexAppearance = DockRingAppearance(
        outerColor: DockColor(red: 0, green: 0.784_314, blue: 0.701_961),
        innerColor: DockColor(red: 0.796_078, green: 0.188_235, blue: 0.878_431),
        outerWidth: 0.12,
        innerWidth: 0.18
    )

    static let claudeCodeAppearance = DockRingAppearance(
        outerColor: DockColor(red: 217 / 255, green: 119 / 255, blue: 87 / 255),
        innerColor: DockColor(red: 217 / 255, green: 119 / 255, blue: 87 / 255),
        outerWidth: 0.12,
        innerWidth: 0.18
    )
}

enum DockTilePresentation: Equatable, Sendable {
    case dockMagic
    case systemMetrics(
        snapshot: SystemMetricsSnapshot,
        appearance: DockRingAppearance,
        errorDescription: String?
    )
    case network(
        history: [NetworkMetricsSnapshot],
        appearance: DockNetworkAppearance,
        errorDescription: String?
    )
    case storage(
        snapshot: StorageMetricsSnapshot,
        appearance: DockSingleRingAppearance,
        errorDescription: String?
    )
    case weather(state: WeatherState)
    case clock(date: Date, configuration: DockClockConfiguration)
    case batteries(snapshot: BatteryMetricsSnapshot, errorDescription: String?)
    case github(
        history: [GitHubRepositorySnapshot],
        appearance: DockGitHubAppearance,
        errorDescription: String?
    )
    case codex(
        state: CodexUsageState,
        appearance: DockRingAppearance
    )
    case claudeCode(
        state: ClaudeCodeUsageState,
        appearance: DockRingAppearance
    )
    case searchConsole(
        state: SearchConsoleState,
        configuration: SearchConsoleConfiguration
    )
}
