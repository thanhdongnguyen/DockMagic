import AppKit
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
        XCTAssertEqual(DockFeature.github.title, "GitHub")
        XCTAssertEqual(DockFeature.codex.title, "Codex")
        XCTAssertEqual(DockFeature.claudeCode.title, "Claude Code")
        XCTAssertEqual(DockFeature.searchConsole.title, "Search Console")
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
        XCTAssertEqual(DockHoverPanelPlacement.standardPanelSize.width, 440)
        XCTAssertEqual(DockHoverPanelPlacement.standardPanelSize.height, 304)
        XCTAssertEqual(
            DockHoverPanelPlacement.panelSize(for: .codex).height,
            410
        )
        XCTAssertEqual(
            DockHoverPanelPlacement.panelSize(for: .claudeCode),
            DockHoverPanelPlacement.standardPanelSize
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

    @MainActor
    func testClaudeCodeBridgeCachesOnlyRateLimitsAndRestoresStatusLine() throws {
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
        let settings: [String: Any] = [
            "theme": "light",
            "statusLine": originalStatusLine
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
        XCTAssertFalse(cachedText.contains("private-session"))
        XCTAssertFalse(cachedText.contains("/private/project"))
        XCTAssertNoThrow(try ClaudeCodeRateLimitParser.parse(cachedData))

        try bridge.uninstall()
        XCTAssertFalse(bridge.isInstalled())
        XCTAssertFalse(FileManager.default.fileExists(atPath: scriptURL.path))
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
        XCTAssertEqual(restoredObject["theme"] as? String, "light")
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
            "temperature_2m,apparent_temperature,weather_code,is_day"
        )
        XCTAssertEqual(
            query["daily"]!,
            "temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        )
        XCTAssertEqual(query["timezone"]!, "auto")
        XCTAssertEqual(query["forecast_days"]!, "1")
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
            codexStore: codex,
            claudeCodeStore: claudeCode
        )

        appModel.start()
        XCTAssertTrue(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
        XCTAssertFalse(codex.isMonitoring)
        XCTAssertFalse(claudeCode.isMonitoring)

        preferences.activeFeature = .dockMagic
        try await waitUntil {
            !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !codex.isMonitoring
                && !claudeCode.isMonitoring
        }

        preferences.activeFeature = .network
        try await waitUntil {
            network.isMonitoring
                && !metrics.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
                && !codex.isMonitoring
                && !claudeCode.isMonitoring
        }

        preferences.activeFeature = .storage
        try await waitUntil {
            storage.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !weather.isMonitoring
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
        XCTAssertFalse(codex.isMonitoring)
        XCTAssertFalse(claudeCode.isMonitoring)

        preferences.activeFeature = .codex
        try await waitUntil {
            codex.isMonitoring
                && !metrics.isMonitoring
                && !network.isMonitoring
                && !storage.isMonitoring
                && !weather.isMonitoring
        }

        XCTAssertTrue(codex.isMonitoring)
        XCTAssertFalse(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
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
        XCTAssertFalse(codex.isMonitoring)

        appModel.stop()
        XCTAssertFalse(metrics.isMonitoring)
        XCTAssertFalse(network.isMonitoring)
        XCTAssertFalse(storage.isMonitoring)
        XCTAssertFalse(weather.isMonitoring)
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
        let hoveredName = "Codex Hover — Token Hover"
        let hovered = try renderPNG(
            of: DockHoverDashboardRoot(
                appModel: appModel,
                pointerEdge: .bottom,
                appearanceMode: .dark,
                initialHoveredBucketID: hoveredBucketID
            ),
            size: DockHoverPanelPlacement.codexPanelSize,
            appearanceName: .darkAqua,
            name: hoveredName
        )
        XCTAssertGreaterThan(hovered.count, 12_000)
        XCTAssertNotEqual(hovered, renderedVariants[0])
        attachPNG(hovered, name: hoveredName)
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
                size: DockHoverPanelPlacement.standardPanelSize,
                appearanceName: appearanceName,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            attachPNG(data, name: name)
            renderedVariants.append(data)
        }
        XCTAssertNotEqual(renderedVariants[0], renderedVariants[1])

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
            size: DockHoverPanelPlacement.standardPanelSize,
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
            size: DockHoverPanelPlacement.standardPanelSize,
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
                size: DockHoverPanelPlacement.standardPanelSize,
                appearanceName: .darkAqua,
                name: name
            )
            XCTAssertGreaterThan(data.count, 12_000)
            attachPNG(data, name: name)
        }

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
        XCTAssertTrue(source.contains("Claude Code statusLine"))
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
            dailyUsageBuckets: buckets
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
            CodexHoverDashboardPresentation.resetLabel(for: weekly),
            "Resets Aug 28, 9:15 AM"
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
        let sourceURL = projectDirectory.appendingPathComponent(
            "DockMagic/Views/Hover/CodexHoverDashboardView.swift"
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
            "DockRingAppearance",
            "import Charts",
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
                    plotHeight: 88
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
        WeatherSnapshot(
            location: "Ho Chi Minh City",
            temperatureCelsius: 29,
            feelsLikeCelsius: 32,
            conditionDescription: conditionDescription,
            condition: condition,
            highCelsius: 33,
            lowCelsius: 26,
            precipitationChance: 0.2,
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
                "weather_code": "wmo code",
                "is_day": ""
              },
              "current": {
                "time": "1970-01-01T07:30",
                "interval": 900,
                "temperature_2m": 29.4,
                "apparent_temperature": 32,
                "weather_code": 2,
                "is_day": 1
              },
              "daily_units": {
                "time": "iso8601",
                "temperature_2m_max": "°C",
                "temperature_2m_min": "°C",
                "precipitation_probability_max": "%"
              },
              "daily": {
                "time": ["1970-01-01"],
                "temperature_2m_max": [33],
                "temperature_2m_min": [26],
                "precipitation_probability_max": [25]
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
        case pngEncodingFailed
    }
}

@MainActor
private final class CodexHoverTestState {
    var hoveredBucketID: Date?
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
