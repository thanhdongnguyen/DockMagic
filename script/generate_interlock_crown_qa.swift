import AppKit
import Foundation

struct BadgeSpec {
    let day: Int
    let title: String
    let filename: String
}

enum BadgeQAError: Error {
    case bitmapAllocationFailed
    case contextCreationFailed
    case missingImage(String)
    case pngEncodingFailed
}

let specs = [
    BadgeSpec(day: 1, title: "First Prompt", filename: "01-first-prompt.png"),
    BadgeSpec(day: 3, title: "Spark", filename: "03-spark.png"),
    BadgeSpec(day: 7, title: "Loop", filename: "07-loop.png"),
    BadgeSpec(day: 14, title: "Builder", filename: "14-builder.png"),
    BadgeSpec(day: 30, title: "Flow", filename: "30-flow.png"),
    BadgeSpec(day: 60, title: "Navigator", filename: "60-navigator.png"),
    BadgeSpec(day: 100, title: "Century", filename: "100-century.png"),
    BadgeSpec(day: 180, title: "Architect", filename: "180-architect.png"),
    BadgeSpec(day: 365, title: "Keystone", filename: "365-keystone.png"),
    BadgeSpec(day: 730, title: "Continuum", filename: "730-continuum.png")
]

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let productionURL = rootURL.appendingPathComponent(
    "docs/streak-concepts/pinterest-v3/production"
)
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : rootURL.appendingPathComponent(
        "docs/streak-concepts/pinterest-v3/interlock-crown-production-contact-sheet.png"
    )

func loadImage(_ url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw BadgeQAError.missingImage(url.path)
    }
    return image
}

let badges = try specs.map { try loadImage(productionURL.appendingPathComponent($0.filename)) }
let selectedTarget = try loadImage(
    rootURL.appendingPathComponent(
        "docs/streak-concepts/pinterest-v3/ideation/interlock-crown.png"
    )
)

let canvasWidth = 1_800
let canvasHeight = 1_040
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
    throw BadgeQAError.bitmapAllocationFailed
}
representation.size = NSSize(width: canvasWidth, height: canvasHeight)
guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
    throw BadgeQAError.contextCreationFailed
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

func fillPanel(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22).fill()
}

func renderBadge(_ image: NSImage, side: Int, grayscale: Bool) throws -> NSImage {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: grayscale ? 2 : 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: grayscale ? .deviceWhite : .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw BadgeQAError.bitmapAllocationFailed
    }
    rep.size = NSSize(width: side, height: side)
    guard let badgeContext = NSGraphicsContext(bitmapImageRep: rep) else {
        throw BadgeQAError.contextCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = badgeContext
    badgeContext.shouldAntialias = true
    badgeContext.imageInterpolation = .high
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
    image.draw(
        in: NSRect(x: 0, y: 0, width: side, height: side),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    let result = NSImage(size: NSSize(width: side, height: side))
    result.addRepresentation(rep)
    return result
}

func drawBadgeRow(
    top: CGFloat,
    title: String,
    side: Int,
    grayscale: Bool,
    panelColor: NSColor,
    textColor: NSColor
) throws {
    fillPanel(
        rectFromTop(x: 24, y: top, width: 1_752, height: 190),
        color: panelColor
    )
    drawText(
        title,
        x: 48,
        y: top + 18,
        width: 1_100,
        height: 28,
        font: .systemFont(ofSize: 20, weight: .bold),
        color: textColor
    )

    let cellWidth: CGFloat = 170
    for (index, spec) in specs.enumerated() {
        let x = 41 + CGFloat(index) * cellWidth
        let image = try renderBadge(badges[index], side: side, grayscale: grayscale)
        image.draw(
            in: rectFromTop(
                x: x + (cellWidth - CGFloat(side)) / 2,
                y: top + 48,
                width: CGFloat(side),
                height: CGFloat(side)
            )
        )
        drawText(
            "\(spec.day) · \(spec.title)",
            x: x,
            y: top + 160,
            width: cellWidth - 4,
            height: 18,
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: textColor
        )
    }
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
context.imageInterpolation = .high

NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)).fill()

drawText(
    "DockMagic · Interlock Crown production QA",
    x: 38,
    y: 24,
    width: 1_200,
    height: 42,
    font: .systemFont(ofSize: 30, weight: .bold),
    color: .white
)
drawText(
    "Selected direction 3 · ten complete milestone artifacts · no service logo or center medallion",
    x: 40,
    y: 67,
    width: 1_500,
    height: 28,
    font: .systemFont(ofSize: 16, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.72)
)

fillPanel(
    rectFromTop(x: 24, y: 104, width: 1_752, height: 200),
    color: NSColor(calibratedWhite: 0.14, alpha: 1)
)
selectedTarget.draw(
    in: rectFromTop(x: 56, y: 120, width: 168, height: 168),
    from: NSRect(origin: .zero, size: selectedTarget.size),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
drawText(
    "SELECTED VISUAL TARGET · BUILDER",
    x: 254,
    y: 134,
    width: 560,
    height: 26,
    font: .systemFont(ofSize: 13, weight: .bold),
    color: NSColor.white.withAlphaComponent(0.58)
)
drawText(
    "Interwoven enamel becomes the achievement symbol",
    x: 254,
    y: 166,
    width: 1_200,
    height: 34,
    font: .systemFont(ofSize: 24, weight: .semibold),
    color: .white
)
drawText(
    "The center is complete structural artwork. Rarity grows through the braid, crown and silhouette—not through a logo holder.",
    x: 254,
    y: 214,
    width: 1_350,
    height: 52,
    font: .systemFont(ofSize: 16, weight: .regular),
    color: NSColor.white.withAlphaComponent(0.72)
)

try drawBadgeRow(
    top: 326,
    title: "Dark hero · 112 pt",
    side: 112,
    grayscale: false,
    panelColor: NSColor(calibratedWhite: 0.15, alpha: 1),
    textColor: .white
)
try drawBadgeRow(
    top: 528,
    title: "Light collection · 58 pt",
    side: 58,
    grayscale: false,
    panelColor: NSColor(calibratedWhite: 0.96, alpha: 1),
    textColor: NSColor(calibratedWhite: 0.12, alpha: 1)
)
try drawBadgeRow(
    top: 730,
    title: "Grayscale compact · 48 pt",
    side: 48,
    grayscale: true,
    panelColor: NSColor(calibratedWhite: 0.38, alpha: 1),
    textColor: .white
)

NSGraphicsContext.restoreGraphicsState()

guard let png = representation.representation(using: .png, properties: [:]) else {
    throw BadgeQAError.pngEncodingFailed
}
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
