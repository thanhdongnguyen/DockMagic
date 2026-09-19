import XCTest

final class GrokUITests: XCTestCase {
    private var suite = "DockMagicGrokUITests.\(UUID())"
    private var launchedApp: XCUIApplication?
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        // Also runs after a failed assertion in the multi-state test.
        launchedApp?.terminate()
        launchedApp = nil
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func testFlagOffDoesNotExposeGrok() {
        let app = launch(mode: "available", flag: false)
        defer { app.terminate() }
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["settings.nav.grokBuild"].exists)
    }

    func testAuthenticationCompletionQuotaUnavailableAndConfirmedLogoutKeepLocalHistory() {
        let app = launch(mode: "auth-complete")
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let signIn = app.buttons["settings.grokBuild.signIn"]
        scrollSettings(app, to: signIn)
        XCTAssertTrue(signIn.isEnabled)
        signIn.click()
        let status = app.staticTexts["settings.grokBuild.connection"]
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "Sign-in command completed"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 8), .completed, app.debugDescription)
        XCTAssertTrue(text(status).contains("quota not verified"))
        XCTAssertTrue(app.staticTexts["Local: live"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.grokBuild.authTerminal"].exists)
        capture(app, "Grok auth — command completed, quota not verified")
        let signOut = app.buttons["settings.grokBuild.signOut"]
        scrollSettings(app, to: signOut)
        signOut.click()
        let confirm = app.buttons["settings.grokBuild.confirmSignOut"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), app.debugDescription)
        confirm.click()
        let loggedOut = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "logout command completed"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [loggedOut], timeout: 8), .completed)
        XCTAssertTrue(text(status).contains("could not be verified"))
        XCTAssertTrue(app.staticTexts["Local: live"].exists)
        XCTAssertTrue(signIn.isEnabled)
        capture(app, "Grok auth — logout completed, history retained")
    }

    func testDeviceAuthenticationCancelAndNavigationCancel() {
        let app = launch(mode: "auth-cancel")
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let device = app.buttons["settings.grokBuild.deviceCode"]
        scrollSettings(app, to: device)
        device.click()
        let cancel = app.buttons["settings.grokBuild.cancelAuth"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        XCTAssertFalse(device.isEnabled)
        capture(app, "Grok auth — device-code in progress")
        cancel.click()
        let status = app.staticTexts["settings.grokBuild.connection"]
        let cancelled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS[c] %@", "cancelled"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: 5), .completed)
        XCTAssertTrue(device.isEnabled)
        // Removing the progress/output region changes the scroll geometry.
        // Resolve the button in the settled viewport before retrying.
        scrollSettings(app, to: device)
        device.click()
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), app.debugDescription)
        app.buttons["settings.nav.general"].click()
        app.buttons["settings.nav.grokBuild"].click()
        scrollSettings(app, to: status)
        let navigated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS[c] %@", "cancelled"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [navigated], timeout: 5), .completed)
        XCTAssertFalse(app.descendants(matching: .any)["settings.grokBuild.authTerminal"].exists)
        XCTAssertTrue(app.staticTexts["Local: live"].exists)
    }

    func testAuthenticationTimeoutIsRetryableNotSignedOut() {
        let app = launch(mode: "auth-timeout")
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let signIn = app.buttons["settings.grokBuild.signIn"]
        scrollSettings(app, to: signIn)
        signIn.click()
        let status = app.staticTexts["settings.grokBuild.connection"]
        let timeout = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "timeout"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [timeout], timeout: 8), .completed)
        XCTAssertTrue(signIn.isEnabled)
        XCTAssertFalse(text(status).contains("Signed out"))
        XCTAssertTrue(app.staticTexts["Local: live"].exists)
        capture(app, "Grok auth — timeout, retry available")
    }

    func testSettingsQuotaSeparationAndBadgeBackEscape() {
        let app = launch(mode: "available")
        defer { app.terminate() }
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5), app.debugDescription)
        let preview = app.buttons["settings.grokBuild.dashboard"]
        scrollSettings(app, to: preview)
        XCTAssertFalse(app.buttons["Sign in with Grok"].isEnabled)
        XCTAssertFalse(app.buttons["Device code"].isEnabled)
        XCTAssertFalse(app.buttons["Sign out"].isEnabled)
        let metric = app.buttons["settings.grokBuild.metric"]
        XCTAssertTrue(metric.exists, app.debugDescription)
        XCTAssertTrue(metric.value as? String == "Quota remaining")
        metric.click()
        app.buttons["Tokens observed today"].click()
        capture(app, "Grok Settings — explicit token metric")
        openDashboard(app)
        XCTAssertTrue(app.staticTexts["grokBuild.today"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["grokBuild.quotaUnavailable"].exists)
        XCTAssertTrue(text(app.staticTexts["grokBuild.today"]).contains("36"))
        XCTAssertFalse(app.buttons["Save image"].exists)
        let streak = app.buttons["grokBuild.streak.open"]
        XCTAssertTrue(streak.waitForExistence(timeout: 5), app.windows.debugDescription)
        streak.click()
        let back = app.buttons["grokBuild.streak.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "Grok Badge detail")
        back.click()
        XCTAssertTrue(streak.waitForExistence(timeout: 3))
        streak.click()
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(streak.waitForExistence(timeout: 3), "Escape should return to overview, not close its preview. \(app.debugDescription)")
        capture(app, "Grok Overview — returned with Escape")
        app.buttons["settings.grokBuild.closePreview"].click()
        XCTAssertFalse(app.staticTexts["grokBuild.today"].exists)
    }

    func testUnknownAndFailureAreNotZeroOrSignedOut() {
        for mode in ["empty", "error"] {
            suite = "DockMagicGrokUITests.\(UUID())"
            let app = launch(mode: mode)
            enable(app)
            let expected = mode == "empty" ? "Local: unavailable" : "Local: failed"
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5), app.debugDescription)
            let preview = app.buttons["settings.grokBuild.dashboard"]
            scrollSettings(app, to: preview)
            openDashboard(app)
            XCTAssertTrue(app.staticTexts["grokBuild.quotaUnavailable"].waitForExistence(timeout: 5), app.windows.debugDescription)
            if mode == "empty" {
                XCTAssertEqual(text(app.staticTexts["grokBuild.today"]), "—")
                let coverage = app.staticTexts["Model coverage unavailable: no eligible tokens observed. Same 30-day window; unobserved days remain unknown."]
                let dashboard = app.scrollViews["grokBuild.overview"]
                for _ in 0..<6 where !coverage.exists { dashboard.scroll(byDeltaX: 0, deltaY: -180) }
                XCTAssertTrue(coverage.exists, app.windows.debugDescription)
            }
            capture(app, "Grok \(mode)")
            app.terminate()
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
    }

    func testTokenColorPersistsAcrossRelaunchAndResetKeepsMetricAndPaths() {
        let app = launch(mode: "available")
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let metric = app.buttons["settings.grokBuild.metric"]
        scrollSettings(app, to: metric)
        metric.click()
        app.buttons["Tokens observed today"].click()
        let purple = app.buttons["settings.grokBuild.tokenColor.purple"]
        scrollSettings(app, to: purple)
        purple.click()
        XCTAssertEqual(app.descendants(matching: .any)["settings.grokBuild.tokenColor"].label,
            "Grok token data color, selected #CB30E0")
        XCTAssertEqual(app.windows.count, 1, "Inline palette must not open a color panel")
        capture(app, "Grok — purple token renderer selection")
        app.terminate()

        let relaunched = launch(mode: "available")
        defer { relaunched.terminate() }
        XCTAssertTrue(relaunched.windows["DockMagic Settings"].waitForExistence(timeout: 10))
        relaunched.activate()
        relaunched.buttons["settings.nav.grokBuild"].click()
        XCTAssertTrue(relaunched.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let reset = relaunched.buttons["settings.grokBuild.resetAppearance"]
        scrollSettings(relaunched, to: reset)
        XCTAssertEqual(relaunched.descendants(matching: .any)["settings.grokBuild.tokenColor"].label,
            "Grok token data color, selected #CB30E0")
        reset.click()
        XCTAssertEqual(relaunched.descendants(matching: .any)["settings.grokBuild.tokenColor"].label,
            "Grok token data color, selected #0088FF")
        XCTAssertEqual(relaunched.buttons["settings.grokBuild.metric"].value as? String, "Tokens observed today")
        XCTAssertEqual(relaunched.textFields["settings.grokBuild.executable"].value as? String, "/fixture/grok")
        XCTAssertEqual(relaunched.textFields["settings.grokBuild.home"].value as? String, "/fixture/grok-home")
        XCTAssertTrue(relaunched.staticTexts["Local: live"].exists)
        capture(relaunched, "Grok — Reset Defaults preserves token metric and local connection")
    }

    func testNewActivityCelebrationIsNotReplayed() {
        let app = launch(mode: "celebration")
        defer { app.terminate() }
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let preview = app.buttons["settings.grokBuild.dashboard"]
        scrollSettings(app, to: preview)
        openDashboard(app)
        XCTAssertTrue(app.staticTexts["grokBuild.today"].waitForExistence(timeout: 5), app.windows.debugDescription)
        XCTAssertEqual(text(app.staticTexts["grokBuild.today"]), "—")
        XCTAssertFalse(app.buttons["View badges"].exists, "Backfill must not celebrate")
        app.buttons["grokBuild.refresh"].click()
        let celebration = app.buttons["View badges"]
        XCTAssertTrue(celebration.waitForExistence(timeout: 3), app.debugDescription)
        // This test verifies the transient notification and its once-only
        // claim. Badge navigation has a separate, persistent-control test;
        // AX auto-scrolling can outlast the production banner's 2.8 seconds.
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: celebration)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        app.buttons["grokBuild.refresh"].click()
        XCTAssertFalse(celebration.waitForExistence(timeout: 3), "Claimed celebration must not replay")
    }

    func testDisablingIntegrationCancelsLoading() {
        let app = launch(mode: "loading")
        defer { app.terminate() }
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: loading"].waitForExistence(timeout: 5), app.windows.debugDescription)
        XCTAssertFalse(app.buttons["settings.grokBuild.refresh"].isEnabled)
        app.checkBoxes["settings.grokBuild.enabled"].click()
        XCTAssertTrue(app.staticTexts["Local: notConfigured"].waitForExistence(timeout: 5), app.windows.debugDescription)
        XCTAssertFalse(app.checkBoxes["settings.grokBuild.monitoring"].isEnabled)
        XCTAssertFalse(app.buttons["settings.grokBuild.refresh"].isEnabled)
        capture(app, "Grok — loading cancelled by disabling integration")
    }

    func testFailedRefreshRetainsStaleObservedTokensWithoutQuotaFallback() {
        let app = launch(mode: "stale")
        defer { app.terminate() }
        enable(app)
        XCTAssertTrue(app.staticTexts["Local: live"].waitForExistence(timeout: 5))
        let refresh = app.buttons["settings.grokBuild.refresh"]
        scrollSettings(app, to: refresh)
        refresh.click()
        XCTAssertTrue(app.staticTexts["Local: stale"].waitForExistence(timeout: 5), app.windows.debugDescription)
        scrollSettings(app, to: app.buttons["settings.grokBuild.dashboard"])
        XCTAssertEqual(app.buttons["settings.grokBuild.metric"].value as? String, "Quota remaining")
        openDashboard(app)
        XCTAssertTrue(text(app.staticTexts["grokBuild.today"]).contains("36"))
        XCTAssertTrue(app.staticTexts["Experimental · local stale"].exists)
        XCTAssertTrue(app.staticTexts["grokBuild.quotaUnavailable"].exists)
        capture(app, "Grok — stale local data retained, quota still unavailable")
    }

    private func enable(_ app: XCUIApplication) {
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 10))
        app.activate()
        let navigation = app.buttons["settings.nav.grokBuild"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 10), app.debugDescription)
        navigation.click()
        let enabled = app.checkBoxes["settings.grokBuild.enabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 5), app.debugDescription)
        enabled.click()
    }

    private func scrollSettings(_ app: XCUIApplication, to element: XCUIElement) {
        let scroll = app.scrollViews["settings.grokBuild"]
        app.activate()
        for _ in 0..<10 {
            if element.exists, scroll.frame.insetBy(dx: 0, dy: 8).contains(element.frame) { break }
            let delta: CGFloat = element.exists && element.frame.minY < scroll.frame.minY ? 220 : -220
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(element.exists && scroll.frame.contains(element.frame), app.windows.debugDescription)
    }

    private func openDashboard(_ app: XCUIApplication) {
        app.buttons["settings.grokBuild.dashboard"].click()
        // At expansion time the outer viewport is still over the Settings
        // controls, not the dashboard's nested scroll view. Reveal the whole
        // compact preview once, before interacting with its own controls.
        app.scrollViews["settings.grokBuild"].scroll(byDeltaX: 0, deltaY: -800)
        XCTAssertTrue(app.buttons["grokBuild.refresh"].waitForExistence(timeout: 5), app.windows.debugDescription)
    }

    // Native macOS StaticText usually exposes its contents as AXValue, not
    // AXLabel. Do not mistake an empty label for empty provider data.
    private func text(_ element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty { return value }
        return element.label
    }

    private func launch(mode: String, flag: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        launchedApp = app
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = suite
        app.launchEnvironment["DockMagicUITestGrok"] = mode
        app.launchEnvironment["DOCKMAGIC_EXPERIMENTAL_GROK"] = flag ? "1" : "0"
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-DockMagicActiveFeature", "systemMetrics", "-DockMagicAppearanceMode", "light",
            "-DockMagicAutomaticallyConfigureClaudeCode", "false", "-DockMagicCodexExecutablePath", "/usr/bin/false",
            "-DockMagicOpenCodeDatabase", "/fixture/absent-opencode.db", "-DockMagicOpenCodeBackground", "NO"]
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
