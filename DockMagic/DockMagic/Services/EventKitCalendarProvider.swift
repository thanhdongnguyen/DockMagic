import EventKit
import Foundation

protocol CalendarProviding: Sendable {
    func authorization() async -> CalendarAccess
    func requestAccess() async throws
    func read(intervals: [DateInterval], selectedIDs: Set<String>?) async throws -> CalendarReadResult
    func reminderAuthorization() async -> CalendarAccess
    func requestReminderAccess() async throws
    func readReminders(selectedIDs: Set<String>?) async throws -> CalendarReminderReadResult
    func saveEvent(_ draft: CalendarEventDraft, original: CalendarEvent?) async throws
    func deleteEvent(_ event: CalendarEvent) async throws
    func saveReminder(_ draft: CalendarReminderDraft, original: CalendarReminder?) async throws
    func deleteReminder(_ reminder: CalendarReminder) async throws
    func setReminderCompleted(_ reminder: CalendarReminder, completed: Bool) async throws
}

// Read-only test/providers remain explicitly unable to mutate data.
extension CalendarProviding {
    func reminderAuthorization() async -> CalendarAccess { .notDetermined }
    func requestReminderAccess() async throws { throw CalendarWriteError.unavailable }
    func readReminders(selectedIDs: Set<String>?) async throws -> CalendarReminderReadResult { .init(lists: [], reminders: []) }
    func saveEvent(_ draft: CalendarEventDraft, original: CalendarEvent?) async throws { throw CalendarWriteError.readOnly }
    func deleteEvent(_ event: CalendarEvent) async throws { throw CalendarWriteError.readOnly }
    func saveReminder(_ draft: CalendarReminderDraft, original: CalendarReminder?) async throws { throw CalendarWriteError.readOnly }
    func deleteReminder(_ reminder: CalendarReminder) async throws { throw CalendarWriteError.readOnly }
    func setReminderCompleted(_ reminder: CalendarReminder, completed: Bool) async throws { throw CalendarWriteError.readOnly }
}

actor EventKitCalendarProvider: CalendarProviding {
    private var store: EKEventStore?
    private var eventStore: EKEventStore {
        if let store { return store }
        let value = EKEventStore()
        store = value
        return value
    }

    func authorization() -> CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: .notDetermined
        case .fullAccess: .fullAccess
        case .denied: .denied
        case .restricted: .restricted
        case .writeOnly: .writeOnly
        @unknown default: .restricted
        }
    }

    func requestAccess() async throws {
        _ = try await eventStore.requestFullAccessToEvents()
    }

    func read(intervals: [DateInterval], selectedIDs: Set<String>?) throws -> CalendarReadResult {
        guard authorization() == .fullAccess else { throw CalendarReadError.accessChanged }
        let store = eventStore
        store.refreshSourcesIfNecessary()
        let calendars = store.calendars(for: .event)
        let sources = calendars.map {
            Self.sourceValue($0)
        }.sorted { ($0.account, $0.title, $0.id) < ($1.account, $1.title, $1.id) }
        let selected = calendars.filter { selectedIDs?.contains($0.calendarIdentifier) ?? true }
        // An empty array must not become nil: nil queries every calendar.
        guard !selected.isEmpty else { return CalendarReadResult(calendars: sources, events: []) }
        var values: [String: CalendarEvent] = [:]
        for interval in intervals {
            let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: selected)
            for event in store.events(matching: predicate) where event.status != .canceled {
                if event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) == true { continue }
                guard let start = event.startDate, event.endDate != nil else { continue }
                // Recurring occurrences share an event identifier.
                let id = "\(event.calendar.calendarIdentifier)|\(event.calendarItemIdentifier)|\(start.timeIntervalSinceReferenceDate)"
                values[id] = Self.eventValue(event)
            }
        }
        guard authorization() == .fullAccess else { throw CalendarReadError.accessChanged }
        return CalendarReadResult(calendars: sources, events: Array(values.values))
    }

    func reminderAuthorization() -> CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .fullAccess
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .restricted
        }
    }

    func requestReminderAccess() async throws { _ = try await eventStore.requestFullAccessToReminders() }

    func readReminders(selectedIDs: Set<String>?) async throws -> CalendarReminderReadResult {
        guard await reminderAuthorization() == .fullAccess else { throw CalendarWriteError.permission }
        let store = eventStore
        store.refreshSourcesIfNecessary()
        let calendars = store.calendars(for: .reminder)
        let lists = calendars.map(Self.sourceValue).sorted { ($0.account, $0.title, $0.id) < ($1.account, $1.title, $1.id) }
        let selected = calendars.filter { selectedIDs?.contains($0.calendarIdentifier) ?? true }
        guard !selected.isEmpty else { return .init(lists: lists, reminders: []) }
        let predicate = store.predicateForReminders(in: selected)
        let reminders: [CalendarReminder] = try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders else { continuation.resume(throwing: CalendarWriteError.unavailable); return }
                // EventKit delivers on its callback queue. Only immutable values
                // cross back into the actor/UI; no fetched EKObject is retained.
                continuation.resume(returning: reminders.map(Self.reminderValue))
            }
        }
        try Task.checkCancellation()
        guard await reminderAuthorization() == .fullAccess else { throw CalendarWriteError.permission }
        return .init(lists: lists, reminders: reminders)
    }

    nonisolated static func sourceValue(_ source: EKCalendar) -> CalendarSource {
        .init(id: source.calendarIdentifier, title: source.title, account: source.source.title,
              allowsModifications: source.allowsContentModifications)
    }

    nonisolated static func eventValue(_ event: EKEvent) -> CalendarEvent {
        .init(id: "\(event.calendar.calendarIdentifier)|\(event.calendarItemIdentifier)|\(event.startDate.timeIntervalSinceReferenceDate)",
              calendarID: event.calendar.calendarIdentifier, calendarTitle: event.calendar.title,
              title: event.title?.isEmpty == false ? event.title : "Untitled event",
              start: event.startDate, end: event.endDate, isAllDay: event.isAllDay, location: event.location,
              meetingURL: CalendarMeetingLink.find(url: event.url, location: event.location, notes: event.notes),
              itemIdentifier: event.calendarItemIdentifier, modificationDate: event.lastModifiedDate,
              notes: event.notes, url: event.url, isRecurring: event.hasRecurrenceRules,
              isReadOnly: !event.calendar.allowsContentModifications)
    }

    nonisolated static func reminderValue(_ reminder: EKReminder) -> CalendarReminder {
        .init(id: reminder.calendarItemIdentifier, calendarID: reminder.calendar.calendarIdentifier,
              calendarTitle: reminder.calendar.title, title: reminder.title ?? "Untitled reminder",
              dueDateComponents: reminder.dueDateComponents, isCompleted: reminder.isCompleted,
              notes: reminder.notes, priority: reminder.priority, modificationDate: reminder.lastModifiedDate,
              isRecurring: reminder.hasRecurrenceRules, isReadOnly: !reminder.calendar.allowsContentModifications)
    }
}

enum CalendarReadError: LocalizedError {
    case accessChanged
    var errorDescription: String? { "Calendar access changed. Check Calendar permissions in System Settings." }
}
