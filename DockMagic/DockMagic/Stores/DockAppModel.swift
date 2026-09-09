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
    let clockStore: ClockStore
    let batteryStore: BatteryMetricsStore
    let githubStore: GitHubRepositoryStore
    let streakStore: TokenUsageStreakStore
    let codexStore: CodexUsageStore
    let antigravityStore: AntigravityUsageStore
    let claudeCodeStore: ClaudeCodeUsageStore
    let developerToolInstallationStore: DeveloperToolInstallationStore
    let serviceStatusStore: ServiceStatusStore
    let searchConsoleStore: SearchConsoleStore

    private(set) var isRunning = false

    @ObservationIgnored
    private var isObservingPreferences = false

    @ObservationIgnored
    private var automaticClaudeSetupTask: Task<Void, Never>?

    @ObservationIgnored
    private var developerToolPreparationTasks:
        [DeveloperTool: Task<Void, Never>] = [:]

    @ObservationIgnored
    private var antigravityPreparationTask: Task<Void, Never>?

    init(
        preferences: DockPreferencesStore? = nil,
        metricsStore: SystemMetricsStore? = nil,
        networkStore: NetworkMetricsStore? = nil,
        storageStore: StorageMetricsStore? = nil,
        weatherStore: WeatherStore? = nil,
        clockStore: ClockStore? = nil,
        batteryStore: BatteryMetricsStore? = nil,
        githubStore: GitHubRepositoryStore? = nil,
        streakStore: TokenUsageStreakStore? = nil,
        codexStore: CodexUsageStore? = nil,
        claudeCodeStore: ClaudeCodeUsageStore? = nil,
        antigravityStore: AntigravityUsageStore? = nil,
        developerToolInstallationStore: DeveloperToolInstallationStore? = nil,
        serviceStatusStore: ServiceStatusStore? = nil,
        searchConsoleStore: SearchConsoleStore? = nil
    ) {
        let preferences = preferences ?? DockPreferencesStore()
        self.preferences = preferences
        self.metricsStore = metricsStore ?? SystemMetricsStore()
        self.networkStore = networkStore ?? NetworkMetricsStore()
        self.storageStore = storageStore ?? StorageMetricsStore()
        self.weatherStore = weatherStore ?? WeatherStore()
        self.clockStore = clockStore ?? ClockStore()
        self.batteryStore = batteryStore ?? BatteryMetricsStore()
        self.githubStore = githubStore ?? GitHubRepositoryStore()
        let streakStore = streakStore ?? TokenUsageStreakStore()
        self.streakStore = streakStore
        self.codexStore = codexStore ?? CodexUsageStore(
            streakTracker: streakStore,
            executableOverridePath: preferences.codexExecutablePath
        )
        self.antigravityStore = antigravityStore ?? AntigravityUsageStore(streakTracker: streakStore)
        self.antigravityStore.selectedGroupID = preferences.antigravityGroupID
        self.claudeCodeStore = claudeCodeStore ?? ClaudeCodeUsageStore(
            streakTracker: streakStore
        )
        self.developerToolInstallationStore = developerToolInstallationStore
            ?? DeveloperToolInstallationStore()
        self.serviceStatusStore = serviceStatusStore ?? ServiceStatusStore()
        self.searchConsoleStore = searchConsoleStore ?? SearchConsoleStore()
        self.githubStore.configure(
            repositoryURL: preferences.githubRepositoryURL
        )
        self.developerToolInstallationStore.refreshAvailability(
            codexOverridePath: preferences.codexExecutablePath
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
        case .clock:
            .clock(
                date: preferences.clockConfiguration.presentationDate(
                    for: clockStore.currentDate
                ),
                configuration: preferences.clockConfiguration
            )
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
                appearance: preferences.codexAppearance,
                serviceStatus: serviceStatusStore.codexState
            )
        case .antigravity:
            .antigravity(state: antigravityStore.state, appearance: preferences.antigravityAppearance)
        case .claudeCode:
            .claudeCode(
                state: claudeCodeStore.state,
                appearance: preferences.claudeCodeAppearance,
                serviceStatus: serviceStatusStore.claudeCodeState
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
        serviceStatusStore.start()
        applyPreferences()
        observePreferences()
    }

    func stop() {
        isRunning = false
        isObservingPreferences = false
        automaticClaudeSetupTask?.cancel()
        automaticClaudeSetupTask = nil
        antigravityPreparationTask?.cancel()
        antigravityPreparationTask = nil
        for task in developerToolPreparationTasks.values {
            task.cancel()
        }
        developerToolPreparationTasks.removeAll()
        developerToolInstallationStore.cancelInstallations()
        metricsStore.stop()
        networkStore.stop()
        storageStore.stop()
        weatherStore.stop()
        clockStore.stop()
        batteryStore.stop()
        githubStore.stop()
        codexStore.stop()
        claudeCodeStore.stop()
        antigravityStore.stop()
        serviceStatusStore.stop()
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
            _ = preferences.antigravityGroupID
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
        antigravityStore.selectedGroupID = preferences.antigravityGroupID
        if preferences.activeFeature != .antigravity && !antigravityStore.isBridgeInstalled { antigravityStore.stop() }
        automaticClaudeSetupTask?.cancel()
        automaticClaudeSetupTask = nil
        codexStore.executableOverridePath = preferences.codexExecutablePath
        developerToolInstallationStore.refreshAvailability(
            codexOverridePath: preferences.codexExecutablePath
        )
        githubStore.configure(
            repositoryURL: preferences.githubRepositoryURL
        )
        switch preferences.activeFeature {
        case .dockMagic:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
        case .systemMetrics:
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            metricsStore.start()
        case .network:
            metricsStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            networkStore.start()
        case .storage:
            metricsStore.stop()
            networkStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            storageStore.start()
        case .weather:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            weatherStore.start()
        case .clock:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            clockStore.start()
        case .batteries:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            searchConsoleStore.stop()
            githubStore.pause()
            batteryStore.start()
        case .github:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            searchConsoleStore.stop()
            githubStore.start()
        case .codex:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            codexStore.start()
        case .antigravity:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            antigravityStore.start()
        case .claudeCode:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.stop()
            claudeCodeStore.start()
            if developerToolInstallationStore.claudeCodeState.isInstalled {
                scheduleAutomaticClaudeCodeSetup()
            }
        case .searchConsole:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            clockStore.stop()
            batteryStore.stop()
            githubStore.pause()
            searchConsoleStore.start()
        }

        // Streak collection is a DockMagic responsibility, independent of
        // which feature currently owns the Dock. Codex is always sampled in
        // the background; Claude Code is sampled whenever its bridge exists.
        codexStore.start()
        if antigravityStore.isBridgeInstalled { antigravityStore.start() }
        if claudeCodeStore.isBridgeInstalled {
            claudeCodeStore.start()
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

    /// Applies a user-driven Dock feature selection. Developer tools are
    /// prepared only from this explicit interaction, never silently at launch.
    func activateFeature(_ feature: DockFeature) {
        preferences.activeFeature = feature
        requestDeveloperToolPreparation(for: feature)
    }

    /// Starts setup when the user opens a developer-tool settings page without
    /// changing the single feature currently shown in the Dock.
    func requestDeveloperToolPreparation(for feature: DockFeature) {
        if feature == .antigravity {
            guard antigravityPreparationTask == nil else { return }
            antigravityPreparationTask = Task { @MainActor [weak self] in
                guard let self, !Task.isCancelled else { return }
                await prepareDeveloperToolIntegration(for: feature)
                antigravityPreparationTask = nil
            }
            return
        }
        guard let tool = feature.developerTool else {
            return
        }
        scheduleDeveloperToolPreparation(tool, feature: feature)
    }

    /// Prepares the local data connection. Codex and Claude also install a missing
    /// vendor CLI. Installation and usage stores coalesce concurrent operations.
    func prepareDeveloperToolIntegration(for feature: DockFeature) async {
        if feature == .antigravity {
            antigravityStore.start()
            if !antigravityStore.isBridgeInstalled || antigravityStore.bridgeError != nil {
                await antigravityStore.connect()
            } else {
                await antigravityStore.refresh(force: true)
            }
            return
        }
        guard let tool = feature.developerTool else {
            return
        }
        guard let executableURL = await developerToolInstallationStore
            .ensureInstalled(
                tool,
                codexOverridePath: preferences.codexExecutablePath
            )
        else {
            return
        }

        switch tool {
        case .codex:
            preferences.codexExecutablePath = executableURL.path
            await prepareCodexIntegration()
        case .claudeCode:
            await prepareClaudeCodeIntegration()
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
    /// Recover independent providers concurrently so a slow status/weather
    /// request cannot delay Codex or Claude Code after login or reconnection.
    func refreshAfterInterruption() async {
        guard isRunning, !Task.isCancelled else { return }
        refreshActiveClockAfterResume()
        async let weather: Void = refreshActiveWeatherAfterResume()
        async let batteries: Void = refreshActiveBatteriesAfterResume()
        async let github: Void = refreshActiveGitHubAfterResume()
        async let statuses: Void = refreshServiceStatusesAfterResume()
        _ = await (weather, batteries, github, statuses)
    }

    func refreshDeveloperUsageAfterInterruption() async {
        guard isRunning, !Task.isCancelled else { return }
        async let codex: Void = codexStore.refreshAfterInterruption()
        async let claude: Void = claudeCodeStore.refreshAfterInterruption()
        async let antigravity: Void = antigravityStore.refreshAfterInterruption()
        _ = await (codex, claude, antigravity)
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

    /// Re-synchronizes the visible time immediately after wake or unlock.
    func refreshActiveClockAfterResume() {
        guard isRunning, preferences.activeFeature == .clock else {
            return
        }

        clockStore.refresh()
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

    /// Refreshes the official Codex and Claude service pages after sleep or
    /// session unlock, when timer delivery may have been suspended by macOS.
    func refreshServiceStatusesAfterResume() async {
        guard isRunning else { return }
        serviceStatusStore.start()
        await serviceStatusStore.refresh()
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

    private func scheduleDeveloperToolPreparation(
        _ tool: DeveloperTool,
        feature: DockFeature
    ) {
        guard developerToolPreparationTasks[tool] == nil else {
            return
        }
        developerToolPreparationTasks[tool] = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.prepareDeveloperToolIntegration(for: feature)
            self.developerToolPreparationTasks[tool] = nil
        }
    }
}
