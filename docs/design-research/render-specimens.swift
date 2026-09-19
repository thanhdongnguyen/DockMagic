// Research specimens only. This file is not part of the DockMagic app target.
// Run from the repository root; fonts are registered for this process only.
import AppKit
import CoreText
import SwiftUI

enum Family: String, CaseIterable {
    case system = "SF Pro"
    case rounded = "SF Pro Rounded"
    case geist = "Geist"
    case plex = "IBM Plex Sans"

    var note: String {
        switch self {
        case .system: return "Đề xuất chính: native, dễ đọc, gọn."
        case .rounded: return "Mềm hơn; phù hợp số liệu nổi bật."
        case .geist: return "Gọn, hiện đại; phương án thay thế."
        case .plex: return "Nét kỹ thuật rõ; cá tính hơn."
        }
    }

    func nativeFont(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .system: return .systemFont(ofSize: size, weight: weight)
        case .rounded:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: size)!
        case .geist, .plex:
            let suffix = weight == .semibold ? "SemiBold" : weight == .medium ? "Medium" : "Regular"
            let plexName = weight == .semibold ? "IBMPlexSans-SmBld" : weight == .medium ? "IBMPlexSans-Medm" : "IBMPlexSans"
            let name = self == .geist ? "Geist-\(suffix)" : plexName
            guard let font = NSFont(name: name, size: size) else { fatalError("Missing font: \(name)") }
            return font
        }
    }

    func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> Font {
        Font(nativeFont(size, weight))
    }
}

struct Palette {
    let dark: Bool
    let contrast: Bool
    var canvas: Color { color(dark ? "1F1E1E" : "F5F4F2") }
    var panel: Color { color(dark ? "1F1E1E" : "FFFFFF") }
    var primary: Color { color(dark ? "FFFFFF" : "000000") }
    var secondary: Color { contrast ? primary : color(dark ? "F5F3F0" : "434242").opacity(dark ? 0.6 : 0.8) }
    var border: Color { color(contrast ? (dark ? "8A8988" : "767676") : (dark ? "3C3C3B" : "D6D5D4")) }
    var action: Color { color(dark ? "0091FF" : "0088FF") }
    var actionText: Color { color(dark ? "0091FF" : "0066C0") }
    func color(_ hex: String) -> Color {
        let n = UInt32(hex, radix: 16)!
        return Color(red: Double(n >> 16) / 255, green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255)
    }
}

struct FontPanel: View {
    let family: Family
    let p: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(family.rawValue).font(.system(size: 20, weight: .semibold))
                Spacer()
                Text(family == .system ? "Khuyên dùng" : "So sánh").font(.system(size: 12, weight: .medium)).foregroundStyle(p.secondary)
            }
            Text(family.note).font(.system(size: 12)).foregroundStyle(p.secondary)
            Divider().overlay(p.border)
            VStack(alignment: .leading, spacing: 8) {
                Text("Hoạt động hôm nay").font(family.font(16, .semibold))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("128.450").font(family.font(32, .semibold)).monospacedDigit()
                    Text("tokens").font(family.font(12)).foregroundStyle(p.secondary)
                }
                HStack {
                    Text("Hạn mức còn lại").font(family.font(14))
                    Spacer()
                    Text("72,8%").font(family.font(14, .semibold)).monospacedDigit()
                }
                HStack {
                    Text("Làm mới sau").font(family.font(14))
                    Spacer()
                    Text("02:48:16").font(family.font(14, .medium)).monospacedDigit()
                }
                Text("Đã cập nhật 2 phút trước").font(family.font(12)).foregroundStyle(p.secondary)
            }
            Divider().overlay(p.border)
            VStack(alignment: .leading, spacing: 8) {
                Text("Aa Bb Gg  0 O  1 I l  0123456789").font(family.font(14)).monospacedDigit()
                Text("Tiếng Việt: Ắ Ằ Ẳ Ẵ Ặ ế ề ễ ộ ớ ự đ").font(family.font(14))
                Text("12 pt: Phiên làm việc • 1.024 MB • $18.42").font(family.font(12)).foregroundStyle(p.secondary)
                Text("11 pt: Chỉ dùng cho chú thích không thiết yếu").font(family.font(11)).foregroundStyle(p.secondary)
            }
        }
        .foregroundStyle(p.primary)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(p.border, lineWidth: p.contrast ? 1.5 : 1))
    }
}

struct SpecimenBoard: View {
    let p: Palette
    let grayscale: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("DockMagic / So sánh typography").font(.system(size: 28, weight: .semibold))
                Text("Mẫu SwiftUI với dữ liệu minh họa. Cùng nội dung, cỡ chữ và độ đậm ở cả bốn phương án.")
                    .font(.system(size: 14)).foregroundStyle(p.secondary)
            }
            HStack(alignment: .top, spacing: 24) {
                FontPanel(family: .system, p: p)
                FontPanel(family: .rounded, p: p)
            }
            HStack(alignment: .top, spacing: 24) {
                FontPanel(family: .geist, p: p)
                FontPanel(family: .plex, p: p)
            }
            Text("\(p.dark ? "Dark" : "Light")\(p.contrast ? " / Increased Contrast specimen" : "")\(grayscale ? " / Grayscale" : "") • Nền đặc • Số dùng monospacedDigit() • Không phải ảnh app đang chạy")
                .font(.system(size: 12)).foregroundStyle(p.secondary)
        }
        .padding(32)
        .frame(width: 1060)
        .foregroundStyle(p.primary)
        .background(p.canvas)
        .environment(\.colorScheme, p.dark ? .dark : .light)
        .saturation(grayscale ? 0 : 1)
    }
}

