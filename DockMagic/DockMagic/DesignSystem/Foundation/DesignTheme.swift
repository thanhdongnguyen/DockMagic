import SwiftUI

/// Semantic values consumed by the design system. Concrete colors belong to
/// the app's `ProjectTheme` and its asset catalog.
struct DesignTheme {
    let action: Color
    let onAction: Color
    let information: Color
    let onInformation: Color
    let processing: Color
    let onProcessing: Color
    let dockTrack: Color
    let dockBackgroundRaised: Color
    let dockBackgroundInset: Color
    let dockOutline: Color
    let warning: Color
    let onWarning: Color
    let danger: Color
    let onDanger: Color
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
}
