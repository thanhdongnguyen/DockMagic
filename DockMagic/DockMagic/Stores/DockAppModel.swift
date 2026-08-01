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
    let codexStore: CodexUsageStore
    let claudeCodeStore: ClaudeCodeUsageStore

    private(set) var isRunning = false

    @ObservationIgnored
    private var isObservingPreferences = false

    init(
        preferences: DockPreferencesStore? = nil,
        metricsStore: SystemMetricsStore? = nil,
        networkStore: NetworkMetricsStore? = nil,
        storageStore: StorageMetricsStore? = nil,
        weatherStore: WeatherStore? = nil,
        codexStore: CodexUsageStore? = nil,
        claudeCodeStore: ClaudeCodeUsageStore? = nil
    ) {
        let preferences = preferences ?? DockPreferencesStore()
        self.preferences = preferences
        self.metricsStore = metricsStore ?? SystemMetricsStore()
        self.networkStore = networkStore ?? NetworkMetricsStore()
        self.storageStore = storageStore ?? StorageMetricsStore()
        self.weatherStore = weatherStore ?? WeatherStore()
        self.codexStore = codexStore ?? CodexUsageStore(
            executableOverridePath: preferences.codexExecutablePath
        )
        self.claudeCodeStore = claudeCodeStore ?? ClaudeCodeUsageStore()
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
        metricsStore.stop()
        networkStore.stop()
        storageStore.stop()
        weatherStore.stop()
        codexStore.stop()
        claudeCodeStore.stop()
    }

    private func observePreferences() {
        guard isRunning, !isObservingPreferences else {
            return
        }

        isObservingPreferences = true
        withObservationTracking {
            _ = preferences.activeFeature
            _ = preferences.codexExecutablePath
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
        codexStore.executableOverridePath = preferences.codexExecutablePath
        switch preferences.activeFeature {
        case .dockMagic:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
        case .systemMetrics:
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            metricsStore.start()
        case .network:
            metricsStore.stop()
            storageStore.stop()
            weatherStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            networkStore.start()
        case .storage:
            metricsStore.stop()
            networkStore.stop()
            weatherStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            storageStore.start()
        case .weather:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            codexStore.stop()
            claudeCodeStore.stop()
            weatherStore.start()
        case .codex:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            claudeCodeStore.stop()
            codexStore.start()
        case .claudeCode:
            metricsStore.stop()
            networkStore.stop()
            storageStore.stop()
            weatherStore.stop()
            codexStore.stop()
            claudeCodeStore.start()
        }
    }
}
