import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

private func attribute(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key, &value) == .success ? value : nil
}

private func settingsAutoHideCheckboxFrame() -> CGRect? {
    guard let process = NSRunningApplication.runningApplications(withBundleIdentifier:
        "com.apple.systempreferences").first else { return nil }
    let app = AXUIElementCreateApplication(process.processIdentifier)
    let windows = attribute(app, kAXWindowsAttribute as CFString) as? [AXUIElement] ?? []
    guard let window = windows.first(where: {
        (attribute($0, kAXTitleAttribute as CFString) as? String) == "Desktop & Dock"
    }) else { return nil }
    var checkbox: AXUIElement?
    func visit(_ element: AXUIElement, depth: Int) {
        guard depth <= 15, checkbox == nil else { return }
        let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
        for (index, child) in children.enumerated() {
            if (attribute(child, kAXValueAttribute as CFString) as? String) ==
                "Automatically hide and show the Dock", index + 1 < children.count,
                (attribute(children[index + 1], kAXRoleAttribute as CFString) as? String) ==
                    "AXCheckBox" {
                checkbox = children[index + 1]
                break
            }
            visit(child, depth: depth + 1)
        }
    }
    visit(window, depth: 0)
    guard let checkbox,
          let positionValue = attribute(checkbox, kAXPositionAttribute as CFString),
          let sizeValue = attribute(checkbox, kAXSizeAttribute as CFString),
          CFGetTypeID(positionValue) == AXValueGetTypeID(),
          CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
          AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: position, size: size)
}

private func displayBounds(for edge: String) -> CGRect? {
    var ids = [CGDirectDisplayID](repeating: 0, count: 32)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success,
          count > 0 else { return nil }
    let active = Array(ids.prefix(Int(count)))
    if edge == "bottom" { return CGDisplayBounds(CGMainDisplayID()) }
    let bounds = active.map(CGDisplayBounds)
    return edge == "left" ? bounds.min(by: { $0.minX < $1.minX })
        : bounds.max(by: { $0.maxX < $1.maxX })
}

private final class Preflight {
    let checkboxFrame: CGRect?
    let edge: String?
    let edgeBounds: CGRect?
    let port: CFMessagePort
    var intercepted = 0
    var edgeIntercepted = 0
    var failures = 0
    private var edgeArmed = true

    init(checkboxFrame: CGRect?, edge: String?, edgeBounds: CGRect?, port: CFMessagePort) {
        self.checkboxFrame = checkboxFrame
        self.edge = edge
        self.edgeBounds = edgeBounds
        self.port = port
    }

    private func preempt(kind: String) {
        let begin = ProcessInfo.processInfo.systemUptime
        var reply: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(port, 2, nil, 0.05, 0.1,
                                              "kCFRunLoopDefaultMode" as CFString, &reply)
        let acknowledged = reply?.takeRetainedValue() != nil
        let elapsed = (ProcessInfo.processInfo.systemUptime - begin) * 1000
        intercepted += 1
        if kind == "edge" { edgeIntercepted += 1 }
        if status != kCFMessagePortSuccess || !acknowledged { failures += 1 }
        print("\(kind) uptime=\(begin) sendStatus=\(status) acknowledged=\(acknowledged) latencyMs=\(elapsed)")
        fflush(stdout)
    }

    func handle(type: CGEventType, event: CGEvent) {
        let location = event.location
        if type == .leftMouseDown,
           let checkboxFrame,
           checkboxFrame.contains(location),
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier ==
               "com.apple.systempreferences" {
            preempt(kind: "click")
        }
        guard type == .mouseMoved || type == .leftMouseDragged,
              let edge, let edgeBounds else { return }
        let inside = edgeBounds.insetBy(dx: -1, dy: -1).contains(location)
        let distance = edge == "left" ? location.x - edgeBounds.minX
            : edge == "right" ? edgeBounds.maxX - location.x
            : edgeBounds.maxY - location.y
        if !inside || distance > 60 {
            edgeArmed = true
        } else if distance >= 0, distance <= 12, edgeArmed {
            edgeArmed = false
            preempt(kind: "edge")
        }
    }
}

private func eventCallback(_ proxy: CGEventTapProxy, _ type: CGEventType,
                           _ event: CGEvent, _ info: UnsafeMutableRawPointer?)
    -> Unmanaged<CGEvent>? {
    if let info {
        let preflight = Unmanaged<Preflight>.fromOpaque(info).takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            preflight.failures += 1
            print("tapDisabled type=\(type.rawValue)")
            fflush(stdout)
        } else {
            preflight.handle(type: type, event: event)
        }
    }
    return Unmanaged.passUnretained(event)
}

let axTrusted = AXIsProcessTrusted()
let canListen = CGPreflightListenEventAccess()
let duration = Double(CommandLine.arguments.dropFirst().first ?? "12") ?? 12
let mode = CommandLine.arguments.dropFirst(2).first ?? "checkbox"
let edge = CommandLine.arguments.dropFirst(3).first ?? "bottom"
guard ["checkbox", "edge", "all"].contains(mode),
      ["bottom", "left", "right"].contains(edge) else {
    fatalError("Usage: DockInputPreflight <seconds> [checkbox|edge|all] [bottom|left|right]")
}
let checkboxFrame = mode == "edge" ? nil : settingsAutoHideCheckboxFrame()
let edgeBounds = mode == "checkbox" ? nil : displayBounds(for: edge)
print("preflight ax=\(axTrusted) listen=\(canListen) mode=\(mode) checkbox=\(String(describing: checkboxFrame)) edgeBounds=\(String(describing: edgeBounds))")
fflush(stdout)
guard axTrusted, canListen,
      (mode == "edge" || checkboxFrame != nil),
      (mode == "checkbox" || edgeBounds != nil) else {
    fatalError("Accessibility, Input Monitoring, Settings checkbox, or display unavailable")
}
var port: CFMessagePort?
for _ in 0..<30 {
    port = CFMessagePortCreateRemote(nil, "DockMagicProbeHandoff" as CFString)
    if port != nil { break }
    Thread.sleep(forTimeInterval: 0.1)
}
guard let port else { fatalError("Probe handoff port unavailable") }
private let preflight = Preflight(checkboxFrame: checkboxFrame, edge: mode == "checkbox" ? nil : edge,
                                 edgeBounds: edgeBounds, port: port)
var mask: CGEventMask = 0
if mode != "edge" { mask |= 1 << CGEventType.leftMouseDown.rawValue }
if mode != "checkbox" {
    mask |= 1 << CGEventType.mouseMoved.rawValue
    mask |= 1 << CGEventType.leftMouseDragged.rawValue
}
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                  place: .headInsertEventTap,
                                  options: .defaultTap,
                                  eventsOfInterest: mask,
                                  callback: eventCallback,
                                  userInfo: Unmanaged.passUnretained(preflight).toOpaque()) else {
    fatalError("CGEvent tap unavailable")
}
let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
CGEvent.tapEnable(tap: tap, enable: true)
print("ready mode=\(mode) edge=\(edge) duration=\(duration)")
fflush(stdout)
CFRunLoopRunInMode(.defaultMode, duration, false)
print("complete intercepted=\(preflight.intercepted) edgeIntercepted=\(preflight.edgeIntercepted) failures=\(preflight.failures)")
