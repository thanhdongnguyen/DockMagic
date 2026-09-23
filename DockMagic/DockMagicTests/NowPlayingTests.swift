import AppKit
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import DockMagic

final class NowPlayingTests: XCTestCase {
    func testAutoIsStableAndManualNeverFallsBack() {
        var config = NowPlayingConfiguration()
        config.enabledSources = Set(NowPlayingSource.allCases)
        let observations = Dictionary(uniqueKeysWithValues: NowPlayingSource.allCases.map { ($0, NowPlayingObservation(access: .authorized, snapshot: NowPlayingFixtures.snapshot(source: $0))) })
        XCTAssertEqual(NowPlayingSourceResolver.resolve(configuration: config, observations: observations, current: .appleMusic), .appleMusic)
        XCTAssertEqual(NowPlayingSourceResolver.resolve(configuration: config, observations: observations, current: nil), .spotify)
        config.selection = .appleMusic
        var denied = observations; denied[.appleMusic] = .init(access: .denied)
        XCTAssertEqual(NowPlayingSourceResolver.resolve(configuration: config, observations: denied, current: .spotify), .appleMusic)
        config.enabledSources.remove(.appleMusic)
        XCTAssertNil(NowPlayingSourceResolver.resolve(configuration: config, observations: denied, current: .spotify))
    }

    func testElapsedUsesMonotonicTimeAndRejectsUnknownValues() {
        var value = NowPlayingFixtures.snapshot()
        value.observedUptime = 100; value.position = 220
        XCTAssertEqual(value.elapsed(at: 106), 224)
        value.state = .paused
        XCTAssertEqual(value.elapsed(at: 106), 220)
        XCTAssertFalse(value.isFresh(at: 99))
        XCTAssertFalse(value.isFresh(at: 112))
        value.position = nil
        XCTAssertNil(value.elapsed(at: 100))
        XCTAssertEqual(NowPlayingSnapshot.clamp(-20, duration: 200), 0)
        XCTAssertEqual(NowPlayingSnapshot.clamp(.infinity, duration: 200), 0)
        XCTAssertEqual(NowPlayingTimeFormat.string(nil), "—:—")
        XCTAssertEqual(NowPlayingTimeFormat.string(3661), "1:01:01")
    }

    @MainActor func testCancelledObservationCannotRestartInactiveStore() async throws {
        let provider = DelayedNowPlayingProvider(source: .spotify)
        let store = makeStore([provider])
        store.setEnabled(.spotify, enabled: true); store.setInterest(.dock, active: true)
        try await Task.sleep(for: .milliseconds(20))
        store.stop()
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertTrue(store.observations.isEmpty)
        XCTAssertFalse(store.isMonitoring)
        XCTAssertNil(store.artworkData)
    }

    @MainActor func testAutoPrefersConfiguredSourceDespiteReversedReplyOrder() async throws {
        let store = makeStore([DelayedNowPlayingProvider(source: .spotify), NowPlayingFixtureProvider(source: .appleMusic)])
        defer { store.stop() }
        store.updateConfiguration { $0.enabledSources = Set(NowPlayingSource.allCases) }
        store.setInterest(.panel, active: true)
        try await wait { store.observations.count == 2 }
        XCTAssertEqual(store.selectedSource, .spotify)
    }

    @MainActor func testDockUses1024PixelSourceAndFeatureMappings() throws {
        let presentation = NowPlayingDockPresentation(source: .spotify, title: "Track", state: .playing, canControl: true)
        let image = try XCTUnwrap(DockApplicationIconRenderer().render(presentation: .nowPlaying(presentation), appearanceMode: .dark))
        XCTAssertTrue(DockIconRenderingRules.satisfiesSourceContract(image))
        XCTAssertTrue(DockFeature.nowPlaying.hasHoverDashboard)
        XCTAssertEqual(SettingsDestination(activeFeature: .nowPlaying), .nowPlaying)
        XCTAssertEqual(SettingsDestination.nowPlaying.feature, .nowPlaying)
    }

