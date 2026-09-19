import EventKit
import Foundation

extension EventKitCalendarProvider {
    // Each explicit mutation uses a fresh store to re-fetch current native data.
    // Failures cannot leave a partially edited object in the reader's cache.
    func saveEvent(_ draft: CalendarEventDraft, original: CalendarEvent?) throws {
        try draft.validate()
        guard authorization() == .fullAccess else { throw CalendarWriteError.permission }
        let store = EKEventStore()
        let destination = try writableCalendar(draft.calendarID, type: .event, in: store)
        let event = try original.map { try currentEvent($0, in: store) } ?? EKEvent(eventStore: store)
        event.calendar = destination
        event.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startDate = draft.start; event.endDate = draft.end; event.isAllDay = draft.isAllDay
        event.location = draft.location.isEmpty ? nil : draft.location
        event.notes = draft.notes.isEmpty ? nil : draft.notes
        event.url = draft.url.isEmpty ? nil : URL(string: draft.url)
        // Attendees, alarms, recurrence rules, availability and time zone are
        // preserved. Recurring event edits/deletes affect this occurrence only.
        do { try store.save(event, span: .thisEvent, commit: true) }
        catch { store.reset(); throw error }
    }

    func deleteEvent(_ original: CalendarEvent) throws {
        guard authorization() == .fullAccess else { throw CalendarWriteError.permission }
        let store = EKEventStore()
        let event = try currentEvent(original, in: store)
        do { try store.remove(event, span: .thisEvent, commit: true) }
        catch { store.reset(); throw error }
    }

    func saveReminder(_ draft: CalendarReminderDraft, original: CalendarReminder?) throws {
        try draft.validate()
        guard reminderAuthorization() == .fullAccess else { throw CalendarWriteError.permission }
        let store = EKEventStore()
        let destination = try writableCalendar(draft.calendarID, type: .reminder, in: store)
        let reminder = try original.map { try currentReminder($0, in: store) } ?? EKReminder(eventStore: store)
        reminder.calendar = destination
        reminder.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = draft.notes.isEmpty ? nil : draft.notes
        reminder.priority = draft.priority
        reminder.isCompleted = draft.isCompleted
        // Keep original components/time zone when the user did not edit the due date.
        let originalDraft = original.map(CalendarReminderDraft.init)
        if originalDraft == nil || draft.hasDueDate != originalDraft?.hasDueDate
            || draft.hasDueDate && (draft.includesTime != originalDraft?.includesTime || draft.dueDate != originalDraft?.dueDate) {
            reminder.dueDateComponents = draft.dueComponents
            // EventKit requires start/due components to use compatible calendars
            // and start <= due. Existing alarms and recurrence remain untouched.
            if let start = reminder.startDateComponents, let due = draft.dueComponents,
               let startDate = start.date, let dueDate = due.date, startDate > dueDate {
                reminder.startDateComponents = due
            } else if !draft.hasDueDate { reminder.startDateComponents = nil }
        }
        do { try store.save(reminder, commit: true) }
        catch { store.reset(); throw error }
    }

    func deleteReminder(_ original: CalendarReminder) throws {
        guard reminderAuthorization() == .fullAccess else { throw CalendarWriteError.permission }
        let store = EKEventStore()
        let reminder = try currentReminder(original, in: store)
        do { try store.remove(reminder, commit: true) }
        catch { store.reset(); throw error }
    }

    func setReminderCompleted(_ original: CalendarReminder, completed: Bool) throws {
        guard reminderAuthorization() == .fullAccess else { throw CalendarWriteError.permission }
        let store = EKEventStore()
        let reminder = try currentReminder(original, in: store)
        reminder.isCompleted = completed
        do { try store.save(reminder, commit: true) }
        catch { store.reset(); throw error }
    }

    private func writableCalendar(_ id: String, type: EKEntityType, in store: EKEventStore) throws -> EKCalendar {
        guard let calendar = store.calendars(for: type).first(where: { $0.calendarIdentifier == id }) else {
            throw CalendarWriteError.unavailable
        }
        guard calendar.allowsContentModifications else { throw CalendarWriteError.readOnly }
        return calendar
    }

    private func currentEvent(_ original: CalendarEvent, in store: EKEventStore) throws -> EKEvent {
        guard !original.isReadOnly else { throw CalendarWriteError.readOnly }
        let calendar = try writableCalendar(original.calendarID, type: .event, in: store)
        // Identifier alone can return the first occurrence of a recurring event.
        let predicate = store.predicateForEvents(withStart: original.start.addingTimeInterval(-1),
            end: max(original.end, original.start.addingTimeInterval(1)), calendars: [calendar])
        guard let event = store.events(matching: predicate).first(where: {
            $0.calendarItemIdentifier == original.itemIdentifier && $0.startDate == original.start
        }), event.refresh(), Self.eventValue(event) == original else { throw CalendarWriteError.conflict }
        return event
    }

    private func currentReminder(_ original: CalendarReminder, in store: EKEventStore) throws -> EKReminder {
        guard !original.isReadOnly else { throw CalendarWriteError.readOnly }
        _ = try writableCalendar(original.calendarID, type: .reminder, in: store)
        guard let reminder = store.calendarItem(withIdentifier: original.id) as? EKReminder,
              reminder.refresh(), Self.reminderValue(reminder) == original else { throw CalendarWriteError.conflict }
        return reminder
    }
}
