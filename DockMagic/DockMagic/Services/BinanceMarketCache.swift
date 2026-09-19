import Foundation

struct BinanceCachedMarket: Codable, Sendable {
    var version = 1
    var savedAt = Date()
    var catalog: [BinanceSymbol] = []
    var catalogFetchedAt: Date?
    var tickers: [String: BinanceTicker] = [:]
    var candles: [String: [BinanceCandle]] = [:]
}

actor BinanceMarketCache {
    private let url: URL?
    static let maximumBytes = 8 * 1_024 * 1_024
    init(url: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appendingPathComponent("com.hypevibe.DockMagic/Binance/market-v1.json")) {
        self.url = url
    }
    func load() -> BinanceCachedMarket? {
        guard let url,
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.maximumBytes,
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(BinanceCachedMarket.self, from: data),
              cache.version == 1, Date().timeIntervalSince(cache.savedAt) < 86_400 else { return nil }
        return cache
    }
    func save(_ cache: BinanceCachedMarket) {
        guard let url, let data = try? JSONEncoder().encode(cache), data.count <= Self.maximumBytes else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch { /* Cache is disposable; market state and preferences remain valid. */ }
    }
}
