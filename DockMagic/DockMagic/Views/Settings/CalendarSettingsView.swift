import SwiftUI

@MainActor
struct CalendarSettingsView: View {
    let store: CalendarStore
    let isActive: Bool
    @State private var showsDashboard = false
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Live Dock preview", detail: isActive ? "Calendar is active in your Dock." : "Choose Calendar as your active feature to show it in the Dock.") {
                HStack(spacing: DSSpacing.xLarge) {
                    DockTileView(presentation: .calendar(date: store.currentDate, events: store.todayDockItems, configuration: store.configuration,
                        access: store.dockAccess, isLoading: store.isLoading, hasError: store.dockHasError), animatesChanges: false)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.calendar.preview")
                    VStack(alignment: .leading, spacing: DSSpacing.compact) {
                        Text(store.currentDate.formatted(date: .complete, time: .omitted))
                            .font(DSTypography.panelTitle).foregroundStyle(theme.textPrimary)
                        Text("Today's events and due reminders on the Dock. Hover to browse your agenda and make changes.")
                            .font(DSTypography.body).foregroundStyle(theme.textSecondary)
                        Button("Open Apple Calendar", action: CalendarStore.openCalendar)
                            .buttonStyle(DSButtonStyle())
                        Button("Preview dashboard") { showsDashboard = true }
                            .buttonStyle(DSButtonStyle())
                            .accessibilityIdentifier("settings.calendar.dashboard")
                            .dsDialog(isPresented: $showsDashboard) {
                                VStack(spacing: DSSpacing.standard) {
                                    CalendarHoverDashboardView(store: store)
                                        .frame(width: 432, height: 564)
                                    DSDivider()
                                    HStack {
                                        Spacer()
                                        Button("Done") { showsDashboard = false }
                                            .buttonStyle(DSButtonStyle())
                                            .keyboardShortcut(.cancelAction)
                                            .accessibilityIdentifier("calendar.closePreview")
                                    }
                                }
                                .padding(DSSpacing.large)
                                .background(theme.surface)
                            }
                    }
                }
            }
            DSSettingsSection(title: "Calendar connection", detail: "Uses the accounts in Apple Calendar. Changes you save here update the same events; your accounts handle syncing to other devices.") {
                CalendarConnectionView(store: store)
            }
            DSSettingsSection(title: "Reminders connection", detail: "Calendar and Reminders have separate permissions. No duplicate events are created from your reminders.") {
                CalendarRemindersConnectionView(store: store)
                Button("Open Apple Reminders", action: CalendarStore.openReminders).buttonStyle(DSButtonStyle())
            }
            DSSettingsSection(title: "Dock display", detail: "Date works without access. Agenda layouts show today's remaining events and due reminders.") {
                VStack(spacing: DSSpacing.standard) {
                    DSSelect(title: "Layout", selection: Binding(get: { store.configuration.layout }, set: { value in store.updateConfiguration { $0.layout = value } }),
                             options: CalendarDockLayout.allCases.map { .init(value: $0, title: $0.title) })
                    .accessibilityIdentifier("settings.calendar.layout")
                    DSDivider()
                    Toggle("Include all-day events", isOn: Binding(get: { store.configuration.includesAllDayEvents }, set: { value in store.updateConfiguration { $0.includesAllDayEvents = value } }))
                        .accessibilityIdentifier("settings.calendar.allDay")
                    Toggle("Show call button", isOn: Binding(get: { store.configuration.showsCallButton }, set: { value in store.updateConfiguration { $0.showsCallButton = value } }))
                        .accessibilityIdentifier("settings.calendar.callButton")
                    Text("Open Google Meet, Zoom, or Microsoft Teams links from event URLs, locations, or notes.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DSDivider()
                    Toggle("Show reminders", isOn: Binding(get: { store.configuration.showsReminders }, set: { value in store.updateConfiguration { $0.showsReminders = value } }))
                        .accessibilityIdentifier("settings.calendar.showReminders")
                    Toggle("Show completed reminders", isOn: Binding(get: { store.configuration.showsCompletedReminders }, set: { value in store.updateConfiguration { $0.showsCompletedReminders = value } }))
                        .accessibilityIdentifier("settings.calendar.showCompleted")
                    Text("Today's agenda includes overdue and undated reminders. The Dock shows unfinished reminders with a due date.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                }
            }
            if store.access == .fullAccess {
                DSSettingsSection(title: "Calendars", detail: "Choose which calendars appear in the Dock and dashboard.") {
                    VStack(alignment: .leading, spacing: DSSpacing.standard) {
                        HStack {
                            Button("All calendars") { store.updateConfiguration { $0.selectedCalendarIDs = nil } }
                            Button("None") { store.updateConfiguration { $0.selectedCalendarIDs = [] } }
                            Spacer()
                            Button("Refresh") { store.reload() }.disabled(store.isLoading)
                        }.buttonStyle(DSButtonStyle())
                        if store.isLoading && store.calendars.isEmpty { ProgressView("Loading calendars…") }
                        else if store.calendars.isEmpty { Text("No calendars found. Add an account in Apple Calendar.").foregroundStyle(theme.textSecondary) }
                        ForEach(store.calendars) { source in
                            DSDivider()
                            Toggle(isOn: Binding(get: { store.configuration.selectedCalendarIDs?.contains(source.id) ?? true }, set: { store.setCalendar(source.id, included: $0) })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.title).font(DSTypography.bodyEmphasis)
                                    Text(source.account).font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                                    if !source.allowsModifications { Text("Read-only").font(DSTypography.caption).foregroundStyle(theme.textSecondary) }
                                }
                            }
                            .accessibilityIdentifier("settings.calendar.source.\(source.id)")
                        }
                        if store.missingSelectionCount > 0 {
                            Text("\(store.missingSelectionCount) selected calendar(s) are unavailable. Check your accounts or choose calendars again.")
                                .font(DSTypography.metadata).foregroundStyle(theme.warningForeground)
                        }
                    }
                }
            }
            if store.reminderAccess == .fullAccess {
                DSSettingsSection(title: "Reminder lists", detail: "Choose lists for the dashboard and Dock. All lists also includes lists added later.") {
                    VStack(alignment: .leading, spacing: DSSpacing.standard) {
                        HStack {
                            Button("All lists") { store.updateConfiguration { $0.selectedReminderListIDs = nil } }
                            Button("None") { store.updateConfiguration { $0.selectedReminderListIDs = [] } }
                            Spacer()
                            Button("Refresh") { store.reload() }.disabled(store.isLoading)
                        }.buttonStyle(DSButtonStyle())
                        if store.reminderLists.isEmpty {
                            Text(store.isLoading ? "Loading reminder lists…" : "No lists found. Add a list in Apple Reminders.")
                                .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        }
                        ForEach(store.reminderLists) { source in
                            DSDivider()
                            Toggle(isOn: Binding(get: { store.configuration.selectedReminderListIDs?.contains(source.id) ?? true },
                                set: { store.setReminderList(source.id, included: $0) })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.title).font(DSTypography.bodyEmphasis)
                                    Text(source.account + (source.allowsModifications ? "" : " · Read-only"))
                                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                                }
                            }.accessibilityIdentifier("settings.calendar.reminderList.\(source.id)")
                        }
                        if store.missingReminderSelectionCount > 0 {
                            Text("\(store.missingReminderSelectionCount) selected list(s) are unavailable. Check your accounts or choose lists again.")
                                .font(DSTypography.metadata).foregroundStyle(theme.warningForeground)
                        }
                    }
                }
            }
        }
        .onAppear { store.setInterest(.settings, active: true) }
        .onDisappear { store.setInterest(.settings, active: false) }
    }
}
