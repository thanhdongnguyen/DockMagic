import AppKit
import ApplicationServices
import Observation
import SwiftUI

enum DockMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case dockActive
    case shelfDock

    var id: Self { self }
    var title: String {
        switch self {
        case .dockActive: "Dock Active"
        case .shelfDock: "Shelf Dock"
        }
    }
}

enum CustomDockEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case bottom, left, right
    var id: Self { self }
}

struct CustomDockSlot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var feature: DockFeature

    init(id: UUID = UUID(), feature: DockFeature) {
        self.id = id
        self.feature = feature
    }
}

struct CustomDockApplication: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var bundleIdentifier: String?
    var path: String

    init?(url: URL, bundleIdentifier: String? = nil) {
        guard url.isFileURL, url.pathExtension == "app",
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        let bundle = Bundle(url: url)
        self.bundleIdentifier = bundleIdentifier ?? bundle?.bundleIdentifier
        self.path = url.standardizedFileURL.path
        self.id = self.bundleIdentifier ?? self.path
    }

    var url: URL { URL(fileURLWithPath: path) }
    var title: String {
        FileManager.default.displayName(atPath: path)
            .replacingOccurrences(of: ".app", with: "")
    }
}

struct CustomDockStack: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var path: String
    init(id: UUID = UUID(), path: String) {
        self.id = id
        self.path = path
    }
    var url: URL { URL(fileURLWithPath: path) }
    var title: String { FileManager.default.displayName(atPath: path) }
}

struct CustomDockConfiguration: Codable, Equatable, Sendable {
    var initialized = false
    var preferredIconSize = 44.0
    var edge: CustomDockEdge = .bottom
    var displayID: UInt32?
    var magnificationEnabled = true
    var pinnedApps: [CustomDockApplication] = []
    var recentApps: [CustomDockApplication] = []
    var stacks: [CustomDockStack] = []
    var slots: [CustomDockSlot] = []
    var importWarning: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case initialized
        case preferredIconSize
        case edge
        case displayID
        case magnificationEnabled
        case pinnedApps
        case recentApps
        case stacks
        case slots
        case importWarning
    }

    /// Configurations written before magnification existed keep the former
    /// static behavior. Newly-created configurations use the property default
    /// above, while an explicitly persisted true/false value is never changed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        initialized = try container.decodeIfPresent(Bool.self, forKey: .initialized) ?? false
        preferredIconSize = try container.decodeIfPresent(
            Double.self, forKey: .preferredIconSize
        ) ?? 44
        edge = try container.decodeIfPresent(CustomDockEdge.self, forKey: .edge) ?? .bottom
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
        magnificationEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .magnificationEnabled
        ) ?? false
        pinnedApps = try container.decodeIfPresent(
            [CustomDockApplication].self, forKey: .pinnedApps
        ) ?? []
        recentApps = try container.decodeIfPresent(
            [CustomDockApplication].self, forKey: .recentApps
        ) ?? []
        stacks = try container.decodeIfPresent(
            [CustomDockStack].self, forKey: .stacks
        ) ?? []
        slots = try container.decodeIfPresent(
            [CustomDockSlot].self, forKey: .slots
        ) ?? []
        importWarning = try container.decodeIfPresent(String.self, forKey: .importWarning)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(initialized, forKey: .initialized)
        try container.encode(preferredIconSize, forKey: .preferredIconSize)
        try container.encode(edge, forKey: .edge)
        try container.encodeIfPresent(displayID, forKey: .displayID)
        try container.encode(magnificationEnabled, forKey: .magnificationEnabled)
        try container.encode(pinnedApps, forKey: .pinnedApps)
        try container.encode(recentApps, forKey: .recentApps)
        try container.encode(stacks, forKey: .stacks)
        try container.encode(slots, forKey: .slots)
        try container.encodeIfPresent(importWarning, forKey: .importWarning)
    }

    mutating func normalize() {
        preferredIconSize = preferredIconSize.isFinite
            ? min(128, max(16, preferredIconSize)) : 44
        var seenApps = Set<String>()
        pinnedApps = pinnedApps.filter {
            $0.id != "com.apple.finder"
                && $0.id != "com.apple.apps.launcher"
                && $0.id != "com.apple.launchpad.launcher"
                && seenApps.insert($0.id).inserted
        }
        var seenRecent = Set<String>()
        recentApps = recentApps.filter {
            !seenApps.contains($0.id) && seenRecent.insert($0.id).inserted
        }
        recentApps = Array(recentApps.prefix(3))
        slots = slots.filter {
            $0.feature != .dockMagic
                && DockFeature.availableCases.contains($0.feature)
        }
    }
}

