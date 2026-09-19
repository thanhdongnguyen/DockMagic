import EventKit
import XCTest
@testable import DockMagic

final class CalendarSyncTests: XCTestCase {
    @MainActor private func makeStore(_ provider: CalendarUITestProvider) -> CalendarStore {
        let name = "CalendarSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return CalendarStore(provider: provider, defaults: defaults)
    }
    private func provider() -> CalendarUITestProvider {
        CalendarUITestProvider(access: "fullAccess", remindersAccess: "fullAccess")
    }

    @MainActor func testExistingPreferencesMigrateWithoutLosingCalendarSelection() throws {
        let data = Data(#"{"layout":"dateAndAgenda","selectedCalendarIDs":[],"includesAllDayEvents":false,"showsCallButton":false}"#.utf8)
        let result = try JSONDecoder().decode(CalendarConfiguration.self, from: data)
        XCTAssertEqual(result.layout, .dateAndAgenda)
        XCTAssertEqual(result.selectedCalendarIDs, [])
        XCTAssertFalse(result.includesAllDayEvents)
        XCTAssertFalse(result.showsCallButton)
        XCTAssertTrue(result.showsReminders)
        XCTAssertFalse(result.showsCompletedReminders)
        XCTAssertNil(result.selectedReminderListIDs)
    }

    @MainActor func testReminderFilteringDateOnlyOverdueUndatedCompletedAndSelection() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        var components = DateComponents(year: 2026, month: 3, day: 8)
        components.calendar = calendar
        let today = CalendarReminder(id: "today", calendarID: "tasks", calendarTitle: "Tasks", title: "Today", dueDateComponents: components)
        var yesterday = today; yesterday.dueDateComponents?.day = 7
        let undated = CalendarReminder(id: "undated", calendarID: "tasks", calendarTitle: "Tasks", title: "Undated")
        var completed = today; completed.isCompleted = true
        XCTAssertFalse(today.isOverdue(at: now, calendar: calendar))
        XCTAssertTrue(yesterday.isOverdue(at: now, calendar: calendar))
        XCTAssertTrue(today.occurs(on: now, calendar: calendar))
        XCTAssertFalse(undated.occurs(on: now, calendar: calendar))
        var config = CalendarConfiguration()
        XCTAssertEqual(CalendarReminderAgenda.items([today, yesterday, undated, completed], configuration: config, on: now, today: now, calendar: calendar).count, 3)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        XCTAssertTrue(CalendarReminderAgenda.items([today, yesterday, undated], configuration: config, on: tomorrow, today: now, calendar: calendar).isEmpty)
        config.showsCompletedReminders = true
        XCTAssertEqual(CalendarReminderAgenda.items([today, completed], configuration: config, today: now).count, 2)
        config.selectedReminderListIDs = []
        XCTAssertTrue(CalendarReminderAgenda.items([today], configuration: config, today: now).isEmpty)
        config.selectedReminderListIDs = ["missing"]
        XCTAssertTrue(CalendarReminderAgenda.items([today], configuration: config, today: now).isEmpty)
    }

    @MainActor func testPermissionsAreIndependentAndNeverRequestedByRefresh() async {
        let provider = CalendarUITestProvider(access: "denied", remindersAccess: "notDetermined")
        let store = makeStore(provider)
        await store.refresh()
        let requests = await provider.requests
        let reminderRequests = await provider.reminderRequests
        XCTAssertEqual(requests, 0); XCTAssertEqual(reminderRequests, 0)
        await store.connectReminders()
        XCTAssertEqual(store.reminderAccess, .fullAccess)
        XCTAssertEqual(store.access, .denied)
        XCTAssertFalse(store.reminders.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.dockAccess, .fullAccess)
        XCTAssertTrue(store.todayDockItems.allSatisfy(\.isReminder))
        let after = await provider.requests
        let reminderAfter = await provider.reminderRequests
        XCTAssertEqual(after, 0); XCTAssertEqual(reminderAfter, 1)
    }

