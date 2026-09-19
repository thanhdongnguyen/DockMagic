import SwiftUI

@MainActor
struct CalendarHoverDashboardView: View {
    let store: CalendarStore
    @Environment(\.designTheme) private var theme
    @State private var showsAllReminders = false

    var body: some View {
        VStack(spacing: DSSpacing.standard) {
            HStack {
                DSLabel("Calendar", systemImage: "calendar")
                    .font(DSTypography.panelTitle)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button("Open Calendar", action: CalendarStore.openCalendar)
                    .buttonStyle(DSContentButtonStyle()).foregroundStyle(theme.actionForeground)
                    .font(DSTypography.metadata)
                    .accessibilityIdentifier("calendar.openApp")
            }
            monthNavigation
            monthGrid
            HStack {
                Button("New event") { store.openEditor(kind: .event) }
                    .disabled(store.access != .fullAccess || store.writableCalendars.isEmpty)
                    .accessibilityIdentifier("calendar.newEvent")
                Button("New reminder") { store.openEditor(kind: .reminder) }
                    .disabled(store.reminderAccess != .fullAccess || store.writableReminderLists.isEmpty)
                    .accessibilityIdentifier("calendar.newReminder")
                Spacer()
                Toggle("All reminders", isOn: $showsAllReminders)
                    .toggleStyle(DSCheckboxStyle()).font(DSTypography.caption)
                    .accessibilityIdentifier("calendar.allReminders")
            }
            .buttonStyle(.borderless).font(DSTypography.metadata)
            DSDivider()
            HStack {
                Text(showsAllReminders ? "Reminders" : store.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary)
                Spacer()
                if store.isLoading { ProgressView().controlSize(.small).accessibilityLabel("Loading events") }
                Button { store.reload() } label: { DSIcon(systemName: "arrow.clockwise") }
                    .buttonStyle(DSContentButtonStyle()).foregroundStyle(theme.textSecondary)
                    .help("Refresh events").accessibilityLabel("Refresh events")
                    .accessibilityIdentifier("calendar.refresh")
            }
            agenda
            HStack {
                Text("\(TimeZone.autoupdatingCurrent.abbreviation() ?? TimeZone.autoupdatingCurrent.identifier) · Changes sync to this Mac")
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                Spacer()
                if let updated = [store.lastUpdated, store.lastRemindersUpdated].compactMap({ $0 }).max() {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar dashboard")
        .accessibilityIdentifier("dockHover.calendar")
    }

    private var monthNavigation: some View {
        HStack {
            Text(store.displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(DSTypography.headline).foregroundStyle(theme.textPrimary)
            Spacer()
            Button { store.moveMonth(-1) } label: { DSIcon(systemName: "chevron.left") }
                .accessibilityLabel("Previous month").help("Previous month")
                .accessibilityIdentifier("calendar.previousMonth")
            Button("Today") { store.showToday() }
                .accessibilityIdentifier("calendar.today")
            Button { store.moveMonth(1) } label: { DSIcon(systemName: "chevron.right") }
                .accessibilityLabel("Next month").help("Next month")
                .accessibilityIdentifier("calendar.nextMonth")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(theme.actionForeground)
    }

    private var monthGrid: some View {
        let calendar = Calendar.autoupdatingCurrent
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return VStack(spacing: DSSpacing.compact) {
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    Text(symbols[(index + calendar.firstWeekday - 1) % 7])
                        .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(CalendarAgenda.monthDays(containing: store.displayedMonth), id: \.self) { day in
                    dayButton(day, calendar: calendar)
                }
            }
        }
    }

    private func dayButton(_ day: Date, calendar: Calendar) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: store.selectedDate)
        let today = calendar.isDate(day, inSameDayAs: store.currentDate)
        let inMonth = calendar.isDate(day, equalTo: store.displayedMonth, toGranularity: .month)
        let count = CalendarAgenda.events(store.events, on: day, configuration: store.configuration).count
            + (store.configuration.showsReminders ? store.reminders.filter {
                (store.configuration.selectedReminderListIDs?.contains($0.calendarID) ?? true)
                    && (!$0.isCompleted || store.configuration.showsCompletedReminders) && $0.occurs(on: day)
            }.count : 0)
        return Button { store.selectDay(day) } label: {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.day()))
                    .dsFont(size: 13, weight: today || selected ? .bold : .medium)
                Circle().fill(selected ? theme.onAction : theme.textPrimary)
                    .frame(width: 3, height: 3).opacity(count > 0 ? 1 : 0)
            }
            .foregroundStyle(selected ? theme.onAction : inMonth ? theme.textPrimary : theme.textSecondary)
            .frame(maxWidth: .infinity).frame(height: 29)
            .background {
                if selected { RoundedRectangle(cornerRadius: DSRadius.fixedSmall).fill(theme.action) }
            }
            .overlay {
                if today { RoundedRectangle(cornerRadius: DSRadius.fixedSmall).strokeBorder(selected ? theme.onAction : theme.outlineStrong, lineWidth: 1.5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DSContentButtonStyle())
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue("\(today ? "Today, " : "")\(count) items\(selected ? ", selected" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var agenda: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.standard) {
                if let error = store.mutationError {
                    Text(error).font(DSTypography.metadata).foregroundStyle(theme.dangerForeground)
                }
                if !showsAllReminders {
                    if store.access != .fullAccess { CalendarConnectionView(store: store) }
                    else if let error = store.errorMessage {
                        emptyState("Calendar unavailable", detail: error, symbol: "exclamationmark.triangle")
                    } else if store.isLoading && store.lastUpdated == nil {
                        Text("Loading events…").font(DSTypography.metadata)
                    } else if store.configuration.selectedCalendarIDs?.isEmpty == true {
                        emptyState("No calendars selected", detail: "Choose calendars in Calendar Settings.", symbol: "calendar.badge.minus")
                    } else if store.missingSelectionCount > 0 && store.selectedDayEvents.isEmpty {
                        emptyState("Selected calendar unavailable", detail: "Check your accounts and select calendars again in Settings.", symbol: "calendar.badge.exclamationmark")
                    } else if store.selectedDayEvents.isEmpty {
                        emptyState("No events", detail: "Your selected calendars are clear for this day.", symbol: "calendar")
                    }
                    ForEach(store.selectedDayEvents) { event in
                        eventRow(event)
                        DSDivider()
                    }
                }
                if store.configuration.showsReminders || showsAllReminders {
                    if !showsAllReminders { Text("Reminders").font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary) }
                    if !store.configuration.showsReminders {
                        Text("Enable Show reminders in Calendar Settings.").font(DSTypography.metadata)
                    } else if store.reminderAccess != .fullAccess {
                        CalendarRemindersConnectionView(store: store)
                    } else if let error = store.remindersErrorMessage {
                        emptyState("Reminders unavailable", detail: error, symbol: "exclamationmark.triangle")
                    } else if store.isLoading && store.lastRemindersUpdated == nil {
                        Text("Loading reminders…").font(DSTypography.metadata)
                    } else if store.configuration.selectedReminderListIDs?.isEmpty == true {
                        Text("No reminder lists selected. Choose lists in Calendar Settings.").font(DSTypography.metadata)
                    } else {
                        let reminders = showsAllReminders ? store.visibleReminders : store.selectedDayReminders
                        if reminders.isEmpty { Text("No reminders").font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
                        ForEach(reminders) { reminder in
                            reminderRow(reminder)
                            DSDivider()
                        }
                    }
                }
            }
            .padding(.vertical, DSSpacing.compact)
            // Keep row actions clear of macOS overlay scroll indicators.
            .padding(.trailing, DSSpacing.large)
        }
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("calendar.agenda")
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.standard) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.timeLabel(now: store.currentDate))
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                Text(event.title).font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary).lineLimit(2).help(event.title)
                Text(event.calendarTitle + (event.location.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? ""))
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if store.configuration.showsCallButton, let url = event.meetingURL {
                Link(destination: url) { DSLabel("Join", systemImage: "video") }
                    .font(DSTypography.metadata).foregroundStyle(theme.actionForeground)
                    .help("Open meeting link for \(event.title)")
                    .accessibilityLabel("Join \(event.title)")
            }
            Button { store.openEditor(kind: .event, event: event) } label: {
                DSIcon(systemName: event.isReadOnly ? "info.circle" : "pencil")
            }
            .buttonStyle(DSIconButtonStyle(visualSize: 22, hitSize: 28)).foregroundStyle(theme.textSecondary)
            .disabled(store.isSaving)
            .help("\(event.isReadOnly ? "View" : "Edit") \(event.title)")
            .accessibilityLabel("\(event.isReadOnly ? "View" : "Edit") \(event.title)")
            .accessibilityIdentifier("calendar.editEvent.\(event.id)")
        }
        .padding(.vertical, DSSpacing.standard)
        .accessibilityElement(children: .contain)
    }

    private func reminderRow(_ reminder: CalendarReminder) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.standard) {
            Button {
                Task { _ = await store.setReminderCompleted(reminder, completed: !reminder.isCompleted) }
            } label: {
                DSIcon(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .dsFont(size: 17)
            }
            .buttonStyle(DSIconButtonStyle(visualSize: 24, hitSize: 30)).foregroundStyle(theme.textPrimary)
            .disabled(reminder.isReadOnly || store.isSaving || store.reminderAccess != .fullAccess)
            .help(reminder.isCompleted ? "Mark incomplete" : "Complete reminder")
            .accessibilityLabel("\(reminder.isCompleted ? "Mark incomplete" : "Complete") \(reminder.title)")
            .accessibilityIdentifier("calendar.completeReminder.\(reminder.id)")
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title).font(DSTypography.bodyEmphasis).strikethrough(reminder.isCompleted)
                    .foregroundStyle(theme.textPrimary).lineLimit(2)
                Text("\(reminder.calendarTitle) · \(reminder.dueLabel(now: store.currentDate))")
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button { store.openEditor(kind: .reminder, reminder: reminder) } label: {
                DSIcon(systemName: reminder.isReadOnly ? "info.circle" : "pencil")
            }
            .buttonStyle(DSIconButtonStyle(visualSize: 22, hitSize: 28)).foregroundStyle(theme.textSecondary)
            .disabled(store.isSaving)
            .help("Edit \(reminder.title)").accessibilityLabel("Edit \(reminder.title)")
            .accessibilityIdentifier("calendar.editReminder.\(reminder.id)")
        }
        .padding(.vertical, DSSpacing.compact)
        .accessibilityElement(children: .contain)
    }

    private func emptyState(_ title: String, detail: String, symbol: String) -> some View {
        DSEmptyState(title: title, detail: detail, icon: DSIconName.fromLegacySymbol(symbol) ?? .info)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
struct CalendarConnectionView: View {
    let store: CalendarStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.standard) {
            DSLabel(store.access == .fullAccess ? "Calendar connected" : "Calendar access", systemImage: store.access == .fullAccess ? "checkmark.circle" : "lock")
                .font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary)
            Text(store.access.message).font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
            if let error = store.errorMessage {
                Text(error).font(DSTypography.metadata).foregroundStyle(theme.dangerForeground)
            }
            if store.access == .notDetermined || store.access == .writeOnly {
                Text("Full Access lets DockMagic display events and save the changes you make here to Apple Calendar.")
                    .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                Button(store.isConnecting ? "Connecting…" : "Connect Calendar") {
                    Task { await store.connect() }
                }
                .buttonStyle(DSButtonStyle(emphasis: .primary)).disabled(store.isConnecting)
                .accessibilityIdentifier("calendar.connect")
            } else if store.access == .denied {
                Button("Open Privacy Settings", action: CalendarStore.openPrivacySettings)
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("calendar.privacySettings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
struct CalendarRemindersConnectionView: View {
    let store: CalendarStore
    @Environment(\.designTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.compact) {
            DSLabel(store.reminderAccess == .fullAccess ? "Reminders connected" : "Reminders access",
                  systemImage: store.reminderAccess == .fullAccess ? "checkmark.circle" : "lock")
                .font(DSTypography.bodyEmphasis).foregroundStyle(theme.textPrimary)
            Text(message).font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
            if let error = store.remindersErrorMessage {
                Text(error).font(DSTypography.metadata).foregroundStyle(theme.dangerForeground)
            }
            if store.reminderAccess == .notDetermined || store.reminderAccess == .writeOnly {
                Button(store.isConnectingReminders ? "Connecting…" : "Connect Reminders") {
                    Task { await store.connectReminders() }
                }
                .buttonStyle(DSButtonStyle(emphasis: .primary)).disabled(store.isConnectingReminders)
                .accessibilityIdentifier("calendar.connectReminders")
            } else if store.reminderAccess == .denied {
                Button("Open Reminders Privacy Settings", action: CalendarStore.openRemindersPrivacySettings)
                    .buttonStyle(DSButtonStyle()).accessibilityIdentifier("calendar.remindersPrivacySettings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var message: String {
        switch store.reminderAccess {
        case .fullAccess: "Changes you make here are saved to Apple Reminders. Changes on this Mac appear here automatically."
        case .denied: "Allow DockMagic in System Settings → Privacy & Security → Reminders."
        case .restricted: "Reminders access is restricted on this Mac."
        case .notDetermined, .writeOnly: "Connect to see, create, edit and complete reminders from the lists on this Mac."
        }
    }
}
