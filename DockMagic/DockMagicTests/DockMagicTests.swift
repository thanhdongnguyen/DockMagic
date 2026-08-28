import AppKit
import CoreImage
import SwiftUI
import XCTest
@testable import DockMagic

final class DockMagicTests: XCTestCase {
    func testRendererColorPaletteContainsEveryFeatureDefault() {
        let options = ProjectTheme.rendererColorOptions
        let paletteHexes = Set(options.map(\.hex))
        let defaultHexes = [
            DockFeatureDefaults.systemMetricsAppearance.outerColor.hex,
            DockFeatureDefaults.systemMetricsAppearance.innerColor.hex,
            DockFeatureDefaults.networkAppearance.downloadColor.hex,
            DockFeatureDefaults.networkAppearance.uploadColor.hex,
            DockFeatureDefaults.storageAppearance.color.hex,
            DockFeatureDefaults.githubAppearance.starColor.hex,
            DockFeatureDefaults.githubAppearance.forkColor.hex,
            DockFeatureDefaults.codexAppearance.outerColor.hex,
            DockFeatureDefaults.codexAppearance.innerColor.hex,
            DockFeatureDefaults.claudeCodeAppearance.outerColor.hex,
            DockFeatureDefaults.claudeCodeAppearance.innerColor.hex
        ]

        XCTAssertEqual(Set(options.map(\.id)).count, options.count)
        XCTAssertEqual(paletteHexes.count, options.count)
        XCTAssertTrue(
            Set(defaultHexes).isSubset(of: paletteHexes),
            "Every feature default must have a selected inline swatch."
        )
    }

