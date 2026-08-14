import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "DSAction" asset catalog color resource.
    static let dsAction = DeveloperToolsSupport.ColorResource(name: "DSAction", bundle: resourceBundle)

    /// The "DSActionForeground" asset catalog color resource.
    static let dsActionForeground = DeveloperToolsSupport.ColorResource(name: "DSActionForeground", bundle: resourceBundle)

    /// The "DSActivityExercise" asset catalog color resource.
    static let dsActivityExercise = DeveloperToolsSupport.ColorResource(name: "DSActivityExercise", bundle: resourceBundle)

    /// The "DSActivityMove" asset catalog color resource.
    static let dsActivityMove = DeveloperToolsSupport.ColorResource(name: "DSActivityMove", bundle: resourceBundle)

    /// The "DSDanger" asset catalog color resource.
    static let dsDanger = DeveloperToolsSupport.ColorResource(name: "DSDanger", bundle: resourceBundle)

    /// The "DSDangerForeground" asset catalog color resource.
    static let dsDangerForeground = DeveloperToolsSupport.ColorResource(name: "DSDangerForeground", bundle: resourceBundle)

    /// The "DSDockBackgroundInset" asset catalog color resource.
    static let dsDockBackgroundInset = DeveloperToolsSupport.ColorResource(name: "DSDockBackgroundInset", bundle: resourceBundle)

    /// The "DSDockBackgroundRaised" asset catalog color resource.
    static let dsDockBackgroundRaised = DeveloperToolsSupport.ColorResource(name: "DSDockBackgroundRaised", bundle: resourceBundle)

    /// The "DSDockCPU" asset catalog color resource.
    static let dsDockCPU = DeveloperToolsSupport.ColorResource(name: "DSDockCPU", bundle: resourceBundle)

    /// The "DSDockMemory" asset catalog color resource.
    static let dsDockMemory = DeveloperToolsSupport.ColorResource(name: "DSDockMemory", bundle: resourceBundle)

    /// The "DSDockOutline" asset catalog color resource.
    static let dsDockOutline = DeveloperToolsSupport.ColorResource(name: "DSDockOutline", bundle: resourceBundle)

    /// The "DSDockTrack" asset catalog color resource.
    static let dsDockTrack = DeveloperToolsSupport.ColorResource(name: "DSDockTrack", bundle: resourceBundle)

    /// The "DSFocus" asset catalog color resource.
    static let dsFocus = DeveloperToolsSupport.ColorResource(name: "DSFocus", bundle: resourceBundle)

    /// The "DSInformation" asset catalog color resource.
    static let dsInformation = DeveloperToolsSupport.ColorResource(name: "DSInformation", bundle: resourceBundle)

    /// The "DSInformationForeground" asset catalog color resource.
    static let dsInformationForeground = DeveloperToolsSupport.ColorResource(name: "DSInformationForeground", bundle: resourceBundle)

    /// The "DSOnAction" asset catalog color resource.
    static let dsOnAction = DeveloperToolsSupport.ColorResource(name: "DSOnAction", bundle: resourceBundle)

    /// The "DSOnDanger" asset catalog color resource.
    static let dsOnDanger = DeveloperToolsSupport.ColorResource(name: "DSOnDanger", bundle: resourceBundle)

    /// The "DSOnInformation" asset catalog color resource.
    static let dsOnInformation = DeveloperToolsSupport.ColorResource(name: "DSOnInformation", bundle: resourceBundle)

    /// The "DSOnProcessing" asset catalog color resource.
    static let dsOnProcessing = DeveloperToolsSupport.ColorResource(name: "DSOnProcessing", bundle: resourceBundle)

    /// The "DSOnSidebarIcon" asset catalog color resource.
    static let dsOnSidebarIcon = DeveloperToolsSupport.ColorResource(name: "DSOnSidebarIcon", bundle: resourceBundle)

    /// The "DSOnWarning" asset catalog color resource.
    static let dsOnWarning = DeveloperToolsSupport.ColorResource(name: "DSOnWarning", bundle: resourceBundle)

    /// The "DSOpaqueSurface" asset catalog color resource.
    static let dsOpaqueSurface = DeveloperToolsSupport.ColorResource(name: "DSOpaqueSurface", bundle: resourceBundle)

    /// The "DSOpaqueSurfaceChrome" asset catalog color resource.
    static let dsOpaqueSurfaceChrome = DeveloperToolsSupport.ColorResource(name: "DSOpaqueSurfaceChrome", bundle: resourceBundle)

    /// The "DSOpaqueSurfaceInset" asset catalog color resource.
    static let dsOpaqueSurfaceInset = DeveloperToolsSupport.ColorResource(name: "DSOpaqueSurfaceInset", bundle: resourceBundle)

    /// The "DSOpaqueSurfaceRaised" asset catalog color resource.
    static let dsOpaqueSurfaceRaised = DeveloperToolsSupport.ColorResource(name: "DSOpaqueSurfaceRaised", bundle: resourceBundle)

    /// The "DSOutline" asset catalog color resource.
    static let dsOutline = DeveloperToolsSupport.ColorResource(name: "DSOutline", bundle: resourceBundle)

    /// The "DSOutlineStrong" asset catalog color resource.
    static let dsOutlineStrong = DeveloperToolsSupport.ColorResource(name: "DSOutlineStrong", bundle: resourceBundle)

    /// The "DSProcessing" asset catalog color resource.
    static let dsProcessing = DeveloperToolsSupport.ColorResource(name: "DSProcessing", bundle: resourceBundle)

    /// The "DSProcessingForeground" asset catalog color resource.
    static let dsProcessingForeground = DeveloperToolsSupport.ColorResource(name: "DSProcessingForeground", bundle: resourceBundle)

    /// The "DSSelectionFill" asset catalog color resource.
    static let dsSelectionFill = DeveloperToolsSupport.ColorResource(name: "DSSelectionFill", bundle: resourceBundle)

    /// The "DSSelectionOutline" asset catalog color resource.
    static let dsSelectionOutline = DeveloperToolsSupport.ColorResource(name: "DSSelectionOutline", bundle: resourceBundle)

    /// The "DSShadow" asset catalog color resource.
    static let dsShadow = DeveloperToolsSupport.ColorResource(name: "DSShadow", bundle: resourceBundle)

    /// The "DSSidebarIconFill" asset catalog color resource.
    static let dsSidebarIconFill = DeveloperToolsSupport.ColorResource(name: "DSSidebarIconFill", bundle: resourceBundle)

    /// The "DSSidebarSelectionFill" asset catalog color resource.
    static let dsSidebarSelectionFill = DeveloperToolsSupport.ColorResource(name: "DSSidebarSelectionFill", bundle: resourceBundle)

    /// The "DSSurface" asset catalog color resource.
    static let dsSurface = DeveloperToolsSupport.ColorResource(name: "DSSurface", bundle: resourceBundle)

    /// The "DSSurfaceChrome" asset catalog color resource.
    static let dsSurfaceChrome = DeveloperToolsSupport.ColorResource(name: "DSSurfaceChrome", bundle: resourceBundle)

    /// The "DSSurfaceInset" asset catalog color resource.
    static let dsSurfaceInset = DeveloperToolsSupport.ColorResource(name: "DSSurfaceInset", bundle: resourceBundle)

    /// The "DSSurfaceRaised" asset catalog color resource.
    static let dsSurfaceRaised = DeveloperToolsSupport.ColorResource(name: "DSSurfaceRaised", bundle: resourceBundle)

    /// The "DSTextPrimary" asset catalog color resource.
    static let dsTextPrimary = DeveloperToolsSupport.ColorResource(name: "DSTextPrimary", bundle: resourceBundle)

    /// The "DSTextSecondary" asset catalog color resource.
    static let dsTextSecondary = DeveloperToolsSupport.ColorResource(name: "DSTextSecondary", bundle: resourceBundle)

    /// The "DSTextTertiary" asset catalog color resource.
    static let dsTextTertiary = DeveloperToolsSupport.ColorResource(name: "DSTextTertiary", bundle: resourceBundle)

    /// The "DSWarning" asset catalog color resource.
    static let dsWarning = DeveloperToolsSupport.ColorResource(name: "DSWarning", bundle: resourceBundle)

    /// The "DSWarningForeground" asset catalog color resource.
    static let dsWarningForeground = DeveloperToolsSupport.ColorResource(name: "DSWarningForeground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "ClaudeCodeLogo" asset catalog image resource.
    static let claudeCodeLogo = DeveloperToolsSupport.ImageResource(name: "ClaudeCodeLogo", bundle: resourceBundle)

    /// The "CodexLogo" asset catalog image resource.
    static let codexLogo = DeveloperToolsSupport.ImageResource(name: "CodexLogo", bundle: resourceBundle)

    /// The "DockMagicLogo" asset catalog image resource.
    static let dockMagicLogo = DeveloperToolsSupport.ImageResource(name: "DockMagicLogo", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "DSAction" asset catalog color.
    static var dsAction: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsAction)
#else
        .init()
#endif
    }

    /// The "DSActionForeground" asset catalog color.
    static var dsActionForeground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsActionForeground)
