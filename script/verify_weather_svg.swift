// Run after building DockMagic: swift script/verify_weather_svg.swift /path/to/DockMagic.app /path/to/output
import AppKit
import SwiftUI

@MainActor
enum WeatherSVGVerification {
    struct Scene {
        let name: String
        let light: UInt32
        let dark: UInt32
    }

    static let scenes: [Scene] = [
        .init(name: "Sun", light: 0x216691, dark: 0x15466C),
        .init(name: "Moon", light: 0x29355F, dark: 0x18213D),
        .init(name: "Cloud", light: 0x415773, dark: 0x293C53),
        .init(name: "Wind", light: 0x256A72, dark: 0x184D57),
        .init(name: "Rain", light: 0x295683, dark: 0x1C416B),
        .init(name: "Ice", light: 0x2B697E, dark: 0x17495E),
        .init(name: "Storm", light: 0x4A3866, dark: 0x30264C)
    ]

    static func verify(appURL: URL, outputURL: URL) throws {
        guard let bundle = Bundle(url: appURL) else {
            throw VerificationError("Cannot open app bundle at \(appURL.path)")
        }
        try FileManager.default.createDirectory(
            at: outputURL, withIntermediateDirectories: true
        )
        _ = NSApplication.shared

        for (mode, appearanceName, increasedContrast, grayscale) in [
            ("light", NSAppearance.Name.aqua, false, false),
            ("dark", .darkAqua, false, false),
            ("contrast", .accessibilityHighContrastDarkAqua, true, false),
            ("grayscale", .darkAqua, false, true),
            // The backdrop contains no material; reduced transparency retains this solid rendering.
            ("reduce-transparency", .darkAqua, false, false)
        ] {
            guard let appearance = NSAppearance(named: appearanceName) else {
                throw VerificationError("Missing \(mode) appearance")
            }
            var modeMinimum = Double.infinity
            for (width, height) in [(48, 48), (96, 96), (440, 420)] {
                let size = "\(width)x\(height)"
                let frameWidth = CGFloat(width)
                let frameHeight = CGFloat(height)
                var signatures = Set<Data>()
                for scene in scenes {
                    let name = "WeatherScene\(scene.name)"
                    guard let artwork = bundle.image(forResource: NSImage.Name(name)) else {
                        throw VerificationError("Missing bundled SVG: \(name)")
                    }
                    let hex = mode == "light" ? scene.light : scene.dark
                    let backdrop = ZStack {
                        Color(
                            red: Double((hex >> 16) & 255) / 255,
                            green: Double((hex >> 8) & 255) / 255,
                            blue: Double(hex & 255) / 255
                        )
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: frameWidth, height: frameHeight)
                            .clipped()
                            .opacity(increasedContrast || width < 64 ? 0.45 : 0.7)
                            .blendMode(.multiply)
                    }
                    .compositingGroup()
                    .frame(width: frameWidth, height: frameHeight)
                    let content = backdrop
                        .environment(\.colorScheme, mode == "light" ? .light : .dark)
                        .grayscale(grayscale ? 1 : 0)
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 1
                    var rendered: NSImage?
                    appearance.performAsCurrentDrawingAppearance {
                        rendered = renderer.nsImage
                    }
                    guard let image = rendered,
                          let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let png = bitmap.representation(
                            using: NSBitmapImageRep.FileType.png,
                            properties: [:]
                          ) else {
                        throw VerificationError("Cannot render \(name) at \(size) pt in \(mode)")
                    }
                    signatures.insert(png)
                    let minimum = try minimumWhiteContrast(bitmap)
                    guard minimum >= 4.5 else {
                        throw VerificationError(
                            "\(name) \(mode) \(size) pt: white contrast \(minimum) < 4.5"
                        )
                    }
                    modeMinimum = min(modeMinimum, minimum)
                    try png.write(to: outputURL.appendingPathComponent(
                        "\(scene.name)-\(mode)-\(size).png"
                    ))
                }
                guard signatures.count == scenes.count else {
                    throw VerificationError("Scenes not distinct at \(size) pt in \(mode)")
                }
            }
            print("\(mode): minimum white contrast \(String(format: "%.2f", modeMinimum)):1")
        }
        print("PASS: 7 bundled scenes × 5 appearances × 3 sizes (105 renders).")
    }

    static func minimumWhiteContrast(_ bitmap: NSBitmapImageRep) throws -> Double {
        var minimum = Double.infinity
        let step = bitmap.pixelsWide <= 48 ? 1 : 4
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: step) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    throw VerificationError("Cannot inspect pixel at \(x), \(y)")
                }
                let rgb = [color.redComponent, color.greenComponent, color.blueComponent]
                let linear = rgb.map { value -> Double in
                    let c = Double(value)
                    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
                }
                let luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
                minimum = min(minimum, 1.05 / (luminance + 0.05))
            }
        }
        return minimum
    }

    struct VerificationError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift script/verify_weather_svg.swift DockMagic.app output-directory\n", stderr)
    exit(2)
}
do {
    try MainActor.assumeIsolated {
        try WeatherSVGVerification.verify(
            appURL: URL(fileURLWithPath: CommandLine.arguments[1]),
            outputURL: URL(fileURLWithPath: CommandLine.arguments[2])
        )
    }
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