    @MainActor
    func testAppDelegateRedrawsDockForAppearanceAndAccessibilityChanges() async throws {
        let suiteName = "DockMagicTests.AppDelegateAppearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(
            DSAppearanceMode.light.rawValue,
            forKey: DSAppearanceMode.storageKey
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let dockTile = SpyDockTile()
        let notificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let appModel = makeAppModel()
        appModel.preferences.activeFeature = .dockMagic
        let delegate = AppDelegate(
            appModel: appModel,
            settingsWindowRouter: SettingsWindowRouter(),
            dockTile: dockTile,
            application: SpyApplicationIconDisplay(),
            appearanceStore: defaults,
            notificationCenter: notificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        defaults.set(
            DSAppearanceMode.dark.rawValue,
            forKey: DSAppearanceMode.storageKey
        )
        let beforePreferenceChange = dockTile.displayCallCount
        notificationCenter.post(
            name: DSAppearanceMode.didChangeNotification,
            object: DSAppearanceMode.dark
        )
        try await waitUntil {
            dockTile.displayCallCount > beforePreferenceChange
        }
        XCTAssertGreaterThan(
            dockTile.displayCallCount,
            beforePreferenceChange
        )

        let beforeAccessibilityChange = dockTile.displayCallCount
        workspaceNotificationCenter.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        try await waitUntil {
            dockTile.displayCallCount > beforeAccessibilityChange
        }
        XCTAssertGreaterThan(
            dockTile.displayCallCount,
            beforeAccessibilityChange
        )

        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let currentMatch = NSApplication.shared.effectiveAppearance.bestMatch(
            from: [.aqua, .darkAqua]
        )
        NSApplication.shared.appearance = NSAppearance(
            named: currentMatch == .darkAqua ? .aqua : .darkAqua
        )
        try await waitUntil {
            dockTile.displayCallCount > beforeAccessibilityChange + 1
        }
        XCTAssertGreaterThan(
            dockTile.displayCallCount,
            beforeAccessibilityChange + 1,
            "Changing the app's effective appearance should redraw the Dock."
        )

        delegate.applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification)
        )
        let afterTermination = dockTile.displayCallCount
        notificationCenter.post(
            name: DSAppearanceMode.didChangeNotification,
            object: DSAppearanceMode.light
        )
        workspaceNotificationCenter.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        XCTAssertEqual(dockTile.displayCallCount, afterTermination)
    }

    @MainActor
    func testAppDelegateRefreshesActiveWeatherAfterSystemResume() async throws {
        let suiteName = "DockMagicTests.WeatherWake.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = sampleWeatherSnapshot(
            observedAt: Date(timeIntervalSince1970: 1_000),
            fetchedAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = sampleWeatherSnapshot(
            condition: .rain,
            conditionDescription: "Rain",
            observedAt: Date(timeIntervalSince1970: 2_000),
            fetchedAt: Date(timeIntervalSince1970: 2_000)
        )
        let third = sampleWeatherSnapshot(
            condition: .clear,
            conditionDescription: "Clear",
            observedAt: Date(timeIntervalSince1970: 3_000),
            fetchedAt: Date(timeIntervalSince1970: 3_000)
        )
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .weather
        let weather = WeatherStore(
            provider: ScriptedWeatherProvider([
                .success(first),
                .success(second),
                .success(third)
            ]),
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60),
            staleAfter: 10_000,
            now: { Date(timeIntervalSince1970: 3_000) }
        )
        let appModel = DockAppModel(
            preferences: preferences,
            weatherStore: weather
        )
        let workspaceNotificationCenter = NotificationCenter()
        let delegate = AppDelegate(
            appModel: appModel,
            settingsWindowRouter: SettingsWindowRouter(),
            dockTile: SpyDockTile(),
            application: SpyApplicationIconDisplay(),
            appearanceStore: defaults,
            notificationCenter: NotificationCenter(),
            workspaceNotificationCenter: workspaceNotificationCenter
        )

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        try await waitUntil { weather.state == .live(first) }

        workspaceNotificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        try await waitUntil { weather.state == .live(second) }

        workspaceNotificationCenter.post(
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        try await waitUntil { weather.state == .live(third) }

        delegate.applicationWillTerminate(
            Notification(name: NSApplication.willTerminateNotification)
        )
    }

    @MainActor
    func testDockReopenRoutesToSingletonSettingsWindow() {
        var didActivate = false
        var didOpen = false
        let router = SettingsWindowRouter(
            showExistingWindow: { false },
            activateApplication: { didActivate = true }
        )
        router.install { didOpen = true }

        let delegate = AppDelegate(
            appModel: makeAppModel(),
            settingsWindowRouter: router
        )

        XCTAssertFalse(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: false
            )
        )
        XCTAssertTrue(didActivate)
        XCTAssertTrue(didOpen)
    }

    @MainActor
    func testDockMenuNestsEveryFeatureAndSwitchesThePersistedSelection() throws {
        let suiteName = "DockMagicTests.DockFeatureMenu.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .network
        let appModel = DockAppModel(preferences: preferences)
        let delegate = AppDelegate(
            appModel: appModel,
            settingsWindowRouter: SettingsWindowRouter()
        )

        let dockMenu = try XCTUnwrap(
            delegate.applicationDockMenu(NSApplication.shared)
        )
        XCTAssertEqual(dockMenu.items.map(\.title), ["Switch Feature"])

        let switchFeatureItem = try XCTUnwrap(dockMenu.items.first)
        XCTAssertEqual(
            switchFeatureItem.identifier?.rawValue,
            "dockMenu.switchFeature"
        )
        let featureSubmenu = try XCTUnwrap(switchFeatureItem.submenu)
        XCTAssertEqual(
            featureSubmenu.items.map(\.title),
            DockFeature.allCases.map(\.title)
        )
        XCTAssertEqual(
            featureSubmenu.items.filter { $0.state == .on }.map(\.title),
            [DockFeature.network.title]
        )

        let codexItem = try XCTUnwrap(
            featureSubmenu.items.first {
                $0.identifier?.rawValue == "dockMenu.feature.codex"
            }
        )
        let action = try XCTUnwrap(codexItem.action)
        XCTAssertTrue(
            NSApplication.shared.sendAction(
                action,
                to: codexItem.target,
                from: nil
            )
        )
        XCTAssertEqual(preferences.activeFeature, .codex)
        XCTAssertEqual(
            defaults.string(forKey: DockFeature.storageKey),
            DockFeature.codex.rawValue
        )

        let updatedMenu = try XCTUnwrap(
            delegate.applicationDockMenu(NSApplication.shared)
        )
        let updatedSubmenu = try XCTUnwrap(updatedMenu.items.first?.submenu)
        XCTAssertEqual(
            updatedSubmenu.items.filter { $0.state == .on }.map(\.title),
            [DockFeature.codex.title]
        )
    }

    @MainActor
    func testSettingsRouterBringsExistingWindowForwardWithoutOpeningAnother() {
        var didBringForward = false
        var didOpen = false
        let router = SettingsWindowRouter(
            showExistingWindow: {
                didBringForward = true
                return true
            },
            activateApplication: {}
        )
        router.install { didOpen = true }

        XCTAssertTrue(router.showSettings())
        XCTAssertFalse(didOpen)
        XCTAssertTrue(didBringForward)
    }

    func testDockFeatureContractStartsWithDockMagicThenCPUAndRAM() {
        XCTAssertEqual(
            DockFeature.allCases,
            [
                .dockMagic,
                .systemMetrics,
                .network,
                .storage,
                .weather,
                .clock,
                .batteries,
                .github,
                .codex,
                .claudeCode,
                .searchConsole
            ]
        )
        XCTAssertEqual(DockFeature.dockMagic.title, "DockMagic")
        XCTAssertEqual(DockFeature.systemMetrics.title, "CPU & RAM")
        XCTAssertEqual(DockFeature.network.title, "Network")
        XCTAssertEqual(DockFeature.storage.title, "Storage")
        XCTAssertEqual(DockFeature.weather.title, "Weather")
        XCTAssertEqual(DockFeature.clock.title, "Clock")
        XCTAssertEqual(DockFeature.github.title, "GitHub")
        XCTAssertEqual(DockFeature.codex.title, "Codex")
        XCTAssertEqual(DockFeature.claudeCode.title, "Claude Code")
        XCTAssertEqual(DockFeature.searchConsole.title, "Search Console")
    }

    func testOnlyImplementedFeaturesExposeHoverDashboards() {
        XCTAssertEqual(
            DockFeature.allCases.filter(\.hasHoverDashboard),
            [.systemMetrics, .weather, .codex, .claudeCode]
        )
    }

    @MainActor
    func testPreferencesDefaultToCPUAndPersistAllFeatureConfiguration() {
        let suiteName = "DockMagicTests.Preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.activeFeature, .systemMetrics)
        XCTAssertTrue(store.automaticallyConfigureClaudeCode)
        XCTAssertFalse(store.isDockHoverDashboardEnabled)
        XCTAssertEqual(
            store.systemMetricsAppearance,
            DockFeatureDefaults.systemMetricsAppearance
        )
        XCTAssertEqual(
            store.networkAppearance,
            DockFeatureDefaults.networkAppearance
        )
        XCTAssertEqual(
            store.storageAppearance,
            DockFeatureDefaults.storageAppearance
        )
        XCTAssertEqual(
            store.githubAppearance,
            DockFeatureDefaults.githubAppearance
        )
        XCTAssertEqual(
            store.clockConfiguration,
            DockFeatureDefaults.clockConfiguration
        )
        XCTAssertTrue(store.clockConfiguration.followsSystemTimeZone)
        XCTAssertEqual(store.clockConfiguration.displayStyle, .digital)
        XCTAssertEqual(store.githubRepositoryURL, "")

        store.activeFeature = .network
        store.setSystemMetricsOuterColor(
            DockColor(red: 0.1, green: 0.2, blue: 0.3)
        )
        store.setSystemMetricsOuterWidth(0.14)
        store.setSystemMetricsDisplayStyle(.numeric)
        store.setNetworkDownloadColor(
            DockColor(red: 0.4, green: 0.5, blue: 0.6)
        )
        store.setNetworkUploadColor(
            DockColor(red: 0.7, green: 0.2, blue: 0.1)
        )
        store.setStorageColor(
            DockColor(red: 0.3, green: 0.4, blue: 0.5)
        )
        store.setStorageWidth(0.21)
        store.setStorageDisplayStyle(.numeric)
        store.setClockDisplayStyle(.splitFlap)
        store.setClockFollowsSystemTimeZone(false)
        store.setClockTimeZoneIdentifier("America/New_York")
        store.githubRepositoryURL = "https://github.com/apple/swift"
        store.setGitHubStarColor(
            DockColor(red: 0.9, green: 0.6, blue: 0.2)
        )
        store.setGitHubForkColor(
            DockColor(red: 0.1, green: 0.7, blue: 0.9)
        )
        store.setGitHubDisplayStyle(.numeric)
        store.setCodexInnerWidth(0.20)
        store.setCodexDisplayStyle(.numeric)
        store.setClaudeCodeOuterColor(
            DockColor(red: 0.2, green: 0.3, blue: 0.4)
        )
        store.setClaudeCodeDisplayStyle(.numeric)
        store.codexExecutablePath = " /opt/homebrew/bin/codex "
        store.automaticallyConfigureClaudeCode = false
        store.isDockHoverDashboardEnabled = true

        let restored = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.activeFeature, .network)
        XCTAssertEqual(restored.systemMetricsAppearance.outerColor.hex, "#1A334D")
        XCTAssertEqual(restored.systemMetricsAppearance.outerWidth, 0.14)
        XCTAssertEqual(restored.systemMetricsAppearance.displayStyle, .numeric)
        XCTAssertEqual(restored.networkAppearance.downloadColor.hex, "#668099")
        XCTAssertEqual(restored.networkAppearance.uploadColor.hex, "#B3331A")
        XCTAssertEqual(restored.storageAppearance.color.hex, "#4D6680")
        XCTAssertEqual(restored.storageAppearance.width, 0.21)
        XCTAssertEqual(restored.storageAppearance.displayStyle, .numeric)
        XCTAssertEqual(restored.clockConfiguration.displayStyle, .splitFlap)
        XCTAssertFalse(restored.clockConfiguration.followsSystemTimeZone)
        XCTAssertEqual(
            restored.clockConfiguration.timeZoneIdentifier,
            "America/New_York"
        )
        XCTAssertEqual(
            restored.githubRepositoryURL,
            "https://github.com/apple/swift"
        )
        XCTAssertEqual(restored.githubAppearance.starColor.hex, "#E69933")
        XCTAssertEqual(restored.githubAppearance.forkColor.hex, "#1AB3E6")
        XCTAssertEqual(restored.githubAppearance.displayStyle, .numeric)
        XCTAssertEqual(restored.codexAppearance.innerWidth, 0.20)
        XCTAssertEqual(restored.codexAppearance.displayStyle, .numeric)
        XCTAssertEqual(restored.claudeCodeAppearance.outerColor.hex, "#334D66")
        XCTAssertEqual(restored.claudeCodeAppearance.displayStyle, .numeric)
        XCTAssertEqual(restored.codexExecutablePath, "/opt/homebrew/bin/codex")
        XCTAssertFalse(restored.automaticallyConfigureClaudeCode)
        XCTAssertTrue(restored.isDockHoverDashboardEnabled)
    }

    func testClockConfigurationNormalizesTimeZonesAndUpdatePrecision() throws {
        let source = Date(timeIntervalSince1970: 12_345.875)
        var configuration = DockClockConfiguration(
            displayStyle: .digital,
            followsSystemTimeZone: false,
            timeZoneIdentifier: "Asia/Kathmandu"
        )

        XCTAssertEqual(configuration.resolvedTimeZone.identifier, "Asia/Kathmandu")
        XCTAssertEqual(
            configuration.presentationDate(for: source),
            Date(timeIntervalSince1970: 12_300)
        )
        XCTAssertEqual(
            DockClockFormatting.locationTitle(for: "America/Los_Angeles"),
            "Los Angeles"
        )
        XCTAssertEqual(
            DockClockFormatting.regionTitle(for: "America/Los_Angeles"),
            "America"
        )
        XCTAssertEqual(
            DockClockFormatting.offsetTitle(
                for: try XCTUnwrap(TimeZone(secondsFromGMT: 5 * 3_600 + 45 * 60)),
                at: source
            ),
            "UTC+05:45"
        )

        configuration.setDisplayStyle(.analog)
        XCTAssertEqual(
            configuration.presentationDate(for: source),
            Date(timeIntervalSince1970: 12_345)
        )

        configuration.setTimeZoneIdentifier("not/a-real-time-zone")
        XCTAssertEqual(
            configuration.timeZoneIdentifier,
            TimeZone.autoupdatingCurrent.identifier
        )
        configuration.setFollowsSystemTimeZone(true)
        XCTAssertEqual(
            configuration.resolvedTimeZone.identifier,
            TimeZone.autoupdatingCurrent.identifier
        )
    }

    @MainActor
    func testClockStoreTicksStopsAndRefreshesDeterministically() async throws {
        var timestamp: TimeInterval = 100
        let store = ClockStore(
            initialDate: Date(timeIntervalSince1970: 0),
            updateInterval: .milliseconds(10),
            now: {
                timestamp += 1
                return Date(timeIntervalSince1970: timestamp)
            }
        )

        store.start()
        XCTAssertTrue(store.isMonitoring)
        XCTAssertEqual(store.currentDate, Date(timeIntervalSince1970: 101))
        try await waitUntil {
            store.currentDate >= Date(timeIntervalSince1970: 102)
        }

        store.stop()
        let stoppedDate = store.currentDate
        XCTAssertFalse(store.isMonitoring)
        try await Task.sleep(for: .milliseconds(35))
        XCTAssertEqual(store.currentDate, stoppedDate)

        store.refresh()
        XCTAssertEqual(
            store.currentDate,
            Date(timeIntervalSince1970: timestamp)
        )
        XCTAssertGreaterThan(store.currentDate, stoppedDate)
    }

    @MainActor
    func testDockHoverPermissionWaitsForUserAndRecoversAfterGrant() {
        let authorizer = StubDockHoverAccessibilityAuthorizer()
        let controller = DockHoverPermissionController(
            authorizer: authorizer
        )

        controller.synchronize(isEnabled: true)
        XCTAssertEqual(controller.state, .needsPermission)

        controller.requestAccess()
        XCTAssertEqual(authorizer.promptCount, 1)
        XCTAssertEqual(controller.state, .awaitingUserAction)

        authorizer.trusted = true
        controller.refresh()
        XCTAssertEqual(controller.state, .authorized)

        controller.synchronize(isEnabled: false)
        XCTAssertEqual(controller.state, .disabled)
        controller.stop()
    }

    func testDockHoverPanelPlacementCoversSystemLabelAndStaysOnScreen() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let centered = DockHoverPanelPlacement.frame(
            iconFrame: CGRect(x: 688, y: 0, width: 64, height: 64),
            pointerEdge: .bottom,
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(centered.midX, 720, accuracy: 0.001)
        XCTAssertEqual(centered.minY, 66, accuracy: 0.001)

        let rightEdge = DockHoverPanelPlacement.frame(
            iconFrame: CGRect(x: 1_400, y: 0, width: 40, height: 40),
            pointerEdge: .bottom,
            visibleFrame: visibleFrame
        )
        XCTAssertLessThanOrEqual(rightEdge.maxX, 1_432)
        XCTAssertGreaterThanOrEqual(rightEdge.minX, 8)

        let sideDock = DockHoverPanelPlacement.frame(
            iconFrame: CGRect(x: 0, y: 400, width: 64, height: 64),
            pointerEdge: .left,
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(sideDock.minX, 66, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(sideDock.minY, 8)
        XCTAssertLessThanOrEqual(sideDock.maxY, 892)

        let rightDock = DockHoverPanelPlacement.frame(
            iconFrame: CGRect(x: 1_376, y: 400, width: 64, height: 64),
            pointerEdge: .right,
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(rightDock.maxX, 1_374, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(rightDock.minY, 8)
        XCTAssertLessThanOrEqual(rightDock.maxY, 892)

        let bottomDockVisibleFrame = CGRect(
            x: 0,
            y: 72,
            width: 1_440,
            height: 828
        )
        let bottomDockIconFrame = CGRect(x: 688, y: 5, width: 64, height: 65)
        let loweredBottomDock = DockHoverPanelPlacement.frame(
            iconFrame: bottomDockIconFrame,
            pointerEdge: .bottom,
            visibleFrame: bottomDockVisibleFrame,
            screenFrame: visibleFrame
        )
        XCTAssertEqual(loweredBottomDock.minY, 72, accuracy: 0.001)
        XCTAssertEqual(
            loweredBottomDock.minY,
            bottomDockVisibleFrame.minY,
            accuracy: 0.001
        )
        XCTAssertEqual(
            loweredBottomDock.minY,
            bottomDockIconFrame.maxY
                + DockHoverPanelPlacement.iconClearance,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            loweredBottomDock.minY,
            bottomDockIconFrame.maxY
        )

        XCTAssertGreaterThan(
            DockHoverPanelPlacement.windowLevel.rawValue,
            NSWindow.Level.popUpMenu.rawValue
        )
        XCTAssertEqual(
            DockHoverPanelPlacement.sharePresentationWindowLevel,
            .normal
        )
        XCTAssertLessThan(
            DockHoverPanelPlacement.sharePresentationWindowLevel.rawValue,
            DockHoverPanelPlacement.windowLevel.rawValue
        )
        XCTAssertEqual(DockHoverPanelPlacement.standardPanelSize.width, 440)
        XCTAssertEqual(DockHoverPanelPlacement.standardPanelSize.height, 304)
        XCTAssertEqual(
            DockHoverPanelPlacement.panelSize(for: .weather),
            DockHoverPanelPlacement.weatherPanelSize
        )
        XCTAssertEqual(
            DockHoverPanelPlacement.weatherPanelSize.height,
            420
        )
        XCTAssertLessThan(
            DockHoverPanelPlacement.weatherPanelSize.height,
            DockHoverPanelPlacement.codexPanelSize.height
        )
        XCTAssertEqual(
            DockHoverPanelPlacement.panelSize(for: .codex).height,
            522
        )
        XCTAssertEqual(
            DockHoverPanelPlacement.panelSize(for: .claudeCode),
            DockHoverPanelPlacement.claudeCodePanelSize
        )
        XCTAssertGreaterThan(
            DockHoverPanelPlacement.claudeCodePanelSize.height,
            DockHoverPanelPlacement.codexPanelSize.height
        )
    }

    @MainActor
    func testRingWidthsClampAndNeverOverlap() {
        var appearance = DockFeatureDefaults.systemMetricsAppearance

        appearance.setOuterWidth(10)
        XCTAssertLessThanOrEqual(
            appearance.outerWidth + appearance.innerWidth,
            DockRingAppearance.maximumCombinedWidth + 0.000_001
        )
        XCTAssertEqual(
            appearance.outerWidth,
            DockRingAppearance.maximumOuterWidth
        )

        appearance.setInnerWidth(10)
        XCTAssertLessThanOrEqual(
            appearance.outerWidth + appearance.innerWidth,
            DockRingAppearance.maximumCombinedWidth + 0.000_001
        )
        XCTAssertEqual(
            appearance.innerWidth,
            DockRingAppearance.maximumInnerWidth
        )
    }

    func testStorageRingWidthClampsInvalidAndExtremeValues() {
        var appearance = DockSingleRingAppearance(
            color: .init(red: 0.5, green: 0.5, blue: 0.5),
            width: .nan
        )
        XCTAssertEqual(appearance.width, DockSingleRingAppearance.minimumWidth)

        appearance.setWidth(10)
        XCTAssertEqual(appearance.width, DockSingleRingAppearance.maximumWidth)

        appearance.setWidth(-10)
        XCTAssertEqual(appearance.width, DockSingleRingAppearance.minimumWidth)
    }

    func testGitHubRepositoryReferenceAcceptsWebAndSSHLinks() {
        XCTAssertEqual(
            GitHubRepositoryReference(
                urlString: "https://github.com/apple/swift"
            )?.fullName,
            "apple/swift"
        )
        XCTAssertEqual(
            GitHubRepositoryReference(
                urlString: "git@github.com:thanhdongnguyen/dockmagic.git"
            )?.webURLString,
            "https://github.com/thanhdongnguyen/dockmagic"
        )
        XCTAssertNil(
            GitHubRepositoryReference(urlString: "https://example.com/a/b")
        )
        XCTAssertNil(
            GitHubRepositoryReference(
                urlString: "https://github.com/apple/swift/issues"
            )
        )
    }

    func testGitHubCountFormattingStaysCompactForDockTile() {
        XCTAssertEqual(GitHubCountFormatting.compact(824), "824")
        XCTAssertEqual(GitHubCountFormatting.compact(12_742), "12.7K")
        XCTAssertEqual(GitHubCountFormatting.compact(1_250_000), "1.3M")
    }

    @MainActor
    func testResetRestoresAllAppearanceDefaults() {
        let suiteName = "DockMagicTests.Reset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DockPreferencesStore(defaults: defaults)

        store.setSystemMetricsDisplayStyle(.numeric)
        store.setSystemMetricsInnerColor(.init(red: 1, green: 1, blue: 1))
        store.setNetworkDownloadColor(.init(red: 1, green: 1, blue: 1))
        store.setStorageWidth(0.21)
        store.setGitHubDisplayStyle(.numeric)
        store.setGitHubStarColor(.init(red: 1, green: 1, blue: 1))
        store.setCodexOuterWidth(0.15)
        store.setClaudeCodeInnerWidth(0.21)
        store.resetSystemMetricsAppearance()
        store.resetNetworkAppearance()
        store.resetStorageAppearance()
        store.resetGitHubAppearance()
        store.resetCodexAppearance()
        store.resetClaudeCodeAppearance()

        var expectedSystemMetrics = DockFeatureDefaults.systemMetricsAppearance
        expectedSystemMetrics.setDisplayStyle(.numeric)
        XCTAssertEqual(store.systemMetricsAppearance, expectedSystemMetrics)
        XCTAssertEqual(
            store.networkAppearance,
            DockFeatureDefaults.networkAppearance
        )
        XCTAssertEqual(
            store.storageAppearance,
            DockFeatureDefaults.storageAppearance
        )
        var expectedGitHub = DockFeatureDefaults.githubAppearance
        expectedGitHub.setDisplayStyle(.numeric)
        XCTAssertEqual(store.githubAppearance, expectedGitHub)
        XCTAssertEqual(
            store.codexAppearance,
            DockFeatureDefaults.codexAppearance
        )
        XCTAssertEqual(
            store.claudeCodeAppearance,
            DockFeatureDefaults.claudeCodeAppearance
        )
        XCTAssertEqual(store.claudeCodeAppearance.outerColor.hex, "#D97757")
        XCTAssertEqual(store.claudeCodeAppearance.innerColor.hex, "#D97757")
    }

    @MainActor
    func testCorruptPreferencesFallBackToSafeDefaults() {
        let suiteName = "DockMagicTests.Corrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("unknown-feature", forKey: DockFeature.storageKey)
        defaults.set(
            Data("not-json".utf8),
            forKey: DockPreferencesStore.systemMetricsAppearanceKey
        )
        defaults.set(
            Data("also-not-json".utf8),
            forKey: DockPreferencesStore.codexAppearanceKey
        )
        defaults.set(
            Data("network-not-json".utf8),
            forKey: DockPreferencesStore.networkAppearanceKey
        )
        defaults.set(
            Data("storage-not-json".utf8),
            forKey: DockPreferencesStore.storageAppearanceKey
        )
        defaults.set(
            Data("github-not-json".utf8),
            forKey: DockPreferencesStore.githubAppearanceKey
        )
        defaults.set(
            Data("still-not-json".utf8),
            forKey: DockPreferencesStore.claudeCodeAppearanceKey
        )
        defaults.set(
            Data("clock-not-json".utf8),
            forKey: DockPreferencesStore.clockConfigurationKey
        )

        let store = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.activeFeature, .systemMetrics)
        XCTAssertEqual(
            store.systemMetricsAppearance,
            DockFeatureDefaults.systemMetricsAppearance
        )
        XCTAssertEqual(
            store.networkAppearance,
            DockFeatureDefaults.networkAppearance
        )
        XCTAssertEqual(
            store.storageAppearance,
            DockFeatureDefaults.storageAppearance
        )
        XCTAssertEqual(
            store.githubAppearance,
            DockFeatureDefaults.githubAppearance
        )
        XCTAssertEqual(
            store.codexAppearance,
            DockFeatureDefaults.codexAppearance
        )
        XCTAssertEqual(
            store.claudeCodeAppearance,
            DockFeatureDefaults.claudeCodeAppearance
        )
        XCTAssertEqual(
            store.clockConfiguration,
            DockFeatureDefaults.clockConfiguration
        )
    }

    func testClaudeCodeParserMapsOfficialStatusLineRateLimits() throws {
        let fetchedAt = Date(timeIntervalSince1970: 100)
        let snapshot = try ClaudeCodeRateLimitParser.parse(
            claudeRateLimits(
                fiveHourUsed: 24.6,
                weeklyUsed: 62.2
            ),
            fetchedAt: fetchedAt
        )

        XCTAssertEqual(snapshot.limitID, "claude-code")
        XCTAssertEqual(snapshot.fiveHour?.usedPercent, 25)
        XCTAssertEqual(snapshot.weekly?.usedPercent, 62)
        XCTAssertEqual(snapshot.fiveHour?.remainingFraction, 0.75)
        XCTAssertEqual(snapshot.weekly?.remainingFraction, 0.38)
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        XCTAssertEqual(
            snapshot.fiveHour?.resetsAt,
            Date(timeIntervalSince1970: 2_000_000_000)
        )
    }

    func testClaudeCodeParserHandlesMissingAndClampedWindows() throws {
        let weeklyOnly = try ClaudeCodeRateLimitParser.parse(
            claudeRateLimits(fiveHourUsed: nil, weeklyUsed: 150)
        )
        XCTAssertNil(weeklyOnly.fiveHour)
        XCTAssertEqual(weeklyOnly.weekly?.remainingFraction, 0)

        XCTAssertThrowsError(
            try ClaudeCodeRateLimitParser.parse(Data("{}".utf8))
        ) { error in
            XCTAssertEqual(
                error as? ClaudeCodeRateLimitProviderError,
                .supportedWindowsMissing
            )
        }
    }

    func testClaudeCodeParserMapsNativeSessionCostContextAndModel() throws {
        let fetchedAt = Date(timeIntervalSince1970: 2_000_000_100)
        let data = Data(
            """
            {
              "session_id": "session-123",
              "session_name": "Telemetry work",
              "version": "2.1.219",
              "model": {
                "id": "claude-sonnet-4-5",
                "display_name": "Sonnet 4.5"
              },
              "cost": {
                "total_cost_usd": 1.625,
                "total_duration_ms": 120000,
                "total_api_duration_ms": 42000,
                "total_lines_added": 80,
                "total_lines_removed": 12
              },
              "context_window": {
                "total_input_tokens": 42000,
                "total_output_tokens": 8000,
                "context_window_size": 200000,
                "used_percentage": 31.5,
                "remaining_percentage": 68.5,
                "current_usage": {
                  "input_tokens": 12000,
                  "output_tokens": 2500,
                  "cache_read_input_tokens": 18000,
                  "cache_creation_input_tokens": 1400
                }
              }
            }
            """.utf8
        )

        let snapshot = try ClaudeCodeRateLimitParser.parse(
            data,
            fetchedAt: fetchedAt
        )
        let session = try XCTUnwrap(
            snapshot.claudeTelemetry?.currentSession
        )
        XCTAssertEqual(session.sessionID, "session-123")
        XCTAssertEqual(session.sessionName, "Telemetry work")
        XCTAssertEqual(session.modelID, "claude-sonnet-4-5")
        XCTAssertEqual(session.modelDisplayName, "Sonnet 4.5")
        XCTAssertEqual(session.estimatedCostUSD, 1.625)
        XCTAssertEqual(session.totalLinesAdded, 80)
        XCTAssertEqual(session.context?.usedPercent, 31.5)
        XCTAssertEqual(session.context?.currentUsage?.inputTokens, 12_000)
        XCTAssertEqual(session.context?.currentUsage?.cachedInputTokens, 18_000)
        XCTAssertEqual(session.context?.currentUsage?.cacheWriteInputTokens, 1_400)
        XCTAssertEqual(session.context?.currentUsage?.outputTokens, 2_500)
        XCTAssertEqual(session.context?.currentUsage?.totalTokens, 33_900)
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertNil(snapshot.weekly)
    }

    func testClaudeCodeTaskSnapshotParserKeepsOnlyActiveNativeTasks() {
        let observedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let data = Data(
            """
            {
              "session_id": "session-123",
              "tasks": [
                {
                  "id": "running-task",
                  "name": "Research telemetry",
                  "type": "Explore",
                  "status": "running",
                  "description": "Inspect native fields",
                  "startTime": 2000000000000,
                  "tokenCount": 18000,
                  "lastToolName": "Read"
                },
                {
                  "id": "done-task",
                  "name": "Already done",
                  "status": "completed",
                  "tokenCount": 4000
                }
              ]
            }
            """.utf8
        )

        let tasks = ClaudeCodeTaskSnapshotParser.parse(
            data,
            observedAt: observedAt
        )
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, "running-task")
        XCTAssertEqual(tasks.first?.state, .running)
        XCTAssertEqual(tasks.first?.kind, "Explore")
        XCTAssertEqual(tasks.first?.tokenCount, 18_000)
        XCTAssertEqual(
            tasks.first?.startedAt,
            Date(timeIntervalSince1970: 2_000_000_000)
        )
    }

    @MainActor
    func testClaudeCodeBridgeCachesNativeTelemetryAndRestoresStatusLines() throws {
        let homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let claudeDirectory = homeDirectory.appendingPathComponent(
            ".claude",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: claudeDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let settingsURL = claudeDirectory.appendingPathComponent("settings.json")
        let originalStatusLine: [String: Any] = [
            "type": "command",
            "command": "/usr/bin/printf preserved",
            "padding": 2
        ]
        let originalSubagentStatusLine: [String: Any] = [
            "type": "command",
            "command": "/usr/bin/printf agent-preserved"
        ]
        let settings: [String: Any] = [
            "theme": "light",
            "statusLine": originalStatusLine,
            "subagentStatusLine": originalSubagentStatusLine
        ]
        try JSONSerialization.data(withJSONObject: settings)
            .write(to: settingsURL)

        let bridge = ClaudeCodeStatusLineBridge(homeDirectory: homeDirectory)
        try bridge.install()
        XCTAssertTrue(bridge.isInstalled())

        let scriptURL = claudeDirectory.appendingPathComponent(
            "dockmagic-statusline.sh"
        )
        let input = Data(
            """
            {"session_id":"private-session","cwd":"/private/project","rate_limits":{"five_hour":{"used_percentage":20,"resets_at":2000000000},"seven_day":{"used_percentage":40,"resets_at":2000500000}}}
            """.utf8
        )
        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        process.executableURL = scriptURL
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        try process.run()
        try standardInput.fileHandleForWriting.write(contentsOf: input)
        try standardInput.fileHandleForWriting.close()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(
            String(
                data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ),
            "preserved"
        )

        let cachedData = try Data(contentsOf: bridge.snapshotURL)
        let cachedText = String(decoding: cachedData, as: UTF8.self)
        XCTAssertTrue(cachedText.contains("five_hour"))
        XCTAssertTrue(cachedText.contains("private-session"))
        XCTAssertTrue(cachedText.contains("/private/project"))
        XCTAssertNoThrow(try ClaudeCodeRateLimitParser.parse(cachedData))
        let perSessionSnapshot = claudeDirectory
            .appendingPathComponent("dockmagic-status-sessions")
            .appendingPathComponent("private-session.json")
        XCTAssertEqual(try Data(contentsOf: perSessionSnapshot), input)

        let subagentScriptURL = claudeDirectory.appendingPathComponent(
            "dockmagic-subagent-statusline.sh"
        )
        let subagentInput = Data(
            """
            {"session_id":"private-session","tasks":[{"id":"task-1","name":"Research","status":"running","tokenCount":1200}]}
            """.utf8
        )
        let subagentProcess = Process()
        let subagentStandardInput = Pipe()
        let subagentStandardOutput = Pipe()
        subagentProcess.executableURL = subagentScriptURL
        subagentProcess.standardInput = subagentStandardInput
        subagentProcess.standardOutput = subagentStandardOutput
        try subagentProcess.run()
        try subagentStandardInput.fileHandleForWriting.write(
            contentsOf: subagentInput
        )
        try subagentStandardInput.fileHandleForWriting.close()
        subagentProcess.waitUntilExit()
        XCTAssertEqual(subagentProcess.terminationStatus, 0)
        XCTAssertEqual(
            String(
                data: subagentStandardOutput.fileHandleForReading
                    .readDataToEndOfFile(),
                encoding: .utf8
            ),
            "agent-preserved"
        )
        let taskSnapshotURL = claudeDirectory.appendingPathComponent(
            "dockmagic-subagents.json"
        )
        XCTAssertEqual(try Data(contentsOf: taskSnapshotURL), subagentInput)
        XCTAssertEqual(
            ClaudeCodeTaskSnapshotParser.parse(
                try Data(contentsOf: taskSnapshotURL),
                observedAt: .now
            ).first?.id,
            "task-1"
        )

        try bridge.uninstall()
        XCTAssertFalse(bridge.isInstalled())
        XCTAssertFalse(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: subagentScriptURL.path)
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: bridge.snapshotURL.path)
        )

        let restoredObject = try JSONSerialization.jsonObject(
            with: Data(contentsOf: settingsURL)
        ) as! [String: Any]
        let restoredStatusLine = restoredObject["statusLine"] as! [String: Any]
        XCTAssertEqual(
            restoredStatusLine["command"] as? String,
            "/usr/bin/printf preserved"
        )
        XCTAssertEqual(restoredStatusLine["padding"] as? Int, 2)
        let restoredSubagentStatusLine = restoredObject[
            "subagentStatusLine"
        ] as! [String: Any]
        XCTAssertEqual(
            restoredSubagentStatusLine["command"] as? String,
            "/usr/bin/printf agent-preserved"
        )
        XCTAssertEqual(restoredObject["theme"] as? String, "light")
    }

    func testClaudeCodeLocalHistoryAggregatesRealUsageModelsTasksAndGoal() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projects = root.appendingPathComponent("projects", isDirectory: true)
        let project = projects.appendingPathComponent("sample", isDirectory: true)
        try FileManager.default.createDirectory(
            at: project,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let currentTimestamp = ISO8601DateFormatter().string(
            from: now.addingTimeInterval(-86_400)
        )
        let currentTranscript = [
            """
            {"type":"user","sessionId":"current-session","timestamp":"\(currentTimestamp)","message":{"role":"user","content":"private prompt that the reader must ignore"}}
            """,
            """
            {"type":"assistant","sessionId":"current-session","timestamp":"\(currentTimestamp)","uuid":"usage-1","message":{"role":"assistant","model":"claude-sonnet-4-5","usage":{"input_tokens":100,"output_tokens":20,"cache_read_input_tokens":300,"cache_creation_input_tokens":40},"content":[{"type":"text","text":"private answer that the reader must ignore"}]}}
            """,
            """
            {"type":"assistant","sessionId":"current-session","timestamp":"\(currentTimestamp)","uuid":"usage-1","message":{"role":"assistant","model":"claude-sonnet-4-5","usage":{"input_tokens":100,"output_tokens":20,"cache_read_input_tokens":300,"cache_creation_input_tokens":40},"content":[]}}
            """,
            """
            {"type":"assistant","sessionId":"current-session","timestamp":"\(currentTimestamp)","uuid":"synthetic","message":{"role":"assistant","model":"<synthetic>","usage":{"input_tokens":999999,"output_tokens":999999},"content":[]}}
            """,
            """
            {"type":"active_goal","sessionId":"current-session","timestamp":"\(currentTimestamp)","value":{"condition":"Ship native telemetry","iterations":3,"last_reason":"continue","set_at":1999990000}}
            """,
            """
            {"type":"system","subtype":"task_started","sessionId":"current-session","timestamp":"\(currentTimestamp)","task_id":"task-1","description":"Inspect Claude data","subagent_type":"Explore"}
            """
        ].joined(separator: "\n")
        let currentURL = project.appendingPathComponent("current.jsonl")
        try Data(currentTranscript.utf8).write(to: currentURL)

        let previousDate = now.addingTimeInterval(-9 * 86_400)
        let previousTimestamp = ISO8601DateFormatter().string(from: previousDate)
        let previousTranscript = """
        {"type":"assistant","sessionId":"previous-session","timestamp":"\(previousTimestamp)","uuid":"usage-2","message":{"role":"assistant","model":"claude-opus-4-1","usage":{"input_tokens":50,"output_tokens":10,"cache_read_input_tokens":0,"cache_creation_input_tokens":5},"content":[]}}
        """
        let previousURL = project.appendingPathComponent("previous.jsonl")
        try Data(previousTranscript.utf8).write(to: previousURL)
        for url in [currentURL, previousURL] {
            try FileManager.default.setAttributes(
                [.modificationDate: now],
                ofItemAtPath: url.path
            )
        }

        let result = ClaudeCodeLocalHistoryReader(
            projectsDirectoryURL: projects,
            now: now,
            calendar: calendar
        ).read()

        XCTAssertEqual(
            result.tokenUsage?.dailyUsageBuckets.reduce(0) {
                $0 + $1.tokens
            },
            525
        )
        XCTAssertEqual(
            result.tokenUsage?.modelUsage?.map(\.model),
            ["claude-sonnet-4-5", "claude-opus-4-1"]
        )
        XCTAssertEqual(
            result.tokenUsage?.modelUsage?.map(\.tokens),
            [460, 65]
        )
        XCTAssertEqual(result.recentTaskActivity?.currentWeekCount, 1)
        XCTAssertEqual(result.recentTaskActivity?.previousWeekCount, 1)
        XCTAssertEqual(result.activeGoals.first?.objective, "Ship native telemetry")
        XCTAssertEqual(result.activeGoals.first?.iterations, 3)
        XCTAssertTrue(result.activeTasks.isEmpty)
    }

    func testClaudeCodeUsageChartAlignsTokensAndObservedCostsByDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let today = calendar.startOfDay(for: now)
        let tokenUsage = CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: 120,
            currentStreakDays: nil,
            longestStreakDays: nil,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(
                    startDate: today,
                    tokens: 120
                )
            ]
        )
        let costs = [
            ClaudeCodeDailyCostUsage(
                startDate: today,
                estimatedCostUSD: 1.25
            )
        ]

        let tokenBuckets = ClaudeCodeHoverDashboardPresentation.chartBuckets(
            tokenUsage: tokenUsage,
            dailyCosts: costs,
            metric: "Tokens",
            now: now,
            calendar: calendar
        )
        let costBuckets = ClaudeCodeHoverDashboardPresentation.chartBuckets(
            tokenUsage: tokenUsage,
            dailyCosts: costs,
            metric: "Cost",
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(tokenBuckets.count, 7)
        XCTAssertEqual(tokenBuckets.last?.value, 120)
        XCTAssertEqual(costBuckets.count, 7)
        XCTAssertEqual(costBuckets.last?.value, 1.25)
        XCTAssertTrue(costBuckets.last?.accessibilityValue.contains("$1.25") == true)
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.tokenLabel(1_280_000),
            "1.28M"
        )
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.modelLabel(
                "claude-haiku-4-5"
            ),
            "Claude Haiku 4.5"
        )
    }

    func testClaudeCodeModelCostRequiresSingleModelSessionEvidence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        let tasks = root.appendingPathComponent("tasks", isDirectory: true)
        let projects = root.appendingPathComponent("projects", isDirectory: true)
        let project = projects.appendingPathComponent("sample", isDirectory: true)
        for directory in [sessions, tasks, project] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let timestamp = ISO8601DateFormatter().string(
            from: now.addingTimeInterval(-60)
        )
        let transcript = [
            """
            {"type":"assistant","sessionId":"single-model","timestamp":"\(timestamp)","uuid":"single-1","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":10,"output_tokens":2}}}
            """,
            """
            {"type":"assistant","sessionId":"switched-model","timestamp":"\(timestamp)","uuid":"switch-1","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":10,"output_tokens":2}}}
            """,
            """
            {"type":"assistant","sessionId":"switched-model","timestamp":"\(timestamp)","uuid":"switch-2","message":{"model":"claude-opus-4-1","usage":{"input_tokens":10,"output_tokens":2}}}
            """
        ].joined(separator: "\n")
        let transcriptURL = project.appendingPathComponent("usage.jsonl")
        try Data(transcript.utf8).write(to: transcriptURL)

        let snapshots: [(String, Double, String)] = [
            ("single-model", 1.5, "claude-sonnet-4-5"),
            ("switched-model", 2.0, "claude-opus-4-1")
        ]
        for (sessionID, cost, model) in snapshots {
            let data = Data(
                """
                {"session_id":"\(sessionID)","model":{"id":"\(model)"},"cost":{"total_cost_usd":\(cost)}}
                """.utf8
            )
            let url = sessions.appendingPathComponent("\(sessionID).json")
            try data.write(to: url)
            try FileManager.default.setAttributes(
                [.modificationDate: now],
                ofItemAtPath: url.path
            )
        }
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: transcriptURL.path
        )

        let result = ClaudeCodeLocalTelemetryReader(
            snapshotURL: root.appendingPathComponent("latest.json"),
            sessionSnapshotsDirectoryURL: sessions,
            taskSnapshotURL: root.appendingPathComponent("latest-tasks.json"),
            taskSnapshotsDirectoryURL: tasks,
            projectsDirectoryURL: projects,
            now: now,
            calendar: calendar
        ).read()

        XCTAssertEqual(
            result.dailyCosts.reduce(0) { $0 + $1.estimatedCostUSD },
            3.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(result.modelCosts.count, 1)
        XCTAssertEqual(result.modelCosts.first?.model, "claude-sonnet-4-5")
        XCTAssertEqual(
            result.modelCosts.first?.estimatedCostUSD ?? 0,
            1.5,
            accuracy: 0.0001
        )
    }

    func testCodexParserMapsFiveHourAndWeeklyRemainingValues() throws {
        let fetchedAt = Date(timeIntervalSince1970: 10)
        let snapshot = try CodexRateLimitParser.parseJSONLines(
            codexResponse(
                fallback: rateLimitBucket(
                    limitID: "codex",
                    primaryDuration: 300,
                    primaryUsed: 25,
                    secondaryDuration: 10_080,
                    secondaryUsed: 60
                )
            ),
            fetchedAt: fetchedAt
        )

        XCTAssertEqual(snapshot.limitID, "codex")
        XCTAssertEqual(snapshot.planType, "pro")
        XCTAssertEqual(snapshot.fiveHour?.remainingFraction, 0.75)
        XCTAssertEqual(snapshot.weekly?.remainingFraction, 0.40)
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
    }

    func testCodexParserMapsAccountTokenUsageAndSevenDailyBuckets() throws {
        let rateLimits = codexResponse(
            fallback: rateLimitBucket(
                limitID: "codex",
                primaryDuration: 300,
                primaryUsed: 26,
                secondaryDuration: 10_080,
                secondaryUsed: 59
            )
        )
        let usage = codexTokenUsageResponse(
            lifetimeTokens: 18_400_000,
            dailyTokens: [980_000, 1_320_000, 1_560_000, 1_210_000,
                          1_010_000, 730_000, 1_280_000]
        )

        XCTAssertTrue(
            CodexRateLimitParser.containsCompleteUsageResponse(
                rateLimits + usage
            )
        )

        let snapshot = try CodexRateLimitParser.parseJSONLines(
            rateLimits + usage
        )
        XCTAssertEqual(snapshot.tokenUsage?.lifetimeTokens, 18_400_000)
        XCTAssertEqual(snapshot.tokenUsage?.peakDailyTokens, 1_560_000)
        XCTAssertEqual(snapshot.tokenUsage?.currentStreakDays, 7)
        XCTAssertEqual(snapshot.tokenUsage?.longestStreakDays, 28)
        XCTAssertEqual(
            snapshot.tokenUsage?.longestRunningTurnSeconds,
            1_460
        )
        XCTAssertEqual(snapshot.tokenUsage?.dailyUsageBuckets.count, 7)
        XCTAssertEqual(snapshot.tokenUsage?.latestDailyTokens, 1_280_000)

        let detail = CodexDailyTokenDetail(
            startDate: Date(timeIntervalSince1970: 1_777_000_000),
            usage: CodexTokenBreakdown(
                inputTokens: 800,
                cachedInputTokens: 600,
                cacheWriteInputTokens: 0,
                outputTokens: 200,
                reasoningOutputTokens: 100,
                totalTokens: 1_000
            ),
            hourlyUsage: [],
            modelUsage: [],
            isPartial: false
        )
        let snapshotWithLocalDetail = try CodexRateLimitParser.parseJSONLines(
            rateLimits + usage,
            localModelUsage: CodexLocalModelUsageResult(
                rows: [
                    CodexModelTokenUsage(model: "gpt-5.6", tokens: 1_000)
                ],
                isPartial: false,
                dailyDetails: [detail]
            )
        )
        XCTAssertEqual(
            snapshotWithLocalDetail.tokenUsage?.localDailyDetails,
            [detail]
        )
    }

    func testCodexParserKeepsRateLimitsWhenAccountUsageIsUnsupported() throws {
        let response = codexResponse(
            fallback: rateLimitBucket(
                limitID: "codex",
                primaryDuration: 300,
                primaryUsed: 20
            )
        ) + Data(
            "{\"id\":3,\"error\":{\"message\":\"method not found\"}}\n".utf8
        )

        let snapshot = try CodexRateLimitParser.parseJSONLines(response)
        XCTAssertEqual(snapshot.fiveHour?.remainingFraction, 0.8)
        XCTAssertNil(snapshot.tokenUsage)
    }

    func testCodexParserMapsRecentRootTasksAcrossActiveAndArchivedPages() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let fetchedAt = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 12
        ))!
        func timestamp(day: Int) -> Int64 {
            Int64(calendar.date(from: DateComponents(
                year: 2026,
                month: 8,
                day: day,
                hour: 12
            ))!.timeIntervalSince1970)
        }
        func thread(day: Int, parent: Any = NSNull()) -> [String: Any] {
            [
                "createdAt": timestamp(day: day),
                "parentThreadId": parent,
                "ephemeral": false
            ]
        }

        let rateLimits = codexResponse(
            fallback: rateLimitBucket(
                limitID: "codex",
                primaryDuration: 300,
                primaryUsed: 26,
                secondaryDuration: 10_080,
                secondaryUsed: 59
            )
        )
        let usage = codexTokenUsageResponse(
            lifetimeTokens: 18_400_000,
            dailyTokens: Array(repeating: 500_000, count: 14)
        )
        let active = codexThreadListResponse(
            id: 4,
            threads: [
                thread(day: 25),
                thread(day: 20),
                thread(day: 18),
                thread(day: 24, parent: "parent-thread")
            ]
        )
        let archived = codexThreadListResponse(
            id: 5,
            threads: [
                thread(day: 22),
                thread(day: 15)
            ]
        )
        let response = rateLimits + usage + active + archived

        XCTAssertTrue(
            CodexRateLimitParser.containsCompleteDashboardResponse(response)
        )
        let snapshot = try CodexRateLimitParser.parseJSONLines(
            response,
            fetchedAt: fetchedAt
        )
        XCTAssertEqual(snapshot.recentTaskActivity?.currentWeekCount, 3)
        XCTAssertEqual(snapshot.recentTaskActivity?.previousWeekCount, 2)
        XCTAssertEqual(snapshot.recentTaskActivity?.isPartial, false)
    }

    func testCodexParserMarksRecentTaskCountPartialWhenPageEndsInWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let fetchedAt = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 12
        ))!
        let createdAt = Int64(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 20,
            hour: 12
        ))!.timeIntervalSince1970)
        let thread: [String: Any] = [
            "createdAt": createdAt,
            "parentThreadId": NSNull(),
            "ephemeral": false
        ]
        let response = codexResponse(
            fallback: rateLimitBucket(
                limitID: "codex",
                primaryDuration: 300,
                primaryUsed: 20
            )
        )
            + codexThreadListResponse(
                id: 4,
                threads: [thread],
                nextCursor: "more"
            )
            + codexThreadListResponse(id: 5, threads: [])

        let snapshot = try CodexRateLimitParser.parseJSONLines(
            response,
            fetchedAt: fetchedAt
        )
        XCTAssertEqual(snapshot.recentTaskActivity?.currentWeekCount, 1)
        XCTAssertEqual(snapshot.recentTaskActivity?.isPartial, true)
    }

    func testCodexParserAggregatesRecentRootThreadTokensByModel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let fetchedAt = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 12
        ))!
        func timestamp(day: Int, month: Int = 8) -> Int64 {
            Int64(calendar.date(from: DateComponents(
                year: 2026,
                month: month,
                day: day,
                hour: 12
            ))!.timeIntervalSince1970)
        }
        func thread(
            id: String,
            day: Int,
            month: Int = 8,
            parent: Any = NSNull()
        ) -> [String: Any] {
            [
                "id": id,
                "createdAt": timestamp(day: day, month: month),
                "parentThreadId": parent,
                "ephemeral": false
            ]
        }

        let response = codexResponse(
            fallback: rateLimitBucket(
                limitID: "codex",
                primaryDuration: 300,
                primaryUsed: 20
            )
        )
            + codexTokenUsageResponse(
                lifetimeTokens: 18_400_000,
                dailyTokens: Array(repeating: 500_000, count: 14)
            )
            + codexThreadListResponse(
                id: 4,
                threads: [
                    thread(id: "active-a", day: 25),
                    thread(
                        id: "child",
                        day: 24,
                        parent: "active-a"
                    ),
                    thread(id: "old", day: 1, month: 7)
                ]
            )
            + codexThreadListResponse(
                id: 5,
                threads: [thread(id: "archived-b", day: 22)]
            )

        let plan = CodexRateLimitParser.modelUsageRequestPlan(
            response,
            fetchedAt: fetchedAt
        )
        XCTAssertEqual(plan.threadIDs, ["active-a", "archived-b"])
        XCTAssertFalse(plan.isPartial)

        let completeResponse = response
            + codexThreadUsageResponse(
                id: 1_000,
                threadID: "active-a",
                groups: [
                    ("gpt-5.6", 1_000_000),
                    ("gpt-5.5", 200_000)
                ]
            )
            + codexThreadUsageResponse(
                id: 1_001,
                threadID: "archived-b",
                groups: [
                    ("gpt-5.5", 600_000),
                    ("gpt-5.6", 100_000)
                ]
            )
        XCTAssertTrue(
            CodexRateLimitParser.containsResponses(
                [1_000, 1_001],
                in: completeResponse
            )
        )

        let snapshot = try CodexRateLimitParser.parseJSONLines(
            completeResponse,
            fetchedAt: fetchedAt
        )
        XCTAssertEqual(
            snapshot.tokenUsage?.modelUsage,
            [
                CodexModelTokenUsage(model: "gpt-5.6", tokens: 1_100_000),
                CodexModelTokenUsage(model: "gpt-5.5", tokens: 800_000)
            ]
        )
        XCTAssertEqual(snapshot.tokenUsage?.isModelUsagePartial, false)

        let partialSnapshot = try CodexRateLimitParser.parseJSONLines(
            response + codexThreadUsageResponse(
                id: 1_000,
                threadID: "active-a",
                groups: [("gpt-5.6", 1_000_000)]
            ),
            fetchedAt: fetchedAt
        )
        XCTAssertEqual(partialSnapshot.tokenUsage?.modelUsage?.count, 1)
        XCTAssertEqual(partialSnapshot.tokenUsage?.isModelUsagePartial, true)
    }

    func testCodexLocalModelUsageReaderUsesOnlyRecentTokenMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        func line(_ object: [String: Any]) throws -> Data {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(0x0A)
            return data
        }
        func turn(model: String, timestamp: String) -> [String: Any] {
            [
                "timestamp": timestamp,
                "type": "turn_context",
                "payload": ["model": model]
            ]
        }
        func tokenCount(
            input: Int64,
            cachedInput: Int64,
            output: Int64,
            timestamp: String
        ) -> [String: Any] {
            [
                "timestamp": timestamp,
                "type": "event_msg",
                "payload": [
                    "type": "token_count",
                    "info": [
                        "last_token_usage": [
                            "input_tokens": input,
                            "cached_input_tokens": cachedInput,
                            "cache_write_input_tokens": 0,
                            "output_tokens": output,
                            "reasoning_output_tokens": output / 2,
                            "total_tokens": input + output
                        ]
                    ]
                ]
            ]
        }

        var fixture = Data()
        fixture.append(try line(turn(
            model: "gpt-5.6",
            timestamp: "2026-08-25T08:00:00.000Z"
        )))
        fixture.append(try line(tokenCount(
            input: 800,
            cachedInput: 600,
            output: 200,
            timestamp: "2026-08-25T08:01:00.000Z"
        )))
        fixture.append(try line(tokenCount(
            input: 90_000,
            cachedInput: 80_000,
            output: 9_000,
            timestamp: "2026-07-01T08:01:00.000Z"
        )))
        fixture.append(try line(turn(
            model: "gpt-5.5",
            timestamp: "2026-08-25T09:00:00.000Z"
        )))
        fixture.append(try line(tokenCount(
            input: 600,
            cachedInput: 400,
            output: 100,
            timestamp: "2026-08-25T09:01:00.000Z"
        )))
        try fixture.write(to: root.appendingPathComponent("rollout.jsonl"))

        let fetchedAt = ISO8601DateFormatter().date(
            from: "2026-08-26T12:00:00Z"
        )!
        let result = try XCTUnwrap(
            CodexLocalModelUsageReader(sessionsRoot: root).read(
                fetchedAt: fetchedAt
            )
        )
        XCTAssertEqual(
            result.rows,
            [
                CodexModelTokenUsage(model: "gpt-5.6", tokens: 1_000),
                CodexModelTokenUsage(model: "gpt-5.5", tokens: 700)
            ]
        )
        XCTAssertFalse(result.isPartial)

        let detail = try XCTUnwrap(result.dailyDetails?.first)
        XCTAssertEqual(result.dailyDetails?.count, 1)
        XCTAssertEqual(detail.usage.inputTokens, 1_400)
        XCTAssertEqual(detail.usage.cachedInputTokens, 1_000)
        XCTAssertEqual(detail.usage.outputTokens, 300)
        XCTAssertEqual(detail.usage.reasoningOutputTokens, 150)
        XCTAssertEqual(detail.usage.totalTokens, 1_700)
        XCTAssertEqual(detail.hourlyUsage.count, 24)
        XCTAssertEqual(
            detail.hourlyUsage.filter { $0.usage.totalTokens > 0 }
                .map(\.usage.totalTokens),
            [1_000, 700]
        )
        XCTAssertEqual(detail.modelUsage.count, 2)
        XCTAssertEqual(detail.modelUsage[0].model, "gpt-5.6")
        XCTAssertEqual(detail.modelUsage[0].usage.totalTokens, 1_000)
        XCTAssertEqual(detail.modelUsage[1].model, "gpt-5.5")
        XCTAssertEqual(detail.modelUsage[1].usage.totalTokens, 700)
        XCTAssertFalse(detail.isPartial)
    }

    func testCodexDailyTokenDetailReaderScansOnlyClickedDayCandidates() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsRoot = root.appendingPathComponent(
            "sessions",
            isDirectory: true
        )
        let archivedRoot = root.appendingPathComponent(
            "archived_sessions",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sessionsRoot,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: archivedRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let referenceDate = ISO8601DateFormatter().date(
            from: "2026-08-25T12:00:00Z"
        )!
        let dayStart = calendar.startOfDay(for: referenceDate)
        let nextDay = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: dayStart)
        )
        let firstHour = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: 8, to: dayStart)
        )
        let secondHour = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: 9, to: dayStart)
        )
        let archivedHour = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: 10, to: dayStart)
        )

        let activeURL = sessionsRoot.appendingPathComponent(
            "rollout-active.jsonl"
        )
        let archivedURL = archivedRoot.appendingPathComponent(
            "rollout-archived.jsonl"
        )
        let irrelevantURL = sessionsRoot.appendingPathComponent(
            "rollout-future.jsonl"
        )
        let activeData = try codexRolloutFixture(
            model: "gpt-5.6",
            events: [
                (firstHour.addingTimeInterval(60), 800, 600, 200),
                (secondHour.addingTimeInterval(60), 600, 400, 100)
            ]
        )
        let archivedData = try codexRolloutFixture(
            model: "gpt-5.5",
            events: [
                (archivedHour.addingTimeInterval(60), 300, 200, 100)
            ]
        )
        try activeData.write(to: activeURL)
        try archivedData.write(to: archivedURL)
        try Data(repeating: 0x78, count: 4 * 1_024 * 1_024)
            .write(to: irrelevantURL)

        let databaseURL = root.appendingPathComponent("state_5.sqlite")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            databaseURL.path,
            """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                rollout_path TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
            INSERT INTO threads VALUES (
                'active',
                '\(sqlString(activeURL.path))',
                \(Int64(dayStart.timeIntervalSince1970 + 60)),
                \(Int64(secondHour.timeIntervalSince1970 + 120))
            );
            INSERT INTO threads VALUES (
                'archived',
                '\(sqlString(archivedURL.path))',
                \(Int64(dayStart.timeIntervalSince1970 + 120)),
                \(Int64(archivedHour.timeIntervalSince1970 + 120))
            );
            INSERT INTO threads VALUES (
                'future',
                '\(sqlString(irrelevantURL.path))',
                \(Int64(nextDay.timeIntervalSince1970 + 60)),
                \(Int64(nextDay.timeIntervalSince1970 + 120))
            );
            """
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let result = try CodexLocalDailyTokenDetailReader(
            sessionRoots: [sessionsRoot, archivedRoot],
            stateDatabaseURL: databaseURL,
            readChunkSize: 128
        ).readDetail(for: referenceDate)
        let detail = try XCTUnwrap(result.detail)

        XCTAssertTrue(result.usedStateDatabaseIndex)
        XCTAssertEqual(result.candidateFileCount, 2)
        XCTAssertEqual(result.scannedFileCount, 2)
        XCTAssertEqual(
            result.scannedBytes,
            Int64(activeData.count + archivedData.count)
        )
        XCTAssertLessThan(result.scannedBytes, 4 * 1_024 * 1_024)
        XCTAssertTrue(calendar.isDate(detail.startDate, inSameDayAs: referenceDate))
        XCTAssertEqual(detail.usage.inputTokens, 1_700)
        XCTAssertEqual(detail.usage.cachedInputTokens, 1_200)
        XCTAssertEqual(detail.usage.outputTokens, 400)
        XCTAssertEqual(detail.usage.totalTokens, 2_100)
        XCTAssertEqual(detail.hourlyUsage.count, 24)
        XCTAssertEqual(
            detail.hourlyUsage.filter { $0.usage.totalTokens > 0 }.count,
            3
        )
        XCTAssertEqual(detail.modelUsage.map(\.model), ["gpt-5.6", "gpt-5.5"])
        XCTAssertFalse(detail.isPartial)
    }

    func testCodexDailyTokenDetailLoaderDeduplicatesAndCachesPastDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = ISO8601DateFormatter().date(
            from: "2026-08-27T12:00:00Z"
        )!
        let requestedDate = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -3, to: now)
        )
        let counter = CodexDailyDetailLoadCounter()
        let loader = CodexDailyTokenDetailLoader(
            now: { now },
            loadOperation: { date in
                try await counter.load(date: date)
            }
        )

        async let first = loader.loadDetail(for: requestedDate)
        async let second = loader.loadDetail(for: requestedDate)
        let (firstDetail, secondDetail) = try await (first, second)
        XCTAssertEqual(firstDetail, secondDetail)

        let cachedDetail = try await loader.loadDetail(for: requestedDate)
        XCTAssertEqual(cachedDetail, firstDetail)
        let callCount = await counter.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testCodexDailyTokenDetailReaderUsesLocalDayBoundaries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let referenceDate = ISO8601DateFormatter().date(
            from: "2026-08-25T12:00:00Z"
        )!
        let dayStart = calendar.startOfDay(for: referenceDate)
        let nextDay = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: dayStart)
        )
        let rolloutURL = root.appendingPathComponent("rollout-boundary.jsonl")
        let rollout = try codexRolloutFixture(
            model: "gpt-boundary",
            events: [
                (dayStart.addingTimeInterval(5 * 60), 100, 60, 20),
                (nextDay.addingTimeInterval(-5 * 60), 200, 120, 40),
                (nextDay.addingTimeInterval(5 * 60), 9_000, 8_000, 1_000)
            ]
        )
        try rollout.write(to: rolloutURL)

        let databaseURL = root.appendingPathComponent("state_5.sqlite")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            databaseURL.path,
            """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                rollout_path TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
            INSERT INTO threads VALUES (
                'boundary',
                '\(sqlString(rolloutURL.path))',
                \(Int64(dayStart.timeIntervalSince1970)),
                \(Int64(nextDay.timeIntervalSince1970 + 600))
            );
            """
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let result = try CodexLocalDailyTokenDetailReader(
            sessionRoots: [root],
            stateDatabaseURL: databaseURL,
            readChunkSize: 96
        ).readDetail(for: referenceDate)
        let detail = try XCTUnwrap(result.detail)
        let populatedHours = detail.hourlyUsage.filter {
            $0.usage.totalTokens > 0
        }

        XCTAssertEqual(detail.usage.inputTokens, 300)
        XCTAssertEqual(detail.usage.outputTokens, 60)
        XCTAssertEqual(detail.usage.totalTokens, 360)
        XCTAssertEqual(
            populatedHours.map {
                calendar.component(.hour, from: $0.startDate)
            },
            [0, 23]
        )
    }

    func testCodexLocalModelUsageReaderPrefersReadOnlyStateDatabase() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let databaseURL = root.appendingPathComponent("state_5.sqlite")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            databaseURL.path,
            """
            CREATE TABLE threads (
                created_at INTEGER NOT NULL,
                model TEXT,
                tokens_used INTEGER NOT NULL
            );
            INSERT INTO threads VALUES (1787590800, 'gpt-5.6', 900);
            INSERT INTO threads VALUES (1787504400, 'gpt-5.5', 600);
            INSERT INTO threads VALUES (1787504400, 'gpt-5.6', 100);
            INSERT INTO threads VALUES (1750000000, 'old-model', 999999);
            """
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let fetchedAt = ISO8601DateFormatter().date(
            from: "2026-08-26T12:00:00Z"
        )!
        let result = try XCTUnwrap(
            CodexLocalModelUsageReader(
                sessionsRoot: root,
                stateDatabaseURL: databaseURL
            ).read(fetchedAt: fetchedAt)
        )
        XCTAssertEqual(
            result.rows,
            [
                CodexModelTokenUsage(model: "gpt-5.6", tokens: 1_000),
                CodexModelTokenUsage(model: "gpt-5.5", tokens: 600)
            ]
        )
        XCTAssertFalse(result.isPartial)
        XCTAssertNil(result.dailyDetails)
    }

    func testCodexParserSupportsWeeklyOnlyWithoutInventingFiveHour() throws {
        let snapshot = try CodexRateLimitParser.parseJSONLines(
            codexResponse(
                fallback: rateLimitBucket(
                    limitID: "codex",
                    primaryDuration: 10_080,
                    primaryUsed: 2
                )
            )
        )

        XCTAssertNil(snapshot.fiveHour)
        XCTAssertEqual(snapshot.weekly?.remainingFraction, 0.98)
    }

    func testCodexParserPrefersAggregateCodexBucketOverModelBucketAndFallback() throws {
        let fallback = rateLimitBucket(
            limitID: "fallback",
            primaryDuration: 300,
            primaryUsed: 99
        )
        let aggregate = rateLimitBucket(
            limitID: "codex",
            primaryDuration: 10_080,
            primaryUsed: 20
        )
        let model = rateLimitBucket(
            limitID: "codex_model",
            primaryDuration: 300,
            primaryUsed: 80
        )

        let snapshot = try CodexRateLimitParser.parseJSONLines(
            codexResponse(
                fallback: fallback,
                buckets: ["codex": aggregate, "codex_model": model]
            )
        )

        XCTAssertEqual(snapshot.limitID, "codex")
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertEqual(snapshot.weekly?.remainingFraction, 0.8)
    }

    func testCodexParserClampsServerPercentage() throws {
        let snapshot = try CodexRateLimitParser.parseJSONLines(
            codexResponse(
                fallback: rateLimitBucket(
                    limitID: "codex",
                    primaryDuration: 300,
                    primaryUsed: 140,
                    secondaryDuration: 10_080,
                    secondaryUsed: -10
                )
            )
        )

        XCTAssertEqual(snapshot.fiveHour?.remainingFraction, 0)
        XCTAssertEqual(snapshot.weekly?.remainingFraction, 1)
    }

    func testCodexParserSurfacesServerAndSchemaErrors() {
        XCTAssertThrowsError(
            try CodexRateLimitParser.parseJSONLines(
                Data("{\"id\":2,\"error\":{\"message\":\"login required\"}}\n".utf8)
            )
        ) { error in
            XCTAssertEqual(
                error as? CodexRateLimitProviderError,
                .serverError("login required")
            )
        }

        XCTAssertThrowsError(
            try CodexRateLimitParser.parseJSONLines(Data("not json\n".utf8))
        ) { error in
            XCTAssertEqual(
                error as? CodexRateLimitProviderError,
                .invalidResponse
            )
        }

        XCTAssertThrowsError(
            try CodexRateLimitParser.parseJSONLines(
                codexResponse(
                    fallback: rateLimitBucket(
                        limitID: "codex",
                        primaryDuration: 1_440,
                        primaryUsed: 50
                    )
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? CodexRateLimitProviderError,
                .supportedWindowsMissing
            )
        }
    }

    func testExecutableLocatorValidatesExplicitPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let executable = directory.appendingPathComponent("codex")
        XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data()))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let locator = CodexExecutableLocator(
            environment: [:],
            homeDirectory: directory
        )
        XCTAssertEqual(
            try locator.locate(overridePath: executable.path),
            executable
        )

        XCTAssertThrowsError(
            try locator.locate(overridePath: directory.appendingPathComponent("missing").path)
        )
    }

    @MainActor
    func testCodexUsageStoreTransitionsFromLiveToStale() async {
        let snapshot = sampleCodexSnapshot()
        let provider = ScriptedCodexProvider([
            .success(snapshot),
            .failure(CodexRateLimitProviderError.timedOut)
        ])
        let store = CodexUsageStore(
            provider: provider,
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )

        await store.refresh()
        XCTAssertEqual(store.state, .live(snapshot))
        XCTAssertEqual(store.resolvedExecutablePath, "/usr/bin/true")

        await store.refresh()
        guard case let .stale(staleSnapshot, message) = store.state else {
            return XCTFail("Expected stale state after a failed refresh.")
        }
        XCTAssertEqual(staleSnapshot, snapshot)
        XCTAssertTrue(message.contains("time"))
    }

    @MainActor
    func testCodexUsageStoreReportsUnavailableWithoutPriorSnapshot() async {
        let store = CodexUsageStore(
            provider: ScriptedCodexProvider([
                .failure(CodexRateLimitProviderError.executableNotFound)
            ]),
            locator: ThrowingCodexLocator(),
            pollingInterval: .seconds(60)
        )

        await store.refresh()
        guard case let .unavailable(message) = store.state else {
            return XCTFail("Expected unavailable state.")
        }
        XCTAssertTrue(message.contains("not found"))
    }

    @MainActor
    func testCodexUsageStoreCancelsRefreshAndCanRestartCleanly() async throws {
        let provider = CancellableCodexProvider()
        let store = CodexUsageStore(
            provider: provider,
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )

        store.start()
        try await waitUntil {
            store.isMonitoring && store.isRefreshing
        }

        store.stop()
        XCTAssertFalse(store.isMonitoring)
        XCTAssertFalse(store.isRefreshing)
        XCTAssertEqual(store.state, .idle)

        try await Task.sleep(for: .milliseconds(30))
        let cancellationCount = await provider.cancellationCount
        XCTAssertEqual(cancellationCount, 1)

        store.start()
        try await waitUntil {
            store.isMonitoring && store.isRefreshing
        }
        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 2)

        store.stop()
    }

    @MainActor
    func testCodexUsageStoreDeduplicatesConcurrentRefreshes() async {
        let snapshot = sampleCodexSnapshot()
        let provider = DelayedCodexProvider(snapshot: snapshot)
        let store = CodexUsageStore(
            provider: provider,
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )

        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await (first, second)

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(store.state, .live(snapshot))
        XCTAssertFalse(store.isRefreshing)
    }

    @MainActor
    func testCodexAutomaticPreparationDetectsExecutableAndRefreshesOnFirstUse() async {
        let suiteName = "DockMagicTests.CodexAutoDetection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = DockPreferencesStore(defaults: defaults)
        let snapshot = sampleCodexSnapshot()
        let store = CodexUsageStore(
            provider: ScriptedCodexProvider([.success(snapshot)]),
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )
        let appModel = DockAppModel(
            preferences: preferences,
            codexStore: store
        )

        await appModel.prepareCodexIntegration()

        XCTAssertNil(preferences.codexExecutablePath)
        XCTAssertEqual(store.resolvedExecutablePath, "/usr/bin/true")
        XCTAssertEqual(store.state, .live(snapshot))
    }

    @MainActor
    func testClaudeCodeUsageStoreReportsLiveStaleAndBridgeMissing() async {
        let now = Date(timeIntervalSince1970: 2_000)
        let freshSnapshot = sampleClaudeCodeSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_950)
        )
        let staleSnapshot = sampleClaudeCodeSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 500)
        )
        let bridge = StubClaudeCodeBridge(installed: true)
        let store = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([
                .success(freshSnapshot),
                .success(staleSnapshot)
            ]),
            bridge: bridge,
            pollingInterval: .seconds(60),
            staleAfter: 900,
            now: { now }
        )

        await store.refresh()
        XCTAssertEqual(store.state, .live(freshSnapshot))

        await store.refresh()
        guard case let .stale(snapshot, message) = store.state else {
            return XCTFail("Expected an old Claude Code cache to become stale.")
        }
        XCTAssertEqual(snapshot, staleSnapshot)
        XCTAssertTrue(message.contains("older than 15 minutes"))

        bridge.installed = false
        await store.refresh()
        guard case let .unavailable(message) = store.state else {
            return XCTFail("Expected the disabled bridge to be unavailable.")
        }
        XCTAssertTrue(message.contains("Activate Claude Code in General"))
    }

    @MainActor
    func testClaudeCodeAutomaticSetupInstallsAndRefreshesOnFirstUse() async {
        let suiteName = "DockMagicTests.ClaudeAutoSetup.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = DockPreferencesStore(defaults: defaults)
        let snapshot = sampleClaudeCodeSnapshot()
        let bridge = StubClaudeCodeBridge(installed: false)
        let store = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([.success(snapshot)]),
            bridge: bridge,
            pollingInterval: .seconds(60)
        )
        let appModel = DockAppModel(
            preferences: preferences,
            claudeCodeStore: store
        )

        await appModel.prepareClaudeCodeIntegration()

        XCTAssertTrue(bridge.installed)
        XCTAssertEqual(bridge.installCallCount, 1)
        XCTAssertEqual(store.state, .live(snapshot))

        preferences.automaticallyConfigureClaudeCode = false
        bridge.installed = false
        await appModel.prepareClaudeCodeIntegration()
        XCTAssertEqual(
            bridge.installCallCount,
            1,
            "An explicit opt-out must survive future automatic preparation."
        )
    }

    @MainActor
    func testOpenMeteoProviderBuildsRequestAndParsesForecast() async throws {
        let fetchedAt = Date(timeIntervalSince1970: 2_000)
        let httpClient = FixtureOpenMeteoHTTPClient(
            statusCode: 200,
            data: openMeteoFixture()
        )
        let provider = OpenMeteoWeatherProvider(
            coordinateProvider: FixedWeatherCoordinateProvider(
                coordinate: WeatherCoordinate(latitude: 10.8231, longitude: 106.6297)
            ),
            locationNameProvider: FixedWeatherLocationNameProvider(
                locationName: "Ho Chi Minh City, Vietnam"
            ),
            httpClient: httpClient,
            now: { fetchedAt }
        )

        let snapshot = try await provider.fetchWeather()

        XCTAssertEqual(snapshot.location, "Ho Chi Minh City, Vietnam")
        XCTAssertEqual(snapshot.temperatureCelsius, 29.4, accuracy: 0.001)
        XCTAssertEqual(snapshot.feelsLikeCelsius, 32)
        XCTAssertEqual(snapshot.conditionDescription, "Partly cloudy")
        XCTAssertEqual(snapshot.condition, .partlyCloudy)
        XCTAssertEqual(snapshot.highCelsius, 33)
        XCTAssertEqual(snapshot.lowCelsius, 26)
        XCTAssertEqual(snapshot.precipitationChance, 0.25)
        XCTAssertEqual(snapshot.relativeHumidity, 0.89)
        XCTAssertEqual(snapshot.windSpeedKPH, 12.9)
        XCTAssertEqual(snapshot.forecast.count, 7)
        XCTAssertEqual(snapshot.forecast.first?.condition, .partlyCloudy)
        XCTAssertEqual(snapshot.forecast.last?.condition, .thunderstorm)
        XCTAssertEqual(snapshot.forecast.last?.highCelsius, 34)
        XCTAssertEqual(snapshot.forecast.last?.precipitationChance, 0.75)
        var forecastCalendar = Calendar(identifier: .gregorian)
        forecastCalendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        XCTAssertEqual(
            forecastCalendar.dateComponents(
                [.year, .month, .day],
                from: try XCTUnwrap(snapshot.forecast.last?.date)
            ),
            DateComponents(year: 1970, month: 1, day: 7)
        )
        XCTAssertEqual(snapshot.isDaylight, true)
        XCTAssertEqual(snapshot.observedAt, Date(timeIntervalSince1970: 1_800))
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)

        let recordedRequest = await httpClient.lastRequest
        let request = try XCTUnwrap(recordedRequest)
        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )
        XCTAssertEqual(query["latitude"]!, "10.823100")
        XCTAssertEqual(query["longitude"]!, "106.629700")
        XCTAssertEqual(
            query["current"]!,
            "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
        )
        XCTAssertEqual(
            query["daily"]!,
            "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        )
        XCTAssertEqual(query["wind_speed_unit"]!, "kmh")
        XCTAssertEqual(query["timezone"]!, "auto")
        XCTAssertEqual(query["forecast_days"]!, "7")
        XCTAssertNil(query["apikey"] ?? nil)
        XCTAssertEqual(request.timeoutInterval, 20)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Cache-Control"),
            "no-cache"
        )
    }

    @MainActor
    func testOpenMeteoWeatherDoesNotWaitForSlowLocationName() async throws {
        let provider = OpenMeteoWeatherProvider(
            coordinateProvider: FixedWeatherCoordinateProvider(
                coordinate: WeatherCoordinate(latitude: 10.8231, longitude: 106.6297)
            ),
            locationNameProvider: SlowWeatherLocationNameProvider(),
            httpClient: FixtureOpenMeteoHTTPClient(
                statusCode: 200,
                data: openMeteoFixture()
            ),
            locationNameTimeout: .milliseconds(20),
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        let snapshot = try await provider.fetchWeather()

        XCTAssertEqual(snapshot.location, "Ho Chi Minh")
    }

    @MainActor
    func testOpenMeteoWeatherReacquiresLocationForEveryFetch() async throws {
        let coordinateProvider = CountingWeatherCoordinateProvider(
            coordinate: WeatherCoordinate(latitude: 10.8231, longitude: 106.6297)
        )
        let provider = OpenMeteoWeatherProvider(
            coordinateProvider: coordinateProvider,
            httpClient: FixtureOpenMeteoHTTPClient(
                statusCode: 200,
                data: openMeteoFixture()
            ),
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        _ = try await provider.fetchWeather()
        _ = try await provider.fetchWeather()

        XCTAssertEqual(coordinateProvider.requestCount, 2)
    }

    func testOpenMeteoSnapshotUsesTimezoneAsLocationFallback() throws {
        let response = try JSONDecoder().decode(
            OpenMeteoForecastResponse.self,
            from: openMeteoFixture()
        )

        let snapshot = try OpenMeteoWeatherProvider.makeSnapshot(
            from: response,
            fetchedAt: Date(timeIntervalSince1970: 2_000),
            location: "  "
        )

        XCTAssertEqual(snapshot.location, "Ho Chi Minh")
    }

    func testOpenMeteoRejectsMisalignedDailyForecastArrays() throws {
        let decoded = try JSONDecoder().decode(
            OpenMeteoForecastResponse.self,
            from: openMeteoFixture()
        )
        let response = OpenMeteoForecastResponse(
            utcOffsetSeconds: decoded.utcOffsetSeconds,
            timezone: decoded.timezone,
            current: decoded.current,
            daily: OpenMeteoForecastResponse.Daily(
                time: ["1970-01-01", "1970-01-02"],
                weatherCode: [2],
                temperature2MMax: [33, 32],
                temperature2MMin: [26, 25],
                precipitationProbabilityMax: [25, 60]
            )
        )

        XCTAssertThrowsError(
            try OpenMeteoWeatherProvider.makeSnapshot(
                from: response,
                fetchedAt: Date(timeIntervalSince1970: 2_000)
            )
        ) { error in
            XCTAssertEqual(error as? OpenMeteoWeatherError, .invalidPayload)
        }
    }

    @MainActor
    func testOpenMeteoProviderSupportsCustomerEndpointAuthentication() throws {
        let provider = OpenMeteoWeatherProvider(
            coordinateProvider: FixedWeatherCoordinateProvider(
                coordinate: WeatherCoordinate(latitude: 1, longitude: 2)
            ),
            httpClient: FixtureOpenMeteoHTTPClient(statusCode: 200, data: Data()),
            endpoint: URL(string: "https://customer-api.open-meteo.com/v1/forecast")!,
            apiKey: "test-api-key"
        )

        let request = try provider.makeRequest(
            for: WeatherCoordinate(latitude: 1, longitude: 2)
        )
        let queryItems = URLComponents(
            url: try XCTUnwrap(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(request.url?.host, "customer-api.open-meteo.com")
        XCTAssertEqual(
            queryItems?.first(where: { $0.name == "apikey" })?.value,
            "test-api-key"
        )
    }

    @MainActor
    func testOpenMeteoProviderSurfacesHTTPAndPayloadFailures() async {
        let coordinateProvider = FixedWeatherCoordinateProvider(
            coordinate: WeatherCoordinate(latitude: 10, longitude: 106)
        )
        let httpFailureProvider = OpenMeteoWeatherProvider(
            coordinateProvider: coordinateProvider,
            httpClient: FixtureOpenMeteoHTTPClient(
                statusCode: 429,
                data: Data("{\"reason\":\"Rate limit exceeded\"}".utf8)
            )
        )

        do {
            _ = try await httpFailureProvider.fetchWeather()
            XCTFail("Expected an HTTP failure.")
        } catch {
            XCTAssertEqual(
                error as? OpenMeteoWeatherError,
                .httpFailure(statusCode: 429, reason: "Rate limit exceeded")
            )
        }

        let invalidPayloadProvider = OpenMeteoWeatherProvider(
            coordinateProvider: coordinateProvider,
            httpClient: FixtureOpenMeteoHTTPClient(
                statusCode: 200,
                data: Data("{\"current\":{}}".utf8)
            )
        )
        do {
            _ = try await invalidPayloadProvider.fetchWeather()
            XCTFail("Expected invalid weather data to be rejected.")
        } catch {
            XCTAssertEqual(error as? OpenMeteoWeatherError, .invalidPayload)
        }
    }

    func testWeatherConditionMappingCoversDockVisualFamilies() {
        XCTAssertEqual(
            WeatherCondition.resolve(code: nil, description: "Thunderstorms"),
            .thunderstorm
        )
        XCTAssertEqual(
            WeatherCondition.resolve(code: "partlyCloudy", description: "Clouds"),
            .partlyCloudy
        )
        XCTAssertEqual(
            WeatherCondition.resolve(code: nil, description: "Freezing Rain"),
            .sleet
        )
        XCTAssertEqual(
            WeatherCondition.resolve(code: nil, description: "Mưa rào"),
            .rain
        )
        XCTAssertEqual(
            WeatherCondition.resolve(code: nil, description: "Nhiều mây"),
            .cloudy
        )
        XCTAssertEqual(
            WeatherCondition.resolve(code: nil, description: "Unmapped"),
            .unknown
        )
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: 0).condition, .clear)
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: 48).condition, .fog)
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: 57).condition, .sleet)
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: 82).condition, .rain)
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: 86).condition, .snow)
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: 99).condition, .thunderstorm)
        XCTAssertEqual(OpenMeteoWeatherCode.metadata(for: -1).condition, .unknown)
    }

    @MainActor
    func testWeatherHoverDashboardRendersWeekAndAvailabilityStates() throws {
        let now = Date(timeIntervalSince1970: 1_787_978_800)
        let snapshot = sampleWeatherSnapshot(
            condition: .drizzle,
            conditionDescription: "Light drizzle",
            observedAt: now,
            fetchedAt: now
        )
        let variants: [(
            label: String,
            state: WeatherState,
            mode: DSAppearanceMode,
            appearance: NSAppearance.Name,
            overrides: DSAccessibilityOverrides,
            grayscale: Bool
        )] = [
            ("Live Dark", .live(snapshot), .dark, .darkAqua, .init(), false),
            ("Live Light", .live(snapshot), .light, .aqua, .init(), false),
            (
                "Increased Contrast",
                .live(snapshot),
                .dark,
                .accessibilityHighContrastDarkAqua,
                .init(increaseContrast: true),
                false
            ),
            (
                "Reduced Transparency",
                .live(snapshot),
                .dark,
                .darkAqua,
                .init(reduceTransparency: true),
                false
            ),
            ("Grayscale", .live(snapshot), .dark, .darkAqua, .init(), true),
            (
                "Saved Forecast",
                .stale(snapshot, message: "Network unavailable"),
                .dark,
                .darkAqua,
                .init(),
                false
            ),
            ("Loading", .loading, .dark, .darkAqua, .init(), false),
            (
                "Unavailable",
                .unavailable(message: "Location access denied"),
                .dark,
                .darkAqua,
                .init(),
                false
            )
        ]

        var renderings: [Data] = []
        for variant in variants {
            var view = AnyView(
                DockMagicThemeRoot(
                    content: DockHoverChrome(
                        pointerEdge: .bottom,
                        panelSize: DockHoverPanelPlacement.weatherPanelSize
                    ) {
                        WeatherHoverDashboardView(
                            state: variant.state,
                            locationPlaceholder: "Ho Chi Minh City",
                            now: now
                        )
                    },
                    appearanceMode: variant.mode
                )
                .environment(
                    \.dsAccessibilityOverrides,
                    variant.overrides
                )
            )
            if variant.grayscale {
                view = AnyView(view.grayscale(1))
            }

            let data = try renderPNG(
                of: view,
                size: DockHoverPanelPlacement.weatherPanelSize,
                appearanceName: variant.appearance,
                name: "Weather Hover — \(variant.label)"
            )
            XCTAssertGreaterThan(
                data.count,
                10_000,
                "\(variant.label) should render a non-empty dashboard."
            )
            attachPNG(data, name: "Weather Hover — \(variant.label)")
            renderings.append(data)
        }

        XCTAssertGreaterThanOrEqual(Set(renderings).count, 6)
    }

    @MainActor
    func testWeatherStoreDefaultPollingIntervalIsTenMinutes() {
        XCTAssertEqual(
            WeatherStore.defaultPollingInterval,
            Duration.seconds(10 * 60)
        )
    }

    @MainActor
    func testWeatherStoreAutomaticallyPollsForNewSnapshots() async throws {
        let first = sampleWeatherSnapshot(
            observedAt: Date(timeIntervalSince1970: 1_000),
            fetchedAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = sampleWeatherSnapshot(
            condition: .rain,
            conditionDescription: "Rain",
            observedAt: Date(timeIntervalSince1970: 2_000),
            fetchedAt: Date(timeIntervalSince1970: 2_000)
        )
        let store = WeatherStore(
            provider: ScriptedWeatherProvider([
                .success(first),
                .success(second)
            ]),
            cache: InMemoryWeatherCache(),
            pollingInterval: .milliseconds(20),
            staleAfter: 10_000,
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        store.start()
        defer { store.stop() }

        try await waitUntil { store.state == .live(second) }
        XCTAssertTrue(store.isMonitoring)
    }

    func testWeatherLocationAuthorizationProvidesRecoveryGuidance() {
        XCTAssertTrue(WeatherLocationAuthorization.notDetermined.allowsLocationRequest)
        XCTAssertTrue(WeatherLocationAuthorization.authorized.allowsLocationRequest)
        XCTAssertFalse(WeatherLocationAuthorization.denied.allowsLocationRequest)
        XCTAssertFalse(WeatherLocationAuthorization.restricted.allowsLocationRequest)
        XCTAssertFalse(WeatherLocationAuthorization.servicesDisabled.allowsLocationRequest)
        XCTAssertTrue(
            WeatherLocationAuthorization.denied.errorDescription?
                .contains("System Settings > Privacy & Security > Location Services")
                == true
        )
        XCTAssertTrue(
            WeatherLocationAuthorization.denied.errorDescription?
                .contains("then refresh Weather") == true
        )
    }

    func testHardenedRuntimeIncludesWeatherLocationEntitlement() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementURL = projectDirectory
            .appendingPathComponent("DockMagic/DockMagic.entitlements")
        let data = try Data(contentsOf: entitlementURL)
        let entitlements = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        )

        XCTAssertEqual(
            entitlements["com.apple.security.personal-information.location"]
                as? Bool,
            true
        )
    }

    @MainActor
    func testWeatherLocationPreviewStopsRequestingAfterRefreshEnds() async throws {
        let provider = CancellableWeatherProvider()
        let store = WeatherStore(
            provider: provider,
            authorizationProvider: MutableWeatherAuthorizationProvider(.notDetermined),
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60)
        )

        XCTAssertEqual(store.locationPreviewValue, "Location access required")

        let refreshTask = Task { await store.refresh() }
        try await waitUntil { store.isRefreshing }
        XCTAssertEqual(store.locationPreviewValue, "Requesting access…")

        store.stop()
        await refreshTask.value
        XCTAssertEqual(store.locationPreviewValue, "Location access required")
    }

    @MainActor
    func testWeatherStorePreflightsPermissionAndRefreshesAfterGrant() async {
        let snapshot = sampleWeatherSnapshot()
        let provider = ScriptedWeatherProvider([.success(snapshot)])
        let authorizationProvider = MutableWeatherAuthorizationProvider(.denied)
        let store = WeatherStore(
            provider: provider,
            authorizationProvider: authorizationProvider,
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60)
        )

        XCTAssertEqual(store.locationAuthorization, .denied)
        await store.refresh()

        guard case let .unavailable(message) = store.state else {
            return XCTFail("Expected denied Location access to block Weather.")
        }
        XCTAssertTrue(message.contains("Enable DockMagic"))
        let blockedCallCount = await provider.callCount
        XCTAssertEqual(blockedCallCount, 0)

        authorizationProvider.authorization = .authorized
        await store.refresh()

        XCTAssertEqual(store.locationAuthorization, .authorized)
        XCTAssertEqual(store.state, .live(snapshot))
        let grantedCallCount = await provider.callCount
        XCTAssertEqual(grantedCallCount, 1)
    }

    func testOpenMeteoCacheDoesNotRestoreLegacyShortcutSnapshot() throws {
        let suiteName = "DockMagicTests.WeatherCache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacySnapshot = sampleWeatherSnapshot()
        defaults.set(
            try JSONEncoder().encode(legacySnapshot),
            forKey: "DockMagicWeatherSnapshotCache"
        )

        let cache = UserDefaultsWeatherSnapshotCache(defaults: defaults)
        XCTAssertNil(cache.load())

        cache.save(legacySnapshot)
        XCTAssertEqual(cache.load(), legacySnapshot)
        XCTAssertNotNil(
            defaults.data(forKey: UserDefaultsWeatherSnapshotCache.cacheKey)
        )
    }

    @MainActor
    func testWeatherStoreCachesLiveDataAndFallsBackToStale() async {
        let snapshot = sampleWeatherSnapshot(
            observedAt: Date(timeIntervalSince1970: 10_000),
            fetchedAt: Date(timeIntervalSince1970: 10_000)
        )
        let provider = ScriptedWeatherProvider([
            .success(snapshot),
            .failure(OpenMeteoWeatherError.locationTimedOut)
        ])
        let cache = InMemoryWeatherCache()
        let store = WeatherStore(
            provider: provider,
            cache: cache,
            pollingInterval: .seconds(60),
            staleAfter: 2_700,
            now: { Date(timeIntervalSince1970: 10_100) }
        )

        await store.refresh()
        XCTAssertEqual(store.state, .live(snapshot))
        XCTAssertEqual(cache.snapshot, snapshot)

        await store.refresh()
        guard case let .stale(staleSnapshot, message) = store.state else {
            return XCTFail("Expected the last successful weather to remain visible.")
        }
        XCTAssertEqual(staleSnapshot, snapshot)
        XCTAssertTrue(message.contains("determine your location in time"))
    }

    @MainActor
    func testWeatherStoreRestoresCacheAndMarksOldResultsStale() async {
        let cached = sampleWeatherSnapshot(
            observedAt: Date(timeIntervalSince1970: 1_000),
            fetchedAt: Date(timeIntervalSince1970: 1_000)
        )
        let oldResult = sampleWeatherSnapshot(
            observedAt: Date(timeIntervalSince1970: 2_000),
            fetchedAt: Date(timeIntervalSince1970: 5_000)
        )
        let cache = InMemoryWeatherCache(snapshot: cached)
        let store = WeatherStore(
            provider: ScriptedWeatherProvider([.success(oldResult)]),
            cache: cache,
            pollingInterval: .seconds(60),
            staleAfter: 2_700,
            now: { Date(timeIntervalSince1970: 5_000) }
        )

        XCTAssertEqual(store.state.snapshot, cached)
        await store.refresh()
        guard case let .stale(snapshot, message) = store.state else {
            return XCTFail("Expected old observed weather to be stale.")
        }
        XCTAssertEqual(snapshot, oldResult)
        XCTAssertTrue(message.contains("older than 45 minutes"))
    }

    @MainActor
    func testWeatherStoreDeduplicatesRefreshAndCancelsMonitoring() async throws {
        let snapshot = sampleWeatherSnapshot()
        let provider = DelayedWeatherProvider(snapshot: snapshot)
        let store = WeatherStore(
            provider: provider,
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60)
        )

        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await (first, second)
        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 1)

        let cancellable = CancellableWeatherProvider()
        let monitoredStore = WeatherStore(
            provider: cancellable,
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60)
        )
        monitoredStore.start()
        try await waitUntil { monitoredStore.isRefreshing }
        monitoredStore.stop()
        try await waitUntil { !monitoredStore.isRefreshing }
        XCTAssertFalse(monitoredStore.isMonitoring)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while await cancellable.cancellationCount == 0, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let cancellationCount = await cancellable.cancellationCount
        XCTAssertEqual(cancellationCount, 1)
    }

    @MainActor
    func testAppModelRunsOnlyTheSelectedFeature() async throws {
        let suiteName = "DockMagicTests.AppModel.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = DockPreferencesStore(defaults: defaults)
        let metrics = SystemMetricsStore(
            sampler: CountingMetricsSampler(),
            samplingInterval: .seconds(60)
        )
        let network = NetworkMetricsStore(
            sampler: CountingNetworkSampler(),
            samplingInterval: .seconds(60)
        )
        let storage = StorageMetricsStore(
            sampler: CountingStorageSampler(),
            samplingInterval: .seconds(60)
        )
        let codex = CodexUsageStore(
            provider: ScriptedCodexProvider([.success(sampleCodexSnapshot())]),
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )
        let weather = WeatherStore(
            provider: ScriptedWeatherProvider([.success(sampleWeatherSnapshot())]),
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60)
        )
        let clock = ClockStore(
            initialDate: Date(timeIntervalSince1970: 1_900_000_000),
            updateInterval: .seconds(60)
        )
        let claudeCodeBridge = StubClaudeCodeBridge(installed: false)
        let claudeCode = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([
                .success(sampleClaudeCodeSnapshot())
            ]),
            bridge: claudeCodeBridge,
            pollingInterval: .seconds(60)
        )
        let appModel = DockAppModel(
            preferences: preferences,
            metricsStore: metrics,
            networkStore: network,
            storageStore: storage,
            weatherStore: weather,
            clockStore: clock,
            codexStore: codex,
            claudeCodeStore: claudeCode
        )

        appModel.start()
        XCTAssertTrue(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
        XCTAssertFalse(clock.isMonitoring)
        XCTAssertFalse(codex.isMonitoring)
        XCTAssertFalse(claudeCode.isMonitoring)

        preferences.activeFeature = .dockMagic
        try await waitUntil {
            !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !clock.isMonitoring
                && !codex.isMonitoring
                && !claudeCode.isMonitoring
        }

        preferences.activeFeature = .network
        try await waitUntil {
            network.isMonitoring
                && !metrics.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !clock.isMonitoring
                && !codex.isMonitoring
                && !claudeCode.isMonitoring
        }

        preferences.activeFeature = .storage
        try await waitUntil {
            storage.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !weather.isMonitoring
                && !clock.isMonitoring
                && !codex.isMonitoring
                && !claudeCode.isMonitoring
        }

        preferences.activeFeature = .weather
        try await waitUntil {
            weather.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
        }

        XCTAssertTrue(weather.isMonitoring)
        XCTAssertFalse(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(clock.isMonitoring)
        XCTAssertFalse(codex.isMonitoring)
        XCTAssertFalse(claudeCode.isMonitoring)

        preferences.activeFeature = .clock
        try await waitUntil {
            clock.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !codex.isMonitoring
                && !claudeCode.isMonitoring
        }

        XCTAssertTrue(clock.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)

        preferences.activeFeature = .codex
        try await waitUntil {
            codex.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !clock.isMonitoring
        }

        XCTAssertTrue(codex.isMonitoring)
        XCTAssertFalse(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
        XCTAssertFalse(clock.isMonitoring)
        XCTAssertFalse(claudeCode.isMonitoring)
        try await waitUntil {
            codex.resolvedExecutablePath == "/usr/bin/true"
                && codex.state.snapshot != nil
        }

        preferences.activeFeature = .claudeCode
        try await waitUntil {
            claudeCode.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !clock.isMonitoring
                && !codex.isMonitoring
        }
        try await waitUntil {
            claudeCodeBridge.installed
                && claudeCode.state.snapshot != nil
        }

        XCTAssertTrue(claudeCode.isMonitoring)
        XCTAssertEqual(claudeCodeBridge.installCallCount, 1)
        XCTAssertFalse(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
        XCTAssertFalse(clock.isMonitoring)
        XCTAssertFalse(codex.isMonitoring)

        appModel.stop()
        XCTAssertFalse(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
        XCTAssertFalse(clock.isMonitoring)
        XCTAssertFalse(codex.isMonitoring)
        XCTAssertFalse(claudeCode.isMonitoring)
    }

    @MainActor
    func testAppModelDockPresentationTracksAppearanceAndFeatureImmediately() {
        let appModel = makeAppModel()

        appModel.preferences.activeFeature = .dockMagic
        XCTAssertEqual(appModel.dockPresentation, .dockMagic)

        appModel.preferences.activeFeature = .systemMetrics
        appModel.preferences.setSystemMetricsOuterWidth(0.14)
        guard case let .systemMetrics(_, appearance, _) = appModel.dockPresentation else {
            return XCTFail("Expected the CPU and RAM Dock presentation.")
        }
        XCTAssertEqual(appearance.outerWidth, 0.14)

        appModel.preferences.activeFeature = .network
        appModel.preferences.setNetworkDownloadColor(
            DockColor(red: 0.2, green: 0.4, blue: 0.6)
        )
        guard case let .network(history, appearance, _) = appModel.dockPresentation else {
            return XCTFail("Expected the Network Dock presentation.")
        }
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(appearance.downloadColor.hex, "#336699")

        appModel.preferences.activeFeature = .storage
        appModel.preferences.setStorageWidth(0.20)
        guard case let .storage(snapshot, appearance, _) = appModel.dockPresentation else {
            return XCTFail("Expected the Storage Dock presentation.")
        }
        XCTAssertEqual(snapshot, .zero)
        XCTAssertEqual(appearance.width, 0.20)

        appModel.preferences.activeFeature = .weather
        guard case let .weather(state) = appModel.dockPresentation else {
            return XCTFail("Expected the Weather Dock presentation.")
        }
        XCTAssertEqual(state, .idle)

        appModel.preferences.setClockDisplayStyle(.splitFlap)
        appModel.preferences.setClockFollowsSystemTimeZone(false)
        appModel.preferences.setClockTimeZoneIdentifier("Asia/Ho_Chi_Minh")
        appModel.preferences.activeFeature = .clock
        guard case let .clock(date, configuration) = appModel.dockPresentation else {
            return XCTFail("Expected the Clock Dock presentation.")
        }
        XCTAssertEqual(configuration.displayStyle, .splitFlap)
        XCTAssertFalse(configuration.followsSystemTimeZone)
        XCTAssertEqual(configuration.timeZoneIdentifier, "Asia/Ho_Chi_Minh")
        XCTAssertEqual(
            date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60),
            0,
            accuracy: 0.000_001
        )

        appModel.preferences.activeFeature = .codex
        guard case let .codex(state, codexAppearance) = appModel.dockPresentation else {
            return XCTFail("Expected the Codex Dock presentation.")
        }
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(
            codexAppearance,
            DockFeatureDefaults.codexAppearance
        )

        appModel.preferences.activeFeature = .claudeCode
        guard case let .claudeCode(state, appearance) = appModel.dockPresentation else {
            return XCTFail("Expected the Claude Code Dock presentation.")
        }
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(appearance, DockFeatureDefaults.claudeCodeAppearance)
    }

    func testNetworkRatesUseCounterDeltasAndElapsedTime() {
        let previous = NetworkInterfaceCounters(
            interfaceName: "en0",
            receivedBytes: 1_000,
            sentBytes: 2_000
        )
        let current = NetworkInterfaceCounters(
            interfaceName: "en0",
            receivedBytes: 5_000,
            sentBytes: 3_000
        )

        let rates = NetworkMetricsCalculation.rates(
            previous: previous,
            current: current,
            elapsed: 2
        )

        XCTAssertEqual(rates.download, 2_000)
        XCTAssertEqual(rates.upload, 500)
    }

    func testNetworkRatesResetForInitialInterfaceChangeRollbackAndBadTime() {
        let baseline = NetworkInterfaceCounters(
            interfaceName: "en0",
            receivedBytes: 1_000,
            sentBytes: 1_000
        )
        let valid = NetworkInterfaceCounters(
            interfaceName: "en0",
            receivedBytes: 2_000,
            sentBytes: 2_000
        )
        let changedInterface = NetworkInterfaceCounters(
            interfaceName: "en1",
            receivedBytes: 2_000,
            sentBytes: 2_000
        )
        let rolledBack = NetworkInterfaceCounters(
            interfaceName: "en0",
            receivedBytes: 500,
            sentBytes: 500
        )

        XCTAssertEqual(
            NetworkMetricsCalculation.rates(
                previous: nil,
                current: valid,
                elapsed: 1
            ).download,
            0
        )
        XCTAssertEqual(
            NetworkMetricsCalculation.rates(
                previous: baseline,
                current: changedInterface,
                elapsed: 1
            ).upload,
            0
        )
        XCTAssertEqual(
            NetworkMetricsCalculation.rates(
                previous: baseline,
                current: rolledBack,
                elapsed: 1
            ).download,
            0
        )
        XCTAssertEqual(
            NetworkMetricsCalculation.rates(
                previous: baseline,
                current: valid,
                elapsed: 0
            ).upload,
            0
        )
    }

    func testNetworkSamplerMaintainsBaselineAndResetsCleanly() async throws {
        let reader = SequenceNetworkCounterReader([
            .init(interfaceName: "en0", receivedBytes: 100, sentBytes: 200),
            .init(interfaceName: "en0", receivedBytes: 2_100, sentBytes: 1_200),
            .init(interfaceName: "en0", receivedBytes: 3_100, sentBytes: 2_200)
        ])
        let dates = LockedDateSequence([
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 12),
            Date(timeIntervalSince1970: 13)
        ])
        let sampler = NetworkMetricsSampler(
            reader: reader,
            now: { dates.next() }
        )

        let initial = try await sampler.sample()
        XCTAssertEqual(initial.downloadBytesPerSecond, 0)
        XCTAssertEqual(initial.uploadBytesPerSecond, 0)

        let delta = try await sampler.sample()
        XCTAssertEqual(delta.downloadBytesPerSecond, 1_000)
        XCTAssertEqual(delta.uploadBytesPerSecond, 500)

        await sampler.reset()
        let reset = try await sampler.sample()
        XCTAssertEqual(reset.downloadBytesPerSecond, 0)
        XCTAssertEqual(reset.uploadBytesPerSecond, 0)
    }

    func testNetworkChartScaleIsSharedQuantizedAndExpandsForLargePeaks() {
        let samples = [
            NetworkMetricsSnapshot(
                interfaceName: "en0",
                downloadBytesPerSecond: 70 * 1_024,
                uploadBytesPerSecond: 900 * 1_024
            )
        ]
        XCTAssertEqual(NetworkChartScale.ceiling(for: samples), 1_024 * 1_024)

        let large = [
            NetworkMetricsSnapshot(
                interfaceName: "en0",
                downloadBytesPerSecond: 1_500 * 1_024 * 1_024,
                uploadBytesPerSecond: 1
            )
        ]
        XCTAssertEqual(
            NetworkChartScale.ceiling(for: large),
            2_048 * 1_024 * 1_024
        )
    }

    func testNetworkAndStorageSnapshotsNormalizeRendererInputs() {
        let network = NetworkMetricsSnapshot(
            interfaceName: "en0",
            downloadBytesPerSecond: -.infinity,
            uploadBytesPerSecond: -1
        )
        XCTAssertEqual(network.downloadBytesPerSecond, 0)
        XCTAssertEqual(network.uploadBytesPerSecond, 0)

        let storage = StorageMetricsSnapshot(
            volumeName: "",
            totalBytes: 1_000,
            availableBytes: 2_000
        )
        XCTAssertEqual(storage.volumeName, "Startup Disk")
        XCTAssertEqual(storage.availableBytes, 1_000)
        XCTAssertEqual(storage.usedBytes, 0)
        XCTAssertEqual(storage.usage, 0)
    }

    func testNetworkAndStorageSamplersReadCurrentHost() async throws {
        let reader = DarwinNetworkCounterReader()
        do {
            let counters = try await reader.readCounters()
            XCTAssertFalse(counters.interfaceName.isEmpty)

            let sampler = NetworkMetricsSampler(reader: reader)
            let first = try await sampler.sample()
            try await Task.sleep(for: .milliseconds(50))
            let second = try await sampler.sample()
            XCTAssertEqual(first.interfaceName, counters.interfaceName)
            XCTAssertEqual(second.interfaceName, counters.interfaceName)
            XCTAssertGreaterThanOrEqual(second.downloadBytesPerSecond, 0)
            XCTAssertGreaterThanOrEqual(second.uploadBytesPerSecond, 0)
        } catch NetworkMetricsSamplingError.primaryInterfaceUnavailable {
            throw XCTSkip("The host has no primary network interface.")
        }

        let storage = try await StorageMetricsSampler().sample()
        XCTAssertFalse(storage.volumeName.isEmpty)
        XCTAssertGreaterThan(storage.totalBytes, 0)
        XCTAssertLessThanOrEqual(storage.availableBytes, storage.totalBytes)
        XCTAssertTrue((0...1).contains(storage.usage))
    }

    @MainActor
    func testNetworkStoreKeepsBoundedHistoryAndStopsSampling() async throws {
        let sampler = CountingNetworkSampler()
        let store = NetworkMetricsStore(
            sampler: sampler,
            samplingInterval: .milliseconds(10),
            historyLimit: 3
        )

        store.start()
        store.start()
        try await waitUntil { store.history.count == 3 }
        XCTAssertTrue(store.isMonitoring)
        XCTAssertEqual(store.history.count, 3)

        store.stop()
        let countAfterStop = await sampler.callCount
        try await Task.sleep(for: .milliseconds(40))
        let finalCount = await sampler.callCount
        let resetCallCount = await sampler.resetCallCount
        XCTAssertEqual(finalCount, countAfterStop)
        XCTAssertFalse(store.isMonitoring)
        XCTAssertEqual(resetCallCount, 1)
    }

    @MainActor
    func testStorageStoreSamplesAndStopsCleanly() async throws {
        let sampler = CountingStorageSampler()
        let store = StorageMetricsStore(
            sampler: sampler,
            samplingInterval: .milliseconds(10)
        )

        store.start()
        store.start()
        try await waitUntil { store.current.totalBytes > 0 }
        XCTAssertTrue(store.isMonitoring)

        store.stop()
        let countAfterStop = await sampler.callCount
        try await Task.sleep(for: .milliseconds(40))
        let finalCount = await sampler.callCount
        XCTAssertEqual(finalCount, countAfterStop)
        XCTAssertFalse(store.isMonitoring)
    }

    func testCPUUtilizationUsesTickDeltas() {
        let previous = CPUTicks(user: 100, system: 50, idle: 200, nice: 10)
        let current = CPUTicks(user: 110, system: 70, idle: 265, nice: 15)

        XCTAssertEqual(
            SystemMetricsCalculation.cpuUtilization(
                previous: previous,
                current: current
            ),
            0.35,
            accuracy: 0.000_001
        )
    }

    func testCPUCalculationHandlesInitialResetAndZeroDelta() {
        let ticks = CPUTicks(user: 100, system: 100, idle: 100, nice: 100)
        XCTAssertEqual(
            SystemMetricsCalculation.cpuUtilization(previous: nil, current: ticks),
            0
        )
        XCTAssertEqual(
            SystemMetricsCalculation.cpuUtilization(previous: ticks, current: ticks),
            0
        )
        XCTAssertEqual(
            SystemMetricsCalculation.cpuUtilization(
                previous: ticks,
                current: CPUTicks(user: 1, system: 110, idle: 110, nice: 110)
            ),
            0
        )
    }

    func testMemoryCalculationUsesAndClampsHostPages() {
        let usage = SystemMetricsCalculation.memoryUsage(
            activePages: 40,
            wiredPages: 20,
            compressedPages: 10,
            pageSize: 10,
            physicalMemory: 1_000
        )
        XCTAssertEqual(usage.usedBytes, 700)
        XCTAssertEqual(usage.utilization, 0.7, accuracy: 0.000_001)

        let clamped = SystemMetricsCalculation.memoryUsage(
            activePages: 80,
            wiredPages: 40,
            compressedPages: 20,
            pageSize: 10,
            physicalMemory: 1_000
        )
        XCTAssertEqual(clamped.usedBytes, 1_000)
        XCTAssertEqual(clamped.utilization, 1)
    }

    func testSystemMetricsSamplerReadsCurrentHost() async throws {
        let sampler = SystemMetricsSampler()
        let first = try await sampler.sample()
        try await Task.sleep(for: .milliseconds(50))
        let second = try await sampler.sample()

        for snapshot in [first, second] {
            XCTAssertTrue((0...1).contains(snapshot.cpuUsage))
            XCTAssertTrue((0...1).contains(snapshot.memoryUsage))
            XCTAssertGreaterThan(snapshot.memoryTotalBytes, 0)
            XCTAssertLessThanOrEqual(
                snapshot.memoryUsedBytes,
                snapshot.memoryTotalBytes
            )
        }
    }

    func testSnapshotNormalizesRendererValues() {
        let snapshot = SystemMetricsSnapshot(
            cpuUsage: 1.5,
            memoryUsage: -.infinity,
            memoryUsedBytes: 2_000,
            memoryTotalBytes: 1_000
        )

        XCTAssertEqual(snapshot.cpuUsage, 1)
        XCTAssertEqual(snapshot.memoryUsage, 0)
        XCTAssertEqual(snapshot.memoryUsedBytes, 1_000)
    }

    @MainActor
    func testSystemMetricsStoreKeepsBoundedHistoryAndCancels() async throws {
        let sampler = CountingMetricsSampler()
        let store = SystemMetricsStore(
            sampler: sampler,
            processSampler: CountingProcessSampler(),
            samplingInterval: .milliseconds(20),
            historyLimit: 3
        )

        store.start()
        store.start()
        try await waitUntil {
            store.history.count >= 2
        }
        XCTAssertTrue(store.isMonitoring)

        store.stop()
        let countAfterStop = await sampler.callCount
        try await Task.sleep(for: .milliseconds(60))
        let finalCount = await sampler.callCount
        XCTAssertEqual(finalCount, countAfterStop)
        XCTAssertLessThanOrEqual(store.history.count, 3)
    }

    @MainActor
    func testDockTileControllerPublishesHiDPIIconAndRedrawsConfiguration() {
        let appearanceDefaults = makeAppearanceDefaults(.light)
        let dockTile = SpyDockTile()
        let application = SpyApplicationIconDisplay()
        let initial = DockTilePresentation.systemMetrics(
            snapshot: .zero,
            appearance: DockFeatureDefaults.systemMetricsAppearance,
            errorDescription: nil
        )
        let controller = DockTileController(
            dockTile: dockTile,
            application: application,
            initialPresentation: initial,
            appearanceStore: appearanceDefaults
        )

        XCTAssertNil(dockTile.contentView)
        XCTAssertEqual(controller.currentAppearanceMode, .light)
        XCTAssertEqual(dockTile.displayCallCount, 1)
        assertHighResolutionApplicationIcon(application.applicationIconImage)

        var appearance = DockFeatureDefaults.systemMetricsAppearance
        appearance.setOuterWidth(0.14)
        let updated = DockTilePresentation.systemMetrics(
            snapshot: SystemMetricsSnapshot(
                cpuUsage: 0.7,
                memoryUsage: 0.5,
                memoryUsedBytes: 500,
                memoryTotalBytes: 1_000
            ),
            appearance: appearance,
            errorDescription: nil
        )
        controller.update(presentation: updated)

        XCTAssertEqual(controller.currentPresentation, updated)
        XCTAssertEqual(dockTile.displayCallCount, 2)
        assertHighResolutionApplicationIcon(application.applicationIconImage)

        controller.update(presentation: updated)
        XCTAssertEqual(dockTile.displayCallCount, 2)

        appearanceDefaults.set(
            DSAppearanceMode.dark.rawValue,
            forKey: DSAppearanceMode.storageKey
        )
        controller.updateAppearance()
        XCTAssertEqual(dockTile.displayCallCount, 3)
        XCTAssertEqual(controller.currentPresentation, updated)
        XCTAssertEqual(controller.currentAppearanceMode, .dark)
        assertHighResolutionApplicationIcon(application.applicationIconImage)
    }

    func testClockAnimationTimelineProducesBoundedStyleSpecificFrames() {
        let previousDate = Date(timeIntervalSince1970: 1_777_777_680)
        let timeline = DockClockAnimationTimeline(
            digitalFrameCount: 3,
            splitFlapFrameCount: 5,
            frameInterval: .zero
        )

        XCTAssertTrue(
            timeline.transitions(
                previousDate: previousDate,
                style: .analog
            ).isEmpty
        )

        let digital = timeline.transitions(
            previousDate: previousDate,
            style: .digital
        )
        XCTAssertEqual(digital.count, 3)
        XCTAssertEqual(digital.map(\.previousDate), Array(repeating: previousDate, count: 3))
        XCTAssertEqual(digital[0].progress, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(digital[1].progress, 2.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(digital[2].progress, 1, accuracy: 0.000_001)

        let splitFlap = timeline.transitions(
            previousDate: previousDate,
            style: .splitFlap
        )
        XCTAssertEqual(splitFlap.count, 5)
        XCTAssertEqual(splitFlap.first?.progress, 0.2)
        XCTAssertEqual(splitFlap.last?.progress, 1)

        XCTAssertEqual(
            DockClockTransition(previousDate: previousDate, progress: -1).progress,
            0
        )
        XCTAssertEqual(
            DockClockTransition(previousDate: previousDate, progress: 2).progress,
            1
        )
    }

    @MainActor
    func testDockTileControllerAnimatesClockMinuteChangesAndHonorsReduceMotion() async throws {
        let previousDate = Date(timeIntervalSince1970: 1_777_777_680)
        let digitalConfiguration = DockClockConfiguration(
            displayStyle: .digital,
            followsSystemTimeZone: false,
            timeZoneIdentifier: "UTC"
        )
        let splitFlapConfiguration = DockClockConfiguration(
            displayStyle: .splitFlap,
            followsSystemTimeZone: false,
            timeZoneIdentifier: "UTC"
        )
        let timeline = DockClockAnimationTimeline(
            digitalFrameCount: 3,
            splitFlapFrameCount: 4,
            frameInterval: .zero
        )
        let renderer = SpyDockApplicationIconRenderer()
        let dockTile = SpyDockTile()
        let controller = DockTileController(
            dockTile: dockTile,
            application: SpyApplicationIconDisplay(),
            initialPresentation: .clock(
                date: previousDate,
                configuration: digitalConfiguration
            ),
            appearanceStore: makeAppearanceDefaults(.light),
            iconRenderer: renderer,
            clockAnimationTimeline: timeline,
            reduceMotionProvider: { false }
        )

        XCTAssertEqual(renderer.clockTransitions.count, 1)
        XCTAssertNil(renderer.clockTransitions[0])

        controller.update(
            presentation: .clock(
                date: previousDate.addingTimeInterval(60),
                configuration: digitalConfiguration
            )
        )
        XCTAssertTrue(controller.isAnimatingClock)
        try await waitUntil { !controller.isAnimatingClock }

        let digitalFrames = renderer.clockTransitions
            .dropFirst()
            .compactMap { $0 }
        XCTAssertEqual(digitalFrames.map(\.progress), [1.0 / 3.0, 2.0 / 3.0, 1])
        XCTAssertEqual(dockTile.displayCallCount, 4)

        controller.update(
            presentation: .clock(
                date: previousDate.addingTimeInterval(60),
                configuration: splitFlapConfiguration
            )
        )
        XCTAssertFalse(controller.isAnimatingClock)
        XCTAssertNil(renderer.clockTransitions.last!)

        let splitFlapStart = renderer.clockTransitions.count
        controller.update(
            presentation: .clock(
                date: previousDate.addingTimeInterval(120),
                configuration: splitFlapConfiguration
            )
        )
        try await waitUntil { !controller.isAnimatingClock }
        let splitFlapFrames = renderer.clockTransitions
            .dropFirst(splitFlapStart)
            .compactMap { $0 }
        XCTAssertEqual(splitFlapFrames.map(\.progress), [0.25, 0.5, 0.75, 1])

        let reducedRenderer = SpyDockApplicationIconRenderer()
        let reducedController = DockTileController(
            dockTile: SpyDockTile(),
            application: SpyApplicationIconDisplay(),
            initialPresentation: .clock(
                date: previousDate,
                configuration: digitalConfiguration
            ),
            appearanceStore: makeAppearanceDefaults(.light),
            iconRenderer: reducedRenderer,
            clockAnimationTimeline: timeline,
            reduceMotionProvider: { true }
        )
        reducedController.update(
            presentation: .clock(
                date: previousDate.addingTimeInterval(60),
                configuration: digitalConfiguration
            )
        )

        XCTAssertFalse(reducedController.isAnimatingClock)
        XCTAssertEqual(reducedRenderer.clockTransitions.count, 2)
        XCTAssertNil(reducedRenderer.clockTransitions.last!)

        let cancellableRenderer = SpyDockApplicationIconRenderer()
        let cancellableController = DockTileController(
            dockTile: SpyDockTile(),
            application: SpyApplicationIconDisplay(),
            initialPresentation: .clock(
                date: previousDate,
                configuration: digitalConfiguration
            ),
            appearanceStore: makeAppearanceDefaults(.light),
            iconRenderer: cancellableRenderer,
            clockAnimationTimeline: DockClockAnimationTimeline(
                digitalFrameCount: 3,
                splitFlapFrameCount: 3,
                frameInterval: .seconds(30)
            ),
            reduceMotionProvider: { false }
        )
        cancellableController.update(
            presentation: .clock(
                date: previousDate.addingTimeInterval(60),
                configuration: digitalConfiguration
            )
        )
        XCTAssertTrue(cancellableController.isAnimatingClock)
        cancellableController.update(presentation: .dockMagic)
        XCTAssertFalse(cancellableController.isAnimatingClock)
        XCTAssertNil(cancellableRenderer.clockTransitions.last!)
    }

    private func assertHighResolutionApplicationIcon(
        _ image: NSImage?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let image else {
            return XCTFail(
                "Expected a rendered application icon.",
                file: file,
                line: line
            )
        }

        XCTAssertTrue(
            DockIconRenderingRules.satisfiesSourceContract(image),
            "The application icon must be 512 pt with a 1024 px source raster.",
            file: file,
            line: line
        )
    }

    @MainActor
    func testEveryDockPresentationUsesCanonicalCommandTabRendering() {
        var numericSystemAppearance = DockFeatureDefaults.systemMetricsAppearance
        numericSystemAppearance.setDisplayStyle(.numeric)
        var numericStorageAppearance = DockFeatureDefaults.storageAppearance
        numericStorageAppearance.setDisplayStyle(.numeric)
        var numericGitHubAppearance = DockFeatureDefaults.githubAppearance
        numericGitHubAppearance.setDisplayStyle(.numeric)
        var numericCodexAppearance = DockFeatureDefaults.codexAppearance
        numericCodexAppearance.setDisplayStyle(.numeric)
        var numericClaudeAppearance = DockFeatureDefaults.claudeCodeAppearance
        numericClaudeAppearance.setDisplayStyle(.numeric)

        let systemSnapshot = SystemMetricsSnapshot(
            cpuUsage: 0.72,
            memoryUsage: 0.54,
            memoryUsedBytes: 540,
            memoryTotalBytes: 1_000
        )
        let storageSnapshot = StorageMetricsSnapshot(
            volumeName: "Macintosh HD",
            totalBytes: 1_000,
            availableBytes: 360
        )
        let batterySnapshot = BatteryMetricsSnapshot(
            devices: [
                BatteryDeviceSnapshot(
                    id: "mac",
                    name: "MacBook",
                    kind: .macBook,
                    level: 0.76,
                    isExternalPowerConnected: true
                ),
                BatteryDeviceSnapshot(
                    id: "mouse",
                    name: "Magic Mouse",
                    kind: .magicMouse,
                    level: 0.43
                )
            ]
        )
        let searchSnapshot = SearchConsoleSnapshot(
            property: "sc-domain:dockmagic.app",
            range: .last7Days,
            points: (0..<7).map { index in
                SearchConsoleDataPoint(
                    key: "2026-08-\(index + 1)",
                    date: Date(timeIntervalSince1970: TimeInterval(index * 86_400)),
                    clicks: Double(24 + index * 3),
                    impressions: Double(280 + index * 31)
                )
            },
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000),
            firstIncompleteDate: nil
        )
        var searchChartConfiguration = SearchConsoleConfiguration.defaultValue
        searchChartConfiguration.displayMode = .chart
        var searchNumbersConfiguration = SearchConsoleConfiguration.defaultValue
        searchNumbersConfiguration.displayMode = .numbers
        var searchFocusConfiguration = SearchConsoleConfiguration.defaultValue
        searchFocusConfiguration.displayMode = .focus

        let presentations: [(String, DockTilePresentation)] = [
            ("DockMagic", .dockMagic),
            (
                "System chart",
                .systemMetrics(
                    snapshot: systemSnapshot,
                    appearance: DockFeatureDefaults.systemMetricsAppearance,
                    errorDescription: nil
                )
            ),
            (
                "System numeric",
                .systemMetrics(
                    snapshot: systemSnapshot,
                    appearance: numericSystemAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Network",
                .network(
                    history: sampleNetworkHistory(),
                    appearance: DockFeatureDefaults.networkAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Storage chart",
                .storage(
                    snapshot: storageSnapshot,
                    appearance: DockFeatureDefaults.storageAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Storage numeric",
                .storage(
                    snapshot: storageSnapshot,
                    appearance: numericStorageAppearance,
                    errorDescription: nil
                )
            ),
            ("Weather", .weather(state: .live(sampleWeatherSnapshot()))),
            (
                "Clock analog",
                .clock(
                    date: Date(timeIntervalSince1970: 1_777_777_745),
                    configuration: DockClockConfiguration(
                        displayStyle: .analog,
                        followsSystemTimeZone: false,
                        timeZoneIdentifier: "Asia/Ho_Chi_Minh"
                    )
                )
            ),
            (
                "Clock digital",
                .clock(
                    date: Date(timeIntervalSince1970: 1_777_777_740),
                    configuration: DockClockConfiguration(
                        displayStyle: .digital,
                        followsSystemTimeZone: false,
                        timeZoneIdentifier: "Asia/Ho_Chi_Minh"
                    )
                )
            ),
            (
                "Clock split-flap",
                .clock(
                    date: Date(timeIntervalSince1970: 1_777_777_740),
                    configuration: DockClockConfiguration(
                        displayStyle: .splitFlap,
                        followsSystemTimeZone: false,
                        timeZoneIdentifier: "Asia/Ho_Chi_Minh"
                    )
                )
            ),
            (
                "Batteries",
                .batteries(snapshot: batterySnapshot, errorDescription: nil)
            ),
            (
                "GitHub chart",
                .github(
                    history: GitHubRepositorySnapshot.designPreviewHistory,
                    appearance: DockFeatureDefaults.githubAppearance,
                    errorDescription: nil
                )
            ),
            (
                "GitHub numeric",
                .github(
                    history: GitHubRepositorySnapshot.designPreviewHistory,
                    appearance: numericGitHubAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Codex chart",
                .codex(
                    state: .live(sampleCodexSnapshot()),
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex numeric",
                .codex(
                    state: .live(sampleCodexSnapshot()),
                    appearance: numericCodexAppearance
                )
            ),
            (
                "Claude chart",
                .claudeCode(
                    state: .live(sampleClaudeCodeSnapshot()),
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude numeric",
                .claudeCode(
                    state: .live(sampleClaudeCodeSnapshot()),
                    appearance: numericClaudeAppearance
                )
            ),
            (
                "Search Console chart",
                .searchConsole(
                    state: .live(searchSnapshot),
                    configuration: searchChartConfiguration
                )
            ),
            (
                "Search Console numbers",
                .searchConsole(
                    state: .live(searchSnapshot),
                    configuration: searchNumbersConfiguration
                )
            ),
            (
                "Search Console focus",
                .searchConsole(
                    state: .live(searchSnapshot),
                    configuration: searchFocusConfiguration
                )
            )
        ]
        let renderer = DockApplicationIconRenderer()

        for (name, presentation) in presentations {
            guard let image = renderer.render(
                presentation: presentation,
                appearanceMode: .dark
            ) else {
                XCTFail("\(name) failed to render an application icon.")
                continue
            }

            XCTAssertTrue(
                DockIconRenderingRules.satisfiesSourceContract(image),
                "\(name) violated the Command-Tab source contract."
            )
        }
    }

    @MainActor
    func testRealNSApplicationPreservesInstalledCommandTabResolution() {
        let renderer = DockApplicationIconRenderer()
        guard let source = renderer.render(
            presentation: .dockMagic,
            appearanceMode: .dark
        ) else {
            return XCTFail("Expected DockMagic to render an application icon.")
        }

        let application = NSApplication.shared
        let originalIcon = application.applicationIconImage
        defer { application.applicationIconImage = originalIcon }

        application.applicationIconImage = source
        guard let installedIcon = application.applicationIconImage else {
            return XCTFail("AppKit did not retain the installed application icon.")
        }

        let backingScale = NSScreen.screens
            .map(\.backingScaleFactor)
            .max() ?? 1
        XCTAssertTrue(
            DockIconRenderingRules.satisfiesInstalledContract(
                installedIcon,
                backingScale: backingScale
            ),
            "AppKit reduced the installed Command-Tab icon below the active display scale."
        )
    }

    func testFullTileDockMagicLogoMeetsRasterAssetRule() {
        guard let logo = NSImage(named: "DockMagicLogo") else {
            return XCTFail("DockMagicLogo is missing from the asset catalog.")
        }

        XCTAssertGreaterThanOrEqual(
            DockIconRenderingRules.maximumPixelDimension(of: logo),
            DockIconRenderingRules.rasterPixelDimension,
            "A full-tile raster asset must supply at least 1024 pixels."
        )
    }

    func testSigmaAppearanceModesAndFoundationContracts() {
        XCTAssertEqual(
            DSAppearanceMode.allCases,
            [.system, .light, .dark]
        )
        XCTAssertEqual(
            DSAppearanceMode.settingsCases,
            [.system, .light, .dark]
        )
        XCTAssertNil(DSAppearanceMode.system.preferredColorScheme)
        XCTAssertEqual(DSAppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(DSAppearanceMode.dark.preferredColorScheme, .dark)
        XCTAssertTrue(DSAppearanceMode.system.usesGlassMaterials)
        XCTAssertTrue(DSAppearanceMode.light.usesGlassMaterials)
        XCTAssertTrue(DSAppearanceMode.dark.usesGlassMaterials)
        XCTAssertEqual(DockDisplayStyle.allCases, [.chart, .numeric])

        XCTAssertFalse(DSSurfaceKind.shell.isGlassEligible)
        XCTAssertFalse(DSSurfaceKind.panel.isGlassEligible)
        XCTAssertFalse(DSSurfaceKind.raised.isGlassEligible)
        XCTAssertFalse(DSSurfaceKind.inset.isGlassEligible)
        XCTAssertTrue(DSSurfaceKind.chrome.isGlassEligible)

        XCTAssertEqual(
            DSRadius.concentric(
                parentRadius: DSRadius.largePanel,
                padding: DSSpacing.small
            ),
            DSRadius.fixedLarge
        )
        XCTAssertEqual(
            DSRadius.concentric(parentRadius: 4, padding: 8),
            0
        )
        XCTAssertGreaterThan(DSElevation.primary.radius, DSElevation.secondary.radius)
        XCTAssertGreaterThan(DSElevation.primary.yOffset, DSElevation.secondary.yOffset)
        XCTAssertGreaterThanOrEqual(DSLayout.minimumWindowWidth, 900)
        XCTAssertGreaterThanOrEqual(DSLayout.minimumWindowHeight, 620)
    }

    func testSigmaAppearancePreferencePersistsAndInvalidValuesFallBackSafely() {
        let suiteName = "DockMagicTests.Appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(DSAppearanceMode.stored(in: defaults), .system)

        defaults.set(
            DSAppearanceMode.dark.rawValue,
            forKey: DSAppearanceMode.storageKey
        )
        XCTAssertEqual(DSAppearanceMode.stored(in: defaults), .dark)

        defaults.set("unsupported-mode", forKey: DSAppearanceMode.storageKey)
        XCTAssertEqual(DSAppearanceMode.stored(in: defaults), .system)

        defaults.set("liquidGlass", forKey: DSAppearanceMode.storageKey)
        XCTAssertEqual(
            DSAppearanceMode.stored(in: defaults),
            .system,
            "The former standalone Liquid Glass mode should migrate to System."
        )
    }

    @MainActor
    func testSigmaPublicPaletteAssetsMatchDocumentedValues() {
        let expected: [
            (name: String, light: String, dark: String, lightAlpha: CGFloat, darkAlpha: CGFloat)
        ] = [
            ("DSAction", "#0088FF", "#0091FF", 1, 1),
            ("DSDanger", "#FF383C", "#FF4245", 1, 1),
            ("DSWarning", "#FF8D28", "#FF9230", 1, 1),
            ("DSInformation", "#00C0E8", "#3CD3FE", 1, 1),
            ("DSProcessing", "#00C8B3", "#00DAC3", 1, 1),
            ("DSOpaqueSurface", "#F5F4F2", "#1F1E1E", 1, 1),
            ("DSOpaqueSurfaceRaised", "#FFFFFF", "#1F1E1E", 1, 1)
        ]

        for item in expected {
            assertColorAsset(
                item.name,
                appearanceName: .aqua,
                expectedHex: item.light,
                expectedAlpha: item.lightAlpha
            )
            assertColorAsset(
                item.name,
                appearanceName: .darkAqua,
                expectedHex: item.dark,
                expectedAlpha: item.darkAlpha
            )
        }
    }

    @MainActor
    func testSigmaSemanticColorPairsMeetAccessibleContrastInLightAndDark() {
        let appearances: [(NSAppearance.Name, String)] = [
            (.aqua, "Light"),
            (.darkAqua, "Dark")
        ]
        let contentSurfaces = [
            "DSOpaqueSurface",
            "DSOpaqueSurfaceRaised",
            "DSOpaqueSurfaceInset",
            "DSOpaqueSurfaceChrome"
        ]
        let contentForegrounds = [
            "DSTextPrimary",
            "DSTextSecondary",
            "DSTextTertiary",
            "DSActionForeground",
            "DSInformationForeground",
            "DSProcessingForeground",
            "DSWarningForeground",
            "DSDangerForeground"
        ]
        let filledPairs = [
            ("DSOnAction", "DSAction"),
            ("DSOnInformation", "DSInformation"),
            ("DSOnProcessing", "DSProcessing"),
            ("DSOnWarning", "DSWarning"),
            ("DSOnDanger", "DSDanger"),
            ("DSOnSidebarIcon", "DSSidebarIconFill")
        ]

        for (appearanceName, appearanceLabel) in appearances {
            guard let appearance = NSAppearance(named: appearanceName) else {
                XCTFail("Unable to create \(appearanceLabel) appearance.")
                continue
            }

            appearance.performAsCurrentDrawingAppearance {
                for foregroundName in contentForegrounds {
                    for backgroundName in contentSurfaces {
                        assertContrast(
                            foregroundName,
                            on: backgroundName,
                            minimum: 4.5,
                            appearance: appearanceLabel
                        )
                    }
                }

                for backgroundName in contentSurfaces {
                    assertContrast(
                        "DSOutlineStrong",
                        on: backgroundName,
                        minimum: 3,
                        appearance: "\(appearanceLabel) strong boundary"
                    )
                    assertContrast(
                        "DSFocus",
                        on: backgroundName,
                        minimum: 3,
                        appearance: "\(appearanceLabel) focus"
                    )
                }

                for (foregroundName, backgroundName) in filledPairs {
                    assertContrast(
                        foregroundName,
                        on: backgroundName,
                        minimum: 4.5,
                        appearance: appearanceLabel
                    )
                }

                for backgroundName in [
                    "DSDockBackgroundRaised",
                    "DSDockBackgroundInset"
                ] {
                    assertContrast(
                        "DSDockForeground",
                        on: backgroundName,
                        minimum: 4.5,
                        appearance: "\(appearanceLabel) Dock foreground"
                    )
                    assertContrast(
                        "DSDockTrack",
                        on: backgroundName,
                        minimum: 3,
                        appearance: "\(appearanceLabel) Dock"
                    )
                    assertContrast(
                        "DSDockOutline",
                        on: backgroundName,
                        minimum: 3,
                        appearance: "\(appearanceLabel) Dock",
                        foregroundOpacity: 0.58
                    )
                }
            }
        }
    }

    @MainActor
    func testNumericDockStylesRenderDistinctFromCharts() throws {
        var numericSystemAppearance = DockFeatureDefaults.systemMetricsAppearance
        numericSystemAppearance.setDisplayStyle(.numeric)
        var numericStorageAppearance = DockFeatureDefaults.storageAppearance
        numericStorageAppearance.setDisplayStyle(.numeric)
        var numericGitHubAppearance = DockFeatureDefaults.githubAppearance
        numericGitHubAppearance.setDisplayStyle(.numeric)
        var numericCodexAppearance = DockFeatureDefaults.codexAppearance
        numericCodexAppearance.setDisplayStyle(.numeric)
        var numericClaudeAppearance = DockFeatureDefaults.claudeCodeAppearance
        numericClaudeAppearance.setDisplayStyle(.numeric)

        let snapshot = SystemMetricsSnapshot(
            cpuUsage: 0.72,
            memoryUsage: 0.54,
            memoryUsedBytes: 540,
            memoryTotalBytes: 1_000
        )
        let storage = StorageMetricsSnapshot(
            volumeName: "Macintosh HD",
            totalBytes: 1_000,
            availableBytes: 360
        )
        let pairs: [(String, DockTilePresentation, DockTilePresentation)] = [
            (
                "CPU RAM",
                .systemMetrics(
                    snapshot: snapshot,
                    appearance: DockFeatureDefaults.systemMetricsAppearance,
                    errorDescription: nil
                ),
                .systemMetrics(
                    snapshot: snapshot,
                    appearance: numericSystemAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Storage",
                .storage(
                    snapshot: storage,
                    appearance: DockFeatureDefaults.storageAppearance,
                    errorDescription: nil
                ),
                .storage(
                    snapshot: storage,
                    appearance: numericStorageAppearance,
                    errorDescription: nil
                )
            ),
            (
                "GitHub",
                .github(
                    history: GitHubRepositorySnapshot.designPreviewHistory,
                    appearance: DockFeatureDefaults.githubAppearance,
                    errorDescription: nil
                ),
                .github(
                    history: GitHubRepositorySnapshot.designPreviewHistory,
                    appearance: numericGitHubAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Codex",
                .codex(
                    state: .live(sampleCodexSnapshot()),
                    appearance: DockFeatureDefaults.codexAppearance
                ),
                .codex(
                    state: .live(sampleCodexSnapshot()),
                    appearance: numericCodexAppearance
                )
            ),
            (
                "Claude Code",
                .claudeCode(
                    state: .live(sampleClaudeCodeSnapshot()),
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                ),
                .claudeCode(
                    state: .live(sampleClaudeCodeSnapshot()),
                    appearance: numericClaudeAppearance
                )
            )
        ]

        for pair in pairs {
            let chart = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: pair.1,
                        animatesChanges: false
                    ),
                    appearanceMode: .dark
                ),
                size: NSSize(width: 128, height: 128),
                appearanceName: .darkAqua,
                name: "Dock — \(pair.0) — Chart"
            )
            let numeric = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: pair.2,
                        animatesChanges: false
                    ),
                    appearanceMode: .dark
                ),
                size: NSSize(width: 128, height: 128),
                appearanceName: .darkAqua,
                name: "Dock — \(pair.0) — Numbers"
            )

            assertPixelDifference(
                chart,
                numeric,
                minimumChangedFraction: 0.08,
                label: "\(pair.0) chart versus numbers"
            )
            attachPNG(chart, name: "Dock — \(pair.0) — Chart")
            attachPNG(numeric, name: "Dock — \(pair.0) — Numbers")
        }
    }

    @MainActor
    func testCodexAndClaudeNumericDockRenderOneHundredPercent() throws {
        let snapshot = CodexRateLimitSnapshot(
            planType: "pro",
            limitID: "maximum-remaining",
            fiveHour: CodexRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 0,
                windowDurationMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            weekly: CodexRateLimitWindow(
                kind: .weekly,
                usedPercent: 0,
                windowDurationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 2_000_500_000)
            ),
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        var codexAppearance = DockFeatureDefaults.codexAppearance
        codexAppearance.setDisplayStyle(.numeric)
        var claudeCodeAppearance = DockFeatureDefaults.claudeCodeAppearance
        claudeCodeAppearance.setDisplayStyle(.numeric)

        let codexPresentation = DockTilePresentation.codex(
            state: .live(snapshot),
            appearance: codexAppearance
        )
        let claudeCodePresentation = DockTilePresentation.claudeCode(
            state: .live(snapshot),
            appearance: claudeCodeAppearance
        )

        for side in [CGFloat(32), 48, 64, 128] {
            try attachScreenshot(
                of: DockMagicThemeRoot(
                    content: HStack(spacing: 0) {
                        DockTileView(
                            presentation: codexPresentation,
                            animatesChanges: false
                        )
                        .frame(width: side, height: side)

                        DockTileView(
                            presentation: claudeCodePresentation,
                            animatesChanges: false
                        )
                        .frame(width: side, height: side)
                    },
                    appearanceMode: .dark
                ),
                size: NSSize(width: side * 2, height: side),
                appearanceName: .darkAqua,
                name: "Dock — Codex + Claude Code — 100% — \(side) pt"
            )
        }
    }

    @MainActor
    func testCodexHoverDashboardMinimalColorRender() async throws {
        let suiteName = "DockMagicTests.CodexHoverRender.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            DockFeature.codex.rawValue,
            forKey: DockFeature.storageKey
        )

        let codexStore = CodexUsageStore(
            provider: ScriptedCodexProvider([
                .success(.hoverDesignPreview)
            ]),
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )
        await codexStore.refresh()
        let appModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            codexStore: codexStore
        )

        let variants: [(String, DSAppearanceMode, NSAppearance.Name)] = [
            ("Dark", .dark, .darkAqua),
            ("Light", .light, .aqua)
        ]
        var renderedVariants: [Data] = []

        for (label, mode, appearanceName) in variants {
            let name = "Codex Hover — Minimal Color — \(label)"
            let data = try renderPNG(
                of: DockHoverDashboardRoot(
                    appModel: appModel,
                    pointerEdge: .bottom,
                    appearanceMode: mode
                ),
                size: DockHoverPanelPlacement.codexPanelSize,
                appearanceName: appearanceName,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            attachPNG(data, name: name)
            renderedVariants.append(data)
        }

        XCTAssertEqual(renderedVariants.count, 2)
        XCTAssertNotEqual(renderedVariants[0], renderedVariants[1])

        let darkRepresentation = try XCTUnwrap(
            NSBitmapImageRep(data: renderedVariants[0])
        )
        let outerCorners = [
            NSPoint(x: 0, y: 0),
            NSPoint(x: darkRepresentation.pixelsWide - 1, y: 0),
            NSPoint(x: 0, y: darkRepresentation.pixelsHigh - 1),
            NSPoint(
                x: darkRepresentation.pixelsWide - 1,
                y: darkRepresentation.pixelsHigh - 1
            )
        ]
        for corner in outerCorners {
            let color = try XCTUnwrap(
                darkRepresentation.colorAt(
                    x: Int(corner.x),
                    y: Int(corner.y)
                )
            )
            XCTAssertLessThanOrEqual(
                color.alphaComponent,
                0.1,
                "Dashboard shadow must not square off an outer corner."
            )
        }

        let centerX = darkRepresentation.pixelsWide / 2
        let topEdgeY = try XCTUnwrap(
            (0..<(darkRepresentation.pixelsHigh / 4)).first { y in
                darkRepresentation.colorAt(x: centerX, y: y)?
                    .alphaComponent ?? 0 > 0.9
            },
            "Dashboard must have an opaque top edge."
        )
        let footerX = darkRepresentation.pixelsWide / 4
        let footerEdgeY = try XCTUnwrap(
            stride(
                from: darkRepresentation.pixelsHigh - 1,
                through: darkRepresentation.pixelsHigh * 3 / 4,
                by: -1
            ).first { y in
                darkRepresentation.colorAt(x: footerX, y: y)?
                    .alphaComponent ?? 0 > 0.9
            },
            "Dashboard must have an opaque footer edge."
        )
        let topEdge = try XCTUnwrap(
            darkRepresentation.colorAt(
                x: centerX,
                y: topEdgeY
            )?.usingColorSpace(.sRGB)
        )
        let topInterior = try XCTUnwrap(
            darkRepresentation.colorAt(
                x: centerX,
                y: min(topEdgeY + 15, darkRepresentation.pixelsHigh - 1)
            )?.usingColorSpace(.sRGB)
        )
        let footerEdge = try XCTUnwrap(
            darkRepresentation.colorAt(
                x: footerX,
                y: footerEdgeY
            )?.usingColorSpace(.sRGB)
        )
        let footerInterior = try XCTUnwrap(
            darkRepresentation.colorAt(
                x: footerX,
                y: max(footerEdgeY - 15, 0)
            )?.usingColorSpace(.sRGB)
        )
        let brightness: (NSColor) -> CGFloat = { color in
            (color.redComponent + color.greenComponent + color.blueComponent)
                / 3
        }
        let headerContrast = abs(brightness(topEdge) - brightness(topInterior))
        let footerContrast = abs(
            brightness(footerEdge) - brightness(footerInterior)
        )
        XCTAssertGreaterThanOrEqual(
            headerContrast,
            footerContrast * 0.75,
            "Header and footer must render with comparable outer-edge contrast."
        )

        let accessibilityVariants: [(String, DSAccessibilityOverrides)] = [
            (
                "Increased Contrast",
                DSAccessibilityOverrides(increaseContrast: true)
            ),
            (
                "Reduced Transparency",
                DSAccessibilityOverrides(reduceTransparency: true)
            )
        ]
        for (label, overrides) in accessibilityVariants {
            let name = "Codex Hover — Minimal Color — \(label)"
            let data = try renderPNG(
                of: DockHoverDashboardRoot(
                    appModel: appModel,
                    pointerEdge: .bottom,
                    appearanceMode: .dark
                )
                .environment(\.dsAccessibilityOverrides, overrides),
                size: DockHoverPanelPlacement.codexPanelSize,
                appearanceName: .darkAqua,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            attachPNG(data, name: name)
        }

        let grayscaleName = "Codex Hover — Ship Momentum — Grayscale"
        let grayscale = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark
            )
            .grayscale(1),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: grayscaleName
        )
        XCTAssertGreaterThan(grayscale.count, 12_000)
        attachPNG(grayscale, name: grayscaleName)

        let fullPreview = CodexRateLimitSnapshot.hoverDesignPreview
        let weeklyOnlySnapshot = CodexRateLimitSnapshot(
            planType: "plus",
            limitID: fullPreview.limitID,
            fiveHour: nil,
            weekly: fullPreview.weekly,
            tokenUsage: fullPreview.tokenUsage,
            recentTaskActivity: fullPreview.recentTaskActivity,
            fetchedAt: fullPreview.fetchedAt
        )
        let weeklyOnlyStore = CodexUsageStore(
            provider: ScriptedCodexProvider([.success(weeklyOnlySnapshot)]),
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )
        await weeklyOnlyStore.refresh()
        let weeklyOnlyModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            codexStore: weeklyOnlyStore
        )
        let weeklyOnlyName = "Codex Hover — Plus — Weekly Only"
        let weeklyOnly = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: weeklyOnlyModel,
                pointerEdge: .bottom,
                appearanceMode: .dark
            ),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: weeklyOnlyName
        )
        XCTAssertGreaterThan(weeklyOnly.count, 12_000)
        attachPNG(weeklyOnly, name: weeklyOnlyName)

        let hoveredBucketID = fullPreview.tokenUsage?
            .dailyUsageBuckets
            .suffix(7)
            .dropLast(2)
            .last?
            .id
        let hoveredName = "Codex Hover — Daily Intensity Hover"
        let hovered = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark,
                initialIntensityHoveredBucketID: hoveredBucketID
            ),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: hoveredName
        )
        XCTAssertGreaterThan(hovered.count, 12_000)
        XCTAssertNotEqual(hovered, renderedVariants[0])
        attachPNG(hovered, name: hoveredName)

        let detailBucketID = try XCTUnwrap(
            fullPreview.tokenUsage?.dailyUsageBuckets.last?.id
        )
        let detailVariants: [(String, DSAppearanceMode, NSAppearance.Name)] = [
            ("Dark", .dark, .darkAqua),
            ("Light", .light, .aqua)
        ]
        for (label, mode, appearanceName) in detailVariants {
            let name = "Codex Hover — Daily Detail — \(label)"
            let data = try renderPNG(
                of: DockHoverDashboardRoot(
                    appModel: appModel,
                    pointerEdge: .bottom,
                    appearanceMode: mode,
                    initialSelectedDailyBucketID: detailBucketID
                ),
                size: DockHoverPanelPlacement.codexPanelSize,
                appearanceName: appearanceName,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            XCTAssertNotEqual(data, renderedVariants[0])
            attachPNG(data, name: name)
        }

        let detailContrastName = "Codex Hover — Daily Detail — Increased Contrast"
        let detailContrast = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark,
                initialSelectedDailyBucketID: detailBucketID
            )
            .environment(
                \.dsAccessibilityOverrides,
                DSAccessibilityOverrides(increaseContrast: true)
            ),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: detailContrastName
        )
        XCTAssertGreaterThan(detailContrast.count, 12_000)
        attachPNG(detailContrast, name: detailContrastName)

        let detailTransparencyName =
            "Codex Hover — Daily Detail — Reduced Transparency"
        let detailTransparency = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark,
                initialSelectedDailyBucketID: detailBucketID
            )
            .environment(
                \.dsAccessibilityOverrides,
                DSAccessibilityOverrides(reduceTransparency: true)
            ),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: detailTransparencyName
        )
        XCTAssertGreaterThan(detailTransparency.count, 12_000)
        attachPNG(detailTransparency, name: detailTransparencyName)

        let detailGrayscaleName = "Codex Hover — Daily Detail — Grayscale"
        let detailGrayscale = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark,
                initialSelectedDailyBucketID: detailBucketID
            )
            .grayscale(1),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: detailGrayscaleName
        )
        XCTAssertGreaterThan(detailGrayscale.count, 12_000)
        attachPNG(detailGrayscale, name: detailGrayscaleName)

        for (index, variant) in variants.enumerated() {
            let (label, mode, appearanceName) = variant
            let captureMenuName = "Codex Hover — Capture Menu — \(label)"
            let captureMenu = try renderPNG(
                of: DockHoverDashboardRoot(
                    appModel: appModel,
                    pointerEdge: .bottom,
                    appearanceMode: mode,
                    initialCaptureMenuPresented: true
                ),
                size: DockHoverPanelPlacement.codexPanelSize,
                appearanceName: appearanceName,
                name: captureMenuName
            )
            XCTAssertGreaterThan(captureMenu.count, 12_000)
            XCTAssertNotEqual(captureMenu, renderedVariants[index])
            attachPNG(captureMenu, name: captureMenuName)
        }

        let captureMenuGrayscaleName =
            "Codex Hover — Capture Menu — Grayscale"
        let captureMenuGrayscale = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark,
                initialCaptureMenuPresented: true
            )
            .grayscale(1),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: captureMenuGrayscaleName
        )
        XCTAssertGreaterThan(captureMenuGrayscale.count, 12_000)
        attachPNG(captureMenuGrayscale, name: captureMenuGrayscaleName)
    }

    @MainActor
    func testCodexDashboardCaptureRendersCrispFourTimesPNG() throws {
        let panelSize = DockHoverPanelPlacement.codexPanelSize
        let fixedNow = Date(timeIntervalSince1970: 1_777_000_000)
        let artifact = try CodexDashboardCaptureService.render(
            state: .live(.hoverDesignPreview),
            configuration: CodexDashboardCaptureConfiguration(
                pointerEdge: .bottom,
                panelSize: panelSize,
                appearanceMode: .dark
            ),
            now: fixedNow
        )
        let representation = try XCTUnwrap(
            NSBitmapImageRep(data: artifact.pngData)
        )

        XCTAssertEqual(artifact.pixelWidth, 1_760)
        XCTAssertEqual(artifact.pixelHeight, 2_088)
        XCTAssertEqual(representation.pixelsWide, 1_760)
        XCTAssertEqual(representation.pixelsHigh, 2_088)
        XCTAssertGreaterThan(artifact.pngData.count, 60_000)
        XCTAssertEqual(
            artifact.fileName,
            CodexDashboardCaptureService.defaultFileName(
                at: fixedNow,
                timeZone: .current
            )
        )
        XCTAssertEqual(
            CodexDashboardCaptureService.pixelSizeLabel(for: panelSize),
            "1760 × 2088 px"
        )

        let pasteboard = NSPasteboard.withUniqueName()
        try CodexDashboardCaptureService.copy(
            artifact,
            to: pasteboard
        )
        XCTAssertEqual(
            pasteboard.data(forType: .png),
            artifact.pngData
        )

        let shareDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DockMagicCaptureTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: shareDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: shareDirectory) }
        let shareURL = try CodexDashboardCaptureService.temporaryShareURL(
            for: artifact,
            directory: shareDirectory
        )
        XCTAssertEqual(
            try Data(contentsOf: shareURL),
            artifact.pngData
        )

        attachPNG(
            artifact.pngData,
            name: "Codex Dashboard — Exported 4× PNG"
        )
    }

    @MainActor
    func testCodexCaptureButtonOpensMenuInNonactivatingPanel() throws {
        let panelSize = DockHoverPanelPlacement.codexPanelSize
        let configuration = CodexDashboardCaptureConfiguration(
            pointerEdge: .bottom,
            panelSize: panelSize,
            appearanceMode: .dark
        )
        let root = DockMagicThemeRoot(
            content: DockHoverChrome(
                pointerEdge: .bottom,
                panelSize: panelSize
            ) {
                CodexHoverDashboardView(
                    state: .live(.hoverDesignPreview),
                    captureConfiguration: configuration
                )
            },
            appearanceMode: .dark
        )
        .frame(width: panelSize.width, height: panelSize.height)
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        panel.ignoresMouseEvents = false
        panel.contentView = hostingView
        panel.orderFront(nil)
        defer {
            panel.contentView = nil
            panel.close()
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        hostingView.layoutSubtreeIfNeeded()
        let before = try renderExistingViewPNG(
            hostingView,
            name: "Codex capture button before click"
        )

        let clickLocation = NSPoint(x: 315, y: 497)
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        let up = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: clickLocation,
            modifierFlags: [],
            timestamp: 0.01,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 0
        ))
        panel.sendEvent(down)
        panel.sendEvent(up)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        hostingView.layoutSubtreeIfNeeded()

        let after = try renderExistingViewPNG(
            hostingView,
            name: "Codex capture menu after click"
        )
        XCTAssertNotEqual(before, after)
        assertPixelDifference(
            before,
            after,
            minimumChangedFraction: 0.02,
            label: "Capture menu click state"
        )
        attachPNG(
            after,
            name: "Codex Hover — Capture Menu — Clicked"
        )
    }

    @MainActor
    func testClaudeCodeHoverDashboardRendersEveryDataState() async throws {
        let suiteName = "DockMagicTests.ClaudeCodeHoverRender.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            DockFeature.claudeCode.rawValue,
            forKey: DockFeature.storageKey
        )

        let renderNow = Date.now
        let liveSnapshot = CodexRateLimitSnapshot
            .claudeCodeHoverDesignPreview(now: renderNow)
        let liveStore = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([.success(liveSnapshot)]),
            bridge: StubClaudeCodeBridge(installed: true),
            pollingInterval: .seconds(60),
            staleAfter: 900,
            now: { renderNow }
        )
        await liveStore.refresh()
        let liveModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            claudeCodeStore: liveStore
        )

        let variants: [(String, DSAppearanceMode, NSAppearance.Name)] = [
            ("Dark", .dark, .darkAqua),
            ("Light", .light, .aqua)
        ]
        var renderedVariants: [Data] = []
        for (label, mode, appearanceName) in variants {
            let name = "Claude Code Hover — Live — \(label)"
            let data = try renderPNG(
                of: DockHoverDashboardRoot(
                    appModel: liveModel,
                    pointerEdge: .bottom,
                    appearanceMode: mode
                ),
                size: DockHoverPanelPlacement.claudeCodePanelSize,
                appearanceName: appearanceName,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            attachPNG(data, name: name)
            renderedVariants.append(data)
        }
        XCTAssertNotEqual(renderedVariants[0], renderedVariants[1])

        let costName = "Claude Code Hover — Cost Metric — Dark"
        let costData = try renderPNG(
            of: DockMagicThemeRoot(
                content: DockHoverChrome(
                    pointerEdge: .bottom,
                    panelSize: DockHoverPanelPlacement.claudeCodePanelSize
                ) {
                    ClaudeCodeHoverDashboardView(
                        state: .live(liveSnapshot),
                        now: renderNow,
                        initialMetric: "Cost"
                    )
                },
                appearanceMode: .dark
            )
            .frame(
                width: DockHoverPanelPlacement.claudeCodePanelSize.width,
                height: DockHoverPanelPlacement.claudeCodePanelSize.height
            ),
            size: DockHoverPanelPlacement.claudeCodePanelSize,
            appearanceName: .darkAqua,
            name: costName
        )
        XCTAssertGreaterThan(costData.count, 12_000)
        XCTAssertNotEqual(costData, renderedVariants[0])
        attachPNG(costData, name: costName)

        let staleSnapshot = CodexRateLimitSnapshot(
            planType: nil,
            limitID: liveSnapshot.limitID,
            fiveHour: liveSnapshot.fiveHour,
            weekly: nil,
            fetchedAt: renderNow.addingTimeInterval(-3_600)
        )
        let staleStore = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([.success(staleSnapshot)]),
            bridge: StubClaudeCodeBridge(installed: true),
            pollingInterval: .seconds(60),
            staleAfter: 900,
            now: { renderNow }
        )
        await staleStore.refresh()
        let staleModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            claudeCodeStore: staleStore
        )
        let staleName = "Claude Code Hover — Stale — Missing Weekly"
        let staleData = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: staleModel,
                pointerEdge: .bottom,
                appearanceMode: .dark
            ),
            size: DockHoverPanelPlacement.claudeCodePanelSize,
            appearanceName: .darkAqua,
            name: staleName
        )
        XCTAssertGreaterThan(staleData.count, 12_000)
        XCTAssertNotEqual(staleData, renderedVariants[0])
        attachPNG(staleData, name: staleName)

        let unavailableStore = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([]),
            bridge: StubClaudeCodeBridge(installed: false),
            pollingInterval: .seconds(60)
        )
        await unavailableStore.refresh()
        let unavailableModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            claudeCodeStore: unavailableStore
        )
        let unavailableName = "Claude Code Hover — Unavailable"
        let unavailableData = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: unavailableModel,
                pointerEdge: .bottom,
                appearanceMode: .dark
            ),
            size: DockHoverPanelPlacement.claudeCodePanelSize,
            appearanceName: .darkAqua,
            name: unavailableName
        )
        XCTAssertGreaterThan(unavailableData.count, 12_000)
        XCTAssertNotEqual(unavailableData, renderedVariants[0])
        attachPNG(unavailableData, name: unavailableName)

        let accessibilityVariants: [(String, DSAccessibilityOverrides)] = [
            (
                "Increased Contrast",
                DSAccessibilityOverrides(increaseContrast: true)
            ),
            (
                "Reduced Transparency",
                DSAccessibilityOverrides(reduceTransparency: true)
            )
        ]
        for (label, overrides) in accessibilityVariants {
            let name = "Claude Code Hover — \(label)"
            let data = try renderPNG(
                of: DockHoverDashboardRoot(
                    appModel: liveModel,
                    pointerEdge: .bottom,
                    appearanceMode: .dark
                )
                .environment(\.dsAccessibilityOverrides, overrides),
                size: DockHoverPanelPlacement.claudeCodePanelSize,
                appearanceName: .darkAqua,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            attachPNG(data, name: name)
        }

        let grayscaleName = "Claude Code Hover — Grayscale"
        let grayscale = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: liveModel,
                pointerEdge: .bottom,
                appearanceMode: .dark
            )
            .grayscale(1),
            size: DockHoverPanelPlacement.claudeCodePanelSize,
            appearanceName: .darkAqua,
            name: grayscaleName
        )
        XCTAssertGreaterThan(grayscale.count, 12_000)
        attachPNG(grayscale, name: grayscaleName)

    }

    func testClaudeCodeHoverPresentationFormatsFreshnessAndReset() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let snapshot = CodexRateLimitSnapshot
            .claudeCodeHoverDesignPreview(now: now)
        let reset = try XCTUnwrap(
            ClaudeCodeHoverDashboardPresentation.nextReset(
                in: snapshot,
                now: now
            )
        )

        XCTAssertEqual(reset.title, "5-hour")
        XCTAssertEqual(reset.date, snapshot.fiveHour?.resetsAt)
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.countdownLabel(
                until: reset.date,
                now: now
            ),
            "2h 18m"
        )
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.countdownLabel(
                until: now.addingTimeInterval(-1),
                now: now
            ),
            "Time passed"
        )
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.ageLabel(
                since: now.addingTimeInterval(-45),
                now: now
            ),
            "Just now"
        )
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.ageLabel(
                since: now.addingTimeInterval(-(2 * 3_600 + 5 * 60)),
                now: now
            ),
            "2h 5m ago"
        )
        XCTAssertFalse(
            ClaudeCodeHoverDashboardPresentation.dateLabel(now).isEmpty
        )

        let mixedSnapshot = CodexRateLimitSnapshot(
            planType: nil,
            limitID: "claude-code",
            fiveHour: ClaudeCodeRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 100,
                windowDurationMinutes: 300,
                resetsAt: now.addingTimeInterval(-1)
            ),
            weekly: snapshot.weekly,
            fetchedAt: now
        )
        XCTAssertEqual(
            ClaudeCodeHoverDashboardPresentation.nextReset(
                in: mixedSnapshot,
                now: now
            )?.title,
            "Weekly"
        )
    }

    func testClaudeCodeHoverDashboardFollowsColorAndPrivacyContracts() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectDirectory.appendingPathComponent(
            "DockMagic/Views/Hover/ClaudeCodeHoverDashboardView.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let forbiddenPatterns = [
            "LinearGradient(",
            "RadialGradient(",
            "AngularGradient(",
            ".ultraThinMaterial",
            "Color.black",
            "Color.white",
            "appearance.outerColor",
            "appearance.innerColor",
            "DockFeatureDefaults.claudeCodeAppearance",
            "DockRingAppearance",
            "import Charts",
            "transcript_path",
            "session_id",
            "OAuth"
        ]

        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                source.contains(pattern),
                "Claude Code hover must not contain \(pattern)."
            )
        }

        XCTAssertTrue(source.contains("Image(\"ClaudeCodeLogo\")"))
        XCTAssertTrue(source.contains("UsageLimitHoverRow("))
        XCTAssertTrue(source.contains("ProjectTheme.claudeCodeUsage"))
        XCTAssertTrue(source.contains("Daily usage"))
        XCTAssertTrue(source.contains("Top models"))
        XCTAssertTrue(source.contains("Ship momentum"))
        XCTAssertTrue(source.contains("ClaudeCodeShipMomentumGauge("))
        XCTAssertTrue(source.contains("Active work"))
        XCTAssertTrue(source.contains("observed est."))
        XCTAssertTrue(source.contains("case tokens = \"Tokens\""))
        XCTAssertTrue(source.contains("case cost = \"Cost\""))
        XCTAssertTrue(source.contains("dockHover.claudeCode"))
        XCTAssertTrue(source.contains(".symbolRenderingMode(.monochrome)"))
        XCTAssertTrue(source.contains("theme.opaqueSurfaceInset"))
    }

    func testCodexHoverPresentationUsesOnlyAvailableLimitsAndThirtyDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let reset = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 28,
            hour: 9,
            minute: 15
        ))!
        let weekly = CodexRateLimitWindow(
            kind: .weekly,
            usedPercent: 40,
            windowDurationMinutes: 10_080,
            resetsAt: reset
        )
        let start = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 21,
            hour: 12
        ))!
        let buckets = (0..<35).map { index in
            CodexTokenUsageDailyBucket(
                startDate: calendar.date(
                    byAdding: .day,
                    value: index,
                    to: start
                )!,
                tokens: Int64((index + 1) * 10_000)
            )
        }
        let usage = CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: nil,
            currentStreakDays: nil,
            longestStreakDays: nil,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: buckets,
            modelUsage: [
                CodexModelTokenUsage(model: "gpt-5.4", tokens: 300),
                CodexModelTokenUsage(model: "gpt-5.6", tokens: 900),
                CodexModelTokenUsage(model: "gpt-5.5", tokens: 600),
                CodexModelTokenUsage(model: "gpt-5.3", tokens: 100)
            ],
            isModelUsagePartial: false
        )
        let snapshot = CodexRateLimitSnapshot(
            planType: "plus",
            limitID: "codex",
            fiveHour: nil,
            weekly: weekly,
            tokenUsage: usage,
            fetchedAt: reset
        )

        let visibleWindows = CodexHoverDashboardPresentation
            .visibleQuotaWindows(in: snapshot)
        XCTAssertEqual(visibleWindows.map(\.kind), [.weekly])

        let visibleBuckets = CodexHoverDashboardPresentation.chartBuckets(
            from: usage
        )
        XCTAssertEqual(visibleBuckets.count, 30)
        XCTAssertEqual(visibleBuckets.first?.id, buckets[5].id)
        XCTAssertEqual(visibleBuckets.last?.id, buckets[34].id)
        XCTAssertEqual(
            CodexHoverDashboardPresentation.topModels(from: usage),
            [
                CodexModelTokenUsage(model: "gpt-5.6", tokens: 900),
                CodexModelTokenUsage(model: "gpt-5.5", tokens: 600),
                CodexModelTokenUsage(model: "gpt-5.4", tokens: 300)
            ]
        )
        XCTAssertEqual(
            CodexHoverDashboardPresentation.resetLabel(for: weekly),
            "Resets Aug 28, 9:15 AM"
        )
    }

    func testCodexDailyDetailCachedInputStaysBounded() {
        let breakdown = CodexTokenBreakdown(
            inputTokens: 800,
            cachedInputTokens: 600,
            cacheWriteInputTokens: 0,
            outputTokens: 200,
            reasoningOutputTokens: 100,
            totalTokens: 1_000
        )
        XCTAssertEqual(breakdown.cachedInputFraction, 0.75)
        XCTAssertEqual(
            breakdown.adding(breakdown),
            CodexTokenBreakdown(
                inputTokens: 1_600,
                cachedInputTokens: 1_200,
                cacheWriteInputTokens: 0,
                outputTokens: 400,
                reasoningOutputTokens: 200,
                totalTokens: 2_000
            )
        )
    }

    func testCodexShipMomentumCombinesTasksAndTokensAgainstPriorWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let fetchedAt = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 12
        ))!
        let start = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 12,
            hour: 12
        ))!
        let buckets = (0..<14).map { index in
            CodexTokenUsageDailyBucket(
                startDate: calendar.date(
                    byAdding: .day,
                    value: index,
                    to: start
                )!,
                tokens: index < 7 ? 300 : 700
            )
        }
        let usage = CodexAccountTokenUsage(
            lifetimeTokens: nil,
            peakDailyTokens: nil,
            currentStreakDays: nil,
            longestStreakDays: nil,
            longestRunningTurnSeconds: nil,
            dailyUsageBuckets: buckets
        )
        let snapshot = CodexRateLimitSnapshot(
            planType: "pro",
            limitID: "codex",
            fiveHour: nil,
            weekly: nil,
            tokenUsage: usage,
            recentTaskActivity: CodexRecentTaskActivity(
                currentWeekCount: 9,
                previousWeekCount: 3,
                isPartial: false
            ),
            fetchedAt: fetchedAt
        )

        let momentum = CodexHoverDashboardPresentation.shipMomentum(
            in: snapshot
        )
        XCTAssertEqual(momentum?.currentTokens, 4_900)
        XCTAssertEqual(momentum?.previousTokens, 2_100)
        XCTAssertEqual(momentum?.currentTasks, 9)
        XCTAssertEqual(momentum?.score, 73)
        XCTAssertEqual(momentum?.rank, .accelerator)

        let missingTaskSignal = CodexRateLimitSnapshot(
            planType: "pro",
            limitID: "codex",
            fiveHour: nil,
            weekly: nil,
            tokenUsage: usage,
            recentTaskActivity: CodexRecentTaskActivity(
                currentWeekCount: 0,
                previousWeekCount: 0,
                isPartial: false
            ),
            fetchedAt: fetchedAt
        )
        XCTAssertNil(
            CodexHoverDashboardPresentation.shipMomentum(
                in: missingTaskSignal
            )
        )
    }

    func testCodexShipMomentumRanksUseSixAscendingThresholds() {
        XCTAssertEqual(CodexShipRank.rank(for: 0), .spark)
        XCTAssertEqual(CodexShipRank.rank(for: 9), .spark)
        XCTAssertEqual(CodexShipRank.rank(for: 10), .builder)
        XCTAssertEqual(CodexShipRank.rank(for: 29), .builder)
        XCTAssertEqual(CodexShipRank.rank(for: 30), .maker)
        XCTAssertEqual(CodexShipRank.rank(for: 49), .maker)
        XCTAssertEqual(CodexShipRank.rank(for: 50), .shipper)
        XCTAssertEqual(CodexShipRank.rank(for: 69), .shipper)
        XCTAssertEqual(CodexShipRank.rank(for: 70), .accelerator)
        XCTAssertEqual(CodexShipRank.rank(for: 89), .accelerator)
        XCTAssertEqual(CodexShipRank.rank(for: 90), .vanguard)
        XCTAssertEqual(CodexShipRank.rank(for: 100), .vanguard)
    }

    func testCodexHoverDashboardFollowsColorDesignSystemSourceContract() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePaths = [
            "DockMagic/Views/Hover/CodexHoverDashboardView.swift",
            "DockMagic/Views/Hover/CodexDailyTokenDetailView.swift"
        ]
        let source = try sourcePaths.map { path in
            try String(
                contentsOf: projectDirectory.appendingPathComponent(path),
                encoding: .utf8
            )
        }.joined(separator: "\n")
        let forbiddenPatterns = [
            "LinearGradient(",
            "RadialGradient(",
            "AngularGradient(",
            ".ultraThinMaterial",
            "Color.black",
            "Color.white",
            "appearance.outerColor",
            "appearance.innerColor",
            "DockRingAppearance",
            "import Charts",
            "Cost",
            "Pricing",
            "Updated just now",
            "\"Live\""
        ]

        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                source.contains(pattern),
                "Codex hover must not contain \(pattern)."
            )
        }

        XCTAssertTrue(source.contains("Image(\"CodexLogo\")"))
        XCTAssertTrue(source.contains(".fill(theme.action)"))
        XCTAssertTrue(source.contains(".dsSurface("))
        XCTAssertTrue(source.contains(".symbolRenderingMode(.monochrome)"))
        XCTAssertTrue(source.contains("ScrollView(.horizontal"))
        XCTAssertTrue(source.contains(".onHover"))
        XCTAssertTrue(source.contains(".help("))
        XCTAssertTrue(source.contains("maximumChartDays = 30"))
        XCTAssertTrue(source.contains("Ship momentum"))
        XCTAssertTrue(source.contains("Daily intensity"))
        XCTAssertTrue(source.contains("Top models"))
        XCTAssertTrue(source.contains("initialIntensityHoveredBucketID"))
        XCTAssertTrue(source.contains("theme.action.opacity(0.10"))
        XCTAssertTrue(source.contains("CodexDailyTokenDetailView("))
        XCTAssertFalse(source.contains("Text(\"Local detail\")"))
        XCTAssertFalse(source.contains("Text(\"Partial\")"))
        XCTAssertFalse(source.contains("Text(summaryStatusLabel)"))
        XCTAssertFalse(source.contains("Text(coverageLabel)"))
        XCTAssertFalse(source.contains("Text(\"No local hourly data\")"))
        XCTAssertTrue(source.contains("Cached input"))
        XCTAssertTrue(source.contains("Hourly usage"))
        XCTAssertTrue(source.contains(".buttonStyle(.plain)"))
        XCTAssertTrue(source.contains("codex.dailyDetail.back"))
        XCTAssertTrue(source.contains("hoverTooltip("))
        XCTAssertTrue(source.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(source.contains("square.and.arrow.up"))
        XCTAssertTrue(source.contains("Save 4× PNG"))
        XCTAssertTrue(source.contains("Copy image"))
        XCTAssertTrue(source.contains("Share…"))
        XCTAssertTrue(source.contains("codex.capture.button"))
        XCTAssertTrue(source.contains("codex.capture.menu"))
        XCTAssertTrue(
            source.contains("hoveredCaptureAction = captureAction")
        )
        XCTAssertTrue(source.contains("hoveredCaptureAction ?? .save"))
        XCTAssertTrue(
            source.contains(".fill(theme.outlineStrong.opacity(0.18))")
        )
        XCTAssertFalse(source.contains("isPrimary: true"))
        XCTAssertFalse(
            source.contains(".help(Self.fullDateLabel(bucket.startDate))")
        )
        XCTAssertFalse(source.contains("Hovered date"))
        XCTAssertTrue(source.contains("CodexGaugeArcShape"))
        XCTAssertTrue(source.contains("CodexShipRankLadder"))
        XCTAssertTrue(source.contains("CodexRankStepShape"))
        XCTAssertTrue(source.contains("case shipper"))
        XCTAssertTrue(source.contains("case vanguard"))
        XCTAssertFalse(source.contains("Equal weight: task starts + token activity"))
        XCTAssertFalse(source.contains("Steady"))
        XCTAssertFalse(source.contains("\"0–10\""))
        XCTAssertFalse(source.contains("\"10–30\""))
        XCTAssertFalse(source.contains("\"30–50\""))
        XCTAssertFalse(source.contains("\"50–70\""))
        XCTAssertFalse(source.contains("\"70–90\""))
        XCTAssertFalse(source.contains("\"90–100\""))
        XCTAssertTrue(source.contains("case \"pro\":"))
        XCTAssertTrue(source.contains("\"crown.fill\""))
        XCTAssertTrue(source.contains("case \"plus\":"))
        XCTAssertTrue(source.contains("\"sparkles\""))
    }

    func testDockHoverPopupSourceAllowsChartPointerInteraction() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectDirectory.appendingPathComponent(
            "DockMagic/Services/DockHoverCoordinator.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("panelController.scheduleHide()"))
        XCTAssertTrue(source.contains("panel.ignoresMouseEvents = false"))
        XCTAssertTrue(source.contains("panel.acceptsMouseMovedEvents = true"))
        XCTAssertTrue(source.contains("panel.frame.contains(NSEvent.mouseLocation)"))
    }

    @MainActor
    func testCodexTokenHistoryChartCreatesScrollableViewportAndHoverTracking() throws {
        let buckets = try XCTUnwrap(
            CodexRateLimitSnapshot.hoverDesignPreview
                .tokenUsage?
                .dailyUsageBuckets
        )
        let hoverState = CodexHoverTestState()
        let binding = Binding<Date?>(
            get: { hoverState.hoveredBucketID },
            set: { hoverState.hoveredBucketID = $0 }
        )
        let hostingView = NSHostingView(
            rootView: DockMagicThemeRoot(
                content: CodexTokenHistoryChart(
                    buckets: buckets,
                    hoveredBucketID: binding,
                    plotHeight: 88,
                    onSelectBucket: { hoverState.selectedBucketID = $0 }
                ),
                appearanceMode: .dark
            )
            .frame(width: 400, height: 126)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 400, height: 126),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer {
            window.contentView = nil
            window.close()
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        hostingView.layoutSubtreeIfNeeded()

        let scrollView = try XCTUnwrap(
            firstSubview(of: NSScrollView.self, in: hostingView)
        )
        let documentView = try XCTUnwrap(scrollView.documentView)
        XCTAssertGreaterThan(
            documentView.bounds.width,
            scrollView.contentView.bounds.width * 2
        )
        XCTAssertTrue(scrollView.hasHorizontalScroller)

        let latestOffset = scrollView.contentView.bounds.origin.x
        XCTAssertGreaterThan(latestOffset, 0)
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        XCTAssertLessThan(
            scrollView.contentView.bounds.origin.x,
            latestOffset
        )

        let trackingAreaCount = countTrackingAreas(in: hostingView)
        XCTAssertGreaterThan(
            trackingAreaCount,
            0,
            "The chart should install AppKit pointer hover tracking."
        )
    }

    @MainActor
    func testCodexAndClaudeWeeklyOnlyNumericDockUsesLargerTypography() throws {
        let snapshot = CodexRateLimitSnapshot(
            planType: "pro",
            limitID: "weekly-only-maximum-remaining",
            fiveHour: nil,
            weekly: CodexRateLimitWindow(
                kind: .weekly,
                usedPercent: 0,
                windowDurationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 2_000_500_000)
            ),
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        var codexAppearance = DockFeatureDefaults.codexAppearance
        codexAppearance.setDisplayStyle(.numeric)
        var claudeCodeAppearance = DockFeatureDefaults.claudeCodeAppearance
        claudeCodeAppearance.setDisplayStyle(.numeric)

        let codexPresentation = DockTilePresentation.codex(
            state: .live(snapshot),
            appearance: codexAppearance
        )
        let claudeCodePresentation = DockTilePresentation.claudeCode(
            state: .live(snapshot),
            appearance: claudeCodeAppearance
        )

        for side in [CGFloat(32), 48, 64, 128] {
            try attachScreenshot(
                of: DockMagicThemeRoot(
                    content: HStack(spacing: 0) {
                        DockTileView(
                            presentation: codexPresentation,
                            animatesChanges: false
                        )
                        .frame(width: side, height: side)

                        DockTileView(
                            presentation: claudeCodePresentation,
                            animatesChanges: false
                        )
                        .frame(width: side, height: side)
                    },
                    appearanceMode: .dark
                ),
                size: NSSize(width: side * 2, height: side),
                appearanceName: .darkAqua,
                name: "Dock — Codex + Claude Code — Weekly only — \(side) pt"
            )
        }
    }

    @MainActor
    func testClaudeCodeChartOmitsCentralStateIcon() throws {
        let idle = try renderPNG(
            of: DockMagicThemeRoot(
                content: DockClaudeCodeView(
                    state: .idle,
                    appearance: DockFeatureDefaults.claudeCodeAppearance,
                    animatesChanges: false
                ),
                appearanceMode: .dark
            ),
            size: NSSize(width: 128, height: 128),
            appearanceName: .darkAqua,
            name: "Claude Code — Idle — No Center Icon"
        )
        let unavailable = try renderPNG(
            of: DockMagicThemeRoot(
                content: DockClaudeCodeView(
                    state: .unavailable(message: "Bridge unavailable"),
                    appearance: DockFeatureDefaults.claudeCodeAppearance,
                    animatesChanges: false
                ),
                appearanceMode: .dark
            ),
            size: NSSize(width: 128, height: 128),
            appearanceName: .darkAqua,
            name: "Claude Code — Unavailable — No Center Icon"
        )

        XCTAssertEqual(
            idle,
            unavailable,
            "Claude Code state changes must not draw an icon in the ring center."
        )
        attachPNG(unavailable, name: "Claude Code — No Center Icon")
    }

    @MainActor
    func testSearchConsoleAdaptiveFocusReferenceRender() async throws {
        let suiteName = "DockMagicTests.SearchConsoleRender.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(
            DockFeature.searchConsole.rawValue,
            forKey: DockFeature.storageKey
        )
        defaults.set(
            DSAppearanceMode.dark.rawValue,
            forKey: DSAppearanceMode.storageKey
        )
        let searchConsoleStore = SearchConsoleStore.uiTestFixture()
        await searchConsoleStore.refresh()
        let appModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            searchConsoleStore: searchConsoleStore
        )

        try attachScreenshot(
            of: DockMagicThemeRoot(
                content: SettingsView(
                    appModel: appModel,
                    initialDestination: .searchConsole
                )
                .defaultAppStorage(defaults),
                appearanceMode: .dark
            ),
            size: NSSize(width: 1_160, height: 820),
            appearanceName: .darkAqua,
            name: "Settings — Search Console — Adaptive Focus Reference"
        )
    }

    @MainActor
    func testDesignSystemRendersAllSettingsAcrossAppearances() async throws {
        let appModel = makeAppModel()
        let appearanceDefaults = makeAppearanceDefaults(.light)
        await appModel.metricsStore.refresh()
        await appModel.networkStore.refresh()
        await appModel.networkStore.refresh()
        await appModel.storageStore.refresh()
        await appModel.weatherStore.refresh()
        await appModel.codexStore.refresh()
        await appModel.claudeCodeStore.refresh()

        let deniedWeatherModel = makeAppModel(weatherAuthorization: .denied)
        await deniedWeatherModel.weatherStore.refresh()

        let appearanceCases: [(
            mode: DSAppearanceMode,
            appKit: NSAppearance.Name,
            label: String
        )] = [
            (.system, .aqua, "System"),
            (.light, .aqua, "Light"),
            (.dark, .darkAqua, "Dark")
        ]

        for appearanceCase in appearanceCases {
            appearanceDefaults.set(
                appearanceCase.mode.rawValue,
                forKey: DSAppearanceMode.storageKey
            )

            for destination in SettingsDestination.allCases {
                try attachScreenshot(
                    of: DockMagicThemeRoot(
                        content: SettingsView(
                            appModel: appModel,
                            initialDestination: destination
                        )
                        .defaultAppStorage(appearanceDefaults),
                        appearanceMode: appearanceCase.mode
                    ),
                    size: NSSize(width: 1_020, height: 740),
                    appearanceName: appearanceCase.appKit,
                    name: "Settings — \(destination.title) — \(appearanceCase.label)",
                    attachmentLifetime: .deleteOnSuccess
                )
            }

            try attachScreenshot(
                of: DockMagicThemeRoot(
                    content: SettingsView(
                        appModel: deniedWeatherModel,
                        initialDestination: .weather
                    )
                    .defaultAppStorage(appearanceDefaults),
                    appearanceMode: appearanceCase.mode
                ),
                size: NSSize(width: 1_020, height: 740),
                appearanceName: appearanceCase.appKit,
                name: "Settings — Weather Permission Denied — \(appearanceCase.label)",
                attachmentLifetime: .deleteOnSuccess
            )
        }
    }

    @MainActor
    func testDesignSystemRendersAllDockStatesInSystemAppearance() throws {
        try attachAllDockStateScreenshots(
            mode: .system,
            appKitAppearance: .aqua,
            label: "System"
        )
    }

    @MainActor
    func testDesignSystemRendersAllDockStatesInLightAppearance() throws {
        try attachAllDockStateScreenshots(
            mode: .light,
            appKitAppearance: .aqua,
            label: "Light"
        )
    }

    @MainActor
    func testDesignSystemRendersAllDockStatesInDarkAppearance() throws {
        try attachAllDockStateScreenshots(
            mode: .dark,
            appKitAppearance: .darkAqua,
            label: "Dark"
        )
    }

    @MainActor
    private func attachAllDockStateScreenshots(
        mode: DSAppearanceMode,
        appKitAppearance: NSAppearance.Name,
        label: String
    ) throws {

        var numericSystemAppearance = DockFeatureDefaults.systemMetricsAppearance
        numericSystemAppearance.setDisplayStyle(.numeric)
        var numericStorageAppearance = DockFeatureDefaults.storageAppearance
        numericStorageAppearance.setDisplayStyle(.numeric)
        var numericCodexAppearance = DockFeatureDefaults.codexAppearance
        numericCodexAppearance.setDisplayStyle(.numeric)
        var numericClaudeCodeAppearance = DockFeatureDefaults.claudeCodeAppearance
        numericClaudeCodeAppearance.setDisplayStyle(.numeric)

        let presentations: [(String, DockTilePresentation)] = [
            (
                "DockMagic",
                .dockMagic
            ),
            (
                "CPU RAM",
                .systemMetrics(
                    snapshot: SystemMetricsSnapshot(
                        cpuUsage: 0.72,
                        memoryUsage: 0.54,
                        memoryUsedBytes: 540,
                        memoryTotalBytes: 1_000
                    ),
                    appearance: DockFeatureDefaults.systemMetricsAppearance,
                    errorDescription: nil
                )
            ),
            (
                "CPU RAM Unavailable",
                .systemMetrics(
                    snapshot: .zero,
                    appearance: DockFeatureDefaults.systemMetricsAppearance,
                    errorDescription: "Unable to sample system metrics"
                )
            ),
            (
                "CPU RAM Numbers",
                .systemMetrics(
                    snapshot: SystemMetricsSnapshot(
                        cpuUsage: 0.72,
                        memoryUsage: 0.54,
                        memoryUsedBytes: 540,
                        memoryTotalBytes: 1_000
                    ),
                    appearance: numericSystemAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Network",
                .network(
                    history: sampleNetworkHistory(),
                    appearance: DockFeatureDefaults.networkAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Network Waiting",
                .network(
                    history: [],
                    appearance: DockFeatureDefaults.networkAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Network Unavailable",
                .network(
                    history: [],
                    appearance: DockFeatureDefaults.networkAppearance,
                    errorDescription: "No primary interface"
                )
            ),
            (
                "Storage",
                .storage(
                    snapshot: StorageMetricsSnapshot(
                        volumeName: "Macintosh HD",
                        totalBytes: 1_000,
                        availableBytes: 360
                    ),
                    appearance: DockFeatureDefaults.storageAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Storage Waiting",
                .storage(
                    snapshot: .zero,
                    appearance: DockFeatureDefaults.storageAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Storage Unavailable",
                .storage(
                    snapshot: .zero,
                    appearance: DockFeatureDefaults.storageAppearance,
                    errorDescription: "Capacity unavailable"
                )
            ),
            (
                "Storage Numbers",
                .storage(
                    snapshot: StorageMetricsSnapshot(
                        volumeName: "Macintosh HD",
                        totalBytes: 1_000,
                        availableBytes: 360
                    ),
                    appearance: numericStorageAppearance,
                    errorDescription: nil
                )
            ),
            (
                "Weather Idle",
                .weather(state: .idle)
            ),
            (
                "Weather Loading",
                .weather(state: .loading)
            ),
            (
                "Weather Clear",
                .weather(state: .live(sampleWeatherSnapshot()))
            ),
            (
                "Weather Night",
                .weather(
                    state: .live(
                        sampleWeatherSnapshot(
                            condition: .clear,
                            conditionDescription: "Clear",
                            isDaylight: false
                        )
                    )
                )
            ),
            (
                "Weather Stale",
                .weather(
                    state: .stale(
                        sampleWeatherSnapshot(condition: .rain),
                        message: "Open-Meteo request timed out"
                    )
                )
            ),
            (
                "Weather Unavailable",
                .weather(state: .unavailable(message: "Location access denied"))
            ),
            (
                "Clock Analog",
                .clock(
                    date: Date(timeIntervalSince1970: 1_777_777_745),
                    configuration: DockClockConfiguration(
                        displayStyle: .analog,
                        followsSystemTimeZone: false,
                        timeZoneIdentifier: "Asia/Ho_Chi_Minh"
                    )
                )
            ),
            (
                "Clock Digital",
                .clock(
                    date: Date(timeIntervalSince1970: 1_777_777_740),
                    configuration: DockClockConfiguration(
                        displayStyle: .digital,
                        followsSystemTimeZone: false,
                        timeZoneIdentifier: "Asia/Ho_Chi_Minh"
                    )
                )
            ),
            (
                "Clock Split-flap",
                .clock(
                    date: Date(timeIntervalSince1970: 1_777_777_740),
                    configuration: DockClockConfiguration(
                        displayStyle: .splitFlap,
                        followsSystemTimeZone: false,
                        timeZoneIdentifier: "Asia/Ho_Chi_Minh"
                    )
                )
            ),
            (
                "Codex Idle",
                .codex(
                    state: .idle,
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex Loading",
                .codex(
                    state: .loading,
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex Both Windows",
                .codex(
                    state: .live(sampleCodexSnapshot()),
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex Stale",
                .codex(
                    state: .stale(
                        sampleCodexSnapshot(),
                        message: "Using cached limits"
                    ),
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex Weekly Only",
                .codex(
                    state: .live(sampleCodexSnapshot(fiveHour: false)),
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex Unavailable",
                .codex(
                    state: .unavailable(message: "Codex not found"),
                    appearance: DockFeatureDefaults.codexAppearance
                )
            ),
            (
                "Codex Numbers",
                .codex(
                    state: .live(sampleCodexSnapshot()),
                    appearance: numericCodexAppearance
                )
            ),
            (
                "Claude Code Idle",
                .claudeCode(
                    state: .idle,
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude Code Loading",
                .claudeCode(
                    state: .loading,
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude Code Both Windows",
                .claudeCode(
                    state: .live(sampleClaudeCodeSnapshot()),
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude Code Weekly Only",
                .claudeCode(
                    state: .live(sampleCodexSnapshot(fiveHour: false)),
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude Code Stale",
                .claudeCode(
                    state: .stale(
                        sampleClaudeCodeSnapshot(),
                        message: "Using cached limits"
                    ),
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude Code Unavailable",
                .claudeCode(
                    state: .unavailable(message: "Enable the bridge"),
                    appearance: DockFeatureDefaults.claudeCodeAppearance
                )
            ),
            (
                "Claude Code Numbers",
                .claudeCode(
                    state: .live(sampleClaudeCodeSnapshot()),
                    appearance: numericClaudeCodeAppearance
                )
            )
        ]

        for side in [32, 48, 64, 128] {
            for presentation in presentations {
                try attachScreenshot(
                    of: DockMagicThemeRoot(
                        content: DockTileView(
                            presentation: presentation.1,
                            animatesChanges: false
                        ),
                        appearanceMode: mode
                    ),
                    size: NSSize(width: side, height: side),
                    appearanceName: appKitAppearance,
                    name: "Dock — \(presentation.0) — \(side) pt — \(label)",
                    attachmentLifetime: .deleteOnSuccess
                )
            }
        }
    }

    @MainActor
    func testClockStylesRenderAcrossAppearanceAndAccessibilityVariants() throws {
        let date = Date(timeIntervalSince1970: 1_777_777_745)
        let size = NSSize(width: 128, height: 128)
        var lightRenders: [DockClockDisplayStyle: Data] = [:]

        for style in DockClockDisplayStyle.allCases {
            let configuration = DockClockConfiguration(
                displayStyle: style,
                followsSystemTimeZone: false,
                timeZoneIdentifier: "Asia/Ho_Chi_Minh"
            )
            let presentation = DockTilePresentation.clock(
                date: configuration.presentationDate(for: date),
                configuration: configuration
            )
            let lightName = "Clock — \(style.title) — Light"
            let light = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false
                    ),
                    appearanceMode: .light
                ),
                size: size,
                appearanceName: .aqua,
                name: lightName
            )
            let darkName = "Clock — \(style.title) — Dark"
            let dark = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false
                    ),
                    appearanceMode: .dark
                ),
                size: size,
                appearanceName: .darkAqua,
                name: darkName
            )
            let contrastName = "Clock — \(style.title) — Increased Contrast"
            let increasedContrast = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false
                    ),
                    appearanceMode: .light
                )
                .environment(
                    \.dsAccessibilityOverrides,
                    DSAccessibilityOverrides(increaseContrast: true)
                ),
                size: size,
                appearanceName: .aqua,
                name: contrastName
            )
            let transparencyName = "Clock — \(style.title) — Reduced Transparency"
            let reducedTransparency = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false
                    ),
                    appearanceMode: .light
                )
                .environment(
                    \.dsAccessibilityOverrides,
                    DSAccessibilityOverrides(reduceTransparency: true)
                ),
                size: size,
                appearanceName: .aqua,
                name: transparencyName
            )
            let grayscaleName = "Clock — \(style.title) — Grayscale"
            let grayscale = try grayscalePNG(light, name: grayscaleName)

            let variants = [
                (lightName, light),
                (darkName, dark),
                (contrastName, increasedContrast),
                (transparencyName, reducedTransparency),
                (grayscaleName, grayscale)
            ]
            for (name, data) in variants {
                XCTAssertGreaterThan(
                    data.count,
                    1_000,
                    "\(name) should render a non-empty Clock image."
                )
                let lifetime: XCTAttachment.Lifetime =
                    name == lightName || name == darkName
                    ? .keepAlways
                    : .deleteOnSuccess
                attachPNG(data, name: name, lifetime: lifetime)
            }
            XCTAssertNotEqual(light, increasedContrast)
            XCTAssertEqual(
                light,
                reducedTransparency,
                "Clock uses only opaque Dock surfaces, so Reduce Transparency must not remove information."
            )
            XCTAssertNotEqual(light, grayscale)
            lightRenders[style] = light
        }

        XCTAssertNotEqual(lightRenders[.analog], lightRenders[.digital])
        XCTAssertNotEqual(lightRenders[.digital], lightRenders[.splitFlap])
        XCTAssertNotEqual(lightRenders[.analog], lightRenders[.splitFlap])
    }

    @MainActor
    func testClockDigitalAndSplitFlapTransitionFramesRenderDistinctly() throws {
        let previousDate = Date(timeIntervalSince1970: 1_777_777_680)
        let date = previousDate.addingTimeInterval(60)
        let size = NSSize(width: 128, height: 128)

        for style in [DockClockDisplayStyle.digital, .splitFlap] {
            let configuration = DockClockConfiguration(
                displayStyle: style,
                followsSystemTimeZone: false,
                timeZoneIdentifier: "UTC"
            )
            let previousPresentation = DockTilePresentation.clock(
                date: previousDate,
                configuration: configuration
            )
            let presentation = DockTilePresentation.clock(
                date: date,
                configuration: configuration
            )
            let previous = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: previousPresentation,
                        animatesChanges: false
                    ),
                    appearanceMode: .dark
                ),
                size: size,
                appearanceName: .darkAqua,
                name: "Clock animation — \(style.title) — Previous"
            )
            let early = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false,
                        clockTransition: DockClockTransition(
                            previousDate: previousDate,
                            progress: 0.25
                        )
                    ),
                    appearanceMode: .dark
                ),
                size: size,
                appearanceName: .darkAqua,
                name: "Clock animation — \(style.title) — Early"
            )
            let late = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false,
                        clockTransition: DockClockTransition(
                            previousDate: previousDate,
                            progress: 0.75
                        )
                    ),
                    appearanceMode: .dark
                ),
                size: size,
                appearanceName: .darkAqua,
                name: "Clock animation — \(style.title) — Late"
            )
            let settled = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false
                    ),
                    appearanceMode: .dark
                ),
                size: size,
                appearanceName: .darkAqua,
                name: "Clock animation — \(style.title) — Settled"
            )
            let reducedMotion = try renderPNG(
                of: DockMagicThemeRoot(
                    content: DockTileView(
                        presentation: presentation,
                        animatesChanges: false,
                        clockTransition: DockClockTransition(
                            previousDate: previousDate,
                            progress: 0.5
                        )
                    ),
                    appearanceMode: .dark
                )
                .environment(
                    \.dsAccessibilityOverrides,
                    DSAccessibilityOverrides(reduceMotion: true)
                ),
                size: size,
                appearanceName: .darkAqua,
                name: "Clock animation — \(style.title) — Reduce Motion"
            )

            XCTAssertNotEqual(previous, early)
            XCTAssertNotEqual(early, late)
            XCTAssertNotEqual(late, settled)
            XCTAssertEqual(reducedMotion, settled)
            attachPNG(
                early,
                name: "Clock animation — \(style.title) — Early",
                lifetime: .keepAlways
            )
            attachPNG(
                late,
                name: "Clock animation — \(style.title) — Late",
                lifetime: .keepAlways
            )
        }
    }

    @MainActor
    func testClockAnimationFramesPreserveApplicationIconSourceContract() throws {
        let previousDate = Date(timeIntervalSince1970: 1_777_777_680)
        let date = previousDate.addingTimeInterval(60)
        let renderer = DockApplicationIconRenderer()

        for style in [DockClockDisplayStyle.digital, .splitFlap] {
            let presentation = DockTilePresentation.clock(
                date: date,
                configuration: DockClockConfiguration(
                    displayStyle: style,
                    followsSystemTimeZone: false,
                    timeZoneIdentifier: "UTC"
                )
            )
            let early = try XCTUnwrap(
                renderer.render(
                    presentation: presentation,
                    appearanceMode: .dark,
                    clockTransition: DockClockTransition(
                        previousDate: previousDate,
                        progress: 0.25
                    )
                )
            )
            let late = try XCTUnwrap(
                renderer.render(
                    presentation: presentation,
                    appearanceMode: .dark,
                    clockTransition: DockClockTransition(
                        previousDate: previousDate,
                        progress: 0.75
                    )
                )
            )

            XCTAssertTrue(DockIconRenderingRules.satisfiesSourceContract(early))
            XCTAssertTrue(DockIconRenderingRules.satisfiesSourceContract(late))
            XCTAssertNotEqual(early.tiffRepresentation, late.tiffRepresentation)
        }
    }

    @MainActor
    func testClockSettingsRenderGeneralAndLocationChoices() throws {
        let appModel = makeAppModel()
        defer { appModel.stop() }
        appModel.preferences.activeFeature = .clock
        let defaults = makeAppearanceDefaults(.light)
        let size = NSSize(width: 1_020, height: 740)

        let generalName = "Settings — General — Clock Active"
        let general = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(
                    appModel: appModel,
                    initialDestination: .general
                )
                .defaultAppStorage(defaults),
                appearanceMode: .light
            ),
            size: size,
            appearanceName: .aqua,
            name: generalName
        )
        let currentName = "Settings — Clock — Current Location"
        let currentLocation = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(
                    appModel: appModel,
                    initialDestination: .clock
                )
                .defaultAppStorage(defaults),
                appearanceMode: .light
            ),
            size: size,
            appearanceName: .aqua,
            name: currentName
        )

        appModel.preferences.setClockDisplayStyle(.splitFlap)
        appModel.preferences.setClockFollowsSystemTimeZone(false)
        appModel.preferences.setClockTimeZoneIdentifier("America/New_York")
        let customName = "Settings — Clock — New York Split-flap"
        let customLocation = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(
                    appModel: appModel,
                    initialDestination: .clock
                )
                .defaultAppStorage(defaults),
                appearanceMode: .light
            ),
            size: size,
            appearanceName: .aqua,
            name: customName
        )

        for (name, data) in [
            (generalName, general),
            (currentName, currentLocation),
            (customName, customLocation)
        ] {
            XCTAssertGreaterThan(data.count, 10_000)
            attachPNG(data, name: name)
        }
        XCTAssertNotEqual(currentLocation, customLocation)
    }

    @MainActor
    func testSigmaAppearanceAndAccessibilityVariantsRenderDistinctSettings() throws {
        let appModel = makeAppModel()
        let size = NSSize(width: 1_020, height: 740)
        let appearanceDefaults = makeAppearanceDefaults(.light)

        let light = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(appModel: appModel)
                    .defaultAppStorage(appearanceDefaults),
                appearanceMode: .light
            ),
            size: size,
            appearanceName: .aqua,
            name: "Settings — General — Light"
        )
        appearanceDefaults.set(
            DSAppearanceMode.dark.rawValue,
            forKey: DSAppearanceMode.storageKey
        )
        let dark = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(appModel: appModel)
                    .defaultAppStorage(appearanceDefaults),
                appearanceMode: .dark
            ),
            size: size,
            appearanceName: .darkAqua,
            name: "Settings — General — Dark"
        )
        let reducedTransparency = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(appModel: appModel)
                    .defaultAppStorage(appearanceDefaults)
                    .environment(
                        \.dsAccessibilityOverrides,
                        DSAccessibilityOverrides(reduceTransparency: true)
                    ),
                appearanceMode: .light
            ),
            size: size,
            appearanceName: .aqua,
            name: "Settings — General — Reduced Transparency"
        )
        let increasedContrast = try renderPNG(
            of: DockMagicThemeRoot(
                content: SettingsView(appModel: appModel)
                    .defaultAppStorage(appearanceDefaults)
                    .environment(
                        \.dsAccessibilityOverrides,
                        DSAccessibilityOverrides(increaseContrast: true)
                    ),
                appearanceMode: .light
            ),
            size: size,
            appearanceName: .aqua,
            name: "Settings — General — Increased Contrast"
        )

        let variants = [
            ("Settings — General — Light", light),
            ("Settings — General — Dark", dark),
            ("Settings — General — Reduced Transparency", reducedTransparency),
            ("Settings — General — Increased Contrast", increasedContrast)
        ]
        for variant in variants {
            XCTAssertGreaterThan(
                variant.1.count,
                10_000,
                "\(variant.0) should render a non-empty settings image."
            )
            attachPNG(variant.1, name: variant.0)
        }

        XCTAssertNotEqual(light, dark)
        XCTAssertNotEqual(light, reducedTransparency)
        XCTAssertNotEqual(light, increasedContrast)
        assertPixelDifference(
            light,
            dark,
            minimumChangedFraction: 0.20,
            label: "Light versus Dark"
        )
        assertPixelDifference(
            light,
            reducedTransparency,
            minimumChangedFraction: 0.002,
            label: "Light Glass versus Reduce Transparency"
        )
        assertPixelDifference(
            light,
            increasedContrast,
            minimumChangedFraction: 0.001,
            label: "Light Glass versus Increase Contrast"
        )
    }

    @MainActor
    private func makeAppModel(
        weatherAuthorization: WeatherLocationAuthorization = .authorized
    ) -> DockAppModel {
        let suiteName = "DockMagicTests.Model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let preferences = DockPreferencesStore(defaults: defaults)
        let metrics = SystemMetricsStore(
            sampler: SequenceMetricsSampler(cpuValues: [0.42])
        )
        let network = NetworkMetricsStore(
            sampler: SequenceNetworkSampler(sampleNetworkHistory())
        )
        let storage = StorageMetricsStore(
            sampler: SequenceStorageSampler([
                StorageMetricsSnapshot(
                    volumeName: "Macintosh HD",
                    totalBytes: 1_000,
                    availableBytes: 360
                )
            ])
        )
        let codex = CodexUsageStore(
            provider: ScriptedCodexProvider([.success(sampleCodexSnapshot())]),
            locator: StubCodexLocator(),
            pollingInterval: .seconds(60)
        )
        let weather = WeatherStore(
            provider: ScriptedWeatherProvider([
                .success(sampleWeatherSnapshot())
            ]),
            authorizationProvider: MutableWeatherAuthorizationProvider(
                weatherAuthorization
            ),
            cache: InMemoryWeatherCache(),
            pollingInterval: .seconds(60)
        )
        let claudeCode = ClaudeCodeUsageStore(
            provider: ScriptedClaudeCodeProvider([
                .success(sampleClaudeCodeSnapshot())
            ]),
            bridge: StubClaudeCodeBridge(installed: true),
            pollingInterval: .seconds(60)
        )
        return DockAppModel(
            preferences: preferences,
            metricsStore: metrics,
            networkStore: network,
            storageStore: storage,
            weatherStore: weather,
            codexStore: codex,
            claudeCodeStore: claudeCode
        )
    }

    private func makeAppearanceDefaults(
        _ mode: DSAppearanceMode
    ) -> UserDefaults {
        let suiteName = "DockMagicTests.AppearanceRender.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(mode.rawValue, forKey: DSAppearanceMode.storageKey)
        return defaults
    }

    private func sampleNetworkHistory() -> [NetworkMetricsSnapshot] {
        (0..<60).map { index in
            let wave = Double(index % 12) / 11
            return NetworkMetricsSnapshot(
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                interfaceName: "en0",
                downloadBytesPerSecond: 128_000 + wave * 3_000_000,
                uploadBytesPerSecond: 32_000 + (1 - wave) * 750_000
            )
        }
    }

    private func sampleCodexSnapshot(
        fiveHour: Bool = true
    ) -> CodexRateLimitSnapshot {
        CodexRateLimitSnapshot(
            planType: "pro",
            limitID: "codex",
            fiveHour: fiveHour
                ? CodexRateLimitWindow(
                    kind: .fiveHour,
                    usedPercent: 28,
                    windowDurationMinutes: 300,
                    resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
                )
                : nil,
            weekly: CodexRateLimitWindow(
                kind: .weekly,
                usedPercent: 42,
                windowDurationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 2_000_500_000)
            ),
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }

    private func sampleClaudeCodeSnapshot(
        fetchedAt: Date = .now
    ) -> ClaudeCodeRateLimitSnapshot {
        ClaudeCodeRateLimitSnapshot(
            planType: nil,
            limitID: "claude-code",
            fiveHour: ClaudeCodeRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 31,
                windowDurationMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            weekly: ClaudeCodeRateLimitWindow(
                kind: .weekly,
                usedPercent: 47,
                windowDurationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 2_000_500_000)
            ),
            fetchedAt: fetchedAt
        )
    }

    private func sampleWeatherSnapshot(
        condition: WeatherCondition = .partlyCloudy,
        conditionDescription: String = "Partly Cloudy",
        isDaylight: Bool = true,
        observedAt: Date = .now,
        fetchedAt: Date = .now
    ) -> WeatherSnapshot {
        let startOfDay = Calendar.current.startOfDay(for: observedAt)
        let forecast = (0 ..< 7).compactMap { dayOffset -> DailyWeatherForecast? in
            guard let date = Calendar.current.date(
                byAdding: .day,
                value: dayOffset,
                to: startOfDay
            ) else {
                return nil
            }
            return DailyWeatherForecast(
                date: date,
                conditionDescription: dayOffset == 0
                    ? conditionDescription
                    : "Thunderstorm",
                condition: dayOffset == 0 ? condition : .thunderstorm,
                highCelsius: Double(33 - (dayOffset % 3)),
                lowCelsius: Double(25 + (dayOffset % 2)),
                precipitationChance: Double(20 + dayOffset * 10) / 100
            )
        }
        return WeatherSnapshot(
            location: "Ho Chi Minh City",
            temperatureCelsius: 29,
            feelsLikeCelsius: 32,
            conditionDescription: conditionDescription,
            condition: condition,
            highCelsius: 33,
            lowCelsius: 26,
            precipitationChance: 0.2,
            relativeHumidity: 0.76,
            windSpeedKPH: 13,
            forecast: forecast,
            isDaylight: isDaylight,
            observedAt: observedAt,
            fetchedAt: fetchedAt
        )
    }

    private func openMeteoFixture() -> Data {
        Data(
            """
            {
              "latitude": 10.875,
              "longitude": 106.625,
              "generationtime_ms": 0.1,
              "utc_offset_seconds": 25200,
              "timezone": "Asia/Ho_Chi_Minh",
              "timezone_abbreviation": "+07",
              "elevation": 10,
              "current_units": {
                "time": "iso8601",
                "interval": "seconds",
                "temperature_2m": "°C",
                "apparent_temperature": "°C",
                "relative_humidity_2m": "%",
                "weather_code": "wmo code",
                "is_day": "",
                "wind_speed_10m": "km/h"
              },
              "current": {
                "time": "1970-01-01T07:30",
                "interval": 900,
                "temperature_2m": 29.4,
                "apparent_temperature": 32,
                "relative_humidity_2m": 89,
                "weather_code": 2,
                "is_day": 1,
                "wind_speed_10m": 12.9
              },
              "daily_units": {
                "time": "iso8601",
                "weather_code": "wmo code",
                "temperature_2m_max": "°C",
                "temperature_2m_min": "°C",
                "precipitation_probability_max": "%"
              },
              "daily": {
                "time": [
                  "1970-01-01", "1970-01-02", "1970-01-03", "1970-01-04",
                  "1970-01-05", "1970-01-06", "1970-01-07"
                ],
                "weather_code": [2, 95, 61, 80, 3, 51, 99],
                "temperature_2m_max": [33, 32, 31, 32, 33, 33, 34],
                "temperature_2m_min": [26, 25, 25, 24, 24, 25, 26],
                "precipitation_probability_max": [25, 60, 55, 70, 40, 65, 75]
              }
            }
            """.utf8
        )
    }

    private func claudeRateLimits(
        fiveHourUsed: Double?,
        weeklyUsed: Double?
    ) -> Data {
        var rateLimits: [String: Any] = [:]
        if let fiveHourUsed {
            rateLimits["five_hour"] = [
                "used_percentage": fiveHourUsed,
                "resets_at": 2_000_000_000
            ]
        }
        if let weeklyUsed {
            rateLimits["seven_day"] = [
                "used_percentage": weeklyUsed,
                "resets_at": 2_000_500_000
            ]
        }
        return try! JSONSerialization.data(
            withJSONObject: ["rate_limits": rateLimits]
        )
    }

    private func codexResponse(
        fallback: [String: Any],
        buckets: [String: [String: Any]]? = nil
    ) -> Data {
        var result: [String: Any] = ["rateLimits": fallback]
        if let buckets {
            result["rateLimitsByLimitId"] = buckets
        }
        let response: [String: Any] = ["id": 2, "result": result]
        let data = try! JSONSerialization.data(withJSONObject: response)
        return data + Data([0x0A])
    }

    private func codexTokenUsageResponse(
        lifetimeTokens: Int64,
        dailyTokens: [Int64]
    ) -> Data {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 18
        ))!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let response: [String: Any] = [
            "id": 3,
            "result": [
                "summary": [
                    "lifetimeTokens": lifetimeTokens,
                    "peakDailyTokens": dailyTokens.max() ?? 0,
                    "currentStreakDays": 7,
                    "longestStreakDays": 28,
                    "longestRunningTurnSec": 1_460
                ],
                "dailyUsageBuckets": dailyTokens.enumerated().map {
                    index, tokens in
                    [
                        "startDate": formatter.string(from: calendar.date(
                            byAdding: .day,
                            value: index,
                            to: startDate
                        )!),
                        "tokens": tokens
                    ] as [String: Any]
                }
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: response)
        return data + Data([0x0A])
    }

    private func codexThreadListResponse(
        id: Int,
        threads: [[String: Any]],
        nextCursor: String? = nil
    ) -> Data {
        var result: [String: Any] = [
            "data": threads,
            "nextCursor": NSNull()
        ]
        if let nextCursor {
            result["nextCursor"] = nextCursor
        }
        let response: [String: Any] = [
            "id": id,
            "result": result
        ]
        let data = try! JSONSerialization.data(withJSONObject: response)
        return data + Data([0x0A])
    }

    private func codexThreadUsageResponse(
        id: Int,
        threadID: String,
        groups: [(model: String, tokens: Int64)]
    ) -> Data {
        let response: [String: Any] = [
            "id": id,
            "result": [
                "threadUsage": [
                    "threadId": threadID,
                    "groups": groups.map { group in
                        [
                            "model": group.model,
                            "totalTokens": group.tokens
                        ] as [String: Any]
                    }
                ]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: response)
        return data + Data([0x0A])
    }

    private func rateLimitBucket(
        limitID: String,
        primaryDuration: Int,
        primaryUsed: Int,
        secondaryDuration: Int? = nil,
        secondaryUsed: Int? = nil
    ) -> [String: Any] {
        var bucket: [String: Any] = [
            "limitId": limitID,
            "planType": "pro",
            "primary": [
                "windowDurationMins": primaryDuration,
                "usedPercent": primaryUsed,
                "resetsAt": 2_000_000_000
            ]
        ]
        if let secondaryDuration, let secondaryUsed {
            bucket["secondary"] = [
                "windowDurationMins": secondaryDuration,
                "usedPercent": secondaryUsed,
                "resetsAt": 2_000_500_000
            ]
        }
        return bucket
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now >= deadline {
                XCTFail("Timed out waiting for condition.")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    private func assertColorAsset(
        _ name: String,
        appearanceName: NSAppearance.Name,
        expectedHex: String,
        expectedAlpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let appearance = NSAppearance(named: appearanceName) else {
            return XCTFail(
                "Unable to create appearance \(appearanceName.rawValue).",
                file: file,
                line: line
            )
        }
        guard expectedHex.hasPrefix("#"),
              let value = UInt32(expectedHex.dropFirst(), radix: 16) else {
            return XCTFail(
                "Invalid expected hex \(expectedHex).",
                file: file,
                line: line
            )
        }

        appearance.performAsCurrentDrawingAppearance {
            guard let color = NSColor(
                named: NSColor.Name(name),
                bundle: Bundle(for: AppDelegate.self)
            )?.usingColorSpace(.sRGB) else {
                return XCTFail(
                    "Missing or unresolved color asset \(name).",
                    file: file,
                    line: line
                )
            }

            XCTAssertEqual(
                color.redComponent,
                CGFloat((value >> 16) & 0xFF) / 255,
                accuracy: 0.002,
                file: file,
                line: line
            )
            XCTAssertEqual(
                color.greenComponent,
                CGFloat((value >> 8) & 0xFF) / 255,
                accuracy: 0.002,
                file: file,
                line: line
            )
            XCTAssertEqual(
                color.blueComponent,
                CGFloat(value & 0xFF) / 255,
                accuracy: 0.002,
                file: file,
                line: line
            )
            XCTAssertEqual(
                color.alphaComponent,
                expectedAlpha,
                accuracy: 0.002,
                file: file,
                line: line
            )
        }
    }

    private func assertContrast(
        _ foregroundName: String,
        on backgroundName: String,
        minimum: Double,
        appearance: String,
        foregroundOpacity: CGFloat = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let bundle = Bundle(for: AppDelegate.self)
        guard let foreground = NSColor(
            named: NSColor.Name(foregroundName),
            bundle: bundle
        ) else {
            XCTFail(
                "Missing color asset \(foregroundName).",
                file: file,
                line: line
            )
            return
        }
        guard let background = NSColor(
            named: NSColor.Name(backgroundName),
            bundle: bundle
        ) else {
            XCTFail(
                "Missing color asset \(backgroundName).",
                file: file,
                line: line
            )
            return
        }
        guard let ratio = contrastRatio(
            foreground: foreground,
            background: background,
            foregroundOpacity: foregroundOpacity
        ) else {
            XCTFail(
                "Unable to resolve \(foregroundName) on \(backgroundName).",
                file: file,
                line: line
            )
            return
        }

        XCTAssertGreaterThanOrEqual(
            ratio,
            minimum,
            "\(appearance): \(foregroundName) on \(backgroundName) is "
                + "\(ratio.formatted(.number.precision(.fractionLength(2)))):1.",
            file: file,
            line: line
        )
    }

    private func contrastRatio(
        foreground: NSColor,
        background: NSColor,
        foregroundOpacity: CGFloat = 1
    ) -> Double? {
        guard let foreground = foreground.usingColorSpace(.sRGB),
              let background = background.usingColorSpace(.sRGB) else {
            return nil
        }

        let alpha = foreground.alphaComponent
            * min(max(foregroundOpacity, 0), 1)
        let foregroundComponents = [
            foreground.redComponent,
            foreground.greenComponent,
            foreground.blueComponent
        ]
        let backgroundComponents = [
            background.redComponent,
            background.greenComponent,
            background.blueComponent
        ]
        let composited = zip(foregroundComponents, backgroundComponents).map {
            $0 * alpha + $1 * (1 - alpha)
        }
        let foregroundLuminance = relativeLuminance(composited)
        let backgroundLuminance = relativeLuminance(backgroundComponents)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ components: [CGFloat]) -> Double {
        let linear = components.map { component -> Double in
            let value = Double(component)
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0]
            + 0.7152 * linear[1]
            + 0.0722 * linear[2]
    }

    private func assertPixelDifference(
        _ first: Data,
        _ second: Data,
        minimumChangedFraction: Double,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let firstImage = NSBitmapImageRep(data: first),
              let secondImage = NSBitmapImageRep(data: second),
              firstImage.pixelsWide == secondImage.pixelsWide,
              firstImage.pixelsHigh == secondImage.pixelsHigh else {
            return XCTFail(
                "Unable to compare rendered pixels for \(label).",
                file: file,
                line: line
            )
        }

        var changed = 0
        var sampled = 0
        let sampleStep = 4
        for y in stride(from: 0, to: firstImage.pixelsHigh, by: sampleStep) {
            for x in stride(from: 0, to: firstImage.pixelsWide, by: sampleStep) {
                guard let firstColor = firstImage.colorAt(x: x, y: y)?
                    .usingColorSpace(.sRGB),
                      let secondColor = secondImage.colorAt(x: x, y: y)?
                    .usingColorSpace(.sRGB) else {
                    continue
                }

                sampled += 1
                let maximumDelta = max(
                    abs(firstColor.redComponent - secondColor.redComponent),
                    abs(firstColor.greenComponent - secondColor.greenComponent),
                    abs(firstColor.blueComponent - secondColor.blueComponent),
                    abs(firstColor.alphaComponent - secondColor.alphaComponent)
                )
                if maximumDelta >= 0.02 {
                    changed += 1
                }
            }
        }

        guard sampled > 0 else {
            return XCTFail(
                "No pixels were sampled for \(label).",
                file: file,
                line: line
            )
        }
        let fraction = Double(changed) / Double(sampled)
        XCTAssertGreaterThanOrEqual(
            fraction,
            minimumChangedFraction,
            "\(label) changed only "
                + fraction.formatted(.percent.precision(.fractionLength(2)))
                + " of sampled pixels.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func attachScreenshot<Content: View>(
        of content: Content,
        size: NSSize,
        appearanceName: NSAppearance.Name = .aqua,
        name: String,
        attachmentLifetime: XCTAttachment.Lifetime = .keepAlways
    ) throws {
        let data = try renderPNG(
            of: content,
            size: size,
            appearanceName: appearanceName,
            name: name
        )
        attachPNG(data, name: name, lifetime: attachmentLifetime)
    }

    @MainActor
    private func renderPNG<Content: View>(
        of content: Content,
        size: NSSize,
        appearanceName: NSAppearance.Name,
        name: String
    ) throws -> Data {
        try autoreleasepool {
            let hostingView = NSHostingView(rootView: content)
            hostingView.appearance = NSAppearance(named: appearanceName)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: appearanceName)
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.contentView = hostingView

            defer {
                window.contentView = nil
                window.close()
            }

            hostingView.wantsLayer = true
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            guard let representation = hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            ) else {
                XCTFail("Unable to allocate bitmap for \(name).")
                throw RenderingError.bitmapAllocationFailed
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
            guard let data = representation.representation(
                using: .png,
                properties: [:]
            ) else {
                XCTFail("Unable to encode \(name).")
                throw RenderingError.pngEncodingFailed
            }

            return data
        }
    }

    @MainActor
    private func renderExistingViewPNG(
        _ view: NSView,
        name: String
    ) throws -> Data {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let representation = view.bitmapImageRepForCachingDisplay(
            in: view.bounds
        ) else {
            XCTFail("Unable to allocate bitmap for \(name).")
            throw RenderingError.bitmapAllocationFailed
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(
            using: .png,
            properties: [:]
        ) else {
            XCTFail("Unable to encode \(name).")
            throw RenderingError.pngEncodingFailed
        }
        return data
    }

    private func attachPNG(
        _ data: Data,
        name: String,
        lifetime: XCTAttachment.Lifetime = .keepAlways
    ) {
        let attachment = XCTAttachment(
            data: data,
            uniformTypeIdentifier: "public.png"
        )
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
    }

    private func grayscalePNG(_ data: Data, name: String) throws -> Data {
        guard let input = CIImage(data: data),
              let filter = CIFilter(name: "CIColorControls") else {
            XCTFail("Unable to decode \(name) for grayscale verification.")
            throw RenderingError.grayscaleConversionFailed
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(0, forKey: kCIInputSaturationKey)
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(
                output,
                from: output.extent
              ),
              let encoded = NSBitmapImageRep(cgImage: cgImage).representation(
                using: .png,
                properties: [:]
              ) else {
            XCTFail("Unable to encode grayscale verification for \(name).")
            throw RenderingError.grayscaleConversionFailed
        }
        return encoded
    }

    @MainActor
    private func firstSubview<ViewType: NSView>(
        of type: ViewType.Type,
        in root: NSView
    ) -> ViewType? {
        if let match = root as? ViewType {
            return match
        }
        for subview in root.subviews {
            if let match = firstSubview(of: type, in: subview) {
                return match
            }
        }
        return nil
    }

    @MainActor
    private func countTrackingAreas(in root: NSView) -> Int {
        root.trackingAreas.count
            + root.subviews.reduce(0) { count, subview in
                count + countTrackingAreas(in: subview)
            }
    }

    private enum RenderingError: Error {
        case bitmapAllocationFailed
        case grayscaleConversionFailed
        case pngEncodingFailed
    }
}

@MainActor
private final class CodexHoverTestState {
    var hoveredBucketID: Date?
    var selectedBucketID: Date?
}

private func codexRolloutFixture(
    model: String,
    events: [(
        date: Date,
        input: Int64,
        cachedInput: Int64,
        output: Int64
    )]
) throws -> Data {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds
    ]
    var data = Data()

    func appendLine(_ object: [String: Any]) throws {
        data.append(try JSONSerialization.data(withJSONObject: object))
        data.append(0x0A)
    }

    if let firstDate = events.first?.date {
        try appendLine([
            "timestamp": formatter.string(
                from: firstDate.addingTimeInterval(-60)
            ),
            "type": "turn_context",
            "payload": ["model": model]
        ])
    }
    for event in events {
        try appendLine([
            "timestamp": formatter.string(from: event.date),
            "type": "event_msg",
            "payload": [
                "type": "token_count",
                "info": [
                    "last_token_usage": [
                        "input_tokens": event.input,
                        "cached_input_tokens": event.cachedInput,
                        "cache_write_input_tokens": 0,
                        "output_tokens": event.output,
                        "reasoning_output_tokens": event.output / 2,
                        "total_tokens": event.input + event.output
                    ]
                ]
            ]
        ])
    }
    return data
}

private func sqlString(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "''")
}

private actor CodexDailyDetailLoadCounter {
    private(set) var callCount = 0

    func load(date: Date) async throws -> CodexDailyTokenDetail? {
        callCount += 1
        try await Task.sleep(for: .milliseconds(40))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.startOfDay(for: date)
        let usage = CodexTokenBreakdown(
            inputTokens: 80,
            cachedInputTokens: 60,
            cacheWriteInputTokens: 0,
            outputTokens: 20,
            reasoningOutputTokens: 10,
            totalTokens: 100
        )
        return CodexDailyTokenDetail(
            startDate: day,
            usage: usage,
            hourlyUsage: [],
            modelUsage: [
                CodexDailyModelTokenUsage(model: "gpt-test", usage: usage)
            ],
            isPartial: false
        )
    }
}

private actor SequenceMetricsSampler: SystemMetricsSampling {
    private let cpuValues: [Double]
    private var index = 0

    init(cpuValues: [Double]) {
        self.cpuValues = cpuValues
    }

    func sample() async throws -> SystemMetricsSnapshot {
        let value = cpuValues[min(index, cpuValues.count - 1)]
        index += 1
        return SystemMetricsSnapshot(
            timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
            cpuUsage: value,
            memoryUsage: 0.5,
            memoryUsedBytes: 500,
            memoryTotalBytes: 1_000
        )
    }
}

private actor CountingMetricsSampler: SystemMetricsSampling {
    private(set) var callCount = 0
    private(set) var resetCallCount = 0

    func reset() {
        resetCallCount += 1
    }

    func sample() async throws -> SystemMetricsSnapshot {
        callCount += 1
        return SystemMetricsSnapshot(
            cpuUsage: 0.25,
            memoryUsage: 0.5,
            memoryUsedBytes: 500,
            memoryTotalBytes: 1_000
        )
    }
}

private actor SequenceNetworkCounterReader: NetworkCounterReading {
    private var counters: [NetworkInterfaceCounters]

    init(_ counters: [NetworkInterfaceCounters]) {
        precondition(!counters.isEmpty)
        self.counters = counters
    }

    func readCounters() async throws -> NetworkInterfaceCounters {
        if counters.count > 1 {
            return counters.removeFirst()
        }
        return counters[0]
    }
}

private final class LockedDateSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var dates: [Date]

    init(_ dates: [Date]) {
        precondition(!dates.isEmpty)
        self.dates = dates
    }

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        if dates.count > 1 {
            return dates.removeFirst()
        }
        return dates[0]
    }
}

