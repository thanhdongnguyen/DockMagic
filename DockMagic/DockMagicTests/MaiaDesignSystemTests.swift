import AppKit
import CoreText
import SwiftUI
import XCTest
@testable import DockMagic

final class MaiaDesignSystemTests: XCTestCase {
    func testSliderDoesNotRenderVisibleThumb() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let slider = try String(
            contentsOf: repositoryRoot.appending(path: "DockMagic/DockMagic/DesignSystem/Components/DSSlider.swift")
        )
        XCTAssertTrue(slider.contains("Preserve AppKit's native knob geometry for hit-testing"))
        XCTAssertTrue(slider.contains("override func knobRect"))
        XCTAssertFalse(slider.contains("NSBezierPath(ovalIn: knobRect"))
    }

    func testSwitchStyleUsesDedicatedBlueControlTokens() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let controls = try String(
            contentsOf: repositoryRoot.appending(path: "DockMagic/DockMagic/DesignSystem/Components/DSFormControls.swift")
        )
        XCTAssertTrue(controls.contains("theme.switchActive"))
        XCTAssertTrue(controls.contains("theme.onSwitchActive"))
        XCTAssertFalse(controls.contains("configuration.isOn ? theme.action : theme.surfaceInset"))
    }

    func testAntigravityDashboardUsesCodexActivityDataRoles() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dashboard = try String(
            contentsOf: root.appendingPathComponent(
                "DockMagic/Views/Hover/AntigravityHoverDashboardView.swift"
            ),
            encoding: .utf8
        )
        let export = try String(
            contentsOf: root.appendingPathComponent(
                "DockMagic/Services/CodexDashboardCaptureService.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            dashboard.contains("activityColor: Color { theme.codexActivity }")
        )
        XCTAssertTrue(
            dashboard.contains(
                "activityForeground: Color { theme.codexActivityForeground }"
            )
        )
        XCTAssertTrue(dashboard.contains("usageAccent: activityColor"))
        XCTAssertTrue(dashboard.contains("dataColor: activityColor"))
        XCTAssertTrue(dashboard.contains("accentForeground: activityForeground"))
        XCTAssertEqual(
            dashboard.components(separatedBy: "unknownDayStyle: .dash").count - 1,
            2
        )
        XCTAssertEqual(
            dashboard.components(separatedBy: "accent: activityColor").count - 1,
            3
        )
        XCTAssertTrue(
            export.contains("case .codex, .antigravity: theme.codexActivity")
        )
        XCTAssertTrue(
            export.contains("brand == .codex || brand == .antigravity")
        )
    }

    func testAIUsageDashboardsShareOneHistoryRenderer() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        func source(_ path: String) throws -> String {
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        }

        let adapter = try source(
            "DockMagic/Views/Shared/ProviderDailyUsageBars.swift"
        )
        let renderer = try source(
            "DockMagic/Views/Shared/AIUsageHistoryChart.swift"
        )
        let controls = try source(
            "DockMagic/DesignSystem/Components/DSControls.swift"
        )
        let openCode = try source(
            "DockMagic/Views/Hover/OpenCodeHoverDashboardView.swift"
        )
        let rootView = try source(
            "DockMagic/Views/Shared/DockHoverDashboardRoot.swift"
        )

        XCTAssertTrue(adapter.contains("AIUsageHistoryChart("))
        XCTAssertFalse(adapter.contains("RoundedRectangle("))
        XCTAssertTrue(
            renderer.contains(
                "DSContentButtonStyle(dimsWhenDisabled: isSelectionEnabled)"
            )
        )
        XCTAssertTrue(controls.contains("var dimsWhenDisabled = true"))
        XCTAssertTrue(openCode.contains("AIUsageTokenHistoryChart("))
        XCTAssertTrue(openCode.contains("dataColor: resolvedChartColor"))
        XCTAssertTrue(
            rootView.contains(
                "appearance: appModel.preferences.openCodeAppearance"
            )
        )
    }

    func testRequestedAIUsageDashboardsShareDailyIntensityComponent() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        func source(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        }

        let shared = try source("DockMagic/Views/Shared/AIUsageCards.swift")
        XCTAssertTrue(shared.contains("struct AIUsageDailyIntensityCard: View"))

        let dashboards = [
            "DockMagic/Views/Hover/CodexHoverDashboardView.swift",
            "DockMagic/Views/Hover/ClaudeCodeHoverDashboardView.swift",
            "DockMagic/Views/Hover/AntigravityHoverDashboardView.swift",
            "DockMagic/Views/Hover/OpenCodeHoverDashboardView.swift",
        ]
        for path in dashboards {
            XCTAssertTrue(
                try source(path).contains("AIUsageDailyIntensityCard("),
                "\(path) must reuse the shared daily intensity component"
            )
        }
    }

    @MainActor func testBundledFontWeightsAndVietnameseFallback() {
        DSFonts.register()
        for weight: Font.Weight in [.regular, .medium, .semibold, .bold] {
            let font = DSFonts.coreText(size: 16, weight: weight)
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, DSFonts.name(for: weight))
            let sample = "Tiếng Việt: Trường, Nguyễn, Đặng · 0123456789 · 1.234 ₫"
            for text in [sample.precomposedStringWithCanonicalMapping, sample.decomposedStringWithCanonicalMapping] {
                let string = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                let line = CTLineCreateWithAttributedString(string)
                for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                    var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
                    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                    XCTAssertFalse(glyphs.contains(0), "Missing glyph in \(text)")
                }
            }
        }
    }

    func testZeroUnknownStalePartialAndFailureRemainDistinct() {
        XCTAssertEqual(DSMetricValue.percent(0).value?.formatted, "0%")
        XCTAssertNil(DSMetricValue.percent(nil).value)
        XCTAssertNil(DSMetricValue.percent(.nan).value)
        XCTAssertNil(DSMetricValue.percent(.infinity).value)
        XCTAssertNil(DSProgressValue.normalized(nil))
        XCTAssertNil(DSProgressValue.normalized(.nan))
        XCTAssertEqual(DSProgressValue.normalized(0), 0)
        let value = DSMetricValue(formatted: "42", unit: "tokens")
        let stale = DSDataState.stale(value, detail: "Updated yesterday")
        let partial = DSDataState.partial(value, detail: "One day missing")
        let failed = DSDataState.failed("Offline", lastValue: value)
        XCTAssertEqual(stale.value, value)
        XCTAssertTrue(stale.detail?.contains("Stale") == true)
        XCTAssertTrue(partial.detail?.contains("Partial") == true)
        XCTAssertEqual(failed.value, value)
        XCTAssertEqual(failed.detail, "Offline")
    }

    @MainActor func testEveryBundledIconAndDomainSymbolResolves() {
        for icon in DSIconName.allCases {
            XCTAssertNotNil(NSImage(named: icon.rawValue), "Missing \(icon.rawValue)")
        }
        for feature in DockFeature.allCases {
            XCTAssertNotNil(DSIconName.fromLegacySymbol(feature.systemImage), "Unmapped \(feature.systemImage)")
        }
        for mode in DSAppearanceMode.allCases {
            XCTAssertNotNil(DSIconName.fromLegacySymbol(mode.systemImage))
        }
        for seconds in NowPlayingConfiguration.skipIntervals {
            XCTAssertNotNil(DSIconName.fromLegacySymbol("gobackward.\(seconds)"))
            XCTAssertNotNil(DSIconName.fromLegacySymbol("goforward.\(seconds)"))
        }
        XCTAssertEqual(
            DSIconName.fromLegacySymbol("accessibility"),
            .accessibility
        )
        XCTAssertNil(DSIconName.fromLegacySymbol("not-a-supported-symbol"))
    }

    @MainActor func testPrimaryTextAndActionContrastInBothAppearances() {
        let theme = ProjectTheme.current
        for scheme: ColorScheme in [.light, .dark] {
            for pair in [(theme.textPrimary, theme.surface), (theme.textSecondary, theme.surfaceRaised),
                         (theme.onAction, theme.action), (theme.textPrimary, theme.surfaceInset)] {
                let fg = ProjectTheme.resolvedColor(pair.0, colorScheme: scheme)
                let bg = ProjectTheme.resolvedColor(pair.1, colorScheme: scheme)
                XCTAssertGreaterThanOrEqual(ProjectTheme.rendererContrast(fg, bg), 4.5)
            }
        }
    }

    @MainActor func testActiveStreakDayUsesSharedAccessibleGreenRole() throws {
        let theme = ProjectTheme.current
        for scheme: ColorScheme in [.light, .dark] {
            let fill = ProjectTheme.resolvedColor(theme.streakActive, colorScheme: scheme)
            let check = ProjectTheme.resolvedColor(theme.onStreakActive, colorScheme: scheme)
            let surface = ProjectTheme.resolvedColor(theme.surfaceRaised, colorScheme: scheme)
            XCTAssertGreaterThanOrEqual(
                ProjectTheme.rendererContrast(fill, surface),
                3,
                "Active streak-day fill must remain visible in \(scheme)"
            )
            XCTAssertGreaterThanOrEqual(
                ProjectTheme.rendererContrast(check, fill),
                4.5,
                "Active streak-day check must remain legible in \(scheme)"
            )
        }

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "DockMagic/Views/Hover/StreakDashboardViews.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains(".fill(theme.streakActive)"))
        XCTAssertTrue(source.contains(".foregroundStyle(theme.onStreakActive)"))
    }

    @MainActor func testComponentRenderMatrix() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DockMagic-Maia-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for mode: DSAppearanceMode in [.light, .dark] {
            for variant in ["standard", "contrast", "transparency", "motion", "grayscale"] {
                let content = DSSettingsSection(title: "Maia · bbVKHJo", detail: "Geist · Tiếng Việt · ₫ · native components") {
                    HStack {
                        Button("Primary") {}.buttonStyle(DSButtonStyle(emphasis: .primary))
                        Button("Outline") {}.buttonStyle(DSButtonStyle())
                        Button("Delete") {}.buttonStyle(DSButtonStyle(emphasis: .primary, intent: .destructive))
                        Button("Disabled") {}.disabled(true)
                    }
                    HStack {
                        DSMetricCard(title: "Zero", icon: .chart, state: DSMetricValue.percent(0))
                        DSMetricCard(title: "Unknown", icon: .help, state: DSMetricValue.percent(nil))
                        DSMetricCard(title: "Stale", icon: .clock, state: .stale(.init(formatted: "42%", fraction: 0.42), detail: "Last observation"))
                    }
                    DSStatusCard(title: "Disconnected", detail: "Reconnect to refresh your data", systemImage: "info.circle", role: .neutral)
                    HStack { ForEach([DSIconName.calendar, .settings, .cpu, .cloudSun, .check], id: \.rawValue) { DSIcon($0, size: 24) } }
                }
                let view = DockMagicThemeRoot(content: content.padding(24).background(ProjectTheme.current.surface), appearanceMode: mode)
                    .environment(\.dsAccessibilityOverrides, .init(reduceTransparency: variant == "transparency",
                        increaseContrast: variant == "contrast", reduceMotion: variant == "motion"))
                    .saturation(variant == "grayscale" ? 0 : 1)
                    .frame(width: 900, height: 440)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage)
                let bitmap = NSBitmapImageRep(cgImage: image)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                XCTAssertGreaterThan(data.count, 12_000)
                let filename = "maia-\(mode.rawValue)-\(variant).png"
                try data.write(to: directory.appendingPathComponent(filename))
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = filename
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}

