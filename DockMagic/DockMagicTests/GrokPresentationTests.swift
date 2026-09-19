import AppKit
import CoreImage
import SwiftUI
import XCTest
@testable import DockMagic

@MainActor
final class GrokPresentationTests: XCTestCase {
    func testUnknownTodayDoesNotBecomeMomentumZero() {
        let history = fixture()
        XCTAssertEqual(GrokBuildPresentation.today(history), 35_987)
        XCTAssertEqual(GrokBuildPresentation.momentum(history)?.score, CodexShipMomentum.score(forTodayTokens: 35_987))
        let unknown = GrokBuildHistorySnapshot(days: Array(history.days.dropLast()), coverage: .init(), observedAt: .now, sourceUpdatedAt: nil)
        XCTAssertNil(GrokBuildPresentation.today(unknown))
        XCTAssertNil(GrokBuildPresentation.momentum(unknown))
        XCTAssertEqual(GrokBuildPresentation.unknown(history).count, 29)
        XCTAssertEqual(GrokBuildPresentation.models(history).first?.tokens, 35_987)
        XCTAssertEqual(GrokBuildPresentation.compact(nil), "—")
        XCTAssertEqual(GrokBuildPresentation.modelCoverage(history), "Model coverage: all observed tokens attributed.")
        XCTAssertEqual(GrokBuildPresentation.modelCoverage(unknown), "Model coverage unavailable: no eligible tokens observed.")
    }

    func testManifestAndProductionGatesRemainExplicit() {
        XCTAssertEqual(GrokBuildDashboardManifest.entries.map(\.module), GrokBuildDashboardManifest.Module.allCases)
        XCTAssertFalse(GrokBuildFeatureGate.productionEnabled)
        XCTAssertFalse(GrokBuildFeatureGate.billingStartupSafetyVerified)
        XCTAssertEqual(GrokBuildSettings().metric, .quota)
        XCTAssertFalse(GrokBuildSettings().enabled)
        XCTAssertEqual(DockFeature.availableCases.contains(.grokBuild), GrokBuildFeatureGate.experimentalEnabled)
        XCTAssertNil(DockFeature.grokBuild.developerTool)
    }