private actor SequenceNetworkSampler: NetworkMetricsSampling {
    private let snapshots: [NetworkMetricsSnapshot]
    private var index = 0

    init(_ snapshots: [NetworkMetricsSnapshot]) {
        precondition(!snapshots.isEmpty)
        self.snapshots = snapshots
    }

    func reset() {
        index = 0
    }

    func sample() async throws -> NetworkMetricsSnapshot {
        let snapshot = snapshots[min(index, snapshots.count - 1)]
        index += 1
        return snapshot
    }
}

private actor CountingNetworkSampler: NetworkMetricsSampling {
    private(set) var callCount = 0
    private(set) var resetCallCount = 0

    func reset() {
        resetCallCount += 1
    }

    func sample() async throws -> NetworkMetricsSnapshot {
        callCount += 1
        return NetworkMetricsSnapshot(
            timestamp: Date(timeIntervalSince1970: TimeInterval(callCount)),
            interfaceName: "en0",
            downloadBytesPerSecond: Double(callCount * 1_000),
            uploadBytesPerSecond: Double(callCount * 500)
        )
    }
}

private actor SequenceStorageSampler: StorageMetricsSampling {
    private let snapshots: [StorageMetricsSnapshot]
    private var index = 0

    init(_ snapshots: [StorageMetricsSnapshot]) {
        precondition(!snapshots.isEmpty)
        self.snapshots = snapshots
    }

    func sample() async throws -> StorageMetricsSnapshot {
        let snapshot = snapshots[min(index, snapshots.count - 1)]
        index += 1
        return snapshot
    }
}

