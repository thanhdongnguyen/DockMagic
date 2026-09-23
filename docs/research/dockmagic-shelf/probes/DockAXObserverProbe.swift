import AppKit
import ApplicationServices
import Foundation

func attribute(_ e: AXUIElement, _ key: CFString) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, key, &v) == .success ? v : nil
}
func dockFrame(_ e: AXUIElement) -> CGRect? {
    guard let p = attribute(e, kAXPositionAttribute as CFString),
          let s = attribute(e, kAXSizeAttribute as CFString),
          CFGetTypeID(p) == AXValueGetTypeID(),
          CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
          AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}
func publish(_ list: AXUIElement, event: String) {
    let frame = dockFrame(list)
    let visible = frame.map { $0.minY < 1070 && $0.maxY <= 1080 } ?? false
    let line = "\(ProcessInfo.processInfo.systemUptime) event=\(event) visible=\(visible) frame=\(String(describing: frame))\n"
    let url = URL(fileURLWithPath: "/private/tmp/dockmagic-shelf-probe/handoff-ax-events.log")
    if let h = try? FileHandle(forWritingTo: url) {
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: Data(line.utf8))
        try? h.close()
    } else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    DistributedNotificationCenter.default.post(
        name: Notification.Name("DockMagicHandoffProbe"), object: visible ? "1" : "0"
    )
}

guard AXIsProcessTrusted(),
      let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
        .first?.processIdentifier else { exit(2) }
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 0.1)
guard let children = attribute(app, kAXChildrenAttribute as CFString) as? [AXUIElement],
      let list = children.first(where: {
          (attribute($0, kAXRoleAttribute as CFString) as? String) == "AXList"
      }) else { exit(3) }

let callback: AXObserverCallback = { _, element, notification, _ in
    publish(element, event: notification as String)
}
var observer: AXObserver?
let creation = AXObserverCreate(pid, callback, &observer)
guard creation == .success, let observer else { print("create=\(creation.rawValue)"); exit(4) }
for name in [kAXMovedNotification, kAXResizedNotification, kAXValueChangedNotification,
             kAXLayoutChangedNotification] {
    let result = AXObserverAddNotification(observer, list, name as CFString, nil)
    print("list \(name): \(result.rawValue)")
}
for name in [kAXCreatedNotification, kAXLayoutChangedNotification] {
    let result = AXObserverAddNotification(observer, app, name as CFString, nil)
    print("app \(name): \(result.rawValue)")
}
CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
publish(list, event: "initial")
CFRunLoopRunInMode(.defaultMode, 30, false)
