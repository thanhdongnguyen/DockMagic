import SwiftUI

enum DSRadius {
    static let keycap: CGFloat = 6
    static let control: CGFloat = 8
    static let inset: CGFloat = 10
    static let row: CGFloat = 12
    static let panel: CGFloat = 16
    static let largePanel: CGFloat = 20
}

enum DSSpacing {
    static let compact: CGFloat = 6
    static let standard: CGFloat = 10
    static let section: CGFloat = 14
    static let panel: CGFloat = 16
}

enum DSTypography {
    static let panelTitle = Font.system(size: 14, weight: .semibold)
    static let sectionTitle = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 12)
    static let bodyEmphasis = Font.system(size: 12, weight: .semibold)
    static let metadata = Font.system(size: 10.5, weight: .medium)
    static let caption = Font.system(size: 10)
    static let keycap = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let settingsTitle = Font.system(size: 24, weight: .bold)
    static let metric = Font.system(size: 24, weight: .bold, design: .rounded)
}

enum DSMotion {
    static let buttonPress = Animation.easeOut(duration: 0.10)
    static let rowHover = Animation.easeOut(duration: 0.12)
    static let focus = Animation.easeOut(duration: 0.10)
    static let metricChange = Animation.easeOut(duration: 0.35)
}

enum DSSurfaceKind {
    case shell
    case panel
    case raised
    case inset
    case chrome

    var usesThinMaterial: Bool {
        switch self {
        case .inset, .chrome:
            true
        case .shell, .panel, .raised:
            false
        }
    }
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
