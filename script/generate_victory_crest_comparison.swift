import AppKit
import Foundation

enum ComparisonError: Error {
    case bitmapAllocationFailed
    case contextCreationFailed
    case missingImage(String)
    case pngEncodingFailed
}

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let evidenceRoot = rootURL.appendingPathComponent("docs/streak-concepts/pinterest-v2")
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : evidenceRoot.appendingPathComponent("victory-crest-native-comparison.png")

func loadImage(_ name: String) throws -> NSImage {
    let url = evidenceRoot.appendingPathComponent(name)
    guard let image = NSImage(contentsOf: url) else {
        throw ComparisonError.missingImage(url.path)
    }
    return image
}

let source = try loadImage("victory-crest-claude.png")
let codexDark = try loadImage("victory-crest-codex-detail-dark.png")
let claudeDark = try loadImage("victory-crest-claude-detail-dark.png")
let codexLight = try loadImage("victory-crest-codex-detail-light.png")
let codexGrayscale = try loadImage("victory-crest-codex-detail-grayscale.png")

let canvasWidth = 2_600
let canvasHeight = 1_230
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
    throw ComparisonError.bitmapAllocationFailed
}
representation.size = NSSize(width: canvasWidth, height: canvasHeight)
guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
    throw ComparisonError.contextCreationFailed
}

func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(
        x: x,
        y: CGFloat(canvasHeight) - y - height,
        width: width,
        height: height
    )
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
        xRadius: 22,
        yRadius: 22
    ).fill()
}

func drawImage(_ image: NSImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    image.draw(
        in: rectFromTop(x: x, y: y, width: width, height: height),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
context.imageInterpolation = .high

NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)).fill()

drawText(
    "DockMagic · Victory Crest native comparison",
    x: 38,
    y: 24,
    width: 1_500,
    height: 44,
    font: .systemFont(ofSize: 31, weight: .bold),
    color: .white
)
drawText(
    "Option 1 source target + app-hosted SwiftUI render test · 2× backing scale",
    x: 40,
    y: 70,
    width: 1_700,
    height: 28,
    font: .systemFont(ofSize: 16, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.7)
)

drawPanel(x: 32, y: 112, width: 2_536, height: 198)
drawImage(source, x: 56, y: 127, width: 168, height: 168)
drawText(
    "SOURCE TARGET",
    x: 252,
    y: 140,
    width: 340,
    height: 24,
    font: .systemFont(ofSize: 13, weight: .bold),
    color: NSColor.white.withAlphaComponent(0.58)
)
drawText(
    "Broad faceted crest · warm copper-gold rim · graphite, ivory and cobalt enamel",
    x: 252,
    y: 172,
    width: 1_700,
    height: 32,
    font: .systemFont(ofSize: 23, weight: .semibold),
    color: .white
)
drawText(
    "Production keeps the center as a deterministic identity region: exact Codex or Claude Code artwork is composited at runtime.",
    x: 252,
    y: 216,
    width: 2_150,
    height: 50,
    font: .systemFont(ofSize: 16, weight: .regular),
    color: NSColor.white.withAlphaComponent(0.72)
)

let top: CGFloat = 344
let renderedHeight: CGFloat = 800

drawText("CODEX · DARK", x: 38, y: 316, width: 420, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawImage(codexDark, x: 38, y: top, width: 674, height: renderedHeight)

drawText("CLAUDE CODE · DARK", x: 748, y: 316, width: 420, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawImage(claudeDark, x: 748, y: top, width: 463, height: renderedHeight)

drawText("CODEX · LIGHT", x: 1_248, y: 316, width: 420, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawImage(codexLight, x: 1_248, y: top, width: 674, height: renderedHeight)

drawText("CODEX · GRAYSCALE", x: 1_958, y: 316, width: 560, height: 24, font: .systemFont(ofSize: 14, weight: .bold), color: .white)
drawImage(codexGrayscale, x: 1_958, y: top, width: 602, height: 713)

NSGraphicsContext.restoreGraphicsState()

guard let png = representation.representation(using: .png, properties: [:]) else {
    throw ComparisonError.pngEncodingFailed
}
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
