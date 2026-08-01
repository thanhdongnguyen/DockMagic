import XCTest

final class DockMagicUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchPresentsLightSettingsWithRequestedSidebar() {
        let app = launchApp()
        let settings = app.windows["DockMagic Settings"]

        XCTAssertTrue(
            settings.waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.header"]
                .waitForExistence(timeout: 3),
            "Missing the DockMagic logo and Settings title in the window header."
        )
        XCTAssertTrue(app.staticTexts["Light appearance"].exists)

        for destination in [
            "General",
            "CPU & RAM",
            "Network",
            "Storage",
            "Weather",
            "Codex",
            "Claude Code",
            "About"
        ] {
            XCTAssertTrue(
                sidebarRow(named: destination, in: app).exists,
                "Missing \(destination) in the Settings sidebar."
            )
        }

        attachScreenshot(named: "Settings — General — Runtime Light")
    }

    func testSettingsDestinationsExposeFeatureControls() {
        let app = launchApp()
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "CPU & RAM", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.systemMetrics"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Ring appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.dockPreview"].exists
        )
        XCTAssertGreaterThanOrEqual(app.colorWells.count, 2)
        XCTAssertGreaterThanOrEqual(app.sliders.count, 2)
        attachScreenshot(named: "Settings — CPU RAM — Runtime Light")

        openSidebarDestination(named: "Network", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.network"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["60-second history"].exists)
        XCTAssertTrue(app.staticTexts["Chart appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.network.color.download"]
                .exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.network.color.upload"]
                .exists
        )
        attachScreenshot(named: "Settings — Network — Runtime Light")

        openSidebarDestination(named: "Storage", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.storage"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Ring appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.storage.color"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.storage.width"].exists
        )
        attachScreenshot(named: "Settings — Storage — Runtime Light")

        openSidebarDestination(named: "Weather", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.weather"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.weather.refresh"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.weather.attribution"].exists
        )
        XCTAssertTrue(app.staticTexts["Open-Meteo connection"].exists)
        XCTAssertTrue(app.staticTexts["Location & privacy"].exists)
        XCTAssertTrue(app.staticTexts["Location access"].exists)
        attachScreenshot(named: "Settings — Weather — Runtime Light")

        openSidebarDestination(named: "Codex", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.codex"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.codex.refresh"].exists
        )
        XCTAssertFalse(app.staticTexts["Usage limits"].exists)
        attachScreenshot(named: "Settings — Codex — Runtime Light")

        openSidebarDestination(named: "Claude Code", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.claudeCode"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.claudeCode.refresh"]
                .exists
        )
        XCTAssertTrue(app.staticTexts["Claude Code connection"].exists)
        attachScreenshot(named: "Settings — Claude Code — Runtime Light")
    }

    func testGeneralEnforcesOneActiveFeature() {
        let app = launchApp()
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )

        XCTAssertFalse(app.staticTexts["Window behavior"].exists)
        XCTAssertFalse(app.staticTexts["Privacy"].exists)

        let featurePicker = activeFeaturePicker(in: app)
        XCTAssertTrue(
            featurePicker.waitForExistence(timeout: 3),
            app.debugDescription
        )
        XCTAssertEqual(featurePicker.value as? String, "CPU & RAM")

        for title in [
            "DockMagic",
            "CPU & RAM",
            "Network",
            "Storage",
            "Weather",
            "Codex",
            "Claude Code",
            "CPU & RAM"
        ] {
            selectFeature(title, in: app)
        }
    }

    func testClosingThenUsingSettingsCommandReopensSingleSettingsWindow() {
        let app = launchApp()
        let settings = app.windows["DockMagic Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))

        settings.buttons[XCUIIdentifierCloseWindow].click()
        let disappeared = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: settings
        )
        wait(for: [disappeared], timeout: 3)

        app.activate()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertEqual(app.windows.count, 1)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-DockMagicActiveFeature",
            "systemMetrics",
            "-DockMagicCodexExecutablePath",
            "/usr/bin/false"
        ]
        app.launch()
        return app
    }

    private func selectFeature(
        _ title: String,
        in app: XCUIApplication
    ) {
        // SwiftUI rebuilds the General detail after the active feature changes.
        // Re-query the control so XCUI does not retain a stale element handle.
        let featurePicker = activeFeaturePicker(in: app)
        XCTAssertTrue(featurePicker.waitForExistence(timeout: 3))
        featurePicker.click()
        let rawValues = [
            "DockMagic": "dockMagic",
            "CPU & RAM": "systemMetrics",
            "Network": "network",
            "Storage": "storage",
            "Weather": "weather",
            "Codex": "codex",
            "Claude Code": "claudeCode"
        ]
        guard let rawValue = rawValues[title] else {
            XCTFail("Unknown active feature option: \(title)")
            return
        }
        let menuItem = app.menuItems[
            "settings.activeFeatureOption.\(rawValue)"
        ].firstMatch
        XCTAssertTrue(
            menuItem.waitForExistence(timeout: 2),
            "Missing active feature option: \(title)"
        )
        menuItem.click()

        if title == "Weather" {
            XCTAssertTrue(
                app.descendants(matching: .any)["settings.weather"]
                    .waitForExistence(timeout: 3),
                "Selecting Weather should open its permission guidance."
            )
            openSidebarDestination(named: "General", in: app)
        }

        // The selection binding rebuilds the General detail, including the
        // pop-up button. Query the replacement instead of reading the stale
        // element handle used to open the menu.
        let updatedFeaturePicker = activeFeaturePicker(in: app)
        XCTAssertTrue(
            updatedFeaturePicker.waitForExistence(timeout: 3),
            "Picker did not return after selecting \(title).\n\(app.debugDescription)"
        )
        XCTAssertEqual(updatedFeaturePicker.value as? String, title)
    }

    private func activeFeaturePicker(in app: XCUIApplication) -> XCUIElement {
        // SwiftUI promotes the selected option's accessibility identifier to
        // the macOS pop-up button. Its label remains stable across selection
        // changes, so use the public control label to re-query the rebuilt view.
        app.popUpButtons["Active Dock feature"].firstMatch
    }

    private func sidebarRow(
        named title: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let identifiers = [
            "General": "settings.nav.general",
            "CPU & RAM": "settings.nav.systemMetrics",
            "Network": "settings.nav.network",
            "Storage": "settings.nav.storage",
            "Weather": "settings.nav.weather",
            "Codex": "settings.nav.codex",
            "Claude Code": "settings.nav.claudeCode",
            "About": "settings.nav.about"
        ]

        guard let identifier = identifiers[title] else {
            XCTFail("Unknown Settings destination: \(title)")
            return app.descendants(matching: .any)[""].firstMatch
        }

        return app.buttons[identifier].firstMatch
    }

    private func openSidebarDestination(
        named title: String,
        in app: XCUIApplication
    ) {
        XCTAssertTrue(
            sidebarRow(named: title, in: app).waitForExistence(timeout: 5),
            "Missing \(title) sidebar destination.\n\(app.debugDescription)"
        )

        // Settings content and screenshot capture can invalidate an existing
        // AX snapshot. Resolve the button again immediately before clicking.
        sidebarRow(named: title, in: app).click()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