private actor CountingStorageSampler: StorageMetricsSampling {
    private(set) var callCount = 0

    func sample() async throws -> StorageMetricsSnapshot {
        callCount += 1
        return StorageMetricsSnapshot(
            timestamp: Date(timeIntervalSince1970: TimeInterval(callCount)),
            volumeName: "Macintosh HD",
            totalBytes: 1_000,
            availableBytes: 400
        )
    }
}

private actor ScriptedCodexProvider: CodexRateLimitProviding {
    private var results: [Result<CodexRateLimitSnapshot, Error>]

    init(_ results: [Result<CodexRateLimitSnapshot, Error>]) {
        self.results = results
    }

    func fetchRateLimits(executableURL: URL) async throws
        -> CodexRateLimitSnapshot {
        guard !results.isEmpty else {
            throw CodexRateLimitProviderError.invalidResponse
        }
        return try results.removeFirst().get()
    }
}

@MainActor
private final class StubDockHoverAccessibilityAuthorizer:
    DockHoverAccessibilityAuthorizing
{
    var trusted = false
    var promptResult = false
    private(set) var promptCount = 0

    func isTrusted() -> Bool {
        trusted
    }

    func requestTrustPrompt() -> Bool {
        promptCount += 1
        return promptResult
    }
}

private actor CancellableCodexProvider: CodexRateLimitProviding {
    private(set) var callCount = 0
    private(set) var cancellationCount = 0

    func fetchRateLimits(executableURL: URL) async throws
        -> CodexRateLimitSnapshot {
        callCount += 1

        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            cancellationCount += 1
            throw error
        }

        throw CodexRateLimitProviderError.timedOut
    }
}

