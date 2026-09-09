import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CodexDashboardCaptureConfiguration: Equatable, Sendable {
    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    let appearanceMode: DSAppearanceMode

    var dashboardSize: CGSize {
        DockHoverCardLayout.size(panelSize: panelSize, pointerEdge: pointerEdge)
    }
}

struct CodexDashboardCaptureArtifact: Equatable, Sendable {
    let pngData: Data
    let fileName: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum CodexDashboardCaptureError: LocalizedError {
    case bitmapAllocationFailed
    case pngEncodingFailed
    case unexpectedPixelSize(width: Int, height: Int)
    case pasteboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .bitmapAllocationFailed:
            "DockMagic could not allocate the dashboard image."
        case .pngEncodingFailed:
            "DockMagic could not encode the dashboard as PNG."
        case let .unexpectedPixelSize(width, height):
            "The dashboard rendered at an unexpected size: \(width) × \(height) px."
        case .pasteboardWriteFailed:
            "DockMagic could not copy the PNG to the clipboard."
        }
    }
}

@MainActor
enum CodexDashboardCaptureService {
    static let rasterScale: CGFloat = 4

    static func pixelDimensions(
        for configuration: CodexDashboardCaptureConfiguration
    ) -> (width: Int, height: Int) {
        let size = configuration.dashboardSize
        return (
            Int((size.width * rasterScale).rounded()),
            Int((size.height * rasterScale).rounded())
        )
    }

    static func pixelSizeLabel(
        for configuration: CodexDashboardCaptureConfiguration
    ) -> String {
        let dimensions = pixelDimensions(for: configuration)
        return "\(dimensions.width) × \(dimensions.height) px"
    }

