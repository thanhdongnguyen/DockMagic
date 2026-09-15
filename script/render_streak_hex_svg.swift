import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Standalone review fixture; this does not change or launch DockMagic.
struct HexRecord: Decodable, Identifiable {
    let day: Int
    let title: String
    let slug: String
    var id: String { slug }
}
struct HexManifest: Decodable { let badges: [HexRecord] }

struct HexBadge: View {
    let bundle: Bundle
    let name: String
    let side: CGFloat
    var scale: CGFloat = 1
    var locked = false
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(name, bundle: bundle).resizable()
                .interpolation(name.hasSuffix("-png") && side <= 60 ? (scale >= 2 ? .none : .medium) : .high)
                .scaledToFit().opacity(locked ? 0.34 : 1)
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(8, side * 0.13), weight: .bold))
                    .padding(max(3, side * 0.055))
                    .background(.background, in: Circle())
                    .overlay(Circle().stroke(.primary, lineWidth: 1))
                    .padding(side * 0.06)
            }
        }.frame(width: side, height: side)
    }
}

struct HexCollection: View {
    let bundle: Bundle
    let badges: [HexRecord]
    let scale: CGFloat
    let dark: Bool
    let contrast: Bool
    let locked: Bool
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("DockMagic / Hex SVG").font(.system(size: 28, weight: .bold))
                Text("10 collectibles · native preserved vectors · \(label)")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            ForEach(0..<2, id: \.self) { row in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(badges[(row * 5)..<(row * 5 + 5)])) { badge in
                        VStack(spacing: 8) {
                            HexBadge(bundle: bundle, name: "\(badge.slug)-master", side: 200, scale: scale, locked: locked)
                            Text(badge.title).font(.system(size: 16, weight: .semibold))
                            Text("\(badge.day) \(badge.day == 1 ? "day" : "days")\(locked ? " · Locked" : "")")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        .frame(width: 212).padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(contrast ? 0.9 : 0.15), lineWidth: contrast ? 2 : 1))
                    }
                }
            }
            Text("Solid vector paths · Transparent canvas · Production asset source")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(32)
        .background(Color(nsColor: dark ? NSColor(white: 0.09, alpha: 1) : .white))
        .environment(\.colorScheme, dark ? .dark : .light)
        .environment(\.displayScale, scale)
    }
}

struct HexSizeSheet: View {
    let bundle: Bundle
    let badges: [HexRecord]
    let scale: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Hex SVG / Small-size proof · \(Int(scale))×").font(.system(size: 24, weight: .bold))
            Text("Concept PNG vs vector master vs compact · 32 / 48 / 58 / 112 pt")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            HStack {
                Text("MILESTONE").frame(width: 136, alignment: .leading)
                ForEach(["CONCEPT PNG", "SVG MASTER", "SVG COMPACT"], id: \.self) { title in
                    Text(title).frame(width: 310)
                }
            }.font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
            ForEach(badges) { badge in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(badge.title).font(.system(size: 15, weight: .semibold))
                        Text("\(badge.day) days").font(.system(size: 12)).foregroundStyle(.secondary)
                    }.frame(width: 136, alignment: .leading)
                    ForEach(["png", "master", "compact"], id: \.self) { variant in
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach([32,48,58,112], id: \.self) { size in
                                VStack(spacing: 5) {
                                    HexBadge(bundle: bundle, name: "\(badge.slug)-\(variant)", side: CGFloat(size), scale: scale)
                                    Text("\(size)").font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                        }.frame(width: 310)
                    }
                }.padding(.vertical, 12)
                Divider()
            }
            Text("Compact removes secondary gleams and increases contour weight; icon, rank and silhouette stay consistent.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(28).background(Color.white)
        .environment(\.colorScheme, .light).environment(\.displayScale, scale)
    }
}

@MainActor
func hexWritePNG<V: View>(_ view: V, scale: CGFloat, path: URL, grayscale: Bool = false) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.cgImage else { throw NSError(domain: "HexSVG", code: 1) }
    let output: CGImage
    if grayscale {
        // Headless ImageRenderer does not reliably apply .saturation in this environment.
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 2, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw NSError(domain: "HexSVG", code: 2) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let gray = context.makeImage() else { throw NSError(domain: "HexSVG", code: 3) }
        output = gray
    } else { output = image }
    if path.lastPathComponent.hasSuffix("-3072.png") {
        // Verify actual alpha, not merely the presence of a PNG alpha channel.
        guard let rgba = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
            let pixels = rgba.data?.assumingMemoryBound(to: UInt8.self) else { throw NSError(domain: "HexSVG", code: 6) }
        rgba.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for (x,y) in [(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)] {
            precondition(pixels[(y * image.width + x) * 4 + 3] == 0, "Nontransparent canvas corner")
        }
        precondition(pixels[((image.height/2) * image.width + image.width/2) * 4 + 3] == 255, "Missing badge center")
    }
    guard let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "HexSVG", code: 4)
    }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "HexSVG", code: 5) }
    print("\(path.lastPathComponent): \(image.width) × \(image.height)")
}

@main struct HexRenderer {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3, let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Usage: render-hex <HexSVG.bundle> <output-directory>")
        }
        let out = URL(fileURLWithPath: CommandLine.arguments[2])
        let manifest = try JSONDecoder().decode(HexManifest.self, from: Data(contentsOf: out.appendingPathComponent("manifest.json")))
        let badges = manifest.badges
        precondition(badges.count == 10)
        for badge in badges {
            for variant in ["png", "master", "compact"] {
                let name = "\(badge.slug)-\(variant)"
                guard bundle.image(forResource: NSImage.Name(name)) != nil else { fatalError("Missing native asset: \(name)") }
            }
        }
        for (name, scale, dark, contrast, gray, locked) in [
            ("light-1x",1.0,false,false,false,false),
            ("dark-2x",2.0,true,false,false,false),
            ("contrast-2x",2.0,true,true,false,false),
            ("grayscale-2x",2.0,true,false,true,false),
            ("locked-2x",2.0,true,false,true,true),
            ("reduced-transparency-2x",2.0,true,false,false,false)
        ] {
            let appearance: NSAppearance.Name = contrast ? .accessibilityHighContrastDarkAqua : (dark ? .darkAqua : .aqua)
            var failure: Error?
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                do {
                    try hexWritePNG(HexCollection(bundle: bundle, badges: badges, scale: scale, dark: dark, contrast: contrast, locked: locked, label: name), scale: scale, path: out.appendingPathComponent("native-collection-\(name).png"), grayscale: gray)
                } catch { failure = error }
            }
            if let failure { throw failure }
        }
        for scale in [1.0,2.0] {
            for page in 0..<2 {
                try hexWritePNG(HexSizeSheet(bundle: bundle, badges: Array(badges[(page*5)..<(page*5+5)]), scale: scale), scale: scale, path: out.appendingPathComponent("native-sizes-page-\(page+1)-\(Int(scale))x.png"))
            }
        }
        for slug in ["01-first-prompt","14-builder","730-continuum"] {
            try hexWritePNG(HexBadge(bundle: bundle, name: "\(slug)-master", side: 1536), scale: 2, path: out.appendingPathComponent("native-\(slug)-3072.png"))
        }
        print("Verified all 30 native assets (10 reference PNGs + 20 SVGs).")
    }
}