private actor DelayedCodexProvider: CodexRateLimitProviding {
    private(set) var callCount = 0
    let snapshot: CodexRateLimitSnapshot

    init(snapshot: CodexRateLimitSnapshot) {
        self.snapshot = snapshot
    }

    func fetchRateLimits(executableURL: URL) async throws
        -> CodexRateLimitSnapshot {
        callCount += 1
        try await Task.sleep(for: .milliseconds(40))
        return snapshot
    }
}

private actor ScriptedClaudeCodeProvider: ClaudeCodeRateLimitProviding {
    private var results: [Result<ClaudeCodeRateLimitSnapshot, Error>]

    init(_ results: [Result<ClaudeCodeRateLimitSnapshot, Error>]) {
        self.results = results
    }

    func fetchRateLimits() async throws -> ClaudeCodeRateLimitSnapshot {
        guard !results.isEmpty else {
            throw ClaudeCodeRateLimitProviderError.invalidSnapshot
        }
        return try results.removeFirst().get()
    }
}

private actor ScriptedWeatherProvider: WeatherSnapshotProviding {
    private var results: [Result<WeatherSnapshot, Error>]
    private(set) var callCount = 0

    init(_ results: [Result<WeatherSnapshot, Error>]) {
        self.results = results
    }

    func fetchWeather() async throws -> WeatherSnapshot {
        callCount += 1
        guard !results.isEmpty else {
            throw OpenMeteoWeatherError.invalidPayload
        }
        return try results.removeFirst().get()
    }
}

