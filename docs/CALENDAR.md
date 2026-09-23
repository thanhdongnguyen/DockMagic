# Calendar and Reminders

DockMagic uses EventKit as the shared source of truth for Apple Calendar events
and Apple Reminders. The Dock tile signals their presence; their details appear
in the dashboard and Settings. Saving an explicit user action writes to the same native item;
changes made in the native apps are read back automatically. Reminders are not
copied into calendar events, and no separate replication database is created.

## Using the feature

1. In Settings → Calendar, choose **Connect Calendar** and **Connect Reminders**.
   macOS asks for these permissions separately. Neither app launch nor selecting
   the feature automatically requests access.
2. Select calendars and reminder lists. **All** includes future sources; an
   explicit empty selection means none. Missing identifiers remain selected and
   are reported, rather than silently replaced with another account/list.
3. Select Calendar as the active Dock feature. Its tile shows only the abbreviated
   weekday, day number, abbreviated month, and an optional red dot. The dot
   means a selected calendar event occurs today (even if it has ended) or an
   unfinished due reminder is included. The date works without access; event
   and reminder times and titles never appear on the tile. With Location access
   and fresh current conditions, the tile uses the shared Weather scene behind
   the date; otherwise it keeps the neutral background.
4. Hover the Dock tile or open **Preview dashboard** in Settings. The month grid
   marks dates with events or reminders and small weather icons for forecast
   days. Select a day to browse its agenda and, when available, a daily summary
   and horizontally scrolling hourly forecast above the agenda. Weather never
   replaces events or reminders. Dates outside today through six days ahead
   show no forecast.
   A red dot marks a day with included events/reminders independently of its
   weather icon. The selected-day forecast uses the matching Weather scene;
   generated colored SVG pictograms identify conditions in the grid and hourly
   strip. These icons render without a white badge or border. Agenda rows use
   restrained labeled color markers for recognized
   birthdays, holidays and work calendars. These are visual hints only and do
   not modify or reclassify the EventKit items. The month grid uses the number
   of weeks that month actually needs rather than always reserving six rows.
   Today's reminders also include unfinished overdue and undated items. **All
   reminders** shows the selected lists independently of the selected day.
5. Use **New event**, **New reminder**, or a row's Edit button. Editing opens a
   normal keyboard-enabled window that remains usable after the hover panel
   closes. Save commits to the native database. Cancel does not write; discarding
   a changed draft and deleting an existing item require explicit confirmation.
6. A reminder's circle marks it complete or incomplete. Completed items are
   hidden by default; **Show completed reminders** enables reopening them.

Event editing supports title, destination calendar, start/end, all-day, location,
URL and notes. Reminder editing supports title, destination list, optional due
date/time, notes, priority and completion. Read-only sources remain visible but
cannot be edited. New-item actions require a writable destination.

The existing meeting shortcuts support HTTPS Google Meet, Zoom and Teams links,
validated from event URL, location and notes. Links open only after a user click.

## Local weather

Calendar uses separate Core Location and Open-Meteo requests/cache from the
Weather feature. Opening Calendar Settings for the first time requests Location
when DockMagic is foreground. A Calendar hover dashboard without access shows
an explicit button; selecting Calendar on the Dock alone never prompts. Denied
access links to macOS Location Settings. Open-Meteo attribution appears beside
the forecast and in Calendar Settings.

While Calendar is visible on the Dock/Shelf or its Settings/dashboard is open,
current conditions and today's forecast refresh every 15 minutes; tomorrow
through day six refresh every four hours. Both requests preload all hourly
values, so selecting a day makes no network request. A midnight boundary, wake,
time-zone change, or materially changed location invalidates/reloads the
appropriate cache. Daily/hourly data use the Mac Calendar time zone and actual
hourly instants, including 23- and 25-hour days. Failed requests retain labeled
last-known forecasts; current-condition artwork becomes neutral after 45 minutes.
The Weather feature's own 10-minute schedule remains independent.

## Synchronization and write behavior

- While the Dock feature, Settings page, or editor is active, `EKEventStoreChanged`
  triggers a read. A 30-second refresh, app activation, day/time-zone changes and
  system recovery provide additional refresh paths. Each surface owns its own
  monitoring interest, so switching the Dock feature does not stop an open editor.
- Calendar and Reminders permissions, errors, sources and refresh timestamps are
  independent. Either can work when the other has not been granted access.
- Before editing/deleting, a fresh EventKit store re-fetches the native item,
  checks source writability and compares its value snapshot/last-modified date to
  the version opened by the user. A detected external edit or deletion rejects
  the stale operation and refreshes the dashboard. This is a pre-save conflict
  check, not an atomic compare-and-swap guarantee; EventKit offers no such API.
- Recurring events are resolved by item identifier **and occurrence start**.
  Saves and deletes use `EKSpan.thisEvent` and affect that occurrence only.
  Attendees, alarms, recurrence rules, availability and event time zone are kept.
- Reminder edits retain existing alarms/recurrence and unchanged due components.
  Completing a repeating reminder is delegated to EventKit/Reminders. Deleting a
  repeating reminder removes that reminder and its repeat rule, as the dialog
  explains. Repeat-rule editing is left to the native apps.
