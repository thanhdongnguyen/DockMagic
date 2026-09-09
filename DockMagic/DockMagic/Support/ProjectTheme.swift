import Foundation
import SwiftUI

/// DockMagic's product palette. Reusable components know only `DesignTheme`;
/// this mapping and the named Color Set values remain application-owned.
enum ProjectTheme {
    /// Persistent renderer default matching DSAction's Light blue. User-picked
    /// colors remain confined to Dock renders and their Settings previews.
    static let defaultUsageRingColor = DockColor(red: 0, green: 136 / 255, blue: 1)
    /// Claude Code usage data uses the service's clay-orange identity as its
    /// single persistent data accent. Status colors still come from
    /// `DesignTheme` and replace this accent when they carry meaning.
    static let claudeCodeUsage = Color("DSClaudeCodeUsage")

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
        dockForeground: Color("DSDockForeground"),
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

    /// Product-owned renderer colors offered by the inline Settings palette.
    /// The values include every existing feature default so Reset Defaults
    /// always restores a visibly selected swatch.
    static let rendererColorOptions: [DSColorSwatchOption] = [
        .init(
            id: "orange",
            title: "Orange",
            color: Color(red: 1, green: 0.552_941, blue: 0.156_863),
            hex: "#FF8D28"
        ),
        .init(
            id: "cyan",
            title: "Cyan",
            color: Color(red: 0, green: 0.752_941, blue: 0.909_804),
            hex: "#00C0E8"
        ),
        .init(
            id: "blue",
            title: "Blue",
            color: Color(red: 0, green: 0.533_333, blue: 1),
            hex: "#0088FF"
        ),
        .init(
            id: "indigo",
            title: "Indigo",
            color: Color(red: 0.380_392, green: 0.333_333, blue: 0.960_784),
            hex: "#6155F5"
        ),
        .init(
            id: "purple",
            title: "Purple",
            color: Color(red: 0.796_078, green: 0.188_235, blue: 0.878_431),
            hex: "#CB30E0"
        ),
        .init(
            id: "pink",
            title: "Pink",
            color: Color(red: 1, green: 0.176_471, blue: 0.333_333),
            hex: "#FF2D55"
        ),
        .init(
            id: "green",
            title: "Green",
            color: Color(red: 0.203_922, green: 0.780_392, blue: 0.349_020),
            hex: "#34C759"
        ),
        .init(
            id: "red",
            title: "Red",
            color: Color(red: 1, green: 0.219_608, blue: 0.235_294),
            hex: "#FF383C"
        ),
        .init(
            id: "yellow",
            title: "Yellow",
            color: Color(red: 1, green: 0.729_412, blue: 0.196_078),
            hex: "#FFBA32"
        ),
        .init(
            id: "sky",
            title: "Sky",
            color: Color(red: 0.258_824, green: 0.776_471, blue: 0.968_627),
            hex: "#42C6F7"
        ),
        .init(
            id: "mint",
            title: "Mint",
            color: Color(red: 0, green: 0.784_314, blue: 0.701_961),
            hex: "#00C8B3"
        ),
        .init(
            id: "clay",
            title: "Clay",
            color: Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255),
            hex: "#D97757"
        )
    ]
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
    var reduceMotion: Bool?

    init(
        reduceTransparency: Bool? = nil,
        increaseContrast: Bool? = nil,
        reduceMotion: Bool? = nil
    ) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.reduceMotion = reduceMotion
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