    @MainActor func testPollingNeverRequestsPermissionAndStopsWhenUnused() async throws {
        let provider = NowPlayingFixtureProvider(source: .spotify, mode: "disconnected")
        let store = makeStore([provider]); defer { store.stop() }
        store.setEnabled(.spotify, enabled: true)
        store.setInterest(.dock, active: true)
        try await wait { store.observations[.spotify] != nil }
        let requests = await provider.permissionRequests
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(store.observation?.access, .notDetermined)
        store.connect(.spotify)
        try await wait { store.observation?.access == .authorized }
        let afterConnect = await provider.permissionRequests
        XCTAssertEqual(afterConnect, 1)
        store.setInterest(.dock, active: false)
        XCTAssertFalse(store.isMonitoring)
        let reads = await provider.reads
        store.reload()
        try await Task.sleep(for: .milliseconds(80))
        let readsAfterStop = await provider.reads
        XCTAssertEqual(reads, readsAfterStop)
    }

    @MainActor func testCapturedTargetCannotCrossSourcesAndCommandsRefresh() async throws {
        let spotify = NowPlayingFixtureProvider(source: .spotify)
        let music = NowPlayingFixtureProvider(source: .appleMusic)
        let store = makeStore([spotify, music]); defer { store.stop() }
        store.updateConfiguration { $0.enabledSources = Set(NowPlayingSource.allCases) }
        store.setInterest(.panel, active: true)
        try await wait { store.observations.count == 2 }
        let captured = store.commandTarget
        let dock = store.dockPresentation
        store.perform(.volume(22))
        try await wait { store.snapshot?.volume == 22 }
        XCTAssertEqual(store.dockPresentation, dock, "Volume does not invalidate the Dock bitmap")
        store.select(.appleMusic)
        store.perform(.seek(90), target: captured)
        try await Task.sleep(for: .milliseconds(60))
        let musicCommands = await music.commands
        let spotifyCommands = await spotify.commands
        XCTAssertTrue(musicCommands.isEmpty)
        XCTAssertEqual(spotifyCommands, [.volume(22)])
        store.togglePlayback()
        try await wait { store.snapshot?.state == .paused }
        store.perform(.seek(999))
        try await wait { store.snapshot?.position == 224 }
        XCTAssertEqual(store.selectedSource, .appleMusic)
    }

    @MainActor func testPendingCommandKeepsControlsAvailableWithoutAcceptingDuplicates() async throws {
        let provider = GatedCommandProvider()
        let store = makeStore([provider]); defer { store.stop(); Task { await provider.finish() } }
        store.setEnabled(.spotify, enabled: true); store.setInterest(.panel, active: true)
        try await wait { store.snapshot != nil }
        let unexpectedRedraw = expectation(description: "Command bookkeeping should not invalidate the dashboard")
        unexpectedRedraw.isInverted = true
        withObservationTracking { _ = store.isCommandPending; _ = store.commandError } onChange: { unexpectedRedraw.fulfill() }
        store.perform(.pause)
        try await waitAsync { await provider.commandStarted }
        XCTAssertTrue(store.isCommandPending)
        XCTAssertTrue(store.canOffer(.play), "A pending command must not dim the controls")
        XCTAssertFalse(store.canPerform(.play), "A second command must still be rejected")
        store.perform(.play)
        let commands = await provider.commands
        XCTAssertEqual(commands, [.pause])
        await fulfillment(of: [unexpectedRedraw], timeout: 0.2)
        await provider.finish()
        try await wait { !store.isCommandPending }
    }

    @MainActor func testSharedArtworkStaysVisibleAcrossTrackChange() async throws {
        let store = NowPlayingFixtures.store(mode: "playing", defaults: freshDefaults()); defer { store.stop() }
        store.setInterest(.panel, active: true)
        try await wait { store.artworkData != nil }
        let artworkChanged = expectation(description: "Shared album artwork should not be cleared")
        artworkChanged.isInverted = true
        withObservationTracking { _ = store.artworkData } onChange: { artworkChanged.fulfill() }
        store.perform(.next)
        try await wait { store.snapshot?.track?.title == "Through the pines" }
        await fulfillment(of: [artworkChanged], timeout: 0.2)
        XCTAssertNotNil(store.artworkData)
    }

