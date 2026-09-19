import Foundation

#if DEBUG
/// Isolated native-store substitute. Never requests permission or touches the
/// user's EventKit database. Values are stable across reads within a test run.
actor CalendarUITestProvider: CalendarProviding {
    var status: CalendarAccess
    var reminderStatus: CalendarAccess
    var nativeEvents: [CalendarEvent]
    var nativeReminders: [CalendarReminder]
    var writeFailure: CalendarWriteError?
    var writeDelay: Duration = .zero
    private(set) var writes = 0
    private(set) var requests = 0
    private(set) var reminderRequests = 0
    let sources: [CalendarSource] = [
        .init(id: "work", title: "Work", account: "iCloud", allowsModifications: true),
        .init(id: "personal", title: "Personal", account: "iCloud", allowsModifications: true),
        .init(id: "holidays", title: "Holidays", account: "Subscribed", allowsModifications: false)
    ]
    let lists: [CalendarSource] = [
        .init(id: "tasks", title: "Tasks", account: "iCloud", allowsModifications: true),
        .init(id: "shared", title: "Shared list", account: "iCloud", allowsModifications: false)
    ]
    init(access: String?, remindersAccess: String? = nil) {
        status = CalendarAccess(rawValue: access ?? "notDetermined") ?? .notDetermined
        reminderStatus = CalendarAccess(rawValue: remindersAccess ?? "notDetermined") ?? .notDetermined
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        nativeEvents = [
            .init(id: "release", calendarID: "personal", calendarTitle: "Personal", title: "Release day", start: day, end: tomorrow, isAllDay: true, location: nil, meetingURL: nil, itemIdentifier: "release", isReadOnly: false),
            .init(id: "planning", calendarID: "work", calendarTitle: "Work", title: "Team planning", start: now.addingTimeInterval(600), end: now.addingTimeInterval(2400), isAllDay: false, location: "Google Meet", meetingURL: URL(string: "https://meet.google.com/abc-defg-hij"), itemIdentifier: "planning", url: URL(string: "https://meet.google.com/abc-defg-hij"), isReadOnly: false),
            .init(id: "review", calendarID: "work", calendarTitle: "Work", title: "Design review with the product team", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(5400), isAllDay: false, location: "Studio", meetingURL: nil, itemIdentifier: "review", isReadOnly: false)
        ]
        nativeReminders = [
            .init(id: "send", calendarID: "tasks", calendarTitle: "Tasks", title: "Send release notes",
                  dueDateComponents: calendar.dateComponents([.year, .month, .day], from: day), isReadOnly: false),
            .init(id: "undated", calendarID: "tasks", calendarTitle: "Tasks", title: "Plan next milestone", isReadOnly: false),
            .init(id: "shared-task", calendarID: "shared", calendarTitle: "Shared list", title: "Read-only reminder", isReadOnly: true)
        ]
    }
    func authorization() -> CalendarAccess { status }
    func reminderAuthorization() -> CalendarAccess { reminderStatus }
    func requestAccess() { requests += 1; status = .fullAccess }
    func requestReminderAccess() { reminderRequests += 1; reminderStatus = .fullAccess }
    func read(intervals: [DateInterval], selectedIDs: Set<String>?) throws -> CalendarReadResult {
        guard status == .fullAccess else { throw CalendarWriteError.permission }
        return .init(calendars: sources, events: nativeEvents.filter { selectedIDs?.contains($0.calendarID) ?? true })
    }
    func readReminders(selectedIDs: Set<String>?) throws -> CalendarReminderReadResult {
        guard reminderStatus == .fullAccess else { throw CalendarWriteError.permission }
        return .init(lists: lists, reminders: nativeReminders.filter { selectedIDs?.contains($0.calendarID) ?? true })
    }
    func saveEvent(_ draft: CalendarEventDraft, original: CalendarEvent?) async throws {
        try await beforeWrite(status); try draft.validate()
        if let original { try validate(original) }
        guard let source = sources.first(where: { $0.id == draft.calendarID }), source.allowsModifications else { throw CalendarWriteError.readOnly }
        let id = original?.id ?? UUID().uuidString
        let event = CalendarEvent(id: id, calendarID: source.id, calendarTitle: source.title, title: draft.title,
            start: draft.start, end: draft.end, isAllDay: draft.isAllDay, location: draft.location,
            meetingURL: CalendarMeetingLink.find(url: URL(string: draft.url), location: draft.location, notes: draft.notes),
            itemIdentifier: id, modificationDate: Date(), notes: draft.notes, url: URL(string: draft.url),
            isRecurring: original?.isRecurring ?? false, isReadOnly: false)
        nativeEvents.removeAll { $0.id == id }; nativeEvents.append(event); writes += 1
    }
    func deleteEvent(_ event: CalendarEvent) async throws {
        try await beforeWrite(status); try validate(event)
        nativeEvents.removeAll { $0.id == event.id }; writes += 1
    }
    func saveReminder(_ draft: CalendarReminderDraft, original: CalendarReminder?) async throws {
        try await beforeWrite(reminderStatus); try draft.validate()
        if let original { try validate(original) }
        guard let list = lists.first(where: { $0.id == draft.calendarID }), list.allowsModifications else { throw CalendarWriteError.readOnly }
        let id = original?.id ?? UUID().uuidString
        let reminder = CalendarReminder(id: id, calendarID: list.id, calendarTitle: list.title, title: draft.title,
            dueDateComponents: draft.dueComponents, isCompleted: draft.isCompleted, notes: draft.notes, priority: draft.priority,
            modificationDate: Date(), isRecurring: original?.isRecurring ?? false, isReadOnly: false)
        nativeReminders.removeAll { $0.id == id }; nativeReminders.append(reminder); writes += 1
    }
    func deleteReminder(_ reminder: CalendarReminder) async throws {
        try await beforeWrite(reminderStatus); try validate(reminder)
        nativeReminders.removeAll { $0.id == reminder.id }; writes += 1
    }
    func setReminderCompleted(_ reminder: CalendarReminder, completed: Bool) async throws {
        try await beforeWrite(reminderStatus); try validate(reminder)
        guard let index = nativeReminders.firstIndex(where: { $0.id == reminder.id }) else { throw CalendarWriteError.conflict }
        nativeReminders[index].isCompleted = completed; nativeReminders[index].modificationDate = Date(); writes += 1
    }
    private func beforeWrite(_ access: CalendarAccess) async throws {
        guard access == .fullAccess else { throw CalendarWriteError.permission }
        if writeDelay > .zero { try await Task.sleep(for: writeDelay) }
        if let writeFailure { throw writeFailure }
    }
    private func validate(_ event: CalendarEvent) throws {
        guard !event.isReadOnly else { throw CalendarWriteError.readOnly }
        guard nativeEvents.first(where: { $0.id == event.id }) == event else { throw CalendarWriteError.conflict }
    }
    private func validate(_ reminder: CalendarReminder) throws {
        guard !reminder.isReadOnly else { throw CalendarWriteError.readOnly }
        guard nativeReminders.first(where: { $0.id == reminder.id }) == reminder else { throw CalendarWriteError.conflict }
    }
    func setAccess(calendar: CalendarAccess, reminders: CalendarAccess) { status = calendar; reminderStatus = reminders }
    func failWrites(_ error: CalendarWriteError?) { writeFailure = error }
    func delayWrites(_ delay: Duration) { writeDelay = delay }
    func replaceEvents(_ events: [CalendarEvent]) { nativeEvents = events }
    func replaceReminders(_ reminders: [CalendarReminder]) { nativeReminders = reminders }
    func simulateExternalEdits() {
        if let event = nativeEvents.first(where: { $0.id == "planning" }) {
            var draft = CalendarEventDraft(event: event); draft.title = "Updated in Apple Calendar"
            nativeEvents.removeAll { $0.id == event.id }
            nativeEvents.append(.init(id: event.id, calendarID: event.calendarID, calendarTitle: event.calendarTitle,
                title: draft.title, start: event.start, end: event.end, isAllDay: event.isAllDay, location: event.location,
                meetingURL: event.meetingURL, itemIdentifier: event.itemIdentifier, modificationDate: Date(), isReadOnly: false))
        }
        if let index = nativeReminders.firstIndex(where: { $0.id == "send" }) {
            let original = nativeReminders[index]
            nativeReminders[index] = .init(id: original.id, calendarID: original.calendarID, calendarTitle: original.calendarTitle,
                title: "Updated in Apple Reminders", dueDateComponents: original.dueDateComponents,
                modificationDate: Date(), isReadOnly: false)
        }
    }
}
#endif