struct PaletteBoard: View {
    let p: Palette
    private var swatches: [(String, String)] {
        [("Canvas", p.dark ? "1F1E1E" : "F5F4F2"), ("Raised", p.dark ? "1F1E1E" : "FFFFFF"),
         ("Action", p.dark ? "0091FF" : "0088FF"), ("Action text", p.dark ? "0091FF" : "0066C0"),
         ("Warning fill", p.dark ? "FF9230" : "FF8D28"), ("Danger fill", p.dark ? "FF4245" : "FF383C")]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("DockMagic / Palette đề xuất giữ lại").font(.system(size: 28, weight: .semibold))
            Text("Một họ xanh cho thao tác. Neutral cho nền và secondary. Cam, đỏ chỉ dùng khi có trạng thái thật.")
                .font(.system(size: 14)).foregroundStyle(p.secondary)
            HStack(spacing: 16) {
                ForEach(swatches, id: \.0) { label, hex in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 12).fill(p.color(hex)).frame(height: 78)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 1))
                        Text(label).font(.system(size: 12, weight: .medium))
                        Text("#\(hex)").font(.system(size: 12, design: .monospaced)).foregroundStyle(p.secondary)
                    }
                }
            }
            HStack(spacing: 16) {
                Text("Làm mới").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.color("000000"))
                    .padding(.horizontal, 16).padding(.vertical, 10).background(p.action, in: RoundedRectangle(cornerRadius: 12))
                Text("Xem chi tiết").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(p.panel, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 1))
                Text("Mở lịch sử").font(.system(size: 14, weight: .medium)).foregroundStyle(p.actionText)
            }
            Text("Mẫu màu tĩnh từ assets hiện có. Nhãn nút xanh dùng onAction (đen), không tự đổi sang trắng.")
                .font(.system(size: 12)).foregroundStyle(p.secondary)
        }.padding(32).frame(width: 1060).foregroundStyle(p.primary).background(p.canvas)
    }
}

@main
enum RenderSpecimens {
    @MainActor static func main() throws {
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/design-research")
        let fonts = base.appendingPathComponent("fonts")
        for file in try FileManager.default.contentsOfDirectory(at: fonts, includingPropertiesForKeys: nil) where ["ttf", "otf"].contains(file.pathExtension) {
            var error: Unmanaged<CFError>?
            guard CTFontManagerRegisterFontsForURL(file as CFURL, .process, &error) else {
                fatalError("Font registration failed: \(file.lastPathComponent), \(String(describing: error))")
            }
        }
        var checks: [[String: Any]] = []
        let sample = "Hoạt động hôm nay Hạn mức còn lại Đã cập nhật Tiếng Việt Ắ Ằ Ẳ Ẵ Ặ ế ề ễ ộ ớ ự đ 0123456789 $ € ₫"
        for family in Family.allCases {
            for weight: NSFont.Weight in [.regular, .medium, .semibold] {
                let font = family.nativeFont(14, weight)
                for (normalization, string) in [("NFC", sample.precomposedStringWithCanonicalMapping), ("NFD", sample.decomposedStringWithCanonicalMapping)] {
                    let chars = Array(string.utf16)
                    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
                    let complete = CTFontGetGlyphsForCharacters(font as CTFont, chars, &glyphs, chars.count)
                    let missing = zip(chars, glyphs).filter { $0.1 == 0 }.map { String(format: "U+%04X", $0.0) }
                    checks.append(["family": family.rawValue, "postScriptName": font.fontName, "normalization": normalization, "sampleCovered": complete, "missing": missing])
                }
            }
        }
        try JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]).write(to: base.appendingPathComponent("font-validation.json"))
        func save<V: View>(_ view: V, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let cg = renderer.cgImage else { fatalError("Rendering failed: \(name)") }
            let rep = NSBitmapImageRep(cgImage: cg)
            guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG failed") }
            try png.write(to: base.appendingPathComponent(name + ".png"))
            print("\(name).png \(cg.width)x\(cg.height)")
        }
        for dark in [false, true] {
            let p = Palette(dark: dark, contrast: false)
            try save(SpecimenBoard(p: p, grayscale: false), "fonts-\(dark ? "dark" : "light")")
            try save(PaletteBoard(p: p), "palette-\(dark ? "dark" : "light")")
            try save(SpecimenBoard(p: Palette(dark: dark, contrast: true), grayscale: false), "fonts-\(dark ? "dark" : "light")-contrast")
        }
        try save(SpecimenBoard(p: Palette(dark: false, contrast: false), grayscale: true), "fonts-grayscale")
        print("Font sample checks: \(checks.count); failures: \(checks.filter { ($0["sampleCovered"] as? Bool) == false }.count)")
    }
}