@MainActor
private final class MutableWeatherAuthorizationProvider:
    WeatherLocationAuthorizationProviding,
    @unchecked Sendable
{
    var authorization: WeatherLocationAuthorization

    init(_ authorization: WeatherLocationAuthorization) {
        self.authorization = authorization
    }

    func weatherLocationAuthorization() -> WeatherLocationAuthorization {
        authorization
    }
}

private actor DelayedWeatherProvider: WeatherSnapshotProviding {
    private(set) var callCount = 0
    let snapshot: WeatherSnapshot

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    func fetchWeather() async throws -> WeatherSnapshot {
        callCount += 1
        try await Task.sleep(for: .milliseconds(40))
        return snapshot
    }
}

private actor CancellableWeatherProvider: WeatherSnapshotProviding {
    private(set) var cancellationCount = 0

    func fetchWeather() async throws -> WeatherSnapshot {
        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            cancellationCount += 1
            throw error
        }
        throw OpenMeteoWeatherError.locationTimedOut
    }
}

private struct FixedWeatherCoordinateProvider: WeatherCoordinateProviding {
    let coordinate: WeatherCoordinate

    @MainActor
    func currentCoordinate() async throws -> WeatherCoordinate {
        coordinate
    }
}

@MainActor
private final class CountingWeatherCoordinateProvider:
    WeatherCoordinateProviding,
    @unchecked Sendable
{
    let coordinate: WeatherCoordinate
    private(set) var requestCount = 0

    init(coordinate: WeatherCoordinate) {
        self.coordinate = coordinate
    }

    func currentCoordinate() async throws -> WeatherCoordinate {
        requestCount += 1
        return coordinate
    }
}

