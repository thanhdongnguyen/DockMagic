import AppKit
import CoreText
import SwiftUI

/// Bundled, process-local Geist. CoreText's cascade handles unsupported glyphs
/// (including U+20AB) without replacing the rest of a label's family.
enum DSFonts {
    static let postScriptNames = ["Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold"]

    private static let registration: Void = {
        for name in postScriptNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "otf", subdirectory: "MaiaFonts") else {
                assertionFailure("Missing bundled font: \(name)")
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }()

    static func register() { _ = registration }

    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy, .bold: return "Geist-Bold"
        case .semibold: return "Geist-SemiBold"
        case .medium: return "Geist-Medium"
        default: return "Geist-Regular"
        }
    }

    static func coreText(size: CGFloat, weight: Font.Weight = .regular) -> CTFont {
        register()
        let fallback = CTFontCreateUIFontForLanguage(.system, size, nil)!
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: name(for: weight),
            kCTFontCascadeListAttribute: [CTFontCopyFontDescriptor(fallback)]
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font(coreText(size: size, weight: weight))
    }
}
