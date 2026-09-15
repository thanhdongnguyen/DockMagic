import AppKit
import Foundation

struct BadgeSpec {
    let day: Int
    let title: String
    let assetDirectory: String
    let filename: String
}

enum BadgeQAGenerationError: Error {
    case bitmapAllocationFailed
    case contextCreationFailed
    case missingImage(String)
    case pngEncodingFailed
}

let badges = [
    BadgeSpec(day: 1, title: "First Prompt", assetDirectory: "StreakBadgeFirstPrompt.imageset", filename: "StreakBadgeFirstPrompt.svg"),
    BadgeSpec(day: 3, title: "Spark", assetDirectory: "StreakBadgeSpark.imageset", filename: "StreakBadgeSpark.svg"),
    BadgeSpec(day: 7, title: "Loop", assetDirectory: "StreakBadgeLoop.imageset", filename: "StreakBadgeLoop.svg"),
    BadgeSpec(day: 14, title: "Builder", assetDirectory: "StreakBadgeBuilder.imageset", filename: "StreakBadgeBuilder.svg"),
    BadgeSpec(day: 30, title: "Flow", assetDirectory: "StreakBadgeFlow.imageset", filename: "StreakBadgeFlow.svg"),
    BadgeSpec(day: 60, title: "Navigator", assetDirectory: "StreakBadgeNavigator.imageset", filename: "StreakBadgeNavigator.svg"),
    BadgeSpec(day: 100, title: "Century", assetDirectory: "StreakBadgeCentury.imageset", filename: "StreakBadgeCentury.svg"),
    BadgeSpec(day: 180, title: "Architect", assetDirectory: "StreakBadgeArchitect.imageset", filename: "StreakBadgeArchitect.svg"),
    BadgeSpec(day: 365, title: "Keystone", assetDirectory: "StreakBadgeCodexCore.imageset", filename: "StreakBadgeCodexCore.svg"),
    BadgeSpec(day: 730, title: "Continuum", assetDirectory: "StreakBadgeContinuum.imageset", filename: "StreakBadgeContinuum.svg")
]

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : rootURL.appendingPathComponent(
        "docs/streak-concepts/pinterest-v2/victory-crest-production-contact-sheet.png"
    )
let assetRoot = rootURL.appendingPathComponent("DockMagic/DockMagic/Assets.xcassets")

func loadImage(_ url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw BadgeQAGenerationError.missingImage(url.path)
    }
    return image
}

let frames = try badges.map { spec in
    try loadImage(
        assetRoot
            .appendingPathComponent(spec.assetDirectory)
            .appendingPathComponent(spec.filename)
    )
}
let claudeLogo = try loadImage(
    assetRoot.appendingPathComponent("ClaudeCodeLogo.imageset/ClaudeCodeLogo.svg")
)
let codexLogo = try loadImage(
    assetRoot.appendingPathComponent("CodexLogo.imageset/CodexLogo.svg")
)
let selectedTarget = try loadImage(
    rootURL.appendingPathComponent(
        "docs/streak-concepts/pinterest-v2/victory-crest-claude.png"
    )
)

let canvasWidth = 1_800
let canvasHeight = 1_250
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
    throw BadgeQAGenerationError.bitmapAllocationFailed
}
representation.size = NSSize(width: canvasWidth, height: canvasHeight)
guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
    throw BadgeQAGenerationError.contextCreationFailed
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
        withAttributes: [
            .font: font,
            .foregroundColor: color
        ]
    )
}

func fillPanel(_ rect: NSRect, color: NSColor, radius: CGFloat = 22) {
    color.setFill()
    NSBezierPath(
        roundedRect: rect,
        xRadius: radius,
        yRadius: radius
    ).fill()
}