#else
        .init()
#endif
    }

    /// The "DSActivityExercise" asset catalog color.
    static var dsActivityExercise: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsActivityExercise)
#else
        .init()
#endif
    }

    /// The "DSActivityMove" asset catalog color.
    static var dsActivityMove: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsActivityMove)
#else
        .init()
#endif
    }

    /// The "DSDanger" asset catalog color.
    static var dsDanger: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDanger)
#else
        .init()
#endif
    }

    /// The "DSDangerForeground" asset catalog color.
    static var dsDangerForeground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDangerForeground)
#else
        .init()
#endif
    }

    /// The "DSDockBackgroundInset" asset catalog color.
    static var dsDockBackgroundInset: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDockBackgroundInset)
#else
        .init()
#endif
    }

    /// The "DSDockBackgroundRaised" asset catalog color.
    static var dsDockBackgroundRaised: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDockBackgroundRaised)
#else
        .init()
#endif
    }

    /// The "DSDockCPU" asset catalog color.
    static var dsDockCPU: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDockCPU)
#else
        .init()
#endif
    }

    /// The "DSDockMemory" asset catalog color.
    static var dsDockMemory: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDockMemory)
#else
        .init()
#endif
    }

    /// The "DSDockOutline" asset catalog color.
    static var dsDockOutline: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDockOutline)
