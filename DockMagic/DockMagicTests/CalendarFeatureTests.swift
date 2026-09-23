import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

final class CalendarFeatureTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-16T10:00:00Z")!
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testAgendaFiltersSelectionAllDayAndExpiredEvents() {
        let events = [event("past", -3600, -1), event("ongoing", -300, 300),
                      event("next", 600, 1200), event("all-day", -36000, 50400, allDay: true),
                      event("other", 900, 1800, calendarID: "other")]
        var configuration = CalendarConfiguration()
        configuration.selectedCalendarIDs = ["work"]
        configuration.includesAllDayEvents = false
        XCTAssertEqual(CalendarAgenda.events(events, on: now, configuration: configuration, upcomingFrom: now, calendar: utc).map(\.id), ["ongoing", "next"])
        configuration.includesAllDayEvents = true
        XCTAssertEqual(CalendarAgenda.events(events, on: now, configuration: configuration, upcomingFrom: now, calendar: utc).first?.id, "all-day")
        configuration.selectedCalendarIDs = []
        XCTAssertTrue(CalendarAgenda.events(events, on: now, configuration: configuration, calendar: utc).isEmpty)
        configuration.selectedCalendarIDs = ["missing"]
        XCTAssertTrue(CalendarAgenda.events(events, on: now, configuration: configuration, calendar: utc).isEmpty)
    }

    func testExclusiveMidnightAndMultiDayBoundaries() {
        let day = utc.startOfDay(for: now)
        let prior = CalendarEvent(id: "prior", calendarID: "work", calendarTitle: "Work", title: "Ends at midnight", start: day.addingTimeInterval(-86400), end: day, isAllDay: true, location: nil, meetingURL: nil)
        XCTAssertFalse(prior.occurs(on: now, calendar: utc))
        XCTAssertTrue(prior.occurs(on: day.addingTimeInterval(-3600), calendar: utc))
        XCTAssertTrue(event("overnight", -86400, 3600).occurs(on: now, calendar: utc))
        XCTAssertTrue(event("instant", 0, 0).occurs(on: now, calendar: utc))
    }

    func testMonthGridRespectsFirstWeekdayAndDST() throws {
        var calendar = utc
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        calendar.firstWeekday = 2
        let march = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-15T12:00:00Z"))
        let days = CalendarAgenda.monthDays(containing: march, calendar: calendar)
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(Set(days).count, 42)
        XCTAssertEqual(calendar.component(.weekday, from: days[0]), 2)
        XCTAssertTrue(days.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        XCTAssertTrue(zip(days, days.dropFirst()).contains { $1.timeIntervalSince($0) == 23 * 3600 })
        let september = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z"))
        XCTAssertEqual(CalendarAgenda.monthDays(containing: september, calendar: calendar).count, 35)
        let february = try XCTUnwrap(ISO8601DateFormatter().date(from: "2021-02-15T12:00:00Z"))
        XCTAssertEqual(CalendarAgenda.monthDays(containing: february, calendar: calendar).count, 28)
    }

    func testBrowsingFarAwayMonthKeepsQueriesBoundedAndTodayAvailable() {
        let future = utc.date(byAdding: .year, value: 10, to: now)!
        let ranges = CalendarAgenda.queryIntervals(month: future, today: now, calendar: utc)
        XCTAssertEqual(ranges.count, 2)
        XCTAssertTrue(ranges.allSatisfy { $0.duration <= 43 * 86400 })
        XCTAssertTrue(ranges.contains { $0.contains(now) })
    }

    func testMeetingLinksValidateHostSchemeAndPriority() {
        let zoom = URL(string: "https://acme.zoom.us/j/123?pwd=abc")!
        XCTAssertEqual(CalendarMeetingLink.find(url: zoom, location: "https://meet.google.com/abc-defg-hij", notes: nil), zoom)
        XCTAssertEqual(CalendarMeetingLink.find(url: URL(string: "file:///tmp/private"), location: "Room 1", notes: "Join https://meet.google.com/abc-defg-hij")?.host, "meet.google.com")
        for value in ["https://zoom.us.evil.test/j/123", "https://evilzoom.us/j/123", "http://zoom.us/j/123", "file:///tmp/meeting", "https://user@zoom.us/j/123", "https://zoom.us/pricing", "javascript:alert(1)"] {
            XCTAssertFalse(CalendarMeetingLink.isSupported(URL(string: value)!), value)
        }
        XCTAssertTrue(CalendarMeetingLink.isSupported(URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!))
    }

    @MainActor func testRefreshDoesNotPromptAndConnectIsExplicit() async {
        let provider = TestCalendarProvider(status: .notDetermined, result: .init(calendars: [], events: []))
        let store = makeStore(provider)
        await store.refresh()
        let initial = await provider.counts()
        XCTAssertEqual(initial.requests, 0)
        XCTAssertEqual(initial.reads, 0)
        await store.connect()
        let connected = await provider.counts()
        XCTAssertEqual(connected.requests, 1)
        XCTAssertEqual(store.access, .fullAccess)
    }

    @MainActor func testRevocationClearsPrivateData() async {
        let provider = fixtureProvider()
        let store = makeStore(provider)
        await store.refresh()
        XCTAssertEqual(store.events.count, 3)
        await provider.setStatus(.denied)
        await store.refresh()
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertTrue(store.calendars.isEmpty)
        XCTAssertNil(store.lastUpdated)
        XCTAssertEqual(store.access, .denied)
    }

    @MainActor func testReadFailureDoesNotPresentStaleEventsAsCurrent() async {
        let provider = fixtureProvider()
        let store = makeStore(provider)
        await store.refresh()
        await provider.fail()
        await store.refresh()
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertNil(store.lastUpdated)
        XCTAssertNotNil(store.errorMessage)
    }

    @MainActor func testStoppedRefreshCannotPublishLateResults() async {
        let provider = fixtureProvider()
        await provider.setDelay(.milliseconds(100))
        let store = makeStore(provider)
        let task = Task { await store.refresh() }
        while await provider.counts().reads == 0 { await Task.yield() }
        store.stop()
        await task.value
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertFalse(store.isLoading)
    }

    @MainActor func testConfigurationPersistsAndMissingCalendarsAreNotReplaced() async throws {
        let defaults = testDefaults()
        let store = CalendarStore(provider: fixtureProvider(), defaults: defaults, now: { self.now })
        store.updateConfiguration {
            $0.selectedCalendarIDs = ["missing"]
            $0.includesAllDayEvents = false
            $0.showsCallButton = false
        }
        store.stop()
        let restored = CalendarStore(provider: fixtureProvider(), defaults: defaults, now: { self.now })
        await restored.refresh()
        XCTAssertEqual(restored.configuration, store.configuration)
        XCTAssertEqual(restored.missingSelectionCount, 1)
        XCTAssertTrue(restored.todayEvents.isEmpty)
        restored.setCalendar("work", included: true)
        restored.stop()
        XCTAssertEqual(restored.configuration.selectedCalendarIDs, ["work", "missing"])
    }

    @MainActor func testMidnightFollowsTodayOnlyWhenTodaySelected() async {
        var clock = now
        let store = CalendarStore(provider: fixtureProvider(), defaults: testDefaults(), now: { clock })
        await store.refresh()
        clock = now.addingTimeInterval(86400)
        await store.refresh()
        XCTAssertEqual(store.selectedDate, clock)
        store.selectDay(now.addingTimeInterval(-86400))
        store.stop()
        clock = clock.addingTimeInterval(86400)
        await store.refresh()
        XCTAssertEqual(store.selectedDate, now.addingTimeInterval(-86400))
    }

    @MainActor func testCalendarRoutingAndProductionRenderersAcrossAppearances() async throws {
        XCTAssertTrue(DockFeature.calendar.hasHoverDashboard)
        XCTAssertEqual(SettingsDestination(activeFeature: .calendar), .calendar)
        XCTAssertEqual(SettingsDestination.calendar.feature, .calendar)
        let store = makeStore(fixtureProvider())
        await store.refresh()
        let output = URL(fileURLWithPath: "/tmp/dockmagic-calendar-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let variants: [(String, DSAppearanceMode, DSAccessibilityOverrides, Bool)] = [
            ("light", .light, .init(), false), ("dark", .dark, .init(), false),
            ("contrast", .dark, .init(increaseContrast: true), false),
            ("opaque", .light, .init(reduceTransparency: true), false),
            ("grayscale", .dark, .init(), true)
        ]
        for (name, mode, overrides, grayscale) in variants {
            let dashboard = CalendarHoverDashboardView(store: store)
                .frame(width: 432, height: 564).padding(16)
                .background(ProjectTheme.current.surface)
                .environment(\.dsAccessibilityOverrides, overrides)
            let data = try render(dashboard, mode: mode, size: CGSize(width: 464, height: 596), increaseContrast: name == "contrast", grayscale: grayscale)
            try data.write(to: output.appendingPathComponent("dashboard-\(name).png"))
            for side in [32.0, 48, 64, 128] {
                let tile = DockTileView(presentation: .calendar(date: now, hasItems: !store.todayDockItems.isEmpty), animatesChanges: false)
                    .environment(\.dsAccessibilityOverrides, overrides)
                let png = try render(tile, mode: mode, size: CGSize(width: side, height: side), increaseContrast: name == "contrast", grayscale: grayscale)
                XCTAssertGreaterThan(png.count, 100)
                if name == "light" || name == "dark" {
                    try png.write(to: output.appendingPathComponent("dock-date-\(Int(side))-\(name).png"))
                }
            }
        }
        await fixtureDeniedRenders(output: output)
    }

    @MainActor func testDockCalendarDotIsConditional() throws {
        let size = CGSize(width: 128, height: 128)
        let empty = try render(DockCalendarView(date: now, hasItems: false), mode: .light, size: size)
        let scheduled = try render(DockCalendarView(date: now, hasItems: true), mode: .light, size: size)
        XCTAssertNotEqual(empty, scheduled)
    }

    @MainActor func testDockNoticeIncludesEventsEarlierToday() async {
        let provider = TestCalendarProvider(status: .fullAccess, result: .init(
            calendars: [.init(id: "work", title: "Work", account: "iCloud")],
            events: [event("finished", -3600, -1800)]
        ))
        let store = makeStore(provider)
        await store.refresh()
        XCTAssertTrue(store.todayEvents.isEmpty)
        XCTAssertEqual(store.todayDockItems.map(\.id), ["finished"])
    }

    @MainActor private func fixtureDeniedRenders(output: URL) async {
        let provider = fixtureProvider()
        await provider.setStatus(.denied)
        let store = makeStore(provider)
        await store.refresh()
        do {
            let png = try render(CalendarHoverDashboardView(store: store).frame(width: 432, height: 564).padding(16).background(ProjectTheme.current.surface), mode: .light, size: CGSize(width: 464, height: 596))
            try png.write(to: output.appendingPathComponent("dashboard-denied.png"))
        } catch { XCTFail("Permission state rendering failed: \(error)") }
    }

    @MainActor func testTwoWayEditorsAndReminderDashboardRenderAcrossAppearances() async throws {
        let provider = CalendarUITestProvider(access: "fullAccess", remindersAccess: "fullAccess")
        let store = CalendarStore(provider: provider, defaults: testDefaults())
        await store.refresh()
        let weatherStore = CalendarWeatherStore(provider: CalendarWeatherTestProvider(), defaults: testDefaults())
        weatherStore.setInterest(.preview, active: true)
        await weatherStore.refresh()
        let output = URL(fileURLWithPath: "/tmp/dockmagic-calendar-sync-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, mode, overrides, grayscale) in [
            ("light", DSAppearanceMode.light, DSAccessibilityOverrides(), false),
            ("dark", .dark, .init(), false),
            ("contrast", .dark, .init(increaseContrast: true), false),
            ("opaque", .light, .init(reduceTransparency: true), false),
            ("grayscale", .dark, .init(), true)
        ] {
            for kind in CalendarEditKind.allCases {
                let editor = CalendarItemEditorView(store: store, kind: kind,
                    event: kind == .event ? store.events.first : nil,
                    reminder: kind == .reminder ? store.reminders.first : nil)
                    .environment(\.dsAccessibilityOverrides, overrides)
                let png = try render(editor, mode: mode, size: CGSize(width: 520, height: 610), increaseContrast: name == "contrast", grayscale: grayscale)
                XCTAssertGreaterThan(png.count, 100)
                try png.write(to: output.appendingPathComponent("editor-\(kind.rawValue)-\(name).png"))
            }
            let dashboard = CalendarHoverDashboardView(store: store).frame(width: 432, height: 564).padding(16)
                .background(ProjectTheme.current.surface).environment(\.dsAccessibilityOverrides, overrides)
            let png = try render(dashboard, mode: mode, size: CGSize(width: 464, height: 596), increaseContrast: name == "contrast", grayscale: grayscale)
            try png.write(to: output.appendingPathComponent("dashboard-\(name).png"))
            let weatherDashboard = CalendarHoverDashboardView(store: store, weatherStore: weatherStore)
                .frame(width: 432, height: 704).padding(16)
                .background(ProjectTheme.current.surface).environment(\.dsAccessibilityOverrides, overrides)
            let weatherPNG = try render(weatherDashboard, mode: mode,
                size: CGSize(width: 464, height: 736), increaseContrast: name == "contrast", grayscale: grayscale)
            try weatherPNG.write(to: output.appendingPathComponent("dashboard-weather-\(name).png"))
            for side in [32.0, 48, 64, 128] {
                let tile = DockTileView(presentation: .calendar(date: store.currentDate, hasItems: !store.todayDockItems.isEmpty), animatesChanges: false)
                let image = try render(tile, mode: mode, size: CGSize(width: side, height: side), increaseContrast: name == "contrast", grayscale: grayscale)
                try image.write(to: output.appendingPathComponent("dock-\(Int(side))-\(name).png"))
                let current = CalendarCurrentWeather(condition: .rain, conditionDescription: "Rain",
                    isDaylight: true, temperatureCelsius: 25, observedAt: Date())
                let weatherTile = DockTileView(presentation: .calendar(date: store.currentDate,
                    hasItems: true, currentWeather: current), animatesChanges: false)
                let weatherImage = try render(weatherTile, mode: mode,
                    size: CGSize(width: side, height: side), increaseContrast: name == "contrast", grayscale: grayscale)
                XCTAssertGreaterThan(weatherImage.count, 100)
                try weatherImage.write(to: output.appendingPathComponent("dock-weather-\(Int(side))-\(name).png"))
            }
        }
        weatherStore.setInterest(.preview, active: false)
    }

    @MainActor func testCalendarEventCategoryColorRender() async throws {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let events: [CalendarEvent] = [
            .init(id: "birthday", calendarID: "personal", calendarTitle: "Personal",
                title: "Ana's birthday", start: start, end: end, isAllDay: true,
                location: nil, meetingURL: nil),
            .init(id: "holiday", calendarID: "holidays", calendarTitle: "Holidays",
                title: "Mid-autumn festival", start: start, end: end, isAllDay: true,
                location: nil, meetingURL: nil),
            .init(id: "work", calendarID: "work", calendarTitle: "Work",
                title: "Design review", start: now.addingTimeInterval(1800),
                end: now.addingTimeInterval(5400), isAllDay: false,
                location: nil, meetingURL: nil)
        ]
        let provider = TestCalendarProvider(status: .fullAccess,
            result: .init(calendars: [.init(id: "personal", title: "Personal", account: "iCloud"),
                .init(id: "holidays", title: "Holidays", account: "iCloud"),
                .init(id: "work", title: "Work", account: "iCloud")], events: events))
        let store = CalendarStore(provider: provider, defaults: testDefaults(), now: { now })
        await store.refresh()
        let weatherStore = CalendarWeatherStore(provider: CalendarWeatherTestProvider(), defaults: testDefaults())
        weatherStore.setInterest(.preview, active: true)
        await weatherStore.refresh()
        let output = URL(fileURLWithPath: "/tmp/dockmagic-calendar-sync-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, mode) in [("light", DSAppearanceMode.light), ("dark", .dark)] {
            let dashboard = CalendarHoverDashboardView(store: store, weatherStore: weatherStore)
                .frame(width: 432, height: 1000).padding(16)
                .background(ProjectTheme.current.surface)
            let png = try render(dashboard, mode: mode, size: CGSize(width: 464, height: 1032))
            try png.write(to: output.appendingPathComponent("dashboard-weather-categories-\(name).png"))
        }
        weatherStore.setInterest(.preview, active: false)
    }

    private func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false, calendarID: String = "work") -> CalendarEvent {
        .init(id: id, calendarID: calendarID, calendarTitle: "Work", title: id,
              start: now.addingTimeInterval(start), end: now.addingTimeInterval(end), isAllDay: allDay, location: nil, meetingURL: nil)
    }

    private func fixtureProvider() -> TestCalendarProvider {
        TestCalendarProvider(status: .fullAccess, result: .init(calendars: [.init(id: "work", title: "Work", account: "iCloud")], events: [
            event("Team planning", 600, 2400), event("Design review with the product team", 3600, 7200), event("Release day", -36000, 50400, allDay: true)
        ]))
    }

    @MainActor private func makeStore(_ provider: TestCalendarProvider) -> CalendarStore {
        CalendarStore(provider: provider, defaults: testDefaults(), now: { self.now })
    }

    private func testDefaults() -> UserDefaults {
        let name = "CalendarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    @MainActor private func render<V: View>(_ content: V, mode: DSAppearanceMode, size: CGSize, increaseContrast: Bool = false, grayscale: Bool = false) throws -> Data {
        let host = NSHostingView(rootView: DockMagicThemeRoot(content: content, appearanceMode: mode))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        host.appearance = NSAppearance(named: increaseContrast ? (mode == .dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua) : (mode == .dark ? .darkAqua : .aqua))
        window.appearance = host.appearance
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.wantsLayer = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if grayscale {
            // Simulate the macOS grayscale display transform after capturing
            // the real view; NSView cacheDisplay omits compositing filters.
            let source = try XCTUnwrap(bitmap.cgImage)
            let context = try XCTUnwrap(CGContext(data: nil, width: source.width, height: source.height,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue))
            context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
            let output = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
            return try XCTUnwrap(output.representation(using: .png, properties: [:]))
        }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}

