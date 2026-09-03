import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CodexDashboardCaptureConfiguration: Equatable, Sendable {
    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    let appearanceMode: DSAppearanceMode
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
        for panelSize: CGSize
    ) -> (width: Int, height: Int) {
        (
            Int((panelSize.width * rasterScale).rounded()),
            Int((panelSize.height * rasterScale).rounded())
        )
    }

    static func pixelSizeLabel(for panelSize: CGSize) -> String {
        let dimensions = pixelDimensions(for: panelSize)
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
        let dimensions = pixelDimensions(for: configuration.panelSize)
        let root = DockMagicThemeRoot(
            content: DockHoverChrome(
                pointerEdge: configuration.pointerEdge,
                panelSize: configuration.panelSize
            ) {
                CodexHoverDashboardView(
                    state: state,
                    serviceStatus: serviceStatus,
                    now: now,
                    initialStreakCelebration: initialStreakCelebration,
                    streakCelebrationAutoDismissDelay:
                        streakCelebrationAutoDismissDelay
                )
            },
            appearanceMode: configuration.appearanceMode
        )
        .frame(
            width: configuration.panelSize.width,
            height: configuration.panelSize.height
        )
        .environment(\.displayScale, rasterScale)
        .environment(\.dsAccessibilityOverrides, accessibilityOverrides)

        return try autoreleasepool {
            let hostingView = NSHostingView(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(
                    origin: .zero,
                    size: configuration.panelSize
                ),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.appearance = appearance(for: configuration.appearanceMode)
            hostingView.appearance = window.appearance
            hostingView.frame = NSRect(
                origin: .zero,
                size: configuration.panelSize
            )
            hostingView.wantsLayer = true
            hostingView.layer?.contentsScale = rasterScale
            window.contentView = hostingView

            defer {
                window.contentView = nil
                window.close()
            }

            // Let ScrollViewReader move Daily tokens to the latest bucket before
            // the detached dashboard is rasterized.
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            guard let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: dimensions.width,
                pixelsHigh: dimensions.height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                throw CodexDashboardCaptureError.bitmapAllocationFailed
            }
            representation.size = configuration.panelSize
            hostingView.cacheDisplay(
                in: hostingView.bounds,
                to: representation
            )

            guard representation.pixelsWide == dimensions.width,
                  representation.pixelsHigh == dimensions.height else {
                throw CodexDashboardCaptureError.unexpectedPixelSize(
                    width: representation.pixelsWide,
                    height: representation.pixelsHigh
                )
            }
            guard let pngData = representation.representation(
                using: .png,
                properties: [:]
            ) else {
                throw CodexDashboardCaptureError.pngEncodingFailed
            }

            return CodexDashboardCaptureArtifact(
                pngData: pngData,
                fileName: defaultFileName(at: now),
                pixelWidth: representation.pixelsWide,
                pixelHeight: representation.pixelsHigh
            )
        }
    }

    static func renderClaudeCode(
        state: ClaudeCodeUsageState,
        serviceStatus: ServiceStatusState = .operational(
            provider: .claudeCode
        ),
        configuration: CodexDashboardCaptureConfiguration,
        now: Date = .now,
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        let dimensions = pixelDimensions(for: configuration.panelSize)
        let root = DockMagicThemeRoot(
            content: DockHoverChrome(
                pointerEdge: configuration.pointerEdge,
                panelSize: configuration.panelSize
            ) {
                ClaudeCodeHoverDashboardView(
                    state: state,
                    serviceStatus: serviceStatus,
                    now: now
                )
            },
            appearanceMode: configuration.appearanceMode
        )
        .frame(
            width: configuration.panelSize.width,
            height: configuration.panelSize.height
        )
        .environment(\.displayScale, rasterScale)
        .environment(\.dsAccessibilityOverrides, accessibilityOverrides)

        return try autoreleasepool {
            let hostingView = NSHostingView(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(
                    origin: .zero,
                    size: configuration.panelSize
                ),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.appearance = appearance(for: configuration.appearanceMode)
            hostingView.appearance = window.appearance
            hostingView.frame = NSRect(
                origin: .zero,
                size: configuration.panelSize
            )
            hostingView.wantsLayer = true
            hostingView.layer?.contentsScale = rasterScale
            window.contentView = hostingView

            defer {
                window.contentView = nil
                window.close()
            }

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            guard let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: dimensions.width,
                pixelsHigh: dimensions.height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                throw CodexDashboardCaptureError.bitmapAllocationFailed
            }
            representation.size = configuration.panelSize
            hostingView.cacheDisplay(
                in: hostingView.bounds,
                to: representation
            )

            guard representation.pixelsWide == dimensions.width,
                  representation.pixelsHigh == dimensions.height else {
                throw CodexDashboardCaptureError.unexpectedPixelSize(
                    width: representation.pixelsWide,
                    height: representation.pixelsHigh
                )
            }
            guard let pngData = representation.representation(
                using: .png,
                properties: [:]
            ) else {
                throw CodexDashboardCaptureError.pngEncodingFailed
            }

            return CodexDashboardCaptureArtifact(
                pngData: pngData,
                fileName: defaultClaudeCodeFileName(at: now),
                pixelWidth: representation.pixelsWide,
                pixelHeight: representation.pixelsHigh
            )
        }
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
        panel.title = artifact.fileName.contains("-Claude-Code-")
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

    private static func appearance(
        for mode: DSAppearanceMode
    ) -> NSAppearance? {
        switch mode {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }
}
