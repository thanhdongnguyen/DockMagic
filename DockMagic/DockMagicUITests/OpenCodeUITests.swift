import XCTest
import SQLite3

final class OpenCodeUITests: XCTestCase {
    private var directory: URL!
    private var suite = "DockMagicOpenCodeUITests.\(UUID())"
    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCodeUI-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(directory.appendingPathComponent("opencode.db").path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE message(id TEXT, session_id TEXT, time_created INTEGER, data TEXT)", nil, nil, nil), SQLITE_OK)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        for index in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -index, to: Date.now)!
            let stamp = Int64(date.timeIntervalSince1970 * 1000)
            let input = (index % 7 + 1) * 123_456
            let json = "{\"role\":\"assistant\",\"modelID\":\"fixture-model\",\"providerID\":\"fixture-provider\",\"tokens\":{\"input\":\(input),\"output\":2345,\"reasoning\":123,\"cache\":{\"read\":12000,\"write\":500}},\"cost\":0.45,\"time\":{\"created\":\(stamp)}}"
            XCTAssertEqual(sqlite3_exec(db, "INSERT INTO message VALUES('m\(index)','s\(index)',\(stamp),'\(json)')", nil, nil, nil), SQLITE_OK)
        }
    }
    override func tearDownWithError() throws {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
    func testSettingsLayoutColorsAndRefresh() {
        let app = launch("light")
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 8))
        app.buttons["settings.nav.openCode"].click()
        let refresh = app.buttons["settings.openCode.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 8), app.debugDescription)
        screenshot(app, "OpenCode Settings Light")
        refresh.click()
        XCTAssertFalse(app.buttons["settings.openCode.dashboard"].exists)
        XCTAssertFalse(app.buttons["settings.openCode.activate"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "message + session_message")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "CLI ")).firstMatch.exists)

        let chartPurple = app.buttons["settings.openCode.chartColor.purple"]
        for _ in 0..<6 where !chartPurple.exists { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(chartPurple.waitForExistence(timeout: 5), app.debugDescription)
        chartPurple.click()
        app.buttons["settings.openCode.tokenColor.green"].click()
        XCTAssertEqual(
            app.descendants(matching: .any)["settings.openCode.chartColor"].label,
            "Chart color, selected #CB30E0"
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["settings.openCode.tokenColor"].label,
            "Token number color, selected #34C759"
        )
        XCTAssertFalse(app.staticTexts["Collection and cache"].exists)
        XCTAssertFalse(app.buttons["settings.openCode.clearCache"].exists)
        screenshot(app, "OpenCode Independent Colors Light")
        app.terminate()

        let dark = launch("dark")
        dark.buttons["settings.nav.openCode"].click()
        let reset = dark.buttons["settings.openCode.resetAppearance"]
        for _ in 0..<6 where !reset.exists { dark.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(reset.waitForExistence(timeout: 5), dark.debugDescription)
        XCTAssertEqual(dark.descendants(matching: .any)["settings.openCode.chartColor"].label,
            "Chart color, selected #CB30E0")
        XCTAssertEqual(dark.descendants(matching: .any)["settings.openCode.tokenColor"].label,
            "Token number color, selected #34C759")
        reset.click()
        XCTAssertEqual(dark.descendants(matching: .any)["settings.openCode.chartColor"].label,
            "Chart color, selected #0088FF")
        XCTAssertEqual(dark.descendants(matching: .any)["settings.openCode.tokenColor"].label,
            "Token number color, selected #0088FF")
        screenshot(dark, "OpenCode Settings Dark")
        dark.terminate()
    }
    private func launch(_ appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = suite
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-DockMagicActiveFeature", "openCode", "-DockMagicAppearanceMode", appearance,
            "-DockMagicOpenCodeDatabase", directory.appendingPathComponent("opencode.db").path,
            "-DockMagicOpenCodeUsed", "YES", "-DockMagicOpenCodeBackground", "NO",
            "-DockMagicCodexExecutablePath", "/usr/bin/false", "-DockMagicAutomaticallyConfigureClaudeCode", "false"]
        app.launch()
        return app
    }
    private func screenshot(_ app: XCUIApplication, _ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = title; attachment.lifetime = .keepAlways; add(attachment)
    }
}