    @MainActor func testEventCreateEditMoveDeleteCommitsThenReadsNativeValues() async throws {
        let provider = provider(); let store = makeStore(provider)
        await store.refresh()
        var draft = CalendarEventDraft(calendarID: "work", date: Date())
        draft.title = "Created in DockMagic"; draft.notes = "Preserve notes"
        let created = await store.saveEvent(draft, original: nil)
        XCTAssertTrue(created)
        let first = try XCTUnwrap(store.events.first { $0.title == draft.title })
        let native = await provider.nativeEvents
        XCTAssertEqual(native.first { $0.id == first.id }, first)
        draft = CalendarEventDraft(event: first); draft.title = "Edited"; draft.calendarID = "personal"
        let saved = await store.saveEvent(draft, original: first)
        XCTAssertTrue(saved)
        let edited = try XCTUnwrap(store.events.first { $0.id == first.id })
        XCTAssertEqual(edited.title, "Edited"); XCTAssertEqual(edited.calendarID, "personal")
        XCTAssertEqual(edited.notes, "Preserve notes")
        let removed = await store.deleteEvent(edited)
        XCTAssertTrue(removed)
        XCTAssertFalse(store.events.contains { $0.id == first.id })
        let writes = await provider.writes
        XCTAssertEqual(writes, 3)
    }

    @MainActor func testReminderCreateEditCompleteReopenAndDeleteRoundTrip() async throws {
        let provider = provider(); let store = makeStore(provider)
        await store.refresh()
        var draft = CalendarReminderDraft(calendarID: "tasks", date: Date())
        draft.title = "Created reminder"; draft.hasDueDate = true
        draft.notes = "Detail"; draft.priority = 1
        let created = await store.saveReminder(draft, original: nil)
        XCTAssertTrue(created)
        let first = try XCTUnwrap(store.reminders.first { $0.title == draft.title })
        XCTAssertTrue(store.todayDockItems.contains { $0.id == "reminder:\(first.id)" })
        draft = CalendarReminderDraft(reminder: first); draft.title = "Edited reminder"
        let saved = await store.saveReminder(draft, original: first)
        XCTAssertTrue(saved)
        let edited = try XCTUnwrap(store.reminders.first { $0.id == first.id })
        let completed = await store.setReminderCompleted(edited, completed: true)
        XCTAssertTrue(completed)
        let finished = try XCTUnwrap(store.reminders.first { $0.id == first.id })
        XCTAssertTrue(finished.isCompleted)
        XCTAssertFalse(store.visibleReminders.contains { $0.id == first.id })
        XCTAssertFalse(store.todayDockItems.contains { $0.id == "reminder:\(first.id)" })
        let reopened = await store.setReminderCompleted(finished, completed: false)
        XCTAssertTrue(reopened)
        let current = try XCTUnwrap(store.reminders.first { $0.id == first.id })
        XCTAssertEqual(current.notes, "Detail"); XCTAssertEqual(current.priority, 1)
        let deleted = await store.deleteReminder(current)
        XCTAssertTrue(deleted)
        XCTAssertFalse(store.reminders.contains { $0.id == first.id })
    }

