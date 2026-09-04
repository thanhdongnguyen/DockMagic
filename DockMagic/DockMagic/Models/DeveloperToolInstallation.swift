import Foundation

enum DeveloperTool: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claudeCode

    var id: Self { self }

    var title: String {
        switch self {
        case .codex:
            "Codex CLI"
        case .claudeCode:
            "Claude Code"
        }
    }

    var executableName: String {
        switch self {
        case .codex:
            "codex"
        case .claudeCode:
            "claude"
        }
    }

    var dockFeature: DockFeature {
        switch self {
        case .codex:
            .codex
        case .claudeCode:
            .claudeCode
        }
    }
}

enum DeveloperToolInstallationState: Equatable, Sendable {
    case checking
    case notInstalled
    case installing
    case installed(path: String)
    case failed(message: String)

    var installedPath: String? {
        guard case let .installed(path) = self else {
            return nil
        }
        return path
    }

    var isInstalled: Bool {
        installedPath != nil
    }
}

extension DockFeature {
    var developerTool: DeveloperTool? {
        switch self {
        case .codex:
            .codex
        case .claudeCode:
            .claudeCode
        case .dockMagic, .systemMetrics, .network, .storage, .weather, .clock,
             .batteries, .github, .searchConsole:
            nil
        }
    }
}
