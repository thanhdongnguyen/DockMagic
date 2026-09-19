import Foundation
import Observation

@MainActor
@Observable
final class BinanceMarketStore {
    private(set) var configuration: BinanceConfiguration
    private(set) var catalog: [BinanceSymbol] = []
    private(set) var catalogIsLoading = false
    private(set) var catalogError: String?
    private(set) var pairs: [String: BinancePairState] = [:]
    private(set) var connection: BinanceConnectionState = .stopped
    private(set) var dockSnapshot = BinanceDockSnapshot()
    private(set) var lastUpdated: Date?
    private(set) var actionMessage: String?

    @ObservationIgnored private let provider: any BinanceMarketDataProviding
    @ObservationIgnored private let stream: any BinanceMarketStreaming
    @ObservationIgnored private let cache: BinanceMarketCache
    @ObservationIgnored private let persist: (BinanceConfiguration) -> Void
    @ObservationIgnored private var selected = false
    @ObservationIgnored private var dashboards: [UUID: Set<String>] = [:]
    @ObservationIgnored private var previews: Set<UUID> = []
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var reconcileTask: Task<Void, Never>?
    @ObservationIgnored private var catalogTask: Task<Void, Never>?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private var chartTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var chartGenerations: [String: UUID] = [:]
    @ObservationIgnored private var cacheTask: Task<Void, Never>?
    @ObservationIgnored private var cacheLoaded = false
    @ObservationIgnored private var catalogFetchedAt: Date?
    @ObservationIgnored private var pendingTickers: [String: BinanceTicker] = [:]
    @ObservationIgnored private var pendingCandles: [String: [BinanceCandle]] = [:]
    @ObservationIgnored private var lastPoll = Date.distantPast
    @ObservationIgnored private var tickerDemand: Set<String> = []
    @ObservationIgnored private var networkBlocked = false
    @ObservationIgnored private var catalogRetryAt = Date.distantPast
    @ObservationIgnored private var chartRetryAt: [String: Date] = [:]

    init(configuration: BinanceConfiguration = .init(),
         provider: any BinanceMarketDataProviding = BinanceMarketDataClient(),
         stream: any BinanceMarketStreaming = BinanceMarketStreamClient(),
         cache: BinanceMarketCache = BinanceMarketCache(),
         persist: @escaping (BinanceConfiguration) -> Void = { _ in }) {
        var configuration = configuration
        configuration.normalize()
        self.configuration = configuration
        self.provider = provider
        self.stream = stream
        self.cache = cache
        self.persist = persist
        updateDock()
    }

    var selectedSymbol: BinanceSymbol? { configuration.selected }
    var hasDashboard: Bool { !dashboards.isEmpty }
    var hasDemand: Bool { hasDashboard || !previews.isEmpty || (selected && selectedSymbol != nil) }
    var quoteAssets: [String] { Array(Set(catalog.map(\.quoteAsset)).union([configuration.preferredQuote])).sorted() }

