import Foundation
import Observation

@MainActor
@Observable
final class ClockStore {
    private(set) var currentDate: Date
    private(set) var isMonitoring = false

    @ObservationIgnored
    private let updateInterval: Duration

    @ObservationIgnored
    private let now: @MainActor @Sendable () -> Date

    @ObservationIgnored
    private var monitoringTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    init(
        initialDate: Date? = nil,
        updateInterval: Duration = .seconds(1),
        now: @escaping @MainActor @Sendable () -> Date = { Date() }
    ) {
        precondition(updateInterval > .zero, "Update interval must be positive.")
        self.updateInterval = updateInterval
        self.now = now
        currentDate = initialDate ?? now()
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
        refresh()

        let updateInterval = self.updateInterval
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: updateInterval)
                } catch {
                    break
                }

                guard !Task.isCancelled, let self else {
                    break
                }
                self.refresh()
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

    func refresh() {
        currentDate = now()
    }
}
