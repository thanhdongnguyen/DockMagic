import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]) else {
    fatalError("Usage: PointerClick <global-screen-x> <global-screen-y>")
}
let location = CGPoint(x: x, y: y)
for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type,
                              mouseCursorPosition: location, mouseButton: .left) else {
        fatalError("CGEvent unavailable")
    }
    event.post(tap: .cghidEventTap)
    if type == .leftMouseDown { Thread.sleep(forTimeInterval: 0.04) }
}
