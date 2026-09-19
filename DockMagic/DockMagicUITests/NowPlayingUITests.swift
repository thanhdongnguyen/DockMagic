import XCTest

final class NowPlayingUITests: XCTestCase {
    private let suite = "DockMagicNowPlayingUITests.\(UUID().uuidString)"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

    func testOpenTransportPinSourceAndEscapeWithoutAccessibility() {
        let app = launch(mode: "playing", appearance: "dark")
        openDashboard(app)
        assertTrack("A quiet afternoon", in: app)
        let source = app.buttons["nowPlaying.source"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), app.debugDescription)
        source.click()
        app.buttons["Spotify"].click()
        let playPause = app.buttons["nowPlaying.playPause"]
        XCTAssertEqual(playPause.label, "Pause")
        playPause.click()
        let play = NSPredicate(format: "label == %@", "Play")
        expectation(for: play, evaluatedWith: playPause)
        waitForExpectations(timeout: 5)
        app.buttons["nowPlaying.pin"].click()
        XCTAssertTrue(app.buttons["nowPlaying.close"].exists)
        screenshot(app, "Now Playing pinned — Dark")
        app.buttons["Next song"].click()
        assertTrack("Through the pines", in: app)
        if source.exists { source.click() } else { app.buttons["nowPlaying.source"].click() }
        app.buttons["Apple Music"].click()
        assertTrack("Evening in motion", in: app)
        let volume = app.sliders["nowPlaying.volume"]
        XCTAssertTrue(volume.isEnabled)
        volume.adjust(toNormalizedSliderPosition: 0.3)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["nowPlaying.playPause"].exists)
    }

    func testLightAndUnknownDuration() {
        let app = launch(mode: "unknownDuration", appearance: "light")
        openDashboard(app)
        assertTrack("A quiet afternoon", in: app)
        let seek = app.sliders["nowPlaying.seek"]
        let seekDisabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == false"), object: seek)
        XCTAssertEqual(XCTWaiter.wait(for: [seekDisabled], timeout: 5), .completed)
        XCTAssertTrue(app.sliders["nowPlaying.volume"].isEnabled)
        screenshot(app, "Now Playing — Light — Unknown duration")
        app.typeKey(.escape, modifierFlags: [])
    }

    func testDeniedSourceKeepsHeaderAndRecoveryVisible() {
        let app = launch(mode: "denied", appearance: "dark")
        openDashboard(app)
        XCTAssertTrue(app.staticTexts["Allow access to Spotify"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nowPlaying.source"].isHittable)
        XCTAssertTrue(app.buttons["nowPlaying.pin"].isHittable)
        XCTAssertTrue(app.buttons["Open Automation Settings"].isHittable)
        screenshot(app, "Now Playing — Denied source recovery")
        app.typeKey(.escape, modifierFlags: [])
    }

    private func launch(mode: String, appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = suite
        app.launchEnvironment["DockMagicUITestNowPlaying"] = mode
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-DockMagicActiveFeature", "nowPlaying", "-DockMagicAppearanceMode", appearance,
            "-DockMagicDockHoverDashboardEnabled", "NO", "-DockMagicCodexExecutablePath", "/usr/bin/false", "-DockMagicAutomaticallyConfigureClaudeCode", "false"]
        app.launch(); app.activate(); return app
    }
    private func openDashboard(_ app: XCUIApplication) {
        XCTAssertTrue(app.windows["DockMagic Settings"].waitForExistence(timeout: 5))
        let row = app.buttons["settings.nav.nowPlaying"]
        let sidebar = app.scrollViews.containing(.button, identifier: "settings.nav.nowPlaying").firstMatch
        sidebar.hover()
        // SwiftUI can report an offscreen row as hittable even when it is clipped
        // behind the appearance footer. Scroll until the entire row is visible.
        for _ in 0..<7 {
            if sidebar.frame.contains(row.frame) { break }
            sidebar.scroll(byDeltaX: 0, deltaY: -180)
        }
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(sidebar.frame.contains(row.frame), "Now Playing must be inside the visible sidebar")
        XCTAssertTrue(row.isHittable, app.debugDescription)
        row.click()
        let open = app.buttons["settings.nowPlaying.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5), app.debugDescription); open.click()
    }
    private func assertTrack(_ title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        // macOS may combine the title, artist and album into one accessibility text.
        let track = app.staticTexts["nowPlaying.trackTitle"]
        let predicate = NSPredicate(format: "exists == true AND (label CONTAINS %@ OR value CONTAINS %@)", title, title)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: track)], timeout: 5)
        XCTAssertEqual(result, .completed, app.debugDescription, file: file, line: line)
    }
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