private struct FixedWeatherLocationNameProvider: WeatherLocationNameProviding {
    let locationName: String?

    @MainActor
    func locationName(for coordinate: WeatherCoordinate) async -> String? {
        locationName
    }
}

private struct SlowWeatherLocationNameProvider: WeatherLocationNameProviding {
    @MainActor
    func locationName(for coordinate: WeatherCoordinate) async -> String? {
        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            return nil
        }
        return "Too Late"
    }
}

private actor FixtureOpenMeteoHTTPClient: OpenMeteoHTTPClient {
    let statusCode: Int
    let responseData: Data
    private(set) var lastRequest: URLRequest?

    init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        responseData = data
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }
}

private final class InMemoryWeatherCache: WeatherSnapshotCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSnapshot: WeatherSnapshot?

    var snapshot: WeatherSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return storedSnapshot
    }

    init(snapshot: WeatherSnapshot? = nil) {
        storedSnapshot = snapshot
    }

    func load() -> WeatherSnapshot? {
        snapshot
    }

    func save(_ snapshot: WeatherSnapshot) {
        lock.lock()
        storedSnapshot = snapshot
        lock.unlock()
    }
}

@MainActor
private final class StubClaudeCodeBridge: ClaudeCodeStatusLineBridging {
    var installed: Bool
    private(set) var installCallCount = 0
    private(set) var uninstallCallCount = 0
    let snapshotURL = URL(fileURLWithPath: "/tmp/dockmagic-claude-test.json")

