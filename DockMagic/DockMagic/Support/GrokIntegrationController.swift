import AppKit
import Observation

/// Owns background collection independently of the active Dock feature.
@MainActor
final class GrokIntegrationController {
    let store: GrokBuildUsageStore
    private let preferences: DockPreferencesStore
    private let isAvailable: Bool
    private var running = false
    private var observing = false
    private var applied: GrokBuildSettings?
    private var task: Task<Void, Never>?
    private var sleepObserver: NSObjectProtocol?
    private let calendarNotifications: NotificationCenter
    private var calendarObservers: [NSObjectProtocol] = []
    private var calendarTask: Task<Void, Never>?
    private var calendarEpoch = UUID()
    private var suspended = false

    init(preferences: DockPreferencesStore, store: GrokBuildUsageStore? = nil,
         isAvailable: Bool = GrokBuildFeatureGate.experimentalEnabled,
         calendarNotifications: NotificationCenter = .default) {
        self.preferences = preferences
        self.store = store ?? GrokBuildUsageStore()
        self.isAvailable = isAvailable
        self.calendarNotifications = calendarNotifications
    }

    func start() {
        guard !running, isAvailable else { return }
        running = true
        suspended = false
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.suspend()
            }
        }
        for name in [NSNotification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange] {
            calendarObservers.append(calendarNotifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleCalendarProjection() }
            })
        }
        apply()
        observe()
    }

    func stop() {
        running = false
        applied = nil
        task?.cancel(); task = nil
        cancelCalendarProjection()
        store.stop()
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        sleepObserver = nil
        calendarObservers.forEach(calendarNotifications.removeObserver)
        calendarObservers.removeAll()
    }

    func resume() async {
        guard running, isAvailable else { return }
        suspended = false
        if let task { await task.value }
        guard running, !suspended, !Task.isCancelled else { return }
        await store.resume()
    }

    func suspend() {
        suspended = true
        cancelCalendarProjection()
        task?.cancel()
        store.stop()
    }

    private func scheduleCalendarProjection() {
        guard running, !suspended else { return }
        cancelCalendarProjection()
        let epoch = calendarEpoch
        calendarTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if let task = self.task { await task.value }
            guard self.running, !self.suspended, self.calendarEpoch == epoch, !Task.isCancelled else { return }
            await self.store.reprojectCalendar()
            if self.calendarEpoch == epoch { self.calendarTask = nil }
        }
    }

    private func cancelCalendarProjection() {
        calendarEpoch = UUID()
        calendarTask?.cancel()
        calendarTask = nil
    }

    private func observe() {
        guard running, !observing else { return }
        observing = true
        withObservationTracking { _ = preferences.grokBuildSettings } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observing = false
                guard self.running else { return }
                self.apply()
                self.observe()
            }
        }
    }

    private func apply() {
        let settings = preferences.grokBuildSettings
        // Appearance changes must not restart processes or reset observation.
        if let applied, applied.enabled == settings.enabled, applied.monitoring == settings.monitoring,
           applied.executablePath == settings.executablePath, applied.homePath == settings.homePath { return }
        applied = settings
        task?.cancel()
        store.stop()
        task = Task { @MainActor [weak self] in
            guard let self, self.running, !Task.isCancelled else { return }
            await self.store.configure(settings.configuration(), enabled: settings.enabled, monitoring: settings.monitoring)
        }
    }
}