extension MaiaDesignSystemTests {
    @MainActor func testNativeEditorPreservesVietnameseCompositionPasteAndUndo() throws {
        try verifyNativeEditing(styled: true)
    }

    @MainActor func testSystemEditorComparisonPreservesVietnameseCompositionPasteAndUndo() throws {
        try verifyNativeEditing(styled: false)
    }

    @MainActor private func verifyNativeEditing(styled: Bool) throws {
        let fixture = MaiaEditingFixture()
        let content = MaiaEditingFixtureView(fixture: fixture, styled: styled).frame(width: 360, height: 100)
        let host = NSHostingView(rootView: DockMagicThemeRoot(content: content))
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: 360, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.contentView = nil; window.close() }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        host.layoutSubtreeIfNeeded()
        func field(in view: NSView) -> NSTextField? {
            if let view = view as? NSTextField { return view }
            return view.subviews.lazy.compactMap { field(in: $0) }.first
        }
        let input = try XCTUnwrap(field(in: host))
        window.makeFirstResponder(input)
        let editor = try XCTUnwrap(window.fieldEditor(true, for: input) as? NSTextView)
        editor.allowsUndo = true
        let sample = "Tiếng Việt · Nguyễn · 1.234 ₫"
        editor.setMarkedText("Tie", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        editor.insertText(sample, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        XCTAssertFalse(editor.hasMarkedText())
        XCTAssertEqual(editor.string, sample)
        editor.selectAll(nil)
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally() }
        clipboard.setString(sample.decomposedStringWithCanonicalMapping, forType: .string)
        XCTAssertTrue(editor.readSelection(from: clipboard))
        XCTAssertEqual(editor.string.precomposedStringWithCanonicalMapping, sample)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        editor.undoManager?.removeAllActions()
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        editor.insertText(" 123", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.string.hasSuffix(" 123"))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(fixture.value.hasSuffix(" 123"))
        XCTAssertTrue(editor.tryToPerform(NSSelectorFromString("undo:"), with: nil))
        XCTAssertFalse(editor.string.hasSuffix(" 123"))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        window.makeFirstResponder(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        // Direct NSTextView undo changes the editor correctly, but this offscreen
        // NSHostingView harness does not deliver the change back to SwiftUI's
        // binding. The unstyled comparison above reproduces it. Keep this strict
        // expected failure visible until the harness/platform behavior changes;
        // MaiaUITests verifies the actual Command-Z path in a running app.
        XCTExpectFailure("Offscreen native SwiftUI editor binding after undo; reproduced with unstyled TextField") {
            XCTAssertEqual(fixture.value.precomposedStringWithCanonicalMapping, sample)
        }
    }

    @MainActor func testSliderKeyboardUsesDeclaredStepAndClamps() throws {
        let slider = DSNativeSlider(frame: NSRect(x: 0, y: 0, width: 200, height: 36))
        slider.minValue = 1; slider.maxValue = 4; slider.doubleValue = 1; slider.keyboardStep = 0.2
        let right = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "\u{F703}", charactersIgnoringModifiers: "\u{F703}", isARepeat: false, keyCode: 124))
        slider.keyDown(with: right)
        XCTAssertEqual(slider.doubleValue, 1.2, accuracy: 0.0001)
        slider.doubleValue = 3.9
        slider.keyDown(with: right)
        XCTAssertEqual(slider.doubleValue, 4)
    }
}