    init(installed: Bool) {
        self.installed = installed
    }

    func isInstalled() -> Bool {
        installed
    }

    func install() throws {
        installCallCount += 1
        installed = true
    }

    func uninstall() throws {
        uninstallCallCount += 1
        installed = false
    }
}

private struct StubCodexLocator: CodexExecutableLocating {
    func locate(overridePath: String?) throws -> URL {
        URL(fileURLWithPath: overridePath ?? "/usr/bin/true")
    }
}

private struct ThrowingCodexLocator: CodexExecutableLocating {
    func locate(overridePath: String?) throws -> URL {
        throw CodexRateLimitProviderError.executableNotFound
    }
}

private final class SpyDockTile: NSDockTile {
    private(set) var displayCallCount = 0

    override var size: NSSize {
        NSSize(width: 128, height: 128)
    }

    override func display() {
        displayCallCount += 1
    }
}

@MainActor
private final class SpyApplicationIconDisplay: ApplicationIconDisplaying {
    var applicationIconImage: NSImage!
}

@MainActor
private final class SpyDockApplicationIconRenderer:
    DockApplicationIconRendering
{
    private(set) var clockTransitions: [DockClockTransition?] = []

    func render(
        presentation: DockTilePresentation,
        appearanceMode: DSAppearanceMode,
        clockTransition: DockClockTransition?
    ) -> NSImage? {
        clockTransitions.append(clockTransition)
        return nil
    }
}
