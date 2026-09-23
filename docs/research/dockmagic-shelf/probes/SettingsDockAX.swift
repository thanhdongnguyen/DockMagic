import AppKit
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name, &value) == .success ? value : nil
}

func label(_ element: AXUIElement) -> String {
    let names = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute]
    return names.compactMap { attribute(element, $0 as CFString) as? String }
        .joined(separator: " | ")
}

guard AXIsProcessTrusted(),
      let process = NSRunningApplication.runningApplications(withBundleIdentifier:
          "com.apple.systempreferences").first else {
    fatalError("System Settings Accessibility is unavailable")
}
let app = AXUIElementCreateApplication(process.processIdentifier)
let windows = attribute(app, kAXWindowsAttribute as CFString) as? [AXUIElement] ?? []
guard let window = windows.first(where: {
    (attribute($0, kAXTitleAttribute as CFString) as? String) == "Desktop & Dock"
}) else { fatalError("Desktop & Dock window is unavailable") }

var matches: [AXUIElement] = []
func visit(_ element: AXUIElement, depth: Int, parent: AXUIElement?, path: String) {
    guard depth <= 15 else { return }
    let role = attribute(element, kAXRoleAttribute as CFString) as? String ?? ""
    let name = label(element)
    let value = attribute(element, kAXValueAttribute as CFString)
    let valueText = value as? String ?? ""
    let isTarget = (name + " " + valueText)
        .localizedCaseInsensitiveContains("Automatically hide and show the Dock")
    if isTarget {
        print("target path=\(path) role=\(role) label=\(name) value=\(valueText)")
        if let parent {
            let siblings = attribute(parent, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
            for (index, sibling) in siblings.enumerated() {
                let siblingRole = attribute(sibling, kAXRoleAttribute as CFString) as? String ?? ""
                let siblingValue = attribute(sibling, kAXValueAttribute as CFString)
                print(" sibling=\(index) role=\(siblingRole) label=\(label(sibling)) value=\(siblingValue.map(String.init(describing:)) ?? "nil")")
            }
            if siblings.count >= 2,
               (attribute(siblings[1], kAXRoleAttribute as CFString) as? String) == "AXCheckBox" {
                matches.append(siblings[1])
            }
        }
    }
    let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
    for (index, child) in children.enumerated() {
        visit(child, depth: depth + 1, parent: element, path: "\(path)/\(index)")
    }
}
visit(window, depth: 0, parent: nil, path: "")
print("labelMatches=\(matches.count)")
let slowClick = CommandLine.arguments.contains("--click-slow")
if CommandLine.arguments.contains("--press") || CommandLine.arguments.contains("--click") || slowClick {
    guard matches.count == 1,
          let currentValue = attribute(matches[0], kAXValueAttribute as CFString) as? NSNumber,
          currentValue.boolValue else {
        fatalError("Expected exactly one enabled Dock auto-hide checkbox")
    }
    if CommandLine.arguments.contains("--click") || slowClick {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == process.processIdentifier,
              let positionValue = attribute(matches[0], kAXPositionAttribute as CFString),
              let sizeValue = attribute(matches[0], kAXSizeAttribute as CFString),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            fatalError("System Settings is not frontmost or checkbox has no frame")
        }
        var position = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &dimensions) else {
            fatalError("Could not read checkbox frame")
        }
        let center = CGPoint(x: position.x + dimensions.width / 2,
                             y: position.y + dimensions.height / 2)
        for eventType in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: eventType,
                                      mouseCursorPosition: center, mouseButton: .left) else {
                fatalError("Could not create pointer event")
            }
            event.post(tap: .cghidEventTap)
            if eventType == .leftMouseDown {
                Thread.sleep(forTimeInterval: slowClick ? 0.08 : 0.01)
            } else if eventType == .leftMouseUp {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        print("clicked=\(center) holdMs=\(slowClick ? 80 : 10)")
    } else {
        let status = AXUIElementPerformAction(matches[0], kAXPressAction as CFString)
        print("pressStatus=\(status.rawValue)")
        guard status == .success else { fatalError("AXPress failed") }
    }
}
