import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Authorized by the user on 2026-09-09: remove only the exterior checkerboard
// from these four generated images. Never redraw or recolor badge artwork.
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let targets = ["07-loop", "60-navigator", "365-keystone", "730-continuum"]
let backupDirectory = directory.appendingPathComponent("references/opaque-originals")
try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
enum CutoutError: Error { case image(String), context, unsafeMask(String), encoding }
var reports: [[String: Any]] = []

for name in targets {
    let targetURL = directory.appendingPathComponent("assets/\(name).png")
    let backupURL = backupDirectory.appendingPathComponent("\(name).png")
    if !FileManager.default.fileExists(atPath: backupURL.path) {
        try FileManager.default.copyItem(at: targetURL, to: backupURL)
    }
    guard let source = CGImageSourceCreateWithURL(backupURL as CFURL, nil),
          let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CutoutError.image(name) }
    let width = original.width, height = original.height, count = width * height
    let space = original.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    var originalPixels = [UInt8](repeating: 0, count: count * 4)
    guard let context = CGContext(data: &originalPixels, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: bitmapInfo) else { throw CutoutError.context }
    context.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))

    func isExteriorGray(_ index: Int) -> Bool {
        let offset = index * 4
        let r = Int(originalPixels[offset]), g = Int(originalPixels[offset + 1]), b = Int(originalPixels[offset + 2])
        // Checkerboard is neutral and brighter than the continuous navy outline.
        return max(r, g, b) - min(r, g, b) <= 44 && (r + g + b) / 3 > 50
    }
    var outside = [Bool](repeating: false, count: count)
    var queue: [Int] = []
    queue.reserveCapacity(count / 2)
    func visit(_ index: Int) {
        if !outside[index] && isExteriorGray(index) {
            outside[index] = true
            queue.append(index)
        }
    }
    for x in 0..<width { visit(x); visit((height - 1) * width + x) }
    for y in 0..<height { visit(y * width); visit(y * width + width - 1) }
    var head = 0
    while head < queue.count {
        let index = queue[head]
        head += 1
        let x = index % width, y = index / width
        if x > 0 { visit(index - 1) }
        if x + 1 < width { visit(index + 1) }
        if y > 0 { visit(index - width) }
        if y + 1 < height { visit(index + width) }
    }
    // Fail closed if the flood leaked through the frame, missed the background,
    // or would remove a central part of the badge.
    guard queue.count > count / 5, queue.count < count * 3 / 5,
          !outside[(height / 2) * width + width / 2] else { throw CutoutError.unsafeMask(name) }
    for y in (height / 3)..<(height * 2 / 3) {
        for x in (width / 3)..<(width * 2 / 3) {
            guard !outside[y * width + x] else { throw CutoutError.unsafeMask(name) }
        }
    }

    var outputPixels = originalPixels
    for index in queue {
        let offset = index * 4
        outputPixels[offset] = 0
        outputPixels[offset + 1] = 0
        outputPixels[offset + 2] = 0
        outputPixels[offset + 3] = 0
    }
    var retainedPixelsChanged = 0
    for index in 0..<count where !outside[index] {
        let offset = index * 4
        if outputPixels[offset..<(offset + 4)] != originalPixels[offset..<(offset + 4)] { retainedPixelsChanged += 1 }
    }
    guard retainedPixelsChanged == 0,
          let provider = CGDataProvider(data: Data(outputPixels) as CFData),
          let cutout = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
              bytesPerRow: width * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
              provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
          let destination = CGImageDestinationCreateWithURL(targetURL as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CutoutError.encoding }
    CGImageDestinationAddImage(destination, cutout, nil)
    guard CGImageDestinationFinalize(destination) else { throw CutoutError.encoding }
    reports.append(["file": "assets/\(name).png", "source": "references/opaque-originals/\(name).png",
                    "width": width, "height": height, "removedExteriorPixels": queue.count,
                    "retainedPixelsChanged": retainedPixelsChanged,
                    "method": "border-connected neutral-background flood fill; preserved all retained RGBA pixels"])
}
let report = try JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
try report.write(to: directory.appendingPathComponent("local-cutout-checks.json"))
print(String(data: report, encoding: .utf8)!)
