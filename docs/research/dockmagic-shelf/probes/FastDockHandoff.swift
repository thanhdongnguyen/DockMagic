import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

func attr(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name, &value) == .success ? value : nil
}

func point(_ element: AXUIElement) -> CGPoint? {
    guard let value = attr(element, kAXPositionAttribute as CFString),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
}

func size(_ element: AXUIElement) -> CGSize? {
    guard let value = attr(element, kAXSizeAttribute as CFString),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
}

func probeState() -> (visible: Bool, alpha: Double, bounds: CGRect?) {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
        as? [[String: Any]] ?? []
    guard let probe = windows.first(where: {
        ($0[kCGWindowOwnerName as String] as? String) == "ReplacementDockProbe"
    }) else { return (false, 0, nil) }
    let rawBounds = probe[kCGWindowBounds as String] as? [String: Any]
    let bounds = rawBounds.flatMap { values -> CGRect? in
        guard let x = values["X"] as? NSNumber,
              let y = values["Y"] as? NSNumber,
              let width = values["Width"] as? NSNumber,
              let height = values["Height"] as? NSNumber else { return nil }
        return CGRect(x: x.doubleValue, y: y.doubleValue,
                      width: width.doubleValue, height: height.doubleValue)
    }
    return (true, probe[kCGWindowAlpha as String] as? Double ?? 1, bounds)
}

