import Foundation

enum CalendarAccess: String, Equatable, Sendable {
    case notDetermined, fullAccess, denied, restricted, writeOnly

    var message: String {
        switch self {
        case .notDetermined: "Connect Calendar to see your events."
        case .fullAccess: "Connected to Apple Calendar"
        case .denied: "Allow DockMagic in System Settings → Privacy & Security → Calendars."
        case .restricted: "Calendar access is restricted on this Mac."
        case .writeOnly: "Full calendar access is required to display existing events."
        }
    }
}

enum CalendarDockLayout: String, CaseIterable, Codable, Identifiable, Sendable {
    case date, nextEvent, dateAndNextEvent, dateAndAgenda
    var id: Self { self }
    var title: String {
        switch self {
        case .date: "Date"
        case .nextEvent: "Next event"
        case .dateAndNextEvent: "Date + next event"
        case .dateAndAgenda: "Date + agenda"
        }
    }
}

struct CalendarConfiguration: Codable, Equatable, Sendable {
    var layout: CalendarDockLayout = .date
    // nil means all calendars, [] means none. Never silently replace a missing
    // selection with every calendar after an account or device changes.
    var selectedCalendarIDs: Set<String>? = nil
    var includesAllDayEvents = true
    var showsCallButton = true
    var selectedReminderListIDs: Set<String>? = nil
    var showsReminders = true
    var showsCompletedReminders = false

    // Preserve existing Calendar preferences when upgrading from the read-only version.
    private enum CodingKeys: String, CodingKey {
        case layout, selectedCalendarIDs, includesAllDayEvents, showsCallButton
        case selectedReminderListIDs, showsReminders, showsCompletedReminders
    }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        layout = try values.decodeIfPresent(CalendarDockLayout.self, forKey: .layout) ?? .date
        selectedCalendarIDs = try values.decodeIfPresent(Set<String>.self, forKey: .selectedCalendarIDs)
        includesAllDayEvents = try values.decodeIfPresent(Bool.self, forKey: .includesAllDayEvents) ?? true
        showsCallButton = try values.decodeIfPresent(Bool.self, forKey: .showsCallButton) ?? true
        selectedReminderListIDs = try values.decodeIfPresent(Set<String>.self, forKey: .selectedReminderListIDs)
        showsReminders = try values.decodeIfPresent(Bool.self, forKey: .showsReminders) ?? true
        showsCompletedReminders = try values.decodeIfPresent(Bool.self, forKey: .showsCompletedReminders) ?? false
    }
}

struct CalendarSource: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let account: String
    var allowsModifications = false
}

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let calendarID: String
    let calendarTitle: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let meetingURL: URL?
    var itemIdentifier: String? = nil
    var modificationDate: Date? = nil
    var notes: String? = nil
    var url: URL? = nil
    var isRecurring = false
    var isReadOnly = true
    // Presentation only: a reminder is never copied into the event database.
    var isReminder = false

    func occurs(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return false }
        // EventKit end dates are exclusive (including multi-day all-day events).
        return start < day.end && (end > day.start || (start == end && start >= day.start))
    }

    func timeLabel(now: Date) -> String {
        if isReminder {
            if start < Calendar.autoupdatingCurrent.startOfDay(for: now) { return "Reminder · overdue" }
            return isAllDay ? "Reminder · today" : "Due \(start.formatted(date: .omitted, time: .shortened))"
        }
        if isAllDay { return "All day" }
        if start <= now && end > now { return "Now · until \(end.formatted(date: .omitted, time: .shortened))" }
        return start.formatted(date: .omitted, time: .shortened)
    }
}

struct CalendarReadResult: Sendable {
    let calendars: [CalendarSource]
    let events: [CalendarEvent]
}

enum CalendarAgenda {
    static func events(
        _ events: [CalendarEvent], on day: Date,
        configuration: CalendarConfiguration,
        upcomingFrom now: Date? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [CalendarEvent] {
        events.filter { event in
            (configuration.selectedCalendarIDs?.contains(event.calendarID) ?? true)
                && (configuration.includesAllDayEvents || !event.isAllDay)
                && event.occurs(on: day, calendar: calendar)
                && (now.map { event.end > $0 || (event.start == event.end && event.start >= $0) } ?? true)
        }.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }

    static func monthDays(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        let offset = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        guard let first = calendar.date(byAdding: .day, value: -offset, to: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    static func queryIntervals(month: Date, today: Date, calendar: Calendar = .autoupdatingCurrent) -> [DateInterval] {
        let days = monthDays(containing: month, calendar: calendar)
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last),
              let currentDay = calendar.dateInterval(of: .day, for: today) else { return [] }
        let grid = DateInterval(start: first, end: end)
        return today >= first && today < end ? [grid] : [grid, currentDay]
    }
}

enum CalendarMeetingLink {
    // Treat invite contents as data. Only open supported HTTPS meeting hosts
    // after an explicit click; never arbitrary file/custom-scheme URLs.
    static func find(url: URL?, location: String?, notes: String?) -> URL? {
        if let url, isSupported(url) { return url }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in [location, notes].compactMap({ $0 }) {
            for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let url = match.url, isSupported(url) { return url }
            }
        }
        return nil
    }

    static func isSupported(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil,
              url.password == nil, let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased()
        if host == "meet.google.com" { return path.count > 1 }
        if host == "zoom.us" || host.hasSuffix(".zoom.us") || host == "zoom.com" || host.hasSuffix(".zoom.com") {
            return path.hasPrefix("/j/") || path.hasPrefix("/my/") || path.hasPrefix("/s/")
        }
        if host == "teams.microsoft.com" || host == "teams.live.com" || host == "teams.cloud.microsoft" {
            return path.hasPrefix("/l/meetup-join/") || path.hasPrefix("/meet/")
        }
        return false
    }
}
