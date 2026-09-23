import AppKit
import CoreGraphics
import Foundation

let point = NSEvent.mouseLocation
let mainDisplay = CGDisplayBounds(CGMainDisplayID())
print("\(Int(point.x.rounded())) \(Int((mainDisplay.height - point.y).rounded()))")
