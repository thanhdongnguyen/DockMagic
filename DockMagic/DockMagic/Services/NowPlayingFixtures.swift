#if DEBUG
import AppKit

enum NowPlayingFixtures {
    static func snapshot(source: NowPlayingSource = .spotify, state: PlaybackState = .playing) -> NowPlayingSnapshot {
        .init(source: source, track: .init(id: "fixture-\(source.rawValue)-1", title: source == .spotify ? "A quiet afternoon" : "Evening in motion",
            artist: "Studio Sessions", album: "Instrumentals · Vol. 01", duration: 224, artwork: .fixture),
            state: state, position: 82, volume: 65,
            capabilities: .init(playPause: true, previous: true, next: true, seek: true, volume: true),
            observedAt: Date(), observedUptime: ProcessInfo.processInfo.systemUptime)
    }
    @MainActor static func store(mode: String, defaults: UserDefaults = DockMagicRuntimeDefaults.current) -> NowPlayingStore {
        let store = NowPlayingStore(providers: NowPlayingSource.allCases.map { NowPlayingFixtureProvider(source: $0, mode: mode) },
            defaults: defaults, fixtureData: NSImage(named: "NowPlayingFixtureAlbum")?.tiffRepresentation)
        store.updateConfiguration { $0.enabledSources = mode == "disconnected" ? [] : Set(NowPlayingSource.allCases) }
        return store
    }
}

actor NowPlayingFixtureProvider: NowPlayingProviding {
    nonisolated let source: NowPlayingSource
    private let mode: String
    private var observation: NowPlayingObservation
    private(set) var commands: [NowPlayingCommand] = []
    private(set) var permissionRequests = 0
    private(set) var reads = 0
    init(source: NowPlayingSource, mode: String = "playing") {
        self.source = source
        self.mode = mode
        var snapshot = NowPlayingFixtures.snapshot(source: source, state: mode == "paused" ? .paused : .playing)
        if mode == "stale" { snapshot.observedUptime -= 30 }
        if mode == "longTitle" { snapshot.track?.title = "A quiet afternoon on the coast — a long instrumental session to keep you company" }
        if mode == "noArtwork" { snapshot.track?.artwork = nil }
        if mode == "unknownDuration" { snapshot.track?.duration = nil; snapshot.capabilities.seek = false }
        if mode == "noMedia" { snapshot.track = nil; snapshot.state = .stopped; snapshot.capabilities = .init() }
        observation = .init(access: .authorized, snapshot: snapshot)
        if mode == "denied" { observation = .init(access: .denied) }
        if mode == "notRunning" { observation = .init(access: .notRunning) }
        if mode == "disconnected" { observation = .init(access: .notDetermined) }
        if mode == "unavailable" { observation = .init(access: .unavailable, error: "The music app did not respond in time. (-1712)") }
    }
    func setObservation(_ value: NowPlayingObservation) { observation = value }
    func observe(requestPermission: Bool) async -> NowPlayingObservation {
        reads += 1
        if mode == "loading" { try? await Task.sleep(for: .seconds(30)) }
        if requestPermission {
            permissionRequests += 1
            if observation.access == .notDetermined { observation = .init(access: .authorized, snapshot: NowPlayingFixtures.snapshot(source: source)) }
        }
        if mode != "stale", var snapshot = observation.snapshot {
            snapshot.position = snapshot.elapsed(at: ProcessInfo.processInfo.systemUptime)
            snapshot.observedAt = Date(); snapshot.observedUptime = ProcessInfo.processInfo.systemUptime
            observation.snapshot = snapshot
        }
        return observation
    }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws {
        guard target.source == source, target.trackID == observation.snapshot?.track?.id else { throw NowPlayingProviderError.targetChanged }
        commands.append(command)
        guard var snapshot = observation.snapshot else { return }
        snapshot.position = snapshot.elapsed(at: ProcessInfo.processInfo.systemUptime)
        switch command {
        case .play: snapshot.state = .playing
        case .pause: snapshot.state = .paused
        case .next, .previous:
            snapshot.track = NowPlayingTrack(id: "fixture-\(source.rawValue)-\(commands.count + 1)", title: command == .next ? "Through the pines" : "A quiet afternoon", artist: "Studio Sessions", album: "Instrumentals · Vol. 01", duration: 245, artwork: .fixture)
            snapshot.position = 0
        case let .seek(value): snapshot.position = NowPlayingSnapshot.clamp(value, duration: snapshot.track?.duration)
        case let .volume(value): snapshot.volume = min(100, max(0, value))
        }
        snapshot.observedAt = Date(); snapshot.observedUptime = ProcessInfo.processInfo.systemUptime
        observation.snapshot = snapshot
    }
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? { nil }
}
#endif
