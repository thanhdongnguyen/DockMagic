import AppKit
import EventKit
import Observation

@MainActor
@Observable
final class CalendarStore {
    static let configurationKey = "DockMagicCalendarConfiguration"
    private(set) var configuration: CalendarConfiguration
    private(set) var access: CalendarAccess = .notDetermined
    private(set) var calendars: [CalendarSource] = []
    private(set) var events: [CalendarEvent] = []
    private(set) var reminderAccess: CalendarAccess = .notDetermined
    private(set) var reminderLists: [CalendarSource] = []
    private(set) var reminders: [CalendarReminder] = []
    private(set) var remindersErrorMessage: String?
    private(set) var lastRemindersUpdated: Date?
    private(set) var isConnectingReminders = false
    private(set) var isSaving = false
    private(set) var mutationError: String?
    private(set) var currentDate: Date
    private(set) var selectedDate: Date
    private(set) var displayedMonth: Date
    private(set) var isLoading = false
    private(set) var isConnecting = false
    private(set) var isMonitoring = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    @ObservationIgnored private let provider: any CalendarProviding
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var interests: Set<Interest> = []
    @ObservationIgnored private var editorController: CalendarEditorWindowController?

    enum Interest { case dock, settings, editor }

    init(provider: any CalendarProviding = EventKitCalendarProvider(),
         defaults: UserDefaults = DockMagicRuntimeDefaults.current,
         now: @escaping @MainActor () -> Date = { Date() }) {
        self.provider = provider
        self.defaults = defaults
        self.now = now
        currentDate = now()
        selectedDate = now()
        displayedMonth = now()
        configuration = defaults.data(forKey: Self.configurationKey)
            .flatMap { try? JSONDecoder().decode(CalendarConfiguration.self, from: $0) }
            ?? CalendarConfiguration()
        for name in [Notification.Name.EKEventStoreChanged, NSApplication.didBecomeActiveNotification,
                     NSNotification.Name.NSSystemTimeZoneDidChange, NSNotification.Name.NSCalendarDayChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isMonitoring else { return }
                    self.reload()
                }
            })
        }
    }

    deinit {
        monitoringTask?.cancel()
        refreshTask?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    var todayEvents: [CalendarEvent] {
        CalendarAgenda.events(events, on: currentDate, configuration: configuration, upcomingFrom: currentDate)
    }

    var selectedDayEvents: [CalendarEvent] {
        CalendarAgenda.events(events, on: selectedDate, configuration: configuration)
    }

    var selectedDayReminders: [CalendarReminder] {
        CalendarReminderAgenda.items(reminders, configuration: configuration, on: selectedDate, today: currentDate)
    }
    var visibleReminders: [CalendarReminder] {
        CalendarReminderAgenda.items(reminders, configuration: configuration, today: currentDate)
    }
    var writableCalendars: [CalendarSource] { calendars.filter(\.allowsModifications) }
    var writableReminderLists: [CalendarSource] { reminderLists.filter(\.allowsModifications) }
    var missingReminderSelectionCount: Int {
        configuration.selectedReminderListIDs?.subtracting(Set(reminderLists.map(\.id))).count ?? 0
    }
    var dockAccess: CalendarAccess {
        access == .fullAccess || configuration.showsReminders && reminderAccess == .fullAccess ? .fullAccess : access
    }
    var dockHasError: Bool { todayDockItems.isEmpty && (errorMessage != nil || configuration.showsReminders && remindersErrorMessage != nil) }
    var todayDockItems: [CalendarEvent] {
        let due = CalendarReminderAgenda.items(reminders, configuration: configuration, on: currentDate, today: currentDate)
            .filter { !$0.isCompleted && $0.dueDate != nil }
        let projected = due.map { reminder in
            CalendarEvent(id: "reminder:\(reminder.id)", calendarID: reminder.calendarID, calendarTitle: reminder.calendarTitle,
                title: reminder.title, start: reminder.dueDate!, end: reminder.dueDate!, isAllDay: !reminder.hasDueTime,
                location: nil, meetingURL: nil, isReminder: true)
        }
        return (todayEvents + projected).sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }

    var missingSelectionCount: Int {
        configuration.selectedCalendarIDs?.subtracting(Set(calendars.map(\.id))).count ?? 0
    }

    func start() { setInterest(.dock, active: true) }
    func stop() { setInterest(.dock, active: false) }

    func setInterest(_ interest: Interest, active: Bool) {
        if active { interests.insert(interest) } else { interests.remove(interest) }
        if interests.isEmpty { stopMonitoring() } else { startMonitoring() }
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        reload()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
                guard let self, !Task.isCancelled else { break }
                self.reload()
            }
        }
    }

    private func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        revision += 1
        isLoading = false
    }

    func reload() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in await self?.refresh() }
    }

    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await provider.requestAccess()
            await refresh()
        } catch {
            access = await provider.authorization()
            events = []
            calendars = []
            errorMessage = "Could not connect to Calendar. \(error.localizedDescription)"
        }
    }

    func connectReminders() async {
        guard !isConnectingReminders else { return }
        isConnectingReminders = true
        defer { isConnectingReminders = false }
        do {
            try await provider.requestReminderAccess()
            await refresh()
        } catch {
            reminderAccess = await provider.reminderAuthorization()
            reminders = []; reminderLists = []
            remindersErrorMessage = "Could not connect to Reminders. \(error.localizedDescription)"
        }
    }

    func refresh() async {
        revision += 1
        let request = revision
        let date = now()
        let calendar = Calendar.autoupdatingCurrent
        if !calendar.isDate(date, inSameDayAs: currentDate), calendar.isDate(selectedDate, inSameDayAs: currentDate) {
            selectedDate = date
            displayedMonth = date
        }
        currentDate = date
        isLoading = true
        defer { if revision == request { isLoading = false } }
        async let eventRefresh: Void = refreshEvents(request: request, date: date)
        async let reminderRefresh: Void = refreshReminders(request: request, date: date)
        _ = await (eventRefresh, reminderRefresh)
    }

    private func refreshEvents(request: Int, date: Date) async {
        let status = await provider.authorization()
        guard request == revision, !Task.isCancelled else { return }
        access = status
        guard status == .fullAccess else {
            events = []; calendars = []; lastUpdated = nil; errorMessage = nil
            return
        }
        do {
            let result = try await provider.read(
                intervals: CalendarAgenda.queryIntervals(month: displayedMonth, today: date),
                selectedIDs: configuration.selectedCalendarIDs
            )
            guard request == revision, !Task.isCancelled else { return }
            // Recheck permission after the read before publishing private data.
            let finalStatus = await provider.authorization()
            guard request == revision, !Task.isCancelled else { return }
            access = finalStatus
            guard finalStatus == .fullAccess else {
                events = []; calendars = []; lastUpdated = nil; errorMessage = nil
                return
            }
            calendars = result.calendars
            events = result.events
            lastUpdated = date
            errorMessage = nil
        } catch {
            guard request == revision, !Task.isCancelled else { return }
            events = []; lastUpdated = nil
            errorMessage = "Could not load calendar events. \(error.localizedDescription)"
        }
    }

    private func refreshReminders(request: Int, date: Date) async {
        let status = await provider.reminderAuthorization()
        guard request == revision, !Task.isCancelled else { return }
        reminderAccess = status
        guard status == .fullAccess else {
            reminders = []; reminderLists = []; lastRemindersUpdated = nil; remindersErrorMessage = nil
            return
        }
        do {
            let result = try await provider.readReminders(selectedIDs: configuration.selectedReminderListIDs)
            guard request == revision, !Task.isCancelled else { return }
            let finalStatus = await provider.reminderAuthorization()
            guard request == revision, !Task.isCancelled else { return }
            reminderAccess = finalStatus
            guard finalStatus == .fullAccess else {
                reminders = []; reminderLists = []; lastRemindersUpdated = nil; remindersErrorMessage = nil
                return
            }
            reminders = result.reminders; reminderLists = result.lists
            lastRemindersUpdated = date; remindersErrorMessage = nil
        } catch {
            guard request == revision, !Task.isCancelled else { return }
            reminders = []; lastRemindersUpdated = nil
            remindersErrorMessage = "Could not load reminders. \(error.localizedDescription)"
        }
    }

    func setReminderList(_ id: String, included: Bool) {
        updateConfiguration {
            var ids = $0.selectedReminderListIDs ?? Set(reminderLists.map(\.id))
            if included { ids.insert(id) } else { ids.remove(id) }
            $0.selectedReminderListIDs = ids
        }
    }

    func saveEvent(_ draft: CalendarEventDraft, original: CalendarEvent?) async -> Bool {
        await mutate { try await self.provider.saveEvent(draft, original: original) }
    }
    func deleteEvent(_ event: CalendarEvent) async -> Bool {
        await mutate { try await self.provider.deleteEvent(event) }
    }
    func saveReminder(_ draft: CalendarReminderDraft, original: CalendarReminder?) async -> Bool {
        await mutate { try await self.provider.saveReminder(draft, original: original) }
    }
    func deleteReminder(_ reminder: CalendarReminder) async -> Bool {
        await mutate { try await self.provider.deleteReminder(reminder) }
    }
    func setReminderCompleted(_ reminder: CalendarReminder, completed: Bool) async -> Bool {
        await mutate { try await self.provider.setReminderCompleted(reminder, completed: completed) }
    }
    func clearMutationError() { mutationError = nil }

    private func mutate(_ operation: () async throws -> Void) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true; mutationError = nil
        // Invalidate any older read before the write. Re-read after commit;
        // writes are never queued/offline-replayed or retried automatically.
        refreshTask?.cancel(); revision += 1
        defer { isSaving = false }
        do {
            try await operation()
            await refresh()
            return true
        } catch {
            mutationError = error.localizedDescription
            await refresh()
            return false
        }
    }

    func openEditor(kind: CalendarEditKind, event: CalendarEvent? = nil, reminder: CalendarReminder? = nil) {
        if editorController == nil { editorController = CalendarEditorWindowController() }
        editorController?.show(store: self, kind: kind, event: event, reminder: reminder)
    }

    func updateConfiguration(_ update: (inout CalendarConfiguration) -> Void) {
        update(&configuration)
        if let data = try? JSONEncoder().encode(configuration) { defaults.set(data, forKey: Self.configurationKey) }
        reload()
    }

    func setCalendar(_ id: String, included: Bool) {
        updateConfiguration {
            var ids = $0.selectedCalendarIDs ?? Set(calendars.map(\.id))
            if included { ids.insert(id) } else { ids.remove(id) }
            $0.selectedCalendarIDs = ids
        }
    }

    func selectDay(_ date: Date) {
        selectedDate = date
        if !Calendar.autoupdatingCurrent.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = date
            reload()
        }
    }

    func moveMonth(_ offset: Int) {
        let calendar = Calendar.autoupdatingCurrent
        guard let start = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
              let date = calendar.date(byAdding: .month, value: offset, to: start) else { return }
        displayedMonth = date
        selectedDate = date
        reload()
    }

    func showToday() { selectedDate = now(); displayedMonth = selectedDate; reload() }

    static func openCalendar() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openRemindersPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openReminders() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
