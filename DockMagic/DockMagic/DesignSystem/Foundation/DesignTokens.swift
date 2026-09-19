import SwiftUI

/// Appearance controls the Maia Light/Dark palette; app-owned surfaces are opaque.
enum DSAppearanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    static let settingsCases: [Self] = [
        .system,
        .light,
        .dark
    ]

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var detail: String {
        switch self {
        case .system:
            "Follow the macOS appearance."
        case .light:
            "Use the light Maia palette."
        case .dark:
            "Use the dark Maia palette."
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var usesGlassMaterials: Bool { false }
}

enum DSRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let large: CGFloat = 10
    static let extraLarge: CGFloat = 14
    static let card: CGFloat = 18
    static let doubleExtraLarge: CGFloat = 22
    static let capsule: CGFloat = 26
    static let fixedSmall = small
    static let fixedMedium = medium
    static let fixedLarge = extraLarge
    static let fixedExtraLarge = card
    static let keycap = small
    static let control = capsule
    static let inset = extraLarge
    static let row = medium
    static let panel = card
    static let largePanel = card

    static func concentric(parentRadius: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, parentRadius - padding)
    }
}

enum DSSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32

    static let iconGap: CGFloat = 6
    static let field: CGFloat = 12
    static let fieldGroup: CGFloat = 28
    static let compact = small
    static let standard = medium
    static let section = large
    static let panel = xLarge
}

enum DSTypography {
    static func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let result = DSFonts.font(size: size, weight: weight)
        return design == .monospaced ? result.monospacedDigit() : result
    }
    enum Surface { case settings, dashboard }

    /// Named roles remain surface-specific; every role resolves to bundled Geist.
    /// Dock renderers choose proportional sizes from the same foundation.
    enum Dashboard {
        static let headline = DSFonts.font(size: 20, weight: .semibold)
        static let panelTitle = DSFonts.font(size: 16, weight: .medium)
        static let body = DSFonts.font(size: 14)
        static let bodyEmphasis = DSFonts.font(size: 14, weight: .medium)
        static let metadata = DSFonts.font(size: 12, weight: .medium)
        static let caption = DSFonts.font(size: 11)
        static let metric = DSFonts.font(size: 24, weight: .bold)
    }

    static let title = DSFonts.font(size: 32, weight: .bold)
    static let headline = DSFonts.font(size: 20, weight: .semibold)
    static let panelTitle = DSFonts.font(size: 16, weight: .medium)
    static let sectionTitle = DSFonts.font(size: 14, weight: .semibold)
    static let bodyLarge = DSFonts.font(size: 16)
    static let body = DSFonts.font(size: 14)
    static let bodyEmphasis = DSFonts.font(size: 14, weight: .medium)
    static let metadata = DSFonts.font(size: 12, weight: .medium)
    static let caption = DSFonts.font(size: 11)
    static let keycap = DSFonts.font(size: 11, weight: .medium)
    static let settingsTitle = title
    static let metric = DSFonts.font(size: 24, weight: .bold)
}

enum DSMotion {
    static let buttonPress = Animation.easeOut(duration: 0.12)
    static let rowHover = Animation.easeOut(duration: 0.16)
    static let focus = Animation.easeOut(duration: 0.14)
    static let metricChange = Animation.easeOut(duration: 0.32)
}

enum DSLayout {
    static let minimumWindowWidth: CGFloat = 1_160
    // Native title-bar and window-capture chrome add about 104 pt in total,
    // producing the 1,160 x 724 reference window at the default size.
    static let minimumWindowHeight: CGFloat = 620
    static let sidebarMinimumWidth: CGFloat = 268
    static let sidebarIdealWidth: CGFloat = 268
    static let sidebarMaximumWidth: CGFloat = 268
    static let detailMaximumWidth: CGFloat = 900
    static let detailHorizontalPadding: CGFloat = 52
    static let detailVerticalPadding: CGFloat = 34
    static let dockPreviewSize: CGFloat = 152
    static let compactControlWidth: CGFloat = 176
    static let sliderMaximumWidth: CGFloat = 260
}

enum DSElevation {
    case none
    case primary
    case secondary

    var radius: CGFloat {
        switch self {
        case .none:
            0
        case .primary:
            10
        case .secondary:
            5
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .none:
            0
        case .primary:
            5
        case .secondary:
            2
        }
    }
}

enum DSSurfaceKind {
    case shell
    case panel
    case raised
    case inset
    case chrome

    /// App-owned Maia surfaces are opaque in every appearance.
    var isGlassEligible: Bool { false }
}

enum DSSemanticRole {
    case neutral
    case information
    case processing
    case warning
    case danger
}
