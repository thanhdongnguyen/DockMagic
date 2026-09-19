import Foundation

enum BinanceChartType: String, Codable, CaseIterable, Identifiable, Sendable {
    case line, candlestick
    var id: Self { self }
    var title: String { self == .line ? "Line" : "Candlestick" }
}

enum BinanceTimeRange: String, Codable, CaseIterable, Identifiable, Sendable {
    case hour = "1H", day = "24H", week = "7D", month = "30D", year = "1Y"
    var id: Self { self }
    var interval: String {
        switch self {
        case .hour: "1m"
        case .day: "5m"
        case .week: "1h"
        case .month: "4h"
        case .year: "1d"
        }
    }
    var seconds: TimeInterval {
        switch self {
        case .hour: 3_600
        case .day: 86_400
        case .week: 604_800
        case .month: 2_592_000
        case .year: 31_536_000
        }
    }
    var candleSeconds: TimeInterval {
        switch self {
        case .hour: 60
        case .day: 300
        case .week: 3_600
        case .month: 14_400
        case .year: 86_400
        }
    }
    var limit: Int { Int(seconds / candleSeconds) + 1 }
}

struct BinanceSymbol: Codable, Equatable, Identifiable, Sendable {
    let symbol: String
    let baseAsset: String
    let quoteAsset: String
    var id: String { symbol }
    var pair: String { "\(baseAsset) / \(quoteAsset)" }
    func matches(_ query: String) -> Bool {
        let query = query.uppercased().filter { !$0.isWhitespace && $0 != "/" }
        return query.isEmpty || symbol.contains(query) || baseAsset.contains(query) || quoteAsset.contains(query)
    }
}

struct BinanceAppearance: Codable, Equatable, Sendable {
    var dockPriceColor: DockColor?
    var priceSeriesColor: DockColor?
    var volumeColor: DockColor?

    static let standard = Self()

    mutating func normalize() {
        for key in [\Self.dockPriceColor, \Self.priceSeriesColor, \Self.volumeColor] {
            if let color = self[keyPath: key] {
                self[keyPath: key] = DockColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            }
        }
    }
}

struct BinanceConfiguration: Codable, Equatable, Sendable {
    static let maximumPairs = 20
    var watchlist: [BinanceSymbol] = []
    var pinnedSymbol: String?
    var chartType: BinanceChartType = .line
    var timeRange: BinanceTimeRange = .day
    var showsVolume = false
    var preferredQuote = "USDT"
    var appearance: BinanceAppearance = .standard

    init() {}

    private enum CodingKeys: String, CodingKey {
        case watchlist, pinnedSymbol, chartType, timeRange, showsVolume, preferredQuote, appearance
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        watchlist = try values.decodeIfPresent([BinanceSymbol].self, forKey: .watchlist) ?? []
        pinnedSymbol = try values.decodeIfPresent(String.self, forKey: .pinnedSymbol)
        chartType = try values.decodeIfPresent(BinanceChartType.self, forKey: .chartType) ?? .line
        timeRange = try values.decodeIfPresent(BinanceTimeRange.self, forKey: .timeRange) ?? .day
        showsVolume = try values.decodeIfPresent(Bool.self, forKey: .showsVolume) ?? false
        preferredQuote = try values.decodeIfPresent(String.self, forKey: .preferredQuote) ?? "USDT"
        appearance = try values.decodeIfPresent(BinanceAppearance.self, forKey: .appearance) ?? .standard
        normalize()
    }

    var selected: BinanceSymbol? {
        watchlist.first { $0.symbol == pinnedSymbol } ?? watchlist.first
    }
    var displayOrder: [BinanceSymbol] {
        guard let selected else { return [] }
        return [selected] + watchlist.filter { $0.id != selected.id }
    }
    mutating func normalize() {
        var seen = Set<String>()
        watchlist = Array(watchlist.filter {
            !$0.symbol.isEmpty && !$0.baseAsset.isEmpty && !$0.quoteAsset.isEmpty && seen.insert($0.symbol).inserted
        }.prefix(Self.maximumPairs))
        if !watchlist.contains(where: { $0.symbol == pinnedSymbol }) { pinnedSymbol = nil }
        preferredQuote = preferredQuote.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if preferredQuote.isEmpty { preferredQuote = "USDT" }
        appearance.normalize()
    }
}