private actor TestCalendarProvider: CalendarProviding {
    var status: CalendarAccess
    let result: CalendarReadResult
    var requests = 0
    var reads = 0
    var shouldFail = false
    var delay: Duration = .zero
    init(status: CalendarAccess, result: CalendarReadResult) { self.status = status; self.result = result }
    func authorization() -> CalendarAccess { status }
    func requestAccess() { requests += 1; status = .fullAccess }
    func read(intervals: [DateInterval], selectedIDs: Set<String>?) async throws -> CalendarReadResult {
        reads += 1
        if delay > .zero { try? await Task.sleep(for: delay) }
        if shouldFail { throw CalendarReadError.accessChanged }
        return result
    }
    func counts() -> (requests: Int, reads: Int) { (requests, reads) }
    func setStatus(_ value: CalendarAccess) { status = value }
    func setDelay(_ value: Duration) { delay = value }
    func fail() { shouldFail = true }
}

@MainActor
final class CalendarWeatherFeatureTests: XCTestCase {
    @MainActor func testGeneratedWeatherIconCoverageAndEventCategories() {
        for condition in WeatherCondition.allCases {
            let name = CalendarWeatherIcon.assetName(for: condition)
            XCTAssertNotNil(NSImage(named: NSImage.Name(name)), "Missing SVG asset for \(condition)")
        }
        XCTAssertEqual(CalendarWeatherIcon.assetName(for: .clear, isDaylight: false), "CalendarWeatherMoon")
        let date = Date()
        func event(_ title: String, calendar: String) -> CalendarEvent {
            .init(id: UUID().uuidString, calendarID: "test", calendarTitle: calendar,
                title: title, start: date, end: date.addingTimeInterval(3600),
                isAllDay: false, location: nil, meetingURL: nil)
        }
        XCTAssertEqual(CalendarEventVisualCategory.classify(event("Mom's birthday", calendar: "Personal")), .birthday)
        XCTAssertEqual(CalendarEventVisualCategory.classify(event("Ngày thường", calendar: "Ngày lễ VN")), .holiday)
        XCTAssertEqual(CalendarEventVisualCategory.classify(event("Planning", calendar: "Work")), .work)
        XCTAssertEqual(CalendarEventVisualCategory.classify(event("Coffee", calendar: "Personal")), .regular)
    }