    @MainActor func testRevocationClearsArtAndOneSourceFailureDoesNotBlockOther() async throws {
        let spotify = NowPlayingFixtureProvider(source: .spotify)
        let music = NowPlayingFixtureProvider(source: .appleMusic, mode: "denied")
        let store = makeStore([spotify, music]); defer { store.stop() }
        store.updateConfiguration { $0.enabledSources = Set(NowPlayingSource.allCases) }
        store.setInterest(.panel, active: true)
        try await wait { store.observations.count == 2 }
        XCTAssertEqual(store.selectedSource, .spotify)
        XCTAssertTrue(store.canPerform(.play))
        await spotify.setObservation(.init(access: .denied))
        store.reload()
        try await wait { store.observations[.spotify]?.access == .denied }
        XCTAssertNil(store.snapshot)
        XCTAssertNil(store.artworkData)
        XCTAssertFalse(store.canPerform(.play))
    }

    func testProviderRejectsTrackThatChangedAfterTouchBegan() async throws {
        let provider = NowPlayingFixtureProvider(source: .spotify)
        let old = NowPlayingFixtures.snapshot()
        var changed = old
        changed.track = .init(id: "new-track", title: "New song")
        await provider.setObservation(.init(access: .authorized, snapshot: changed))
        do {
            try await provider.perform(.seek(42), target: .init(source: .spotify, trackID: old.track?.id))
            XCTFail("Expected a changed-track error")
        } catch { XCTAssertTrue(error is NowPlayingProviderError) }
        let commands = await provider.commands
        XCTAssertTrue(commands.isEmpty)
    }

    @MainActor func testCapabilityDisabledForUnknownDuration() async throws {
        let provider = NowPlayingFixtureProvider(source: .spotify, mode: "unknownDuration")
        let store = makeStore([provider]); defer { store.stop() }
        store.setEnabled(.spotify, enabled: true); store.setInterest(.panel, active: true)
        try await wait { store.snapshot != nil }
        XCTAssertFalse(store.canPerform(.seek(10)))
        XCTAssertTrue(store.canPerform(.volume(10)))
        XCTAssertNil(store.snapshot?.track?.duration)
    }

    func testArtworkFailureDoesNotRetryOnEveryPlaybackPoll() async {
        let provider = FailingArtworkProvider()
        let cache = NowPlayingArtworkCache()
        for _ in 0..<3 {
            let data = await cache.data(for: .musicTrack("same-track"), provider: provider)
            XCTAssertNil(data)
        }
        let reads = await provider.reads
        XCTAssertEqual(reads, 1)
    }

    @MainActor func testStaleSnapshotRejectsEveryPlaybackCommand() async throws {
        let provider = NowPlayingFixtureProvider(source: .spotify, mode: "stale")
        let store = makeStore([provider]); defer { store.stop() }
        store.setEnabled(.spotify, enabled: true); store.setInterest(.panel, active: true)
        try await wait { store.snapshot != nil }
        for command: NowPlayingCommand in [.play, .pause, .previous, .next, .seek(60), .volume(30)] {
            XCTAssertFalse(store.canPerform(command))
            store.perform(command)
        }
        let commands = await provider.commands
        XCTAssertTrue(commands.isEmpty)
    }

