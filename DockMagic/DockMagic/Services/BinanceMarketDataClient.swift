import Foundation

protocol BinanceMarketDataProviding: Sendable {
    func symbols() async throws -> [BinanceSymbol]
    func tickers(symbols: [String]) async throws -> [BinanceTicker]
    func candles(symbol: String, range: BinanceTimeRange) async throws -> [BinanceCandle]
}

enum BinanceAPIError: Error, LocalizedError, Equatable, Sendable {
    case malformedData
    case invalidSymbol
    case rateLimited(until: Date)
    case restricted
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .malformedData: "Binance returned an unreadable response."
        case .invalidSymbol: "This pair is no longer available on Binance Spot."
        case .rateLimited(let until): "Binance rate limit. Retry after \(until.formatted(date: .omitted, time: .standard))."
        case .restricted: "Binance is unavailable from this connection."
        case .http(let status): "Binance could not load this data (HTTP \(status))."
        }
    }
}

actor BinanceMarketDataClient: BinanceMarketDataProviding {
    private let session: URLSession
    private let baseURL: URL
    private var retryAfter: Date?

    init(session: URLSession = .shared, baseURL: URL = URL(string: "https://data-api.binance.vision")!) {
        self.session = session
        self.baseURL = baseURL
    }

    func symbols() async throws -> [BinanceSymbol] {
        // Do not filter status at the transport boundary: a successful full
        // catalog is needed to distinguish delisting from a network failure.
        let data = try await get("exchangeInfo", query: ["permissions": "SPOT", "showPermissionSets": "false"])
        return try BinanceMarketParser.symbols(data)
    }
    func tickers(symbols: [String]) async throws -> [BinanceTicker] {
        guard !symbols.isEmpty else { return [] }
        let encoded = try JSONEncoder().encode(Array(symbols.prefix(BinanceConfiguration.maximumPairs)))
        let data = try await get("ticker/24hr", query: ["symbols": String(decoding: encoded, as: UTF8.self)])
        return try BinanceMarketParser.tickers(data)
    }
    func candles(symbol: String, range: BinanceTimeRange) async throws -> [BinanceCandle] {
        let requestedAt = Date()
        let data = try await get("klines", query: ["symbol": symbol, "interval": range.interval, "limit": String(range.limit)])
        return try BinanceMarketParser.candles(data, now: requestedAt)
    }

    private func get(_ path: String, query: [String: String]) async throws -> Data {
        if let retryAfter, retryAfter > Date() { throw BinanceAPIError.rateLimited(until: retryAfter) }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v3/" + path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BinanceAPIError.malformedData }
        if http.statusCode == 429 || http.statusCode == 418 {
            let until = Self.retryDate(http.value(forHTTPHeaderField: "Retry-After"), now: Date())
            retryAfter = max(retryAfter ?? .distantPast, until)
            throw BinanceAPIError.rateLimited(until: until)
        }
        if http.statusCode == 403 || http.statusCode == 451 { throw BinanceAPIError.restricted }
        guard (200..<300).contains(http.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["code"] as? Int == -1121 {
                throw BinanceAPIError.invalidSymbol
            }
            throw BinanceAPIError.http(http.statusCode)
        }
        return data
    }

    static func retryDate(_ header: String?, now: Date) -> Date {
        if let header, let seconds = TimeInterval(header) { return now.addingTimeInterval(max(1, seconds)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return header.flatMap(formatter.date(from:)).map { max($0, now.addingTimeInterval(1)) } ?? now.addingTimeInterval(60)
    }
}

enum BinanceMarketParser {
    static func symbols(_ data: Data) throws -> [BinanceSymbol] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["symbols"] as? [[String: Any]] else { throw BinanceAPIError.malformedData }
        guard !rows.isEmpty else { throw BinanceAPIError.malformedData }
        return try rows.compactMap { row in
            guard let status = row["status"] as? String, let spot = row["isSpotTradingAllowed"] as? Bool else { throw BinanceAPIError.malformedData }
            guard status == "TRADING", spot else { return nil }
            guard let symbol = row["symbol"] as? String, let base = row["baseAsset"] as? String,
                  let quote = row["quoteAsset"] as? String else { throw BinanceAPIError.malformedData }
            return BinanceSymbol(symbol: symbol, baseAsset: base, quoteAsset: quote)
        }.sorted { $0.symbol < $1.symbol }
    }
    static func tickers(_ data: Data, now: Date = Date()) throws -> [BinanceTicker] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw BinanceAPIError.malformedData }
        return try rows.map { try ticker($0, stream: false, now: now) }
    }
    static func ticker(_ row: [String: Any], stream: Bool, now: Date) throws -> BinanceTicker {
        guard let symbol = row[stream ? "s" : "symbol"] as? String else { throw BinanceAPIError.malformedData }
        return try BinanceTicker(symbol: symbol, price: decimal(row[stream ? "c" : "lastPrice"]),
            changePercent: decimal(row[stream ? "P" : "priceChangePercent"]),
            high: decimal(row[stream ? "h" : "highPrice"]), low: decimal(row[stream ? "l" : "lowPrice"]),
            volume: decimal(row[stream ? "v" : "volume"]), eventTime: date(row[stream ? "E" : "closeTime"]), receivedAt: now)
    }
    static func candles(_ data: Data, now: Date = Date()) throws -> [BinanceCandle] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else { throw BinanceAPIError.malformedData }
        return try rows.map { row in
            guard row.count >= 7 else { throw BinanceAPIError.malformedData }
            let closeTime = try date(row[6])
            return try checkedCandle(openTime: date(row[0]), closeTime: closeTime,
                open: decimal(row[1]), high: decimal(row[2]), low: decimal(row[3]), close: decimal(row[4]),
                volume: decimal(row[5]), isClosed: closeTime < now, eventTime: min(closeTime, now))
        }
    }
    static func stream(_ data: Data, now: Date = Date()) throws -> BinanceStreamEvent? {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw BinanceAPIError.malformedData }
        let row = envelope["data"] as? [String: Any] ?? envelope
        switch row["e"] as? String {
        case "24hrTicker": return .ticker(try ticker(row, stream: true, now: now))
        case "kline":
            guard let symbol = row["s"] as? String, let k = row["k"] as? [String: Any],
                  let interval = k["i"] as? String, let closed = k["x"] as? Bool else { throw BinanceAPIError.malformedData }
            return .candle(symbol: symbol, interval: interval, candle: try checkedCandle(
                openTime: date(k["t"]), closeTime: date(k["T"]), open: decimal(k["o"]), high: decimal(k["h"]),
                low: decimal(k["l"]), close: decimal(k["c"]), volume: decimal(k["v"]), isClosed: closed, eventTime: date(row["E"])))
        case "serverShutdown": throw BinanceAPIError.http(503)
        default: return nil // subscription acknowledgement / additive event
        }
    }
    private static func checkedCandle(openTime: Date, closeTime: Date, open: Decimal, high: Decimal, low: Decimal,
                                      close: Decimal, volume: Decimal, isClosed: Bool, eventTime: Date) throws -> BinanceCandle {
        guard high >= max(open, close), low <= min(open, close), low >= 0, volume >= 0, closeTime >= openTime else {
            throw BinanceAPIError.malformedData
        }
        return BinanceCandle(openTime: openTime, closeTime: closeTime, open: open, high: high, low: low,
            close: close, volume: volume, isClosed: isClosed, eventTime: eventTime)
    }
    private static func decimal(_ value: Any?) throws -> Decimal {
        guard let string = value as? String,
              string.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil,
              let number = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")),
              !number.isNaN else { throw BinanceAPIError.malformedData }
        return number
    }
    private static func date(_ value: Any?) throws -> Date {
        guard let number = value as? NSNumber, number.doubleValue.isFinite else { throw BinanceAPIError.malformedData }
        return Date(timeIntervalSince1970: number.doubleValue / 1_000)
    }
}