#else
        .init()
#endif
    }

    /// The "DSDockTrack" asset catalog color.
    static var dsDockTrack: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsDockTrack)
#else
        .init()
#endif
    }

    /// The "DSFocus" asset catalog color.
    static var dsFocus: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsFocus)
#else
        .init()
#endif
    }

    /// The "DSInformation" asset catalog color.
    static var dsInformation: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsInformation)
#else
        .init()
#endif
    }

    /// The "DSInformationForeground" asset catalog color.
    static var dsInformationForeground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsInformationForeground)
#else
        .init()
#endif
    }

    /// The "DSOnAction" asset catalog color.
    static var dsOnAction: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOnAction)
#else
        .init()
#endif
    }

    /// The "DSOnDanger" asset catalog color.
    static var dsOnDanger: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOnDanger)
#else
        .init()
#endif
    }

    /// The "DSOnInformation" asset catalog color.
    static var dsOnInformation: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOnInformation)
#else
        .init()
#endif
    }

    /// The "DSOnProcessing" asset catalog color.
    static var dsOnProcessing: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOnProcessing)
#else
        .init()
#endif
    }

    /// The "DSOnSidebarIcon" asset catalog color.
    static var dsOnSidebarIcon: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOnSidebarIcon)
#else
        .init()
#endif
    }

    /// The "DSOnWarning" asset catalog color.
    static var dsOnWarning: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOnWarning)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurface" asset catalog color.
    static var dsOpaqueSurface: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOpaqueSurface)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurfaceChrome" asset catalog color.
    static var dsOpaqueSurfaceChrome: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOpaqueSurfaceChrome)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurfaceInset" asset catalog color.
    static var dsOpaqueSurfaceInset: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOpaqueSurfaceInset)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurfaceRaised" asset catalog color.
    static var dsOpaqueSurfaceRaised: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOpaqueSurfaceRaised)
#else
        .init()
#endif
    }

    /// The "DSOutline" asset catalog color.
    static var dsOutline: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOutline)
#else
        .init()
#endif
    }

    /// The "DSOutlineStrong" asset catalog color.
    static var dsOutlineStrong: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsOutlineStrong)
#else
        .init()
#endif
    }

    /// The "DSProcessing" asset catalog color.
    static var dsProcessing: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsProcessing)
#else
        .init()
#endif
    }

    /// The "DSProcessingForeground" asset catalog color.
    static var dsProcessingForeground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsProcessingForeground)
#else
        .init()
