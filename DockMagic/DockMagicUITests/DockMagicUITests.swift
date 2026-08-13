import XCTest

final class DockMagicUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchPresentsGlassSettingsWithRequestedSidebar() {
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
        XCTAssertTrue(app.staticTexts["System appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.appearancePicker"].exists
        )

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
        XCTAssertTrue(sidebarRow(named: "General", in: app).isSelected)
        XCTAssertEqual(
            sidebarRow(named: "CPU & RAM", in: app).value as? String,
            "Active"
        )

        attachScreenshot(
            named: "Settings — General — System Glass Chrome",
            in: app
        )
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
        selectDisplayStyle(.chart, in: app, feature: "CPU & RAM")
        XCTAssertTrue(app.staticTexts["Ring appearance"].exists)
        XCTAssertGreaterThanOrEqual(app.colorWells.count, 2)
        XCTAssertGreaterThanOrEqual(app.sliders.count, 2)
        selectNumericDisplay(in: app, feature: "CPU & RAM")
        XCTAssertTrue(app.staticTexts["Number appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.dockPreview"].exists
        )
        XCTAssertGreaterThanOrEqual(app.colorWells.count, 2)
        XCTAssertEqual(app.sliders.count, 0)
        attachScreenshot(
            named: "Settings — CPU RAM — Numeric",
            in: app
        )

        openSidebarDestination(named: "Network", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.network"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.staticTexts["60-second history"].exists)
        XCTAssertTrue(app.staticTexts["Chart appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.network.color.download"]
                .exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.network.color.upload"]
                .exists
        )
        attachScreenshot(
            named: "Settings — Network — System Glass Chrome",
            in: app
        )

        openSidebarDestination(named: "Storage", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.storage"]
                .waitForExistence(timeout: 3)
        )
        selectDisplayStyle(.chart, in: app, feature: "Storage")
        XCTAssertTrue(app.staticTexts["Ring appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.storage.width"].exists
        )
        selectNumericDisplay(in: app, feature: "Storage")
        XCTAssertTrue(app.staticTexts["Number appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.storage.color"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.storage.width"].exists
        )
        attachScreenshot(
            named: "Settings — Storage — Numeric",
            in: app
        )

        openSidebarDestination(named: "Weather", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.weather"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.weather.attribution"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.weather.location"].exists
        )
        XCTAssertFalse(app.staticTexts["Open-Meteo connection"].exists)
        XCTAssertFalse(app.staticTexts["Location & privacy"].exists)
        XCTAssertFalse(app.staticTexts["Location access"].exists)
        attachScreenshot(
            named: "Settings — Weather — System Glass Chrome",
            in: app
        )

        openSidebarDestination(named: "Codex", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.codex"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.staticTexts["Codex connection"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.codex.detect"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.codex.choose"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.codex.refresh"].exists
        )
        XCTAssertFalse(app.staticTexts["Usage limits"].exists)
        selectDisplayStyle(.chart, in: app, feature: "Codex")
        selectNumericDisplay(in: app, feature: "Codex")
        XCTAssertTrue(app.staticTexts["Number appearance"].exists)
        attachScreenshot(
            named: "Settings — Codex — Numeric",
            in: app
        )

        openSidebarDestination(named: "Claude Code", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.claudeCode"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.staticTexts["Claude Code connection"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.claudeCode.enable"]
                .exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.claudeCode.disable"]
                .exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.claudeCode.refresh"]
                .exists
        )
        selectDisplayStyle(.chart, in: app, feature: "Claude Code")
        selectNumericDisplay(in: app, feature: "Claude Code")
        XCTAssertTrue(app.staticTexts["Number appearance"].exists)
        attachScreenshot(
            named: "Settings — Claude Code — Numeric",
            in: app
        )

