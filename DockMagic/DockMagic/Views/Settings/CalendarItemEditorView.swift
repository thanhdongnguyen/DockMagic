import SwiftUI

@MainActor
struct CalendarItemEditorView: View {
    let store: CalendarStore
    let kind: CalendarEditKind
    let event: CalendarEvent?
    let reminder: CalendarReminder?
    var onDirty: (Bool) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onSaved: () -> Void = {}
    @State private var eventDraft: CalendarEventDraft
    @State private var reminderDraft: CalendarReminderDraft
    private let initialEventDraft: CalendarEventDraft
    private let initialReminderDraft: CalendarReminderDraft
    @State private var confirmsDelete = false
    @Environment(\.designTheme) private var theme

    init(store: CalendarStore, kind: CalendarEditKind, event: CalendarEvent? = nil, reminder: CalendarReminder? = nil,
         onDirty: @escaping (Bool) -> Void = { _ in }, onCancel: @escaping () -> Void = {}, onSaved: @escaping () -> Void = {}) {
        self.store = store; self.kind = kind; self.event = event; self.reminder = reminder
        self.onDirty = onDirty; self.onCancel = onCancel; self.onSaved = onSaved
        let calendarID = store.writableCalendars.first { store.configuration.selectedCalendarIDs?.contains($0.id) ?? true }?.id
            ?? store.writableCalendars.first?.id ?? ""
        let listID = store.writableReminderLists.first { store.configuration.selectedReminderListIDs?.contains($0.id) ?? true }?.id
            ?? store.writableReminderLists.first?.id ?? ""
        let calendar = Calendar.autoupdatingCurrent
        let date = calendar.date(bySettingHour: min(23, calendar.component(.hour, from: store.currentDate) + 1),
                                 minute: 0, second: 0, of: store.selectedDate) ?? store.selectedDate
        let eventDraft = event.map(CalendarEventDraft.init) ?? CalendarEventDraft(calendarID: calendarID, date: date)
        let reminderDraft = reminder.map(CalendarReminderDraft.init) ?? CalendarReminderDraft(calendarID: listID, date: date)
        _eventDraft = State(initialValue: eventDraft); initialEventDraft = eventDraft
        _reminderDraft = State(initialValue: reminderDraft); initialReminderDraft = reminderDraft
    }