#endif
    }

    /// The "DSSelectionFill" asset catalog color.
    static var dsSelectionFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSelectionFill)
#else
        .init()
#endif
    }

    /// The "DSSelectionOutline" asset catalog color.
    static var dsSelectionOutline: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSelectionOutline)
#else
        .init()
#endif
    }

    /// The "DSShadow" asset catalog color.
    static var dsShadow: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsShadow)
#else
        .init()
#endif
    }

    /// The "DSSidebarIconFill" asset catalog color.
    static var dsSidebarIconFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSidebarIconFill)
#else
        .init()
#endif
    }

    /// The "DSSidebarSelectionFill" asset catalog color.
    static var dsSidebarSelectionFill: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSidebarSelectionFill)
#else
        .init()
#endif
    }

    /// The "DSSurface" asset catalog color.
    static var dsSurface: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSurface)
#else
        .init()
#endif
    }

    /// The "DSSurfaceChrome" asset catalog color.
    static var dsSurfaceChrome: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSurfaceChrome)
#else
        .init()
#endif
    }

    /// The "DSSurfaceInset" asset catalog color.
    static var dsSurfaceInset: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSurfaceInset)
#else
        .init()
#endif
    }

    /// The "DSSurfaceRaised" asset catalog color.
    static var dsSurfaceRaised: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsSurfaceRaised)
#else
        .init()
#endif
    }

    /// The "DSTextPrimary" asset catalog color.
    static var dsTextPrimary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsTextPrimary)
#else
        .init()
#endif
    }

    /// The "DSTextSecondary" asset catalog color.
    static var dsTextSecondary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsTextSecondary)
#else
        .init()
#endif
    }

    /// The "DSTextTertiary" asset catalog color.
    static var dsTextTertiary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsTextTertiary)
#else
        .init()
#endif
    }

    /// The "DSWarning" asset catalog color.
    static var dsWarning: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsWarning)
#else
        .init()
#endif
    }

    /// The "DSWarningForeground" asset catalog color.
    static var dsWarningForeground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dsWarningForeground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "DSAction" asset catalog color.
    static var dsAction: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsAction)
#else
        .init()
#endif
    }

    /// The "DSActionForeground" asset catalog color.
    static var dsActionForeground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsActionForeground)
#else
        .init()
#endif
    }

    /// The "DSActivityExercise" asset catalog color.
    static var dsActivityExercise: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsActivityExercise)
#else
        .init()
#endif
    }

    /// The "DSActivityMove" asset catalog color.
    static var dsActivityMove: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsActivityMove)
#else
        .init()
#endif
    }

    /// The "DSDanger" asset catalog color.
    static var dsDanger: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDanger)
#else
        .init()
#endif
    }

    /// The "DSDangerForeground" asset catalog color.
    static var dsDangerForeground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDangerForeground)
#else
        .init()
#endif
    }

    /// The "DSDockBackgroundInset" asset catalog color.
    static var dsDockBackgroundInset: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDockBackgroundInset)
#else
        .init()
#endif
    }

    /// The "DSDockBackgroundRaised" asset catalog color.
    static var dsDockBackgroundRaised: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDockBackgroundRaised)
#else
        .init()
#endif
    }

    /// The "DSDockCPU" asset catalog color.
    static var dsDockCPU: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDockCPU)
#else
        .init()
#endif
    }

    /// The "DSDockMemory" asset catalog color.
    static var dsDockMemory: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDockMemory)
#else
        .init()
#endif
    }

    /// The "DSDockOutline" asset catalog color.
    static var dsDockOutline: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDockOutline)
#else
        .init()
#endif
    }

    /// The "DSDockTrack" asset catalog color.
    static var dsDockTrack: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsDockTrack)
#else
        .init()
#endif
    }

    /// The "DSFocus" asset catalog color.
    static var dsFocus: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsFocus)
#else
        .init()
#endif
    }

    /// The "DSInformation" asset catalog color.
    static var dsInformation: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsInformation)
#else
        .init()
#endif
    }

    /// The "DSInformationForeground" asset catalog color.
    static var dsInformationForeground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsInformationForeground)
#else
        .init()
#endif
    }

    /// The "DSOnAction" asset catalog color.
    static var dsOnAction: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOnAction)
#else
        .init()
#endif
    }

    /// The "DSOnDanger" asset catalog color.
    static var dsOnDanger: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOnDanger)