struct BinanceTicker: Codable, Equatable, Sendable {
    let symbol: String
    let price: Decimal
    let changePercent: Decimal
    let high: Decimal
    let low: Decimal
    let volume: Decimal
    let eventTime: Date
    var receivedAt: Date
}

struct BinanceCandle: Codable, Equatable, Identifiable, Sendable {
    let openTime: Date
    let closeTime: Date
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let close: Decimal
    let volume: Decimal
    let isClosed: Bool
    let eventTime: Date
    var id: Date { openTime }
    var rising: Bool { close >= open }

    /// REST snapshots overlap the stream. An older snapshot must never reopen
    /// a closed candle, or overwrite a newer update to an in-progress candle.
    static func merge(_ existing: [Self], _ incoming: [Self], limit: Int) -> [Self] {
        var buckets = Dictionary(existing.map { ($0.openTime, $0) }, uniquingKeysWith: { _, last in last })
        for candle in incoming {
            if let old = buckets[candle.openTime] {
                if old.isClosed && !candle.isClosed { continue }
                if old.isClosed == candle.isClosed && old.eventTime > candle.eventTime { continue }
            }
            buckets[candle.openTime] = candle
        }
        return Array(buckets.values.sorted { $0.openTime < $1.openTime }.suffix(limit))
    }
}

enum BinanceLoadPhase: String, Codable, Sendable {
    case loading, ready, stale, unavailable, error
}

struct BinancePairState: Equatable, Sendable {
    var ticker: BinanceTicker?
    var candles: [BinanceCandle] = []
    var quotePhase: BinanceLoadPhase = .loading
    var chartPhase: BinanceLoadPhase = .loading
    var message: String?
    var chartMessage: String?
    var chartRange: BinanceTimeRange = .day
}

enum BinanceConnectionState: Equatable, Sendable {
    case stopped, connecting, live, reconnecting, restricted
    var label: String {
        switch self {
        case .stopped: "Not connected"
        case .connecting: "Connecting…"
        case .live: "Live"
        case .reconnecting: "Reconnecting · 30s updates"
        case .restricted: "Service unavailable"
        }
    }
}

enum BinanceStreamEvent: Sendable {
    case ticker(BinanceTicker)
    case candle(symbol: String, interval: String, candle: BinanceCandle)
    case connection(BinanceConnectionState)
}

/// Only strings and state that actually affect icon pixels. Candle updates and
/// sub-second ticker changes do not invalidate the shared application icon.
struct BinanceDockSnapshot: Equatable, Sendable {
    var priceColor: DockColor?
    var base = "Binance"
    var quote = ""
    var price = "—"
    var compactPrice = "—"
    var prefersCompactPrice = false
    var isStale = false
    var isUnavailable = false
    var accessibilityValue = "Binance. Add your first coin."
}

enum BinancePriceFormat {
    static func price(_ value: Decimal, compact: Bool = false) -> String {
        let number = NSDecimalNumber(decimal: value)
        guard number != .notANumber else { return "—" }
        let magnitude = abs(number.doubleValue)
        if !compact {
            if magnitude > 0 && magnitude < 1e-36 { return number.stringValue }
            return decimal(value, digits: 38)
        }
        if compact, magnitude >= 1_000 {
            let divisor: Decimal = magnitude >= 1_000_000_000 ? 1_000_000_000 : magnitude >= 1_000_000 ? 1_000_000 : 1_000
            let suffix = magnitude >= 1_000_000_000 ? "B" : magnitude >= 1_000_000 ? "M" : "K"
            return decimal(value / divisor, digits: 2) + suffix
        }
        if magnitude > 0, magnitude < 0.000001, compact {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 2
            formatter.exponentSymbol = "e"
            return formatter.string(from: number) ?? number.stringValue
        }
        let digits = magnitude == 0 ? 2 : magnitude < 1 ? min(20, max(2, Int(-floor(log10(magnitude))) + 3)) : 2
        return decimal(value, digits: compact && magnitude >= 100 ? 0 : digits)
    }
    static func decimal(_ value: Decimal, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }
    static func change(_ value: Decimal) -> String {
        (value > 0 ? "+" : "") + decimal(value, digits: 2) + "%"
    }
    static func dockPrice(_ value: Decimal) -> String {
        if abs(NSDecimalNumber(decimal: value).doubleValue) >= 100_000 { return price(value, compact: true) }
        if abs(NSDecimalNumber(decimal: value).doubleValue) >= 100 { return decimal(value, digits: 0) }
        return price(value, compact: true)
    }
}
