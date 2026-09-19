import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

private struct OpenCodeVisualReader: OpenCodeHistoryReading {
    let snapshot: OpenCodeUsageSnapshot
    func read(database: URL, timezone: TimeZone, now: Date) async throws -> OpenCodeUsageSnapshot { snapshot }
}

private struct LegacyOpenCodeDockAppearance: Encodable {
    let color: DockColor
    let lineWidth: Double
}

@MainActor
final class OpenCodeIntegrationTests: XCTestCase {
    private let output = URL(fileURLWithPath: "/private/tmp/dockmagic-opencode-qa", isDirectory: true)
    private func fixture(now: Date = .now) -> OpenCodeUsageSnapshot {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let days = (0..<30).reversed().compactMap { offset -> OpenCodeDailyDetail? in
            guard offset != 4 && offset != 11 else { return nil }
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
            let tokens = OpenCodeTokens(input: Int64((offset % 7 + 1) * 1_234_567), output: 42_567, reasoning: 567, cacheRead: 678_910, cacheWrite: 345)
            return OpenCodeDailyDetail(startDate: day, tokens: tokens,
                cost: OpenCodeCost(recordedUSD: 1.23, eligibleMessages: 1, usageMessages: 2),
                hourly: [OpenCodeHourlyUsage(startDate: day.addingTimeInterval(3600), tokens: tokens, isPartial: true)],
                models: [OpenCodeModelUsage(provider: "provider", model: "A long model name for width and truncation verification", tokens: tokens, isPartial: true)],
                sessionCount: 1, messageCount: 2, isPartial: true)
        }
        return OpenCodeUsageSnapshot(sourceID: "private-source-hash", timezoneID: calendar.timeZone.identifier,
            readAt: now, schema: "message + session_message", days: days, recordKeys: ["hashed-key"], skippedRecords: 1,
            lifetimeTokens: days.compactMap { $0.tokens.total }.reduce(0, +), cost: OpenCodeCost(recordedUSD: 20, eligibleMessages: 20, usageMessages: 30))
    }
    func testSharedSnapshotPresentationAndManifest() {
        let snapshot = fixture()
        let last = OpenCodePresentation.buckets(snapshot, count: 7).last
        XCTAssertEqual(last?.tokens, snapshot.day(.now)?.tokens.total)
        XCTAssertEqual(OpenCodePresentation.account(snapshot).lifetimeTokens, snapshot.lifetimeTokens)
        XCTAssertEqual(OpenCodePresentation.momentum(snapshot)?.todayTokens, snapshot.day(.now)?.tokens.total)
        XCTAssertEqual(OpenCodePresentation.buckets(snapshot, count: 7).count, 7)
        XCTAssertEqual(OpenCodeDashboardManifest.entries.map(\.module), OpenCodeDashboardManifest.selectedModules)
        XCTAssertEqual(OpenCodeDashboardManifest.excluded["quota"], .unknown)
        XCTAssertEqual(OpenCodeDashboardManifest.excluded["transcripts"], .prohibited)
        XCTAssertEqual(OpenCodePresentation.compact(1_200_000_000), 1.2.formatted(.number.precision(.fractionLength(0...1))) + "B")
        XCTAssertEqual(OpenCodePresentation.compact(nil), "—")
        XCTAssertEqual(DockFeature.openCode.developerTool, nil)
        XCTAssertTrue(DockFeature.openCode.hasHoverDashboard)
        XCTAssertEqual(SettingsDestination.openCode.feature, .openCode)
    }
    func testAppearancePersistsIndependentColorsAndMigratesLegacyColor() throws {
        let chartColor = DockColor(red: 0.2, green: 0.4, blue: 0.8)
        let tokenColor = DockColor(red: 0.8, green: 0.3, blue: 0.5)
        let appearance = OpenCodeDockAppearance(
            chartColor: chartColor,
            tokenColor: tokenColor,
            lineWidth: 2.6
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                OpenCodeDockAppearance.self,
                from: JSONEncoder().encode(appearance)
            ),
            appearance
        )

