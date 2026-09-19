import AppKit
import Carbon

/// A serial worker owns all AE descriptors. No scripts, child processes or private frameworks.
final class AppleEventsPlaybackClient: @unchecked Sendable {
    let source: NowPlayingSource
    private let queue: DispatchQueue
    private var cachedTrack: NowPlayingTrack?
    private var metadataCheckedAt: TimeInterval = 0

    init(source: NowPlayingSource) {
        self.source = source
        queue = DispatchQueue(label: "com.hypevibe.DockMagic.nowPlaying.\(source.rawValue)", qos: .utility)
    }

    private func work<T: Sendable>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try operation() }) }
        }
    }

    @MainActor private func application() -> (installed: Bool, pid: pid_t?) {
        (NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) != nil,
         NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).first?.processIdentifier)
    }

    func observe(requestPermission: Bool) async -> NowPlayingObservation {
        let app = await application()
        guard app.installed else { return .init(access: .notInstalled) }
        guard let pid = app.pid else { return .init(access: .notRunning) }
        do {
            return try await work { [self] in
                let session = AppleEventsPlaybackSession(pid: pid)
                let permission = session.permission(ask: requestPermission)
                guard permission == .authorized else { return .init(access: permission) }
                let stateValue = try session.get("pPlS").enumCodeValue
                let state: PlaybackState = stateValue == Self.code("kPSP") ? .playing : stateValue == Self.code("kPSp") ? .paused : .stopped
                let volume = try session.optionalNumber("pVol").map { min(100, max(0, $0)) }
                let position = try session.optionalNumber("pPos")
                let trackObject = session.property("pTrk")
                let identity = try session.optionalString(source == .spotify ? "ID  " : "pPIS", of: trackObject)
                let fallbackTitle = identity == nil ? try session.optionalString("pnam", of: trackObject) : nil
                let id = identity ?? fallbackTitle
                var track: NowPlayingTrack?
                if let id {
                    let uptime = ProcessInfo.processInfo.systemUptime
                    if cachedTrack?.id == id && uptime - metadataCheckedAt < 15 {
                        track = cachedTrack
                    } else {
                        let title = try session.optionalString("pnam", of: trackObject) ?? fallbackTitle ?? "Untitled"
                        let duration = try session.optionalNumber("pDur", of: trackObject)
                            .map { source == .spotify ? $0 / 1000 : $0 }
                            .flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
                        let artwork: NowPlayingArtworkReference?
                        if source == .spotify {
                            artwork = try session.optionalString("aUrl", of: trackObject)
                                .flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? .remote($0) : nil }
                        } else { artwork = .musicTrack(id) }
                        track = NowPlayingTrack(id: id, title: title,
                            artist: try session.optionalString("pArt", of: trackObject),
                            album: try session.optionalString("pAlb", of: trackObject),
                            duration: duration, artwork: artwork)
                        cachedTrack = track
                        metadataCheckedAt = uptime
                    }
                } else { cachedTrack = nil }
                let playable = track != nil && state != .stopped
                let isAdvertisement = source == .spotify && (id?.hasPrefix("spotify:ad:") == true)
                return NowPlayingObservation(access: .authorized, snapshot: NowPlayingSnapshot(
                    source: source, track: track, state: state, position: position, volume: volume,
                    capabilities: PlaybackCapabilities(playPause: playable, previous: playable && !isAdvertisement,
                        next: playable && !isAdvertisement, seek: playable && !isAdvertisement && track?.duration != nil && position != nil,
                        volume: volume != nil), observedAt: Date(), observedUptime: ProcessInfo.processInfo.systemUptime))
            }
        } catch {
            let code = Self.errorCode(error)
            return .init(access: code == -1743 ? .denied : code == -600 ? .notRunning : .unavailable,
                         error: code == -1743 ? nil : error.localizedDescription)
        }
    }

    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws {
        guard target.source == source, let pid = await application().pid else { throw NowPlayingProviderError.unavailable }
        try await work { [self] in
            let session = AppleEventsPlaybackSession(pid: pid)
            guard session.permission(ask: false) == .authorized else {
                throw NowPlayingProviderError.appleEvent(-1743, "Allow Automation in System Settings.")
            }
            let track = session.property("pTrk")
            let identity = try session.optionalString(source == .spotify ? "ID  " : "pPIS", of: track)
                ?? session.optionalString("pnam", of: track)
            guard identity == target.trackID else { throw NowPlayingProviderError.targetChanged }
            let suite = source == .spotify ? "spfy" : "hook"
            switch command {
            case .play: _ = try session.send(suite: suite, event: "Play")
            case .pause: _ = try session.send(suite: suite, event: "Paus")
            case .previous: _ = try session.send(suite: suite, event: "Prev")
            case .next: _ = try session.send(suite: suite, event: "Next")
            case let .seek(seconds):
                guard seconds.isFinite else { throw NowPlayingProviderError.unavailable }
                let rawDuration = try session.optionalNumber("pDur", of: track)
                let duration = rawDuration.map { source == .spotify ? $0 / 1000 : $0 }
                try session.set("pPos", to: NSAppleEventDescriptor(double: NowPlayingSnapshot.clamp(seconds, duration: duration)))
            case let .volume(value):
                guard value.isFinite else { throw NowPlayingProviderError.unavailable }
                try session.set("pVol", to: NSAppleEventDescriptor(int32: Int32(min(100, max(0, value)).rounded())))
            }
        }
    }

    func musicArtwork(trackID: String) async throws -> Data? {
        guard source == .appleMusic, let pid = await application().pid else { return nil }
        return try await work {
            let session = AppleEventsPlaybackSession(pid: pid)
            guard session.permission(ask: false) == .authorized else { return nil }
            let track = session.property("pTrk")
            let identity = try session.optionalString("pPIS", of: track) ?? session.optionalString("pnam", of: track)
            guard identity == trackID else { return nil }
            let artwork = session.element("cArt", index: 1, of: track)
            do {
                let value = try session.get("pRaw", of: artwork)
                guard value.data.count <= 12_000_000 else { return nil }
                return value.data
            } catch where [-1728, -1708].contains(Self.errorCode(error)) { return nil }
        }
    }

    static func code(_ text: String) -> OSType { text.utf8.reduce(0) { ($0 << 8) | OSType($1) } }
    static func errorCode(_ error: Error) -> Int {
        if case let NowPlayingProviderError.appleEvent(code, _) = error { return code }
        return (error as NSError).code
    }
}