#else
        .init()
#endif
    }

    /// The "DSOnInformation" asset catalog color.
    static var dsOnInformation: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOnInformation)
#else
        .init()
#endif
    }

    /// The "DSOnProcessing" asset catalog color.
    static var dsOnProcessing: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOnProcessing)
#else
        .init()
#endif
    }

    /// The "DSOnSidebarIcon" asset catalog color.
    static var dsOnSidebarIcon: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOnSidebarIcon)
#else
        .init()
#endif
    }

    /// The "DSOnWarning" asset catalog color.
    static var dsOnWarning: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOnWarning)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurface" asset catalog color.
    static var dsOpaqueSurface: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOpaqueSurface)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurfaceChrome" asset catalog color.
    static var dsOpaqueSurfaceChrome: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOpaqueSurfaceChrome)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurfaceInset" asset catalog color.
    static var dsOpaqueSurfaceInset: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOpaqueSurfaceInset)
#else
        .init()
#endif
    }

    /// The "DSOpaqueSurfaceRaised" asset catalog color.
    static var dsOpaqueSurfaceRaised: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOpaqueSurfaceRaised)
#else
        .init()
#endif
    }

    /// The "DSOutline" asset catalog color.
    static var dsOutline: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOutline)
#else
        .init()
#endif
    }

    /// The "DSOutlineStrong" asset catalog color.
    static var dsOutlineStrong: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsOutlineStrong)
#else
        .init()
#endif
    }

    /// The "DSProcessing" asset catalog color.
    static var dsProcessing: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsProcessing)
#else
        .init()
#endif
    }

    /// The "DSProcessingForeground" asset catalog color.
    static var dsProcessingForeground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsProcessingForeground)
#else
        .init()
#endif
    }

    /// The "DSSelectionFill" asset catalog color.
    static var dsSelectionFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSelectionFill)
#else
        .init()
#endif
    }

    /// The "DSSelectionOutline" asset catalog color.
    static var dsSelectionOutline: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSelectionOutline)
#else
        .init()
#endif
    }

    /// The "DSShadow" asset catalog color.
    static var dsShadow: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsShadow)
#else
        .init()
#endif
    }

    /// The "DSSidebarIconFill" asset catalog color.
    static var dsSidebarIconFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSidebarIconFill)
#else
        .init()
#endif
    }

    /// The "DSSidebarSelectionFill" asset catalog color.
    static var dsSidebarSelectionFill: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSidebarSelectionFill)
#else
        .init()
#endif
    }

    /// The "DSSurface" asset catalog color.
    static var dsSurface: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSurface)
#else
        .init()
#endif
    }

    /// The "DSSurfaceChrome" asset catalog color.
    static var dsSurfaceChrome: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSurfaceChrome)
#else
        .init()
#endif
    }

    /// The "DSSurfaceInset" asset catalog color.
    static var dsSurfaceInset: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSurfaceInset)
#else
        .init()
#endif
    }

    /// The "DSSurfaceRaised" asset catalog color.
    static var dsSurfaceRaised: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsSurfaceRaised)
#else
        .init()
#endif
    }

    /// The "DSTextPrimary" asset catalog color.
    static var dsTextPrimary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsTextPrimary)
#else
        .init()
#endif
    }

    /// The "DSTextSecondary" asset catalog color.
    static var dsTextSecondary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsTextSecondary)
#else
        .init()
#endif
    }

    /// The "DSTextTertiary" asset catalog color.
    static var dsTextTertiary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsTextTertiary)
#else
        .init()
#endif
    }

    /// The "DSWarning" asset catalog color.
    static var dsWarning: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsWarning)
#else
        .init()
