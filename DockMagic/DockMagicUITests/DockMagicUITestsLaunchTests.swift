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
            "-DockMagicCodexExecutablePath",
            "/usr/bin/false"
        ]
        app.launch()

        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.staticTexts["Light appearance"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "DockMagic launch — Light Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