struct CustomDockMagnificationItemID: Hashable, Sendable {
    let rawValue: String

    static func system(_ name: String) -> Self { .init(rawValue: "system.\(name)") }
    static func application(_ id: String) -> Self { .init(rawValue: "app.\(id)") }
    static let overflow = Self(rawValue: "overflow")
    static func stack(_ id: UUID) -> Self { .init(rawValue: "stack.\(id.uuidString)") }
    static func window(_ id: String) -> Self { .init(rawValue: "window.\(id)") }
    static let trash = Self(rawValue: "trash")
}

enum CustomDockMagnificationGroup: Hashable, Sendable {
    case beforeShelf
    case afterShelf
}

struct CustomDockMagnificationItem: Equatable {
    let id: CustomDockMagnificationItemID
    let frame: CGRect
    let group: CustomDockMagnificationGroup
}

struct CustomDockMagnificationTransform: Equatable {
    var scale: CGFloat
    var xOffset: CGFloat
    var yOffset: CGFloat
    var zIndex: Double

    static let identity = Self(scale: 1, xOffset: 0, yOffset: 0, zIndex: 0)
}

struct CustomDockMagnificationResult: Equatable {
    var transforms: [CustomDockMagnificationItemID: CustomDockMagnificationTransform]
    var activeItemID: CustomDockMagnificationItemID?

    func transform(for id: CustomDockMagnificationItemID) -> CustomDockMagnificationTransform {
        transforms[id] ?? .identity
    }
}

enum CustomDockMagnificationEngine {
    static let peakScale: CGFloat = 1.32
    static let radiusMultiplier: CGFloat = 1.75