    func testIndependentRefreshCadencesAndCurrentSceneExpiry() async throws {
        let clock = CalendarWeatherTestClock(Date(timeIntervalSince1970: 1_779_009_600))
        let provider = CalendarWeatherTestProvider()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = CalendarWeatherStore(provider: provider, defaults: defaults,
            now: { clock.date }, timeZone: { TimeZone(secondsFromGMT: 0)! })
        store.setInterest(.dock, active: true)
        await store.refresh()
        XCTAssertEqual(provider.todayCount, 1)
        XCTAssertEqual(provider.futureCount, 1)
        XCTAssertNotNil(store.currentScene)

        clock.date = clock.date.addingTimeInterval(16 * 60)
        await store.refresh()
        XCTAssertEqual(provider.todayCount, 2)
        XCTAssertEqual(provider.futureCount, 1)

        clock.date = clock.date.addingTimeInterval(46 * 60)
        XCTAssertNil(store.currentScene)
        clock.date = clock.date.addingTimeInterval(3 * 60 * 60)
        await store.refresh()
        XCTAssertEqual(provider.futureCount, 2)
        store.setInterest(.dock, active: false)
    }

    func testLocationPromptIsExplicitAndRevocationClearsCache() async {
        let provider = CalendarWeatherTestProvider()
        provider.status = .notDetermined
        let store = CalendarWeatherStore(provider: provider,
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.setInterest(.dock, active: true)
        await store.refresh()
        XCTAssertEqual(provider.todayCount, 0)
        // A foreground Settings or hover button may ask; Dock selection alone must not.
        XCTAssertEqual(provider.permissionPromptCount, 0)
        await store.requestAccessAndRefresh()
        XCTAssertEqual(provider.permissionPromptCount, 1)
        XCTAssertNotNil(store.currentScene)
        provider.status = .denied
        store.refreshAuthorization()
        XCTAssertNil(store.currentScene)
        XCTAssertNil(store.cache)
        store.setInterest(.dock, active: false)
    }

    func testDateKeysRespectDSTAndHourlyInstants() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let spring = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T12:00:00Z"))
        XCTAssertEqual(CalendarWeatherDates.offsetDayID(from: spring, by: 1, timeZone: zone), "2026-03-09")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: spring)
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        XCTAssertEqual(next.timeIntervalSince(start), 23 * 3600)
        let fall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z"))
        let fallStart = calendar.startOfDay(for: fall)
        let fallNext = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: fallStart))
        XCTAssertEqual(fallNext.timeIntervalSince(fallStart), 25 * 3600)
    }

    func testMidnightTimezoneWakeAndFailedFutureKeepLabeledCache() async {
        let clock = CalendarWeatherTestClock(Date(timeIntervalSince1970: 1_779_009_600))
        let zone = CalendarWeatherTestZone(TimeZone(secondsFromGMT: 0)!)
        let provider = CalendarWeatherTestProvider()
        let store = CalendarWeatherStore(provider: provider,
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            now: { clock.date }, timeZone: { zone.value })
        store.setInterest(.dock, active: true)
        await store.refresh()
        provider.failFuture = true
        clock.date = clock.date.addingTimeInterval(4 * 3600)
        await store.refresh()
        let tomorrow = clock.date.addingTimeInterval(86400)
        let previous = store.day(for: tomorrow)
        XCTAssertNotNil(previous)
        XCTAssertTrue(store.isLastKnown(previous!))
        provider.failFuture = false
        await store.refreshAfterInterruption()
        XCTAssertEqual(provider.futureCount, 3)
        zone.value = TimeZone(secondsFromGMT: 3600)!
        await store.refresh()
        XCTAssertEqual(provider.futureCount, 4)
        clock.date = clock.date.addingTimeInterval(24 * 3600)
        await store.refresh()
        XCTAssertEqual(provider.todayCount, 5)
        store.setInterest(.dock, active: false)
    }

    func testOpenMeteoHourlyDecodePreserves23HourDayAndRequestRange() async throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T12:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: now)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let timestamps = stride(from: Int(start.timeIntervalSince1970), to: Int(end.timeIntervalSince1970), by: 3600).map { $0 }
        XCTAssertEqual(timestamps.count, 23)
        let payload: [String: Any] = [
            "timezone": zone.identifier,
            "current": ["time": Int(now.timeIntervalSince1970), "temperature_2m": 21.0,
                "weather_code": 2, "is_day": 1],
            "daily": ["time": [Int(start.timeIntervalSince1970)], "weather_code": [2],
                "temperature_2m_max": [25.0], "temperature_2m_min": [16.0],
                "precipitation_probability_max": [35]],
            "hourly": ["time": timestamps, "temperature_2m": Array(repeating: 20.0, count: 23),
                "weather_code": Array(repeating: 2, count: 23),
                "precipitation_probability": Array(repeating: 35, count: 23)]
        ]
        let provider = OpenMeteoCalendarWeatherProvider(
            coordinateProvider: CalendarWeatherCoordinateStub(),
            locationNameProvider: CalendarWeatherNameStub(),
            httpClient: CalendarWeatherHTTPStub(data: try JSONSerialization.data(withJSONObject: payload)))
        let request = try provider.makeRequest(.future,
            coordinate: WeatherCoordinate(latitude: 10.8, longitude: 106.6), now: now, timeZone: zone)
        let items = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first(where: { $0.name == "start_date" })?.value, "2026-03-09")
        XCTAssertEqual(items.first(where: { $0.name == "end_date" })?.value, "2026-03-14")
        XCTAssertNil(items.first(where: { $0.name == "current" }))
        let result = try await provider.fetch(.today, now: now, timeZone: zone)
        XCTAssertEqual(result.days.first?.dayID, "2026-03-08")
        XCTAssertEqual(result.days.first?.hours.count, 23)
        XCTAssertEqual(result.days.first?.hours.first?.date, start)
        XCTAssertEqual(result.days.first?.hours.last?.date, end.addingTimeInterval(-3600))
    }

    func testConcurrentRefreshDeduplicatesBothRequests() async {
        let provider = CalendarWeatherTestProvider()
        provider.delay = .milliseconds(30)
        let store = CalendarWeatherStore(provider: provider,
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.setInterest(.dock, active: true)
        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await (first, second)
        XCTAssertEqual(provider.todayCount, 1)
        XCTAssertEqual(provider.futureCount, 1)
        store.setInterest(.dock, active: false)
    }
}

