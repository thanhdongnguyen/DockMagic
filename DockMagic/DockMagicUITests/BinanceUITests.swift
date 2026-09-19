import XCTest

final class BinanceUITests: XCTestCase {
    func testColorPersistenceResetAndAccessibleControls() {
        let app = launch(count: 3, appearance: "dark")
        defer { app.terminate() }
        openSettings(app)
        let pink = app.buttons["settings.binance.color.dockPrice.pink"]
        for _ in 0..<8 where !pink.isHittable { app.scrollViews["settings.binance"].scroll(byDeltaX: 0, deltaY: -180) }
        XCTAssertTrue(pink.waitForExistence(timeout: 3))
        pink.click()
        capture(app, "Binance Colors — Custom Dock price")
        let colorMode = app.staticTexts["settings.binance.color.dockPrice.mode"]
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "#FF2D55"), object: colorMode)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, "Actual color mode: \(String(describing: colorMode.value))")
        app.terminate()
        let restored = launch(count: 0, appearance: "light")
        defer { restored.terminate() }
        openSettings(restored)
        XCTAssertTrue((restored.staticTexts["settings.binance.color.dockPrice.mode"].value as? String)?.contains("#FF2D55") == true)
        let reset = restored.buttons["settings.binance.resetAppearance"]
        for _ in 0..<8 where !reset.isHittable { restored.scrollViews["settings.binance"].scroll(byDeltaX: 0, deltaY: -180) }
        reset.click()
        XCTAssertEqual(restored.staticTexts["settings.binance.color.dockPrice.mode"].value as? String, "Automatic")
        let open = restored.buttons["settings.binance.dashboard"]
        for _ in 0..<8 where !open.isHittable { restored.scrollViews["settings.binance"].scroll(byDeltaX: 0, deltaY: 220) }
        open.click()
        let pin = restored.buttons["binance.pin.ETHUSDT"]
        XCTAssertTrue(pin.waitForExistence(timeout: 4))
        XCTAssertTrue(pin.label.contains("Unpin"))
        XCTAssertGreaterThanOrEqual(pin.frame.width, 36)
        XCTAssertGreaterThanOrEqual(pin.frame.height, 36)
        XCTAssertEqual(restored.buttons["binance.menu.ETHUSDT"].label, "Manage ETH / USDT")
        restored.buttons["binance.add"].click()
        let close = restored.buttons["binance.closeSearch"]
        XCTAssertEqual(close.label, "Close search")
        XCTAssertGreaterThanOrEqual(close.frame.height, 36)
        close.click()
        XCTAssertTrue(pin.exists, "Close must not reopen the finder through its container tap gesture")
        capture(restored, "Binance dashboard — Rounded controls after color reset")
    }

    func testSharedSettingsComponents() {
        let app = launch(count: 3, appearance: "light")
        defer { app.terminate() }
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 8))
        app.buttons["settings.nav.general"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings.appearancePicker"].waitForExistence(timeout: 3))
        capture(app, "Settings General — Shared solid buttons")
        app.buttons["settings.nav.claudeCode"].click()
        XCTAssertTrue(app.scrollViews["settings.claudeCode"].waitForExistence(timeout: 3))
        capture(app, "Settings Claude Code — Shared solid buttons")
        openSettings(app)
        capture(app, "Settings Binance — Shared solid buttons")
    }

    private var suite = "DockMagicBinanceUITests.\(UUID().uuidString)"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

    func testSearchAddPinRemoveAndSharedSettings() {
        let app = launch(count: 0, appearance: "dark")
        defer { app.terminate() }
        openSettings(app)
        app.buttons["settings.binance.dashboard"].click()
        XCTAssertTrue(app.staticTexts["Add your first coin"].waitForExistence(timeout: 5), app.debugDescription)
        add("BTC/USDT", symbol: "BTCUSDT", app: app)
        add("ETH/USDT", symbol: "ETHUSDT", app: app)
        add("SOL/USDT", symbol: "SOLUSDT", app: app)
        app.buttons["binance.pin.ETHUSDT"].click()
        XCTAssertTrue(app.buttons["binance.pin.ETHUSDT"].label.contains("Unpin"))
        capture(app, "Binance dashboard — Pinned Focus — Dark")
        app.buttons["binance.range.7D"].click()
        let picker = app.descendants(matching: .any)["binance.chartType"]
        XCTAssertTrue(picker.exists)
        picker.buttons["Candlestick"].click()
        app.buttons["binance.settings"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings.binance.chartType"].waitForExistence(timeout: 3))
        assertSelected(app.descendants(matching: .any)["settings.binance.chartType"].buttons["Candlestick"])
        XCTAssertEqual(app.buttons["settings.binance.range"].value as? String, "7D")
        capture(app, "Binance Settings — Shared configuration")
        app.terminate()
        let restored = launch(count: 0, appearance: "light")
        openSettings(restored)
        assertSelected(restored.descendants(matching: .any)["settings.binance.chartType"].buttons["Candlestick"])
        restored.buttons["settings.binance.dashboard"].click()
        XCTAssertTrue(restored.buttons["binance.pin.ETHUSDT"].waitForExistence(timeout: 4))
        XCTAssertTrue(restored.buttons["binance.pin.ETHUSDT"].label.contains("Unpin"))
        let menu = restored.buttons["binance.menu.ETHUSDT"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3), restored.debugDescription)
        menu.click()
        restored.buttons["Remove pair"].click()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: restored.buttons["binance.pin.ETHUSDT"])
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 3), .completed)
        XCTAssertTrue(restored.buttons["binance.pin.BTCUSDT"].exists)
        capture(restored, "Binance dashboard — Light — Removed pinned pair")
        restored.terminate()
    }

    func testTwentyPairsAndEmptySearch() {
        let app = launch(count: 20, appearance: "light")
        defer { app.terminate() }
        openSettings(app)
        app.buttons["settings.binance.dashboard"].click()
        XCTAssertTrue(app.buttons["binance.pin.ETHUSDT"].waitForExistence(timeout: 5))
        app.buttons["binance.add"].click()
        let search = app.textFields["binance.search"]
        search.click(); search.typeText("BTC/USDC")
        let result = app.buttons["binance.result.BTCUSDC"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertFalse(result.isEnabled)
        search.click(); search.typeKey("a", modifierFlags: .command); search.typeText("NO_SUCH_PAIR")
        XCTAssertTrue(app.staticTexts["No matching Spot pairs. Try a symbol such as BTC or BTC/USDT."].waitForExistence(timeout: 3))
        capture(app, "Binance — No matching pair")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["binance.pin.ETHUSDT"].exists)
    }
    private func launch(count: Int, appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = suite
        app.launchEnvironment["DockMagicUITestBinanceFixtures"] = "1"
        app.launchEnvironment["DockMagicUITestBinanceCount"] = String(count)
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-DockMagicActiveFeature", "binance", "-DockMagicAppearanceMode", appearance, "-DockMagicAutomaticallyConfigureClaudeCode", "false", "-DockMagicCodexExecutablePath", "/usr/bin/false"]
        app.launch()
        app.activate()
        return app
    }
    private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 8))
        let row = app.buttons["settings.nav.binance"]
        for _ in 0..<8 where !row.isHittable { app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -250) }
        XCTAssertTrue(row.waitForExistence(timeout: 4), app.debugDescription)
        row.click()
        XCTAssertTrue(app.buttons["settings.binance.dashboard"].waitForExistence(timeout: 5))
    }
    private func add(_ query: String, symbol: String, app: XCUIApplication) {
        app.buttons["binance.add"].click()
        let search = app.textFields["binance.search"]
        search.click(); search.typeText(query)
        let row = app.buttons["binance.result.\(symbol)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        row.click()
        XCTAssertTrue(app.buttons["binance.pin.\(symbol)"].waitForExistence(timeout: 5))
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows["DockMagic Settings"].screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func assertSelected(_ option: XCUIElement) {
        XCTAssertTrue(option.isSelected, option.debugDescription)
    }
}