    static func resolve(
        pointer: CGPoint?,
        items: [CustomDockMagnificationItem],
        shelfFrame: CGRect?,
        panelBounds: CGRect,
        iconSize: CGFloat,
        edge: CustomDockEdge,
        enabled: Bool,
        reduceMotion: Bool
    ) -> CustomDockMagnificationResult {
        let identities = Dictionary(uniqueKeysWithValues: items.map {
            ($0.id, CustomDockMagnificationTransform.identity)
        })
        guard enabled, !reduceMotion, let pointer, panelBounds.contains(pointer),
              let shelfFrame, !shelfFrame.insetBy(dx: -1, dy: -1).contains(pointer)
        else {
            return .init(transforms: identities, activeItemID: nil)
        }

        let vertical = edge != .bottom
        func mainCenter(_ frame: CGRect) -> CGFloat {
            vertical ? frame.midY : frame.midX
        }
        func mainLength(_ frame: CGRect) -> CGFloat {
            vertical ? frame.height : frame.width
        }
        func mainMinimum(_ frame: CGRect) -> CGFloat {
            vertical ? frame.minY : frame.minX
        }
        func mainMaximum(_ frame: CGRect) -> CGFloat {
            vertical ? frame.maxY : frame.maxX
        }
        let pointerMain = vertical ? pointer.y : pointer.x
        let shelfMinimum = mainMinimum(shelfFrame)
        let shelfMaximum = mainMaximum(shelfFrame)
        let group: CustomDockMagnificationGroup = pointerMain < shelfMinimum
            ? .beforeShelf : .afterShelf
        let groupItems = items.filter { $0.group == group }.sorted {
            mainCenter($0.frame) < mainCenter($1.frame)
        }
        guard !groupItems.isEmpty else {
            return .init(transforms: identities, activeItemID: nil)
        }

        let nearest = groupItems.min {
            abs(mainCenter($0.frame) - pointerMain)
                < abs(mainCenter($1.frame) - pointerMain)
        }!
        let radius = max(1, iconSize * radiusMultiplier)
        guard abs(mainCenter(nearest.frame) - pointerMain) <= radius else {
            return .init(transforms: identities, activeItemID: nil)
        }

        var nominalScales = Dictionary(uniqueKeysWithValues: groupItems.map { item in
            let distance = abs(mainCenter(item.frame) - pointerMain)
            let influence = distance < radius
                ? 0.5 + 0.5 * cos(.pi * distance / radius)
                : 0
            return (item.id, 1 + (peakScale - 1) * influence)
        })

        let panelCrossLength = vertical ? panelBounds.width : panelBounds.height
        for item in groupItems {
            let crossLength = vertical ? item.frame.width : item.frame.height
            let maximumScale = crossLength > 0 ? panelCrossLength / crossLength : 1
            nominalScales[item.id] = min(nominalScales[item.id] ?? 1, maximumScale)
        }

        let panelMainMinimum = mainMinimum(panelBounds) + 0.5
        let panelMainMaximum = mainMaximum(panelBounds) - 0.5
        let groupMinimum = group == .beforeShelf
            ? panelMainMinimum : shelfMaximum + 0.5
        let groupMaximum = group == .beforeShelf
            ? shelfMinimum - 0.5 : panelMainMaximum
        let availableLength = max(0, groupMaximum - groupMinimum)
        let anchorIndex = groupItems.firstIndex(where: { $0.id == nearest.id }) ?? 0

        func scaledValues(amplitude: CGFloat) -> [CustomDockMagnificationItemID: CGFloat] {
            Dictionary(uniqueKeysWithValues: groupItems.map { item in
                let nominal = nominalScales[item.id] ?? 1
                return (item.id, 1 + (nominal - 1) * amplitude)
            })
        }

        func desiredCenters(
            scales: [CustomDockMagnificationItemID: CGFloat]
        ) -> [CGFloat] {
            var centers = groupItems.map { mainCenter($0.frame) }
            centers[anchorIndex] = mainCenter(groupItems[anchorIndex].frame)
            if anchorIndex + 1 < groupItems.count {
                for index in (anchorIndex + 1)..<groupItems.count {
                    let previous = groupItems[index - 1]
                    let current = groupItems[index]
                    let baseGap = max(
                        0,
                        mainCenter(current.frame) - mainCenter(previous.frame)
                            - (mainLength(previous.frame) + mainLength(current.frame)) / 2
                    )
                    centers[index] = centers[index - 1]
                        + mainLength(previous.frame) * (scales[previous.id] ?? 1) / 2
                        + baseGap
                        + mainLength(current.frame) * (scales[current.id] ?? 1) / 2
                }
            }
            if anchorIndex > 0 {
                for index in stride(from: anchorIndex - 1, through: 0, by: -1) {
                    let current = groupItems[index]
                    let next = groupItems[index + 1]
                    let baseGap = max(
                        0,
                        mainCenter(next.frame) - mainCenter(current.frame)
                            - (mainLength(current.frame) + mainLength(next.frame)) / 2
                    )
                    centers[index] = centers[index + 1]
                        - mainLength(next.frame) * (scales[next.id] ?? 1) / 2
                        - baseGap
                        - mainLength(current.frame) * (scales[current.id] ?? 1) / 2
                }
            }
            return centers
        }

        func span(
            centers: [CGFloat],
            scales: [CustomDockMagnificationItemID: CGFloat]
        ) -> CGFloat {
            guard let first = groupItems.first, let last = groupItems.last else { return 0 }
            let minimum = centers[0]
                - mainLength(first.frame) * (scales[first.id] ?? 1) / 2
            let maximum = centers[centers.count - 1]
                + mainLength(last.frame) * (scales[last.id] ?? 1) / 2
            return maximum - minimum
        }

        var amplitude: CGFloat = 1
        var scales = scaledValues(amplitude: amplitude)
        var centers = desiredCenters(scales: scales)
        if span(centers: centers, scales: scales) > availableLength {
            var lower: CGFloat = 0
            var upper: CGFloat = 1
            for _ in 0..<12 {
                let candidate = (lower + upper) / 2
                let candidateScales = scaledValues(amplitude: candidate)
                let candidateCenters = desiredCenters(scales: candidateScales)
                if span(centers: candidateCenters, scales: candidateScales) <= availableLength {
                    lower = candidate
                } else {
                    upper = candidate
                }
            }
            amplitude = lower
            scales = scaledValues(amplitude: amplitude)
            centers = desiredCenters(scales: scales)
        }

        let first = groupItems[0]
        let last = groupItems[groupItems.count - 1]
        let visualMinimum = centers[0]
            - mainLength(first.frame) * (scales[first.id] ?? 1) / 2
        let visualMaximum = centers[centers.count - 1]
            + mainLength(last.frame) * (scales[last.id] ?? 1) / 2
        var groupShift: CGFloat = 0
        if visualMinimum < groupMinimum { groupShift += groupMinimum - visualMinimum }
        if visualMaximum + groupShift > groupMaximum {
            groupShift += groupMaximum - (visualMaximum + groupShift)
        }

        var transforms = identities
        for (index, item) in groupItems.enumerated() {
            let scale = scales[item.id] ?? 1
            let mainOffset = centers[index] + groupShift - mainCenter(item.frame)
            let crossRange: ClosedRange<CGFloat>
            switch edge {
            case .bottom:
                crossRange = (item.frame.maxY - item.frame.height * scale)...item.frame.maxY
            case .left:
                crossRange = item.frame.minX...(item.frame.minX + item.frame.width * scale)
            case .right:
                crossRange = (item.frame.maxX - item.frame.width * scale)...item.frame.maxX
            }
            let panelCrossMinimum = vertical ? panelBounds.minX : panelBounds.minY
            let panelCrossMaximum = vertical ? panelBounds.maxX : panelBounds.maxY
            var crossOffset: CGFloat = 0
            if crossRange.lowerBound < panelCrossMinimum {
                crossOffset += panelCrossMinimum - crossRange.lowerBound
            }
            if crossRange.upperBound + crossOffset > panelCrossMaximum {
                crossOffset += panelCrossMaximum - (crossRange.upperBound + crossOffset)
            }
            transforms[item.id] = .init(
                scale: scale,
                xOffset: vertical ? crossOffset : mainOffset,
                yOffset: vertical ? mainOffset : crossOffset,
                zIndex: scale > 1 ? 10 + Double(scale) : 0
            )
        }
        return .init(transforms: transforms, activeItemID: nearest.id)
    }
}

