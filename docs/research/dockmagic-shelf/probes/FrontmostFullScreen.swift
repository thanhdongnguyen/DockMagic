import AppKit
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name, &value) == .success ? value : nil
}

guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else {
    fatalError("Frontmost app Accessibility is unavailable")
}
let root = AXUIElementCreateApplication(app.processIdentifier)
let focused = attribute(root, kAXFocusedWindowAttribute as CFString)
let window = focused.flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
    ?? (attribute(root, kAXWindowsAttribute as CFString) as? [AXUIElement])?.first
let fullScreen = window.flatMap { attribute($0, "AXFullScreen" as CFString) as? Bool }
let title = window.flatMap { attribute($0, kAXTitleAttribute as CFString) as? String } ?? ""
print("bundle=\(app.bundleIdentifier ?? "unknown") pid=\(app.processIdentifier) window=\(title) AXFullScreen=\(String(describing: fullScreen))")
