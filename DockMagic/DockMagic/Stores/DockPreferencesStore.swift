import Foundation
import Observation

@MainActor
@Observable
final class DockPreferencesStore {
    static let systemMetricsAppearanceKey = "DockMagicSystemMetricsAppearance"
    static let networkAppearanceKey = "DockMagicNetworkAppearance"
    static let storageAppearanceKey = "DockMagicStorageAppearance"
    static let codexAppearanceKey = "DockMagicCodexAppearance"
    static let codexExecutablePathKey = "DockMagicCodexExecutablePath"
    static let claudeCodeAppearanceKey = "DockMagicClaudeCodeAppearance"

    var activeFeature: DockFeature {
        didSet {
            guard activeFeature != oldValue else {
                return
            }

            defaults.set(activeFeature.rawValue, forKey: DockFeature.storageKey)
        }
    }

    private(set) var systemMetricsAppearance: DockRingAppearance
    private(set) var networkAppearance: DockNetworkAppearance
    private(set) var storageAppearance: DockSingleRingAppearance
    private(set) var codexAppearance: DockRingAppearance
    private(set) var claudeCodeAppearance: DockRingAppearance

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

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        activeFeature = defaults.string(forKey: DockFeature.storageKey)
            .flatMap(DockFeature.init(rawValue:))
            ?? .systemMetrics
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
        codexExecutablePath = Self.normalizedPath(
            defaults.string(forKey: Self.codexExecutablePathKey)
        )
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

    func resetSystemMetricsAppearance() {
        systemMetricsAppearance = DockFeatureDefaults.systemMetricsAppearance
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

    func resetStorageAppearance() {
        storageAppearance = DockFeatureDefaults.storageAppearance
        persistStorageAppearance()
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

    func resetCodexAppearance() {
        codexAppearance = DockFeatureDefaults.codexAppearance
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

    func resetClaudeCodeAppearance() {
        claudeCodeAppearance = DockFeatureDefaults.claudeCodeAppearance
        persistClaudeCodeAppearance()
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
            innerWidth: appearance.innerWidth
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