/// One-time read of Dock preferences. The tile dictionary is undocumented, so
/// failure is visible to the user and never changes the Apple Dock.
enum NativeDockImport {
    static func initialConfiguration(
        legacyFeatures: [DockFeature]
    ) -> CustomDockConfiguration {
        var result = CustomDockConfiguration()
        _ = CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        if let size = CFPreferencesCopyAppValue(
            "tilesize" as CFString, "com.apple.dock" as CFString
        ) as? NSNumber {
            result.preferredIconSize = size.doubleValue
        }
        if let orientation = CFPreferencesCopyAppValue(
            "orientation" as CFString, "com.apple.dock" as CFString
        ) as? String, let edge = CustomDockEdge(rawValue: orientation) {
            result.edge = edge
        }
        if let items = CFPreferencesCopyAppValue(
            "persistent-apps" as CFString, "com.apple.dock" as CFString
        ) as? [[String: Any]] {
            result.pinnedApps = items.compactMap(app)
            if !items.isEmpty && result.pinnedApps.isEmpty {
                result.importWarning = "Couldn't read Apple Dock apps. Add them manually."
            }
        } else {
            result.importWarning = "Couldn't read Apple Dock apps. Add them manually."
        }
        result.slots = legacyFeatures.map { CustomDockSlot(feature: $0) }
        result.initialized = true
        result.normalize()
        return result
    }

    private static func app(_ entry: [String: Any]) -> CustomDockApplication? {
        guard let data = entry["tile-data"] as? [String: Any] else { return nil }
        let identifier = data["bundle-identifier"] as? String
        if let identifier,
           let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: identifier
           ) {
            return CustomDockApplication(url: url, bundleIdentifier: identifier)
        }
        guard let file = data["file-data"] as? [String: Any],
              let raw = file["_CFURLString"] as? String else { return nil }
        let url = URL(string: raw)?.isFileURL == true
            ? URL(string: raw) : URL(fileURLWithPath: raw)
        guard let url else { return nil }
        return CustomDockApplication(url: url, bundleIdentifier: identifier)
    }
}

enum CustomDockTrashState: Equatable {
    case unknown, empty, full
}

struct CustomDockMinimizedWindow: Identifiable {
    let id: String
    let title: String
    let appName: String
    let appPath: String?
    let processID: pid_t
    let element: AXUIElement
}

@MainActor
@Observable
final class CustomDockRuntime {
    private(set) var runningApps: [CustomDockApplication] = []
    private(set) var minimizedWindows: [CustomDockMinimizedWindow] = []
    private(set) var trashState: CustomDockTrashState = .unknown

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var trashRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastTrashRefresh = Date.distantPast
    private let preferences: DockPreferencesStore

    init(preferences: DockPreferencesStore) {
        self.preferences = preferences
    }