extension MaiaDesignSystemTests {
    @MainActor func testProductionGalleryRendersNativeControlsInBothModes() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DockMagic-Maia-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for mode in [DSAppearanceMode.light, .dark] {
            let size = NSSize(width: 1160, height: 900)
            let host = NSHostingView(rootView: DSComponentGallery(appearance: mode))
            let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -20000, y: -20000), size: size),
                styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: mode == .dark ? .darkAqua : .aqua)
            window.contentView = host
            defer { window.contentView = nil; window.close() }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(data.count, 20_000)
            try data.write(to: directory.appendingPathComponent("gallery-\(mode.rawValue).png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "Maia gallery \(mode.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}

@MainActor private final class MaiaEditingFixture: ObservableObject {
    @Published var value = ""
}
private struct MaiaEditingFixtureView: View {
    @ObservedObject var fixture: MaiaEditingFixture
    let styled: Bool
    var body: some View {
        if styled {
            DSField(title: "Vietnamese") { DSTextInput(title: "Vietnamese", text: $fixture.value) }
        } else {
            TextField("Vietnamese", text: $fixture.value).textFieldStyle(.plain)
        }
    }
}


extension MaiaDesignSystemTests {
    func testSelectionNavigationSkipsUnavailableAndHandlesChangedOptions() {
        let options: [DSSelectOption<String>] = [
            .init(value: "line", title: "Line"),
            .init(value: "disabled", title: "Unavailable", disabled: true),
            .init(value: "candle", title: "Candlestick")
        ]
        XCTAssertEqual(DSSelectionNavigation.next(from: "line", options: options, forward: true), "candle")
        XCTAssertEqual(DSSelectionNavigation.next(from: "candle", options: options, forward: false), "line")
        XCTAssertEqual(DSSelectionNavigation.next(from: "candle", options: options, forward: true), "candle")
        XCTAssertEqual(DSSelectionNavigation.next(from: "line", options: options, forward: false), "line")
        XCTAssertEqual(DSSelectionNavigation.next(from: "removed", options: options, forward: true), "line")
        XCTAssertEqual(DSSelectionNavigation.next(from: nil, options: options, forward: false), "candle")
        XCTAssertNil(DSSelectionNavigation.next(from: "line", options: [], forward: true))
        XCTAssertNil(DSSelectionNavigation.next(from: "disabled", options: [options[1]], forward: true))
    }

    /// Prevent a default AppKit picker or a separate selection menu from returning
    /// to app-owned screens when a new feature is added.
    func testFeatureSelectionUsesMaiaControls() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DockMagic/Views")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file)
            XCTAssertNil(source.range(of: #"\bPicker\s*\("#, options: .regularExpression), file.lastPathComponent)
            XCTAssertFalse(source.contains(".pickerStyle("), file.lastPathComponent)
        }
    }

    @MainActor func testSelectionControlsRenderAcrossAppearanceAndAccessibility() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DockMagic-Maia-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for mode in [DSAppearanceMode.light, .dark] {
            for variant in ["standard", "contrast", "transparency", "motion", "grayscale"] {
                let content = VStack(spacing: 16) {
                    DSSettingsSection(title: "Dock display", detail: "Chart or direct numeric values") {
                        DSSegmentedControl(title: "Dock display", selection: .constant("numbers"), options: [
                            .init(value: "chart", title: "Chart"), .init(value: "numbers", title: "Numbers")
                        ])
                    }
                    HStack {
                        DSSegmentedControl(title: "Chart type", selection: .constant("line"), options: [
                            .init(value: "line", title: "Line"), .init(value: "candle", title: "Candlestick")
                        ], size: .small).frame(width: 210)
                        DSSelect(title: "Source", selection: .constant("auto"), options: [
                            .init(value: "auto", title: "Automatic"), .init(value: "disabled", title: "Unavailable", disabled: true)
                        ], size: .small).labelsHidden().frame(width: 160)
                    }
                    DSSegmentedControl(title: "Partial options", selection: .constant(0), options: [
                        .init(value: 0, title: "Tokens"), .init(value: 1, title: "Unavailable", disabled: true),
                        .init(value: 2, title: "Billed USD")
                    ])
                    DSSegmentedControl(title: "Disabled", selection: .constant(0), options: [
                        .init(value: 0, title: "System"), .init(value: 1, title: "Light"), .init(value: 2, title: "Dark")
                    ]).disabled(true)
                    DSSelect(title: "Missing selection", selection: .constant("missing"), options: [DSSelectOption<String>]())
                }.padding(24).frame(width: 600).background(ProjectTheme.current.surface)
                let view = DockMagicThemeRoot(content: content, appearanceMode: mode)
                    .environment(\.dsAccessibilityOverrides, .init(reduceTransparency: variant == "transparency",
                        increaseContrast: variant == "contrast", reduceMotion: variant == "motion"))
                    .saturation(variant == "grayscale" ? 0 : 1)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage)
                let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                let name = "selection-\(mode.rawValue)-\(variant).png"
                try data.write(to: directory.appendingPathComponent(name))
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}
