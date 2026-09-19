import XCTest

final class MaiaUITests: XCTestCase {
    private var suite = "DockMagicUITests.Maia.\(UUID().uuidString)"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["DockMagicUITesting": "1", "DockMagicUITestDefaultsSuite": suite, "DockMagicMaiaGallery": "1"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["maia.gallery"].waitForExistence(timeout: 8), app.debugDescription)
        return app
    }

    func testNativeTextEditingAndDisabledAction() {
        let app = launch()
        defer { app.terminate() }
        let input = app.textFields["maia.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3), app.debugDescription)
        input.click()
        input.typeKey("a", modifierFlags: .command)
        input.typeText("Maia 123")
        XCTAssertEqual(input.value as? String, "Maia 123")
        input.typeKey("z", modifierFlags: .command)
        XCTAssertNotEqual(input.value as? String, "Maia 123")
        XCTAssertFalse(app.buttons["maia.disabled"].isEnabled)
        capture(app, "Maia fields and actions")
    }

    func testMenuEscapeAndDialogDefaultCancelActions() {
        let app = launch()
        defer { app.terminate() }
        let menu = app.buttons["maia.menu"]
        menu.click()
        XCTAssertTrue(app.buttons["Copy fixture"].waitForExistence(timeout: 3), app.debugDescription)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["Copy fixture"].exists)
        menu.click()
        app.buttons["Copy fixture"].click()
        XCTAssertEqual(app.staticTexts["maia.lastAction"].value as? String, "Copied")
        XCTAssertFalse(app.buttons["Copy fixture"].exists)
        app.buttons["maia.dialog"].click()
        XCTAssertTrue(app.staticTexts["Delete fixture?"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].click()
        XCTAssertFalse(app.staticTexts["Delete fixture?"].exists)
        XCTAssertEqual(app.staticTexts["maia.lastAction"].value as? String, "Cancelled")
        app.buttons["maia.dialog"].click()
        XCTAssertTrue(app.staticTexts["Delete fixture?"].waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.staticTexts["Delete fixture?"].exists)
        app.buttons["maia.dialog"].click()
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(app.staticTexts["maia.lastAction"].value as? String, "Deleted")
    }

    func testSelectSearchKeyboardAndAppearanceMatrix() {
        let app = launch()
        defer { app.terminate() }
        let select = app.descendants(matching: .any)["maia.select"].firstMatch
        for _ in 0..<4 where !select.isHittable { app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -180) }
        select.click()
        XCTAssertTrue(app.buttons["Beta"].waitForExistence(timeout: 3), app.debugDescription)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(app.buttons["maia.select"].value as? String, "Beta")
        let searchable = app.descendants(matching: .any)["maia.searchSelect"].firstMatch
        searchable.click()
        let query = app.textFields["Search City"]
        XCTAssertTrue(query.waitForExistence(timeout: 3), app.debugDescription)
        query.typeText("Hồ")
        XCTAssertTrue(app.buttons["Hồ Chí Minh"].exists)
        XCTAssertFalse(app.buttons["Đà Nẵng"].exists)
        app.buttons["Hồ Chí Minh"].click()
        capture(app, "Maia Light selection")
        app.buttons["maia.dark"].click()
        capture(app, "Maia Dark selection")
    }

    func testSegmentedControlKeyboardSkipsDisabledAndReflectsSelection() {
        let app = launch()
        defer { app.terminate() }
        let chart = app.buttons["maia.segment.chart"]
        for _ in 0..<4 where !chart.isHittable { app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -180) }
        XCTAssertTrue(chart.exists, app.debugDescription)
        chart.click()
        XCTAssertFalse(app.buttons["maia.segment.disabled"].isEnabled)
        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertEqual(app.staticTexts["maia.segment.value"].value as? String, "numbers")
        app.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertEqual(app.staticTexts["maia.segment.value"].value as? String, "chart")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(app.staticTexts["maia.segment.value"].value as? String, "numbers")
        capture(app, "Maia segmented keyboard and selection")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