func renderBadge(
    frame: NSImage,
    logo: NSImage,
    side: Int,
    grayscale: Bool
) throws -> NSImage {
    let sampleCount = grayscale ? 2 : 4
    let colorSpace: NSColorSpaceName = grayscale ? .deviceWhite : .deviceRGB
    guard let badgeRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: sampleCount,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: colorSpace,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw BadgeQAGenerationError.bitmapAllocationFailed
    }
    badgeRep.size = NSSize(width: side, height: side)
    guard let badgeContext = NSGraphicsContext(bitmapImageRep: badgeRep) else {
        throw BadgeQAGenerationError.contextCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = badgeContext
    badgeContext.shouldAntialias = true
    badgeContext.imageInterpolation = .high
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()

    let badgeRect = NSRect(x: 0, y: 0, width: side, height: side)
    frame.draw(
        in: badgeRect,
        from: NSRect(origin: .zero, size: frame.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )

    let logoSide = max(11, CGFloat(side) * 0.22)
    let logoRect = NSRect(
        x: (CGFloat(side) - logoSide) / 2,
        y: (CGFloat(side) - logoSide) / 2,
        width: logoSide,
        height: logoSide
    )
    logo.draw(
        in: logoRect,
        from: NSRect(origin: .zero, size: logo.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: side, height: side))
    image.addRepresentation(badgeRep)
    return image
}

func drawBadgeRow(
    top: CGFloat,
    panelColor: NSColor,
    title: String,
    logo: NSImage,
    side: Int,
    grayscale: Bool = false,
    pairedLogo: NSImage? = nil,
    textColor: NSColor
) throws {
    let panel = rectFromTop(x: 24, y: top, width: 1_752, height: 192)
    fillPanel(panel, color: panelColor)
    drawText(
        title,
        x: 48,
        y: top + 18,
        width: 700,
        height: 28,
        font: .systemFont(ofSize: 20, weight: .bold),
        color: textColor
    )

    let cellWidth: CGFloat = 170
    for (index, spec) in badges.enumerated() {
        let cellX = 41 + CGFloat(index) * cellWidth
        if let pairedLogo {
            let first = try renderBadge(
                frame: frames[index],
                logo: logo,
                side: side,
                grayscale: grayscale
            )
            let second = try renderBadge(
                frame: frames[index],
                logo: pairedLogo,
                side: side,
                grayscale: grayscale
            )
            first.draw(
                in: rectFromTop(
                    x: cellX + 17,
                    y: top + 55,
                    width: CGFloat(side),
                    height: CGFloat(side)
                )
            )
            second.draw(
                in: rectFromTop(
                    x: cellX + 88,
                    y: top + 55,
                    width: CGFloat(side),
                    height: CGFloat(side)
                )
            )
        } else {
            let badge = try renderBadge(
                frame: frames[index],
                logo: logo,
                side: side,
                grayscale: grayscale
            )
            badge.draw(
                in: rectFromTop(
                    x: cellX + (cellWidth - CGFloat(side)) / 2,
                    y: top + 48,
                    width: CGFloat(side),
                    height: CGFloat(side)
                )
            )
        }

        drawText(
            "\(spec.day) · \(spec.title)",
            x: cellX,
            y: top + 162,
            width: cellWidth - 5,
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
    "DockMagic · Victory Crest production QA",
    x: 38,
    y: 24,
    width: 1_000,
    height: 42,
    font: .systemFont(ofSize: 30, weight: .bold),
    color: .white
)
drawText(
    "Selected Option 1 · ten milestone frames · exact runtime Claude Code / Codex marks",
    x: 40,
    y: 67,
    width: 1_400,
    height: 28,
    font: .systemFont(ofSize: 16, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.72)
)

let targetPanel = rectFromTop(x: 24, y: 104, width: 1_752, height: 208)
fillPanel(targetPanel, color: NSColor(calibratedWhite: 0.135, alpha: 1))
selectedTarget.draw(
    in: rectFromTop(x: 56, y: 120, width: 176, height: 176),
    from: NSRect(origin: .zero, size: selectedTarget.size),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
drawText(
    "SOURCE VISUAL TARGET",
    x: 270,
    y: 132,
    width: 440,
    height: 26,
    font: .systemFont(ofSize: 13, weight: .bold),
    color: NSColor.white.withAlphaComponent(0.6)
)
drawText(
    "Broad faceted silhouette · thick warm-metal rim · graphite / ivory / cobalt enamel",
    x: 270,
    y: 164,
    width: 1_350,
    height: 32,
    font: .systemFont(ofSize: 22, weight: .semibold),
    color: .white
)
drawText(
    "Production keeps one blank graphite medallion as a deterministic service-logo safe zone. Rarity grows through silhouette and structural hierarchy, never text, numerals, glow, or micro-circuitry.",
    x: 270,
    y: 211,
    width: 1_350,
    height: 56,
    font: .systemFont(ofSize: 16, weight: .regular),
    color: NSColor.white.withAlphaComponent(0.74)
)

try drawBadgeRow(
    top: 330,
    panelColor: NSColor(calibratedWhite: 0.16, alpha: 1),
    title: "Claude Code · hero scale 112 pt",
    logo: claudeLogo,
    side: 112,
    textColor: .white
)
try drawBadgeRow(
    top: 538,
    panelColor: NSColor(calibratedWhite: 0.16, alpha: 1),
    title: "Codex · hero scale 112 pt",
    logo: codexLogo,
    side: 112,
    textColor: .white
)
try drawBadgeRow(
    top: 746,
    panelColor: NSColor(calibratedWhite: 0.95, alpha: 1),
    title: "Light collection · Claude Code + Codex · 58 pt",
    logo: claudeLogo,
    side: 58,
    pairedLogo: codexLogo,
    textColor: NSColor(calibratedWhite: 0.13, alpha: 1)
)
try drawBadgeRow(
    top: 954,
    panelColor: NSColor(calibratedWhite: 0.32, alpha: 1),
    title: "Grayscale compact · both services · 48 pt",
    logo: claudeLogo,
    side: 48,
    grayscale: true,
    pairedLogo: codexLogo,
    textColor: .white
)

NSGraphicsContext.restoreGraphicsState()

guard let png = representation.representation(using: .png, properties: [:]) else {
    throw BadgeQAGenerationError.pngEncodingFailed
}
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