    func setSelected(_ value: Bool) { selected = value; scheduleReconcile() }
    func acquireDashboard(_ id: UUID) {
        if dashboards[id] == nil { dashboards[id] = [] }
        scheduleReconcile()
    }
    func releaseDashboard(_ id: UUID) { dashboards[id] = nil; scheduleReconcile() }
    func setPreview(_ id: UUID, visible: Bool) {
        if visible { previews.insert(id) } else { previews.remove(id) }
        scheduleReconcile()
    }
    func setVisible(_ symbol: String, dashboard: UUID, visible: Bool) {
        if visible { dashboards[dashboard, default: []].insert(symbol) } else { dashboards[dashboard]?.remove(symbol) }
        scheduleReconcile()
    }
    func updateConfiguration(_ mutate: (inout BinanceConfiguration) -> Void) {
        let previous = configuration
        let oldRange = configuration.timeRange
        mutate(&configuration)
        configuration.normalize()
        persist(configuration)
        // Appearance changes do not alter data demand, candle generations or
        // the market cache. Only the Dock price color belongs in its snapshot.
        var dataConfiguration = configuration
        dataConfiguration.appearance = previous.appearance
        if dataConfiguration == previous {
            updateDock()
            return
        }
        let retained = Set(configuration.watchlist.map(\.symbol))
        pairs = pairs.filter { retained.contains($0.key) }
        if oldRange != configuration.timeRange {
            for task in chartTasks.values { task.cancel() }
            chartTasks = [:]
            chartGenerations = [:]
            pendingCandles = [:]
            for key in pairs.keys {
                pairs[key]?.candles = []
                pairs[key]?.chartPhase = .loading
                pairs[key]?.chartRange = configuration.timeRange
            }
        }
        updateDock()
        scheduleReconcile()
        scheduleCache()
    }
    @discardableResult
    func add(_ symbol: BinanceSymbol) -> Bool {
        guard !configuration.watchlist.contains(where: { $0.id == symbol.id }) else { return false }
        guard configuration.watchlist.count < BinanceConfiguration.maximumPairs else {
            actionMessage = "You can follow up to 20 pairs. Remove a pair to add another."
            return false
        }
        guard catalog.contains(symbol) else { actionMessage = "This pair is not available in the current catalog."; return false }
        actionMessage = nil
        updateConfiguration { $0.watchlist.append(symbol) }
        return true
    }
    func pin(_ symbol: String) {
        updateConfiguration { $0.pinnedSymbol = $0.pinnedSymbol == symbol ? nil : symbol }
    }
    func remove(_ symbol: String) { updateConfiguration { $0.watchlist.removeAll { $0.symbol == symbol } } }
    func move(_ symbol: String, by offset: Int) {
        guard let index = configuration.watchlist.firstIndex(where: { $0.id == symbol }),
              configuration.watchlist.indices.contains(index + offset) else { return }
        updateConfiguration { $0.watchlist.swapAt(index, index + offset) }
    }
    func search(_ query: String, tracked: Bool) -> [BinanceSymbol] {
        let watched = Set(configuration.watchlist.map(\.id))
        let source = tracked ? configuration.watchlist : catalog.filter { !watched.contains($0.id) }
        return Array(source.filter { $0.matches(query) }.sorted {
            if ($0.quoteAsset == configuration.preferredQuote) != ($1.quoteAsset == configuration.preferredQuote) {
                return $0.quoteAsset == configuration.preferredQuote
            }
            return $0.symbol < $1.symbol
        }.prefix(30))
    }
    func retry() {
        networkBlocked = false
        catalogFetchedAt = nil
        catalogRetryAt = .distantPast
        chartRetryAt = [:]
        refreshAfterInterruption()
    }
    func refreshAfterInterruption() {
        guard hasDemand else { return }
        lastPoll = .distantPast
        for task in chartTasks.values { task.cancel() }
        chartTasks = [:]
        chartGenerations = [:]
        for key in pairs.keys where pairs[key]?.chartPhase == .ready { pairs[key]?.chartPhase = .stale }
        scheduleReconcile()
    }
    func stop() {
        selected = false
        dashboards = [:]
        previews = []
        reconcileTask?.cancel()
        stopNetworking()
    }

