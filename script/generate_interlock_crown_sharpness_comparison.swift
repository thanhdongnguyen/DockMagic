import AppKit
import Foundation

enum SharpnessComparisonError: Error {
    case bitmapAllocationFailed
    case contextCreationFailed
    case missingImage(String)
    case pngEncodingFailed
}

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let evidenceRoot = rootURL.appendingPathComponent("docs/streak-concepts/pinterest-v3")
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : evidenceRoot.appendingPathComponent("interlock-crown-small-sharpness-comparison.png")

func loadImage(_ path: String) throws -> NSImage {
    let url = evidenceRoot.appendingPathComponent(path)
    guard let image = NSImage(contentsOf: url) else {
        throw SharpnessComparisonError.missingImage(url.path)
    }
    return image
}

let source = try loadImage("ideation/interlock-crown.png")
let before = try loadImage("interlock-crown-small-sharpness-before.png")
let after = try loadImage("interlock-crown-small-sharpness-after.png")

let canvasWidth = 2_200
let canvasHeight = 1_180
guard let representation = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvasWidth,
    pixelsHigh: canvasHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    throw SharpnessComparisonError.bitmapAllocationFailed
}
representation.size = NSSize(width: canvasWidth, height: canvasHeight)
guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
    throw SharpnessComparisonError.contextCreationFailed
}

func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(canvasHeight) - y - height, width: width, height: height)
}

func drawText(
    _ value: String,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
    font: NSFont,
    color: NSColor
) {
    value.draw(
        in: rectFromTop(x: x, y: y, width: width, height: height),
        withAttributes: [.font: font, .foregroundColor: color]
    )
}

func drawPanel(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: rectFromTop(x: x, y: y, width: width, height: height),
        xRadius: 20,
        yRadius: 20
    ).fill()
}

func drawImage(
    _ image: NSImage,
    sourceRect: NSRect? = nil,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
    interpolation: NSImageInterpolation = .high
) {
    image.draw(
        in: rectFromTop(x: x, y: y, width: width, height: height),
        from: sourceRect ?? NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: interpolation]
    )
}

func collectionCrop(for image: NSImage) -> NSRect {
    let top = image.size.height * (610 / 1_044)
    let height = image.size.height * (420 / 1_044)
    return NSRect(
        x: 0,
        y: image.size.height - top - height,
        width: image.size.width,
        height: height
    )
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
context.imageInterpolation = .high

NSColor(calibratedWhite: 0.065, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)).fill()

drawText(
    "Interlock Crown · compact sharpness QA",
    x: 34,
    y: 24,
    width: 1_400,
    height: 42,
    font: .systemFont(ofSize: 30, weight: .bold),
    color: .white
)
drawText(
    "Selected source + same Codex viewport before/after · 48–58 pt badges · 2× backing scale",
    x: 36,
    y: 68,
    width: 1_700,
    height: 28,
    font: .systemFont(ofSize: 16, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.68)
)

drawPanel(x: 28, y: 112, width: 2_144, height: 192)
drawImage(source, x: 48, y: 124, width: 168, height: 168)
drawText(
    "SOURCE ART",
    x: 244,
    y: 138,
    width: 260,
    height: 22,
    font: .systemFont(ofSize: 13, weight: .bold),
    color: NSColor.white.withAlphaComponent(0.56)
)
drawText(
    "Preserve crisp copper outlines and clean graphite / ivory / cobalt separation at compact size",
    x: 244,
    y: 172,
    width: 1_700,
    height: 32,
    font: .systemFont(ofSize: 22, weight: .semibold),
    color: .white
)
drawText(
    "Final renderer uses pixel-preserving sampling on Retina for ≤60 pt, medium interpolation on 1× displays, and high-quality interpolation for 112–185 pt hero art.",
    x: 244,
    y: 216,
    width: 1_760,
    height: 48,
    font: .systemFont(ofSize: 15, weight: .regular),
    color: NSColor.white.withAlphaComponent(0.72)
)

drawText("BEFORE · HIGH INTERPOLATION", x: 36, y: 324, width: 560, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawImage(before, x: 36, y: 354, width: 650, height: 771)

drawText("AFTER · DENSITY-AWARE", x: 716, y: 324, width: 560, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawImage(after, x: 716, y: 354, width: 650, height: 771)

drawText("COMPACT COLLECTION · BEFORE", x: 1_400, y: 324, width: 640, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawPanel(x: 1_392, y: 350, width: 780, height: 370)
drawImage(
    before,
    sourceRect: collectionCrop(for: before),
    x: 1_404,
    y: 362,
    width: 756,
    height: 346,
    interpolation: .none
)

drawText("COMPACT COLLECTION · AFTER", x: 1_400, y: 750, width: 640, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawPanel(x: 1_392, y: 776, width: 780, height: 370)
drawImage(
    after,
    sourceRect: collectionCrop(for: after),
    x: 1_404,
    y: 788,
    width: 756,
    height: 346,
    interpolation: .none
)

NSGraphicsContext.restoreGraphicsState()

guard let png = representation.representation(using: .png, properties: [:]) else {
    throw SharpnessComparisonError.pngEncodingFailed
}
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
