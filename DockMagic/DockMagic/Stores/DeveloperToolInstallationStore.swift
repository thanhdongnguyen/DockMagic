import Foundation
import Observation

@MainActor
@Observable
final class DeveloperToolInstallationStore {
    private(set) var codexState: DeveloperToolInstallationState = .checking
    private(set) var claudeCodeState: DeveloperToolInstallationState = .checking
    private(set) var antigravityState: DeveloperToolInstallationState = .checking

    @ObservationIgnored
    private let installer: any DeveloperToolInstalling

    @ObservationIgnored
    private var installationTasks: [DeveloperTool: Task<URL, Error>] = [:]

    init(installer: (any DeveloperToolInstalling)? = nil) {
        self.installer = installer ?? DeveloperToolInstaller()
    }

    deinit {
        for task in installationTasks.values {
            task.cancel()
        }
    }

    func state(for tool: DeveloperTool) -> DeveloperToolInstallationState {
        switch tool {
        case .codex:
            codexState
        case .claudeCode:
            claudeCodeState
        case .antigravity:
            antigravityState
        }
    }

    func refreshAvailability(codexOverridePath: String?) {
        for tool in DeveloperTool.allCases where installationTasks[tool] == nil {
            do {
                let url = try installer.locate(
                    tool,
                    codexOverridePath: codexOverridePath
                )
                setState(.installed(path: url.path), for: tool)
            } catch {
                setState(.notInstalled, for: tool)
            }
        }
    }

    func ensureInstalled(
        _ tool: DeveloperTool,
        codexOverridePath: String?
    ) async -> URL? {
        if let existing = try? installer.locate(
            tool,
            codexOverridePath: codexOverridePath
        ) {
            setState(.installed(path: existing.path), for: tool)
            return existing
        }

        if let task = installationTasks[tool] {
            return await finish(task, for: tool)
        }

        setState(.installing, for: tool)
        let task = Task { try await installer.install(tool) }
        installationTasks[tool] = task
        return await finish(task, for: tool)
    }

    func cancelInstallations() {
        for task in installationTasks.values {
            task.cancel()
        }
        installationTasks.removeAll()
    }

    private func finish(
        _ task: Task<URL, Error>,
        for tool: DeveloperTool
    ) async -> URL? {
        do {
            let url = try await task.value
            installationTasks[tool] = nil
            setState(.installed(path: url.path), for: tool)
            return url
        } catch is CancellationError {
            installationTasks[tool] = nil
            setState(.notInstalled, for: tool)
            return nil
        } catch {
            installationTasks[tool] = nil
            setState(
                .failed(message: error.localizedDescription),
                for: tool
            )
            return nil
        }
    }

    private func setState(
        _ state: DeveloperToolInstallationState,
        for tool: DeveloperTool
    ) {
        switch tool {
        case .codex:
            codexState = state
        case .claudeCode:
            claudeCodeState = state
        case .antigravity:
            antigravityState = state
        }
    }
}
