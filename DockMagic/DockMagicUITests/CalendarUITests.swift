import XCTest

final class CalendarUITests: XCTestCase {
    private var suite = "DockMagicCalendarUITests.\(UUID().uuidString)"

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func testConnectSelectionDashboardAndPersistedPreferences() {
        let app = launch(access: "notDetermined", appearance: "light")
        openCalendarSettings(app)
        XCTAssertFalse(app.staticTexts["Local weather"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["calendar.weather.attribution"].exists)
        let connect = app.buttons["calendar.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5), app.debugDescription)
        connect.click()
        XCTAssertTrue(app.staticTexts["Calendar connected"].waitForExistence(timeout: 5))
        screenshot(app, "Calendar Settings — Light")
        let preview = app.buttons["settings.calendar.dashboard"]
        XCTAssertTrue(preview.isHittable)
        preview.click()
        XCTAssertTrue(app.buttons["calendar.nextMonth"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.scrollViews["calendar.weather.hours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Open-Meteo · CC BY 4.0"))
            .firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Team planning"].exists)
        screenshot(app, "Calendar dashboard — Light")
        app.buttons["calendar.nextMonth"].click()
        XCTAssertTrue(app.staticTexts["No events"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No forecast for this date"].exists)
        app.buttons["calendar.today"].click()
        XCTAssertTrue(app.staticTexts["Team planning"].waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["settings.calendar.layout"].exists)
        let allDay = app.checkBoxes["settings.calendar.allDay"]
        XCTAssertTrue(allDay.exists)
        allDay.scrollToVisibleIfNeeded(in: app)
        allDay.click()
        let source = app.checkBoxes["settings.calendar.source.work"]
        source.scrollToVisibleIfNeeded(in: app)
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        source.click()
        XCTAssertTrue(source.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(checkboxValue(source), 0, app.debugDescription)
        screenshot(app, "Calendar Settings — Selection")
        app.terminate()
        let reopened = launch(access: "fullAccess", appearance: "dark")
        openCalendarSettings(reopened)
        XCTAssertFalse(reopened.buttons["settings.calendar.layout"].exists)
        XCTAssertEqual(checkboxValue(reopened.checkBoxes["settings.calendar.allDay"]), 0)
    }

    func testDeniedStateAndDarkDashboard() {
        let app = launch(access: "denied", appearance: "dark")
        openCalendarSettings(app)
        XCTAssertTrue(app.buttons["calendar.privacySettings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["calendar.connect"].exists)
        app.buttons["settings.calendar.dashboard"].click()
        XCTAssertTrue(app.buttons["calendar.nextMonth"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons.matching(identifier: "calendar.privacySettings").firstMatch.exists)
        screenshot(app, "Calendar dashboard — Denied — Dark")
    }

    func testEventEditorCreateEditDeleteAndCancel() {
        let app = launch(access: "fullAccess", appearance: "light", remindersAccess: "fullAccess")
        openCalendarSettings(app)
        app.buttons["settings.calendar.dashboard"].click()
        XCTAssertTrue(app.buttons["calendar.newEvent"].waitForExistence(timeout: 5))
        app.buttons["calendar.newEvent"].click()
        let title = app.textFields["calendar.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["calendar.editor.save"].isEnabled)
        title.click(); title.typeText("Calendar sync UI event")
        app.buttons["calendar.editor.save"].click()
        waitForEditorToClose(app)
        let edit = app.buttons["Edit Calendar sync UI event"]
        scrollAgenda(edit, in: app)
        XCTAssertTrue(edit.waitForExistence(timeout: 5), app.debugDescription)
        edit.click()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click(); title.typeKey("a", modifierFlags: .command); title.typeText("Updated sync UI event")
        screenshot(app, "Calendar event editor — Light")
        app.buttons["calendar.editor.save"].click()
        waitForEditorToClose(app)
        let updated = app.buttons["Edit Updated sync UI event"]
        scrollAgenda(updated, in: app)
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        updated.click()
        XCTAssertTrue(app.buttons["calendar.editor.delete"].waitForExistence(timeout: 5))
        app.buttons["calendar.editor.delete"].click()
        XCTAssertTrue(app.windows["calendar.editor"].sheets.buttons["Delete"].waitForExistence(timeout: 3), app.debugDescription)
        app.windows["calendar.editor"].sheets.buttons["Cancel"].click()
        XCTAssertTrue(title.exists)
        app.buttons["calendar.editor.delete"].click()
        app.windows["calendar.editor"].sheets.buttons["Delete"].click()
        XCTAssertTrue(app.buttons["calendar.newEvent"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Updated sync UI event"].exists)
    }

    func testRemindersConnectCreateCompleteReopenAndDelete() {
        let app = launch(access: "fullAccess", appearance: "dark")
        openCalendarSettings(app)
        let connect = app.buttons["calendar.connectReminders"]
        connect.scrollToVisibleIfNeeded(in: app)
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.click()
        let showCompleted = app.checkBoxes["settings.calendar.showCompleted"]
        showCompleted.scrollToVisibleIfNeeded(in: app)
        showCompleted.click()
        let preview = app.buttons["settings.calendar.dashboard"]
        for _ in 0..<8 where !preview.isHittable { app.scrollViews["settings.calendar"].scroll(byDeltaX: 0, deltaY: 320) }
        preview.click()
        app.checkBoxes["calendar.allReminders"].click()
        app.buttons["calendar.newReminder"].click()
        let title = app.textFields["calendar.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click(); title.typeText("Reminder sync UI task")
        app.descendants(matching: .any).matching(identifier: "calendar.editor.hasDueDate").firstMatch.click()
        screenshot(app, "Reminder editor — Dark")
        app.buttons["calendar.editor.save"].click()
        waitForEditorToClose(app)
        let complete = app.buttons["Complete Reminder sync UI task"]
        scrollAgenda(complete, in: app)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), app.debugDescription)
        complete.click()
        let reopen = app.buttons["Mark incomplete Reminder sync UI task"]
        scrollAgenda(reopen, in: app)
        XCTAssertTrue(reopen.waitForExistence(timeout: 5), app.debugDescription)
        reopen.click()
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: complete)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        let edit = app.buttons["Edit Reminder sync UI task"]
        scrollAgenda(edit, in: app)
        edit.click()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click(); title.typeKey("a", modifierFlags: .command); title.typeText("Updated reminder UI task")
        app.buttons["calendar.editor.save"].click()
        waitForEditorToClose(app)
        let updated = app.buttons["Edit Updated reminder UI task"]
        scrollAgenda(updated, in: app)
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        screenshot(app, "Calendar reminders — Dark")
        updated.click()
        app.buttons["calendar.editor.delete"].click()
        XCTAssertTrue(app.windows["calendar.editor"].sheets.buttons["Delete"].waitForExistence(timeout: 3), app.debugDescription)
        app.windows["calendar.editor"].sheets.buttons["Delete"].click()
        XCTAssertTrue(app.buttons["calendar.newReminder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Updated reminder UI task"].exists)
    }

    private func scrollAgenda(_ element: XCUIElement, in app: XCUIApplication) {
        _ = app.buttons["calendar.newEvent"].waitForExistence(timeout: 5)
        let scroll = app.scrollViews.matching(identifier: "calendar.agenda").firstMatch
        for _ in 0..<10 {
            let visible = scroll.frame.insetBy(dx: 0, dy: 8)
            if element.exists && element.isHittable && visible.contains(element.frame) { return }
            let dy: CGFloat = element.exists && element.frame.minY < visible.minY ? 140 : -140
            scroll.scroll(byDeltaX: 0, deltaY: dy)
        }
    }

    private func waitForEditorToClose(_ app: XCUIApplication) {
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.windows["calendar.editor"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed, app.debugDescription)
    }

    private func launch(access: String, appearance: String, remindersAccess: String = "notDetermined") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = suite
        app.launchEnvironment["DockMagicUITestCalendarAccess"] = access
        app.launchEnvironment["DockMagicUITestRemindersAccess"] = remindersAccess
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-DockMagicActiveFeature", "calendar", "-DockMagicAppearanceMode", appearance, "-DockMagicCodexExecutablePath", "/usr/bin/false", "-DockMagicAutomaticallyConfigureClaudeCode", "false"]
        app.launch()
        return app
    }

    private func openCalendarSettings(_ app: XCUIApplication) {
        app.activate()
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 5))
        let row = app.buttons["settings.nav.calendar"]
        for _ in 0..<6 where !row.isHittable { app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -320) }
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.click()
        XCTAssertTrue(app.buttons["settings.calendar.dashboard"].waitForExistence(timeout: 5), app.debugDescription)
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func checkboxValue(_ element: XCUIElement) -> Int? {
        if let value = element.value as? NSNumber { return value.intValue }
        return (element.value as? String).flatMap(Int.init)
    }
}

private extension XCUIElement {
    func scrollToVisibleIfNeeded(in app: XCUIApplication) {
        app.activate()
        let scroll = app.scrollViews["settings.calendar"]
        for _ in 0..<10 {
            let visible = scroll.frame.insetBy(dx: 0, dy: 12)
            if exists && isHittable && visible.contains(frame) { return }
            scroll.scroll(byDeltaX: 0, deltaY: exists && frame.minY < visible.minY ? 220 : -220)
        }
    }
}