    @MainActor func testExternalNativeChangesArriveThroughEventStoreNotification() async throws {
        let provider = provider(); let store = makeStore(provider)
        store.start()
        defer { store.stop() }
        await store.refresh()
        await provider.simulateExternalEdits()
        NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
        for _ in 0..<100 {
            if store.events.contains(where: { $0.title == "Updated in Apple Calendar" })
                && store.reminders.contains(where: { $0.title == "Updated in Apple Reminders" }) { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(store.events.contains { $0.title == "Updated in Apple Calendar" })
        XCTAssertTrue(store.reminders.contains { $0.title == "Updated in Apple Reminders" })
        let writes = await provider.writes
        XCTAssertEqual(writes, 0, "Reading native updates must never write them back or duplicate them")
    }

    @MainActor func testExternalEditAndDeletionRejectStaleDraftWithoutOverwriting() async throws {
        let provider = provider(); let store = makeStore(provider)
        await store.refresh()
        let event = try XCTUnwrap(store.events.first { $0.id == "planning" })
        let reminder = try XCTUnwrap(store.reminders.first { $0.id == "send" })
        await provider.simulateExternalEdits()
        var draft = CalendarEventDraft(event: event); draft.title = "Stale edit"
        let saved = await store.saveEvent(draft, original: event)
        XCTAssertFalse(saved)
        XCTAssertNotNil(store.mutationError)
        XCTAssertTrue(store.events.contains { $0.title == "Updated in Apple Calendar" })
        let completed = await store.setReminderCompleted(reminder, completed: true)
        XCTAssertFalse(completed)
        await provider.replaceEvents([])
        let retry = await store.saveEvent(draft, original: event)
        XCTAssertFalse(retry); XCTAssertTrue(store.events.isEmpty)
        let writes = await provider.writes
        XCTAssertEqual(writes, 0)
    }

    @MainActor func testWriteFailureReadOnlyAndPermissionLossNeverOptimisticallyChangeData() async throws {
        let provider = provider(); let store = makeStore(provider)
        await store.refresh()
        let reminder = try XCTUnwrap(store.reminders.first { $0.id == "send" })
        await provider.failWrites(.unavailable)
        let failed = await store.setReminderCompleted(reminder, completed: true)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.reminders.first { $0.id == reminder.id }?.isCompleted, false)
        await provider.failWrites(nil)
        let readOnly = try XCTUnwrap(store.reminders.first { $0.isReadOnly })
        let refused = await store.deleteReminder(readOnly)
        XCTAssertFalse(refused)
        await provider.setAccess(calendar: .fullAccess, reminders: .denied)
        let revoked = await store.setReminderCompleted(reminder, completed: true)
        XCTAssertFalse(revoked)
        XCTAssertEqual(store.reminderAccess, .denied)
        XCTAssertTrue(store.reminders.isEmpty); XCTAssertTrue(store.reminderLists.isEmpty)
        XCTAssertFalse(store.events.isEmpty)
        let writes = await provider.writes
        XCTAssertEqual(writes, 0)
    }

    @MainActor func testDuplicateSaveIsBlockedWhileCommitIsPending() async throws {
        let provider = provider(); let store = makeStore(provider)
        await store.refresh(); await provider.delayWrites(.milliseconds(100))
        let reminder = try XCTUnwrap(store.reminders.first { !$0.isReadOnly })
        let first = Task { await store.setReminderCompleted(reminder, completed: true) }
        while !store.isSaving { await Task.yield() }
        let duplicate = await store.setReminderCompleted(reminder, completed: true)
        XCTAssertFalse(duplicate)
        let committed = await first.value
        XCTAssertTrue(committed)
        let writes = await provider.writes
        XCTAssertEqual(writes, 1)
    }

    @MainActor func testSettingsAndEditorKeepMonitoringWhenDockFeatureChanges() {
        let store = makeStore(provider())
        store.start(); store.setInterest(.settings, active: true); store.setInterest(.editor, active: true)
        store.stop()
        XCTAssertTrue(store.isMonitoring)
        store.setInterest(.settings, active: false)
        XCTAssertTrue(store.isMonitoring)
        store.setInterest(.editor, active: false)
        XCTAssertFalse(store.isMonitoring)
    }

    @MainActor func testDraftValidationAndFloatingReminderDates() throws {
        var event = CalendarEventDraft(calendarID: "work", date: Date())
        XCTAssertThrowsError(try event.validate())
        event.title = "Valid"; event.end = event.start
        XCTAssertThrowsError(try event.validate())
        event.end = event.start.addingTimeInterval(3600); event.url = "file:///private"
        XCTAssertThrowsError(try event.validate())
        event.url = "https://meet.google.com/abc-defg-hij"
        XCTAssertNoThrow(try event.validate())
        var reminder = CalendarReminderDraft(calendarID: "tasks", date: Date())
        reminder.title = "Task"; reminder.hasDueDate = true
        XCTAssertNil(reminder.dueComponents?.hour)
        XCTAssertNil(reminder.dueComponents?.timeZone)
        reminder.includesTime = true
        XCTAssertNotNil(reminder.dueComponents?.hour)
        reminder.hasDueDate = false
        XCTAssertNil(reminder.dueComponents)
    }

    @MainActor func testAllDayEditorUsesInclusiveEndAcrossDSTWithoutDroppingLastDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 10))!
        let timedEnd = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 15))!
        var draft = CalendarEventDraft(calendarID: "work", date: start)
        draft.title = "Multi-day"; draft.end = timedEnd; draft.isAllDay = true
        draft.normalizeAllDayRange(calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: draft.end), 9)
        XCTAssertEqual(calendar.component(.day, from: draft.displayedEndDate(calendar: calendar)), 8)
        XCTAssertEqual(draft.end.timeIntervalSince(draft.start), 47 * 3600)
        draft.setDisplayedEndDate(draft.start, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: draft.end), 8)
        XCTAssertNoThrow(try draft.validate())
    }
}
