import SwiftUI

/// DockMagic's product palette. Reusable components know only `DesignTheme`;
/// this mapping and the named Color Set values remain application-owned.
enum ProjectTheme {
    static let current = DesignTheme(
        action: Color("DSAction"),
        onAction: Color("DSOnAction"),
        information: Color("DSInformation"),
        onInformation: Color("DSOnInformation"),
        processing: Color("DSProcessing"),
        onProcessing: Color("DSOnProcessing"),
        dockTrack: Color("DSDockTrack"),
        dockBackgroundRaised: Color("DSDockBackgroundRaised"),
        dockBackgroundInset: Color("DSDockBackgroundInset"),
        dockOutline: Color("DSDockOutline"),
        warning: Color("DSWarning"),
        onWarning: Color("DSOnWarning"),
        danger: Color("DSDanger"),
        onDanger: Color("DSOnDanger"),
        focus: Color("DSFocus"),
        textPrimary: Color("DSTextPrimary"),
        textSecondary: Color("DSTextSecondary"),
        textTertiary: Color("DSTextTertiary"),
        surface: Color("DSSurface"),
        surfaceRaised: Color("DSSurfaceRaised"),
        surfaceInset: Color("DSSurfaceInset"),
        surfaceChrome: Color("DSSurfaceChrome"),
        opaqueSurface: Color("DSOpaqueSurface"),
        opaqueSurfaceRaised: Color("DSOpaqueSurfaceRaised"),
        opaqueSurfaceInset: Color("DSOpaqueSurfaceInset"),
        opaqueSurfaceChrome: Color("DSOpaqueSurfaceChrome"),
        outline: Color("DSOutline"),
        outlineStrong: Color("DSOutlineStrong"),
        shadow: Color("DSShadow"),
        selectionFill: Color("DSSelectionFill"),
        selectionOutline: Color("DSSelectionOutline"),
        sidebarSelectionFill: Color("DSSidebarSelectionFill"),
        sidebarIconFill: Color("DSSidebarIconFill"),
        onSidebarIcon: Color("DSOnSidebarIcon")
    )
}

private struct DesignThemeKey: EnvironmentKey {
    static let defaultValue = ProjectTheme.current
}

extension EnvironmentValues {
    var designTheme: DesignTheme {
        get { self[DesignThemeKey.self] }
        set { self[DesignThemeKey.self] = newValue }
    }
}

/// Installs the product theme and the app's intentional Light appearance once
/// at a scene or AppKit host boundary.
struct DockMagicThemeRoot<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .environment(\.designTheme, ProjectTheme.current)
            .preferredColorScheme(.light)
    }
}
