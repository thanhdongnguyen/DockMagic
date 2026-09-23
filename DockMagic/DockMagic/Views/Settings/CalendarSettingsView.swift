import SwiftUI

@MainActor
struct CalendarSettingsView: View {
    let store: CalendarStore
    let weatherStore: CalendarWeatherStore
    let isActive: Bool
    @State private var showsDashboard = false
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Live Dock preview", detail: isActive ? "Calendar is active in your Dock." : "Choose Calendar as your active feature to show it in the Dock.") {
                HStack(spacing: DSSpacing.xLarge) {
                    DockTileView(presentation: .calendar(date: store.currentDate,
                        hasItems: !store.todayDockItems.isEmpty,
                        currentWeather: weatherStore.currentScene), animatesChanges: false)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.calendar.preview")
                    VStack(alignment: .leading, spacing: DSSpacing.compact) {
                        Text(store.currentDate.formatted(date: .complete, time: .omitted))
                            .font(DSTypography.panelTitle).foregroundStyle(theme.textPrimary)
                        Text("The Dock shows today's date and a red dot when you have calendar items. Hover to browse your agenda and make changes.")
                            .font(DSTypography.body).foregroundStyle(theme.textSecondary)
                        Button("Open Apple Calendar", action: CalendarStore.openCalendar)
                            .buttonStyle(DSButtonStyle())
                        Button("Preview dashboard") { showsDashboard = true }
                            .buttonStyle(DSButtonStyle())
                            .accessibilityIdentifier("settings.calendar.dashboard")
                            .dsDialog(isPresented: $showsDashboard) {
                                VStack(spacing: DSSpacing.standard) {
                                    CalendarHoverDashboardView(store: store, weatherStore: weatherStore,
                                                               weatherInterest: .preview)
                                        .frame(width: 432, height: 704)
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
            DSSettingsSection(title: "Calendar display", detail: "The Dock tile shows the date and an optional red dot. Event and reminder details stay in the dashboard.") {
                Grid(alignment: .leading, horizontalSpacing: DSSpacing.xxLarge, verticalSpacing: DSSpacing.large) {
                    GridRow {
                        calendarDisplayToggle(
                            title: "Include all-day events",
                            detail: "Show all-day items in today’s agenda.",
                            isOn: Binding(
                                get: { store.configuration.includesAllDayEvents },
                                set: { value in store.updateConfiguration { $0.includesAllDayEvents = value } }
                            ),
                            identifier: "settings.calendar.allDay"
                        )
                        calendarDisplayToggle(
                            title: "Show call button",
                            detail: "Open Meet, Zoom, or Teams links from event details.",
                            isOn: Binding(
                                get: { store.configuration.showsCallButton },
                                set: { value in store.updateConfiguration { $0.showsCallButton = value } }
                            ),
                            identifier: "settings.calendar.callButton"
                        )
                    }

                    DSDivider()
                        .gridCellColumns(2)
                        .gridCellUnsizedAxes(.horizontal)

                    GridRow {
                        calendarDisplayToggle(
                            title: "Show reminders",
                            detail: "Include due, overdue, and undated reminders.",
                            isOn: Binding(
                                get: { store.configuration.showsReminders },
                                set: { value in store.updateConfiguration { $0.showsReminders = value } }
                            ),
                            identifier: "settings.calendar.showReminders"
                        )
                        calendarDisplayToggle(
                            title: "Show completed reminders",
                            detail: "Include completed reminders in the agenda.",
                            isOn: Binding(
                                get: { store.configuration.showsCompletedReminders },
                                set: { value in store.updateConfiguration { $0.showsCompletedReminders = value } }
                            ),
                            identifier: "settings.calendar.showCompleted"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if store.access == .fullAccess {
                DSSettingsSection(title: "Calendars", detail: "Choose which calendars appear in the Dock and dashboard.") {
                    VStack(alignment: .leading, spacing: DSSpacing.large) {
                        HStack {
                            Button("All calendars") { store.updateConfiguration { $0.selectedCalendarIDs = nil } }
                            Button("None") { store.updateConfiguration { $0.selectedCalendarIDs = [] } }
                            Spacer()
                            Button("Refresh") { store.reload() }.disabled(store.isLoading)
                        }.buttonStyle(DSButtonStyle())

                        DSDivider()

                        if store.isLoading && store.calendars.isEmpty { ProgressView("Loading calendars…") }
                        else if store.calendars.isEmpty { Text("No calendars found. Add an account in Apple Calendar.").foregroundStyle(theme.textSecondary) }
                        else {
                            LazyVGrid(columns: sourceGridColumns, alignment: .leading, spacing: DSSpacing.large) {
                                ForEach(store.calendars) { source in
                                    calendarSourceToggle(
                                        source,
                                        isOn: Binding(
                                            get: { store.configuration.selectedCalendarIDs?.contains(source.id) ?? true },
                                            set: { store.setCalendar(source.id, included: $0) }
                                        ),
                                        identifier: "settings.calendar.source.\(source.id)"
                                    )
                                }
                            }
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
                    VStack(alignment: .leading, spacing: DSSpacing.large) {
                        HStack {
                            Button("All lists") { store.updateConfiguration { $0.selectedReminderListIDs = nil } }
                            Button("None") { store.updateConfiguration { $0.selectedReminderListIDs = [] } }
                            Spacer()
                            Button("Refresh") { store.reload() }.disabled(store.isLoading)
                        }.buttonStyle(DSButtonStyle())

                        DSDivider()

                        if store.reminderLists.isEmpty {
                            Text(store.isLoading ? "Loading reminder lists…" : "No lists found. Add a list in Apple Reminders.")
                                .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        }
                        else {
                            LazyVGrid(columns: sourceGridColumns, alignment: .leading, spacing: DSSpacing.large) {
                                ForEach(store.reminderLists) { source in
                                    calendarSourceToggle(
                                        source,
                                        isOn: Binding(
                                            get: { store.configuration.selectedReminderListIDs?.contains(source.id) ?? true },
                                            set: { store.setReminderList(source.id, included: $0) }
                                        ),
                                        identifier: "settings.calendar.reminderList.\(source.id)"
                                    )
                                }
                            }
                        }

                        if store.missingReminderSelectionCount > 0 {
                            Text("\(store.missingReminderSelectionCount) selected list(s) are unavailable. Check your accounts or choose lists again.")
                                .font(DSTypography.metadata).foregroundStyle(theme.warningForeground)
                        }
                    }
                }
            }
        }
        .onAppear {
            store.setInterest(.settings, active: true)
            weatherStore.setInterest(.settings, active: true)
        }
        .onDisappear {
            store.setInterest(.settings, active: false)
            weatherStore.setInterest(.settings, active: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            weatherStore.refreshAuthorization()
            if weatherStore.authorization == .notDetermined { weatherStore.requestAccess() }
        }
    }

    private var sourceGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: DSSpacing.xxLarge, alignment: .leading),
            GridItem(.flexible(minimum: 0), alignment: .leading)
        ]
    }

    private func calendarDisplayToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .accessibilityHint(detail)
        .accessibilityIdentifier(identifier)
    }

    private func calendarSourceToggle(
        _ source: CalendarSource,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(source.account + (source.allowsModifications ? "" : " · Read-only"))
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .accessibilityIdentifier(identifier)
    }
}