    func testPreferencesRetainHomeAndExplicitMetricWithoutChangingOtherProviders() throws {
        let suite = "GrokPresentation.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        let codex = preferences.codexAppearance
        preferences.grokBuildSettings.homePath = "/tmp/another-grok-home"
        preferences.grokBuildSettings.metric = .tokensToday
        preferences.grokBuildSettings.enabled = true
        let restored = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.grokBuildSettings, preferences.grokBuildSettings)
        XCTAssertEqual(restored.codexAppearance, codex)
        XCTAssertEqual(restored.grokBuildSettings.configuration().home.path, "/tmp/another-grok-home")
    }

    func testCoverageAwareViewsKeepLegacyDefaults() {
        let summary = TokenUsageStreakSummary.fixture(currentDays: 0, bestDays: 7, endingAt: .now)
        let legacy = StreakContinuityStrip(summary: summary, brand: .codex, accent: .primary, onOpen: {})
        XCTAssertFalse(legacy.currentDayIsUnknown)
        let grok = StreakContinuityStrip(summary: summary, brand: .grokBuild, accent: .primary, currentDayIsUnknown: true, onOpen: {})
        XCTAssertTrue(grok.currentDayIsUnknown)
        XCTAssertEqual(grok.summary?.bestDays, 7)
        XCTAssertEqual(StreakDetailView(summary: summary, brand: .codex, onBack: {}).currentDayIsUnknown, false)
        XCTAssertFalse(StreakDetailView(summary: summary, brand: .codex, onBack: {}).handlesEscape)
        XCTAssertTrue(StreakDetailView(summary: summary, brand: .grokBuild, handlesEscape: true, onBack: {}).handlesEscape)
        XCTAssertFalse(AIUsageDailyIntensityCard(buckets: []).marksUnknownDays)
        XCTAssertTrue(AIUsageDailyIntensityCard(buckets: [], marksUnknownDays: true).marksUnknownDays)
        XCTAssertNil(AIUsageTokenHistoryChart(buckets: [], hoveredBucketID: .constant(nil), plotHeight: 100, onSelectBucket: { _ in }).dataColor)
        XCTAssertNil(AIUsageHistoryChart(points: [], hoveredDate: .constant(nil), plotHeight: 100,
            formatValue: { "\($0)" }, onSelect: { _ in }).dataColor)
    }

    func testTokenAppearancePersistsCustomColorWithoutChangingConnectionOrMetric() throws {
        let suite = "GrokAppearance.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(preferences.grokBuildAppearance, .standard, "Existing installs must receive the default without changing connection settings")
        preferences.grokBuildSettings = .init(enabled: true, monitoring: false,
            executablePath: "/fixture/grok", homePath: "/fixture/home", metric: .tokensToday, style: .ring)
        let settings = preferences.grokBuildSettings
        let codex = preferences.codexAppearance
        let custom = DockColor(red: 0.13, green: 0.41, blue: 0.72, alpha: 0.64)
        preferences.grokBuildAppearance.tokenColor = custom
        let restored = DockPreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.grokBuildAppearance.tokenColor, custom)
        XCTAssertEqual(restored.grokBuildSettings, settings)
        XCTAssertEqual(restored.codexAppearance, codex)
        restored.grokBuildAppearance = .standard
        XCTAssertEqual(DockPreferencesStore(defaults: defaults).grokBuildAppearance, .standard)
        XCTAssertEqual(restored.grokBuildSettings, settings)
    }

    func testTokenAppearanceDecodingDefaultsAndNormalizesInvalidComponents() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(GrokBuildAppearance.self, from: Data("{}".utf8)), .standard)
        XCTAssertEqual(try decoder.decode(GrokBuildAppearance.self, from: Data("{\"tokenColor\":null}".utf8)), .standard)
        let decoded = try decoder.decode(GrokBuildAppearance.self,
            from: Data("{\"tokenColor\":{\"red\":-1,\"green\":2,\"blue\":0.5,\"alpha\":3}}".utf8))
        XCTAssertEqual(decoded.tokenColor, DockColor(red: 0, green: 1, blue: 0.5))
    }

    func testTokenRendererColorsMeetContrastWithoutChangingSavedSwatches() throws {
        let white = DockColor(red: 1, green: 1, blue: 1)
        let black = DockColor(red: 0, green: 0, blue: 0)
        let colors = ProjectTheme.rendererColorOptions.map { DockColor($0.color) } + [
            white, black,
            DockColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 0.05)
        ]
        XCTAssertEqual(ProjectTheme.rendererContrast(white, black), 21, accuracy: 0.0001)
        for scheme in [ColorScheme.light, .dark] {
            let appearance = try XCTUnwrap(NSAppearance(named: scheme == .dark ? .darkAqua : .aqua))
            for (surface, ratio) in [(ProjectTheme.current.dockBackgroundRaised, 4.5),
                                     (ProjectTheme.current.opaqueSurfaceRaised, 3.0),
                                     (ProjectTheme.current.opaqueSurfaceInset, 3.0)] {
                var background = DockColor(surface)
                appearance.performAsCurrentDrawingAppearance { background = DockColor(surface) }
                for swatch in colors {
                    let saved = GrokBuildAppearance(tokenColor: swatch)
                    let result = ProjectTheme.readableRendererColor(saved.tokenColor, on: surface,
                        colorScheme: scheme, minimumContrast: ratio)
                    XCTAssertGreaterThanOrEqual(ProjectTheme.rendererContrast(result, background), ratio - 0.00001,
                        "\(scheme) \(swatch.hex)")
                    XCTAssertEqual(saved.tokenColor, swatch)
                    XCTAssertEqual(result.alpha, 1)
                }
            }
        }
    }

    func testAppCompositionFlagOffStartsNoCollection() async throws {
        let suite = "GrokComposition.Disabled.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.grokBuildSettings.enabled = true
        let cli = CompositionCLI()
        let store = GrokBuildUsageStore(cli: cli, collector: VisualCollector(history: fixture()),
            repository: VisualCache(), monitor: VisualMonitor())
        let controller = GrokIntegrationController(preferences: preferences, store: store, isAvailable: false)
        controller.start()
        await controller.resume()
        XCTAssertNil(store.configuration)
        XCTAssertFalse(store.isEnabled)
        let calls = await cli.versionHomes
        XCTAssertTrue(calls.isEmpty)
        controller.stop()
    }

    func testAppCompositionMonitorsOtherDockAndFollowsPathsEnableAndSleep() async throws {
        let suite = "GrokComposition.Lifecycle.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .clock
        preferences.grokBuildSettings = .init(enabled: true, homePath: "/tmp/grok-composition-a")
        let cli = CompositionCLI()
        let store = GrokBuildUsageStore(cli: cli, collector: VisualCollector(history: fixture()),
            repository: VisualCache(), monitor: VisualMonitor(), pollingInterval: .seconds(3600))
        let controller = GrokIntegrationController(preferences: preferences, store: store, isAvailable: true)
        defer { controller.stop() }
        controller.start()
        try await waitFor { store.local.status == .live && store.isMonitoring }
        let collected = store.local.collectedAt
        preferences.activeFeature = .systemMetrics
        preferences.grokBuildSettings.metric = .tokensToday
        preferences.grokBuildAppearance.tokenColor = DockColor(red: 0.4, green: 0.2, blue: 0.6)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.local.collectedAt, collected, "Dock/appearance changes must not restart collection")
        let initialCalls = await cli.versionHomes
        XCTAssertEqual(initialCalls, ["/tmp/grok-composition-a"])

        controller.suspend()
        XCTAssertFalse(store.isMonitoring)
        XCTAssertEqual(store.local.status, .stale)
        await controller.resume()
        XCTAssertTrue(store.isMonitoring)
        XCTAssertEqual(store.local.status, .live)

        preferences.grokBuildSettings.homePath = "/tmp/grok-composition-b"
        try await waitFor { store.configuration?.home.path == "/tmp/grok-composition-b" && store.local.status == .live }
        let changedCalls = await cli.versionHomes
        XCTAssertEqual(changedCalls.last, "/tmp/grok-composition-b")
        preferences.grokBuildSettings.enabled = false
        try await waitFor { !store.isEnabled && !store.isMonitoring }
        XCTAssertNil(store.local.value)

        controller.stop()
        preferences.grokBuildSettings.enabled = true
        controller.start()
        try await waitFor { store.isEnabled && store.local.status == .live }
        controller.stop()
        XCTAssertFalse(store.isMonitoring)
        await controller.resume()
        XCTAssertFalse(store.isMonitoring, "Stopped app must not resume collection")
    }

    private func waitFor(_ predicate: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(predicate(), "Timed out waiting for app composition")
    }

    func testCalendarNotificationsReprojectManualModeAndRespectSuspendStop() async throws {
        let suite = "GrokComposition.Calendar.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.grokBuildSettings = .init(enabled: true, monitoring: false, homePath: "/tmp/grok-calendar-fixture")
        let clock = PresentationClock()
        let cli = CompositionCLI()
        let store = GrokBuildUsageStore(cli: cli, collector: VisualCollector(history: fixture()),
            repository: VisualCache(), monitor: VisualMonitor(), now: { clock.date }, calendar: { clock.calendar })
        let notifications = NotificationCenter()
        let controller = GrokIntegrationController(preferences: preferences, store: store,
            isAvailable: true, calendarNotifications: notifications)
        defer { controller.stop() }
        controller.start()
        try await waitFor { store.local.status == .live }
        let collected = store.local.collectedAt
        clock.date = clock.calendar.date(byAdding: .day, value: 1, to: clock.date)!
        notifications.post(name: .NSCalendarDayChanged, object: nil)
        try await waitFor { store.local.value?.days.last?.startDate == clock.calendar.startOfDay(for: clock.date) }
        XCTAssertNil(store.local.value?.days.last?.tokens)
        XCTAssertEqual(store.local.collectedAt, collected)

        clock.calendar.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        notifications.post(name: .NSSystemTimeZoneDidChange, object: nil)
        try await waitFor { store.activity?.timeZoneIdentifier == clock.calendar.timeZone.identifier }
        XCTAssertEqual(store.local.value?.days.last?.startDate, clock.calendar.startOfDay(for: clock.date))
        XCTAssertFalse(store.isMonitoring)
        let calls = await cli.versionHomes
        XCTAssertEqual(calls.count, 1, "Calendar notifications must not start CLI acquisition")

        controller.suspend()
        let suspended = store.local.value
        clock.date = clock.calendar.date(byAdding: .day, value: 1, to: clock.date)!
        notifications.post(name: .NSCalendarDayChanged, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.local.value, suspended)
        await controller.resume()
        XCTAssertEqual(store.local.value?.days.last?.startDate, clock.calendar.startOfDay(for: clock.date))
        XCTAssertEqual(store.local.collectedAt, collected)

        controller.stop()
        let stopped = store.local.value
        clock.date = clock.calendar.date(byAdding: .day, value: 1, to: clock.date)!
        notifications.post(name: .NSCalendarDayChanged, object: nil)
        notifications.post(name: .NSSystemTimeZoneDidChange, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.local.value, stopped)
        let finalCalls = await cli.versionHomes
        XCTAssertEqual(finalCalls.count, 1)
    }

    func testNativeAppearanceMatrix() async throws {
        let history = fixture()
        let store = GrokBuildUsageStore(cli: VisualCLI(), collector: VisualCollector(history: history),
            repository: VisualCache(), monitor: VisualMonitor())
        await store.configure(.init(executable: URL(fileURLWithPath: "/usr/bin/false"), home: URL(fileURLWithPath: "/tmp/grok-visual-fixture")), enabled: true, monitoring: false)
        defer { store.stop() }
        XCTAssertEqual(store.local.status, .live)
        XCTAssertEqual(store.quota.error, .billingStartupUnverified)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("dockmagic-grok-ui-\(UUID())")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let suite = "GrokVisualSettings.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.grokBuildSettings = .init(enabled: true, metric: .tokensToday)
        preferences.grokBuildAppearance.tokenColor = DockColor(try XCTUnwrap(ProjectTheme.rendererColorOptions.first { $0.id == "purple" }).color)
        let variants: [(String, DSAppearanceMode, DSAccessibilityOverrides)] = [
            ("light", .light, .init()), ("dark", .dark, .init()),
            ("contrast", .dark, .init(increaseContrast: true)),
            ("opaque", .dark, .init(reduceTransparency: true)),
            ("motion", .light, .init(reduceMotion: true)), ("grayscale", .light, .init())
        ]
        for (name, mode, overrides) in variants {
            let local = store.local
            let panel = HStack(alignment: .top, spacing: 12) {
                DockHoverChrome(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: 740)) {
                    GrokBuildHoverDashboardView(store: store, appearance: preferences.grokBuildAppearance)
                }.frame(width: 440, height: 740)
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach([32.0, 48, 64, 128], id: \.self) { size in
                            DockTileView(presentation: .grokBuild(local: local, settings: .init(enabled: true, metric: .tokensToday),
                                appearance: preferences.grokBuildAppearance), animatesChanges: false)
                                .frame(width: size, height: size)
                        }
                        DockTileView(presentation: .grokBuild(local: local, settings: .init(enabled: true),
                            appearance: preferences.grokBuildAppearance), animatesChanges: false)
                            .frame(width: 64, height: 64)
                    }.frame(height: 128)
                    DockHoverChrome(pointerEdge: .bottom, panelSize: CGSize(width: 400, height: 600)) {
                        StreakDetailView(summary: .fixture(currentDays: 0, bestDays: 7, endingAt: .now), brand: .grokBuild,
                            currentDayIsUnknown: true, onBack: {})
                    }.frame(width: 400, height: 600)
                }
            }.padding(12).frame(width: 884, height: 780)
            let root = DockMagicThemeRoot(content: panel, appearanceMode: mode)
                .environment(\.dsAccessibilityOverrides, overrides)
            let appearance = NSAppearance(named: mode == .dark ? (name == "contrast" ? .accessibilityHighContrastDarkAqua : .darkAqua) : .aqua)
            try await capture(root, size: CGSize(width: 884, height: 780), appearance: appearance, name: name, output: output)
            let settings = DockMagicThemeRoot(content:
                GrokBuildSettingsView(store: store, preferences: preferences).padding(24).frame(width: 760),
                appearanceMode: mode)
                .environment(\.dsAccessibilityOverrides, overrides)
            try await capture(settings, size: CGSize(width: 760, height: 1660), appearance: appearance,
                name: "settings-\(name)", output: output)
        }
        print("Grok native visual evidence: \(output.path)")
    }

    func testAuthenticationOutputAppearanceMatrix() async throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("grok-auth-visual-\(UUID())")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let suite = "GrokAuthVisual.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DockPreferencesStore(defaults: defaults)
        let variants: [(String, DSAppearanceMode, DSAccessibilityOverrides)] = [
            ("light", .light, .init()), ("dark", .dark, .init()),
            ("contrast", .dark, .init(increaseContrast: true)),
            ("opaque", .dark, .init(reduceTransparency: true)),
            ("motion", .light, .init(reduceMotion: true)), ("grayscale", .light, .init())
        ]
        for (name, mode, overrides) in variants {
            let store = GrokUIFixtures.store(mode: "auth-cancel", preferences: preferences)
            await store.configure(.init(executable: URL(fileURLWithPath: "/fixture/grok"),
                home: URL(fileURLWithPath: "/fixture/grok-home")), enabled: true, monitoring: false)
            XCTAssertTrue(store.authentication.start(store: store, deviceCode: true))
            try await waitFor { !store.authentication.output.isEmpty }
            let root = DockMagicThemeRoot(content:
                GrokBuildAuthenticationSection(store: store).padding(24).frame(width: 760), appearanceMode: mode)
                .environment(\.dsAccessibilityOverrides, overrides)
            let appearance = NSAppearance(named: mode == .dark
                ? (name == "contrast" ? .accessibilityHighContrastDarkAqua : .darkAqua) : .aqua)
            let png = try await capture(root, size: CGSize(width: 760, height: 680), appearance: appearance,
                name: "auth-output-\(name)", output: output, compositedWindow: true)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: png))
            let terminalBackground = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2,
                y: bitmap.pixelsHigh * 3 / 4)?.usingColorSpace(.deviceRGB))
            XCTAssertLessThan(max(terminalBackground.redComponent, terminalBackground.greenComponent,
                terminalBackground.blueComponent), 0.15, "Shared dark terminal background must survive Light-mode native capture")
            store.cancelAuthentication()
            try await waitFor { !store.authentication.isRunning }
            XCTAssertTrue(store.authentication.output.isEmpty)
            store.stop()
        }
    }

    func testProductionDockColorChangesOnlyKnownTokens() async throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("grok-color-render-\(UUID())")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let purple = GrokBuildAppearance(tokenColor: DockColor(try XCTUnwrap(ProjectTheme.rendererColorOptions.first { $0.id == "purple" }).color))
        let known = GrokBuildObservation<GrokBuildHistorySnapshot>(status: .live, value: fixture())
        let unknown = GrokBuildObservation<GrokBuildHistorySnapshot>(status: .unavailable)
        for (name, local, settings, shouldChange) in [
            ("known", known, GrokBuildSettings(enabled: true, metric: .tokensToday), true),
            ("unknown", unknown, GrokBuildSettings(enabled: true, metric: .tokensToday), false),
            ("disabled", known, GrokBuildSettings(enabled: false, metric: .tokensToday), false),
            ("quota", known, GrokBuildSettings(enabled: true, metric: .quota), false)
        ] {
            var images: [Data] = []
            for (index, appearance) in [GrokBuildAppearance.standard, purple].enumerated() {
                let renderer = DockTileView(presentation: .grokBuild(local: local, settings: settings, appearance: appearance), animatesChanges: false)
                    .frame(width: 128, height: 128)
                images.append(try await capture(DockMagicThemeRoot(content: renderer, appearanceMode: .light),
                    size: CGSize(width: 128, height: 128), appearance: NSAppearance(named: .aqua),
                    name: "\(name)-\(index)", output: output))
            }
            XCTAssertEqual(images[0] != images[1], shouldChange, "\(name): only known token pixels may use the saved data color")
        }
    }

    @discardableResult
    private func capture(_ view: some View, size: CGSize, appearance: NSAppearance?, name: String, output: URL,
                         compositedWindow: Bool = false) async throws -> Data {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        window.contentView = host; window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(350))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        var bitmap: NSBitmapImageRep
        if compositedWindow {
            // SwiftTerm paints default backgrounds through CALayer. AppKit's
            // cacheDisplay omits them, unlike the real window. Capture only
            // this test-owned window; never include other desktop content.
            let image = try XCTUnwrap(CGWindowListCreateImage(.null, .optionIncludingWindow,
                CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]))
            bitmap = NSBitmapImageRep(cgImage: image)
        } else {
            bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
        }
        if name.contains("grayscale") {
            // Native scroll views and controls cannot be flattened with
            // drawingGroup. Simulate grayscale from the complete native capture,
            // matching the existing dashboard QA harness; no app setting changes.
            let original = try XCTUnwrap(bitmap.cgImage)
            let filter = try XCTUnwrap(CIFilter(name: "CIColorControls"))
            filter.setValue(CIImage(cgImage: original), forKey: kCIInputImageKey)
            filter.setValue(0, forKey: kCIInputSaturationKey)
            let outputImage = try XCTUnwrap(filter.outputImage)
            let grayscaleImage = try XCTUnwrap(CIContext().createCGImage(outputImage, from: outputImage.extent))
            bitmap = NSBitmapImageRep(cgImage: grayscaleImage)
            var visibleSamples = 0
            var maximumChannelDifference: CGFloat = 0
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 13) {
                for y in stride(from: 0, to: bitmap.pixelsHigh, by: 13) {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.9 else { continue }
                    visibleSamples += 1
                    maximumChannelDifference = max(maximumChannelDifference,
                        abs(color.redComponent - color.greenComponent), abs(color.greenComponent - color.blueComponent))
                }
            }
            XCTAssertGreaterThan(visibleSamples, 100, "Grayscale capture must not be a blank image")
            XCTAssertLessThan(maximumChannelDifference, 0.03)
        }
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: output.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "Grok \(name)"; attachment.lifetime = .keepAlways; add(attachment)
        return png
    }

    private func fixture() -> GrokBuildHistorySnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<30).reversed().map { offset in
            GrokBuildDailyObservation(startDate: calendar.date(byAdding: .day, value: -offset, to: today)!,
                tokens: offset == 0 ? 35_987 : nil, modelTokens: offset == 0 ? ["grok-4.6-build": 35_987] : [:],
                modelCoverageIsPartial: offset != 0)
        }
        return .init(days: days, coverage: .init(), observedAt: .now, sourceUpdatedAt: .now)
    }
}

