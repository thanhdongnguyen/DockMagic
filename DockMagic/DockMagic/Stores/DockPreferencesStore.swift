import Foundation
import Observation

@MainActor
@Observable
final class DockPreferencesStore {
    static let binanceConfigurationKey = "DockMagicBinanceConfiguration"
    static let clockConfigurationKey = "DockMagicClockConfiguration"
    static let systemMetricsAppearanceKey = "DockMagicSystemMetricsAppearance"
    static let networkAppearanceKey = "DockMagicNetworkAppearance"
    static let storageAppearanceKey = "DockMagicStorageAppearance"
    static let githubAppearanceKey = "DockMagicGitHubAppearance"
    static let githubRepositoryURLKey = "DockMagicGitHubRepositoryURL"
    static let codexAppearanceKey = "DockMagicCodexAppearance"
    static let codexExecutablePathKey = "DockMagicCodexExecutablePath"
    static let claudeCodeAppearanceKey = "DockMagicClaudeCodeAppearance"
    static let antigravityAppearanceKey = "DockMagicAntigravityAppearance"
    static let automaticallyConfigureClaudeCodeKey =
        "DockMagicAutomaticallyConfigureClaudeCode"
    static let dockHoverDashboardEnabledKey =
        "DockMagicDockHoverDashboardEnabled"
    static let shelfConfigurationKey = "DockMagicShelfConfiguration"
    static let dockModeKey = "DockMagicDockMode"
    static let customDockConfigurationKey = "DockMagicCustomDockConfiguration"
    var customDockStatusMessage: String?

    var dockMode: DockMode {
        didSet {
            guard dockMode != oldValue else { return }
            defaults.set(dockMode.rawValue, forKey: Self.dockModeKey)
        }
    }

    private(set) var customDockConfiguration: CustomDockConfiguration {
        didSet {
            guard customDockConfiguration != oldValue,
                  let data = try? JSONEncoder().encode(customDockConfiguration)
            else { return }
            defaults.set(data, forKey: Self.customDockConfigurationKey)
        }
    }

    var activeFeature: DockFeature {
        didSet {
            guard activeFeature != oldValue else {
                return
            }

            defaults.set(activeFeature.rawValue, forKey: DockFeature.storageKey)
        }
    }

    var binanceConfiguration: BinanceConfiguration {
        didSet {
            if let data = try? JSONEncoder().encode(binanceConfiguration) { defaults.set(data, forKey: Self.binanceConfigurationKey) }
        }
    }

    private(set) var clockConfiguration: DockClockConfiguration
    private(set) var systemMetricsAppearance: DockRingAppearance
    private(set) var networkAppearance: DockNetworkAppearance
    private(set) var storageAppearance: DockSingleRingAppearance
    private(set) var githubAppearance: DockGitHubAppearance
    private(set) var codexAppearance: DockRingAppearance
    private(set) var claudeCodeAppearance: DockRingAppearance
    private(set) var antigravityAppearance: DockRingAppearance
    var grokBuildSettings: GrokBuildSettings {
        didSet {
            if let data = try? JSONEncoder().encode(grokBuildSettings) { defaults.set(data, forKey: "DockMagicGrokBuildSettings") }
        }
    }
    var grokBuildAppearance: GrokBuildAppearance {
        didSet {
            if let data = try? JSONEncoder().encode(grokBuildAppearance) { defaults.set(data, forKey: "DockMagicGrokBuildAppearance") }
        }
    }
    var openCodeAppearance: OpenCodeDockAppearance {
        didSet {
            if let data = try? JSONEncoder().encode(openCodeAppearance) { defaults.set(data, forKey: "DockMagicOpenCodeAppearance") }
        }
    }

    var githubRepositoryURL: String {
        didSet {
            guard githubRepositoryURL != oldValue else {
                return
            }

            defaults.set(
                githubRepositoryURL,
                forKey: Self.githubRepositoryURLKey
            )
        }
    }

    var codexExecutablePath: String? {
        didSet {
            guard codexExecutablePath != oldValue else {
                return
            }

            let normalized = Self.normalizedPath(codexExecutablePath)
            if normalized != codexExecutablePath {
                codexExecutablePath = normalized
                return
            }

            if let normalized {
                defaults.set(normalized, forKey: Self.codexExecutablePathKey)
            } else {
                defaults.removeObject(forKey: Self.codexExecutablePathKey)
            }
        }
    }

