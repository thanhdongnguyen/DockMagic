import SwiftUI

/// Semantic values consumed by the design system. Concrete colors belong to
/// the app's `ProjectTheme` and its asset catalog.
struct DesignTheme {
    let action: Color
    let actionForeground: Color
    let onAction: Color
    /// User-approved blue, confined to the enabled shared binary-switch track.
    let switchActive: Color
    let onSwitchActive: Color
    /// Codex quantitative content only; never a control or status accent.
    let codexActivity: Color
    let codexActivityForeground: Color
    let information: Color
    let informationForeground: Color
    let onInformation: Color
    let processing: Color
    let processingForeground: Color
    let onProcessing: Color
    /// Verified streak-day content only; never chrome, focus, or status.
    let streakActive: Color
    let onStreakActive: Color
    /// Weather-condition data colors, confined to Weather glyph renderers.
    let weatherSun: Color
    let weatherMoon: Color
    let weatherCloud: Color
    let weatherWind: Color
    let weatherRain: Color
    let weatherIce: Color
    let weatherStorm: Color
    /// Opaque Weather scenes shared by the Dock renderer and hover card.
    let weatherSceneSun: Color
    let weatherSceneMoon: Color
    let weatherSceneCloud: Color
    let weatherSceneWind: Color
    let weatherSceneRain: Color
    let weatherSceneIce: Color
    let weatherSceneStorm: Color
    let weatherSceneForeground: Color
    /// Bounded Calendar content markers, never chrome or control accents.
    let calendarBirthday: Color
    let calendarHoliday: Color
    let calendarWork: Color
    let dockTrack: Color
    let dockBackgroundRaised: Color
    let dockBackgroundInset: Color
    let dockOutline: Color
    let dockForeground: Color
    let warning: Color
    let warningForeground: Color
    let onWarning: Color
    let danger: Color
    let dangerForeground: Color
    let onDanger: Color
    let inputOutline: Color
    let focus: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let surface: Color
    let surfaceRaised: Color
    let surfaceInset: Color
    let surfaceChrome: Color
    let opaqueSurface: Color
    let opaqueSurfaceRaised: Color
    let opaqueSurfaceInset: Color
    let opaqueSurfaceChrome: Color
    let outline: Color
    let outlineStrong: Color
    let shadow: Color
    let selectionFill: Color
    let selectionOutline: Color
    let sidebarSelectionFill: Color
    let sidebarIconFill: Color
    let onSidebarIcon: Color
    let terminalBackground: Color
    let terminalChrome: Color
    let terminalForeground: Color
    let terminalSecondary: Color
    let terminalOutline: Color
    let terminalClose: Color
    let terminalMinimize: Color
    let terminalZoom: Color

    /// Quantitative price series, confined to market chart renderers.
    /// Uses the Neutral series role; never used to tint market chrome.
    var marketPriceSeries: Color { actionForeground }

    func surface(for kind: DSSurfaceKind) -> Color {
        switch kind {
        case .shell, .panel:
            surface
        case .raised:
            surfaceRaised
        case .inset:
            surfaceInset
        case .chrome:
            surfaceChrome
        }
    }

    func opaqueSurface(for kind: DSSurfaceKind) -> Color {
        switch kind {
        case .shell, .panel:
            opaqueSurface
        case .raised:
            opaqueSurfaceRaised
        case .inset:
            opaqueSurfaceInset
        case .chrome:
            opaqueSurfaceChrome
        }
    }

    func color(for role: DSSemanticRole) -> Color? {
        switch role {
        case .neutral:
            nil
        case .information:
            information
        case .processing:
            processing
        case .warning:
            warning
        case .danger:
            danger
        }
    }

    func foreground(for role: DSSemanticRole) -> Color {
        switch role {
        case .neutral:
            textPrimary
        case .information:
            onInformation
        case .processing:
            onProcessing
        case .warning:
            onWarning
        case .danger:
            onDanger
        }
    }

    /// Accessible accent for text and icons drawn directly on content
    /// surfaces. The brighter base colors remain available for fills.
    func accentForeground(for role: DSSemanticRole) -> Color {
        switch role {
        case .neutral:
            textPrimary
        case .information:
            informationForeground
        case .processing:
            processingForeground
        case .warning:
            warningForeground
        case .danger:
            dangerForeground
        }
    }
}
