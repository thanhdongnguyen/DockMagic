import XCTest

final class DockMagicUITests: XCTestCase {
    private let automaticDefaultsSuite =
        "DockMagicUITests.Automatic.\(UUID().uuidString)"

    override func setUpWithError() throws {
        continueAfterFailure = false
        UserDefaults(suiteName: automaticDefaultsSuite)?
            .removePersistentDomain(forName: automaticDefaultsSuite)
    }

    override func tearDownWithError() throws {
        UserDefaults(suiteName: automaticDefaultsSuite)?
            .removePersistentDomain(forName: automaticDefaultsSuite)
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
        let launchAtLoginToggle = app.descendants(matching: .any)[
            "settings.launchAtLogin.toggle"
        ]
        XCTAssertTrue(
            launchAtLoginToggle.exists,
            "Missing the Launch at login control in General settings."
        )
        XCTAssertTrue(
            launchAtLoginToggle.isEnabled,
            "Launch at login should remain actionable when registration is missing."
        )

        for destination in [
            "General",
            "CPU & RAM",
            "Network",
            "Storage",
            "Weather",
            "Clock",
            "Batteries",
            "GitHub",
            "Codex",
            "Claude Code",
            "Antigravity",
            "Search Console"
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

    func testUpdateAvailableFooterAndAutomaticUpdateControls() {
        let app = launchApp(
            appearance: "dark",
            updateAvailableVersion: "1.0.2"
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        let updateFooter = app.descendants(matching: .any)[
            "settings.updateAvailable"
        ]
        XCTAssertTrue(updateFooter.waitForExistence(timeout: 3))
        XCTAssertEqual(
            updateFooter.label,
            "Update available, version 1.0.2"
        )
        XCTAssertTrue(updateFooter.isEnabled)

        let generalScrollView = app.scrollViews["settings.general"].firstMatch
        XCTAssertTrue(generalScrollView.waitForExistence(timeout: 3))
        generalScrollView.scroll(byDeltaX: 0, deltaY: -1_000)

        var automaticChecks = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticChecks"
        ]
        var automaticDownloads = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticDownloads"
        ]
        XCTAssertTrue(automaticChecks.waitForExistence(timeout: 3))
        XCTAssertTrue(automaticDownloads.waitForExistence(timeout: 3))
        XCTAssertTrue(automaticChecks.isEnabled)
        XCTAssertTrue(automaticDownloads.isEnabled)
        XCTAssertTrue(automaticChecks.isHittable)

        automaticChecks.click()
        automaticChecks = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticChecks"
        ]
        XCTAssertEqual(
            automaticChecks.label,
            "Automatically check for updates, Off"
        )
        automaticDownloads = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticDownloads"
        ]
        XCTAssertFalse(automaticDownloads.isEnabled)

