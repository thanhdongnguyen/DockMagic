import Foundation
import Observation

@MainActor
@Observable
final class NetworkMetricsStore {
    private(set) var current: NetworkMetricsSnapshot = .zero
    private(set) var history: [NetworkMetricsSnapshot] = []
    private(set) var isMonitoring = false
    private(set) var lastErrorDescription: String?

    @ObservationIgnored private let sampler: any NetworkMetricsSampling
    @ObservationIgnored private let samplingInterval: Duration
    @ObservationIgnored private let historyLimit: Int
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var activeRunID: UUID?

    init(
        sampler: any NetworkMetricsSampling = NetworkMetricsSampler(),
        samplingInterval: Duration = .seconds(1),
        historyLimit: Int = 60
    ) {
        precondition(samplingInterval > .zero, "Sampling interval must be positive.")
        self.sampler = sampler
        self.samplingInterval = samplingInterval
        self.historyLimit = max(historyLimit, 2)
    }

    deinit {
        monitoringTask?.cancel()
    }

    func start() {
        guard monitoringTask == nil else {
            return
        }

        let runID = UUID()
        activeRunID = runID
        history.removeAll(keepingCapacity: true)
        current = .zero
        isMonitoring = true

        let sampler = self.sampler
        let samplingInterval = self.samplingInterval
        monitoringTask = Task { [weak self] in
            await sampler.reset()

            while !Task.isCancelled {
                guard self != nil else {
                    break
                }

                do {
                    let snapshot = try await sampler.sample()
                    guard !Task.isCancelled, let self else {
                        break
                    }
                    self.record(snapshot)
                    self.lastErrorDescription = nil
                } catch is CancellationError {
                    break
                } catch {
                    self?.lastErrorDescription = error.localizedDescription
                }

                guard !Task.isCancelled else {
                    break
                }
                do {
                    try await Task.sleep(for: samplingInterval)
                } catch {
                    break
                }
            }

            guard let self, self.activeRunID == runID else {
                return
            }
            self.activeRunID = nil
            self.monitoringTask = nil
            self.isMonitoring = false
        }
    }

    func stop() {
        activeRunID = nil
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }

    @discardableResult
    func refresh() async -> NetworkMetricsSnapshot? {
        do {
            let snapshot = try await sampler.sample()
            guard !Task.isCancelled else {
                return nil
            }
            record(snapshot)
            lastErrorDescription = nil
            return snapshot
        } catch is CancellationError {
            return nil
        } catch {
            lastErrorDescription = error.localizedDescription
            return nil
        }
    }

    private func record(_ snapshot: NetworkMetricsSnapshot) {
        current = snapshot
        history.append(snapshot)
        let overflow = history.count - historyLimit
        if overflow > 0 {
            history.removeFirst(overflow)
        }
    }
}
