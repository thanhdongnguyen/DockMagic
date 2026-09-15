import AppKit
import Foundation
import ImageIO

// Review composition only: does not modify generated badge source files.
struct Badge: Decodable {
    let day: Int
    let title: String
    let file: String
}
struct Manifest: Decodable { let badges: [Badge] }
enum ReviewError: Error { case image(String), bitmap, encoding }
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
let images = try manifest.badges.map { badge -> NSImage in
    let url = directory.appendingPathComponent(badge.file)
    guard let image = NSImage(contentsOf: url) else { throw ReviewError.image(url.path) }
    return image
}

func canvas(_ width: Int, _ height: Int, draw: () throws -> Void) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw ReviewError.bitmap }
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    defer { NSGraphicsContext.restoreGraphicsState() }
    try draw()
    return bitmap
}
func fill(_ rect: NSRect, _ white: CGFloat) {
    NSColor(white: white, alpha: 1).setFill()
    rect.fill()
}
func label(_ text: String, _ x: CGFloat, _ top: CGFloat, _ width: CGFloat,
           _ size: CGFloat, _ height: CGFloat, _ color: CGFloat = 0.12, centered: Bool = false) {
    let style = NSMutableParagraphStyle()
    style.alignment = centered ? .center : .left
    (text as NSString).draw(in: NSRect(x: x, y: height - top - size * 1.7, width: width, height: size * 1.8),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium),
                         .foregroundColor: NSColor(white: color, alpha: 1), .paragraphStyle: style])
}
func drawImage(_ image: NSImage, _ x: CGFloat, _ top: CGFloat, _ side: CGFloat, _ height: CGFloat) {
    image.draw(in: NSRect(x: x, y: height - top - side, width: side, height: side),
               from: .zero, operation: .sourceOver, fraction: 1,
               respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
}
func save(_ bitmap: NSBitmapImageRep, _ name: String) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw ReviewError.encoding }
    try data.write(to: directory.appendingPathComponent(name))
}

let sheetHeight: CGFloat = 980
let sheet = try canvas(1600, Int(sheetHeight)) {
    fill(NSRect(x: 0, y: 0, width: 1600, height: sheetHeight), 1)
    label("DockMagic / Hex Collectibles", 60, 34, 1480, 36, sheetHeight)
    label("10 streak milestones · original illustrated badge redesign · design review only", 60, 88, 1480, 19, sheetHeight, 0.4)
    for (index, badge) in manifest.badges.enumerated() {
        let x = 50 + CGFloat(index % 5) * 302
        let top = 142 + CGFloat(index / 5) * 374
        drawImage(images[index], x + 17, top, 268, sheetHeight)
        label(badge.title, x, top + 280, 302, 22, sheetHeight, centered: true)
        label("\(badge.day) \(badge.day == 1 ? "day" : "days")", x, top + 316, 302, 17, sheetHeight, 0.42, centered: true)
    }
    label("Concept PNGs, not SVG vectors. Existing app assets and streak rules are unchanged.", 60, 924, 1480, 17, sheetHeight, 0.45)
}
try save(sheet, "collection-review.png")

// Sample-size fixtures use AppKit image compositing, not the production SwiftUI view.
// Grayscale is a real grayscale bitmap, rather than a display-only filter.
func grayImage(_ image: NSImage) throws -> NSImage {
    var sourceRect = NSRect(origin: .zero, size: image.size)
    guard let source = image.cgImage(forProposedRect: &sourceRect, context: nil, hints: nil),
          let context = CGContext(data: nil, width: source.width, height: source.height,
              bitsPerComponent: 8, bytesPerRow: source.width * 2, space: CGColorSpaceCreateDeviceGray(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ReviewError.bitmap }
    context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
    guard let gray = context.makeImage() else { throw ReviewError.bitmap }
    return NSImage(cgImage: gray, size: image.size)
}
let grayImages = try images.map(grayImage)
for scale in [1, 2] {
    let logicalHeight: CGFloat = 1320
    let review = try canvas(1440 * scale, Int(logicalHeight) * scale) {
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        fill(NSRect(x: 0, y: 0, width: 1440, height: logicalHeight), 1)
        label("Asset size review / \(scale)x", 36, 24, 1300, 28, logicalHeight)
        label("AppKit samples only · no production UI, lock-state or accessibility sign-off", 36, 72, 1350, 17, logicalHeight, 0.4)
        for (index, badge) in manifest.badges.enumerated() {
            let x = 24 + CGFloat(index % 5) * 282
            let top = 126 + CGFloat(index / 5) * 568
            label(badge.title, x, top, 270, 20, logicalHeight)
            label("\(badge.day) \(badge.day == 1 ? "day" : "days")", x, top + 30, 270, 15, logicalHeight, 0.4)
            drawImage(images[index], x + 38, top + 60, 185, logicalHeight)
            label("185 pt", x, top + 242, 260, 14, logicalHeight, 0.4, centered: true)
            fill(NSRect(x: x, y: logicalHeight - top - 402, width: 264, height: 124), 0.12)
            drawImage(images[index], x + 13, top + 284, 112, logicalHeight)
            drawImage(images[index], x + 161, top + 306, 58, logicalHeight)
            label("112 pt / 58 pt · dark", x, top + 408, 260, 14, logicalHeight, 0.4, centered: true)
            drawImage(images[index], x + 30, top + 444, 48, logicalHeight)
            drawImage(images[index], x + 107, top + 439, 58, logicalHeight)
            drawImage(grayImages[index], x + 194, top + 444, 48, logicalHeight)
            label("48 / 58 pt · light     48 pt gray", x, top + 504, 274, 13, logicalHeight, 0.4)
        }
    }
    try save(review, "size-review-\(scale)x.png")
}

// Decode original alpha and dimensions. Has-alpha metadata alone is not sufficient.
var reports: [[String: Any]] = []
for badge in manifest.badges {
    let url = directory.appendingPathComponent(badge.file)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ReviewError.image(url.path) }
    let width = cg.width, height = cg.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo) else { throw ReviewError.bitmap }
    context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    var transparent = 0, opaque = 0
    for offset in stride(from: 3, to: pixels.count, by: 4) {
        if pixels[offset] == 0 { transparent += 1 }
        if pixels[offset] == 255 { opaque += 1 }
    }
    let cornerIndices = [0, width - 1, (height - 1) * width, width * height - 1]
    reports.append(["day": badge.day, "title": badge.title, "file": badge.file,
                    "width": width, "height": height, "alphaInfo": cg.alphaInfo.rawValue,
                    "transparentPixels": transparent, "opaquePixels": opaque,
                    "cornerAlpha": cornerIndices.map { Int(pixels[$0 * 4 + 3]) }])
}
let json = try JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
try json.write(to: directory.appendingPathComponent("asset-checks.json"))
print(String(data: json, encoding: .utf8)!)
print("Saved collection-review.png; original badge pixels are unchanged.")
