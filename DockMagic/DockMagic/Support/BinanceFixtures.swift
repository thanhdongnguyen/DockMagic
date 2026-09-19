#if DEBUG
import Foundation

/// Deterministic data for renderer and UI tests only. Production never selects
/// this provider, and it never falls back to fixtures after a network error.
actor BinanceFixtureProvider: BinanceMarketDataProviding {
    static let bases = ["BTC", "ETH", "SOL", "BNB", "XRP", "ADA", "DOGE", "AVAX", "LTC", "LINK", "DOT", "ATOM", "UNI", "NEAR", "FIL", "APT", "ARB", "OP", "SUI", "TRX"]
    static let catalog = bases.map { BinanceSymbol(symbol: $0 + "USDT", baseAsset: $0, quoteAsset: "USDT") }
        + [BinanceSymbol(symbol: "BTCUSDC", baseAsset: "BTC", quoteAsset: "USDC")]
    var failure: BinanceAPIError?
    var candleDelay: [BinanceTimeRange: Duration] = [:]
    private(set) var tickerCalls = 0
    private(set) var chartCalls = 0
    private(set) var catalogCalls = 0

    func setFailure(_ error: BinanceAPIError?) { failure = error }
    func setDelay(_ range: BinanceTimeRange, _ duration: Duration) { candleDelay[range] = duration }
    func symbols() async throws -> [BinanceSymbol] {
        catalogCalls += 1
        if let failure { throw failure }
        return Self.catalog
    }
    func tickers(symbols: [String]) async throws -> [BinanceTicker] {
        tickerCalls += 1
        if let failure { throw failure }
        return symbols.map { symbol in
            let price = Self.price(symbol)
            return BinanceTicker(symbol: symbol, price: price, changePercent: symbol == "ETHUSDT" ? Decimal(string: "-2.95")! : symbol == "SOLUSDT" ? Decimal(string: "0.86")! : Decimal(string: "-1.41")!,
                high: price * Decimal(string: "1.04")!, low: price * Decimal(string: "0.97")!, volume: 10_000, eventTime: Date(), receivedAt: Date())
        }
    }
    func candles(symbol: String, range: BinanceTimeRange) async throws -> [BinanceCandle] {
        chartCalls += 1
        if let delay = candleDelay[range] { try await Task.sleep(for: delay) }
        if let failure { throw failure }
        return Self.history(symbol: symbol, range: range)
    }
    static func price(_ symbol: String) -> Decimal {
        switch symbol {
        case "BTCUSDT", "BTCUSDC": Decimal(string: "75830.04")!
        case "ETHUSDT": Decimal(string: "2402.41")!
        case "SOLUSDT": Decimal(string: "146.82")!
        default: Decimal(string: "0.12345678")!
        }
    }
    static func history(symbol: String, range: BinanceTimeRange, now: Date = Date()) -> [BinanceCandle] {
        let end = floor(now.timeIntervalSince1970 / range.candleSeconds) * range.candleSeconds
        let base = NSDecimalNumber(decimal: price(symbol)).doubleValue
        return (0..<range.limit).map { index in
            let t = Double(index) / Double(range.limit - 1)
            let trend = symbol == "SOLUSDT" ? (t - 1) * 0.035 : (1 - t) * 0.035 - sin(t * .pi) * 0.02
            let oscillation = sin(Double(index) * 1.7) * 0.0015 + sin(Double(index) * 0.18) * 0.002
            let close = Decimal(base * (1 + trend + oscillation))
            let open = close * Decimal(index.isMultiple(of: 2) ? 1.001 : 0.999)
            let date = Date(timeIntervalSince1970: end - Double(range.limit - 1 - index) * range.candleSeconds)
            let closeTime = date.addingTimeInterval(range.candleSeconds - 0.001)
            return BinanceCandle(openTime: date, closeTime: closeTime, open: open, high: max(open, close) * Decimal(string: "1.001")!,
                low: min(open, close) * Decimal(string: "0.999")!, close: close, volume: Decimal(50 + index % 47),
                isClosed: index < range.limit - 1, eventTime: min(now, closeTime))
        }
    }
    static func configuration(count: Int) -> BinanceConfiguration {
        var value = BinanceConfiguration()
        value.watchlist = Array(catalog.prefix(max(0, min(count, 20))))
        if count > 1 { value.pinnedSymbol = "ETHUSDT" }
        return value
    }
}

actor BinanceFixtureStream: BinanceMarketStreaming {
    private var continuation: AsyncStream<BinanceStreamEvent>.Continuation?
    private(set) var subscriptions: Set<String> = []
    private(set) var subscriptionCalls = 0
    func events() -> AsyncStream<BinanceStreamEvent> {
        AsyncStream { continuation = $0 }
    }
    func setSubscriptions(_ streams: Set<String>) {
        subscriptionCalls += 1
        subscriptions = streams
        continuation?.yield(.connection(streams.isEmpty ? .stopped : .live))
    }
    func disconnect() { subscriptions = []; continuation?.finish(); continuation = nil }
    func send(_ event: BinanceStreamEvent) { continuation?.yield(event) }
}
#endif