    func start() {
        guard refreshTimer == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ] {
            observers.append(center.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.recordActivation(notification)
                    self?.refresh()
                }
            })
        }
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        trashRefreshTask?.cancel()
        trashRefreshTask = nil
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
        runningApps = []
        minimizedWindows = []
    }

    func refresh() {
#if DEBUG
        if ProcessInfo.processInfo.environment[
            "DockMagicUITestHideRuntimeDockItems"
        ] == "1" {
            runningApps = []
            minimizedWindows = []
            if Date().timeIntervalSince(lastTrashRefresh) > 5 {
                lastTrashRefresh = Date()
                refreshTrash()
            }
            return
        }
#endif
        runningApps = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular,
                  app.bundleIdentifier != "com.hypevibe.DockMagic",
                  let url = app.bundleURL else { return nil }
            return CustomDockApplication(
                url: url, bundleIdentifier: app.bundleIdentifier
            )
        }
        if AXIsProcessTrusted() { refreshMinimizedWindows() }
        if Date().timeIntervalSince(lastTrashRefresh) > 5 {
            lastTrashRefresh = Date()
            refreshTrash()
        }
    }

    private func recordActivation(_ notification: Notification) {
        guard notification.name == NSWorkspace.didActivateApplicationNotification,
              let running = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
              ] as? NSRunningApplication,
              running.activationPolicy == .regular,
              let url = running.bundleURL,
              let app = CustomDockApplication(
                url: url, bundleIdentifier: running.bundleIdentifier
              ),
              !["com.apple.finder", "com.hypevibe.DockMagic"].contains(app.id)
        else { return }
        preferences.recordCustomDockRecentApp(app)
    }

    private func refreshMinimizedWindows() {
        var result: [CustomDockMinimizedWindow] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                application, kAXWindowsAttribute as CFString, &value
            ) == .success, let windows = value as? [AXUIElement] else { continue }
            for (index, window) in windows.enumerated() {
                var minimized: CFTypeRef?
                guard AXUIElementCopyAttributeValue(
                    window, kAXMinimizedAttribute as CFString, &minimized
                ) == .success, (minimized as? Bool) == true else { continue }
                var titleValue: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(
                    window, kAXTitleAttribute as CFString, &titleValue
                )
                result.append(CustomDockMinimizedWindow(
                    id: "\(app.processIdentifier)-\(index)",
                    title: (titleValue as? String) ?? "Minimized window",
                    appName: app.localizedName ?? "App",
                    appPath: app.bundleURL?.path,
                    processID: app.processIdentifier,
                    element: window
                ))
            }
        }
        minimizedWindows = result
    }

    func restore(_ window: CustomDockMinimizedWindow) {
        AXUIElementSetAttributeValue(
            window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse
        )
        AXUIElementPerformAction(
            window.element, kAXRaiseAction as CFString
        )
        NSRunningApplication(processIdentifier: window.processID)?
            .activate(options: [])
        refresh()
    }

    private func refreshTrash() {
        guard trashRefreshTask == nil else { return }
        trashRefreshTask = Task { [weak self] in
            let state = await Task.detached(priority: .utility) {
                Self.readTrashState()
            }.value
            guard !Task.isCancelled, let self else { return }
            trashState = state
            trashRefreshTask = nil
        }
    }

    nonisolated private static func readTrashState() -> CustomDockTrashState {
        var error: NSDictionary?
        let script = NSAppleScript(source:
            "tell application \"Finder\" to count items of trash"
        )
        let answer = script?.executeAndReturnError(&error)
        guard error == nil, let count = answer?.int32Value else {
            return .unknown
        }
        return count > 0 ? .full : .empty
    }

    @discardableResult
    func openTrash() -> Bool {
        let trashURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
        if NSWorkspace.shared.open(trashURL) { return true }

        var error: NSDictionary?
        NSAppleScript(source:
            "tell application \"Finder\" to activate\n"
                + "tell application \"Finder\" to open trash"
        )?
            .executeAndReturnError(&error)
        return error == nil
    }

    func recycle(
        _ urls: [URL],
        completion: (([URL: URL], Error?) -> Void)? = nil
    ) {
        NSWorkspace.shared.recycle(urls) { [weak self] recycled, error in
            #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            if environment["DockMagicUITesting"] == "1",
               let resultPath = environment["DockMagicUITestTrashDropResult"],
               let destination = recycled.values.first {
                try? Data(destination.path.utf8).write(
                    to: URL(fileURLWithPath: resultPath),
                    options: .atomic
                )
            }
            #endif
            completion?(recycled, error)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if error == nil, !recycled.isEmpty {
                    trashState = .full
                } else {
                    refreshTrash()
                }
            }
        }
    }
}
