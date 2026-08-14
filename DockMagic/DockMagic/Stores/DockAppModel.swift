import Foundation
import Observation

@MainActor
@Observable
final class DockAppModel {
    let preferences: DockPreferencesStore
    let metricsStore: SystemMetricsStore
    let networkStore: NetworkMetricsStore
    let storageStore: StorageMetricsStore
    let weatherStore: WeatherStore
    let batteryStore: BatteryMetricsStore
    let githubStore: GitHubRepositoryStore
    let codexStore: CodexUsageStore
    let claudeCodeStore: ClaudeCodeUsageStore
    let searchConsoleStore: SearchConsoleStore

    private(set) var isRunning = false

    @ObservationIgnored
    private var isObservingPreferences = false

    @ObservationIgnored
    private var automaticClaudeSetupTask: Task<Void, Never>?

    init(
        preferences: DockPreferencesStore? = nil,
        metricsStore: SystemMetricsStore? = nil,
        networkStore: NetworkMetricsStore? = nil,
        storageStore: StorageMetricsStore? = nil,
        weatherStore: WeatherStore? = nil,
        batteryStore: BatteryMetricsStore? = nil,
        githubStore: GitHubRepositoryStore? = nil,
        codexStore: CodexUsageStore? = nil,
        claudeCodeStore: ClaudeCodeUsageStore? = nil,
        searchConsoleStore: SearchConsoleStore? = nil
    ) {
        let preferences = preferences ?? DockPreferencesStore()
        self.preferences = preferences
        self.metricsStore = metricsStore ?? SystemMetricsStore()
        self.networkStore = networkStore ?? NetworkMetricsStore()
        self.storageStore = storageStore ?? StorageMetricsStore()
        self.weatherStore = weatherStore ?? WeatherStore()
        self.batteryStore = batteryStore ?? BatteryMetricsStore()
        self.githubStore = githubStore ?? GitHubRepositoryStore()
        self.codexStore = codexStore ?? CodexUsageStore(
            executableOverridePath: preferences.codexExecutablePath
        )
        self.claudeCodeStore = claudeCodeStore ?? ClaudeCodeUsageStore()
        self.searchConsoleStore = searchConsoleStore ?? SearchConsoleStore()
        self.githubStore.configure(
            repositoryURL: preferences.githubRepositoryURL
        )
    }

    var dockPresentation: DockTilePresentation {
        switch preferences.activeFeature {
        case .dockMagic:
            .dockMagic
        case .systemMetrics:
            .systemMetrics(
                snapshot: metricsStore.current,
                appearance: preferences.systemMetricsAppearance,
                errorDescription: metricsStore.lastErrorDescription
            )
        case .network:
            .network(
                history: networkStore.history,
                appearance: preferences.networkAppearance,
                errorDescription: networkStore.lastErrorDescription
            )
        case .storage:
            .storage(
                snapshot: storageStore.current,
                appearance: preferences.storageAppearance,
                errorDescription: storageStore.lastErrorDescription
            )
        case .weather:
            .weather(state: weatherStore.state)
        case .batteries:
            .batteries(
                snapshot: batteryStore.current,
                errorDescription: batteryStore.lastErrorDescription
            )
        case .github:
            .github(
                history: githubStore.history,
                appearance: preferences.githubAppearance,
                errorDescription: githubStore.lastErrorDescription
            )
        case .codex:
            .codex(
                state: codexStore.state,
                appearance: preferences.codexAppearance
            )
        case .claudeCode:
            .claudeCode(
                state: claudeCodeStore.state,
                appearance: preferences.claudeCodeAppearance
            )
        case .searchConsole:
            .searchConsole(
                state: searchConsoleStore.state,
                configuration: searchConsoleStore.configuration
            )
        }
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        applyPreferences()
        observePreferences()
    }

    func stop() {
        isRunning = false
        isObservingPreferences = false
        automaticClaudeSetupTask?.cancel()
        automaticClaudeSetupTask = nil
        metricsStore.stop()
        networkStore.stop()
        storageStore.stop()
        weatherStore.stop()
        batteryStore.stop()
        githubStore.stop()
        codexStore.stop()
        claudeCodeStore.stop()
        searchConsoleStore.stop()
    }

