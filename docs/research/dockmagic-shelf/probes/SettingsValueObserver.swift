import AppKit
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name, &value) == .success ? value : nil
}

func name(_ element: AXUIElement) -> String {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute]
        .compactMap { attribute(element, $0 as CFString) as? String }
        .joined(separator: " | ")
}

guard AXIsProcessTrusted(),
      let app = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.systempreferences").first else {
    fatalError("System Settings Accessibility unavailable")
}
let root = AXUIElementCreateApplication(app.processIdentifier)
let windows = attribute(root, kAXWindowsAttribute as CFString) as? [AXUIElement] ?? []
guard let window = windows.first(where: {
    (attribute($0, kAXTitleAttribute as CFString) as? String) == "Desktop & Dock"
}) else { fatalError("Desktop & Dock window unavailable") }

var checkbox: AXUIElement?
func visit(_ element: AXUIElement, parent: AXUIElement?, depth: Int) {
    guard depth < 15, checkbox == nil else { return }
    let label = name(element) + " " +
        ((attribute(element, kAXValueAttribute as CFString) as? String) ?? "")
    let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
    let siblings = parent.flatMap {
        attribute($0, kAXChildrenAttribute as CFString) as? [AXUIElement]
    } ?? []
    if label.localizedCaseInsensitiveContains("Automatically hide and show the Dock"),
       let match = siblings.first(where: {
           (attribute($0, kAXRoleAttribute as CFString) as? String) == "AXCheckBox"
       }) {
        checkbox = match
        return
    }
    for child in children { visit(child, parent: element, depth: depth + 1) }
}
visit(window, parent: nil, depth: 0)
guard let checkbox else { fatalError("Dock auto-hide checkbox unavailable") }

let preemptEnabled = CommandLine.arguments.contains("--preempt")
let handoffPort = preemptEnabled
    ? CFMessagePortCreateRemote(nil, "DockMagicProbeHandoff" as CFString) : nil
if preemptEnabled && handoffPort == nil { fatalError("Probe message port unavailable") }

var observer: AXObserver?
let createStatus = AXObserverCreate(app.processIdentifier, { _, element, notification, _ in
    let now = ProcessInfo.processInfo.systemUptime
    var preemptResult = "disabled"
    if let handoffPort {
        var reply: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(handoffPort, 2, nil, 0.05, 0.1,
                                              "kCFRunLoopDefaultMode" as CFString, &reply)
        let acknowledged = reply?.takeRetainedValue() != nil
        let latencyMs = (ProcessInfo.processInfo.systemUptime - now) * 1000
        preemptResult = "status=\(status),ack=\(acknowledged),latencyMs=\(latencyMs)"
    }
    let value = attribute(element, kAXValueAttribute as CFString)
    print("event uptime=\(now) notification=\(notification) value=\(String(describing: value)) preempt=\(preemptResult)")
    fflush(stdout)
}, &observer)
guard createStatus == .success, let observer else {
    fatalError("AXObserverCreate failed: \(createStatus.rawValue)")
}
let addStatus = AXObserverAddNotification(observer, checkbox,
                                          kAXValueChangedNotification as CFString, nil)
print("ready uptime=\(ProcessInfo.processInfo.systemUptime) addStatus=\(addStatus.rawValue) value=\(String(describing: attribute(checkbox, kAXValueAttribute as CFString)))")
fflush(stdout)
if addStatus == .success {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
    let duration = Double(CommandLine.arguments.dropFirst().first ?? "20") ?? 20
    RunLoop.current.run(until: Date().addingTimeInterval(duration))
}
