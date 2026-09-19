import Foundation

struct CalendarReminder: Identifiable, Equatable, Sendable {
    let id: String
    let calendarID: String
    let calendarTitle: String
    let title: String
    var dueDateComponents: DateComponents? = nil
    var isCompleted = false
    var notes: String? = nil
    var priority = 0
    var modificationDate: Date? = nil
    var isRecurring = false
    var isReadOnly = true

    var hasDueTime: Bool { dueDateComponents?.hour != nil }
    var dueDate: Date? {
        guard let components = dueDateComponents, components.year != nil,
              components.month != nil, components.day != nil else { return nil }
        var calendar = components.calendar ?? Calendar.autoupdatingCurrent
        if let zone = components.timeZone { calendar.timeZone = zone }
        return calendar.date(from: components)
    }

    func occurs(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let dueDate else { return false }
        return calendar.isDate(dueDate, inSameDayAs: date)
    }

    func isOverdue(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < (hasDueTime ? now : calendar.startOfDay(for: now))
    }

    func dueLabel(now: Date) -> String {
        guard let dueDate else { return "No due date" }
        let value = dueDate.formatted(date: .abbreviated, time: hasDueTime ? .shortened : .omitted)
        return isOverdue(at: now) ? "Overdue · \(value)" : value
    }
}

struct CalendarReminderReadResult: Sendable {
    let lists: [CalendarSource]
    let reminders: [CalendarReminder]
}

enum CalendarReminderAgenda {
    static func items(_ reminders: [CalendarReminder], configuration: CalendarConfiguration,
                      on day: Date? = nil, today: Date, calendar: Calendar = .autoupdatingCurrent) -> [CalendarReminder] {
        guard configuration.showsReminders else { return [] }
        return reminders.filter { reminder in
            guard configuration.selectedReminderListIDs?.contains(reminder.calendarID) ?? true,
                  configuration.showsCompletedReminders || !reminder.isCompleted else { return false }
            guard let day else { return true }
            // Today's agenda also contains overdue and undated unfinished work.
            return reminder.occurs(on: day, calendar: calendar)
                || (calendar.isDate(day, inSameDayAs: today) && !reminder.isCompleted
                    && (reminder.dueDate == nil || reminder.isOverdue(at: today, calendar: calendar)))
        }.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.dueDate != $1.dueDate { return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            return ($0.title, $0.id) < ($1.title, $1.id)
        }
    }
}

enum CalendarEditKind: String, CaseIterable, Identifiable {
    case event, reminder
    var id: Self { self }
    var title: String { self == .event ? "Event" : "Reminder" }
}

struct CalendarEventDraft: Equatable, Sendable {
    var calendarID: String
    var title = ""
    var start: Date
    var end: Date
    var isAllDay = false
    var location = ""
    var notes = ""
    var url = ""

    init(calendarID: String, date: Date) {
        self.calendarID = calendarID; start = date; end = date.addingTimeInterval(3600)
    }
    init(event: CalendarEvent) {
        calendarID = event.calendarID; title = event.title; start = event.start; end = event.end
        isAllDay = event.isAllDay; location = event.location ?? ""; notes = event.notes ?? ""; url = event.url?.absoluteString ?? ""
    }
    mutating func normalizeAllDayRange(calendar: Calendar = .autoupdatingCurrent) {
        guard isAllDay else { return }
        start = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let exclusiveEnd = end > endDay ? calendar.date(byAdding: .day, value: 1, to: endDay)! : endDay
        end = exclusiveEnd > start ? exclusiveEnd : calendar.date(byAdding: .day, value: 1, to: start)!
    }
    func displayedEndDate(calendar: Calendar = .autoupdatingCurrent) -> Date {
        isAllDay ? calendar.date(byAdding: .day, value: -1, to: end) ?? end : end
    }
    mutating func setDisplayedEndDate(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        end = isAllDay ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date : date
    }
    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CalendarWriteError.validation("Enter a title.") }
        guard !calendarID.isEmpty else { throw CalendarWriteError.validation("Choose a writable calendar.") }
        guard end > start else { throw CalendarWriteError.validation("The end must be after the start.") }
        if !url.isEmpty {
            guard let value = URL(string: url), ["https", "http"].contains(value.scheme?.lowercased() ?? ""), value.host != nil else {
                throw CalendarWriteError.validation("Enter a complete http or https URL.")
            }
        }
    }
}

struct CalendarReminderDraft: Equatable, Sendable {
    var calendarID: String
    var title = ""
    var hasDueDate = false
    var includesTime = false
    var dueDate: Date
    var notes = ""
    var priority = 0
    var isCompleted = false

    init(calendarID: String, date: Date) { self.calendarID = calendarID; dueDate = date }
    init(reminder: CalendarReminder) {
        calendarID = reminder.calendarID; title = reminder.title; hasDueDate = reminder.dueDate != nil
        includesTime = reminder.hasDueTime; dueDate = reminder.dueDate ?? Date()
        notes = reminder.notes ?? ""; priority = reminder.priority; isCompleted = reminder.isCompleted
    }
    var dueComponents: DateComponents? {
        guard hasDueDate else { return nil }
        let calendar = Calendar.autoupdatingCurrent
        let fields: Set<Calendar.Component> = includesTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        var components = calendar.dateComponents(fields, from: dueDate)
        components.calendar = calendar
        // Date-only reminders are floating dates, not midnight UTC appointments.
        if includesTime { components.timeZone = calendar.timeZone }
        return components
    }
    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CalendarWriteError.validation("Enter a title.") }
        guard !calendarID.isEmpty else { throw CalendarWriteError.validation("Choose a writable reminder list.") }
        guard (0...9).contains(priority) else { throw CalendarWriteError.validation("Invalid reminder priority.") }
    }
}

enum CalendarWriteError: LocalizedError, Equatable {
    case permission, readOnly, conflict, unavailable, busy, validation(String)
    var errorDescription: String? {
        switch self {
        case .permission: "Access changed. Reconnect in Calendar Settings before saving."
        case .readOnly: "This calendar or list is read-only. Choose a writable destination."
        case .conflict: "This item changed or was deleted in another app. Close this editor and reopen the latest version before saving."
        case .unavailable: "This item is no longer available. Refresh your calendars and lists."
        case .busy: "Another change is being saved. Try again when it finishes."
        case let .validation(message): message
        }
    }
}
