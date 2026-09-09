import Foundation
import Network

@MainActor
protocol NetworkAvailabilityMonitoring: AnyObject {
    func start(onReconnect: @escaping @MainActor () -> Void)
    func stop()
}

/// Only transitions from an unavailable path trigger recovery. The initial
/// satisfied path is already covered by the stores' initial reads.
@MainActor
final class NetworkAvailabilityMonitor: NetworkAvailabilityMonitoring {
    private var monitor: NWPathMonitor?
    private var runID: UUID?
    private var wasConnected: Bool?
    private let queue = DispatchQueue(label: "com.hypevibe.DockMagic.network-availability")

    func start(onReconnect: @escaping @MainActor () -> Void) {
        guard monitor == nil else { return }
        let id = UUID()
        runID = id
        wasConnected = nil
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.runID == id else { return }
                let reconnected = self.wasConnected == false && connected
                self.wasConnected = connected
                if reconnected { onReconnect() }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        runID = nil
        monitor?.cancel()
        monitor = nil
        wasConnected = nil
    }

    deinit { monitor?.cancel() }
}

/// Failures retry promptly, then back off up to the regular polling interval.
/// A successful read resets the delay, including a read requested by recovery.
struct UsageRetrySchedule {
    let pollingInterval: Duration
    let initialRetryInterval: Duration
    private(set) var failureCount = 0

    init(pollingInterval: Duration, initialRetryInterval: Duration) {
        precondition(pollingInterval > .zero && initialRetryInterval > .zero)
        self.pollingInterval = pollingInterval
        self.initialRetryInterval = initialRetryInterval
    }

    var nextDelay: Duration {
        guard failureCount > 0 else { return pollingInterval }
        return min(pollingInterval, initialRetryInterval * (1 << min(failureCount - 1, 16)))
    }

    mutating func succeeded() { failureCount = 0 }
    mutating func failed() { failureCount = min(failureCount + 1, 17) }
}