        let legacyColor = DockColor(red: 0.3, green: 0.7, blue: 0.2)
        let migrated = try JSONDecoder().decode(
            OpenCodeDockAppearance.self,
            from: JSONEncoder().encode(
                LegacyOpenCodeDockAppearance(color: legacyColor, lineWidth: 3.2)
            )
        )
        XCTAssertEqual(migrated.chartColor, legacyColor)
        XCTAssertEqual(migrated.tokenColor, legacyColor)
        XCTAssertEqual(migrated.lineWidth, 3.2)
    }
    func testExportPNGAndIdenticalSaveCopyShareArtifact() throws {
        let now = Date.now
        let state = OpenCodeUsageState(snapshot: fixture(now: now), observation: .stale)
        let artifact = try CodexDashboardCaptureService.renderActivityCard(state: state, appearanceMode: .dark, now: now)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: artifact.pngData))
        XCTAssertEqual(bitmap.pixelsWide, 1200); XCTAssertEqual(bitmap.pixelsHigh, 1200)
        for x in stride(from: 0, to: 1200, by: 40) {
            for y in stride(from: 0, to: 1200, by: 40) {
                XCTAssertEqual(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0, 1, accuracy: 0.001)
            }
        }
        XCTAssertTrue(artifact.fileName.contains("OpenCode-Activity"))
        let board = NSPasteboard.withUniqueName()
        try CodexDashboardCaptureService.copy(artifact, to: board)
        XCTAssertEqual(board.data(forType: .png), artifact.pngData)
        let url = try CodexDashboardCaptureService.temporaryShareURL(for: artifact)
        XCTAssertEqual(try Data(contentsOf: url), artifact.pngData)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try artifact.pngData.write(to: output.appendingPathComponent("export-stale-partial-dark.png"))
        XCTAssertFalse(String(decoding: artifact.pngData, as: UTF8.self).contains("private-source-hash"))
        XCTAssertThrowsError(try CodexDashboardCaptureService.renderActivityCard(state: OpenCodeUsageState(), appearanceMode: .light))
        for mode in [DSAppearanceMode.light, .dark] {
            let image = try CodexDashboardCaptureService.renderActivityCard(state: state, appearanceMode: mode, now: now)
            try image.pngData.write(to: output.appendingPathComponent("export-\(mode.rawValue).png"))
        }
    }
    func testNativeVisualMatrix() async throws {
        let snapshot = fixture()
        let defaults = UserDefaults(suiteName: "OpenCodeVisual.\(UUID())")!
        defaults.set("/fixture/opencode.db", forKey: "DockMagicOpenCodeDatabase")
        defaults.set(true, forKey: "DockMagicOpenCodeUsed")
        let store = OpenCodeUsageStore(reader: OpenCodeVisualReader(snapshot: snapshot), cache: .init(directory: output.appendingPathComponent("cache")), defaults: defaults)
        defer { store.stop() }
        store.refresh()
        for _ in 0..<100 where store.state.snapshot == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(store.state.snapshot)
        let variants: [(String, DSAppearanceMode, NSAppearance.Name, DSAccessibilityOverrides, Bool)] = [
            ("light", .light, .aqua, .init(), false), ("dark", .dark, .darkAqua, .init(), false),
            ("contrast", .dark, .accessibilityHighContrastDarkAqua, .init(increaseContrast: true), false),
            ("opaque", .dark, .darkAqua, .init(reduceTransparency: true), false),
            ("motion", .light, .aqua, .init(reduceMotion: true), false),
            ("grayscale", .light, .aqua, .init(), true)
        ]
        for (name, mode, appearance, overrides, grayscale) in variants {
            let panel = HStack(alignment: .top, spacing: 16) {
                DockHoverChrome(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: 680)) {
                    OpenCodeHoverDashboardView(
                        store: store,
                        appearanceMode: mode,
                        appearance: OpenCodeDockAppearance(
                            chartColor: DockColor(red: 0.10, green: 0.68, blue: 0.42),
                            tokenColor: DockColor(red: 0.78, green: 0.22, blue: 0.62)
                        )
                    )
                }.frame(width: 440, height: 680)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Dock · 32 / 48 / 64 pt").font(.headline)
                    ForEach([32.0, 48, 64], id: \.self) { size in
                        DockTileView(presentation: .openCode(state: store.state, appearance: .standard), animatesChanges: false).frame(width: size, height: size)
                    }
                    Text("Missing / stale / loading").font(.caption)
                    ForEach([OpenCodeObservation.unavailable, .stale, .loading], id: \.rawValue) { observation in
                        DockTileView(presentation: .openCode(state: OpenCodeUsageState(snapshot: observation == .stale ? snapshot : nil, observation: observation), appearance: .standard), animatesChanges: false).frame(width: 64, height: 64)
                    }
                    Text("One point / all zero").font(.caption)
                    ForEach([true, false], id: \.self) { singleton in
                        let day = snapshot.day(.now)!
                        let zero = OpenCodeDailyDetail(startDate: day.startDate, tokens: .zero, cost: .init(), hourly: [], models: [], sessionCount: 0, messageCount: 0, isPartial: false)
                        let value = OpenCodeUsageSnapshot(sourceID: "fixture", timezoneID: snapshot.timezoneID, readAt: snapshot.readAt, schema: "fixture", days: singleton ? [day] : snapshot.days.map { OpenCodeDailyDetail(startDate: $0.startDate, tokens: zero.tokens, cost: .init(), hourly: [], models: [], sessionCount: 0, messageCount: 0, isPartial: false) }, recordKeys: [], skippedRecords: 0, lifetimeTokens: singleton ? day.tokens.total : 0, cost: .init())
                        DockTileView(presentation: .openCode(state: OpenCodeUsageState(snapshot: value, observation: .current), appearance: .standard), animatesChanges: false).frame(width: 64, height: 64)
                    }
                }.frame(width: 220, alignment: .leading)
            }.padding(12).frame(width: 710, height: 710)
            let root = DockMagicThemeRoot(content: panel.background(.background), appearanceMode: mode)
                .environment(\.dsAccessibilityOverrides, overrides)
            try await capture(root, size: CGSize(width: 710, height: 710), appearance: appearance, name: name, grayscale: grayscale)
        }
    }
    func testSettingsNativeVisualMatrix() async throws {
        let snapshot = fixture()
        let defaults = UserDefaults(suiteName: "OpenCodeSettingsVisual.\(UUID())")!
        defaults.set("/fixture/opencode.db", forKey: "DockMagicOpenCodeDatabase")
        defaults.set(true, forKey: "DockMagicOpenCodeUsed")
        let store = OpenCodeUsageStore(
            reader: OpenCodeVisualReader(snapshot: snapshot),
            cache: .init(directory: output.appendingPathComponent("settings-cache")),
            defaults: defaults
        )
        defer { store.stop() }
        store.refresh()
        for _ in 0..<100 where store.state.snapshot == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(store.state.snapshot)

        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.openCodeAppearance = OpenCodeDockAppearance(
            chartColor: DockColor(red: 0.10, green: 0.68, blue: 0.42),
            tokenColor: DockColor(red: 0.78, green: 0.22, blue: 0.62),
            lineWidth: 2.4
        )
        let variants: [(String, DSAppearanceMode, NSAppearance.Name, DSAccessibilityOverrides, Bool)] = [
            ("light", .light, .aqua, .init(), false), ("dark", .dark, .darkAqua, .init(), false),
            ("contrast", .dark, .accessibilityHighContrastDarkAqua, .init(increaseContrast: true), false),
            ("opaque", .dark, .darkAqua, .init(reduceTransparency: true), false),
            ("motion", .light, .aqua, .init(reduceMotion: true), false),
            ("grayscale", .light, .aqua, .init(), true)
        ]
        for (name, mode, appearance, overrides, grayscale) in variants {
            let settings = ScrollView {
                OpenCodeSettingsView(store: store, preferences: preferences)
                    .padding(32)
            }
            .frame(width: 900, height: 720)
            let root = DockMagicThemeRoot(
                content: settings.background(ProjectTheme.current.opaqueSurface),
                appearanceMode: mode
            )
            .environment(\.dsAccessibilityOverrides, overrides)
            try await capture(
                root,
                size: CGSize(width: 900, height: 720),
                appearance: appearance,
                name: "settings-\(name)",
                grayscale: grayscale
            )
        }
    }
    func testDockRasterAtSmallSizesAndAccessibilitySettings() throws {
        // Match the production Dock renderer directly; NSHostingView cacheDisplay can omit GPU text layers.
        let state = OpenCodeUsageState(snapshot: fixture(), observation: .current)
        let variants: [(String, DSAppearanceMode, DSAccessibilityOverrides)] = [
            ("light", .light, .init()), ("dark", .dark, .init()),
            ("contrast", .dark, .init(increaseContrast: true)),
            ("opaque", .dark, .init(reduceTransparency: true)),
            ("motion", .light, .init(reduceMotion: true))
        ]
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, mode, overrides) in variants {
            for size in [32.0, 48, 64] {
                let content = DockMagicThemeRoot(content:
                    DockTileView(presentation: .openCode(state: state, appearance: .standard), animatesChanges: false)
                        .frame(width: size, height: size), appearanceMode: mode)
                    .environment(\.dsAccessibilityOverrides, overrides)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage)
                XCTAssertEqual(image.width, Int(size * 2))
                XCTAssertEqual(image.height, Int(size * 2))
                let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try data.write(to: output.appendingPathComponent("dock-\(name)-\(Int(size)).png"))
            }
        }
    }
    private func capture<Content: View>(_ content: Content, size: CGSize, appearance: NSAppearance.Name, name: String, grayscale: Bool = false) async throws {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: appearance)
        window.setFrameOrigin(NSPoint(x: 120, y: 120)); window.contentView = host
        window.orderFront(nil)
        host.wantsLayer = true
        try await Task.sleep(for: .milliseconds(500))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        var data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        if grayscale {
            let input = try XCTUnwrap(CIImage(data: data))
            let filter = try XCTUnwrap(CIFilter(name: "CIColorControls"))
            filter.setValue(input, forKey: kCIInputImageKey)
            filter.setValue(0, forKey: kCIInputSaturationKey)
            let image = try XCTUnwrap(filter.outputImage)
            let cg = try XCTUnwrap(CIContext().createCGImage(image, from: image.extent))
            data = try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try data.write(to: output.appendingPathComponent("native-\(name).png"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "OpenCode \(name)"; attachment.lifetime = .keepAlways; add(attachment)
        window.close()
    }
}
