import AppKit
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name, &value) == .success ? value : nil
}

func position(_ element: AXUIElement) -> CGPoint? {
    guard let value = attribute(element, kAXPositionAttribute as CFString),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
}

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 5,
      AXIsProcessTrusted() else {
    fatalError("Usage: SetWindowPosition BUNDLE_ID WINDOW_TITLE [X Y]")
}
let bundle = CommandLine.arguments[1]
let title = CommandLine.arguments[2]
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
    fatalError("App unavailable")
}
let root = AXUIElementCreateApplication(app.processIdentifier)
let windows = attribute(root, kAXWindowsAttribute as CFString) as? [AXUIElement] ?? []
guard let window = windows.first(where: {
    (attribute($0, kAXTitleAttribute as CFString) as? String) == title
}) else { fatalError("Window unavailable") }
print("before=\(String(describing: position(window)))")
if CommandLine.arguments.count == 5 {
    guard let x = Double(CommandLine.arguments[3]),
          let y = Double(CommandLine.arguments[4]) else { fatalError("Invalid coordinates") }
    var point = CGPoint(x: x, y: y)
    guard let axPoint = AXValueCreate(.cgPoint, &point) else { fatalError("AXValueCreate failed") }
    let status = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPoint)
    print("setStatus=\(status.rawValue) after=\(String(describing: position(window)))")
    guard status == .success else { fatalError("Window position was not set") }
}