    private func observePreferences() {
        guard isRunning, !isObservingPreferences else {
            return
        }

        isObservingPreferences = true
        withObservationTracking {
            _ = preferences.activeFeature
            _ = preferences.githubRepositoryURL
            _ = preferences.codexExecutablePath
            _ = preferences.automaticallyConfigureClaudeCode
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else {
                    return
                }

                self.isObservingPreferences = false
                self.applyPreferences()
                self.observePreferences()
            }
        }
    }

    private func applyPreferences() {
        automaticClaudeSetupTask?.cancel()
        automaticClaudeSetupTask = nil
        codexStore.executableOverridePath = preferences.codexExecutablePath
        githubStore.configure(
            repositoryURL: preferences.githubRepositoryURL
        )
        switch preferences.activeFeature {
        case .dockMagic:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
        case .systemMetrics:
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
            metricsStore.start()
        case .network:
            metricsStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
            networkStore.start()
        case .storage:
            metricsStore.stop()
            networkStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
            storageStore.start()
        case .weather:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            weatherStore.start()
        case .batteries:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
            githubStore.pause()
            batteryStore.start()
        case .github:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
            githubStore.start()
        case .codex:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            claudeCodeStore.stop()
            searchConsoleStore.stop()
            codexStore.start()
        case .claudeCode:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            codexStore.stop()
            searchConsoleStore.stop()
            claudeCodeStore.start()
            scheduleAutomaticClaudeCodeSetup()
        case .searchConsole:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            codexStore.stop()
            claudeCodeStore.stop()
            searchConsoleStore.start()
        }
    }

    /// Resolves the default Codex executable and reads the first usage sample.
    /// This is safe to call repeatedly; the store coalesces concurrent reads.
    func prepareCodexIntegration() async {
        codexStore.executableOverridePath = preferences.codexExecutablePath
        await codexStore.refresh()
    }

    /// Installs DockMagic's status-line bridge on first use, unless the user
    /// explicitly disabled automatic setup, then reads the latest snapshot.
    func prepareClaudeCodeIntegration() async {
        guard preferences.automaticallyConfigureClaudeCode else {
            return
        }

        if claudeCodeStore.isBridgeInstalled {
            await claudeCodeStore.refresh()
        } else {
            await claudeCodeStore.installBridge()
        }
    }

    /// Saves a canonical GitHub repository URL and verifies it immediately.
    func connectGitHubRepository(_ repositoryURL: String) async {
        guard let reference = GitHubRepositoryReference(urlString: repositoryURL) else {
            githubStore.configure(repositoryURL: repositoryURL)
            return
        }

        preferences.githubRepositoryURL = reference.webURLString
        applyPreferences()
        await githubStore.refresh()
    }

    func disconnectGitHubRepository() {
        preferences.githubRepositoryURL = ""
        applyPreferences()
    }

    func refreshGitHubRepository() async {
        githubStore.configure(
            repositoryURL: preferences.githubRepositoryURL
        )
        await githubStore.refresh()
    }

    /// A sleeping or locked Mac can miss timer delivery for background work.
    /// Re-arm active Weather and fetch when the system or user session resumes.
    func refreshActiveWeatherAfterResume() async {
        guard isRunning, preferences.activeFeature == .weather else {
            return
        }

        weatherStore.start()
        await weatherStore.refresh()
    }

    /// Re-enumerates live power sources after sleep, unlock, and device churn.
    func refreshActiveBatteriesAfterResume() async {
        guard isRunning, preferences.activeFeature == .batteries else {
            return
        }

        batteryStore.start()
        await batteryStore.refresh()
    }

    /// Re-arms polling after macOS sleep and immediately refreshes GitHub.
    func refreshActiveGitHubAfterResume() async {
        guard isRunning, preferences.activeFeature == .github else {
            return
        }

        githubStore.start()
        await githubStore.refresh()
    }

    private func scheduleAutomaticClaudeCodeSetup() {
        guard preferences.automaticallyConfigureClaudeCode else {
            return
        }

        automaticClaudeSetupTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.prepareClaudeCodeIntegration()
        }
    }
}