private struct VisualCLI: GrokBuildCLIProviding {
    func version(configuration: GrokBuildCLIConfiguration) async throws -> String { "1.0.30" }
    func usage(id: UUID, configuration: GrokBuildCLIConfiguration) async throws -> GrokBuildSessionUsage { throw GrokBuildError.commandFailed }
    func billing(configuration: GrokBuildCLIConfiguration, observedAt: Date) async throws -> GrokBuildQuotaSnapshot { throw GrokBuildError.billingStartupUnverified }
    func signOut(configuration: GrokBuildCLIConfiguration) async throws { throw GrokBuildError.billingStartupUnverified }
}
@MainActor private final class PresentationClock {
    var date = Date()
    var calendar = Calendar.current
}
private actor CompositionCLI: GrokBuildCLIProviding {
    private(set) var versionHomes: [String] = []
    func version(configuration: GrokBuildCLIConfiguration) async throws -> String {
        versionHomes.append(configuration.home.path)
        return "1.0.30"
    }
    func usage(id: UUID, configuration: GrokBuildCLIConfiguration) async throws -> GrokBuildSessionUsage { throw GrokBuildError.commandFailed }
    func billing(configuration: GrokBuildCLIConfiguration, observedAt: Date) async throws -> GrokBuildQuotaSnapshot { throw GrokBuildError.billingStartupUnverified }
    func signOut(configuration: GrokBuildCLIConfiguration) async throws { throw GrokBuildError.billingStartupUnverified }
}
private struct VisualCollector: GrokBuildLocalCollecting {
    let history: GrokBuildHistorySnapshot
    func collect(configuration: GrokBuildCLIConfiguration, cache: GrokBuildHistoryCache, now: Date, calendar: Calendar, force: Bool) async throws -> GrokBuildLocalCollection {
        var cache = cache
        cache.collectedAt = now
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000321")!
        let lineage = try JSONDecoder().decode(GrokBuildLineage.self, from: Data("{\"info\":{\"id\":\"\(id.uuidString)\"}}".utf8))
        let counts = GrokBuildTokenCounts(input: 35_879, output: 108, total: 35_987, cacheRead: 6_144, cacheWrite: nil, reasoning: 54)
        let usage = GrokBuildSessionUsage(id: id, sourceUpdatedAt: now, total: counts,
            turns: [.init(number: 1, recordedAt: now, tokens: counts, models: ["grok-4.6-build": counts], upstreamIncomplete: false)])
        _ = cache.ledger.ingest(usage, lineage: lineage, observedAt: now, calendar: calendar)
        cache.activity = .importing(cache.ledger, at: now, calendar: calendar)
        return .init(cache: cache, snapshot: history, readableRootCount: 1)
    }
}
private final class VisualMonitor: GrokBuildFileMonitoring, @unchecked Sendable {
    func start(home: URL, onChange: @escaping @Sendable () -> Void) -> Bool { false }
    func stop() {}
}
private struct VisualCache: GrokBuildHistoryCaching {
    func load(home: URL) throws -> GrokBuildHistoryCache? { nil }
    func save(_ cache: GrokBuildHistoryCache) throws {}
}
