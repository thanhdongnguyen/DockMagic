import XCTest

final class DockMagicUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-DockMagicActiveFeature",
            "systemMetrics",
            "-DockMagicAppearanceMode",
            "system",
            "-DockMagicCodexExecutablePath",
            "/usr/bin/false"
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
