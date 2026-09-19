import XCTest

final class AugmentUITests: XCTestCase {
    private let suite = "DockMagicAugmentUITests.\(UUID())"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

    func testSettingsConnectionDashboardAndUTCDetail() {
        let app = launch(mode: "setup")
        defer { app.terminate() }
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.nav.augment"].click()
        let token = app.secureTextFields["settings.augment.token"]
        XCTAssertTrue(token.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.augment.connect"].isEnabled)
        token.click(); token.typeText("fixture-only")
        app.buttons["settings.augment.connect"].click()
        XCTAssertTrue(app.staticTexts["Token saved in macOS Keychain"].waitForExistence(timeout: 5))
        let preview = app.buttons["settings.augment.dashboard"]
        app.activate()
        app.scrollViews["settings.augment"].scroll(byDeltaX: 0, deltaY: -240)
        capture(app, "Augment Settings Light")
        app.activate()
        preview.click()
        XCTAssertTrue(app.staticTexts["Daily history"].waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "Augment Dashboard Light")
        let range = app.descendants(matching: .any)["augment.history.range"]
        XCTAssertTrue(range.exists)
        range.buttons["7d"].click()
        XCTAssertTrue(app.buttons["augment.models.all"].exists)
        app.buttons["augment.models.all"].click()
        XCTAssertTrue(app.buttons["augment.detail.back"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Fixture model 1"].exists)
        XCTAssertFalse(app.staticTexts["Fixture compute"].exists)
        app.buttons["augment.detail.back"].click()
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", formatter.string(from: yesterday))).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), app.debugDescription)
        day.click()
        XCTAssertTrue(app.buttons["augment.detail.back"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Estimated USD"].exists)
        capture(app, "Augment UTC Detail")
        app.activate()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Daily history"].waitForExistence(timeout: 3), app.debugDescription)
    }

    func testPartialDayCanOpenDetailWhenOutputIsMissing() {
        let app = launch(mode: "partial")
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["settings.nav.augment"].waitForExistence(timeout: 10))
        app.buttons["settings.nav.augment"].click()
        let preview = app.buttons["settings.augment.dashboard"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        for _ in 0..<4 where !preview.isHittable { app.scrollViews["settings.augment"].swipeUp() }
        app.activate(); preview.click()
        XCTAssertTrue(app.staticTexts["Daily history"].waitForExistence(timeout: 5))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let formatter = DateFormatter(); formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", formatter.string(from: yesterday))).firstMatch
        XCTAssertTrue(day.isEnabled)
        day.click()
        XCTAssertTrue(app.staticTexts["Estimated USD"].waitForExistence(timeout: 3))
        capture(app, "Augment Partial UTC Detail")
    }

    func testEmptyAndAuthenticationErrorStayDistinct() {
        for mode in ["empty", "error"] {
            let app = launch(mode: mode)
            XCTAssertTrue(app.buttons["settings.nav.augment"].waitForExistence(timeout: 10))
            app.buttons["settings.nav.augment"].click()
            let expected = mode == "empty" ? "No reported data" : "Could not read usage"
            XCTAssertTrue(app.staticTexts[expected].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
            capture(app, "Augment \(mode)")
            app.terminate()
        }
    }
    private func launch(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = suite
        app.launchEnvironment["DockMagicUITestAugment"] = mode
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-DockMagicActiveFeature", "augment", "-DockMagicAppearanceMode", "light", "-DockMagicAutomaticallyConfigureClaudeCode", "false", "-DockMagicCodexExecutablePath", "/usr/bin/false"]
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