    var automaticallyConfigureClaudeCode: Bool {
        didSet {
            guard automaticallyConfigureClaudeCode != oldValue else {
                return
            }
            defaults.set(
                automaticallyConfigureClaudeCode,
                forKey: Self.automaticallyConfigureClaudeCodeKey
            )
        }
    }

    var isDockHoverDashboardEnabled: Bool {
        didSet {
            guard isDockHoverDashboardEnabled != oldValue else {
                return
            }
            defaults.set(
                isDockHoverDashboardEnabled,
                forKey: Self.dockHoverDashboardEnabledKey
            )
        }
    }

    private(set) var shelfConfiguration: DockShelfConfiguration {
        didSet {
            guard shelfConfiguration != oldValue,
                  let data = try? JSONEncoder().encode(shelfConfiguration) else { return }
            defaults.set(data, forKey: Self.shelfConfigurationKey)
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dockMode = DockMode(
            rawValue: defaults.string(forKey: Self.dockModeKey) ?? ""
        ) ?? .dockActive
        customDockConfiguration = Self.decodeValue(
            CustomDockConfiguration.self,
            from: defaults,
            key: Self.customDockConfigurationKey,
            fallback: .init()
        )
        var binance = Self.decodeValue(BinanceConfiguration.self, from: defaults, key: Self.binanceConfigurationKey, fallback: .init())
        binance.normalize()
        binanceConfiguration = binance
        grokBuildSettings = Self.decodeValue(GrokBuildSettings.self, from: defaults, key: "DockMagicGrokBuildSettings", fallback: .init())
        grokBuildAppearance = Self.decodeValue(GrokBuildAppearance.self, from: defaults, key: "DockMagicGrokBuildAppearance", fallback: .standard)
        openCodeAppearance = Self.decodeValue(OpenCodeDockAppearance.self, from: defaults, key: "DockMagicOpenCodeAppearance", fallback: .standard)
        let storedFeature = defaults.string(forKey: DockFeature.storageKey)
        let restoredFeature = storedFeature.flatMap(DockFeature.init(rawValue:)) ?? .systemMetrics
        activeFeature = DockFeature.availableCases.contains(restoredFeature) ? restoredFeature : .systemMetrics
        clockConfiguration = Self.decodeValue(
            DockClockConfiguration.self,
            from: defaults,
            key: Self.clockConfigurationKey,
            fallback: DockFeatureDefaults.clockConfiguration
        )
        systemMetricsAppearance = Self.decodeAppearance(
            from: defaults,
            key: Self.systemMetricsAppearanceKey,
            fallback: DockFeatureDefaults.systemMetricsAppearance
        )
        networkAppearance = Self.decodeValue(
            DockNetworkAppearance.self,
            from: defaults,
            key: Self.networkAppearanceKey,
            fallback: DockFeatureDefaults.networkAppearance
        )
        storageAppearance = Self.decodeValue(
            DockSingleRingAppearance.self,
            from: defaults,
            key: Self.storageAppearanceKey,
            fallback: DockFeatureDefaults.storageAppearance
        )
        githubAppearance = Self.decodeValue(
            DockGitHubAppearance.self,
            from: defaults,
            key: Self.githubAppearanceKey,
            fallback: DockFeatureDefaults.githubAppearance
        )
        githubRepositoryURL = defaults.string(
            forKey: Self.githubRepositoryURLKey
        ) ?? ""
        codexAppearance = Self.decodeAppearance(
            from: defaults,
            key: Self.codexAppearanceKey,
            fallback: DockFeatureDefaults.codexAppearance
        )
        claudeCodeAppearance = Self.decodeAppearance(
            from: defaults,
            key: Self.claudeCodeAppearanceKey,
            fallback: DockFeatureDefaults.claudeCodeAppearance
        )
        antigravityAppearance = Self.decodeAppearance(
            from: defaults,
            key: Self.antigravityAppearanceKey,
            fallback: DockFeatureDefaults.antigravityAppearance
        )
        codexExecutablePath = Self.normalizedPath(
            defaults.string(forKey: Self.codexExecutablePathKey)
        )
        automaticallyConfigureClaudeCode =
            defaults.object(
                forKey: Self.automaticallyConfigureClaudeCodeKey
            ) as? Bool ?? true
        isDockHoverDashboardEnabled =
            defaults.object(
                forKey: Self.dockHoverDashboardEnabledKey
            ) as? Bool ?? false
        var shelf = Self.decodeValue(DockShelfConfiguration.self,
                                     from: defaults, key: Self.shelfConfigurationKey,
                                     fallback: .init())
        shelf.normalize()
        shelfConfiguration = shelf
        customDockConfiguration.normalize()
    }

    func initializeCustomDockIfNeeded() {
        guard !customDockConfiguration.initialized else { return }
        customDockConfiguration = NativeDockImport.initialConfiguration(
            legacyFeatures: shelfConfiguration.orderedFeatures
        )
    }

    func updateCustomDock(_ change: (inout CustomDockConfiguration) -> Void) {
        var value = customDockConfiguration
        change(&value)
        value.normalize()
        customDockConfiguration = value
    }

    func addCustomDockSlot(_ feature: DockFeature) {
        guard feature != .dockMagic,
              DockFeature.availableCases.contains(feature) else { return }
        updateCustomDock { $0.slots.append(CustomDockSlot(feature: feature)) }
    }

    func removeCustomDockSlot(_ id: UUID) {
        updateCustomDock { $0.slots.removeAll { $0.id == id } }
    }

    func moveCustomDockSlot(_ id: UUID, by offset: Int) {
        updateCustomDock { value in
            guard let index = value.slots.firstIndex(where: { $0.id == id }),
                  value.slots.indices.contains(index + offset) else { return }
            value.slots.swapAt(index, index + offset)
        }
    }

    func addCustomDockApplication(_ app: CustomDockApplication) {
        updateCustomDock { $0.pinnedApps.append(app) }
    }

    func removeCustomDockApplication(_ id: String) {
        updateCustomDock { $0.pinnedApps.removeAll { $0.id == id } }
    }

    func moveCustomDockApplication(_ id: String, by offset: Int) {
        updateCustomDock { value in
            guard let index = value.pinnedApps.firstIndex(where: { $0.id == id }),
                  value.pinnedApps.indices.contains(index + offset) else { return }
            value.pinnedApps.swapAt(index, index + offset)
        }
    }

    func recordCustomDockRecentApp(_ app: CustomDockApplication) {
        updateCustomDock { value in
            value.recentApps.removeAll { $0.id == app.id }
            value.recentApps.insert(app, at: 0)
        }
    }

    func setShelfEnabled(_ enabled: Bool) {
        shelfConfiguration.isEnabled = enabled
    }

    func setShelfHidesSensitiveValues(_ hidden: Bool) {
        shelfConfiguration.hidesSensitiveValues = hidden
    }

    func setShelfPositionFraction(_ fraction: Double) {
        shelfConfiguration.positionFraction = fraction
        shelfConfiguration.normalize()
    }

    func addShelfFeature(_ feature: DockFeature) {
        shelfConfiguration.orderedFeatures.append(feature)
        shelfConfiguration.normalize()
    }

    func removeShelfFeature(_ feature: DockFeature) {
        shelfConfiguration.orderedFeatures.removeAll { $0 == feature }
    }

    func moveShelfFeature(_ feature: DockFeature, by offset: Int) {
        guard let index = shelfConfiguration.orderedFeatures.firstIndex(of: feature),
              shelfConfiguration.orderedFeatures.indices.contains(index + offset) else { return }
        shelfConfiguration.orderedFeatures.swapAt(index, index + offset)
    }

    func setClockDisplayStyle(_ value: DockClockDisplayStyle) {
        clockConfiguration.setDisplayStyle(value)
        persistClockConfiguration()
    }

    func setClockFollowsSystemTimeZone(_ value: Bool) {
        clockConfiguration.setFollowsSystemTimeZone(value)
        persistClockConfiguration()
    }

    func setClockTimeZoneIdentifier(_ value: String) {
        clockConfiguration.setTimeZoneIdentifier(value)
        persistClockConfiguration()
    }

    func setSystemMetricsOuterColor(_ color: DockColor) {
        systemMetricsAppearance.outerColor = color
        persistSystemMetricsAppearance()
    }

    func setSystemMetricsInnerColor(_ color: DockColor) {
        systemMetricsAppearance.innerColor = color
        persistSystemMetricsAppearance()
    }

    func setSystemMetricsOuterWidth(_ value: Double) {
        systemMetricsAppearance.setOuterWidth(value)
        persistSystemMetricsAppearance()
    }

    func setSystemMetricsInnerWidth(_ value: Double) {
        systemMetricsAppearance.setInnerWidth(value)
        persistSystemMetricsAppearance()
    }

    func setSystemMetricsDisplayStyle(_ value: DockDisplayStyle) {
        systemMetricsAppearance.setDisplayStyle(value)
        persistSystemMetricsAppearance()
    }

    func resetSystemMetricsAppearance() {
        let displayStyle = systemMetricsAppearance.displayStyle
        systemMetricsAppearance = DockFeatureDefaults.systemMetricsAppearance
        systemMetricsAppearance.setDisplayStyle(displayStyle)
        persistSystemMetricsAppearance()
    }

    func setNetworkDownloadColor(_ color: DockColor) {
        networkAppearance.downloadColor = color
        persistNetworkAppearance()
    }

    func setNetworkUploadColor(_ color: DockColor) {
        networkAppearance.uploadColor = color
        persistNetworkAppearance()
    }

    func resetNetworkAppearance() {
        networkAppearance = DockFeatureDefaults.networkAppearance
        persistNetworkAppearance()
    }

    func setStorageColor(_ color: DockColor) {
        storageAppearance.color = color
        persistStorageAppearance()
    }

    func setStorageWidth(_ value: Double) {
        storageAppearance.setWidth(value)
        persistStorageAppearance()
    }

    func setStorageDisplayStyle(_ value: DockDisplayStyle) {
        storageAppearance.setDisplayStyle(value)
        persistStorageAppearance()
    }

    func resetStorageAppearance() {
        let displayStyle = storageAppearance.displayStyle
        storageAppearance = DockFeatureDefaults.storageAppearance
        storageAppearance.setDisplayStyle(displayStyle)
        persistStorageAppearance()
    }

    func setGitHubStarColor(_ color: DockColor) {
        githubAppearance.starColor = color
        persistGitHubAppearance()
    }

    func setGitHubForkColor(_ color: DockColor) {
        githubAppearance.forkColor = color
        persistGitHubAppearance()
    }

    func setGitHubDisplayStyle(_ value: DockDisplayStyle) {
        githubAppearance.setDisplayStyle(value)
        persistGitHubAppearance()
    }

    func resetGitHubAppearance() {
        let displayStyle = githubAppearance.displayStyle
        githubAppearance = DockFeatureDefaults.githubAppearance
        githubAppearance.setDisplayStyle(displayStyle)
        persistGitHubAppearance()
    }

    func setCodexOuterColor(_ color: DockColor) {
        codexAppearance.outerColor = color
        persistCodexAppearance()
    }

    func setCodexInnerColor(_ color: DockColor) {
        codexAppearance.innerColor = color
        persistCodexAppearance()
    }

    func setCodexOuterWidth(_ value: Double) {
        codexAppearance.setOuterWidth(value)
        persistCodexAppearance()
    }

    func setCodexInnerWidth(_ value: Double) {
        codexAppearance.setInnerWidth(value)
        persistCodexAppearance()
    }

    func setCodexDisplayStyle(_ value: DockDisplayStyle) {
        codexAppearance.setDisplayStyle(value)
        persistCodexAppearance()
    }

    func resetCodexAppearance() {
        let displayStyle = codexAppearance.displayStyle
        codexAppearance = DockFeatureDefaults.codexAppearance
        codexAppearance.setDisplayStyle(displayStyle)
        persistCodexAppearance()
    }

    func setClaudeCodeOuterColor(_ color: DockColor) {
        claudeCodeAppearance.outerColor = color
        persistClaudeCodeAppearance()
    }

    func setClaudeCodeInnerColor(_ color: DockColor) {
        claudeCodeAppearance.innerColor = color
        persistClaudeCodeAppearance()
    }

    func setClaudeCodeOuterWidth(_ value: Double) {
        claudeCodeAppearance.setOuterWidth(value)
        persistClaudeCodeAppearance()
    }

    func setClaudeCodeInnerWidth(_ value: Double) {
        claudeCodeAppearance.setInnerWidth(value)
        persistClaudeCodeAppearance()
    }

    func setClaudeCodeDisplayStyle(_ value: DockDisplayStyle) {
        claudeCodeAppearance.setDisplayStyle(value)
        persistClaudeCodeAppearance()
    }

    func resetClaudeCodeAppearance() {
        let displayStyle = claudeCodeAppearance.displayStyle
        claudeCodeAppearance = DockFeatureDefaults.claudeCodeAppearance
        claudeCodeAppearance.setDisplayStyle(displayStyle)
        persistClaudeCodeAppearance()
    }

    func setAntigravityOuterColor(_ color: DockColor) {
        antigravityAppearance.outerColor = color
        persistAntigravityAppearance()
    }

    func setAntigravityInnerColor(_ color: DockColor) {
        antigravityAppearance.innerColor = color
        persistAntigravityAppearance()
    }

    func setAntigravityOuterWidth(_ value: Double) {
        antigravityAppearance.setOuterWidth(value)
        persistAntigravityAppearance()
    }

    func setAntigravityInnerWidth(_ value: Double) {
        antigravityAppearance.setInnerWidth(value)
        persistAntigravityAppearance()
    }

    func setAntigravityDisplayStyle(_ value: DockDisplayStyle) {
        antigravityAppearance.setDisplayStyle(value)
        persistAntigravityAppearance()
    }

    func resetAntigravityAppearance() {
        let displayStyle = antigravityAppearance.displayStyle
        antigravityAppearance = DockFeatureDefaults.antigravityAppearance
        antigravityAppearance.setDisplayStyle(displayStyle)
        persistAntigravityAppearance()
    }

    private func persistClockConfiguration() {
        Self.encodeValue(
            clockConfiguration,
            to: defaults,
            key: Self.clockConfigurationKey
        )
    }

    private func persistSystemMetricsAppearance() {
        Self.encodeAppearance(
            systemMetricsAppearance,
            to: defaults,
            key: Self.systemMetricsAppearanceKey
        )
    }

    private func persistNetworkAppearance() {
        Self.encodeValue(
            networkAppearance,
            to: defaults,
            key: Self.networkAppearanceKey
        )
    }

    private func persistStorageAppearance() {
        Self.encodeValue(
            storageAppearance,
            to: defaults,
            key: Self.storageAppearanceKey
        )
    }

    private func persistGitHubAppearance() {
        Self.encodeValue(
            githubAppearance,
            to: defaults,
            key: Self.githubAppearanceKey
        )
    }

    private func persistCodexAppearance() {
        Self.encodeAppearance(
            codexAppearance,
            to: defaults,
            key: Self.codexAppearanceKey
        )
    }

    private func persistClaudeCodeAppearance() {
        Self.encodeAppearance(
            claudeCodeAppearance,
            to: defaults,
            key: Self.claudeCodeAppearanceKey
        )
    }

    private func persistAntigravityAppearance() {
        Self.encodeAppearance(
            antigravityAppearance,
            to: defaults,
            key: Self.antigravityAppearanceKey
        )
    }

    private static func decodeAppearance(
        from defaults: UserDefaults,
        key: String,
        fallback: DockRingAppearance
    ) -> DockRingAppearance {
        guard
            let data = defaults.data(forKey: key),
            let appearance = try? JSONDecoder().decode(
                DockRingAppearance.self,
                from: data
            )
        else {
            return fallback
        }

        return DockRingAppearance(
            outerColor: appearance.outerColor,
            innerColor: appearance.innerColor,
            outerWidth: appearance.outerWidth,
            innerWidth: appearance.innerWidth,
            displayStyle: appearance.displayStyle
        )
    }

    private static func encodeAppearance(
        _ appearance: DockRingAppearance,
        to defaults: UserDefaults,
        key: String
    ) {
        guard let data = try? JSONEncoder().encode(appearance) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func decodeValue<Value: Codable>(
        _ type: Value.Type,
        from defaults: UserDefaults,
        key: String,
        fallback: Value
    ) -> Value {
        guard
            let data = defaults.data(forKey: key),
            let value = try? JSONDecoder().decode(type, from: data)
        else {
            return fallback
        }
        return value
    }

    private static func encodeValue<Value: Encodable>(
        _ value: Value,
        to defaults: UserDefaults,
        key: String
    ) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path else {
            return nil
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}