- Save/complete/delete controls serialize writes. No optimistic completion, silent
  retry, offline replay queue or duplicate creation occurs after an error. After
  each committed change the store reads native data again. A failed read is shown
  separately from a committed save; it does not repeat that save.
- Canceled events and invitations declined by the current user are excluded.
  Recurring occurrences have distinct display IDs. Event ends are exclusive;
  all-day editors show the inclusive last day and convert it to EventKit's
  exclusive end using calendar-day arithmetic. Date-only reminders
  stay date-only. Month arithmetic respects local calendars, time zones and DST.
- Event queries cover the visible 42-day grid plus today, even when browsing a
  distant month. Reminder queries fetch the selected lists, including undated
  items, so reminders are not silently lost outside the visible month.

Native accounts (iCloud, CalDAV, Exchange, etc., as exposed by EventKit) perform
network/device synchronization. A successful local save does not claim that an
account server or another device has already received it. This feature does not
add a DockMagic server, provider login, bulk migration or Calendar↔Reminder type
conversion. Advanced native fields such as recurrence editing, attachments,
subtasks and invitation management are not exposed in the editor.

## Authorization and distribution

The two explicit connection actions call `requestFullAccessToEvents()` and
`requestFullAccessToReminders()`. The Info.plist contains both full-access purpose
strings and accurately describes reads and user-directed writes. Permission loss
or read failure clears the affected displayed items; late canceled results cannot
repopulate them. No event/reminder contents are persisted by DockMagic. Only
preferences and selected source IDs are stored in UserDefaults.

The existing `com.apple.security.personal-information.calendars` entitlement is
retained for EventKit resource access under Hardened Runtime. Direct Developer ID
distribution is unchanged; release signing, notarization and stapling remain the
release process. No App Store provisioning or StoreKit dependency is introduced.

## Implementation

- `CalendarAgenda.swift`: calendar models, preferences with backward-compatible
  decoding, bounded date queries and supported meeting links.
- `CalendarEditing.swift`: reminder models, date/filtering semantics, editable
  drafts, validation and user-facing write errors.
- `EventKitCalendarProvider.swift`: permissions, reads, immutable snapshots.
- `EventKitCalendarWriter.swift`: explicit native CRUD/completion, write checks,
  occurrence resolution and conflict detection.
- `CalendarStore.swift`: observable state, independent source states, monitoring
  interests, revision checks, serialized writes and post-commit reads.
- `CalendarEditorWindowController.swift` / `CalendarItemEditorView.swift`: native
  keyboard window, forms, discard/delete confirmation, errors and disabled states.
- `CalendarHoverDashboardView.swift`, `CalendarSettingsView.swift`, and
  `DockCalendarView.swift`: neutral semantic UI and production Dock rendering.
- `CalendarUITestProvider.swift`: Debug-only in-memory native-store substitute.
  Used only when the app is explicitly launched in its UI-testing mode.

## Verification

The Calendar model, store and render tests cover independent permissions,
legacy preference migration, reminder dates/filtering, bidirectional store
behavior, external-change notifications, stale edits/deletions, denied and
read-only writes, duplicate-submit protection, all-day/DST boundaries, and
monitoring ownership. The date-only tile is rendered at 32/48/64/128 pt across
accessibility appearances, and the dot is tested with and without items.

`CalendarUITests` exercises native forms and the connection/create/edit/complete/
reopen/delete paths through the injected Debug provider. Render checks cover the
production dashboard, both editors, and Dock sizes 32/48/64/128 pt in Light, Dark,
Increased Contrast, Reduce Transparency and simulated display grayscale. Artifacts
are written to `/tmp/dockmagic-calendar-sync-qa`.

All four UI cases passed across the focused reruns: denied access and event CRUD
in `tests-5`, Settings persistence in `tests-7`, and reminder CRUD/completion in
`tests-8` (each result bundle is `/tmp/dockmagic-calendar-sync-<name>.xcresult`).
The final appearance-render test also passed in `tests-7`. Earlier UI runs exposed
an overlay scrollbar covering row edit buttons; the agenda now reserves trailing
space for it. Concurrent DockMagic UI sessions also caused window interruptions
and a synthesized-input timeout; the reminder rerun waited for other UI runners
to exit and passed without changing the test's interaction sequence.

The final Debug build passed `script/build_and_run.sh --verify` with
`DOCKMAGIC_DERIVED_DATA_PATH=.derivedData-calendar-sync`; the process was still
running on a subsequent check. `codesign --verify --deep --strict` passed when run
with access to macOS certificate trust services. This verifies the local Debug
bundle, not a notarized release. Build log: `/tmp/dockmagic-calendar-sync-build.log`.

These fixture tests do not prove real-account EventKit writes or cross-device
sync. Real macOS consent, native account changes and recurring-item behavior must
also be checked with a user-approved test calendar/list before release. No test
creates, modifies or deletes items in the user's actual Calendar or Reminders.

## Sources

- [Dockset Calendar and Reminders](https://dockset.app/manual/calendar-reminders)
- [Apple: Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
- [Apple: Creating events and reminders](https://developer.apple.com/documentation/eventkit/creating-events-and-reminders)
- [Apple: Full Reminders access purpose](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription)
- [Apple: Fetching reminders](https://developer.apple.com/documentation/eventkit/ekeventstore/fetchreminders(matching:completion:))
- [Apple: Calendars entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.calendars)
