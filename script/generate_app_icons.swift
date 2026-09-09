import AppKit
import Foundation

struct IconSlot {
    let filename: String
    let pixels: Int
}

enum IconGenerationError: Error {
    case invalidArguments
    case unreadableSource(String)
    case bitmapAllocationFailed(Int)
    case contextCreationFailed(Int)
    case pngEncodingFailed(Int)
}

let slots = [
    IconSlot(filename: "DockMagicAppIcon-16.png", pixels: 16),
    IconSlot(filename: "DockMagicAppIcon-16@2x.png", pixels: 32),
    IconSlot(filename: "DockMagicAppIcon-32.png", pixels: 32),
    IconSlot(filename: "DockMagicAppIcon-32@2x.png", pixels: 64),
    IconSlot(filename: "DockMagicAppIcon-128.png", pixels: 128),
    IconSlot(filename: "DockMagicAppIcon-128@2x.png", pixels: 256),
    IconSlot(filename: "DockMagicAppIcon-256.png", pixels: 256),
    IconSlot(filename: "DockMagicAppIcon-256@2x.png", pixels: 512),
    IconSlot(filename: "DockMagicAppIcon-512.png", pixels: 512),
    IconSlot(filename: "DockMagicAppIcon-512@2x.png", pixels: 1_024)
]

guard CommandLine.arguments.count == 3 else {
    throw IconGenerationError.invalidArguments
}

let sourcePath = CommandLine.arguments[1]
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    throw IconGenerationError.unreadableSource(sourcePath)
}

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

func renderIcon(pixels: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.bitmapAllocationFailed(pixels)
    }

    representation.size = NSSize(width: pixels, height: pixels)

    guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
        throw IconGenerationError.contextCreationFailed(pixels)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    context.shouldAntialias = true
    context.imageInterpolation = .high

    let side = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor.clear.setFill()
    NSBezierPath(rect: canvas).fill()

    // Keep the bundled icon aligned with DockIconRenderingRules.contentFraction:
    // an 824-pixel body centered inside a 1024-pixel canvas.
    let margin = side * (100.0 / 1_024.0)
    let iconRect = canvas.insetBy(dx: margin, dy: margin)
    let cornerRadius = iconRect.width * 0.22
    let borderWidth = max(1, side * 0.018)
    let outerPath = NSBezierPath(
        roundedRect: iconRect,
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = max(1, side * 0.025)
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.012)
    shadow.set()
    NSColor(calibratedWhite: 0.16, alpha: 0.96).setFill()
    outerPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let contentRect = iconRect.insetBy(dx: borderWidth, dy: borderWidth)
    let contentPath = NSBezierPath(
        roundedRect: contentRect,
        xRadius: max(0, cornerRadius - borderWidth),
        yRadius: max(0, cornerRadius - borderWidth)
    )

    NSGraphicsContext.saveGraphicsState()
    contentPath.addClip()
    sourceImage.draw(
        in: contentRect,
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    outerPath.lineWidth = borderWidth
    NSColor(calibratedWhite: 0.12, alpha: 0.78).setStroke()
    outerPath.stroke()

    let highlightInset = borderWidth * 0.72
    let highlightPath = NSBezierPath(
        roundedRect: iconRect.insetBy(dx: highlightInset, dy: highlightInset),
        xRadius: max(0, cornerRadius - highlightInset),
        yRadius: max(0, cornerRadius - highlightInset)
    )
    highlightPath.lineWidth = max(0.5, side * 0.004)
    NSColor.white.withAlphaComponent(0.68).setStroke()
    highlightPath.stroke()

    guard let png = representation.representation(
        using: .png,
        properties: [:]
    ) else {
        throw IconGenerationError.pngEncodingFailed(pixels)
    }

    return png
}

for slot in slots {
    let outputURL = outputDirectory.appendingPathComponent(slot.filename)
    try renderIcon(pixels: slot.pixels).write(to: outputURL, options: .atomic)
}
