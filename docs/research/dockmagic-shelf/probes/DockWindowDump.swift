import AppKit
import CoreGraphics

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
for window in (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []) {
    guard let owner = window[kCGWindowOwnerName as String] as? String,
          owner == "Dock" || owner == "ReplacementDockProbe" || owner == "System Settings" else { continue }
    print("owner=\(owner) id=\(window[kCGWindowNumber as String] ?? "?") layer=\(window[kCGWindowLayer as String] ?? "?") bounds=\(window[kCGWindowBounds as String] ?? "?") name=\(window[kCGWindowName as String] ?? "?")")
}
