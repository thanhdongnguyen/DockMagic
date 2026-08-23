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
            "Batteries",
            "GitHub",
            "Codex",
            "Claude Code",
            "Search Console",
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

        openSidebarDestination(named: "Batteries", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.batteries"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Live Dock preview"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.batteries.dockPreview"
            ].exists
        )
        for id in [
            "ui.macbook",
            "ui.airpods",
            "ui.case",
            "ui.mouse"
        ] {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "settings.batteries.device.\(id)"
                ].waitForExistence(timeout: 3),
                "Missing battery device fixture: \(id)"
            )
        }
        attachScreenshot(
            named: "Settings — Batteries — Live Dock Preview",
            in: app
        )

        openSidebarDestination(named: "GitHub", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.github"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.github.dockPreview"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.github.repositoryURL"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.github.displayStyle"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.github.color.stars"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.github.color.forks"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.refreshCadence"
            ].exists
        )
        XCTAssertFalse(app.staticTexts["Authentication"].exists)
        attachScreenshot(
            named: "Settings — GitHub — Line Chart",
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

        openSidebarDestination(named: "Search Console", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.searchConsole"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.dockPreview"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.connection"
            ].exists
        )
        XCTAssertTrue(app.staticTexts["Data source & security"].exists)
        XCTAssertTrue(app.staticTexts["Private key in macOS Keychain"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.refresh"
            ].exists
        )
        attachScreenshot(
            named: "Settings — Search Console — Adaptive Focus",
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

    func testGitHubConnectionShowsFetchedCountsAndApplyControl() {
        let app = launchApp(
            activeFeature: "github",
            githubRepositoryURL: "https://github.com/apple/swift"
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "GitHub", in: app)

        XCTAssertTrue(
            app.staticTexts["Live"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.staticTexts["apple/swift"].exists)
        let stars = app.descendants(matching: .any)[
            "settings.github.metric.stars"
        ]
        let forks = app.descendants(matching: .any)[
            "settings.github.metric.forks"
        ]
        XCTAssertEqual(stars.value as? String, "12742")
        XCTAssertEqual(forks.value as? String, "824")
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.github.repositoryConnect"
            ].isEnabled
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.repositoryValid"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.refreshNow"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.repositoryDisconnect"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.token"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.tokenSave"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.github.refreshCadence"
            ].exists
        )

        attachScreenshot(
            named: "Settings — GitHub — Apply Only",
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
        XCTAssertTrue(
            featurePicker.isHittable,
            "The active Dock feature picker must receive pointer clicks."
        )

        for (index, title) in [
            "DockMagic",
            "CPU & RAM",
            "Network",
            "Storage",
            "Weather",
            "Batteries",
            "GitHub",
            "Codex",
            "Claude Code",
            "Search Console",
            "CPU & RAM"
        ].enumerated() {
            selectFeature(
                title,
                in: app,
                normalizedX: index.isMultiple(of: 2) ? 0.1 : 0.9
            )
        }
    }

    func testSearchConsoleEveryMetricTimeRangeAndDisplayMode() {
        let app = launchApp(appearance: "dark", activeFeature: "searchConsole")
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )
        openSidebarDestination(named: "Search Console", in: app)
        XCTAssertEqual(
            sidebarRow(named: "Search Console", in: app).value as? String,
            "Active"
        )

        selectSearchConsoleOption(
            picker: "primaryMetric",
            option: "clicks",
            expectedValue: "Clicks",
            in: app
        )
        selectSearchConsoleOption(
            picker: "primaryMetric",
            option: "impressions",
            expectedValue: "Impressions",
            in: app
        )

        for (option, title) in [
            ("last24Hours", "24h"),
            ("last7Days", "7d"),
            ("last28Days", "28d"),
            ("last3Months", "3m")
        ] {
            selectSearchConsoleOption(
                picker: "timeRange",
                option: option,
                expectedValue: title,
                in: app
            )
        }

        for (option, title) in [
            ("chart", "Chart"),
            ("numbers", "Numbers"),
            ("focus", "Focus")
        ] {
            selectSearchConsoleOption(
                picker: "displayMode",
                option: option,
                expectedValue: title,
                in: app
            )
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "settings.searchConsole.dockPreview"
                ].exists
            )
        }

        let refresh = app.descendants(matching: .any)[
            "settings.searchConsole.refresh"
        ].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 3))
        refresh.click()

        attachScreenshot(
            named: "Settings — Search Console — All Controls Verified",
            in: app
        )
    }

    func testSearchConsoleManageSheetAndPropertyControl() {
        let app = launchApp(appearance: "dark", activeFeature: "searchConsole")
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )
        openSidebarDestination(named: "Search Console", in: app)
        let manage = app.descendants(matching: .any)[
            "settings.searchConsole.manage"
        ].firstMatch
        XCTAssertTrue(
            manage.waitForExistence(timeout: 3),
            "The connected Search Console Manage action was unavailable."
        )
        manage.click()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.setupSteps"
            ].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.guide.googleCloud"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.guide.searchConsole"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.property"
            ].exists
        )
        app.buttons["Done"].click()
    }

    func testSearchConsoleAdaptiveFocusReferenceScreenshot() {
        let app = launchApp(appearance: "dark", activeFeature: "searchConsole")
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )
        openSidebarDestination(named: "Search Console", in: app)
        XCTAssertTrue(app.staticTexts["Search Console"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.dockPreview"
            ].waitForExistence(timeout: 3)
        )
        attachScreenshot(
            named: "Settings — Search Console — Adaptive Focus Reference",
            in: app
        )
    }

    func testBatteryReferenceLayoutAndActiveDockFeature() {
        let app = launchApp(appearance: "dark", activeFeature: "batteries")
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )
        openSidebarDestination(named: "Batteries", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.batteries.device.ui.mouse"
            ].waitForExistence(timeout: 3)
        )
        XCTAssertEqual(
            sidebarRow(named: "Batteries", in: app).value as? String,
            "Active"
        )
        attachScreenshot(
            named: "Settings — Batteries — Dark Reference",
            in: app
        )
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
        defaultsSuite: String? = nil,
        activeFeature: String = "systemMetrics",
        githubRepositoryURL: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchArguments += [
            "-ApplePersistenceIgnoreState",
            "YES",
            "-DockMagicActiveFeature",
            activeFeature,
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
        if let githubRepositoryURL {
            app.launchArguments += [
                "-DockMagicGitHubRepositoryURL",
                githubRepositoryURL
            ]
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
        in app: XCUIApplication,
        normalizedX: CGFloat = 0.5
    ) {
        // SwiftUI rebuilds the General detail after the active feature changes.
        // Re-query the control so XCUI does not retain a stale element handle.
        let featurePicker = activeFeaturePicker(in: app)
        XCTAssertTrue(featurePicker.waitForExistence(timeout: 3))
        featurePicker.coordinate(
            withNormalizedOffset: CGVector(dx: normalizedX, dy: 0.5)
        ).click()
        let rawValues = [
            "DockMagic": "dockMagic",
            "CPU & RAM": "systemMetrics",
            "Network": "network",
            "Storage": "storage",
            "Weather": "weather",
            "Batteries": "batteries",
            "GitHub": "github",
            "Codex": "codex",
            "Claude Code": "claudeCode",
            "Search Console": "searchConsole"
        ]
        guard let rawValue = rawValues[title] else {
            XCTFail("Unknown active feature option: \(title)")
            return
        }
        let option = app.buttons[
            "settings.activeFeatureOption.\(rawValue)"
        ].firstMatch
        XCTAssertTrue(
            option.waitForExistence(timeout: 2),
            "Missing active feature option: \(title)"
        )
        XCTAssertTrue(
            option.isHittable,
            "Active feature option is not clickable: \(title)"
        )
        option.click()

        if title == "Weather" || title == "Batteries" || title == "GitHub"
            || title == "Search Console" {
            let destination = switch title {
            case "Weather": "weather"
            case "Batteries": "batteries"
            case "Search Console": "searchConsole"
            default: "github"
            }
            XCTAssertTrue(
                app.descendants(matching: .any)["settings.\(destination)"]
                    .waitForExistence(timeout: 3),
                "Selecting \(title) should open its feature settings."
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
        let valueUpdated = expectation(
            for: NSPredicate(format: "value == %@", title),
            evaluatedWith: updatedFeaturePicker
        )
        wait(for: [valueUpdated], timeout: 3)
        XCTAssertEqual(updatedFeaturePicker.value as? String, title)
    }

    private func activeFeaturePicker(in app: XCUIApplication) -> XCUIElement {
        app.buttons["settings.activeFeaturePicker"].firstMatch
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
            "Batteries": "settings.nav.batteries",
            "GitHub": "settings.nav.github",
            "Codex": "settings.nav.codex",
            "Claude Code": "settings.nav.claudeCode",
            "Search Console": "settings.nav.searchConsole",
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

    private func selectSearchConsoleOption(
        picker: String,
        option: String,
        expectedValue: String,
        in app: XCUIApplication
    ) {
        var pickerElement = app.radioGroups[
            "settings.searchConsole.\(picker)"
        ].firstMatch
        XCTAssertTrue(
            pickerElement.waitForExistence(timeout: 3),
            "Missing Search Console picker: \(picker)"
        )

        let optionOrder: [String]
        switch picker {
        case "primaryMetric":
            optionOrder = ["clicks", "impressions"]
        case "timeRange":
            optionOrder = [
                "last24Hours", "last7Days", "last28Days", "last3Months"
            ]
        case "displayMode":
            optionOrder = ["chart", "numbers", "focus"]
        default:
            XCTFail("Unknown Search Console picker: \(picker)")
            return
        }
        guard let optionIndex = optionOrder.firstIndex(of: option) else {
            XCTFail("Unknown Search Console option: \(option)")
            return
        }

        // SwiftUI's segmented-control children occasionally disappear from
        // the macOS accessibility snapshot after a refresh. Click the actual
        // segment center through the stable radio-group frame instead.
        pickerElement.coordinate(
            withNormalizedOffset: CGVector(
                dx: (CGFloat(optionIndex) + 0.5) / CGFloat(optionOrder.count),
                dy: 0.5
            )
        ).click()

        pickerElement = app.radioGroups[
            "settings.searchConsole.\(picker)"
        ].firstMatch
        let updated = app.radioGroups[
            "settings.searchConsole.\(picker)"
        ].firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 3))
        let valueUpdated = expectation(
            for: NSPredicate(format: "value == %@", expectedValue),
            evaluatedWith: pickerElement
        )
        wait(for: [valueUpdated], timeout: 3)
        XCTAssertEqual(pickerElement.value as? String, expectedValue)
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