guard AXIsProcessTrusted() else { fatalError("Dock AX unavailable") }
func dockList() -> AXUIElement? {
    guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
        .first?.processIdentifier else { return nil }
    let root = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(root, 0.1)
    guard let children = attr(root, kAXChildrenAttribute as CFString) as? [AXUIElement],
          let list = children.first(where: {
              (attr($0, kAXRoleAttribute as CFString) as? String) == "AXList"
          }) else { return nil }
    AXUIElementSetMessagingTimeout(list, 0.1)
    return list
}
var list = dockList()
let screenBottom = (NSScreen.screens.map { $0.frame.maxY }.max() ?? 1080)
let screenLeft = NSScreen.screens.map { $0.frame.minX }.min() ?? 0
let screenRight = NSScreen.screens.map { $0.frame.maxX }.max() ?? 1920
let edge = CommandLine.arguments.dropFirst(2).first ?? "bottom"
var remotePort: CFMessagePort?
for _ in 0..<30 {
    remotePort = CFMessagePortCreateRemote(nil, "DockMagicProbeHandoff" as CFString)
    if remotePort != nil { break }
    Thread.sleep(forTimeInterval: 0.1)
}
guard let handoffPort = remotePort else { fatalError("Probe message port unavailable") }
let duration = Double(CommandLine.arguments.dropFirst().first ?? "30") ?? 30
let end = ProcessInfo.processInfo.systemUptime + duration
var lastVisible: Bool?
var transitionCount = 0
var samples = 0
var errorCount = 0
var overlapCandidateSamples = 0
var overlapGeometrySamples = 0
var lastHeartbeat = 0.0
var lastWindowSample = 0.0
var lines = ["time,event,dockX,dockY,probeVisible,probeAlpha,alphaLatencyMs,windowLatencyMs,sendStatus"]
func intersectsDock(_ list: AXUIElement, probeBounds: CGRect?) -> (Bool, CGPoint?) {
    guard let probeBounds, let position = point(list), let dimensions = size(list) else {
        return (false, nil)
    }
    return (CGRect(origin: position, size: dimensions).intersects(probeBounds), position)
}
func autoHideEnabled() -> Bool? {
    let domain = "com.apple.dock" as CFString
    guard CFPreferencesAppSynchronize(domain),
          let value = CFPreferencesCopyAppValue("autohide" as CFString, domain) else {
        return nil
    }
    if CFGetTypeID(value) == CFBooleanGetTypeID() {
        return CFBooleanGetValue((value as! CFBoolean))
    }
    return (value as? NSNumber)?.boolValue
}
func foregroundContext() -> (fullScreen: Bool, systemSettings: Bool) {
    guard let app = NSWorkspace.shared.frontmostApplication else { return (false, false) }
    let systemSettings = app.bundleIdentifier == "com.apple.systempreferences"
    let root = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 0.1)
    let focused = attr(root, kAXFocusedWindowAttribute as CFString)
    let focusedWindow = focused.flatMap {
        CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil
    }
    guard let window = focusedWindow ??
        (attr(root, kAXWindowsAttribute as CFString) as? [AXUIElement])?.first else {
        return (false, systemSettings)
    }
    return ((attr(window, "AXFullScreen" as CFString) as? Bool) == true, systemSettings)
}
var preferenceAutoHide: Bool?
var nextPreferenceRead = 0.0
var nextFullScreenRead = 0.0
var fullScreenState: Bool?
var fullScreenTransitions = 0
var systemSettingsState: Bool?
var systemSettingsTransitions = 0
func sendVisibility(_ visible: Bool, at time: TimeInterval, force: Bool = false) -> Int32 {
    guard force || time - lastHeartbeat >= 0.025 else { return 0 }
    lastHeartbeat = time
    return CFMessagePortSendRequest(handoffPort, visible ? 1 : 0,
                                    nil, 0.1, 0, nil, nil)
}
while ProcessInfo.processInfo.systemUptime < end {
    let now = ProcessInfo.processInfo.systemUptime
    if now >= nextFullScreenRead {
        let context = foregroundContext()
        if fullScreenState != context.fullScreen {
            lines.append("\(now),full-screen-\(context.fullScreen),0,0,false,0,-1,-1,0")
            fullScreenTransitions += 1
            fullScreenState = context.fullScreen
        }
        if systemSettingsState != context.systemSettings {
            lines.append("\(now),system-settings-\(context.systemSettings),0,0,false,0,-1,-1,0")
            systemSettingsTransitions += 1
            systemSettingsState = context.systemSettings
        }
        _ = CFMessagePortSendRequest(handoffPort, context.fullScreen ? 3 : 4, nil, 0.1, 0, nil, nil)
        _ = CFMessagePortSendRequest(handoffPort, context.systemSettings ? 5 : 6,
                                     nil, 0.1, 0, nil, nil)
        nextFullScreenRead = now + 0.1
    }
    if now >= nextPreferenceRead {
        let observedPreference = autoHideEnabled()
        if observedPreference != preferenceAutoHide {
            lines.append("\(now),pref-autohide-\(observedPreference.map(String.init) ?? "unknown"),0,0,false,0,-1,-1,0")
            preferenceAutoHide = observedPreference
        }
        nextPreferenceRead = now + 0.02
    }
    if list == nil { list = dockList() }
    guard let currentList = list, let position = point(currentList) else {
        errorCount += 1
        // Dock restart or AX loss: keep the replacement hidden until a fresh
        // Dock AXList proves that the system Dock is offscreen.
        _ = sendVisibility(true, at: now, force: lastVisible != true)
        lastVisible = true
        list = nil
        Thread.sleep(forTimeInterval: 0.025)
        continue
    }
    samples += 1
    let dockWidth = size(currentList)?.width ?? 46
    let frameVisible = edge == "left" ? position.x > screenLeft - dockWidth + 0.5
        : edge == "right" ? position.x < screenRight - 0.5
        : position.y < screenBottom - 0.5
    let visible = preferenceAutoHide == false || frameVisible
    if lastVisible != visible {
        let sendStatus = sendVisibility(visible, at: now, force: true)
        transitionCount += 1
        var windowLatency = -1.0
        var alphaLatency = -1.0
        if visible {
            let deadline = now + 0.4
            while ProcessInfo.processInfo.systemUptime < deadline {
                let state = probeState()
                if state.visible && state.alpha > 0.001 {
                    overlapCandidateSamples += 1
                    let (intersects, livePosition) = intersectsDock(currentList, probeBounds: state.bounds)
                    if intersects { overlapGeometrySamples += 1 }
                    let observed = livePosition ?? position
                    lines.append("\(ProcessInfo.processInfo.systemUptime),\(intersects ? "overlap-geometry" : "overlap-candidate"),\(observed.x),\(observed.y),true,\(state.alpha),-1,-1,0")
                }
                let elapsed = (ProcessInfo.processInfo.systemUptime - now) * 1000
                if alphaLatency < 0 && state.alpha <= 0.001 { alphaLatency = elapsed }
                if windowLatency < 0 && !state.visible { windowLatency = elapsed }
                if alphaLatency >= 0 && windowLatency >= 0 { break }
                _ = sendVisibility(true, at: ProcessInfo.processInfo.systemUptime)
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
        let finalState = probeState()
        lines.append("\(now),\(visible ? "show" : "hide"),\(position.x),\(position.y),\(finalState.visible),\(finalState.alpha),\(alphaLatency),\(windowLatency),\(sendStatus)")
        lastVisible = visible
    } else {
        _ = sendVisibility(visible, at: now)
        if visible && now - lastWindowSample >= 0.008 {
            lastWindowSample = now
            let state = probeState()
            if state.visible && state.alpha > 0.001 {
                overlapCandidateSamples += 1
                let (intersects, livePosition) = intersectsDock(currentList, probeBounds: state.bounds)
                if intersects { overlapGeometrySamples += 1 }
                let observed = livePosition ?? position
                lines.append("\(now),\(intersects ? "overlap-geometry" : "overlap-candidate"),\(observed.x),\(observed.y),true,\(state.alpha),-1,-1,0")
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.001)
}
let stamp = ISO8601DateFormatter().string(from: Date())
    .replacingOccurrences(of: ":", with: "-")
let directory = "/private/tmp/dockmagic-shelf-probe"
let path = "\(directory)/fast-handoff-\(edge)-\(stamp).csv"
let output = lines.joined(separator: "\n").appending("\n")
try output.write(toFile: path, atomically: true, encoding: .utf8)
try output.write(toFile: "\(directory)/fast-handoff.csv", atomically: true, encoding: .utf8)
print("file=\(path) samples=\(samples) errors=\(errorCount) transitions=\(transitionCount) fullScreenTransitions=\(fullScreenTransitions) systemSettingsTransitions=\(systemSettingsTransitions) overlapCandidateSamples=\(overlapCandidateSamples) overlapGeometrySamples=\(overlapGeometrySamples)")
