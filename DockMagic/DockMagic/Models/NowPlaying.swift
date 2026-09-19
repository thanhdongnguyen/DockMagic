import Foundation

enum NowPlayingSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case spotify, appleMusic
    var id: Self { self }
    var title: String { self == .spotify ? "Spotify" : "Apple Music" }
    var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
}

enum NowPlayingSelection: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic, spotify, appleMusic
    var id: Self { self }
    var source: NowPlayingSource? { NowPlayingSource(rawValue: rawValue) }
    var title: String { source?.title ?? "Auto" }
}

struct NowPlayingConfiguration: Codable, Equatable, Sendable {
    var enabledSources: Set<NowPlayingSource> = []
    var selection: NowPlayingSelection = .automatic
    var preferredSource: NowPlayingSource = .spotify
    var skipSeconds: Int = 15
    static let skipIntervals = [5, 10, 15, 30, 60]
}

enum PlaybackState: String, Equatable, Sendable {
    case playing, paused, stopped
    var title: String { rawValue.capitalized }
}

struct PlaybackCapabilities: Equatable, Sendable {
    var playPause = false
    var previous = false
    var next = false
    var seek = false
    var volume = false
}

enum NowPlayingAccess: String, Equatable, Sendable {
    case notInstalled, notRunning, notDetermined, denied, authorized, unavailable
    var title: String {
        switch self {
        case .notInstalled: "Not installed"
        case .notRunning: "App not running"
        case .notDetermined: "Not connected"
        case .denied: "Automation permission denied"
        case .authorized: "Connected"
        case .unavailable: "Not responding"
        }
    }
}

enum NowPlayingArtworkReference: Equatable, Hashable, Sendable {
    case remote(URL)
    case musicTrack(String)
    case fixture
}

struct NowPlayingTrack: Equatable, Sendable {
    let id: String
    var title: String
    var artist: String?
    var album: String?
    var duration: TimeInterval?
    var artwork: NowPlayingArtworkReference?
}

struct NowPlayingSnapshot: Equatable, Sendable {
    let source: NowPlayingSource
    var track: NowPlayingTrack?
    var state: PlaybackState
    var position: TimeInterval?
    var volume: Double?
    var capabilities: PlaybackCapabilities
    var observedAt: Date
    var observedUptime: TimeInterval

    func isFresh(at uptime: TimeInterval) -> Bool {
        uptime >= observedUptime && uptime - observedUptime < 12
    }

    func elapsed(at uptime: TimeInterval) -> TimeInterval? {
        guard let position, position.isFinite else { return nil }
        let advance = state == .playing && isFresh(at: uptime) ? max(0, uptime - observedUptime) : 0
        return Self.clamp(position + advance, duration: track?.duration)
    }

    static func clamp(_ value: TimeInterval, duration: TimeInterval?) -> TimeInterval {
        guard value.isFinite else { return 0 }
        return min(max(0, value), duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? .greatestFiniteMagnitude)
    }
}

struct NowPlayingObservation: Equatable, Sendable {
    var access: NowPlayingAccess = .notDetermined
    var snapshot: NowPlayingSnapshot?
    var error: String?
}

/// Captured when the interaction begins. A source or track change invalidates it.
struct NowPlayingCommandTarget: Equatable, Sendable {
    let source: NowPlayingSource
    let trackID: String?
}

enum NowPlayingCommand: Equatable, Sendable {
    case play, pause, previous, next, seek(TimeInterval), volume(Double)
}

/// Deliberately excludes elapsed time and volume: these never redraw the Dock icon.
struct NowPlayingDockPresentation: Equatable, Sendable {
    var source: NowPlayingSource?
    var title: String?
    var state: PlaybackState?
    var artworkData: Data?
    var canControl = false
}

enum NowPlayingSourceResolver {
    static func resolve(configuration: NowPlayingConfiguration, observations: [NowPlayingSource: NowPlayingObservation], current: NowPlayingSource?) -> NowPlayingSource? {
        let enabled = configuration.enabledSources
        if let manual = configuration.selection.source { return enabled.contains(manual) ? manual : nil }
        let playing = enabled.filter { observations[$0]?.snapshot?.state == .playing && observations[$0]?.access == .authorized }
        if let current, playing.contains(current) { return current }
        if playing.contains(configuration.preferredSource) { return configuration.preferredSource }
        if let source = NowPlayingSource.allCases.first(where: { playing.contains($0) }) { return source }
        if let current, enabled.contains(current), observations[current]?.snapshot?.track != nil { return current }
        if enabled.contains(configuration.preferredSource) { return configuration.preferredSource }
        return NowPlayingSource.allCases.first { enabled.contains($0) }
    }
}

enum NowPlayingTimeFormat {
    static func string(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0, seconds < Double(Int.max / 2) else { return "—:—" }
        let value = Int(seconds)
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%d:%02d", value / 60, value % 60)
    }
}
