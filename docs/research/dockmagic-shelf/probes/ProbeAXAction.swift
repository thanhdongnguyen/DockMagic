import AppKit
import ApplicationServices
import Foundation

guard AXIsProcessTrusted(),
      let process = NSRunningApplication.runningApplications(withBundleIdentifier:
          "dev.dockmagic.replacementdockprobe").first else {
    fatalError("Prototype Accessibility unavailable")
}
func attr(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key, &value) == .success ? value : nil
}
func text(_ element: AXUIElement, _ key: CFString) -> String {
    attr(element, key) as? String ?? ""
}
let target = CommandLine.arguments.dropFirst().first
var matches: [AXUIElement] = []
var visited = Set<CFHashCode>()
func visit(_ element: AXUIElement, depth: Int) {
    guard depth <= 18 else { return }
    let key = CFHash(element)
    guard visited.insert(key).inserted else { return }
    let role = text(element, kAXRoleAttribute as CFString)
    let title = text(element, kAXTitleAttribute as CFString)
    let label = text(element, kAXDescriptionAttribute as CFString)
    if depth <= 5 || role == "AXMenuItem" || role == "AXButton" {
        var frame = ""
        if let position = attr(element, kAXPositionAttribute as CFString),
           let dimensions = attr(element, kAXSizeAttribute as CFString),
           CFGetTypeID(position) == AXValueGetTypeID(),
           CFGetTypeID(dimensions) == AXValueGetTypeID() {
            var origin = CGPoint.zero
            var size = CGSize.zero
            if AXValueGetValue(position as! AXValue, .cgPoint, &origin),
               AXValueGetValue(dimensions as! AXValue, .cgSize, &size) {
                frame = " frame=\(CGRect(origin: origin, size: size))"
            }
        }
        print("depth=\(depth) role=\(role) title=\(title) label=\(label)\(frame)")
    }
    if let target, role == "AXMenuItem" && title == target { matches.append(element) }
    for child in attr(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? [] {
        visit(child, depth: depth + 1)
    }
}
let app = AXUIElementCreateApplication(process.processIdentifier)
visit(app, depth: 0)
if let focused = attr(app, kAXFocusedUIElementAttribute as CFString),
   CFGetTypeID(focused) == AXUIElementGetTypeID() {
    visit(focused as! AXUIElement, depth: 0)
}
if let target {
    guard matches.count == 1 else { fatalError("Expected one menu item named \(target), found \(matches.count)") }
    let status = AXUIElementPerformAction(matches[0], kAXPressAction as CFString)
    print("pressed=\(target) status=\(status.rawValue)")
    guard status == .success else { exit(1) }
}