        openSidebarDestination(named: "About", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.about"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["Distribution"].exists)
        attachScreenshot(
            named: "Settings — About — System Glass Chrome",
            in: app
        )
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
        XCTAssertEqual(
            featurePicker.label,
            "Active Dock feature with CPU & RAM icon"
        )
        XCTAssertGreaterThanOrEqual(featurePicker.frame.width, 280)

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

    func testGeneralAppearanceControlExposesAllSupportedModes() {
        let app = launchApp()
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )

        let picker = app.descendants(matching: .any)["settings.appearancePicker"]
            .firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(picker.value as? String, "System")

        for rawValue in ["system", "light", "dark"] {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "settings.appearanceOption.\(rawValue)"
                ].exists,
                "Missing appearance option \(rawValue)."
            )
        }
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.appearanceOption.liquidGlass"
            ].exists
        )
    }

    func testAppearanceSelectionUpdatesAndPersistsAcrossRelaunch() {
        let suiteName = "DockMagicUITests.Appearance.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)

        // Do not pass the appearance launch argument in this test. Command-line
        // defaults outrank persisted defaults and would mask the value written
        // by the Settings control on relaunch.
        let app = launchApp(appearance: nil, defaultsSuite: suiteName)
        defer {
            XCUIApplication().terminate()
            isolatedDefaults.removePersistentDomain(forName: suiteName)
        }
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )
        app.activate()

        // Establish a deterministic starting point even when a developer has
        // previously changed the persisted preference on this test host.
        let systemOption = appearanceOption("system", in: app)
        XCTAssertTrue(systemOption.waitForExistence(timeout: 3))
        systemOption.click()
        XCTAssertTrue(
            app.staticTexts["System appearance"]
                .waitForExistence(timeout: 3)
        )

        let darkOption = appearanceOption("dark", in: app)
        XCTAssertTrue(darkOption.waitForExistence(timeout: 3))
        darkOption.click()

        XCTAssertTrue(
            app.staticTexts["Dark appearance"].waitForExistence(timeout: 3),
            "Appearance footer did not update after selecting Dark."
        )
        XCTAssertEqual(appearancePicker(in: app).value as? String, "Dark")

        app.terminate()
        let relaunched = launchApp(
            appearance: nil,
            defaultsSuite: suiteName
        )
        XCTAssertTrue(
            relaunched.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )
        relaunched.activate()
        XCTAssertTrue(
            relaunched.staticTexts["Dark appearance"]
                .waitForExistence(timeout: 3),
            "Dark appearance did not persist across relaunch."
        )
        XCTAssertEqual(
            appearancePicker(in: relaunched).value as? String,
            "Dark"
        )

        let restoredLightOption = appearanceOption("light", in: relaunched)
        XCTAssertTrue(restoredLightOption.waitForExistence(timeout: 3))
        restoredLightOption.click()
        XCTAssertTrue(
            relaunched.staticTexts["Light appearance"]
                .waitForExistence(timeout: 3)
        )
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

    private func launchApp(
        appearance: String? = "system",
        defaultsSuite: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-DockMagicActiveFeature",
            "systemMetrics",
            "-DockMagicCodexExecutablePath",
            "/usr/bin/false",
            // Keep UI automation from editing the developer account's real
            // ~/.claude/settings.json. Unit tests cover the default-on setup
            // path with an injected bridge.
            "-DockMagicAutomaticallyConfigureClaudeCode",
            "false"
        ]
        if let appearance {
            app.launchArguments += [
                "-DockMagicAppearanceMode",
                appearance
            ]
        }
        if let defaultsSuite {
            app.launchEnvironment[
                "DockMagicUITestDefaultsSuite"
            ] = defaultsSuite
        }
        app.launch()
        return app
    }

    private func appearancePicker(in app: XCUIApplication) -> XCUIElement {
        app.radioGroups["settings.appearancePicker"].firstMatch
    }

    private func appearanceOption(
        _ rawValue: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.radioButtons[
            "settings.appearanceOption.\(rawValue)"
        ].firstMatch
    }

    private func selectNumericDisplay(
        in app: XCUIApplication,
        feature: String
    ) {
        selectDisplayStyle(.numeric, in: app, feature: feature)
    }

    private enum DisplayStyle: String {
        case chart
        case numeric

        var title: String {
            switch self {
            case .chart: "Chart"
            case .numeric: "Numbers"
            }
        }
    }

    private func selectDisplayStyle(
        _ style: DisplayStyle,
        in app: XCUIApplication,
        feature: String
    ) {
        let picker = app.radioGroups["settings.displayStyle"].firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "Missing Dock display configuration for \(feature)."
        )

        let option = app.radioButtons[
            "settings.displayStyleOption.\(style.rawValue)"
        ].firstMatch
        XCTAssertTrue(
            option.waitForExistence(timeout: 3),
            "Missing \(style.title) Dock display option for \(feature)."
        )
        option.click()

        // Selecting an option rebuilds the section. Re-query so repeated UI
        // runs do not retain a stale accessibility element handle.
        let updatedPicker = app.radioGroups["settings.displayStyle"].firstMatch
        XCTAssertTrue(updatedPicker.waitForExistence(timeout: 3))
        XCTAssertEqual(updatedPicker.value as? String, style.title)
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
        app.descendants(matching: .any)["settings.activeFeaturePicker"]
            .firstMatch
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

    private func attachScreenshot(
        named name: String,
        in app: XCUIApplication
    ) {
        let window = app.windows["DockMagic Settings"].firstMatch
        XCTAssertTrue(window.exists, "Cannot capture a missing Settings window.")
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