#endif
    }

    /// The "DSWarningForeground" asset catalog color.
    static var dsWarningForeground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .dsWarningForeground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "DSAction" asset catalog color.
    static var dsAction: SwiftUI.Color { .init(.dsAction) }

    /// The "DSActionForeground" asset catalog color.
    static var dsActionForeground: SwiftUI.Color { .init(.dsActionForeground) }

    /// The "DSActivityExercise" asset catalog color.
    static var dsActivityExercise: SwiftUI.Color { .init(.dsActivityExercise) }

    /// The "DSActivityMove" asset catalog color.
    static var dsActivityMove: SwiftUI.Color { .init(.dsActivityMove) }

    /// The "DSDanger" asset catalog color.
    static var dsDanger: SwiftUI.Color { .init(.dsDanger) }

    /// The "DSDangerForeground" asset catalog color.
    static var dsDangerForeground: SwiftUI.Color { .init(.dsDangerForeground) }

    /// The "DSDockBackgroundInset" asset catalog color.
    static var dsDockBackgroundInset: SwiftUI.Color { .init(.dsDockBackgroundInset) }

    /// The "DSDockBackgroundRaised" asset catalog color.
    static var dsDockBackgroundRaised: SwiftUI.Color { .init(.dsDockBackgroundRaised) }

    /// The "DSDockCPU" asset catalog color.
    static var dsDockCPU: SwiftUI.Color { .init(.dsDockCPU) }

    /// The "DSDockMemory" asset catalog color.
    static var dsDockMemory: SwiftUI.Color { .init(.dsDockMemory) }

    /// The "DSDockOutline" asset catalog color.
    static var dsDockOutline: SwiftUI.Color { .init(.dsDockOutline) }

    /// The "DSDockTrack" asset catalog color.
    static var dsDockTrack: SwiftUI.Color { .init(.dsDockTrack) }

    /// The "DSFocus" asset catalog color.
    static var dsFocus: SwiftUI.Color { .init(.dsFocus) }

    /// The "DSInformation" asset catalog color.
    static var dsInformation: SwiftUI.Color { .init(.dsInformation) }

    /// The "DSInformationForeground" asset catalog color.
    static var dsInformationForeground: SwiftUI.Color { .init(.dsInformationForeground) }

    /// The "DSOnAction" asset catalog color.
    static var dsOnAction: SwiftUI.Color { .init(.dsOnAction) }

    /// The "DSOnDanger" asset catalog color.
    static var dsOnDanger: SwiftUI.Color { .init(.dsOnDanger) }

    /// The "DSOnInformation" asset catalog color.
    static var dsOnInformation: SwiftUI.Color { .init(.dsOnInformation) }

    /// The "DSOnProcessing" asset catalog color.
    static var dsOnProcessing: SwiftUI.Color { .init(.dsOnProcessing) }

    /// The "DSOnSidebarIcon" asset catalog color.
    static var dsOnSidebarIcon: SwiftUI.Color { .init(.dsOnSidebarIcon) }

    /// The "DSOnWarning" asset catalog color.
    static var dsOnWarning: SwiftUI.Color { .init(.dsOnWarning) }

    /// The "DSOpaqueSurface" asset catalog color.
    static var dsOpaqueSurface: SwiftUI.Color { .init(.dsOpaqueSurface) }

    /// The "DSOpaqueSurfaceChrome" asset catalog color.
    static var dsOpaqueSurfaceChrome: SwiftUI.Color { .init(.dsOpaqueSurfaceChrome) }

    /// The "DSOpaqueSurfaceInset" asset catalog color.
    static var dsOpaqueSurfaceInset: SwiftUI.Color { .init(.dsOpaqueSurfaceInset) }

    /// The "DSOpaqueSurfaceRaised" asset catalog color.
    static var dsOpaqueSurfaceRaised: SwiftUI.Color { .init(.dsOpaqueSurfaceRaised) }

    /// The "DSOutline" asset catalog color.
    static var dsOutline: SwiftUI.Color { .init(.dsOutline) }

    /// The "DSOutlineStrong" asset catalog color.
    static var dsOutlineStrong: SwiftUI.Color { .init(.dsOutlineStrong) }

    /// The "DSProcessing" asset catalog color.
    static var dsProcessing: SwiftUI.Color { .init(.dsProcessing) }

    /// The "DSProcessingForeground" asset catalog color.
    static var dsProcessingForeground: SwiftUI.Color { .init(.dsProcessingForeground) }

    /// The "DSSelectionFill" asset catalog color.
    static var dsSelectionFill: SwiftUI.Color { .init(.dsSelectionFill) }

    /// The "DSSelectionOutline" asset catalog color.
    static var dsSelectionOutline: SwiftUI.Color { .init(.dsSelectionOutline) }

    /// The "DSShadow" asset catalog color.
    static var dsShadow: SwiftUI.Color { .init(.dsShadow) }

    /// The "DSSidebarIconFill" asset catalog color.
    static var dsSidebarIconFill: SwiftUI.Color { .init(.dsSidebarIconFill) }

    /// The "DSSidebarSelectionFill" asset catalog color.
    static var dsSidebarSelectionFill: SwiftUI.Color { .init(.dsSidebarSelectionFill) }

    /// The "DSSurface" asset catalog color.
    static var dsSurface: SwiftUI.Color { .init(.dsSurface) }

    /// The "DSSurfaceChrome" asset catalog color.
    static var dsSurfaceChrome: SwiftUI.Color { .init(.dsSurfaceChrome) }

    /// The "DSSurfaceInset" asset catalog color.
    static var dsSurfaceInset: SwiftUI.Color { .init(.dsSurfaceInset) }

    /// The "DSSurfaceRaised" asset catalog color.
    static var dsSurfaceRaised: SwiftUI.Color { .init(.dsSurfaceRaised) }

    /// The "DSTextPrimary" asset catalog color.
    static var dsTextPrimary: SwiftUI.Color { .init(.dsTextPrimary) }

    /// The "DSTextSecondary" asset catalog color.
    static var dsTextSecondary: SwiftUI.Color { .init(.dsTextSecondary) }

    /// The "DSTextTertiary" asset catalog color.
    static var dsTextTertiary: SwiftUI.Color { .init(.dsTextTertiary) }

    /// The "DSWarning" asset catalog color.
    static var dsWarning: SwiftUI.Color { .init(.dsWarning) }

    /// The "DSWarningForeground" asset catalog color.
    static var dsWarningForeground: SwiftUI.Color { .init(.dsWarningForeground) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "DSAction" asset catalog color.
    static var dsAction: SwiftUI.Color { .init(.dsAction) }

    /// The "DSActionForeground" asset catalog color.
    static var dsActionForeground: SwiftUI.Color { .init(.dsActionForeground) }

    /// The "DSActivityExercise" asset catalog color.
    static var dsActivityExercise: SwiftUI.Color { .init(.dsActivityExercise) }

    /// The "DSActivityMove" asset catalog color.
    static var dsActivityMove: SwiftUI.Color { .init(.dsActivityMove) }

    /// The "DSDanger" asset catalog color.
    static var dsDanger: SwiftUI.Color { .init(.dsDanger) }

    /// The "DSDangerForeground" asset catalog color.
    static var dsDangerForeground: SwiftUI.Color { .init(.dsDangerForeground) }

    /// The "DSDockBackgroundInset" asset catalog color.
    static var dsDockBackgroundInset: SwiftUI.Color { .init(.dsDockBackgroundInset) }

    /// The "DSDockBackgroundRaised" asset catalog color.
    static var dsDockBackgroundRaised: SwiftUI.Color { .init(.dsDockBackgroundRaised) }

    /// The "DSDockCPU" asset catalog color.
    static var dsDockCPU: SwiftUI.Color { .init(.dsDockCPU) }

    /// The "DSDockMemory" asset catalog color.
    static var dsDockMemory: SwiftUI.Color { .init(.dsDockMemory) }

    /// The "DSDockOutline" asset catalog color.
    static var dsDockOutline: SwiftUI.Color { .init(.dsDockOutline) }

    /// The "DSDockTrack" asset catalog color.
    static var dsDockTrack: SwiftUI.Color { .init(.dsDockTrack) }

    /// The "DSFocus" asset catalog color.
    static var dsFocus: SwiftUI.Color { .init(.dsFocus) }

    /// The "DSInformation" asset catalog color.
    static var dsInformation: SwiftUI.Color { .init(.dsInformation) }

    /// The "DSInformationForeground" asset catalog color.
    static var dsInformationForeground: SwiftUI.Color { .init(.dsInformationForeground) }

    /// The "DSOnAction" asset catalog color.
    static var dsOnAction: SwiftUI.Color { .init(.dsOnAction) }

    /// The "DSOnDanger" asset catalog color.
    static var dsOnDanger: SwiftUI.Color { .init(.dsOnDanger) }

    /// The "DSOnInformation" asset catalog color.
    static var dsOnInformation: SwiftUI.Color { .init(.dsOnInformation) }

    /// The "DSOnProcessing" asset catalog color.
    static var dsOnProcessing: SwiftUI.Color { .init(.dsOnProcessing) }

    /// The "DSOnSidebarIcon" asset catalog color.
    static var dsOnSidebarIcon: SwiftUI.Color { .init(.dsOnSidebarIcon) }

    /// The "DSOnWarning" asset catalog color.
    static var dsOnWarning: SwiftUI.Color { .init(.dsOnWarning) }

    /// The "DSOpaqueSurface" asset catalog color.
    static var dsOpaqueSurface: SwiftUI.Color { .init(.dsOpaqueSurface) }

    /// The "DSOpaqueSurfaceChrome" asset catalog color.
    static var dsOpaqueSurfaceChrome: SwiftUI.Color { .init(.dsOpaqueSurfaceChrome) }

    /// The "DSOpaqueSurfaceInset" asset catalog color.
    static var dsOpaqueSurfaceInset: SwiftUI.Color { .init(.dsOpaqueSurfaceInset) }

    /// The "DSOpaqueSurfaceRaised" asset catalog color.
    static var dsOpaqueSurfaceRaised: SwiftUI.Color { .init(.dsOpaqueSurfaceRaised) }

    /// The "DSOutline" asset catalog color.
    static var dsOutline: SwiftUI.Color { .init(.dsOutline) }

    /// The "DSOutlineStrong" asset catalog color.
    static var dsOutlineStrong: SwiftUI.Color { .init(.dsOutlineStrong) }

    /// The "DSProcessing" asset catalog color.
    static var dsProcessing: SwiftUI.Color { .init(.dsProcessing) }

    /// The "DSProcessingForeground" asset catalog color.
    static var dsProcessingForeground: SwiftUI.Color { .init(.dsProcessingForeground) }

    /// The "DSSelectionFill" asset catalog color.
    static var dsSelectionFill: SwiftUI.Color { .init(.dsSelectionFill) }

    /// The "DSSelectionOutline" asset catalog color.
    static var dsSelectionOutline: SwiftUI.Color { .init(.dsSelectionOutline) }

    /// The "DSShadow" asset catalog color.
    static var dsShadow: SwiftUI.Color { .init(.dsShadow) }

    /// The "DSSidebarIconFill" asset catalog color.
    static var dsSidebarIconFill: SwiftUI.Color { .init(.dsSidebarIconFill) }

    /// The "DSSidebarSelectionFill" asset catalog color.
    static var dsSidebarSelectionFill: SwiftUI.Color { .init(.dsSidebarSelectionFill) }

    /// The "DSSurface" asset catalog color.
    static var dsSurface: SwiftUI.Color { .init(.dsSurface) }

    /// The "DSSurfaceChrome" asset catalog color.
    static var dsSurfaceChrome: SwiftUI.Color { .init(.dsSurfaceChrome) }

    /// The "DSSurfaceInset" asset catalog color.
    static var dsSurfaceInset: SwiftUI.Color { .init(.dsSurfaceInset) }

    /// The "DSSurfaceRaised" asset catalog color.
    static var dsSurfaceRaised: SwiftUI.Color { .init(.dsSurfaceRaised) }

    /// The "DSTextPrimary" asset catalog color.
    static var dsTextPrimary: SwiftUI.Color { .init(.dsTextPrimary) }

    /// The "DSTextSecondary" asset catalog color.
    static var dsTextSecondary: SwiftUI.Color { .init(.dsTextSecondary) }

    /// The "DSTextTertiary" asset catalog color.
    static var dsTextTertiary: SwiftUI.Color { .init(.dsTextTertiary) }

    /// The "DSWarning" asset catalog color.
    static var dsWarning: SwiftUI.Color { .init(.dsWarning) }

    /// The "DSWarningForeground" asset catalog color.
    static var dsWarningForeground: SwiftUI.Color { .init(.dsWarningForeground) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "ClaudeCodeLogo" asset catalog image.
    static var claudeCodeLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .claudeCodeLogo)
#else
        .init()
#endif
    }

    /// The "CodexLogo" asset catalog image.
    static var codexLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .codexLogo)
#else
        .init()
#endif
    }

    /// The "DockMagicLogo" asset catalog image.
    static var dockMagicLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dockMagicLogo)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "ClaudeCodeLogo" asset catalog image.
    static var claudeCodeLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .claudeCodeLogo)
#else
        .init()
#endif
    }

    /// The "CodexLogo" asset catalog image.
    static var codexLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .codexLogo)
#else
        .init()
#endif
    }

    /// The "DockMagicLogo" asset catalog image.
    static var dockMagicLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .dockMagicLogo)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

