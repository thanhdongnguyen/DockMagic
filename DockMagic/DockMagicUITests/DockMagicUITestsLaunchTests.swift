import XCTest

final class DockMagicUITestsLaunchTests: XCTestCase {
    private let defaultsSuite =
        "DockMagicUITests.Launch.\(UUID().uuidString)"

    override func setUpWithError() throws {
        continueAfterFailure = false
        UserDefaults(suiteName: defaultsSuite)?
            .removePersistentDomain(forName: defaultsSuite)
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        UserDefaults(suiteName: defaultsSuite)?
            .removePersistentDomain(forName: defaultsSuite)
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = defaultsSuite
        app.launchArguments += [
            "-ApplePersistenceIgnoreState",
            "YES",
            "-DockMagicActiveFeature",
            "systemMetrics",
            "-DockMagicAppearanceMode",
            "system",
            "-DockMagicCodexExecutablePath",
            "/usr/bin/false",
            "-DockMagicAutomaticallyConfigureClaudeCode",
            "false"
        ]
        app.launch()

        let settingsWindow = app.windows["DockMagic Settings"]
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.staticTexts["System appearance"].exists)

        let attachment = XCTAttachment(screenshot: settingsWindow.screenshot())
        attachment.name = "DockMagic launch — System Glass Chrome"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