    private var wantedTickers: Set<String> {
        if hasDashboard { return Set(configuration.watchlist.map(\.symbol)) }
        return (selected || !previews.isEmpty) ? Set([selectedSymbol?.symbol].compactMap { $0 }) : []
    }
    private var wantedCharts: Set<String> {
        var result = dashboards.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        if hasDashboard, let hero = selectedSymbol { result.insert(hero.symbol) }
        return result.intersection(Set(configuration.watchlist.map(\.symbol)))
    }
    private func scheduleReconcile() {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            await self?.reconcile()
        }
    }
    private func reconcile() async {
        guard hasDemand else { stopNetworking(); return }
        if !cacheLoaded {
            cacheLoaded = true
            if let saved = await cache.load() {
                catalog = saved.catalog
                catalogFetchedAt = saved.catalogFetchedAt
                for item in configuration.watchlist {
                    var state = pairs[item.id] ?? BinancePairState()
                    if state.ticker == nil { state.ticker = saved.tickers[item.id]; state.quotePhase = .stale }
                    let key = item.id + ":" + configuration.timeRange.interval
                    if state.candles.isEmpty { state.candles = saved.candles[key] ?? []; state.chartPhase = .stale; state.chartRange = configuration.timeRange }
                    pairs[item.id] = state
                }
                updateDock()
            }
        }
        guard !Task.isCancelled, hasDemand else { return }
        loadCatalog()
        if eventTask == nil {
            let events = await stream.events()
            eventTask = Task { [weak self] in
                for await event in events {
                    guard !Task.isCancelled else { return }
                    self?.receive(event)
                }
            }
        }
        if heartbeat == nil {
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    self?.flush()
                }
            }
        }
        let tickers = wantedTickers
        if tickerDemand != tickers { tickerTask?.cancel(); tickerTask = nil; lastPoll = .distantPast; tickerDemand = tickers }
        let charts = wantedCharts
        for symbol in Array(chartTasks.keys) where !charts.contains(symbol) {
            chartTasks.removeValue(forKey: symbol)?.cancel()
            chartGenerations[symbol] = nil
        }
        let available = Set(catalog.map(\.id))
        let known = catalogFetchedAt != nil
        let validTickers = known ? tickers.intersection(available) : tickers
        let validCharts = known ? charts.intersection(available) : charts
        let subscriptions = Set(validTickers.map { $0.lowercased() + "@ticker" })
            .union(validCharts.map { $0.lowercased() + "@kline_" + configuration.timeRange.interval })
        await stream.setSubscriptions(networkBlocked ? [] : subscriptions)
        fetchTickersIfNeeded(force: lastPoll == .distantPast)
        for symbol in validCharts {
            if pairs[symbol]?.chartPhase != .ready { loadChart(symbol) }
        }
    }
    private func stopNetworking() {
        eventTask?.cancel(); eventTask = nil
        heartbeat?.cancel(); heartbeat = nil
        catalogTask?.cancel(); catalogTask = nil
        tickerTask?.cancel(); tickerTask = nil
        for task in chartTasks.values { task.cancel() }
        chartTasks = [:]; chartGenerations = [:]
        pendingTickers = [:]; pendingCandles = [:]
        tickerDemand = []; lastPoll = .distantPast
        connection = .stopped
        catalogIsLoading = false
        Task { await stream.disconnect() }
        for key in pairs.keys {
            if pairs[key]?.ticker != nil { pairs[key]?.quotePhase = .stale }
            if pairs[key]?.candles.isEmpty == false { pairs[key]?.chartPhase = .stale }
        }
        updateDock()
        scheduleCache()
    }
    private func loadCatalog() {
        guard !networkBlocked, catalogTask == nil, catalogRetryAt <= Date(),
              catalogFetchedAt.map({ Date().timeIntervalSince($0) > 6 * 3_600 }) ?? true else { return }
        catalogIsLoading = true
        catalogTask = Task { [weak self, provider] in
            do {
                let symbols = try await provider.symbols()
                guard let self, !Task.isCancelled else { return }
                self.catalog = symbols
                self.catalogFetchedAt = Date()
                self.catalogError = nil
                let listed = Set(symbols.map(\.id))
                for item in self.configuration.watchlist where !listed.contains(item.id) {
                    var state = self.pairs[item.id] ?? BinancePairState()
                    state.quotePhase = .unavailable; state.chartPhase = .unavailable
                    state.message = "Pair unavailable on Binance Spot"
                    self.pairs[item.id] = state
                    self.pendingTickers[item.id] = nil
                    self.pendingCandles[item.id] = nil
                    self.chartTasks.removeValue(forKey: item.id)?.cancel()
                    self.chartGenerations[item.id] = nil
                }
                self.scheduleCache()
                self.scheduleReconcile()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.catalogError = error.localizedDescription
                self.catalogRetryAt = Self.retryDate(for: error)
                self.handleAccessError(error)
            }
            self?.catalogIsLoading = false
            self?.catalogTask = nil
        }
    }
    private func fetchTickersIfNeeded(force: Bool = false) {
        guard !networkBlocked, tickerTask == nil, !wantedTickers.isEmpty else { return }
        guard force || (connection != .live && Date().timeIntervalSince(lastPoll) >= 30) else { return }
        lastPoll = Date()
        if connection != .live {
            for symbol in wantedCharts { loadChart(symbol) }
        }
        let wanted = wantedTickers
        let symbols = catalogFetchedAt == nil ? wanted.sorted() : wanted.filter { id in catalog.contains { $0.id == id } }.sorted()
        guard !symbols.isEmpty else { return }
        tickerTask = Task { [weak self, provider] in
            do {
                let tickers = try await provider.tickers(symbols: symbols)
                guard let self, !Task.isCancelled else { return }
                for ticker in tickers where self.wantedTickers.contains(ticker.symbol) { self.receive(.ticker(ticker)) }
            } catch {
                guard let self, !Task.isCancelled else { return }
                for symbol in symbols {
                    var state = self.pairs[symbol] ?? BinancePairState()
                    state.quotePhase = state.ticker == nil ? .error : .stale
                    state.message = error.localizedDescription
                    self.pairs[symbol] = state
                }
                self.handleAccessError(error)
            }
            self?.tickerTask = nil
        }
    }
    private func loadChart(_ symbol: String) {
        guard !networkBlocked, chartTasks[symbol] == nil, (chartRetryAt[symbol] ?? .distantPast) <= Date() else { return }
        let range = configuration.timeRange
        let token = UUID()
        chartGenerations[symbol] = token
        chartTasks[symbol] = Task { [weak self, provider] in
            do {
                let candles = try await provider.candles(symbol: symbol, range: range)
                guard let self, !Task.isCancelled, self.chartGenerations[symbol] == token, self.configuration.timeRange == range else { return }
                var state = self.pairs[symbol] ?? BinancePairState()
                state.candles = BinanceCandle.merge(candles, state.candles, limit: range.limit)
                state.chartRange = range
                state.chartPhase = .ready
                state.chartMessage = nil
                self.pairs[symbol] = state
                self.scheduleCache()
            } catch {
                guard let self, !Task.isCancelled, self.chartGenerations[symbol] == token else { return }
                var state = self.pairs[symbol] ?? BinancePairState()
                state.chartPhase = state.candles.isEmpty ? .error : .stale
                state.chartMessage = error.localizedDescription
                self.chartRetryAt[symbol] = Self.retryDate(for: error)
                self.pairs[symbol] = state
                self.handleAccessError(error)
            }
            if self?.chartGenerations[symbol] == token { self?.chartTasks[symbol] = nil }
        }
    }
    private func handleAccessError(_ error: Error) {
        if error as? BinanceAPIError == .invalidSymbol {
            catalogFetchedAt = nil
            loadCatalog()
        }
        if error as? BinanceAPIError == .restricted {
            networkBlocked = true
            connection = .restricted
            Task { await stream.setSubscriptions([]) }
        }
    }
    private static func retryDate(for error: Error) -> Date {
        if case .rateLimited(let until) = error as? BinanceAPIError { return until }
        return Date().addingTimeInterval(30)
    }
    private func receive(_ event: BinanceStreamEvent) {
        switch event {
        case .connection(let state):
            guard !networkBlocked else { return }
            let previous = connection
            connection = state
            if state == .reconnecting {
                for symbol in wantedCharts where pairs[symbol]?.candles.isEmpty == false { pairs[symbol]?.chartPhase = .stale }
            }
            if state == .live, previous == .reconnecting {
                for symbol in wantedCharts { loadChart(symbol) }
                lastPoll = .distantPast
                fetchTickersIfNeeded(force: true)
            }
        case .ticker(let ticker):
            guard wantedTickers.contains(ticker.symbol) else { return }
            guard catalogFetchedAt == nil || catalog.contains(where: { $0.id == ticker.symbol }) else { return }
            let previous = pendingTickers[ticker.symbol] ?? pairs[ticker.symbol]?.ticker
            if previous.map({ $0.eventTime > ticker.eventTime }) != true { pendingTickers[ticker.symbol] = ticker }
        case .candle(let symbol, let interval, let candle):
            guard wantedCharts.contains(symbol), interval == configuration.timeRange.interval else { return }
            guard catalogFetchedAt == nil || catalog.contains(where: { $0.id == symbol }) else { return }
            pendingCandles[symbol] = BinanceCandle.merge(pendingCandles[symbol] ?? [], [candle], limit: configuration.timeRange.limit)
        }
    }
    private func flush() {
        let now = Date()
        for (symbol, ticker) in pendingTickers where configuration.watchlist.contains(where: { $0.id == symbol }) {
            var state = pairs[symbol] ?? BinancePairState()
            state.ticker = ticker; state.quotePhase = .ready; state.message = nil
            pairs[symbol] = state
            lastUpdated = max(lastUpdated ?? .distantPast, ticker.receivedAt)
        }
        for (symbol, candles) in pendingCandles where wantedCharts.contains(symbol) {
            var state = pairs[symbol] ?? BinancePairState()
            state.candles = BinanceCandle.merge(state.candles, candles, limit: configuration.timeRange.limit)
            if state.chartPhase == .error { state.chartPhase = .stale }
            pairs[symbol] = state
        }
        let hadUpdates = !pendingTickers.isEmpty || !pendingCandles.isEmpty
        pendingTickers = [:]; pendingCandles = [:]
        for symbol in pairs.keys {
            if let ticker = pairs[symbol]?.ticker, now.timeIntervalSince(ticker.receivedAt) > 60,
               pairs[symbol]?.quotePhase == .ready { pairs[symbol]?.quotePhase = .stale }
        }
        updateDock()
        fetchTickersIfNeeded()
        loadCatalog()
        for symbol in wantedCharts where catalog.contains(where: { $0.id == symbol }) {
            if pairs[symbol]?.chartPhase != .ready && pairs[symbol]?.chartPhase != .unavailable { loadChart(symbol) }
        }
        if hadUpdates { scheduleCache() }
    }
    private func updateDock() {
        guard let item = selectedSymbol else {
            let snapshot = BinanceDockSnapshot(priceColor: configuration.appearance.dockPriceColor)
            if dockSnapshot != snapshot { dockSnapshot = snapshot }
            return
        }
        let state = pairs[item.id]
        let price = state?.ticker.map { BinancePriceFormat.dockPrice($0.price) } ?? "—"
        let compact = state?.ticker.map { BinancePriceFormat.price($0.price, compact: true) } ?? "—"
        let stale = state?.quotePhase == .stale || state?.quotePhase == .error
        let unavailable = state?.quotePhase == .unavailable
        let label = "\(item.baseAsset), \(price) \(item.quoteAsset)" + (stale ? ", last known price" : "") + (unavailable ? ", unavailable" : "")
        let snapshot = BinanceDockSnapshot(priceColor: configuration.appearance.dockPriceColor,
            base: item.baseAsset, quote: item.quoteAsset, price: price, compactPrice: compact,
            isStale: stale, isUnavailable: unavailable, accessibilityValue: label)
        if dockSnapshot != snapshot { dockSnapshot = snapshot }
    }
    private func scheduleCache() {
        guard cacheTask == nil else { return }
        cacheTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self else { return }
            var saved = BinanceCachedMarket(catalog: self.catalog, catalogFetchedAt: self.catalogFetchedAt)
            for (symbol, state) in self.pairs {
                saved.tickers[symbol] = state.ticker
                saved.candles[symbol + ":" + state.chartRange.interval] = Array(state.candles.suffix(366))
            }
            await self.cache.save(saved)
            self.cacheTask = nil
        }
    }
}
