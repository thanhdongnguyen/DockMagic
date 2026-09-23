import XCTest
import CoreGraphics
import AppKit

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

    func testShelfModeWithoutAccessibilityReturnsToDockActiveWithRecoveryMessage() {
        let suite = "DockMagicUITests.ShelfDenied.\(UUID().uuidString)"
        let app = launchApp(
            defaultsSuite: suite,
            initialDockMode: "shelfDock",
            denyShelfAccessibility: true
        )
        let settings = app.windows["DockMagic Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["settings.dockMode.dockActive"].exists)
        let recoveryStatus = app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@",
                "Shelf Dock unavailable",
                "Shelf Dock unavailable"
            )
        ).firstMatch
        XCTAssertTrue(
            recoveryStatus.waitForExistence(timeout: 3),
            app.debugDescription
        )

        app.terminate()
        let relaunched = launchApp(defaultsSuite: suite)
        XCTAssertTrue(
            relaunched.windows["DockMagic Settings"].waitForExistence(timeout: 8)
        )
        XCTAssertTrue(
            relaunched.buttons["settings.dockMode.dockActive"].isSelected
        )
    }

    func testShelfDockShowsDuplicateTilesAddsFeatureAndControlsDashboard() {
        let suite = "DockMagicUITests.ShelfInteractions.\(UUID().uuidString)"
        let app = launchApp(
            defaultsSuite: suite,
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,systemMetrics",
            shelfEdge: "right",
            hideRuntimeDockItems: true,
            assumeShelfAccessibility: true,
            skipAppleDockLease: true,
            disableDockHandoff: true
        )
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 8)
        )

        let root = app.descendants(matching: .any)["customDock.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.descendants(matching: .any)["customDock.system.finder"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["customDock.system.apps"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["customDock.shelf"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["customDock.resize"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["customDock.trash"].exists
        )

        let slots = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "customDock.slot.")
        )
        XCTAssertEqual(slots.count, 2)
        let firstSlot = slots.element(boundBy: 0)
        let secondSlot = slots.element(boundBy: 1)
        XCTAssertEqual(firstSlot.label, "CPU & RAM")
        XCTAssertEqual(secondSlot.label, "CPU & RAM")
        XCTAssertNotEqual(firstSlot.identifier, secondSlot.identifier)

        let add = app.buttons["customDock.addFeature"]
        XCTAssertTrue(add.exists)
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertEqual(finder.state, .runningForeground)
        add.click()
        let picker = app.descendants(matching: .any)["customDock.picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(app.state, .runningForeground)
        let pickerWindow = app.windows["Add Shelf feature"]
        XCTAssertTrue(pickerWindow.waitForExistence(timeout: 2))
        XCTAssertTrue(pickerWindow.isHittable)
        let search = app.textFields["Search Shelf feature"]
        XCTAssertTrue(search.waitForExistence(timeout: 2))
        search.click()
        search.typeText("Weather")
        let weather = app.buttons["customDock.picker.weather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 2))
        weather.click()

        let threeSlots = expectation(
            for: NSPredicate(format: "count == 3"),
            evaluatedWith: slots
        )
        wait(for: [threeSlots], timeout: 4)
        XCTAssertTrue(add.exists)

        let weatherSlot = slots.element(boundBy: 2)
        XCTAssertEqual(weatherSlot.label, "Weather")
        app.activate()
        firstSlot.hover()
        weatherSlot.hover()
        let dashboard = app.descendants(matching: .any)[
            "customDock.dashboard.\(weatherSlot.identifier.replacingOccurrences(of: "customDock.slot.", with: ""))"
        ]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 3), app.debugDescription)
        let dashboardCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        dashboardCapture.name = "Shelf Weather dashboard on right-edge Custom Dock"
        dashboardCapture.lifetime = .keepAlways
        self.add(dashboardCapture)
        app.typeKey(.escape, modifierFlags: [])
        let dashboardClosed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: dashboard
        )
        wait(for: [dashboardClosed], timeout: 3)

        weatherSlot.click()
        XCTAssertTrue(dashboard.waitForExistence(timeout: 3))
        weatherSlot.click()
        let dashboardClickClosed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: dashboard
        )
        wait(for: [dashboardClickClosed], timeout: 3)

        weatherSlot.press(forDuration: 0.8, thenDragTo: firstSlot)
        let weatherMovedFirst = expectation(
            for: NSPredicate(format: "label == %@", "Weather"),
            evaluatedWith: slots.element(boundBy: 0)
        )
        wait(for: [weatherMovedFirst], timeout: 4)

        slots.element(boundBy: 1).rightClick()
        let remove = app.menuItems["Remove from Shelf"]
        XCTAssertTrue(remove.waitForExistence(timeout: 2))
        remove.click()
        let twoSlots = expectation(
            for: NSPredicate(format: "count == 2"),
            evaluatedWith: slots
        )
        wait(for: [twoSlots], timeout: 4)
        XCTAssertTrue(add.exists)

        finder.activate()
        let trash = app.buttons["customDock.trash"]
        XCTAssertTrue(trash.isHittable)
        trash.click()
        XCTAssertTrue(
            finder.windows["Trash"].waitForExistence(timeout: 5),
            finder.debugDescription
        )
    }

    func testShelfDockResizeDividerSupportsPointerDrag() {
        let app = launchApp(
            defaultsSuite: "DockMagicUITests.ShelfResize.\(UUID().uuidString)",
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,weather",
            shelfEdge: "bottom",
            shelfIconSize: "44",
            hideRuntimeDockItems: true,
            assumeShelfAccessibility: true,
            skipAppleDockLease: true,
            disableDockHandoff: true
        )
        defer { app.terminate() }
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 8),
            app.debugDescription
        )

        let root = app.descendants(matching: .any)["customDock.root"]
        var resize = app.descendants(matching: .any)["customDock.resize"]
        XCTAssertTrue(root.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(resize.waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertTrue(resize.isHittable)

        let initialHeight = root.frame.height
        let growStart = resize.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        )
        growStart.press(
            forDuration: 0.8,
            thenDragTo: growStart.withOffset(CGVector(dx: 40, dy: 0))
        )
        let grew = expectation(
            for: NSPredicate { _, _ in root.frame.height > initialHeight + 8 },
            evaluatedWith: root
        )
        wait(for: [grew], timeout: 4)

        let grownHeight = root.frame.height
        resize = app.descendants(matching: .any)["customDock.resize"]
        XCTAssertTrue(resize.isHittable)
        let shrinkStart = resize.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        )
        shrinkStart.press(
            forDuration: 0.8,
            thenDragTo: shrinkStart.withOffset(CGVector(dx: -28, dy: 0))
        )
        let shrank = expectation(
            for: NSPredicate { _, _ in root.frame.height < grownHeight - 8 },
            evaluatedWith: root
        )
        wait(for: [shrank], timeout: 4)
    }

    func testShelfDockHybridMagnificationKeepsShelfGeometryFixed() {
        let app = launchApp(
            defaultsSuite: "DockMagicUITests.ShelfMagnification.\(UUID().uuidString)",
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,weather,nowPlaying",
            shelfEdge: "bottom",
            shelfIconSize: "44",
            shelfMagnification: true,
            assumeShelfAccessibility: true,
            skipAppleDockLease: true,
            disableDockHandoff: true
        )
        defer { app.terminate() }
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 8),
            app.debugDescription
        )
        let root = app.descendants(matching: .any)["customDock.root"]
        let finder = app.descendants(matching: .any)["customDock.system.finder"]
        let shelf = app.descendants(matching: .any)["customDock.shelf"]
        let add = app.buttons["customDock.addFeature"]
        let trash = app.buttons["customDock.trash"]
        XCTAssertTrue(root.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(finder.exists)
        XCTAssertTrue(shelf.exists)
        XCTAssertTrue(add.exists)
        XCTAssertTrue(trash.exists)

        // The pointer can already be resting over a Dock item when the panel
        // appears. Move it into the Shelf hard boundary before taking baselines.
        add.hover()
        XCTAssertTrue(app.descendants(matching: .any)[
            "customDock.magnificationProbe.idle"
        ].waitForExistence(timeout: 3), app.debugDescription)
        let shelfFrame = shelf.frame
        let addFrame = add.frame
        let finderFrame = finder.frame
        let trashFrame = trash.frame
        finder.hover()
        XCTAssertTrue(app.descendants(matching: .any)[
            "customDock.magnificationProbe.system.finder"
        ].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(shelf.frame.origin.x, shelfFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(shelf.frame.origin.y, shelfFrame.origin.y, accuracy: 0.5)
        XCTAssertEqual(shelf.frame.size.width, shelfFrame.size.width, accuracy: 0.5)
        XCTAssertEqual(shelf.frame.size.height, shelfFrame.size.height, accuracy: 0.5)
        XCTAssertEqual(add.frame.origin.x, addFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(add.frame.origin.y, addFrame.origin.y, accuracy: 0.5)
        XCTAssertEqual(finder.frame.origin.x, finderFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(finder.frame.origin.y, finderFrame.origin.y, accuracy: 0.5)
        XCTAssertEqual(finder.frame.size.width, finderFrame.size.width, accuracy: 0.5)
        XCTAssertEqual(finder.frame.size.height, finderFrame.size.height, accuracy: 0.5)

        let peakCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        peakCapture.name = "Hybrid magnification peak with fixed Shelf segment"
        peakCapture.lifetime = .keepAlways
        self.add(peakCapture)

        add.hover()
        XCTAssertTrue(app.descendants(matching: .any)[
            "customDock.magnificationProbe.idle"
        ].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(shelf.frame.origin.x, shelfFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(add.frame.origin.x, addFrame.origin.x, accuracy: 0.5)

        trash.hover()
        XCTAssertTrue(app.descendants(matching: .any)[
            "customDock.magnificationProbe.trash"
        ].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(shelf.frame.origin.x, shelfFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(add.frame.origin.x, addFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(trash.frame.origin.x, trashFrame.origin.x, accuracy: 0.5)
        XCTAssertEqual(trash.frame.origin.y, trashFrame.origin.y, accuracy: 0.5)
        XCTAssertEqual(trash.frame.size.width, trashFrame.size.width, accuracy: 0.5)
        XCTAssertEqual(trash.frame.size.height, trashFrame.size.height, accuracy: 0.5)
    }

    func testShelfDockReduceMotionSuppressesMagnification() {
        let app = launchApp(
            defaultsSuite: "DockMagicUITests.ShelfReduceMotion.\(UUID().uuidString)",
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,weather",
            shelfEdge: "bottom",
            shelfIconSize: "44",
            shelfMagnification: true,
            reduceMotion: true,
            hideRuntimeDockItems: true,
            assumeShelfAccessibility: true,
            skipAppleDockLease: true,
            disableDockHandoff: true
        )
        defer { app.terminate() }
        XCTAssertTrue(
            app.windows["DockMagic Settings"].waitForExistence(timeout: 8),
            app.debugDescription
        )
        let finder = app.descendants(matching: .any)["customDock.system.finder"]
        XCTAssertTrue(finder.waitForExistence(timeout: 5), app.debugDescription)
        let baseline = finder.frame
        finder.hover()
        XCTAssertTrue(app.descendants(matching: .any)[
            "customDock.magnificationProbe.idle"
        ].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(finder.frame.origin.x, baseline.origin.x, accuracy: 0.5)
        XCTAssertEqual(finder.frame.origin.y, baseline.origin.y, accuracy: 0.5)
        XCTAssertEqual(finder.frame.size.width, baseline.size.width, accuracy: 0.5)
        XCTAssertEqual(finder.frame.size.height, baseline.size.height, accuracy: 0.5)
        XCTAssertTrue(app.staticTexts[
            "Reduce Motion is on, so Dock items stay at their normal size."
        ].waitForExistence(timeout: 3), app.debugDescription)
    }

    @available(macOS 14.0, *)
    func testShelfDockPassesAccessibilityAudit() throws {
        let app = launchApp(
            defaultsSuite: "DockMagicUITests.ShelfAccessibility.\(UUID().uuidString)",
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,weather,nowPlaying",
            shelfEdge: "bottom",
            assumeShelfAccessibility: true,
            skipAppleDockLease: true,
            disableDockHandoff: true
        )
        defer { app.terminate() }
        let settings = app.windows["DockMagic Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8), app.debugDescription)
        settings.buttons[XCUIIdentifierCloseWindow].click()
        let root = app.descendants(matching: .any)["customDock.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 5), app.debugDescription)

        var issues: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            if issue.element?.elementType == .touchBar { return true }
            issues.append(
                "\(issue.auditType.rawValue): \(issue.compactDescription) — "
                + "\(issue.detailedDescription) — "
                + "\(issue.element?.debugDescription ?? "No element")"
            )
            return true
        }
        XCTAssertTrue(
            issues.isEmpty,
            "Custom Dock accessibility audit found:\n\(issues.joined(separator: "\n"))"
        )
    }

    /// Opt-in desktop integration test. It drags one generated text file from
    /// Finder to TextEdit and then to the Custom Dock Trash. The test restores
    /// the file from Trash and removes its temporary directory before exiting.
    func testCustomDockAcceptsFinderFileDrops() throws {
        let marker = "/private/tmp/dockmagic-custom-dock-pointer-drop"
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: marker),
            "This test moves one generated file through Finder and Trash."
        )

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DockMagicPointerDropQA-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        let source = folder.appendingPathComponent(
            "DockMagic-pointer-drop-QA-\(UUID().uuidString).txt"
        )
        try Data("DockMagic pointer drop QA".utf8).write(to: source)
        let appDropResult = folder.appendingPathComponent("app-drop-result.txt")
        let dropResult = folder.appendingPathComponent("trash-destination.txt")
        var recycledURL: URL?

        let textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.terminate()
        textEdit.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        textEdit.launch()
        let newDocumentButton = textEdit.buttons["NewDocumentButton"]
        if newDocumentButton.waitForExistence(timeout: 2) {
            newDocumentButton.click()
        }
        let app = launchApp(
            defaultsSuite: "DockMagicUITests.PointerDrop.\(UUID().uuidString)",
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics",
            shelfEdge: "right",
            assumeShelfAccessibility: true,
            skipAppleDockLease: true,
            disableDockHandoff: true,
            appDropResultPath: appDropResult.path,
            trashDropResultPath: dropResult.path
        )
        defer {
            app.terminate()
            textEdit.terminate()
            if let recycledURL,
               FileManager.default.fileExists(atPath: recycledURL.path),
               !FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.moveItem(at: recycledURL, to: source)
            }
            try? FileManager.default.removeItem(at: folder)
        }

        let settings = app.windows["DockMagic Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8), app.debugDescription)
        settings.buttons[XCUIIdentifierCloseWindow].click()
        let trash = app.buttons["customDock.trash"]
        XCTAssertTrue(trash.waitForExistence(timeout: 10), app.debugDescription)
        let trashReady = expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: trash
        )
        wait(for: [trashReady], timeout: 15)

        let textEditTile = app.buttons["customDock.app.com.apple.TextEdit"]
        XCTAssertTrue(textEditTile.waitForExistence(timeout: 5), app.debugDescription)
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        XCTAssertTrue(
            NSWorkspace.shared.selectFile(
                source.path,
                inFileViewerRootedAtPath: folder.path
            )
        )
        finder.activate()
        let finderWindow = finder.windows.firstMatch
        XCTAssertTrue(finderWindow.waitForExistence(timeout: 5), finder.debugDescription)
        let safeInset: CGFloat = 80
        let moveLeftBy = max(0, finderWindow.frame.minX - safeInset)
        if moveLeftBy > 1 {
            let titleBar = finderWindow.coordinate(
                withNormalizedOffset: CGVector(dx: 0.05, dy: 0.03)
            )
            titleBar.press(
                forDuration: 0.2,
                thenDragTo: titleBar.withOffset(CGVector(dx: -moveLeftBy, dy: 0))
            )
        }
        let sourceItem = finder.images[source.lastPathComponent].firstMatch
        XCTAssertTrue(sourceItem.waitForExistence(timeout: 8), finder.debugDescription)

        sourceItem.press(forDuration: 0.8, thenDragTo: textEditTile)
        if !waitForFile(at: appDropResult, timeout: 5) {
            XCTAssertTrue(
                NSWorkspace.shared.selectFile(
                    source.path,
                    inFileViewerRootedAtPath: folder.path
                )
            )
            finder.activate()
            XCTAssertTrue(sourceItem.waitForExistence(timeout: 5), finder.debugDescription)
            sourceItem.press(forDuration: 0.8, thenDragTo: textEditTile)
        }
        XCTAssertTrue(
            waitForFile(at: appDropResult, timeout: 10),
            "Custom Dock app tile did not confirm the Finder file drop."
        )
        let appDropStatus = try String(contentsOf: appDropResult, encoding: .utf8)
        XCTAssertEqual(appDropStatus, "success\n\(source.path)")
        let openedDocument = textEdit.windows.matching(
            NSPredicate(format: "title CONTAINS[c] %@", source.deletingPathExtension().lastPathComponent)
        ).firstMatch
        _ = openedDocument.waitForExistence(timeout: 3)
        textEdit.terminate()

        XCTAssertTrue(
            NSWorkspace.shared.selectFile(
                source.path,
                inFileViewerRootedAtPath: folder.path
            )
        )
        finder.activate()
        XCTAssertTrue(sourceItem.waitForExistence(timeout: 8), finder.debugDescription)
        sourceItem.press(forDuration: 0.8, thenDragTo: trash)
        if !waitForFileToDisappear(at: source, timeout: 5) {
            XCTAssertTrue(
                NSWorkspace.shared.selectFile(
                    source.path,
                    inFileViewerRootedAtPath: folder.path
                )
            )
            finder.activate()
            XCTAssertTrue(sourceItem.waitForExistence(timeout: 5), finder.debugDescription)
            sourceItem.press(forDuration: 0.8, thenDragTo: trash)
        }
        XCTAssertTrue(
            waitForFileToDisappear(at: source, timeout: 10),
            "Custom Dock Trash did not remove the generated QA file from its source."
        )
        XCTAssertTrue(
            waitForFile(at: dropResult, timeout: 10),
            "NSWorkspace.recycle did not return the generated QA file destination."
        )
        let destinationPath = try String(contentsOf: dropResult, encoding: .utf8)
        recycledURL = URL(fileURLWithPath: destinationPath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: destinationPath),
            "NSWorkspace did not return a live Trash destination."
        )

        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Custom Dock accepted Finder file drop into Trash"
        capture.lifetime = .keepAlways
        self.add(capture)
    }

    private func waitForFile(at url: URL, timeout: TimeInterval) -> Bool {
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                FileManager.default.fileExists(atPath: url.path)
            },
            object: nil
        )
        return XCTWaiter.wait(for: [completed], timeout: timeout) == .completed
    }

    private func waitForFileToDisappear(at url: URL, timeout: TimeInterval) -> Bool {
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                !FileManager.default.fileExists(atPath: url.path)
            },
            object: nil
        )
        return XCTWaiter.wait(for: [completed], timeout: timeout) == .completed
    }

    /// Run explicitly while the system Dock is set to auto-hide. This moves the
    /// macOS pointer, so it must not run as part of the ordinary UI test suite.
    func testShelfProbeRevealsAndHidesWithSystemDock() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DockMagicShelfProbeUITest"] == "1",
            "The Shelf geometry probe is an opt-in desktop integration test."
        )
        let app = XCUIApplication()
        app.launchEnvironment["DockMagicUITesting"] = "1"
        app.launchEnvironment["DOCKMAGIC_SHELF_PROBE"] = "1"
        app.launchEnvironment["DockMagicUITestDefaultsSuite"] = automaticDefaultsSuite
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let display = CGDisplayBounds(CGMainDisplayID())
        let origin = window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let edge = origin.withOffset(CGVector(
            dx: display.midX - window.frame.minX,
            dy: display.maxY - window.frame.minY - 1
        ))
        let away = origin.withOffset(CGVector(
            dx: display.midX - window.frame.minX,
            dy: display.midY - window.frame.minY
        ))

        away.hover()
        Thread.sleep(forTimeInterval: 2)
        let logURL = URL(fileURLWithPath: "/private/tmp/dockmagic-shelf-geometry.log")
        let hiddenLog = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(hiddenLog.contains("DockList=unavailable"), hiddenLog.suffix(2000).description)

        edge.hover()
        Thread.sleep(forTimeInterval: 3)
        let revealedLog = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(revealedLog.contains("edge=bottom autohide=true"), revealedLog.suffix(2000).description)

        away.hover()
        Thread.sleep(forTimeInterval: 2)
        let finalLog = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(finalLog.suffix(2000).contains("DockList=unavailable"), finalLog.suffix(2000).description)
    }

    /// Opt-in desktop integration test. The caller sets Apple Dock auto-hide
    /// and orientation, then restores both values after this test exits.
    func testCustomDockYieldsToNativeDockAtPhysicalEdge() throws {
        let harnessURL = URL(
            fileURLWithPath: "/private/tmp/dockmagic-custom-dock-gate0.env"
        )
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: harnessURL.path),
            "Run only while the Apple Dock handoff harness owns Dock auto-hide."
        )
        let harness = try String(contentsOf: harnessURL, encoding: .utf8)
        let values = Dictionary(uniqueKeysWithValues: harness.split(separator: "\n").compactMap {
            line -> (String, String)? in
            let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
            return pair.count == 2 ? (pair[0], pair[1]) : nil
        })
        let requestedEdge = values["edge"] ?? "bottom"
        XCTAssertTrue(["bottom", "left", "right"].contains(requestedEdge))
        let suite = "DockMagicUITests.Gate0.\(requestedEdge).\(UUID().uuidString)"
        let driver = launchApp(
            defaultsSuite: suite,
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,weather",
            shelfEdge: requestedEdge,
            assumeShelfAccessibility: true,
            skipAppleDockLease: true
        )
        let settings = driver.windows["DockMagic Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8), driver.debugDescription)
        let customDock = driver.dialogs["customDock.panel"]
        XCTAssertTrue(customDock.waitForExistence(timeout: 5), driver.debugDescription)

        let targetScreen: NSScreen
        switch requestedEdge {
        case "left":
            targetScreen = try XCTUnwrap(
                NSScreen.screens.min { $0.frame.minX < $1.frame.minX }
            )
        case "right":
            targetScreen = try XCTUnwrap(
                NSScreen.screens.max { $0.frame.maxX < $1.frame.maxX }
            )
        default:
            targetScreen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        }
        let displayID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let display = CGDisplayBounds(displayID)
        let edgePoint: CGPoint
        switch requestedEdge {
        case "left":
            edgePoint = CGPoint(x: display.minX + 1, y: display.midY)
        case "right":
            edgePoint = CGPoint(x: display.maxX - 1, y: display.midY)
        default:
            edgePoint = CGPoint(x: display.midX, y: display.maxY - 1)
        }
        let origin = settings.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let away = origin.withOffset(CGVector(
            dx: display.midX - settings.frame.minX,
            dy: display.midY - settings.frame.minY
        ))
        let edge = origin.withOffset(CGVector(
            dx: edgePoint.x - settings.frame.minX,
            dy: edgePoint.y - settings.frame.minY
        ))
        defer { away.hover() }

        let cycles = min(max(Int(values["cycles"] ?? "1") ?? 1, 1), 100)
        for cycle in 1...cycles {
            away.hover()
            XCTAssertTrue(
                customDock.waitForExistence(timeout: 3),
                "Cycle \(cycle): Custom Dock did not return after Apple Dock hid."
            )
            edge.hover()
            let pointer = NSEvent.mouseLocation
            let edgeDistance: CGFloat = requestedEdge == "left"
                ? abs(pointer.x - targetScreen.frame.minX)
                : requestedEdge == "right"
                    ? abs(pointer.x - targetScreen.frame.maxX)
                    : abs(pointer.y - targetScreen.frame.minY)
            XCTAssertLessThanOrEqual(
                edgeDistance, 5,
                "Cycle \(cycle): XCUITest did not move the physical pointer to the \(requestedEdge) Dock edge: \(pointer)"
            )
            let hidden = expectation(
                for: NSPredicate(format: "exists == false"),
                evaluatedWith: customDock
            )
            wait(for: [hidden], timeout: 2)
        }

        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Custom Dock handoff at native Dock \(requestedEdge) edge"
        capture.lifetime = .keepAlways
        add(capture)
    }

    /// Opt-in desktop integration test. The shell harness owns and restores
    /// Apple Dock preferences even when this test fails or Xcode is stopped.
    func testNativeAndCustomDockGeometryVisualMatrix() throws {
        let markerURL = URL(
            fileURLWithPath: "/private/tmp/dockmagic-custom-dock-geometry.env"
        )
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: markerURL.path),
            "Run through script/run_custom_dock_geometry_qa.sh."
        )
        let marker = try String(contentsOf: markerURL, encoding: .utf8)
        let values = Dictionary(uniqueKeysWithValues: marker
            .split(separator: "\n")
            .compactMap { line -> (String, String)? in
                let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
                return pair.count == 2 ? (pair[0], pair[1]) : nil
            })
        let edge = try XCTUnwrap(values["edge"])
        let size = try XCTUnwrap(Int(values["size"] ?? ""))
        XCTAssertTrue(["bottom", "left", "right"].contains(edge))
        XCTAssertTrue([30, 44, 60].contains(size))

        let nativeDock = XCUIApplication(bundleIdentifier: "com.apple.dock")
        let nativeList = nativeDock.children(matching: .other).firstMatch
        XCTAssertTrue(
            nativeList.waitForExistence(timeout: 5),
            nativeDock.debugDescription
        )
        let nativeFrame = nativeList.frame
        let nativeThickness = edge == "bottom"
            ? nativeFrame.height : nativeFrame.width
        let nativeCapture = XCTAttachment(
            screenshot: XCUIScreen.main.screenshot()
        )
        nativeCapture.name = "Native Dock — \(edge) — \(size) pt"
        nativeCapture.lifetime = .keepAlways
        self.add(nativeCapture)
        let nativeElementCapture = XCTAttachment(screenshot: nativeList.screenshot())
        nativeElementCapture.name = "Native Dock element — \(edge) — \(size) pt"
        nativeElementCapture.lifetime = .keepAlways
        self.add(nativeElementCapture)

        let app = launchApp(
            defaultsSuite: "DockMagicUITests.Geometry.\(edge).\(size).\(UUID().uuidString)",
            initialDockMode: "shelfDock",
            shelfFeatures: "systemMetrics,weather,nowPlaying",
            shelfEdge: edge,
            shelfIconSize: "\(size)",
            preserveNativeDockApps: true,
            assumeShelfAccessibility: true,
            disableDockHandoff: true
        )
        let settings = app.windows["DockMagic Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ).hover()
        Thread.sleep(forTimeInterval: 1)
        let customPanel = app.dialogs["customDock.panel"]
        XCTAssertTrue(customPanel.waitForExistence(timeout: 5))
        let customFrame = customPanel.frame
        let customThickness = edge == "bottom"
            ? customFrame.height : customFrame.width
        let delta = abs(customThickness - nativeThickness)
        let customCapture = XCTAttachment(
            screenshot: XCUIScreen.main.screenshot()
        )
        customCapture.name = "DockMagic Custom Dock — \(edge) — \(size) pt"
        customCapture.lifetime = .keepAlways
        self.add(customCapture)
        let customElementCapture = XCTAttachment(screenshot: customPanel.screenshot())
        customElementCapture.name = "DockMagic Custom Dock element — \(edge) — \(size) pt"
        customElementCapture.lifetime = .keepAlways
        self.add(customElementCapture)
        let measurement: [String: Any] = [
            "edge": edge,
            "iconSize": size,
            "native": rectDictionary(nativeFrame),
            "custom": rectDictionary(customFrame),
            "thicknessDelta": delta
        ]
        app.terminate()
        let data = try JSONSerialization.data(
            withJSONObject: measurement,
            options: [.prettyPrinted, .sortedKeys]
        )
        let geometryAttachment = XCTAttachment(
            data: data,
            uniformTypeIdentifier: "public.json"
        )
        geometryAttachment.name = "DockMagic native-custom geometry measurements"
        geometryAttachment.lifetime = .keepAlways
        self.add(geometryAttachment)
        XCTAssertLessThanOrEqual(
            delta,
            2,
            "\(edge), \(size) pt: Custom \(customThickness), native \(nativeThickness), delta \(delta)"
        )
    }

    func testLegacyCompanionShelfIsUnavailable() {
        let suiteName = "DockMagicUITests.LegacyShelf.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let oldConfiguration = Data(#"{"isEnabled":true,"orderedFeatures":["weather"],"positionFraction":0,"hidesSensitiveValues":false}"#.utf8)
        defaults.set(oldConfiguration, forKey: "DockMagicShelfConfiguration")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let app = launchApp(defaultsSuite: suiteName)
        let scroll = app.scrollViews["settings.general"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        scroll.scroll(byDeltaX: 0, deltaY: -650)
        XCTAssertFalse(app.checkBoxes["settings.shelf.toggle"].exists)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(app.descendants(matching: .any)["dockmagic.shelf"].exists)
        XCTAssertEqual(defaults.data(forKey: "DockMagicShelfConfiguration"), oldConfiguration)
    }

    func testLaunchPresentsMaiaSettingsWithRequestedSidebar() {
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
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.appearanceBadge"].exists
        )
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
            named: "Settings — General — System Maia Chrome",
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

        var stylePicker = app.descendants(matching: .any)["settings.clock.style"].firstMatch
        XCTAssertTrue(stylePicker.waitForExistence(timeout: 3))
        XCTAssertEqual(stylePicker.value as? String, "Digital")
        guard let splitFlap = waitForHittableSelectionButton(
            identifiedBy: "settings.clock.styleOption.splitFlap",
            in: app,
            timeout: 3
        ) else {
            return XCTFail("Missing Split-flap Clock style in General.")
        }
        splitFlap.click()
        stylePicker = app.descendants(matching: .any)["settings.clock.style"].firstMatch
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
        stylePicker = app.descendants(matching: .any)["settings.clock.style"].firstMatch
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
            named: "Settings — Network — System Maia Chrome",
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
            named: "Settings — Weather — System Maia Chrome",
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
        XCTAssertFalse(
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
        XCTAssertTrue(
            featurePicker.label.contains("Active Dock feature"),
            "The picker must keep its accessible purpose after adopting the shared feature identity."
        )
        XCTAssertGreaterThanOrEqual(featurePicker.frame.width, 280)
        XCTAssertTrue(
            featurePicker.isHittable,
            "The active Dock feature picker must receive pointer clicks."
        )
        app.terminate()

        for title in [
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
            "OpenCode",
            "Antigravity",
            "Search Console",
            "CPU & RAM"
        ] {
            let app = launchApp(openActiveFeaturePicker: true)
            XCTAssertTrue(
                app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
            )
            selectFeature(
                title,
                in: app,
                pickerInitiallyPresented: true
            )
            app.terminate()
        }
    }

    func testActiveDockFeaturePickerShowsSharedFeatureIdentities() {
        for appearance in ["dark", "light"] {
            let app = launchApp(
                appearance: appearance,
                activeFeature: "codex",
                openActiveFeaturePicker: true
            )
            XCTAssertTrue(
                app.windows["DockMagic Settings"].waitForExistence(timeout: 5)
            )

            let search = app.textFields["Search Active Dock feature"]
            XCTAssertTrue(
                search.waitForExistence(timeout: 3),
                app.debugDescription
            )
            for rawValue in [
                "dockMagic",
                "systemMetrics",
                "network",
                "storage",
                "weather",
                "clock",
                "calendar",
                "nowPlaying",
                "batteries",
                "github",
                "codex",
                "claudeCode",
                "antigravity",
                "openCode",
                "binance",
                "searchConsole"
            ] {
                XCTAssertTrue(
                    app.descendants(matching: .any)[
                        "settings.activeFeatureOption.\(rawValue)"
                    ].exists,
                    "Missing \(appearance) Active Dock option for \(rawValue)."
                )
            }

            attachScreenshot(
                named: "Settings — Active Dock Feature — Shared Identities — \(appearance.capitalized)",
                in: app
            )
            app.terminate()
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

        let moreActions = app.descendants(matching: .any)["settings.claudeCode.moreActions"]
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

    func testClaudeSignOutReturnsToNamedConnectionRow() {
        for appearance in ["light", "dark"] {
            let app = launchApp(appearance: appearance, activeFeature: "claudeCode", claudeConnected: true)
            openSidebarDestination(named: "Claude Code", in: app)
            let more = app.descendants(matching: .any)["settings.claudeCode.moreActions"]
            XCTAssertTrue(more.waitForExistence(timeout: 5))
            more.click()
            let signOut = app.descendants(matching: .any)["settings.claudeCode.signOut"]
            XCTAssertTrue(signOut.waitForExistence(timeout: 3))
            signOut.click()
            XCTAssertTrue(app.buttons["settings.claudeCode.signIn"].waitForExistence(timeout: 6))
            XCTAssertTrue(app.staticTexts["Claude Code connection"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["settings.claudeCode.loginTerminal"].exists)
            attachScreenshot(named: "Claude signed out — \(appearance)", in: app)
            app.terminate()
        }
    }

    func testClaudeCancelThenSignInStartsANewProcess() throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("claude-login-starts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let executable = try makeClaudeLoginFixtureExecutable(launchCounterURL: marker)
        let app = launchApp(activeFeature: "claudeCode", claudeExecutablePath: executable.path)
        openSidebarDestination(named: "Claude Code", in: app)
        for expectedCount in 1...2 {
            let signIn = app.buttons["settings.claudeCode.signIn"]
            XCTAssertTrue(signIn.waitForExistence(timeout: 5))
            signIn.click()
            let started = expectation(for: NSPredicate { _, _ in
                let text = (try? String(contentsOf: marker)) ?? ""
                return text.split(separator: "\n").count == expectedCount
            }, evaluatedWith: nil)
            wait(for: [started], timeout: 5)
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path), app.debugDescription)
            let cancel = app.buttons["settings.claudeCode.cancelSignIn"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 3))
            cancel.click()
        }
        XCTAssertTrue(app.buttons["settings.claudeCode.signIn"].waitForExistence(timeout: 5))
    }

    func testAntigravityCancelThenSignInStartsANewProcess() throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("agy-login-starts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }
        let executable = try makeAntigravityLoginFixtureExecutable(launchCounterURL: marker)
        let app = launchApp(activeFeature: "antigravity", antigravitySignedOut: true, antigravityExecutablePath: executable.path)
        openSidebarDestination(named: "Antigravity", in: app)
        for expectedCount in 1...2 {
            let signIn = app.buttons["settings.antigravity.signIn"]
            XCTAssertTrue(signIn.waitForExistence(timeout: 5))
            signIn.click()
            let started = expectation(for: NSPredicate { _, _ in
                let text = (try? String(contentsOf: marker)) ?? ""
                return text.split(separator: "\n").count == expectedCount
            }, evaluatedWith: nil)
            wait(for: [started], timeout: 5)
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path), app.debugDescription)
            let cancel = app.buttons["settings.antigravity.cancelAuth"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 3))
            cancel.click()
        }
        XCTAssertTrue(app.buttons["settings.antigravity.signIn"].waitForExistence(timeout: 5))
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

        let moreActions = app.descendants(matching: .any)["settings.claudeCode.moreActions"]
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

        let moreActions = app.descendants(matching: .any)["settings.antigravity.moreActions"]
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
        let systemAppearanceSelected = expectation(
            for: NSPredicate(format: "value == %@", "System"),
            evaluatedWith: appearancePicker(in: app)
        )
        wait(for: [systemAppearanceSelected], timeout: 3)
        XCTAssertEqual(appearancePicker(in: app).value as? String, "System")

        let darkOption = appearanceOption("dark", in: app)
        XCTAssertTrue(darkOption.waitForExistence(timeout: 3))
        darkOption.click()

        let darkAppearanceSelected = expectation(
            for: NSPredicate(format: "value == %@", "Dark"),
            evaluatedWith: appearancePicker(in: app)
        )
        wait(for: [darkAppearanceSelected], timeout: 3)
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
        let persistedDarkAppearance = expectation(
            for: NSPredicate(format: "value == %@", "Dark"),
            evaluatedWith: appearancePicker(in: relaunched)
        )
        wait(for: [persistedDarkAppearance], timeout: 3)
        XCTAssertEqual(
            appearancePicker(in: relaunched).value as? String,
            "Dark"
        )

        let restoredLightOption = appearanceOption("light", in: relaunched)
        XCTAssertTrue(restoredLightOption.waitForExistence(timeout: 3))
        restoredLightOption.click()
        let lightAppearanceSelected = expectation(
            for: NSPredicate(format: "value == %@", "Light"),
            evaluatedWith: appearancePicker(in: relaunched)
        )
        wait(for: [lightAppearanceSelected], timeout: 3)
        XCTAssertEqual(appearancePicker(in: relaunched).value as? String, "Light")
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
        antigravityExecutablePath: String? = nil,
        openActiveFeaturePicker: Bool = false,
        nowPlayingMode: String? = nil,
        initialDockMode: String? = nil,
        shelfFeatures: String? = nil,
        shelfEdge: String? = nil,
        shelfIconSize: String? = nil,
        shelfMagnification: Bool? = nil,
        reduceMotion: Bool = false,
        preserveNativeDockApps: Bool = false,
        hideRuntimeDockItems: Bool = false,
        assumeShelfAccessibility: Bool = false,
        skipAppleDockLease: Bool = false,
        disableDockHandoff: Bool = false,
        appDropResultPath: String? = nil,
        trashDropResultPath: String? = nil,
        denyShelfAccessibility: Bool = false
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
        if denyShelfAccessibility {
            app.launchEnvironment["DockMagicUITestDenyShelfAccessibility"] = "1"
        }
        if let initialDockMode {
            app.launchEnvironment["DockMagicUITestInitialDockMode"] = initialDockMode
        }
        if let shelfFeatures {
            app.launchEnvironment["DockMagicUITestShelfFeatures"] = shelfFeatures
        }
        if let shelfEdge {
            app.launchEnvironment["DockMagicUITestShelfEdge"] = shelfEdge
        }
        if let shelfIconSize {
            app.launchEnvironment["DockMagicUITestShelfIconSize"] = shelfIconSize
        }
        if let shelfMagnification {
            app.launchEnvironment["DockMagicUITestShelfMagnification"] =
                shelfMagnification ? "1" : "0"
        }
        if reduceMotion {
            app.launchEnvironment["DockMagicUITestReduceMotion"] = "1"
        }
        if preserveNativeDockApps {
            app.launchEnvironment["DockMagicUITestPreserveNativeDockApps"] = "1"
        }
        if hideRuntimeDockItems {
            app.launchEnvironment["DockMagicUITestHideRuntimeDockItems"] = "1"
        }
        if assumeShelfAccessibility {
            app.launchEnvironment["DockMagicUITestAssumeShelfAccessibility"] = "1"
        }
        if skipAppleDockLease {
            app.launchEnvironment["DockMagicUITestSkipAppleDockLease"] = "1"
        }
        if disableDockHandoff {
            app.launchEnvironment["DockMagicUITestDisableDockHandoff"] = "1"
        }
        if let appDropResultPath {
            app.launchEnvironment["DockMagicUITestAppDropResult"] = appDropResultPath
        }
        if let trashDropResultPath {
            app.launchEnvironment["DockMagicUITestTrashDropResult"] = trashDropResultPath
        }
        if let nowPlayingMode {
            app.launchEnvironment["DockMagicUITestNowPlaying"] = nowPlayingMode
        }
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
        if openActiveFeaturePicker {
            app.launchEnvironment[
                "DockMagicUITestOpenActiveFeaturePicker"
            ] = "1"
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

    private func rectDictionary(_ rect: CGRect) -> [String: CGFloat] {
        [
            "x": rect.origin.x,
            "y": rect.origin.y,
            "width": rect.width,
            "height": rect.height
        ]
    }

    private func makeClaudeLoginFixtureExecutable(launchCounterURL: URL? = nil) throws -> URL {
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
        let counterCommand = launchCounterURL.map {
            "printf 'started\\n' >> '" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        } ?? ""
        let script = """
        #!/bin/zsh
        \(counterCommand)
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

    private func makeAntigravityLoginFixtureExecutable(launchCounterURL: URL? = nil) throws -> URL {
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
        let counterCommand = launchCounterURL.map {
            "printf 'started\\n' >> '" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        } ?? ""
        let script = """
        #!/bin/zsh
        \(counterCommand)
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
        app.descendants(matching: .any)["settings.appearancePicker"].firstMatch
    }

    private func appearanceOption(
        _ rawValue: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.buttons[
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

        let picker = app.descendants(matching: .any)["settings.displayStyle"].firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            "Missing Dock display configuration for \(feature)."
        )

        let optionIdentifier = "settings.displayStyleOption.\(style.rawValue)"
        let option = waitForHittableSelectionButton(
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

    private func waitForHittableSelectionButton(
        identifiedBy identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let matches = app.buttons.matching(
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
        normalizedX: CGFloat = 0.5,
        pickerInitiallyPresented: Bool = false
    ) {
        // SwiftUI rebuilds the General detail after the active feature changes.
        // Re-query the control so XCUI does not retain a stale element handle.
        let featurePicker = hittableActiveFeaturePicker(in: app)
        XCTAssertTrue(featurePicker.waitForExistence(timeout: 3))
        if !pickerInitiallyPresented {
            featurePicker.coordinate(
                withNormalizedOffset: CGVector(dx: normalizedX, dy: 0.5)
            ).click()
        }
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
            "OpenCode": "openCode",
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
        if !option.isHittable {
            let search = app.textFields["Search Active Dock feature"]
            XCTAssertTrue(search.waitForExistence(timeout: 3), app.debugDescription)
            search.click()
            search.typeText(title)
        }
        XCTAssertTrue(option.waitForExistence(timeout: 3), app.debugDescription)
        option.click()

        if title == "Weather" || title == "Batteries" || title == "GitHub"
            || title == "Codex" || title == "Claude Code"
            || title == "OpenCode" || title == "Antigravity"
            || title == "Search Console" {
            let destination = switch title {
            case "Weather": "weather"
            case "Batteries": "batteries"
            case "Codex": "codex"
            case "Claude Code": "claudeCode"
            case "OpenCode": "openCode"
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
        var pickerElement = app.descendants(matching: .any)[
            "settings.searchConsole.\(picker)"
        ].firstMatch
        XCTAssertTrue(
            pickerElement.waitForExistence(timeout: 3),
            "Missing Search Console picker: \(picker)"
        )

        let button = app.buttons["settings.searchConsole.\(picker).\(option)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3), app.debugDescription)
        button.click()

        pickerElement = app.descendants(matching: .any)[
            "settings.searchConsole.\(picker)"
        ].firstMatch
        let updated = app.descendants(matching: .any)[
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
