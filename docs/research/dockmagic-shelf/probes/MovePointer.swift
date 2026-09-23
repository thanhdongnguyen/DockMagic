import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]),
      let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: CGPoint(x: x, y: y),
                          mouseButton: .left) else {
    fatalError("Usage: MovePointer <global-screen-x> <global-screen-y>")
}
event.post(tap: .cghidEventTap)