        automaticChecks = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticChecks"
        ]
        automaticChecks.click()
        automaticDownloads = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticDownloads"
        ]
        XCTAssertTrue(automaticDownloads.isEnabled)
        XCTAssertTrue(automaticDownloads.isHittable)
        automaticDownloads.click()
        automaticDownloads = app.descendants(matching: .any)[
            "settings.softwareUpdate.automaticDownloads"
        ]
        XCTAssertEqual(
            automaticDownloads.label,
            "Automatically download updates, On"
        )

        openSidebarDestination(named: "Batteries", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.batteries"]
                .waitForExistence(timeout: 3)
        )

        attachScreenshot(
            named: "Settings — Batteries — Update Available — Dark",
            in: app
        )
    }

    func testClockIsDockOnlyAndConfiguresStyleAndLocation() {
        let app = launchApp(appearance: "light", activeFeature: "clock")
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertEqual(
            sidebarRow(named: "Clock", in: app).value as? String,
            "Active"
        )

        let hoverToggle = app.descendants(matching: .any)[
            "settings.dockHover.toggle"
        ]
        XCTAssertTrue(hoverToggle.waitForExistence(timeout: 3))
        XCTAssertFalse(
            hoverToggle.isEnabled,
            "Clock must not expose an actionable hover-dashboard toggle."
        )

        var stylePicker = app.radioGroups["settings.clock.style"].firstMatch
        XCTAssertTrue(stylePicker.waitForExistence(timeout: 3))
        XCTAssertEqual(stylePicker.value as? String, "Digital")
        guard let splitFlap = waitForHittableRadioButton(
            identifiedBy: "settings.clock.styleOption.splitFlap",
            in: app,
            timeout: 3
        ) else {
            return XCTFail("Missing Split-flap Clock style in General.")
        }
        splitFlap.click()
        stylePicker = app.radioGroups["settings.clock.style"].firstMatch
        XCTAssertEqual(stylePicker.value as? String, "Split-flap")

        openSidebarDestination(named: "Clock", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.clock"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.clock.dockPreview"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.clock.noDashboard"].exists
        )
        stylePicker = app.radioGroups["settings.clock.style"].firstMatch
        XCTAssertEqual(stylePicker.value as? String, "Split-flap")

        let followToggle = app.descendants(matching: .any)[
            "settings.clock.followSystemTimeZone"
        ]
        XCTAssertTrue(followToggle.waitForExistence(timeout: 3))
        followToggle.click()
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.clock.location"]
                .waitForExistence(timeout: 3),
            "Turning off the Mac time zone should reveal another-location selection."
        )

        attachScreenshot(
            named: "Settings — Clock — Split-flap Custom Location",
            in: app
        )
    }

    func testSettingsDestinationsExposeFeatureControls() {
        let app = launchApp(antigravityConnected: true)
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
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.cpu.ring"]
                .exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.ram.ring"]
                .exists
        )
        XCTAssertGreaterThanOrEqual(app.sliders.count, 2)
        selectNumericDisplay(in: app, feature: "CPU & RAM")
        XCTAssertTrue(app.staticTexts["Number appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.dockPreview"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.cpu.value"]
                .exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.ram.value"]
                .exists
        )
        XCTAssertEqual(app.colorWells.count, 0)
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
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.5.hour.value"]
                .exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.weekly.value"]
                .exists
        )
        attachScreenshot(
            named: "Settings — Codex — Numeric",
            in: app
        )

        openSidebarDestination(named: "Claude Code", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.claudeCode"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Claude Code connection"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.claudeCode.connectionStatus"
            ].exists
        )
        XCTAssertTrue(
            app.buttons["settings.claudeCode.install"].exists,
            "A missing Claude CLI should require an explicit install action."
        )
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
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.5.hour.value"]
                .exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.ringColor.weekly.value"]
                .exists
        )
        attachScreenshot(
            named: "Settings — Claude Code — Numeric",
            in: app
        )

        openSidebarDestination(named: "Antigravity", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.antigravity"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Antigravity"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.antigravity.connectionStatus"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.buttons["settings.antigravity.refresh"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            app.buttons["settings.antigravity.installationIndicator"].exists,
            "Authentication state should not overlay the Dock preview."
        )
        XCTAssertFalse(app.staticTexts["Local session metrics"].exists)
        XCTAssertFalse(
            app.buttons["settings.antigravity.statusLine"].exists
        )
        selectDisplayStyle(.chart, in: app, feature: "Antigravity")
        selectNumericDisplay(in: app, feature: "Antigravity")
        XCTAssertTrue(app.staticTexts["Number appearance"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.ringColor.primary.pool.value"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.ringColor.secondary.pool.value"
            ].exists
        )
        attachScreenshot(
            named: "Settings — Antigravity — Numeric",
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
        XCTAssertTrue(app.staticTexts["Data source & storage"].exists)
        XCTAssertTrue(app.staticTexts["Complete JSON files in SwiftData"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.refresh"
            ].exists
        )
        attachScreenshot(
            named: "Settings — Search Console — Adaptive Focus",
            in: app
        )
    }

    func testInlineColorPaletteSelectsAndPersistsWithoutOpeningPanel() {
        let suiteName = "DockMagicUITests.ColorPalette.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        defer {
            XCUIApplication().terminate()
            isolatedDefaults.removePersistentDomain(forName: suiteName)
        }

        let app = launchApp(defaultsSuite: suiteName)
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "CPU & RAM", in: app)
        selectNumericDisplay(in: app, feature: "CPU & RAM")

        let palette = app.descendants(matching: .any)[
            "settings.ringColor.cpu.value"
        ]
        XCTAssertTrue(palette.waitForExistence(timeout: 3))
        XCTAssertEqual(
            palette.label,
            "CPU value, selected #FF8D28"
        )

        let orange = app.buttons[
            "settings.ringColor.cpu.value.orange"
        ]
        XCTAssertTrue(orange.waitForExistence(timeout: 3))
        XCTAssertEqual(orange.value as? String, "#FF8D28")

        let purple = app.buttons[
            "settings.ringColor.cpu.value.purple"
        ]
        XCTAssertTrue(purple.waitForExistence(timeout: 3))
        XCTAssertTrue(purple.isHittable)
        purple.click()

        XCTAssertEqual(purple.value as? String, "#CB30E0")
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertEqual(
            app.descendants(matching: .any)[
                "settings.ringColor.cpu.value"
            ].label,
            "CPU value, selected #CB30E0"
        )

        app.terminate()
        let relaunched = launchApp(defaultsSuite: suiteName)
        XCTAssertTrue(
            relaunched.windows["DockMagic Settings"]
                .waitForExistence(timeout: 5)
        )
        openSidebarDestination(named: "CPU & RAM", in: relaunched)
        selectNumericDisplay(in: relaunched, feature: "CPU & RAM")

        let persistedPurple = relaunched.buttons[
            "settings.ringColor.cpu.value.purple"
        ]
        XCTAssertTrue(persistedPurple.waitForExistence(timeout: 3))
        XCTAssertEqual(persistedPurple.value as? String, "#CB30E0")
        XCTAssertEqual(
            relaunched.descendants(matching: .any)[
                "settings.ringColor.cpu.value"
            ].label,
            "CPU value, selected #CB30E0"
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

        let featurePicker = hittableActiveFeaturePicker(in: app)
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
            "Clock",
            "Batteries",
            "GitHub",
            "Codex",
            "Claude Code",
            "Antigravity",
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

    func testOpeningDeveloperToolSettingsAutomaticallyPreparesCLIs() {
        let app = launchApp()
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
        )

        openSidebarDestination(named: "Codex", in: app)
        assertDeveloperToolInstalledIndicator(
            rawValue: "codex",
            title: "Codex CLI installed",
            in: app
        )
        XCTAssertEqual(
            sidebarRow(named: "CPU & RAM", in: app).value as? String,
            "Active"
        )

        openSidebarDestination(named: "Claude Code", in: app)
        XCTAssertTrue(
            app.buttons["settings.claudeCode.install"]
                .waitForExistence(timeout: 3)
        )
        app.buttons["settings.claudeCode.install"].click()
        assertDeveloperToolInstalledIndicator(
            rawValue: "claudeCode",
            title: "Claude Code installed",
            in: app
        )
        XCTAssertTrue(
            app.buttons["settings.claudeCode.signIn"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertEqual(
            sidebarRow(named: "CPU & RAM", in: app).value as? String,
            "Active"
        )
    }

    func testClaudeConnectedRowIsCompactAndOffersSignOut() {
        let app = launchApp(
            appearance: "light",
            activeFeature: "claudeCode",
            claudeConnected: true
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "Claude Code", in: app)

        let connectionStatus = app.descendants(matching: .any)[
            "settings.claudeCode.connectionStatus"
        ]
        XCTAssertTrue(connectionStatus.waitForExistence(timeout: 3))
        XCTAssertTrue(connectionStatus.label.contains("Connected"))
        XCTAssertTrue(
            app.buttons["settings.claudeCode.refresh"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            app.staticTexts[
                "Sign in with the official Claude CLI. DockMagic reads plan quota from /usage once per minute."
            ].exists
        )
        XCTAssertFalse(
            app.staticTexts[
                "DockMagic never reads or stores your Claude token. It runs the unmodified official Claude CLI and keeps only quota percentages, reset times, CLI version, and capture time."
            ].exists
        )

        let moreActions = app.buttons["settings.claudeCode.moreActions"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 3))
        moreActions.click()

        let signOut = app.descendants(matching: .any)[
            "settings.claudeCode.signOut"
        ]
        XCTAssertTrue(signOut.waitForExistence(timeout: 3))
        XCTAssertEqual(signOut.label, "Sign Out")
        app.typeKey(.escape, modifierFlags: [])

        attachScreenshot(
            named: "Settings — Claude Code — Compact Connected Row",
            in: app
        )
    }

    func testClaudeSignInTerminalUsesDarkNativeChrome() throws {
        let executableURL = try makeClaudeLoginFixtureExecutable()
        let app = launchApp(
            appearance: "light",
            activeFeature: "claudeCode",
            claudeExecutablePath: executableURL.path
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "Claude Code", in: app)
        let signIn = app.buttons["settings.claudeCode.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 3))
        signIn.click()

        let terminal = app.descendants(matching: .any)[
            "settings.claudeCode.loginTerminal"
        ]
        XCTAssertTrue(terminal.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.claudeCode.terminal.title"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.claudeCode.terminal.profile"
            ].exists
        )

        attachScreenshot(
            named: "Settings — Claude Code — Native Terminal Sign In",
            in: app
        )

        let cancel = app.buttons["settings.claudeCode.cancelSignIn"]
        XCTAssertTrue(cancel.exists)
        cancel.click()
        XCTAssertTrue(signIn.waitForExistence(timeout: 3))
    }

    func testClaudeConnectedActionsRemainHittableAfterLoginCompletes() throws {
        let fixture = try makeClaudeSuccessfulLoginFixture()
        let app = launchApp(
            appearance: "light",
            activeFeature: "claudeCode",
            claudeExecutablePath: "/bin/zsh",
            claudeLoginMarkerPath: fixture.markerURL.path,
            claudeLoginWorkingDirectoryPath: fixture.directoryURL.path
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "Claude Code", in: app)
        let signIn = app.buttons["settings.claudeCode.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 3))
        signIn.click()

        let refresh = app.buttons["settings.claudeCode.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        XCTAssertTrue(refresh.isHittable)

        let moreActions = app.buttons["settings.claudeCode.moreActions"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 3))
        XCTAssertTrue(moreActions.isHittable)
        moreActions.click()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.claudeCode.signOut"
            ].waitForExistence(timeout: 3)
        )
    }

    func testAntigravityLoginOpensInteractiveCLIInsideSettings() throws {
        try assertAntigravityLoginCLIIsFullyVisible(appearance: "light")
    }

    func testAntigravityLoginCLIIsFullyVisibleInDarkAppearance() throws {
        try assertAntigravityLoginCLIIsFullyVisible(appearance: "dark")
    }

    func testAntigravitySettingsHidesLocalMetricsAndLegacyBridgeActions() {
        assertAntigravitySettingsHasNoLocalMetrics(appearance: "dark")
    }

    func testAntigravitySettingsHidesLocalMetricsInLightAppearance() {
        assertAntigravitySettingsHasNoLocalMetrics(appearance: "light")
    }

    private func assertAntigravitySettingsHasNoLocalMetrics(
        appearance: String
    ) {
        let app = launchApp(
            appearance: appearance,
            activeFeature: "antigravity",
            antigravitySignedOut: true,
            antigravityBridgeInstalled: true,
            antigravityExecutablePath: "/usr/bin/true"
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "Antigravity", in: app)
        XCTAssertTrue(
            app.buttons["settings.antigravity.signIn"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Local session metrics"].exists)
        XCTAssertFalse(app.buttons["settings.antigravity.statusLine"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.antigravity.moreActions"
            ].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.antigravity.disconnectSessionMetrics"
            ].exists
        )
        attachScreenshot(
            named: "Settings — Antigravity — No Local Session Metrics — \(appearance)",
            in: app
        )
    }

    private func assertAntigravityLoginCLIIsFullyVisible(
        appearance: String
    ) throws {
        let executableURL = try makeAntigravityLoginFixtureExecutable()
        let app = launchApp(
            appearance: appearance,
            activeFeature: "antigravity",
            antigravitySignedOut: true,
            antigravityExecutablePath: executableURL.path
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "Antigravity", in: app)
        let terminal = app.descendants(matching: .any)[
            "settings.antigravity.authTerminal"
        ]
        XCTAssertFalse(
            terminal.exists,
            "Opening Antigravity Settings must not start the login CLI."
        )
        let signIn = app.buttons["settings.antigravity.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 3))
        XCTAssertEqual(signIn.label, "Sign in with Antigravity")
        signIn.click()

        XCTAssertTrue(terminal.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.buttons["settings.antigravity.pasteCode"].exists
        )
        XCTAssertFalse(
            app.buttons["settings.antigravity.openInTerminal"].exists
        )

        attachScreenshot(
            named: "Settings — Antigravity — Interactive CLI Sign In — \(appearance)",
            in: app
        )

        let detailScrollView = app.scrollViews[
            "settings.antigravity"
        ].firstMatch
        detailScrollView.scroll(byDeltaX: 0, deltaY: -180)
        XCTAssertGreaterThanOrEqual(
            terminal.frame.height,
            240,
            "The native CLI surface must retain enough height for its 18 rows."
        )
        let cancel = app.buttons["settings.antigravity.cancelAuth"]
        XCTAssertTrue(cancel.isHittable)
        XCTAssertGreaterThan(
            cancel.frame.minY,
            terminal.frame.maxY,
            "Authentication actions must stay below the complete CLI surface."
        )
        attachScreenshot(
            named: "Settings — Antigravity — Full CLI and Actions — \(appearance)",
            in: app
        )
        cancel.click()
        XCTAssertTrue(signIn.waitForExistence(timeout: 3))
    }

    func testAntigravitySignOutUsesLoadingWithoutShowingTerminal() {
        let app = launchApp(
            appearance: "light",
            activeFeature: "antigravity",
            antigravityConnected: true,
            antigravityExecutablePath: "/usr/bin/true"
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )

        openSidebarDestination(named: "Antigravity", in: app)
        let connectionStatus = app.descendants(matching: .any)[
            "settings.antigravity.connectionStatus"
        ]
        let connected = expectation(
            for: NSPredicate(format: "value CONTAINS %@", "Connected"),
            evaluatedWith: connectionStatus
        )
        wait(for: [connected], timeout: 5)

        let moreActions = app.buttons["settings.antigravity.moreActions"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 3))
        XCTAssertTrue(moreActions.isHittable)
        moreActions.click()

        let signOut = app.descendants(matching: .any)[
            "settings.antigravity.signOut"
        ]
        XCTAssertTrue(signOut.waitForExistence(timeout: 3))
        signOut.click()

        let signingOut = expectation(
            for: NSPredicate(format: "value CONTAINS %@", "Signing out"),
            evaluatedWith: connectionStatus
        )
        wait(for: [signingOut], timeout: 3)
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.antigravity.authTerminal"
            ].exists,
            "Signing out must not expose the Antigravity terminal UI."
        )

        let signIn = app.buttons["settings.antigravity.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 8))
        XCTAssertEqual(signIn.label, "Sign in with Antigravity")
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "settings.antigravity.authTerminal"
            ].exists
        )
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

    func testSearchConsoleManageSheetAndPropertyControl() throws {
        let importedKeyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dockmagic-search-console-ui-import.json")
        let importedKeyData = try JSONSerialization.data(withJSONObject: [
            "type": "service_account",
            "project_id": "ui-import-project",
            "private_key_id": "ui-import-third",
            "private_key": "-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----",
            "client_email": "imported@ui-import-project.iam.gserviceaccount.com",
            "token_uri": "https://oauth2.googleapis.com/token"
        ])
        try importedKeyData.write(to: importedKeyURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: importedKeyURL) }

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
                "settings.searchConsole.credentialList"
            ].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.credential.ui-test-primary"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.credential.ui-test-secondary"
            ].exists
        )
        let secondaryUse = app.descendants(matching: .any)[
            "settings.searchConsole.credential.use.ui-test-secondary"
        ].firstMatch
        XCTAssertTrue(secondaryUse.exists)
        let sheetImport = app.buttons[
            "settings.searchConsole.sheetImport"
        ].firstMatch
        XCTAssertTrue(sheetImport.exists)
        XCTAssertTrue(
            sheetImport.isHittable,
            "The JSON key import action should be available inside Management."
        )
        sheetImport.click()
        let openImport = app.sheets.buttons["Open"].firstMatch
        XCTAssertTrue(
            openImport.waitForExistence(timeout: 3),
            "Add JSON Key should present the macOS file importer above Management.\n\(app.debugDescription)"
        )
        app.typeKey("G", modifierFlags: [.command, .shift])
        let pathField = app.textFields["PathTextField"].firstMatch
        XCTAssertTrue(
            pathField.waitForExistence(timeout: 3),
            "The file importer should support direct keyboard path navigation."
        )
        pathField.click()
        pathField.typeKey("a", modifierFlags: .command)
        pathField.typeText(importedKeyURL.path)
        app.typeKey(.return, modifierFlags: [])
        let confirmImport = app.sheets.buttons["Open"].firstMatch
        XCTAssertTrue(confirmImport.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmImport.isEnabled)
        confirmImport.click()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.credential.ui-import-third"
            ].waitForExistence(timeout: 3),
            "The selected JSON file should be imported into Management."
        )
        let credentialSummary = app.staticTexts[
            "settings.searchConsole.credentialSummary"
        ].firstMatch
        XCTAssertTrue(credentialSummary.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["3 keys stored locally in SwiftData"]
                .waitForExistence(timeout: 3),
            "A successful import should update the stored-key summary."
        )
        let updatedSecondaryUse = app.descendants(matching: .any)[
            "settings.searchConsole.credential.use.ui-test-secondary"
        ].firstMatch
        XCTAssertTrue(updatedSecondaryUse.waitForExistence(timeout: 3))
        updatedSecondaryUse.click()
        let primaryUse = app.descendants(matching: .any)[
            "settings.searchConsole.credential.use.ui-test-primary"
        ].firstMatch
        XCTAssertTrue(
            primaryUse.waitForExistence(timeout: 3),
            "Selecting the secondary key did not update the active key."
        )
        XCTAssertFalse(updatedSecondaryUse.exists)

        let propertyPicker = app.buttons[
            "settings.searchConsole.property"
        ].firstMatch
        XCTAssertTrue(
            propertyPicker.waitForExistence(timeout: 3),
            "The active key should expose the design-system Property selector."
        )
        XCTAssertEqual(
            propertyPicker.value as? String,
            "https://www.example.com/"
        )
        propertyPicker.click()
        let domainProperty = app.buttons[
            "settings.searchConsole.property.option.sc-domain:example.com"
        ].firstMatch
        XCTAssertTrue(
            domainProperty.waitForExistence(timeout: 3),
            "The Property selector should expose every accessible property."
        )
        XCTAssertTrue(domainProperty.isHittable)
        domainProperty.click()
        let updatedPropertyPicker = app.buttons[
            "settings.searchConsole.property"
        ].firstMatch
        let propertyUpdated = expectation(
            for: NSPredicate(format: "value == %@", "sc-domain:example.com"),
            evaluatedWith: updatedPropertyPicker
        )
        wait(for: [propertyUpdated], timeout: 3)
        XCTAssertEqual(
            updatedPropertyPicker.value as? String,
            "sc-domain:example.com"
        )

        let removePrimary = app.descendants(matching: .any)[
            "settings.searchConsole.credential.remove.ui-test-primary"
        ].firstMatch
        XCTAssertTrue(removePrimary.exists)
        removePrimary.click()
        let cancelRemoval = app.sheets.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelRemoval.waitForExistence(timeout: 3))
        cancelRemoval.click()
        XCTAssertTrue(primaryUse.exists)
        let setupGuide = app.descendants(matching: .any)[
            "settings.searchConsole.setupGuide"
        ].firstMatch
        XCTAssertTrue(setupGuide.exists)
        attachScreenshot(
            named: "Settings — Search Console — JSON Key Manager",
            in: app
        )
        let sheetScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(sheetScrollView.exists)
        sheetScrollView.scroll(byDeltaX: 0, deltaY: -600)
        for step in 1...5 {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "settings.searchConsole.setupStep.\(step)"
                ].exists,
                "Missing Search Console setup step \(step)."
            )
        }
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.dataDelayNote"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "settings.searchConsole.guide.api"
            ].exists
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
        attachScreenshot(
            named: "Settings — Search Console — Setup Guide",
            in: app
        )
        XCTAssertFalse(app.buttons["Done"].exists)
        let close = app.descendants(matching: .any)[
            "settings.searchConsole.sheetClose"
        ].firstMatch
        XCTAssertTrue(close.exists)
        close.click()
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
        githubRepositoryURL: String? = nil,
        updateAvailableVersion: String? = nil,
        claudeConnected: Bool = false,
        claudeExecutablePath: String? = nil,
        claudeLoginMarkerPath: String? = nil,
        claudeLoginWorkingDirectoryPath: String? = nil,
        antigravitySignedOut: Bool = false,
        antigravityConnected: Bool = false,
        antigravityBridgeInstalled: Bool = false,
        antigravityExecutablePath: String? = nil
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
        app.launchEnvironment[
            "DockMagicUITestDefaultsSuite"
        ] = defaultsSuite ?? automaticDefaultsSuite
        if let updateAvailableVersion {
            app.launchEnvironment[
                "DockMagicUITestUpdateAvailableVersion"
            ] = updateAvailableVersion
        }
        if claudeConnected {
            app.launchEnvironment["DockMagicUITestClaudeConnected"] = "1"
        }
        if let claudeExecutablePath {
            app.launchEnvironment[
                "DockMagicUITestClaudeExecutablePath"
            ] = claudeExecutablePath
        }
        if let claudeLoginMarkerPath {
            app.launchEnvironment[
                "DockMagicUITestClaudeLoginMarkerPath"
            ] = claudeLoginMarkerPath
        }
        if let claudeLoginWorkingDirectoryPath {
            app.launchEnvironment[
                "DockMagicUITestClaudeLoginWorkingDirectoryPath"
            ] = claudeLoginWorkingDirectoryPath
        }
        if antigravitySignedOut {
            app.launchEnvironment[
                "DockMagicUITestAntigravitySignedOut"
            ] = "1"
        }
        if antigravityConnected {
            app.launchEnvironment[
                "DockMagicUITestAntigravityConnected"
            ] = "1"
        }
        if antigravityBridgeInstalled {
            app.launchEnvironment[
                "DockMagicUITestAntigravityBridgeInstalled"
            ] = "1"
        }
        if let antigravityExecutablePath {
            app.launchEnvironment[
                "DockMagicUITestAntigravityExecutablePath"
            ] = antigravityExecutablePath
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

    private func makeClaudeLoginFixtureExecutable() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DockMagic-Claude-Terminal-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let executableURL = directoryURL.appendingPathComponent("claude")
        let script = """
        #!/bin/zsh
        trap 'exit 0' INT TERM
        printf '\\033[1;35mClaude Code\\033[0m\\r\\n'
        printf 'Opening browser to sign in…\\r\\n'
        printf 'Paste code here if prompted > '
        IFS= read -r code
        while true; do
          /bin/sleep 1
        done
        """
        try Data(script.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return executableURL
    }

    private func makeAntigravityLoginFixtureExecutable() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DockMagic-Antigravity-Terminal-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let executableURL = directoryURL.appendingPathComponent("agy")
        let script = """
        #!/bin/zsh
        trap 'exit 0' INT TERM
        printf '\\033[1;36mAntigravity CLI\\033[0m\\r\\n'
        printf 'Paste your Antigravity code and press Return > '
        IFS= read -r code
        while true; do
          /bin/sleep 1
        done
        """
        try Data(script.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return executableURL
    }

    private func makeClaudeSuccessfulLoginFixture() throws -> (
        directoryURL: URL,
        markerURL: URL
    ) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DockMagic-Claude-Successful-Login-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let markerURL = directoryURL.appendingPathComponent("authenticated")
        let quotedMarkerPath = markerURL.path.replacingOccurrences(
            of: "'",
            with: "'\\''"
        )
        let authScriptURL = directoryURL.appendingPathComponent("auth")
        let script = """
        printf 'Claude login complete\\r\\n'
        : > '\(quotedMarkerPath)'
        /bin/sleep 0.2
        exit 0
        """
        try Data(script.utf8).write(to: authScriptURL, options: .atomic)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return (directoryURL, markerURL)
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
        let scrollIdentifiers = [
            "CPU & RAM": "settings.systemMetrics",
            "Storage": "settings.storage",
            "Codex": "settings.codex",
            "Claude Code": "settings.claudeCode",
            "Antigravity": "settings.antigravity"
        ]
        let identifiedScrollView = scrollIdentifiers[feature].map {
            app.scrollViews[$0].firstMatch
        }
        let detailScrollView = identifiedScrollView?.exists == true
            ? identifiedScrollView
            : app.scrollViews.allElementsBoundByIndex
                .filter { $0.exists }
                .max(by: { $0.frame.width < $1.frame.width })
        if let detailScrollView, detailScrollView.exists {
            detailScrollView.scroll(byDeltaX: 0, deltaY: 1_000)
        }

        let picker = app.radioGroups["settings.displayStyle"].firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "Missing Dock display configuration for \(feature)."
        )

        let optionIdentifier = "settings.displayStyleOption.\(style.rawValue)"
        let option = waitForHittableRadioButton(
            identifiedBy: optionIdentifier,
            in: app,
            timeout: 1
        )
        guard let option else {
            XCTFail(
                "Missing clickable \(style.title) Dock display option for \(feature)."
            )
            return
        }
        option.click()

        // Selecting an option rebuilds the section, so verify the resulting
        // controls rather than retaining a transient accessibility handle.
        let resultingSectionTitle = if style == .numeric {
            "Number appearance"
        } else {
            "Ring appearance"
        }
        XCTAssertTrue(
            app.staticTexts[resultingSectionTitle].waitForExistence(timeout: 3),
            "Selecting \(style.title) did not update \(feature)."
        )
    }

    private func waitForHittableRadioButton(
        identifiedBy identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let matches = app.radioButtons.matching(
                NSPredicate(format: "identifier == %@", identifier)
            ).allElementsBoundByIndex
            if let option = matches.first(where: { $0.exists && $0.isHittable }) {
                return option
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return nil
    }

    private func selectFeature(
        _ title: String,
        in app: XCUIApplication,
        normalizedX: CGFloat = 0.5
    ) {
        // SwiftUI rebuilds the General detail after the active feature changes.
        // Re-query the control so XCUI does not retain a stale element handle.
        let featurePicker = hittableActiveFeaturePicker(in: app)
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
            "Clock": "clock",
            "Batteries": "batteries",
            "GitHub": "github",
            "Codex": "codex",
            "Claude Code": "claudeCode",
            "Antigravity": "antigravity",
            "Search Console": "searchConsole"
        ]
        guard let rawValue = rawValues[title] else {
            XCTFail("Unknown active feature option: \(title)")
            return
        }
        let option = app.descendants(matching: .any)[
            "settings.activeFeatureOption.\(rawValue)"
        ].firstMatch
        if option.waitForExistence(timeout: 0.5), option.isHittable {
            option.click()
        } else {
            // On macOS 14, SwiftUI renders this NSPopover in a transient
            // accessibility window that XCUI does not attach to the target
            // application's element tree. Its layout is intentionally fixed:
            // 44-point rows, 4-point gaps, and 8-point vertical padding.
            let orderedTitles = [
                "DockMagic",
                "CPU & RAM",
                "Network",
                "Storage",
                "Weather",
                "Clock",
                "Batteries",
                "GitHub",
                "Codex",
                "Claude Code",
                "Antigravity",
                "Search Console"
            ]
            guard let rowIndex = orderedTitles.firstIndex(of: title) else {
                XCTFail("Missing popover row mapping: \(title)")
                return
            }
            let rowsBelow = orderedTitles.count - rowIndex - 1
            let rowCenterOffset = -64 - CGFloat(rowsBelow * 48)
            let settingsWindow = app.windows["DockMagic Settings"].firstMatch
            settingsWindow.coordinate(
                withNormalizedOffset: CGVector(dx: 0, dy: 0)
            )
                .withOffset(
                    CGVector(
                        dx: featurePicker.frame.midX
                            - settingsWindow.frame.minX,
                        dy: featurePicker.frame.midY + rowCenterOffset
                            - settingsWindow.frame.minY
                    )
                )
                .click()
        }

        if title == "Weather" || title == "Batteries" || title == "GitHub"
            || title == "Codex" || title == "Claude Code"
            || title == "Antigravity"
            || title == "Search Console" {
            let destination = switch title {
            case "Weather": "weather"
            case "Batteries": "batteries"
            case "Codex": "codex"
            case "Claude Code": "claudeCode"
            case "Antigravity": "antigravity"
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

    private func hittableActiveFeaturePicker(
        in app: XCUIApplication
    ) -> XCUIElement {
        var picker = activeFeaturePicker(in: app)

        for _ in 0 ..< 5 {
            if picker.exists, picker.isHittable {
                return picker
            }
            if let detailScrollView = app.scrollViews.allElementsBoundByIndex
                .filter({ $0.exists })
                .max(by: { $0.frame.width < $1.frame.width }) {
                detailScrollView.scroll(byDeltaX: 0, deltaY: -320)
            }
            picker = activeFeaturePicker(in: app)
        }
        return picker
    }

    private func assertDeveloperToolInstalledIndicator(
        rawValue: String,
        title: String,
        in app: XCUIApplication
    ) {
        let status = app.buttons[
            "settings.\(rawValue).installationIndicator"
        ].firstMatch
        XCTAssertTrue(
            status.waitForExistence(timeout: 3),
            "Missing compact \(title) indicator."
        )
        let detected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", title),
            object: status
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [detected], timeout: 3),
            .completed,
            "Opening \(title) settings should prepare its CLI automatically."
        )
        XCTAssertEqual(
            status.value as? String,
            "DockMagic is using /usr/bin/true. Click to check the connection."
        )
        XCTAssertFalse(
            app.staticTexts["CLI integration"].exists,
            "Developer-tool status should stay inside the Dock preview."
        )

        let dockPreview = app.descendants(matching: .any)[
            "settings.dockPreview"
        ].firstMatch
        XCTAssertTrue(dockPreview.exists, "Missing Dock preview for \(title).")
        XCTAssertGreaterThan(
            status.frame.minX,
            dockPreview.frame.maxX,
            "The installation indicator should be on the preview's right side."
        )
        XCTAssertLessThan(
            status.frame.maxY,
            dockPreview.frame.midY,
            "The installation indicator should be in the preview's top-right corner."
        )
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
            "Clock": "settings.nav.clock",
            "Batteries": "settings.nav.batteries",
            "GitHub": "settings.nav.github",
            "Codex": "settings.nav.codex",
            "Claude Code": "settings.nav.claudeCode",
            "Antigravity": "settings.nav.antigravity",
            "Search Console": "settings.nav.searchConsole"
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