private final class AppleEventsPlaybackSession {
    private let target: NSAppleEventDescriptor
    private var deadline = ProcessInfo.processInfo.systemUptime + 8
    private func code(_ string: String) -> OSType { AppleEventsPlaybackClient.code(string) }
    init(pid: pid_t) { target = NSAppleEventDescriptor(processIdentifier: pid) }

    func permission(ask: Bool) -> NowPlayingAccess {
        // The user's time in the consent dialog is not an IPC timeout.
        defer { deadline = ProcessInfo.processInfo.systemUptime + 8 }
        guard let descriptor = target.aeDesc else { return .unavailable }
        switch AEDeterminePermissionToAutomateTarget(descriptor, typeWildCard, typeWildCard, ask) {
        case noErr: return .authorized
        case -1744: return .notDetermined
        case -1743: return .denied
        case -600: return .notRunning
        default: return .unavailable
        }
    }

    func property(_ name: String, of container: NSAppleEventDescriptor = .null()) -> NSAppleEventDescriptor {
        specifier(want: "prop", form: "prop", key: NSAppleEventDescriptor(typeCode: code(name)), container: container)
    }

    func element(_ name: String, index: Int32, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        specifier(want: name, form: "indx", key: NSAppleEventDescriptor(int32: index), container: container)
    }

    private func specifier(want: String, form: String, key: NSAppleEventDescriptor, container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: code(want)), forKeyword: code("want"))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: code(form)), forKeyword: code("form"))
        record.setDescriptor(key, forKeyword: code("seld"))
        record.setDescriptor(container, forKeyword: code("from"))
        return record.coerce(toDescriptorType: code("obj "))!
    }

    func send(suite: String = "core", event: String, object: NSAppleEventDescriptor? = nil, value: NSAppleEventDescriptor? = nil) throws -> NSAppleEventDescriptor {
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { throw NowPlayingProviderError.appleEvent(-1712, "The music app did not respond in time.") }
        let request = NSAppleEventDescriptor(eventClass: code(suite), eventID: code(event), targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        if let object { request.setParam(object, forKeyword: code("----")) }
        if let value { request.setParam(value, forKeyword: code("data")) }
        let reply = try request.sendEvent(options: [.waitForReply, .neverInteract], timeout: min(2, remaining))
        if let error = reply.paramDescriptor(forKeyword: code("errn")), error.int32Value != 0 {
            throw NowPlayingProviderError.appleEvent(Int(error.int32Value), reply.paramDescriptor(forKeyword: code("errs"))?.stringValue ?? "The music app could not complete the request.")
        }
        return reply.paramDescriptor(forKeyword: code("----")) ?? .null()
    }

    func get(_ name: String, of container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        try send(event: "getd", object: property(name, of: container))
    }
    func set(_ name: String, to value: NSAppleEventDescriptor) throws { _ = try send(event: "setd", object: property(name), value: value) }
    private func optional(_ name: String, of container: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor? {
        do {
            let value = try get(name, of: container)
            return [code("msng"), code("null")].contains(value.descriptorType) ? nil : value
        } catch where [-1728, -1708].contains(AppleEventsPlaybackClient.errorCode(error)) { return nil }
    }
    func optionalString(_ name: String, of container: NSAppleEventDescriptor = .null()) throws -> String? {
        try optional(name, of: container)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
    }
    func optionalNumber(_ name: String, of container: NSAppleEventDescriptor = .null()) throws -> Double? {
        guard let value = try optional(name, of: container)?.coerce(toDescriptorType: typeIEEE64BitFloatingPoint)?.doubleValue,
              value.isFinite else { return nil }
        return value
    }
}

struct SpotifyPlaybackProvider: NowPlayingProviding {
    let source = NowPlayingSource.spotify
    private let client = AppleEventsPlaybackClient(source: .spotify)
    func observe(requestPermission: Bool) async -> NowPlayingObservation { await client.observe(requestPermission: requestPermission) }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws { try await client.perform(command, target: target) }
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? { nil }
}

struct AppleMusicPlaybackProvider: NowPlayingProviding {
    let source = NowPlayingSource.appleMusic
    private let client = AppleEventsPlaybackClient(source: .appleMusic)
    func observe(requestPermission: Bool) async -> NowPlayingObservation { await client.observe(requestPermission: requestPermission) }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws { try await client.perform(command, target: target) }
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? {
        guard case let .musicTrack(id) = reference else { return nil }
        return try await client.musicArtwork(trackID: id)
    }
}
