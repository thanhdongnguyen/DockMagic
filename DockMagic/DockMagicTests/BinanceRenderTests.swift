import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

final class BinanceRenderTests: XCTestCase {
    @MainActor func testAppearanceSettingsAndSharedButtonsRenderMatrix() async throws {
        let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: 3), provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
        let id = UUID(); store.acquireDashboard(id)
        for item in store.configuration.watchlist { store.setVisible(item.id, dashboard: id, visible: true) }
        defer { store.stop() }
        for _ in 0..<60 {
            if store.pairs.count == 3 && store.pairs.values.allSatisfy({ $0.chartPhase == .ready && $0.ticker != nil }) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(store.pairs["ETHUSDT"]?.chartPhase, .ready)
        XCTAssertNotNil(store.pairs["ETHUSDT"]?.ticker)
        let folder = captureFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for mode in [DSAppearanceMode.light, .dark] {
            store.updateConfiguration { $0.appearance = .standard }
            let settings = BinanceSettingsView(store: store, isActive: true).padding(24)
                .frame(width: 800, height: 1450, alignment: .top).background(ProjectTheme.current.opaqueSurface)
            try render(settings, mode: mode, size: CGSize(width: 800, height: 1450))
                .write(to: folder.appendingPathComponent("settings-automatic-\(mode.rawValue).png"))
            store.updateConfiguration {
                $0.appearance = BinanceAppearance(dockPriceColor: DockColor(red: 0.796, green: 0.188, blue: 0.878),
                    priceSeriesColor: DockColor(red: 0, green: 0.753, blue: 0.91), volumeColor: DockColor(red: 1, green: 0.553, blue: 0.157))
                $0.showsVolume = true; $0.chartType = .candlestick
            }
            try render(settings, mode: mode, size: CGSize(width: 800, height: 1450), enhanced: true)
                .write(to: folder.appendingPathComponent("settings-custom-\(mode.rawValue)-contrast.png"))
            try render(settings, mode: mode, size: CGSize(width: 800, height: 1450), enhanced: true, grayscale: true)
                .write(to: folder.appendingPathComponent("settings-custom-\(mode.rawValue)-grayscale.png"))
            let dashboard = BinanceDashboardView(store: store).padding(20).frame(width: 620, height: 740)
                .background(ProjectTheme.current.opaqueSurface)
            for grayscale in [false, true] {
                try render(dashboard, mode: mode, size: CGSize(width: 620, height: 740), enhanced: true, grayscale: grayscale)
                    .write(to: folder.appendingPathComponent("dashboard-custom-\(mode.rawValue)\(grayscale ? "-grayscale" : "-contrast").png"))
            }
            for size in [32.0, 48, 64, 128] {
                let icon = DockTileView(presentation: .binance(snapshot: store.dockSnapshot), animatesChanges: false).frame(width: size, height: size)
                try render(icon, mode: mode, size: CGSize(width: size, height: size), enhanced: true)
                    .write(to: folder.appendingPathComponent("dock-custom-\(mode.rawValue)-\(Int(size)).png"))
            }
            try render(DockTileView(presentation: .binance(snapshot: store.dockSnapshot), animatesChanges: false),
                mode: mode, size: CGSize(width: 128, height: 128), enhanced: true, grayscale: true)
                .write(to: folder.appendingPathComponent("dock-custom-\(mode.rawValue)-grayscale.png"))
            let buttons = VStack(spacing: 24) {
                Text("Settings · SF Pro").font(DSTypography.panelTitle)
                HStack {
                    Button("Primary") {}.buttonStyle(DSButtonStyle(emphasis: .primary))
                    Button("Neutral") {}.buttonStyle(DSButtonStyle())
                    Button("Destructive") {}.buttonStyle(DSButtonStyle(emphasis: .primary, intent: .destructive))
                }
                Text("Dashboard · SF Pro Rounded").font(DSTypography.Dashboard.panelTitle)
                HStack {
                    Button("Add coin") {}.buttonStyle(DSButtonStyle(emphasis: .primary, surface: .dashboard))
                    Button("Retry") {}.buttonStyle(DSButtonStyle(surface: .dashboard))
                    Button("Remove") {}.buttonStyle(DSButtonStyle(emphasis: .primary, intent: .destructive, surface: .dashboard))
                }
                HStack {
                    Button("Primary disabled") {}.buttonStyle(DSButtonStyle(emphasis: .primary)).disabled(true)
                    Button("Neutral disabled") {}.buttonStyle(DSButtonStyle()).disabled(true)
                    Button("Destructive disabled") {}.buttonStyle(DSButtonStyle(emphasis: .primary, intent: .destructive)).disabled(true)
                }
            }.padding(24).frame(width: 640, height: 300).background(ProjectTheme.current.opaqueSurface)
                .environment(\.dsAccessibilityOverrides, DSAccessibilityOverrides(reduceTransparency: true, increaseContrast: true, reduceMotion: true))
            try render(buttons, mode: mode, size: CGSize(width: 640, height: 300), enhanced: true)
                .write(to: folder.appendingPathComponent("shared-buttons-\(mode.rawValue)-reduce-motion.png"))
        }
    }

