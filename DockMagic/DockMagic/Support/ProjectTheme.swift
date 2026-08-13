import Foundation
import SwiftUI

/// DockMagic's product palette. Reusable components know only `DesignTheme`;
/// this mapping and the named Color Set values remain application-owned.
enum ProjectTheme {
    static let current = DesignTheme(
        action: Color("DSAction"),
        actionForeground: Color("DSActionForeground"),
        onAction: Color("DSOnAction"),
        information: Color("DSInformation"),
        informationForeground: Color("DSInformationForeground"),
        onInformation: Color("DSOnInformation"),
        processing: Color("DSProcessing"),
        processingForeground: Color("DSProcessingForeground"),
        onProcessing: Color("DSOnProcessing"),
        dockTrack: Color("DSDockTrack"),
        dockBackgroundRaised: Color("DSDockBackgroundRaised"),
        dockBackgroundInset: Color("DSDockBackgroundInset"),
        dockOutline: Color("DSDockOutline"),
        warning: Color("DSWarning"),
        warningForeground: Color("DSWarningForeground"),
        onWarning: Color("DSOnWarning"),
        danger: Color("DSDanger"),
        dangerForeground: Color("DSDangerForeground"),
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

private struct DSAppearanceModeKey: EnvironmentKey {
    static let defaultValue = DSAppearanceMode.system
}

/// Optional deterministic overrides for previews and render tests. Production
/// leaves both values nil so macOS remains the source of truth.
struct DSAccessibilityOverrides: Equatable, Sendable {
    var reduceTransparency: Bool?
    var increaseContrast: Bool?

    init(
        reduceTransparency: Bool? = nil,
        increaseContrast: Bool? = nil
    ) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
    }
}

private struct DSAccessibilityOverridesKey: EnvironmentKey {
    static let defaultValue = DSAccessibilityOverrides()
}

extension EnvironmentValues {
    var designTheme: DesignTheme {
        get { self[DesignThemeKey.self] }
        set { self[DesignThemeKey.self] = newValue }
    }

    var dsAppearanceMode: DSAppearanceMode {
        get { self[DSAppearanceModeKey.self] }
        set { self[DSAppearanceModeKey.self] = newValue }
    }

    var dsAccessibilityOverrides: DSAccessibilityOverrides {
        get { self[DSAccessibilityOverridesKey.self] }
        set { self[DSAccessibilityOverridesKey.self] = newValue }
    }
}

extension DSAppearanceMode {
    static let storageKey = "DockMagicAppearanceMode"
    static let didChangeNotification = Notification.Name(
        "DockMagicAppearanceModeDidChange"
    )

    static func stored(in defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey) else {
            return .system
        }

        // Migrate the former standalone Liquid Glass mode. Glass is now built
        // into System, Light, and Dark, so the closest behavior is System.
        if rawValue == "liquidGlass" {
            return .system
        }

        return Self(rawValue: rawValue) ?? .system
    }
}

/// Keeps UI-test persistence isolated from the developer's real preferences.
/// Release builds always use the standard application defaults domain.
enum DockMagicRuntimeDefaults {
    static var current: UserDefaults {
#if DEBUG
        if let suiteName = ProcessInfo.processInfo.environment[
            "DockMagicUITestDefaultsSuite"
        ], !suiteName.isEmpty,
           let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
#endif
        return .standard
    }
}

/// Installs DockMagic's semantic palette and the selected appearance once at a
/// scene or AppKit host boundary. Tests and previews can pass an override while
/// production follows the persisted preference.
struct DockMagicThemeRoot<Content: View>: View {
    let content: Content
    private let appearanceOverride: DSAppearanceMode?

    @AppStorage(DSAppearanceMode.storageKey)
    private var storedAppearance = DSAppearanceMode.system.rawValue

    init(
        content: Content,
        appearanceMode: DSAppearanceMode? = nil
    ) {
        self.content = content
        appearanceOverride = appearanceMode
    }

    var body: some View {
        content
            .environment(\.designTheme, ProjectTheme.current)
            .environment(\.dsAppearanceMode, appearanceMode)
            .preferredColorScheme(appearanceMode.preferredColorScheme)
            .tint(ProjectTheme.current.action)
    }

    private var appearanceMode: DSAppearanceMode {
        appearanceOverride
            ?? DSAppearanceMode(rawValue: storedAppearance)
            ?? .system
    }
}
