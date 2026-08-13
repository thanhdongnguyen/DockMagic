import SwiftUI

/// Appearance controls only color-scheme selection. Liquid Glass navigation
/// chrome is part of every mode instead of being a separate appearance.
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
            "Follow macOS and use Liquid Glass navigation chrome."
        case .light:
            "Use the light palette with Liquid Glass navigation chrome."
        case .dark:
            "Use the dark palette with Liquid Glass navigation chrome."
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

    var usesGlassMaterials: Bool {
        true
    }
}

enum DSRadius {
    static let fixedSmall: CGFloat = 8
    static let fixedMedium: CGFloat = 12
    static let fixedLarge: CGFloat = 16
    static let fixedExtraLarge: CGFloat = 24
    static let capsule: CGFloat = 999

    static let keycap = fixedSmall
    static let control = fixedMedium
    static let inset = fixedMedium
    static let row = fixedLarge
    static let panel = fixedLarge
    static let largePanel = fixedExtraLarge

    /// Sigma describes concentric corners as the parent radius minus padding.
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

    static let compact = small
    static let standard = medium
    static let section = large
    static let panel = xLarge
}

enum DSTypography {
    static let title = Font.system(size: 32, weight: .bold)
    static let headline = Font.system(size: 20, weight: .semibold)
    static let panelTitle = Font.system(size: 16, weight: .semibold)
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    static let bodyLarge = Font.system(size: 16)
    static let body = Font.system(size: 14)
    static let bodyEmphasis = Font.system(size: 14, weight: .semibold)
    static let metadata = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11)
    static let keycap = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let settingsTitle = title
    static let metric = Font.system(size: 24, weight: .bold, design: .rounded)
}

enum DSMotion {
    static let buttonPress = Animation.easeOut(duration: 0.12)
    static let rowHover = Animation.easeOut(duration: 0.16)
    static let focus = Animation.easeOut(duration: 0.14)
    static let metricChange = Animation.easeOut(duration: 0.32)
}

enum DSLayout {
    static let minimumWindowWidth: CGFloat = 900
    static let minimumWindowHeight: CGFloat = 640
    static let sidebarMinimumWidth: CGFloat = 210
    static let sidebarIdealWidth: CGFloat = 232
    static let sidebarMaximumWidth: CGFloat = 272
    static let detailMaximumWidth: CGFloat = 800
    static let detailPadding: CGFloat = 32
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

    var material: Material {
        switch self {
        case .chrome:
            .thinMaterial
        case .shell, .panel, .raised:
            .regularMaterial
        case .inset:
            .ultraThinMaterial
        }
    }

    /// Public Sigma guidance reserves Liquid Glass for the navigation layer.
    var isGlassEligible: Bool { self == .chrome }
}

enum DSSemanticRole {
    case neutral
    case information
    case processing
    case warning
    case danger
}

enum DSButtonKind {
    case neutral
    case primary
    case destructive
}
