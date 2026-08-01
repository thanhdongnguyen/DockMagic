import Foundation
import Observation

@MainActor
@Observable
final class StorageMetricsStore {
    private(set) var current: StorageMetricsSnapshot = .zero
    private(set) var isMonitoring = false
    private(set) var lastErrorDescription: String?

    @ObservationIgnored private let sampler: any StorageMetricsSampling
    @ObservationIgnored private let samplingInterval: Duration
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var activeRunID: UUID?

    init(
        sampler: any StorageMetricsSampling = StorageMetricsSampler(),
        samplingInterval: Duration = .seconds(5)
    ) {
        precondition(samplingInterval > .zero, "Sampling interval must be positive.")
        self.sampler = sampler
        self.samplingInterval = samplingInterval
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
        isMonitoring = true

        let sampler = self.sampler
        let samplingInterval = self.samplingInterval
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else {
                    break
                }

                do {
                    let snapshot = try await sampler.sample()
                    guard !Task.isCancelled, let self else {
                        break
                    }
                    self.current = snapshot
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
    func refresh() async -> StorageMetricsSnapshot? {
        do {
            let snapshot = try await sampler.sample()
            guard !Task.isCancelled else {
                return nil
            }
            current = snapshot
            lastErrorDescription = nil
            return snapshot
        } catch is CancellationError {
            return nil
        } catch {
            lastErrorDescription = error.localizedDescription
            return nil
        }
    }
}