    private var isNew: Bool { event == nil && reminder == nil }
    private var readOnly: Bool { event?.isReadOnly == true || reminder?.isReadOnly == true }
    private var hasAccess: Bool { (kind == .event ? store.access : store.reminderAccess) == .fullAccess }
    private var validationMessage: String? {
        do {
            if kind == .event { try eventDraft.validate() } else { try reminderDraft.validate() }
            return nil
        } catch { return error.localizedDescription }
    }
    private var destinationExists: Bool {
        kind == .event ? store.writableCalendars.contains { $0.id == eventDraft.calendarID }
            : store.writableReminderLists.contains { $0.id == reminderDraft.calendarID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.standard) {
            Text("\(isNew ? "New" : "Edit") \(kind.title.lowercased())")
                .font(DSTypography.headline).foregroundStyle(theme.textPrimary)
            Text(kind == .event ? "Saved directly to Apple Calendar." : "Saved directly to Apple Reminders.")
                .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.fieldGroup) {
                    if kind == .event { eventFields } else { reminderFields }
                }
                .disabled(store.isSaving || readOnly || !hasAccess)
            }
            if !hasAccess {
                notice("Access is unavailable. Reconnect in Calendar Settings.")
            } else if readOnly { notice("This item belongs to a read-only calendar or list.") }
            else if !destinationExists { notice("Choose a writable destination. Add an account in Apple Calendar or Reminders if none are available.") }
            if event?.isRecurring == true {
                notice("Changes and deletion affect this occurrence only. Use Apple Calendar to edit the repeat schedule.")
            }
            if reminder?.isRecurring == true {
                notice("The existing repeat rule is preserved. Completing this reminder lets Reminders schedule the next occurrence. Deleting removes the repeating reminder.")
            }
            if let error = store.mutationError {
                Text(error).font(DSTypography.metadata).foregroundStyle(theme.dangerForeground)
                    .accessibilityIdentifier("calendar.editor.error")
            } else if let validationMessage, !readOnly {
                notice(validationMessage)
            }
            DSDivider()
            HStack {
                if !isNew {
                    Button("Delete…", role: .destructive) { confirmsDelete = true }
                        .buttonStyle(DSButtonStyle()).disabled(store.isSaving || readOnly || !hasAccess)
                        .accessibilityIdentifier("calendar.editor.delete")
                }
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(DSButtonStyle())
                    .keyboardShortcut(.cancelAction).disabled(store.isSaving)
                    .accessibilityIdentifier("calendar.editor.cancel")
                Button(store.isSaving ? "Saving…" : "Save") { Task { await save() } }
                    .buttonStyle(DSButtonStyle(emphasis: .primary)).keyboardShortcut(.defaultAction)
                    .disabled(store.isSaving || readOnly || !hasAccess || !destinationExists || validationMessage != nil)
                    .accessibilityIdentifier("calendar.editor.save")
            }
        }
        .padding(DSSpacing.large)
        .frame(width: 520, height: 610)
        .background(theme.surface)
        .onChange(of: eventDraft) { _, value in onDirty(value != initialEventDraft) }
        .onChange(of: reminderDraft) { _, value in onDirty(value != initialReminderDraft) }
        .dsAlert("Delete this \(kind.title.lowercased())?", isPresented: $confirmsDelete) {
            DSDialogButton("Delete", role: .destructive) { Task { await delete() } }
            DSDialogButton("Cancel", role: .cancel) {}
        } message: {
            Text(kind == .event
                ? "This removes the event from Apple Calendar and its connected account. For a repeating event, only this occurrence is removed."
                : "This removes the reminder from Apple Reminders and its connected account, including its repeat rule.")
        }
    }

    private var eventFields: some View {
        Group {
            DSField(title: "Title") { DSTextInput(title: "Title", text: $eventDraft.title) }.accessibilityIdentifier("calendar.editor.title")
            DSSelect(title: "Calendar", selection: $eventDraft.calendarID,
                     options: (destinationExists ? [] : [.init(value: eventDraft.calendarID, title: event?.calendarTitle ?? "Choose calendar", disabled: true)])
                        + store.writableCalendars.map { .init(value: $0.id, title: "\($0.title) · \($0.account)") }, searchable: true).accessibilityIdentifier("calendar.editor.destination")
            Toggle("All day", isOn: $eventDraft.isAllDay).accessibilityIdentifier("calendar.editor.allDay")
                .onChange(of: eventDraft.isAllDay) { _, allDay in
                    if allDay { eventDraft.normalizeAllDayRange() }
                }
            DatePicker("Starts", selection: $eventDraft.start, displayedComponents: eventDraft.isAllDay ? [.date] : [.date, .hourAndMinute])
                .accessibilityIdentifier("calendar.editor.start")
            DatePicker("Ends", selection: eventEndBinding,
                       displayedComponents: eventDraft.isAllDay ? [.date] : [.date, .hourAndMinute])
                .accessibilityIdentifier("calendar.editor.end")
            DSField(title: "Location") { DSTextInput(title: "Location", text: $eventDraft.location) }.accessibilityIdentifier("calendar.editor.location")
            DSField(title: "URL") { DSTextInput(title: "URL", text: $eventDraft.url) }.accessibilityIdentifier("calendar.editor.url")
            DSTextArea(title: "Notes", text: $eventDraft.notes)
                .accessibilityIdentifier("calendar.editor.notes")
        }
        .textFieldStyle(DSInputStyle())
    }

    private var reminderFields: some View {
        Group {
            DSField(title: "Title") { DSTextInput(title: "Title", text: $reminderDraft.title) }.accessibilityIdentifier("calendar.editor.title")
            DSSelect(title: "List", selection: $reminderDraft.calendarID,
                     options: (destinationExists ? [] : [.init(value: reminderDraft.calendarID, title: reminder?.calendarTitle ?? "Choose list", disabled: true)])
                        + store.writableReminderLists.map { .init(value: $0.id, title: "\($0.title) · \($0.account)") }, searchable: true).accessibilityIdentifier("calendar.editor.destination")
            Toggle("Due date", isOn: $reminderDraft.hasDueDate).accessibilityIdentifier("calendar.editor.hasDueDate")
            if reminderDraft.hasDueDate {
                Toggle("Include time", isOn: $reminderDraft.includesTime).accessibilityIdentifier("calendar.editor.includesTime")
                DatePicker("Due", selection: $reminderDraft.dueDate, displayedComponents: reminderDraft.includesTime ? [.date, .hourAndMinute] : [.date])
                    .accessibilityIdentifier("calendar.editor.due")
            }
            DSSelect(title: "Priority", selection: $reminderDraft.priority,
                     options: [.init(value: 0, title: "None"), .init(value: 1, title: "High"), .init(value: 5, title: "Medium"), .init(value: 9, title: "Low")]
                        + ([0, 1, 5, 9].contains(reminderDraft.priority) ? [] : [.init(value: reminderDraft.priority, title: "Priority \(reminderDraft.priority)")]))
            Toggle("Completed", isOn: $reminderDraft.isCompleted).accessibilityIdentifier("calendar.editor.completed")
            DSTextArea(title: "Notes", text: $reminderDraft.notes)
                .accessibilityIdentifier("calendar.editor.notes")
        }
        .textFieldStyle(DSInputStyle())
    }

    private var eventEndBinding: Binding<Date> {
        Binding(get: { eventDraft.displayedEndDate() }, set: { eventDraft.setDisplayedEndDate($0) })
    }

    private func notice(_ text: String) -> some View {
        Text(text).font(DSTypography.metadata).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
    }
    private func save() async {
        let success = kind == .event
            ? await store.saveEvent(eventDraft, original: event)
            : await store.saveReminder(reminderDraft, original: reminder)
        if success { onSaved() }
    }
    private func delete() async {
        let success: Bool
        if let event { success = await store.deleteEvent(event) }
        else if let reminder { success = await store.deleteReminder(reminder) }
        else { return }
        if success { onSaved() }
    }
}
