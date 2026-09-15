import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Review harness only. Neutral presentation colors do not enter product code.
struct PilotBadge: View {
    let bundle: Bundle
    let name: String
    let side: CGFloat
    let scale: CGFloat
    let locked: Bool
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(name, bundle: bundle)
                .resizable()
                .interpolation(name.hasSuffix("-png") && side <= 60 ? (scale >= 2 ? .none : .medium) : .high)
                .scaledToFit()
                .saturation(locked ? 0 : 1)
                .opacity(locked ? 0.34 : 1)
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(8, side * 0.13), weight: .bold))
                    .padding(max(3, side * 0.055))
                    .background(.background, in: Circle())
                    .overlay(Circle().stroke(.primary, lineWidth: 0.75))
                    .padding(side * 0.06)
            }
        }.frame(width: side, height: side)
    }
}

struct PilotSheet: View {
    let bundle: Bundle
    let scale: CGFloat
    let dark: Bool
    let contrast: Bool
    let grayscale: Bool
    let locked: Bool
    let reduceTransparency: Bool
    private var surface: Color { Color(nsColor: dark ? NSColor(white: 0.13, alpha: 1) : .white) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("DockMagic · native SVG pilot").font(.system(size: 24, weight: .bold))
                Text("SwiftUI / compiled asset catalog · \(Int(scale))× · \(dark ? "Dark" : "Light")\(contrast ? " · Increased Contrast" : "")\(grayscale ? " · Grayscale" : "")\(locked ? " · Locked" : "")\(reduceTransparency ? " · Reduce Transparency" : "")")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(["first-prompt", "builder"], id: \.self) { slug in
                VStack(alignment: .leading, spacing: 16) {
                    Text(slug == "builder" ? "Builder · 14 days" : "First Prompt · 1 day")
                        .font(.system(size: 17, weight: .semibold))
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(["png", "svg", "compact"], id: \.self) { variant in
                            VStack(spacing: 14) {
                                Text(variant == "png" ? "CURRENT PNG" : variant == "svg" ? "SVG MASTER" : "SVG COMPACT")
                                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                                PilotBadge(bundle: bundle, name: "\(slug)-\(variant)", side: 185, scale: scale, locked: locked)
                                Divider()
                                HStack(alignment: .bottom, spacing: 12) {
                                    ForEach([32,48,58,112], id: \.self) { side in
                                        VStack(spacing: 5) {
                                            PilotBadge(bundle: bundle, name: "\(slug)-\(variant)", side: CGFloat(side), scale: scale, locked: locked)
                                            Text("\(side) pt").font(.system(size: 9)).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
                .background(surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(contrast ? 0.8 : 0.18), lineWidth: contrast ? 2 : 1))
            }
            Text("Raster column uses the production size/density interpolation rule. SVG columns use preserved vector assets.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 1100)
        .background(Color(nsColor: dark ? NSColor(white: 0.08, alpha: 1) : NSColor(white: 0.96, alpha: 1)))
        .environment(\.colorScheme, dark ? .dark : .light)
        // These accessibility EnvironmentValues are read-only on macOS.
        // The review fixture explicitly increases its outline contrast and
        // uses opaque surfaces for the reduced-transparency case.
        .environment(\.displayScale, scale)
        .saturation(grayscale ? 0 : 1)
    }
}

@MainActor
func writePNG<V: View>(_ view: V, scale: CGFloat, path: URL, forceGrayscale: Bool = false) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.cgImage,
          let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "BadgePilot", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to render \(path.lastPathComponent)"])
    }
    // ImageRenderer's headless output does not apply the saturation filter in
    // this environment. Use a real monochrome color space for review fixtures
    // rather than incorrectly labeling a colored image as grayscale.
    let outputImage: CGImage
    if forceGrayscale {
        guard let grayContext = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 2,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "BadgePilot", code: 3)
        }
        grayContext.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let grayImage = grayContext.makeImage() else { throw NSError(domain: "BadgePilot", code: 4) }
        outputImage = grayImage
    } else {
        outputImage = image
    }
    CGImageDestinationAddImage(destination, outputImage, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain:"BadgePilot",code:2) }
    print("\(path.lastPathComponent): \(image.width) × \(image.height)")
}

@main struct PilotRenderer {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3, let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Usage: render-pilot <BadgePilot.bundle> <output-directory>")
        }
        let out = URL(fileURLWithPath: CommandLine.arguments[2])
        for slug in ["first-prompt", "builder"] {
            for variant in ["png", "svg", "compact"] {
                let name = "\(slug)-\(variant)"
                guard let image = bundle.image(forResource: NSImage.Name(name)) else { fatalError("Missing compiled asset \(name)") }
                print("Loaded \(name): \(image.size)")
            }
        }
        for (name, scale, dark, contrast, gray, locked, reduced) in [
            ("dark-2x",2.0,true,false,false,false,false),
            ("light-1x",1.0,false,false,false,false,false),
            ("contrast-2x",2.0,true,true,false,false,false),
            ("grayscale-2x",2.0,true,false,true,false,false),
            ("locked-2x",2.0,true,false,false,true,false),
            ("reduced-transparency-2x",2.0,true,false,false,false,true)
        ] {
            let appearance: NSAppearance.Name = contrast ? .accessibilityHighContrastDarkAqua : (dark ? .darkAqua : .aqua)
            var renderError: Error?
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                do {
                    try writePNG(PilotSheet(bundle:bundle, scale:scale, dark:dark, contrast:contrast, grayscale:gray, locked:locked, reduceTransparency:reduced), scale:scale, path:out.appendingPathComponent("native-\(name).png"), forceGrayscale:gray || locked)
                } catch { renderError = error }
            }
            if let renderError { throw renderError }
        }
        for slug in ["first-prompt","builder"] {
            try writePNG(PilotBadge(bundle:bundle, name:"\(slug)-svg", side:1536, scale:2, locked:false), scale:2, path:out.appendingPathComponent("native-\(slug)-3072.png"))
        }
    }
}
