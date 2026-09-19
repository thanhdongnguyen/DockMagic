import Foundation

@main
struct BinanceWebSocketProbe {
    static func main() async {
        let endpoint = "wss://data-stream.binance.vision:443/stream?streams=btcusdt@ticker/btcusdt@kline_1m/ethusdt@ticker/ethusdt@kline_5m"
        let session = URLSession(configuration: .ephemeral)
        let socket = session.webSocketTask(with: URL(string: endpoint)!)
        let start = Date()
        var counts: [String: Int] = [:]
        var samples: [String: [String: Any]] = [:]
        var lastError: String?
        socket.resume()
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 40_000_000_000)
            socket.cancel(with: .goingAway, reason: nil)
        }
        do {
            while Date().timeIntervalSince(start) < 39 {
                let message = try await socket.receive()
                let bytes: Data
                switch message {
                case .string(let text): bytes = Data(text.utf8)
                case .data(let data): bytes = data
                @unknown default: continue
                }
                guard let envelope = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                      let stream = envelope["stream"] as? String,
                      let data = envelope["data"] as? [String: Any] else { continue }
                counts[stream, default: 0] += 1
                samples[stream] = data
            }
        } catch {
            lastError = error.localizedDescription
        }
        timeout.cancel()
        socket.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
        let report: [String: Any] = [
            "endpoint": endpoint,
            "checked_at_utc": ISO8601DateFormatter().string(from: start),
            "duration_seconds": Date().timeIntervalSince(start),
            "counts": counts,
            "last_samples": samples,
            "error": lastError as Any? ?? NSNull(),
            "all_four_streams_received": counts.count == 4
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/dockmagic-binance-research-20260916/websocket-results.json"))
            print(String(data: data, encoding: .utf8)!)
        }
    }
}
