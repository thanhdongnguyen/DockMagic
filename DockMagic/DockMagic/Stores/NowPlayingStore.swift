import AppKit
import Observation

@MainActor @Observable
final class NowPlayingStore {
    enum Interest: Hashable { case dock, panel, settings }
    static let configurationKey = "DockMagicNowPlayingConfiguration"
    private(set) var configuration: NowPlayingConfiguration
    private(set) var observations: [NowPlayingSource: NowPlayingObservation] = [:]
    private(set) var selectedSource: NowPlayingSource?
    private(set) var artworkData: Data?
    private(set) var isLoading = false
    private(set) var connecting: Set<NowPlayingSource> = []
    private(set) var isCommandPending = false
    private(set) var commandError: String?
    private(set) var isMonitoring = false
    @ObservationIgnored private let providers: [NowPlayingSource: any NowPlayingProviding]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let artworkCache: NowPlayingArtworkCache
    @ObservationIgnored private var interests: Set<Interest> = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var commandTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTasks: [NowPlayingSource: Task<Void, Never>] = [:]
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private let workspaceNotifications: NotificationCenter
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var artworkTarget: NowPlayingCommandTarget?
    @ObservationIgnored private var artworkReference: NowPlayingArtworkReference?

    init(providers: [any NowPlayingProviding] = [SpotifyPlaybackProvider(), AppleMusicPlaybackProvider()],
         defaults: UserDefaults = DockMagicRuntimeDefaults.current, fixtureData: Data? = nil,
         workspaceNotifications: NotificationCenter? = nil) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.source, $0) })
        self.defaults = defaults
        self.artworkCache = NowPlayingArtworkCache(fixtureData: fixtureData)
        self.workspaceNotifications = workspaceNotifications ?? NSWorkspace.shared.notificationCenter
        configuration = defaults.data(forKey: Self.configurationKey)
            .flatMap { try? JSONDecoder().decode(NowPlayingConfiguration.self, from: $0) } ?? .init()
        if !NowPlayingConfiguration.skipIntervals.contains(configuration.skipSeconds) { configuration.skipSeconds = 15 }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification] {
            workspaceObservers.append(self.workspaceNotifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reload() }
            })
        }
    }

    deinit {
        pollTask?.cancel(); artworkTask?.cancel(); commandTask?.cancel()
        for task in connectionTasks.values { task.cancel() }
        for observer in workspaceObservers { workspaceNotifications.removeObserver(observer) }
    }

    var observation: NowPlayingObservation? { selectedSource.flatMap { observations[$0] } }
    var snapshot: NowPlayingSnapshot? { observation?.snapshot }
    var commandTarget: NowPlayingCommandTarget? {
        guard let selectedSource else { return nil }
        return .init(source: selectedSource, trackID: snapshot?.track?.id)
    }
    var dockPresentation: NowPlayingDockPresentation {
        .init(source: selectedSource, title: snapshot?.track?.title, state: snapshot?.state,
              artworkData: artworkData, canControl: observation?.access == .authorized && snapshot?.capabilities.playPause == true)
    }
    var pollingSeconds: Double {
        if snapshot?.state == .playing { return interests.contains(.panel) ? 1 : 4 }
        return interests.contains(.panel) ? 3 : 8
    }

    func setInterest(_ interest: Interest, active: Bool) {
        let before = interests
        if active { interests.insert(interest) } else { interests.remove(interest) }
        guard before != interests else { return }
        if interests.isEmpty { stopPolling() } else { reload() }
    }

    func stop() {
        interests.removeAll()
        stopPolling()
        for task in connectionTasks.values { task.cancel() }
        connectionTasks.removeAll(); connecting.removeAll()
    }

    private func stopPolling() {
        revision += 1
        pollTask?.cancel(); pollTask = nil
        artworkTask?.cancel(); artworkTask = nil
        artworkTarget = nil; artworkReference = nil
        commandTask?.cancel(); commandTask = nil
        isCommandPending = false; isLoading = false; isMonitoring = false
    }

    func updateConfiguration(_ update: (inout NowPlayingConfiguration) -> Void) {
        update(&configuration)
        if !NowPlayingConfiguration.skipIntervals.contains(configuration.skipSeconds) { configuration.skipSeconds = 15 }
        if let data = try? JSONEncoder().encode(configuration) { defaults.set(data, forKey: Self.configurationKey) }
        commandError = nil
        resolve()
        reload()
    }
    func select(_ selection: NowPlayingSelection) {
        updateConfiguration {
            $0.selection = selection
            if let source = selection.source { $0.preferredSource = source }
        }
    }
    func setEnabled(_ source: NowPlayingSource, enabled: Bool) {
        if !enabled { connectionTasks[source]?.cancel(); connectionTasks[source] = nil; connecting.remove(source) }
        updateConfiguration { if enabled { $0.enabledSources.insert(source) } else { $0.enabledSources.remove(source) } }
    }

    func reload() {
        guard !interests.isEmpty else { return }
        revision += 1
        let token = revision
        pollTask?.cancel()
        isMonitoring = true
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh(token: token)
                guard !Task.isCancelled, self.revision == token else { return }
                do { try await Task.sleep(for: .seconds(self.pollingSeconds)) } catch { return }
            }
        }
    }

    private func refresh(token: Int) async {
        let currentBeforeRefresh = selectedSource
        let enabled = configuration.enabledSources.subtracting(connecting)
        if observations.isEmpty { isLoading = true }
        // Each app has its own serial worker; a timeout cannot block the other app.
        await withTaskGroup(of: (NowPlayingSource, NowPlayingObservation).self) { group in
            for source in enabled {
                guard let provider = providers[source] else { continue }
                group.addTask { (source, await provider.observe(requestPermission: false)) }
            }
            for await (source, result) in group {
                guard !Task.isCancelled, token == revision, configuration.enabledSources.contains(source), !connecting.contains(source) else { continue }
                observations[source] = result
                // Completion order must not decide the cold-start Auto source.
                resolve(current: currentBeforeRefresh)
            }
        }
        guard !Task.isCancelled, token == revision else { return }
        isLoading = false
        resolve()
    }

    func connect(_ source: NowPlayingSource) {
        guard !connecting.contains(source), let provider = providers[source] else { return }
        connecting.insert(source)
        setEnabled(source, enabled: true)
        connectionTasks[source] = Task { [weak self] in
            let result = await provider.observe(requestPermission: true)
            guard let self, !Task.isCancelled, self.configuration.enabledSources.contains(source) else { return }
            self.observations[source] = result
            self.connecting.remove(source); self.connectionTasks[source] = nil
            self.resolve(); self.reload()
        }
    }

    private func resolve() { resolve(current: selectedSource) }

    private func resolve(current: NowPlayingSource?) {
        let previous = commandTarget
        selectedSource = NowPlayingSourceResolver.resolve(configuration: configuration, observations: observations, current: current)
        if previous != commandTarget { commandError = nil }
        let reference = snapshot?.track?.artwork
        guard artworkTarget != commandTarget || artworkReference != reference || (artworkData == nil && artworkTask == nil) else { return }
        artworkTask?.cancel()
        artworkTarget = commandTarget; artworkReference = reference; artworkData = nil
        guard let target = commandTarget, let reference, let provider = providers[target.source], !interests.isEmpty else { artworkTask = nil; return }
        artworkTask = Task { [weak self, artworkCache] in
            let data = await artworkCache.data(for: reference, provider: provider)
            guard let self, !Task.isCancelled, self.commandTarget == target, self.artworkReference == reference else { return }
            self.artworkData = data; self.artworkTask = nil
        }
    }

    func canPerform(_ command: NowPlayingCommand) -> Bool {
        guard observation?.access == .authorized, let snapshot, snapshot.isFresh(at: ProcessInfo.processInfo.systemUptime), !isCommandPending else { return false }
        switch command {
        case .play, .pause: return snapshot.capabilities.playPause
        case .previous: return snapshot.capabilities.previous
        case .next: return snapshot.capabilities.next
        case .seek: return snapshot.capabilities.seek
        case .volume: return snapshot.capabilities.volume
        }
    }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget? = nil) {
        guard let target = target ?? commandTarget, target == commandTarget,
              canPerform(command), let provider = providers[target.source] else { return }
        isCommandPending = true; commandError = nil
        commandTask = Task { [weak self] in
            do { try await provider.perform(command, target: target) }
            catch {
                guard !Task.isCancelled else { return }
                if self?.commandTarget == target { self?.commandError = error.localizedDescription }
            }
            guard let self, !Task.isCancelled else { return }
            self.isCommandPending = false; self.commandTask = nil
            self.reload()
        }
    }
    func togglePlayback() { perform(snapshot?.state == .playing ? .pause : .play) }
    func skip(_ direction: Double) {
        guard let elapsed = snapshot?.elapsed(at: ProcessInfo.processInfo.systemUptime) else { return }
        perform(.seek(NowPlayingSnapshot.clamp(elapsed + direction * Double(configuration.skipSeconds), duration: snapshot?.track?.duration)))
    }

    static func isInstalled(_ source: NowPlayingSource) -> Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) != nil }
    static func openApp(_ source: NowPlayingSource) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
    }
}