    private var captureFolder: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["BINANCE_CAPTURE_DIR"] ?? "/tmp/binance-captures")
    }

    @MainActor func testDashboardAndDockRenderMatrix() async throws {
        let configuration = BinanceFixtureProvider.configuration(count: 3)
        let store = BinanceMarketStore(configuration: configuration, provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
        let id = UUID()
        store.acquireDashboard(id)
        for symbol in configuration.watchlist { store.setVisible(symbol.id, dashboard: id, visible: true) }
        defer { store.stop() }
        for _ in 0..<60 {
            if configuration.watchlist.allSatisfy({ store.pairs[$0.id]?.ticker != nil && store.pairs[$0.id]?.chartPhase == .ready }) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(store.pairs["ETHUSDT"]?.candles.count, 289)
        let destination: URL? = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BINANCE_CAPTURE_DIR"] ?? "/tmp/binance-captures")
        if let destination { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
        for mode in [DSAppearanceMode.light, .dark] {
            for enhanced in [false, true] {
                let content = BinanceDashboardView(store: store).padding(20)
                    .frame(width: 620, height: 740).background(ProjectTheme.current.opaqueSurface)
                let image = try render(content, mode: mode, size: CGSize(width: 620, height: 740), enhanced: enhanced)
                XCTAssertGreaterThan(image.count, 10_000)
                if let destination { try image.write(to: destination.appendingPathComponent("dashboard-\(mode.rawValue)\(enhanced ? "-contrast" : "").png")) }
            }
            for size in [32.0, 48, 64, 128] {
                let icon = DockTileView(presentation: .binance(snapshot: store.dockSnapshot), animatesChanges: false)
                    .frame(width: size, height: size)
                let image = try render(icon, mode: mode, size: CGSize(width: size, height: size))
                XCTAssertGreaterThan(image.count, 300)
                if let destination { try image.write(to: destination.appendingPathComponent("dock-\(mode.rawValue)-\(Int(size)).png")) }
            }
        }
        store.updateConfiguration { $0.chartType = .candlestick; $0.showsVolume = true; $0.timeRange = .week }
        try await Task.sleep(for: .milliseconds(500))
        let candle = try render(BinanceDashboardView(store: store).padding(20).frame(width: 620, height: 740).background(ProjectTheme.current.opaqueSurface), mode: .dark, size: CGSize(width: 620, height: 740))
        if let destination { try candle.write(to: destination.appendingPathComponent("dashboard-candlestick-volume.png")) }
    }

    @MainActor func testCountsLoadingErrorStaleAndSmallScreen() async throws {
        let folder = captureFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for count in [0, 1, 2, 20] {
            let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: count), provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
            let id = UUID(); store.acquireDashboard(id)
            for symbol in store.configuration.watchlist.prefix(3) { store.setVisible(symbol.id, dashboard: id, visible: true) }
            try await Task.sleep(for: .milliseconds(1500))
            let data = try render(BinanceDashboardView(store: store).padding(20).frame(width: 620, height: 580).background(ProjectTheme.current.opaqueSurface), mode: .light, size: CGSize(width: 620, height: 580))
            try data.write(to: folder.appendingPathComponent("dashboard-\(count)-pairs-small-screen.png"))
            store.stop()
        }
        let provider = BinanceFixtureProvider()
        let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: 3), provider: provider, stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
        defer { store.stop() }
        let content = BinanceDashboardView(store: store).padding(20).frame(width: 620, height: 740).background(ProjectTheme.current.opaqueSurface)
        try render(content, mode: .dark, size: CGSize(width: 620, height: 740)).write(to: folder.appendingPathComponent("dashboard-loading.png"))
        await provider.setFailure(.http(503))
        let id = UUID(); store.acquireDashboard(id)
        for symbol in store.configuration.watchlist { store.setVisible(symbol.id, dashboard: id, visible: true) }
        try await Task.sleep(for: .milliseconds(600))
        try render(content, mode: .dark, size: CGSize(width: 620, height: 740)).write(to: folder.appendingPathComponent("dashboard-error.png"))
        await provider.setFailure(nil); store.retry()
        try await Task.sleep(for: .milliseconds(1600))
        XCTAssertNotNil(store.pairs["ETHUSDT"]?.ticker)
        await provider.setFailure(.http(503)); store.refreshAfterInterruption()
        try await Task.sleep(for: .milliseconds(1300))
        XCTAssertTrue(store.dockSnapshot.isStale)
        try render(content, mode: .dark, size: CGSize(width: 620, height: 740)).write(to: folder.appendingPathComponent("dashboard-stale.png"))
        try render(DockTileView(presentation: .binance(snapshot: store.dockSnapshot), animatesChanges: false), mode: .dark, size: CGSize(width: 128, height: 128)).write(to: folder.appendingPathComponent("dock-stale.png"))
    }

    /// Explicit local QA only; normal and CI runs remain deterministic/offline.
    @MainActor func testOptInLiveMarketPanelAndInstalledDockCapture() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/dockmagic-binance-enable-live-qa") else { throw XCTSkip("Live Binance QA is opt-in") }
        let folder = captureFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let config = BinanceFixtureProvider.configuration(count: 3)
        let store = BinanceMarketStore(configuration: config, cache: BinanceMarketCache(url: nil))
        let id = UUID(); store.acquireDashboard(id)
        for item in config.watchlist { store.setVisible(item.id, dashboard: id, visible: true) }
        defer { store.stop() }
        for _ in 0..<300 {
            if config.watchlist.allSatisfy({ store.pairs[$0.id]?.ticker != nil && store.pairs[$0.id]?.chartPhase == .ready }) && store.connection == .live { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(store.connection, .live)
        for item in config.watchlist { XCTAssertNotNil(store.pairs[item.id]?.ticker); XCTAssertEqual(store.pairs[item.id]?.chartPhase, .ready) }
        let suite = "BinanceLiveQA.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = DockPreferencesStore(defaults: defaults)
        prefs.activeFeature = .binance; prefs.isDockHoverDashboardEnabled = true; prefs.automaticallyConfigureClaudeCode = false
        let model = DockAppModel(preferences: prefs, binanceStore: store,
            streakStore: TokenUsageStreakStore(modelContainer: TokenUsageStreakStore.inMemoryContainer()))
        let controller = DockHoverPanelController()
        let screen = try XCTUnwrap(NSScreen.main)
        controller.scheduleShow(anchor: DockHoverAnchor(iconFrame: CGRect(x: screen.frame.midX, y: screen.frame.minY, width: 64, height: 64), screen: screen, pointerEdge: .bottom), appModel: model)
        defer { controller.hide() }
        try await Task.sleep(for: .milliseconds(1400))
        let panel = try XCTUnwrap(NSApp.windows.first { String(describing: type(of: $0)) == "DockHoverPanel" && $0.isVisible })
        let content = try XCTUnwrap(panel.contentView)
        content.layoutSubtreeIfNeeded(); content.displayIfNeeded()
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("live-hover-panel.png"))
        let oldIcon = NSApp.applicationIconImage
        defer { NSApp.applicationIconImage = oldIcon }
        let iconController = DockTileController(initialPresentation: .binance(snapshot: store.dockSnapshot))
        let installed = try XCTUnwrap(NSApp.applicationIconImage)
        XCTAssertTrue(DockIconRenderingRules.satisfiesInstalledContract(installed, backingScale: screen.backingScaleFactor))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(installed.tiffRepresentation)))
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("live-installed-dock.png"))
        _ = iconController
        let evidence: [String: Any] = ["recordedAt": ISO8601DateFormatter().string(from: Date()), "source": "live Binance REST and WebSocket", "connection": store.connection.label,
            "pairs": config.watchlist.map { ["symbol": $0.id, "quote": $0.quoteAsset, "price": store.pairs[$0.id]?.ticker.map { BinancePriceFormat.price($0.price) } ?? "—", "candles": String(store.pairs[$0.id]?.candles.count ?? 0)] },
            "panelWidth": panel.frame.width, "panelHeight": panel.frame.height, "dockTileWidth": NSApp.dockTile.size.width, "installedPixels": DockIconRenderingRules.maximumPixelDimension(of: installed)]
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("live-appkit-evidence.json"))
    }

    @MainActor private func render<V: View>(_ content: V, mode: DSAppearanceMode, size: CGSize, enhanced: Bool = false, grayscale: Bool = false) throws -> Data {
        let host = NSHostingView(rootView: DockMagicThemeRoot(content: content, appearanceMode: mode)
            .environment(\.dsAccessibilityOverrides, DSAccessibilityOverrides(reduceTransparency: enhanced, increaseContrast: enhanced)))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        host.appearance = NSAppearance(named: enhanced ? (mode == .dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua) : (mode == .dark ? .darkAqua : .aqua))
        window.appearance = host.appearance
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.wantsLayer = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if grayscale {
            // NSHostingView bitmap capture does not include the GPU saturation
            // modifier. Convert the completed native raster for grayscale QA.
            let cgImage = try XCTUnwrap(bitmap.cgImage)
            let context = try XCTUnwrap(CGContext(data: nil, width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            let grayscaleImage = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
            return try XCTUnwrap(grayscaleImage.representation(using: .png, properties: [:]))
        }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
