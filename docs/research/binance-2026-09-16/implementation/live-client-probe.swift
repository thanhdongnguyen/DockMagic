import Foundation
@main struct BinanceLiveProbe {
    static func main() async throws {
        let client = BinanceMarketDataClient()
        let symbols = try await client.symbols()
        let ticker = try await client.tickers(symbols: ["BTCUSDT", "ETHUSDT", "SOLUSDT"])
        let candles = try await client.candles(symbol: "ETHUSDT", range: .day)
        let stream = BinanceMarketStreamClient()
        let events = await stream.events()
        await stream.setSubscriptions(["btcusdt@ticker", "ethusdt@ticker", "ethusdt@kline_5m"])
        let deadline = Task { try? await Task.sleep(for: .seconds(10)); await stream.disconnect() }
        var tickerEvents = 0
        var candleEvents = 0
        var live = false
        for await event in events {
            switch event {
            case .ticker: tickerEvents += 1
            case .candle: candleEvents += 1
            case .connection(.live): live = true
            default: break
            }
        }
        deadline.cancel()
        let result: [String: Any] = ["catalogPairs": symbols.count, "tickerPairs": ticker.count,
            "ETH24HCandles": candles.count, "streamLive": live, "tickerEvents": tickerEvents,
            "candleEvents": candleEvents, "recordedAt": ISO8601DateFormatter().string(from: Date())]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        guard !symbols.isEmpty, ticker.count == 3, candles.count > 0, live, tickerEvents > 0, candleEvents > 0 else {
            throw BinanceAPIError.malformedData
        }
    }
}