    static func render(
        state: CodexUsageState,
        serviceStatus: ServiceStatusState = .operational(provider: .codex),
        configuration: CodexDashboardCaptureConfiguration,
        now: Date = .now,
        initialStreakCelebration: TokenUsageStreakCelebration? = nil,
        streakCelebrationAutoDismissDelay: Duration = .milliseconds(2_800),
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        try renderDashboard(
            content: CodexHoverDashboardView(
                state: state,
                serviceStatus: serviceStatus,
                now: now,
                initialStreakCelebration: initialStreakCelebration,
                streakCelebrationAutoDismissDelay: streakCelebrationAutoDismissDelay
            ),
            configuration: configuration,
            fileName: defaultFileName(at: now),
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderClaudeCode(
        state: ClaudeCodeUsageState,
        serviceStatus: ServiceStatusState = .operational(provider: .claudeCode),
        configuration: CodexDashboardCaptureConfiguration,
        now: Date = .now,
        initialMetric: String = "Tokens",
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        try renderDashboard(
            content: ClaudeCodeHoverDashboardView(
                state: state,
                serviceStatus: serviceStatus,
                now: now,
                initialMetric: initialMetric
            ),
            configuration: configuration,
            fileName: defaultClaudeCodeFileName(at: now),
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderAntigravity(
        state: ClaudeCodeUsageState,
        configuration: CodexDashboardCaptureConfiguration,
        now: Date = .now,
        initialMetric: String = "Tokens",
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        try renderDashboard(
            content: ClaudeCodeHoverDashboardView(
                state: state,
                brand: .antigravity,
                now: now,
                initialMetric: initialMetric
            ),
            configuration: configuration,
            fileName: "DockMagic-Antigravity-\(Int(now.timeIntervalSince1970)).png",
            accessibilityOverrides: accessibilityOverrides
        )
    }

    private static func renderDashboard<Content: View>(
        content: Content,
        configuration: CodexDashboardCaptureConfiguration,
        fileName: String,
        accessibilityOverrides: DSAccessibilityOverrides
    ) throws -> CodexDashboardCaptureArtifact {
        // ImageRenderer has no window to inherit macOS accessibility settings
        // from. Resolve them explicitly while retaining deterministic overrides.
        let workspace = NSWorkspace.shared
        let resolvedAccessibility = DSAccessibilityOverrides(
            reduceTransparency: accessibilityOverrides.reduceTransparency
                ?? workspace.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: accessibilityOverrides.increaseContrast
                ?? workspace.accessibilityDisplayShouldIncreaseContrast,
            reduceMotion: accessibilityOverrides.reduceMotion
                ?? workspace.accessibilityDisplayShouldReduceMotion
        )
        let root = DockMagicThemeRoot(
            content: DockHoverDashboardCard(size: configuration.dashboardSize) {
                content
            },
            appearanceMode: configuration.appearanceMode
        )
        .environment(\.dsAccessibilityOverrides, resolvedAccessibility)
        let pngData = try rasterize(
            content: root,
            size: configuration.dashboardSize,
            appearanceMode: configuration.appearanceMode
        )
        let dimensions = pixelDimensions(for: configuration)
        return CodexDashboardCaptureArtifact(
            pngData: pngData,
            fileName: fileName,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }

    /// Render SwiftUI text, symbols, and paths directly at the target density.
    /// AppKit's cached display can contain screen-resolution text layers even
    /// when its destination bitmap is larger. The static chart viewport also
    /// avoids native scroll views and their asynchronous scroll positioning.
    static func rasterize<Content: View>(
        content: Content,
        size: CGSize,
        appearanceMode: DSAppearanceMode
    ) throws -> Data {
        let colorScheme = appearanceMode.preferredColorScheme
            ?? (NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
                == .darkAqua ? .dark : .light)
        let root = content
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)
            .environment(\.displayScale, rasterScale)
            .environment(\.isDashboardCapture, true)
        let renderer = ImageRenderer(content: root)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = rasterScale
        renderer.isOpaque = false
        renderer.colorMode = .nonLinear

        guard let image = renderer.cgImage else {
            throw CodexDashboardCaptureError.bitmapAllocationFailed
        }
        let pixelWidth = Int((size.width * rasterScale).rounded())
        let pixelHeight = Int((size.height * rasterScale).rounded())
        guard image.width == pixelWidth, image.height == pixelHeight else {
            throw CodexDashboardCaptureError.unexpectedPixelSize(
                width: image.width,
                height: image.height
            )
        }
        let representation = NSBitmapImageRep(cgImage: image)
        representation.size = size
        guard let pngData = representation.representation(
            using: .png,
            properties: [:]
        ) else {
            throw CodexDashboardCaptureError.pngEncodingFailed
        }
        return pngData
    }

    static func presentSavePanel(
        for artifact: CodexDashboardCaptureArtifact,
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = artifact.fileName
        panel.title = artifact.fileName.contains("-Antigravity-")
            ? "Save Antigravity Dashboard"
            : artifact.fileName.contains("-Claude-Code-")
            ? "Save Claude Code Dashboard"
            : "Save Codex Dashboard"
        panel.prompt = "Save"

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            do {
                try write(artifact, to: url)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    static func write(
        _ artifact: CodexDashboardCaptureArtifact,
        to url: URL
    ) throws {
        try artifact.pngData.write(to: url, options: .atomic)
    }

    static func copy(
        _ artifact: CodexDashboardCaptureArtifact,
        to pasteboard: NSPasteboard = .general
    ) throws {
        pasteboard.clearContents()
        guard pasteboard.setData(artifact.pngData, forType: .png) else {
            throw CodexDashboardCaptureError.pasteboardWriteFailed
        }
    }

    static func temporaryShareURL(
        for artifact: CodexDashboardCaptureArtifact,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let url = directory.appendingPathComponent(
            artifact.fileName,
            isDirectory: false
        )
        try write(artifact, to: url)
        return url
    }

    static func defaultFileName(
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "DockMagic-Codex-\(formatter.string(from: date)).png"
    }

    static func defaultClaudeCodeFileName(
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "DockMagic-Claude-Code-\(formatter.string(from: date)).png"
    }
}
