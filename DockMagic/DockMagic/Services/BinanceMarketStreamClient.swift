import Foundation

protocol BinanceMarketStreaming: Sendable {
    func events() async -> AsyncStream<BinanceStreamEvent>
    func setSubscriptions(_ streams: Set<String>) async
    func disconnect() async
}

/// One connection for the feature. URLSession handles the server's ping/pong
/// control frames. Subscription control messages are serialized and limited.
actor BinanceMarketStreamClient: BinanceMarketStreaming {
    private let session: URLSession
    private let baseURL: URL
    private var desired: Set<String> = []
    private var subscribed: Set<String> = []
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var controlTask: Task<Void, Never>?
    private var continuation: AsyncStream<BinanceStreamEvent>.Continuation?
    private var generation = 0
    private var requestID = 0

    init(session: URLSession = .shared, baseURL: URL = URL(string: "wss://data-stream.binance.vision:443")!) {
        self.session = session
        self.baseURL = baseURL
    }
    func events() -> AsyncStream<BinanceStreamEvent> {
        continuation?.finish()
        return AsyncStream(bufferingPolicy: .bufferingNewest(256)) { continuation = $0 }
    }
    func setSubscriptions(_ streams: Set<String>) {
        desired = streams
        guard !streams.isEmpty else { closeConnection(); return }
        guard receiveTask != nil else {
            generation += 1
            let token = generation
            receiveTask = Task { await self.run(generation: token) }
            return
        }
        scheduleControls()
    }
    func disconnect() {
        desired = []
        closeConnection()
        continuation?.finish()
        continuation = nil
    }
    private func closeConnection() {
        generation += 1
        receiveTask?.cancel()
        receiveTask = nil
        controlTask?.cancel()
        controlTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        subscribed = []
        continuation?.yield(.connection(.stopped))
    }
    private func run(generation token: Int) async {
        var failures = 0
        while !Task.isCancelled && token == generation && !desired.isEmpty {
            continuation?.yield(.connection(failures == 0 ? .connecting : .reconnecting))
            var components = URLComponents(url: baseURL.appendingPathComponent("stream"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "streams", value: desired.sorted().joined(separator: "/"))]
            let task = session.webSocketTask(with: components.url!)
            socket = task
            subscribed = desired
            task.resume()
            let began = Date()
            var announcedLive = false
            // Rotate before Binance's 24-hour connection limit. A ping also
            // detects a half-open socket independently of market activity.
            let health = Task {
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(20))
                        if Date().timeIntervalSince(began) > 23 * 3_600 + 50 * 60 {
                            task.cancel(with: .goingAway, reason: nil)
                            return
                        }
                        let deadline = Task {
                            do { try await Task.sleep(for: .seconds(10)) } catch { return }
                            task.cancel(with: .goingAway, reason: nil)
                        }
                        defer { deadline.cancel() }
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            task.sendPing { error in
                                if let error {
                                    continuation.resume(throwing: error)
                                } else {
                                    continuation.resume()
                                }
                            }
                        }
                    }
                } catch { task.cancel(with: .goingAway, reason: nil) }
            }
            do {
                while !Task.isCancelled && token == generation {
                    let message = try await task.receive()
                    let data: Data
                    switch message {
                    case .data(let bytes): data = bytes
                    case .string(let string): data = Data(string.utf8)
                    @unknown default: continue
                    }
                    if let event = try BinanceMarketParser.stream(data) {
                        if !announcedLive {
                            continuation?.yield(.connection(.live))
                            announcedLive = true
                        }
                        failures = 0
                        continuation?.yield(event)
                    }
                }
            } catch {
                if token == generation && !Task.isCancelled {
                    continuation?.yield(.connection(.reconnecting))
                }
            }
            health.cancel()
            task.cancel(with: .goingAway, reason: nil)
            guard token == generation, !Task.isCancelled else { return }
            socket = nil
            subscribed = []
            controlTask?.cancel()
            controlTask = nil
            failures += 1
            let delay = min(30, pow(2, Double(min(failures, 5)))) + Double.random(in: 0...1)
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
        }
    }
    private func scheduleControls() {
        guard controlTask == nil, socket != nil else { return }
        let token = generation
        controlTask = Task {
            do {
                while !Task.isCancelled && token == generation {
                    try await Task.sleep(for: .milliseconds(650))
                    guard let socket else { break }
                    let remove = subscribed.subtracting(desired)
                    let add = desired.subtracting(subscribed)
                    guard !remove.isEmpty || !add.isEmpty else { break }
                    let params = !remove.isEmpty ? remove : add
                    requestID += 1
                    let payload: [String: Any] = ["method": !remove.isEmpty ? "UNSUBSCRIBE" : "SUBSCRIBE", "params": params.sorted(), "id": requestID]
                    let data = try JSONSerialization.data(withJSONObject: payload)
                    try await socket.send(.string(String(decoding: data, as: UTF8.self)))
                    if !remove.isEmpty { subscribed.subtract(remove) } else { subscribed.formUnion(add) }
                }
            } catch { socket?.cancel(with: .goingAway, reason: nil) }
            if token == generation { controlTask = nil }
        }
    }
}
