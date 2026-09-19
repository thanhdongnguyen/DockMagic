import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

final class BinanceFeatureTests: XCTestCase {
    @MainActor func testLegacyPreferencesAndAppearanceRoundTripPreserveMarketConfiguration() throws {
        let legacy = Data(#"{"watchlist":[{"symbol":"BTCUSDT","baseAsset":"BTC","quoteAsset":"USDT"},{"symbol":"ETHUSDT","baseAsset":"ETH","quoteAsset":"USDT"}],"pinnedSymbol":"ETHUSDT","chartType":"candlestick","timeRange":"7D","showsVolume":true,"preferredQuote":"USDC"}"#.utf8)
        let suite = "BinanceAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(legacy, forKey: DockPreferencesStore.binanceConfigurationKey)
        let prefs = DockPreferencesStore(defaults: defaults)
        let original = prefs.binanceConfiguration
        XCTAssertEqual(original.watchlist.map(\.id), ["BTCUSDT", "ETHUSDT"])
        XCTAssertEqual(original.selected?.id, "ETHUSDT")
        XCTAssertEqual(original.chartType, .candlestick)
        XCTAssertEqual(original.timeRange, .week)
        XCTAssertTrue(original.showsVolume)
        XCTAssertEqual(original.preferredQuote, "USDC")
        XCTAssertEqual(original.appearance, .standard)

        let store = BinanceMarketStore(configuration: original, provider: BinanceFixtureProvider(),
            stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil),
            persist: { prefs.binanceConfiguration = $0 })
        defer { store.stop() }
        let custom = BinanceAppearance(dockPriceColor: DockColor(red: 0.2, green: 0.4, blue: 0.6),
            priceSeriesColor: DockColor(red: 0.8, green: 0.2, blue: 0.4),
            volumeColor: DockColor(red: 0.4, green: 0.5, blue: 0.2))
        store.updateConfiguration { $0.appearance = custom }
        XCTAssertEqual(DockPreferencesStore(defaults: defaults).binanceConfiguration, store.configuration)
        XCTAssertEqual(store.dockSnapshot.priceColor, custom.dockPriceColor)
        XCTAssertEqual(store.dockSnapshot.price, "—")
        store.updateConfiguration { $0.appearance = .standard }
        XCTAssertEqual(DockPreferencesStore(defaults: defaults).binanceConfiguration, original)
        XCTAssertNil(store.dockSnapshot.priceColor)

        let partial = try JSONDecoder().decode(BinanceConfiguration.self, from: Data(#"{"appearance":{"volumeColor":{"red":0.1,"green":0.2,"blue":0.3,"alpha":1}}}"#.utf8))
        XCTAssertNil(partial.appearance.dockPriceColor)
        XCTAssertNil(partial.appearance.priceSeriesColor)
        XCTAssertEqual(partial.appearance.volumeColor?.hex, "#1A334D")
    }

    @MainActor func testAppearanceUpdatesDoNotReloadMarketOrInvalidateUnchangedDock() async throws {
        let provider = BinanceFixtureProvider(), stream = BinanceFixtureStream()
        let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: 3),
            provider: provider, stream: stream, cache: BinanceMarketCache(url: nil))
        defer { store.stop() }
        let id = UUID(); store.acquireDashboard(id)
        for item in store.configuration.watchlist { store.setVisible(item.id, dashboard: id, visible: true) }
        try await eventually { store.pairs.values.allSatisfy { $0.chartPhase == .ready && $0.ticker != nil } && store.pairs.count == 3 }
        try await Task.sleep(for: .milliseconds(450))
        let counts = await (provider.catalogCalls, provider.tickerCalls, provider.chartCalls, stream.subscriptionCalls)
        let snapshot = store.dockSnapshot
        let candles = store.pairs["ETHUSDT"]?.candles
        let custom = DockColor(red: 0.8, green: 0.2, blue: 0.4)
        store.updateConfiguration { $0.appearance.priceSeriesColor = custom; $0.appearance.volumeColor = custom }
        XCTAssertEqual(store.dockSnapshot, snapshot)
        store.updateConfiguration { $0.appearance.dockPriceColor = custom }
        XCTAssertEqual(store.dockSnapshot.price, snapshot.price)
        XCTAssertEqual(store.dockSnapshot.priceColor, custom)
        XCTAssertNotEqual(store.dockSnapshot, snapshot)
        try await Task.sleep(for: .milliseconds(500))
        let after = await (provider.catalogCalls, provider.tickerCalls, provider.chartCalls, stream.subscriptionCalls)
        XCTAssertEqual(after.0, counts.0); XCTAssertEqual(after.1, counts.1)
        XCTAssertEqual(after.2, counts.2); XCTAssertEqual(after.3, counts.3)
        XCTAssertEqual(store.pairs["ETHUSDT"]?.candles, candles)

        await provider.setFailure(.http(503)); store.refreshAfterInterruption()
        try await eventually { store.dockSnapshot.isStale }
        store.updateConfiguration { $0.appearance = .standard }
        XCTAssertTrue(store.dockSnapshot.isStale)
        XCTAssertEqual(store.dockSnapshot.price, snapshot.price)
        XCTAssertNil(store.dockSnapshot.priceColor)

        let empty = BinanceMarketStore(provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
        defer { empty.stop() }
        empty.updateConfiguration { $0.appearance.dockPriceColor = custom }
        XCTAssertEqual(empty.dockSnapshot.priceColor, custom)
        XCTAssertEqual(empty.dockSnapshot.price, "—")
    }

    @MainActor func testRendererColorsMeetContrastWithoutChangingSavedColor() {
        let theme = ProjectTheme.current
        let saved = BinanceAppearance(dockPriceColor: DockColor(red: 1, green: 1, blue: 1),
            priceSeriesColor: DockColor(red: 0, green: 0, blue: 0, alpha: 0.05),
            volumeColor: DockColor(red: 0.95, green: 0.95, blue: 0.95))
        for scheme in [ColorScheme.light, .dark] {
            let background = ProjectTheme.resolvedColor(theme.opaqueSurfaceRaised, colorScheme: scheme)
            for (custom, automatic, minimum) in [(saved.dockPriceColor, theme.textPrimary, 4.5),
                (saved.priceSeriesColor, theme.marketPriceSeries, 3.0), (saved.volumeColor, theme.textTertiary, 3.0)] {
                for choice in [custom, nil] {
                    let rendered = DockColor(ProjectTheme.rendererColor(choice, automatic: automatic,
                        on: theme.opaqueSurfaceRaised, colorScheme: scheme, minimumContrast: minimum))
                    XCTAssertGreaterThanOrEqual(ProjectTheme.rendererContrast(rendered, background), minimum - 0.001)
                }
            }
        }
        XCTAssertEqual(saved.priceSeriesColor?.alpha, 0.05)
        XCTAssertEqual(saved.dockPriceColor?.hex, "#FFFFFF")
    }

    func testConfigurationSelectionOrderingAndNormalization() throws {
        var value = BinanceFixtureProvider.configuration(count: 3)
        XCTAssertEqual(value.selected?.id, "ETHUSDT")
        XCTAssertEqual(value.displayOrder.map(\.id), ["ETHUSDT", "BTCUSDT", "SOLUSDT"])
        XCTAssertEqual(value.watchlist.first?.id, "BTCUSDT")
        value.pinnedSymbol = nil
        XCTAssertEqual(value.selected?.id, "BTCUSDT")
        value.pinnedSymbol = "ETHUSDT"
        value.watchlist.removeAll { $0.id == "ETHUSDT" }
        value.watchlist += value.watchlist
        value.normalize()
        XCTAssertNil(value.pinnedSymbol)
        XCTAssertEqual(value.watchlist.count, 2)
        XCTAssertEqual(try JSONDecoder().decode(BinanceConfiguration.self, from: JSONEncoder().encode(value)), value)
    }

    func testDecimalFormattingAndRangeContract() {
        XCTAssertEqual(BinancePriceFormat.price(Decimal(string: "0.000000012345")!), "0.000000012345")
        XCTAssertNotEqual(BinancePriceFormat.price(Decimal(string: "0.000000012345")!, compact: true), "0")
        XCTAssertEqual(BinancePriceFormat.price(Decimal(string: "2402.41")!, compact: true), "2.4K")
        XCTAssertEqual(BinanceTimeRange.allCases.map(\.limit), [61, 289, 169, 181, 366])
        XCTAssertEqual(BinanceTimeRange.allCases.map(\.interval), ["1m", "5m", "1h", "4h", "1d"])
    }

    func testSearchUsesPairsAndPreferredQuote() {
        let symbol = BinanceSymbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT")
        XCTAssertTrue(symbol.matches("btc / usdt"))
        XCTAssertTrue(symbol.matches("USDT"))
        XCTAssertFalse(symbol.matches("Bitcoin"))
    }

    func testRESTAndStreamParsersValidateOHLCAndPreserveDecimals() throws {
        let data = Data("[[1000,\"0.00000001\",\"0.00000003\",\"0.00000001\",\"0.00000002\",\"100\",1999]]".utf8)
        let candles = try BinanceMarketParser.candles(data, now: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(candles.first?.close, Decimal(string: "0.00000002"))
        XCTAssertTrue(try XCTUnwrap(candles.first).isClosed)
        let malformed = Data("[[1000,\"4\",\"3\",\"1\",\"2\",\"100\",1999]]".utf8)
        XCTAssertThrowsError(try BinanceMarketParser.candles(malformed))
        let stream = Data(#"{"stream":"ethusdt@kline_5m","data":{"e":"kline","E":2000,"s":"ETHUSDT","k":{"t":1000,"T":1999,"i":"5m","o":"1","h":"3","l":"1","c":"2","v":"42","x":true}}}"#.utf8)
        guard case .candle(let symbol, let interval, let candle) = try BinanceMarketParser.stream(stream) else { return XCTFail("Missing candle") }
        XCTAssertEqual(symbol, "ETHUSDT"); XCTAssertEqual(interval, "5m"); XCTAssertTrue(candle.isClosed)
        XCTAssertNil(try BinanceMarketParser.stream(Data(#"{"result":null,"id":1}"#.utf8)))
        XCTAssertThrowsError(try BinanceMarketParser.stream(Data(#"{"e":"serverShutdown"}"#.utf8)))
    }

    func testCandleMergeCannotReopenOrReplaceNewerData() {
        let date = Date(timeIntervalSince1970: 1_000)
        func candle(_ price: Int, _ event: Double, closed: Bool) -> BinanceCandle {
            .init(openTime: date, closeTime: date.addingTimeInterval(60), open: 10, high: 30, low: 1, close: Decimal(price), volume: 100,
                isClosed: closed, eventTime: date.addingTimeInterval(event))
        }
        let open = candle(12, 20, closed: false)
        let older = candle(11, 10, closed: false)
        XCTAssertEqual(BinanceCandle.merge([open], [older], limit: 5), [open])
        let closed = candle(13, 60, closed: true)
        XCTAssertEqual(BinanceCandle.merge([closed], [open, older], limit: 5), [closed])
        XCTAssertEqual(BinanceCandle.merge([open], [closed, closed], limit: 5), [closed])
    }

    @MainActor func testStorePinAddRemoveSearchAndPersistence() async throws {
        let suite = "BinanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        let store = BinanceMarketStore(provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil),
            persist: { preferences.binanceConfiguration = $0 })
        let id = UUID(); store.acquireDashboard(id)
        defer { store.stop() }
        try await eventually { !store.catalog.isEmpty }
        let btc = try XCTUnwrap(store.catalog.first { $0.id == "BTCUSDT" })
        let eth = try XCTUnwrap(store.catalog.first { $0.id == "ETHUSDT" })
        XCTAssertTrue(store.add(btc)); XCTAssertFalse(store.add(btc)); XCTAssertTrue(store.add(eth))
        try await eventually { store.pairs[eth.id]?.ticker != nil }
        store.pin(eth.id)
        XCTAssertEqual(store.dockSnapshot.base, "ETH")
        XCTAssertEqual(store.configuration.watchlist.first, btc)
        _ = store.search("BTC", tracked: true)
        XCTAssertEqual(store.selectedSymbol, eth)
        XCTAssertEqual(DockPreferencesStore(defaults: defaults).binanceConfiguration.pinnedSymbol, eth.id)
        store.remove(eth.id)
        XCTAssertEqual(store.dockSnapshot.base, "BTC"); XCTAssertNil(store.configuration.pinnedSymbol)
        store.remove(btc.id)
        XCTAssertEqual(store.dockSnapshot.price, "—")
    }

    @MainActor func testMovingPinnedPairKeepsSelectionAndQuoteIdentity() async throws {
        let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: 2), provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
        let id = UUID(); store.acquireDashboard(id)
        defer { store.stop() }
        try await eventually { !store.catalog.isEmpty }
        let usdc = try XCTUnwrap(store.catalog.first { $0.id == "BTCUSDC" })
        XCTAssertTrue(store.add(usdc))
        store.move("ETHUSDT", by: -1)
        XCTAssertEqual(store.configuration.watchlist.map(\.id), ["ETHUSDT", "BTCUSDT", "BTCUSDC"])
        XCTAssertEqual(store.selectedSymbol?.id, "ETHUSDT")
        store.pin("BTCUSDC")
        XCTAssertEqual(store.dockSnapshot.quote, "USDC")
        store.pin("BTCUSDC")
        XCTAssertEqual(store.selectedSymbol?.id, "ETHUSDT")
        XCTAssertEqual(store.dockSnapshot.quote, "USDT")
    }

    @MainActor func testDemandUsesOneFeedAndReleasesInvisibleCharts() async throws {
        let stream = BinanceFixtureStream()
        let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: 3), provider: BinanceFixtureProvider(), stream: stream, cache: BinanceMarketCache(url: nil))
        defer { store.stop() }
        store.setSelected(true)
        try await Task.sleep(for: .milliseconds(450))
        var subscribed = await stream.subscriptions
        XCTAssertEqual(subscribed, ["ethusdt@ticker"])
        let id = UUID()
        // SwiftUI children may appear before the parent's onAppear.
        store.setVisible("BTCUSDT", dashboard: id, visible: true)
        store.acquireDashboard(id)
        try await Task.sleep(for: .milliseconds(450))
        subscribed = await stream.subscriptions
        XCTAssertTrue(subscribed.contains("btcusdt@kline_5m"))
        XCTAssertTrue(subscribed.contains("ethusdt@kline_5m"))
        XCTAssertFalse(subscribed.contains("solusdt@kline_5m"))
        store.releaseDashboard(id)
        try await Task.sleep(for: .milliseconds(450))
        subscribed = await stream.subscriptions
        XCTAssertEqual(subscribed, ["ethusdt@ticker"])
        store.setSelected(false)
        try await Task.sleep(for: .milliseconds(450))
        subscribed = await stream.subscriptions
        XCTAssertTrue(subscribed.isEmpty)
    }

    @MainActor func testLateRangeResponseAndNetworkFailurePreserveSelectedPair() async throws {
        let provider = BinanceFixtureProvider()
        await provider.setDelay(.day, .milliseconds(700))
        let stream = BinanceFixtureStream()
        let store = BinanceMarketStore(configuration: BinanceFixtureProvider.configuration(count: 2), provider: provider, stream: stream, cache: BinanceMarketCache(url: nil))
        let id = UUID(); store.acquireDashboard(id)
        defer { store.stop() }
        try await Task.sleep(for: .milliseconds(400))
        store.updateConfiguration { $0.timeRange = .hour }
        try await eventually { store.pairs["ETHUSDT"]?.chartPhase == .ready && store.pairs["ETHUSDT"]?.ticker != nil }
        XCTAssertEqual(store.pairs["ETHUSDT"]?.candles.count, 61)
        let price = store.dockSnapshot.price
        await provider.setFailure(.http(503))
        await stream.send(.connection(.reconnecting))
        store.refreshAfterInterruption()
        try await eventually { store.pairs["ETHUSDT"]?.quotePhase == .stale }
        XCTAssertEqual(store.selectedSymbol?.id, "ETHUSDT")
        XCTAssertEqual(store.dockSnapshot.price, price)
        XCTAssertFalse(store.pairs["ETHUSDT"]?.quotePhase == .unavailable)
    }

    func testRetryAfterSupportsSecondsAndHTTPDate() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(BinanceMarketDataClient.retryDate("120", now: now), now.addingTimeInterval(120))
        XCTAssertGreaterThan(BinanceMarketDataClient.retryDate("Wed, 16 Sep 2026 12:00:00 GMT", now: now), now)
    }

    func testHTTPRateLimitCooldownAndErrorClassification() async throws {
        for status in [429, 418, 403, 451, 400] {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [BinanceHTTPFixture.self]
            let session = URLSession(configuration: configuration)
            let client = BinanceMarketDataClient(session: session, baseURL: URL(string: "https://fixture-\(status).invalid")!)
            let before = BinanceHTTPFixture.requestCount
            do { _ = try await client.symbols(); XCTFail("Expected HTTP error") }
            catch let error as BinanceAPIError {
                if status == 429 || status == 418 {
                    guard case .rateLimited(let until) = error else { return XCTFail("Expected Retry-After") }
                    XCTAssertGreaterThan(until.timeIntervalSinceNow, 100)
                    do { _ = try await client.symbols(); XCTFail("Expected cooldown") } catch {}
                    XCTAssertEqual(BinanceHTTPFixture.requestCount, before + 1, "Cooldown must not issue a second HTTP request")
                } else if status == 400 { XCTAssertEqual(error, .invalidSymbol) }
                else { XCTAssertEqual(error, .restricted) }
            }
            session.invalidateAndCancel()
        }
    }

    @MainActor func testHoverDelayKeyboardOptInAndCloseReleaseDemand() async throws {
        let suite = "BinanceHoverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = DockPreferencesStore(defaults: defaults)
        prefs.activeFeature = .binance; prefs.isDockHoverDashboardEnabled = true; prefs.automaticallyConfigureClaudeCode = false
        let store = BinanceMarketStore(provider: BinanceFixtureProvider(), stream: BinanceFixtureStream(), cache: BinanceMarketCache(url: nil))
        let model = DockAppModel(preferences: prefs, binanceStore: store,
            streakStore: TokenUsageStreakStore(modelContainer: TokenUsageStreakStore.inMemoryContainer()))
        let controller = DockHoverPanelController()
        let screen = try XCTUnwrap(NSScreen.main)
        let anchor = DockHoverAnchor(iconFrame: CGRect(x: screen.frame.midX, y: screen.frame.minY, width: 64, height: 64), screen: screen, pointerEdge: .bottom)
        defer { controller.hide(); store.stop() }
        let began = ContinuousClock.now
        controller.scheduleShow(anchor: anchor, appModel: model)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(controller.isVisible)
        controller.scheduleShow(anchor: anchor, appModel: model)
        try await eventually { controller.isVisible }
        XCTAssertGreaterThanOrEqual(began.duration(to: .now), .seconds(1))
        XCTAssertFalse(controller.isInteracting)
        controller.setBinanceInteraction(true)
        controller.scheduleHide()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(controller.isVisible); XCTAssertTrue(controller.isInteracting)
        controller.hide()
        try await eventually { !store.hasDashboard }
        XCTAssertFalse(controller.isInteracting)
    }

    @MainActor private func eventually(_ predicate: () -> Bool) async throws {
        for _ in 0..<80 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("State did not settle within 4 seconds")
    }
}

private final class BinanceHTTPFixture: URLProtocol {
    private static let lock = NSLock()
    private static var count = 0
    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return count }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.count += 1; Self.lock.unlock()
        let status = Int(request.url!.host!.split(separator: "-")[1].split(separator: ".")[0])!
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Retry-After": "120"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"code":-1121,"msg":"Invalid symbol."}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