    @MainActor func testLateArtworkCannotReplaceNewTrackArtwork() async throws {
        let oldData = try XCTUnwrap(NSImage(named: "NowPlayingFixtureAlbum")?.tiffRepresentation)
        let newData = try XCTUnwrap(NSImage(named: "NowPlayingDisc")?.tiffRepresentation)
        let expectedNew = try XCTUnwrap(NowPlayingArtworkCache.thumbnail(newData))
        let provider = GatedArtworkProvider(oldData: oldData, newData: newData)
        let store = makeStore([provider])
        defer { store.stop(); Task { await provider.releaseOldArtwork() } }
        store.setEnabled(.appleMusic, enabled: true); store.setInterest(.panel, active: true)
        try await waitAsync { await provider.oldArtworkRequested }
        await provider.selectNewTrack()
        store.reload()
        try await wait { store.artworkData == expectedNew }
        await provider.releaseOldArtwork()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.snapshot?.track?.id, "new")
        XCTAssertEqual(store.artworkData, expectedNew)
    }

    @MainActor func testWorkspaceEventsRefreshActiveStoreButNotStoppedStore() async throws {
        let notifications = NotificationCenter()
        let provider = NowPlayingFixtureProvider(source: .spotify, mode: "paused")
        let store = NowPlayingStore(providers: [provider], defaults: freshDefaults(), workspaceNotifications: notifications)
        defer { store.stop() }
        store.setEnabled(.spotify, enabled: true); store.setInterest(.dock, active: true)
        try await wait { store.observation?.access == .authorized }
        await provider.setObservation(.init(access: .notRunning))
        notifications.post(name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        try await wait { store.observation?.access == .notRunning }
        await provider.setObservation(.init(access: .authorized, snapshot: NowPlayingFixtures.snapshot(state: .paused)))
        notifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await wait { store.observation?.access == .authorized }
        store.stop()
        let reads = await provider.reads
        notifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        let readsAfterStop = await provider.reads
        XCTAssertEqual(reads, readsAfterStop)
        XCTAssertFalse(store.isMonitoring)
    }

    @MainActor func testNativeRenderMatrix() async throws {
        let directory = URL(fileURLWithPath: "/private/tmp/dockmagic-nowplaying-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cases: [(String, String, DSAppearanceMode, DSAccessibilityOverrides)] = [
            ("dark", "playing", .dark, .init()), ("light", "playing", .light, .init()),
            ("contrast", "playing", .dark, .init(increaseContrast: true)),
            ("opaque", "playing", .light, .init(reduceTransparency: true, reduceMotion: true)),
            ("paused", "paused", .dark, .init()), ("no-artwork", "noArtwork", .dark, .init()),
            ("stale", "stale", .dark, .init()), ("loading", "loading", .dark, .init()),
            ("long-title", "longTitle", .dark, .init()), ("unknown-duration", "unknownDuration", .dark, .init()),
            ("denied", "denied", .dark, .init()), ("disconnected", "disconnected", .light, .init()),
            ("not-running", "notRunning", .dark, .init()), ("no-media", "noMedia", .dark, .init()),
            ("timeout", "unavailable", .dark, .init())
        ]
        for (name, mode, appearance, accessibility) in cases {
            let store = NowPlayingFixtures.store(mode: mode, defaults: freshDefaults())
            store.setInterest(.panel, active: true)
            if mode == "loading" { try await wait { store.isLoading } }
            else if mode != "disconnected" { try await wait { store.observations.count == 2 } }
            if mode == "playing" || mode == "paused" || mode == "longTitle" || mode == "unknownDuration" { try await wait { store.artworkData != nil } }
            let size = DockHoverPanelPlacement.nowPlayingPanelSize
            let view = DockMagicThemeRoot(content: DockHoverChrome(pointerEdge: .bottom, panelSize: size) {
                NowPlayingHoverDashboardView(store: store)
            }, appearanceMode: appearance).environment(\.dsAccessibilityOverrides, accessibility)
                .frame(width: size.width, height: size.height)
            try save(view, name: "dashboard-\(name)", directory: directory, size: size, appearance: appearance, contrast: accessibility.increaseContrast == true)
            if name == "dark" {
                try save(view.saturation(0), name: "dashboard-grayscale", directory: directory, size: size, appearance: appearance)
                let dockVariants: [(name: String, appearance: DSAppearanceMode, accessibility: DSAccessibilityOverrides)] = [
                    ("dark", .dark, .init()),
                    ("light", .light, .init()),
                    ("contrast", .dark, .init(increaseContrast: true)),
                    ("opaque", .light, .init(reduceTransparency: true))
                ]
                for points in [32, 48, 64, 128, 512] {
                    for variant in dockVariants {
                        let dock = DockMagicThemeRoot(content: DockTileView(presentation: .nowPlaying(store.dockPresentation), animatesChanges: false)
                            .frame(width: CGFloat(points), height: CGFloat(points)), appearanceMode: variant.appearance)
                            .environment(\.dsAccessibilityOverrides, variant.accessibility)
                        let suffix = variant.name == "dark" ? "" : "-\(variant.name)"
                        try save(dock, name: "dock-\(points)\(suffix)", directory: directory, size: CGSize(width: points, height: points),
                            appearance: variant.appearance, contrast: variant.accessibility.increaseContrast == true)
                    }
                    try save(DockMagicThemeRoot(content: DockTileView(presentation: .nowPlaying(store.dockPresentation), animatesChanges: false)
                        .frame(width: CGFloat(points), height: CGFloat(points)), appearanceMode: .dark)
                        .saturation(0), name: "dock-\(points)-grayscale", directory: directory, size: CGSize(width: points, height: points), appearance: .dark)
                }
            }
            store.stop()
        }
    }

    @MainActor private func save<V: View>(_ view: V, name: String, directory: URL, size: CGSize, appearance: DSAppearanceMode, contrast: Bool = false) throws {
        // ImageRenderer cannot capture NSMenu/NSSlider; capture the native host.
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.appearance = NSAppearance(named: contrast ? (appearance == .dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua) : (appearance == .dark ? .darkAqua : .aqua))
        host.appearance = window.appearance
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.wantsLayer = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = try XCTUnwrap(bitmap.cgImage, name)
        let url = directory.appendingPathComponent(name + ".png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let attachment = XCTAttachment(contentsOfFile: url); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func makeStore(_ providers: [any NowPlayingProviding]) -> NowPlayingStore { NowPlayingStore(providers: providers, defaults: freshDefaults()) }
    private func freshDefaults() -> UserDefaults {
        let name = "DockMagicNowPlayingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    @MainActor private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<150 { if condition() { return }; try await Task.sleep(for: .milliseconds(20)) }
        XCTFail("Timed out waiting for Now Playing state")
    }
    private func waitAsync(_ condition: () async -> Bool) async throws {
        for _ in 0..<150 { if await condition() { return }; try await Task.sleep(for: .milliseconds(20)) }
        XCTFail("Timed out waiting for provider state")
    }
}

private actor GatedArtworkProvider: NowPlayingProviding {
    nonisolated let source = NowPlayingSource.appleMusic
    private let oldData: Data
    private let newData: Data
    private var trackID = "old"
    private var oldArtwork: CheckedContinuation<Data?, Never>?
    private(set) var oldArtworkRequested = false
    init(oldData: Data, newData: Data) { self.oldData = oldData; self.newData = newData }
    func observe(requestPermission: Bool) async -> NowPlayingObservation {
        var snapshot = NowPlayingFixtures.snapshot(source: source, state: .paused)
        snapshot.track = .init(id: trackID, title: trackID, duration: 224, artwork: .musicTrack(trackID))
        return .init(access: .authorized, snapshot: snapshot)
    }
    func selectNewTrack() { trackID = "new" }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws {}
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? {
        if reference == .musicTrack("new") { return newData }
        // Deliberately ignores cancellation, like a response already in flight.
        return await withCheckedContinuation { oldArtworkRequested = true; oldArtwork = $0 }
    }
    func releaseOldArtwork() { oldArtwork?.resume(returning: oldData); oldArtwork = nil }
}

private actor GatedCommandProvider: NowPlayingProviding {
    nonisolated let source = NowPlayingSource.spotify
    private(set) var commands: [NowPlayingCommand] = []
    private(set) var commandStarted = false
    private var continuation: CheckedContinuation<Void, Never>?
    func observe(requestPermission: Bool) async -> NowPlayingObservation {
        .init(access: .authorized, snapshot: NowPlayingFixtures.snapshot(source: source))
    }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws {
        commands.append(command)
        commandStarted = true
        await withCheckedContinuation { continuation = $0 }
    }
    func finish() { continuation?.resume(); continuation = nil }
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? { nil }
}

private struct DelayedNowPlayingProvider: NowPlayingProviding {
    let source: NowPlayingSource
    func observe(requestPermission: Bool) async -> NowPlayingObservation {
        // Intentionally returns even after cancellation, like bounded synchronous IPC.
        try? await Task.sleep(for: .milliseconds(120))
        return .init(access: .authorized, snapshot: NowPlayingFixtures.snapshot(source: source))
    }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws {}
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? { nil }
}

private actor FailingArtworkProvider: NowPlayingProviding {
    nonisolated let source = NowPlayingSource.appleMusic
    private(set) var reads = 0
    func observe(requestPermission: Bool) async -> NowPlayingObservation { .init(access: .authorized) }
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws {}
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data? {
        reads += 1
        throw NowPlayingProviderError.unavailable
    }
}