private final class CalendarWeatherTestClock: @unchecked Sendable {
    var date: Date
    init(_ date: Date) { self.date = date }
}

private final class CalendarWeatherTestZone: @unchecked Sendable {
    var value: TimeZone
    init(_ value: TimeZone) { self.value = value }
}

@MainActor
private final class CalendarWeatherTestProvider: CalendarWeatherProviding {
    var status: WeatherLocationAuthorization = .authorized
    var todayCount = 0
    var futureCount = 0
    var permissionPromptCount = 0
    var failFuture = false
    var delay: Duration = .zero
    func authorization() -> WeatherLocationAuthorization { status }
    func fetch(_ scope: CalendarWeatherRequestScope, now: Date, timeZone: TimeZone) async throws -> CalendarWeatherResult {
        if delay > .zero { try await Task.sleep(for: delay) }
        if status == .notDetermined {
            permissionPromptCount += 1
            status = .authorized
        }
        if scope == .today { todayCount += 1 } else { futureCount += 1 }
        if scope == .future && failFuture { throw OpenMeteoWeatherError.invalidResponse }
        let offsets = scope == .today ? [0] : Array(1 ... 6)
        let days = offsets.map { offset in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let start = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            var hours: [CalendarWeatherHour] = []
            var instant = start
            while instant < end {
                hours.append(CalendarWeatherHour(date: instant, condition: .partlyCloudy,
                    conditionDescription: "Partly cloudy", temperatureCelsius: 27,
                    precipitationChance: 0.2))
                instant = instant.addingTimeInterval(3600)
            }
            return CalendarWeatherDay(dayID: CalendarWeatherDates.offsetDayID(from: now, by: offset, timeZone: timeZone),
                condition: .partlyCloudy, conditionDescription: "Partly cloudy", highCelsius: 30,
                lowCelsius: 24, precipitationChance: 0.2, hours: hours)
        }
        return CalendarWeatherResult(coordinate: WeatherCoordinate(latitude: 10.8, longitude: 106.6),
            location: "Test city", timeZoneID: timeZone.identifier,
            current: scope == .today ? CalendarCurrentWeather(condition: .partlyCloudy,
                conditionDescription: "Partly cloudy", isDaylight: true,
                temperatureCelsius: 27, observedAt: now) : nil, days: days)
    }
}

private struct CalendarWeatherCoordinateStub: WeatherCoordinateProviding {
    func currentCoordinate() async throws -> WeatherCoordinate {
        WeatherCoordinate(latitude: 10.8, longitude: 106.6)
    }
}

private struct CalendarWeatherNameStub: WeatherLocationNameProviding {
    func locationName(for coordinate: WeatherCoordinate) async -> String? { "Test city" }
}

private struct CalendarWeatherHTTPStub: OpenMeteoHTTPClient {
    let data: Data
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
