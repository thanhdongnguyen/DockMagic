import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

@MainActor
final class AugmentIntegrationTests: XCTestCase {
    func testFeatureDefaultsManifestAndSameDayPresentation() {
        let appearance = AugmentDockAppearance.standard
        XCTAssertEqual(appearance.metric, .tokens)
        XCTAssertEqual(appearance.displayStyle, .numeric)
        XCTAssertTrue(DockFeature.augment.hasHoverDashboard)
        XCTAssertEqual(AugmentDashboardManifest.selectedModules.count, 7)
        XCTAssertTrue(AugmentDashboardManifest.excluded.contains("totalTokens"))
        XCTAssertTrue(AugmentDashboardManifest.selectedModules.contains(.continuity))
        XCTAssertTrue(AugmentDashboardManifest.selectedModules.contains(.dailyIntensity))
        XCTAssertTrue(AugmentDashboardManifest.excluded.contains("personalStreak"))
        let range = AugmentDateRange.reported(days: 7, now: Date())
        let days = [AugmentDailyBucket(date: range.start, metrics: .init(input: 123, output: 456)),
                    AugmentDailyBucket(date: range.end, metrics: .init(input: 0, output: nil))]
        let snapshot = AugmentUsageSnapshot(range: range, days: days, fetchedAt: Date(), generatedAt: nil)
        XCTAssertEqual(snapshot.latest?.metrics.input, 0)
        XCTAssertNil(snapshot.latest?.metrics.output)
        XCTAssertEqual(AugmentPresentation.trend(snapshot, metric: .input), [123, nil, nil, nil, nil, nil, 0])
        XCTAssertEqual(AugmentPresentation.trend(snapshot, metric: .output), [456, nil, nil, nil, nil, nil, nil])
    }

    func testOrganizationContinuityAndOutputIntensityPreserveZeroAndUnknownDays() throws {
        let start = try XCTUnwrap(AugmentUTC.date("2026-09-01"))
        let end = try XCTUnwrap(AugmentUTC.date("2026-09-07"))
        let range = AugmentDateRange(start: start, end: end)
        let dates = range.dates
        let days = [
            AugmentDailyBucket(date: dates[0], metrics: .init(output: 10)),
            AugmentDailyBucket(date: dates[1], metrics: .init(output: 20)),
            AugmentDailyBucket(date: dates[2], metrics: .init(output: 0)),
            AugmentDailyBucket(date: dates[4], metrics: .init(input: 1, output: nil)),
            AugmentDailyBucket(date: dates[5], metrics: .init(output: 3)),
            AugmentDailyBucket(date: dates[6], metrics: .init(output: 4)),
        ]
        let snapshot = AugmentUsageSnapshot(
            range: range,
            days: days,
            fetchedAt: end,
            generatedAt: nil
        )

        let continuity = AugmentPresentation.organizationContinuity(snapshot)
        XCTAssertEqual(continuity.currentDays, 3)
        XCTAssertEqual(continuity.bestDays, 3)
        XCTAssertEqual(
            continuity.recentDays.map(\.state),
            [.active, .active, .inactive, .unknown, .active, .active, .active]
        )
        XCTAssertFalse(AugmentPresentation.organizationEndpointIsUnknown(snapshot))

        let intensity = AugmentPresentation.intensityBuckets(snapshot)
        XCTAssertEqual(intensity.map(\.tokens), [10, 20, 0, 0, 0, 3, 4])
        XCTAssertEqual(
            AugmentPresentation.unavailableIntensityBucketIDs(snapshot),
            Set([dates[3], dates[4]])
        )
    }

    func testSeparateKeychainItemRoundTripInSignedHost() throws {
        let vault = KeychainAugmentCredentialVault(service: "com.hypevibe.DockMagic.augment.tests.\(UUID())")
        defer { try? vault.deleteAccessToken() }
        XCTAssertNil(try vault.loadAccessToken())
        try vault.storeAccessToken("synthetic-local-test-only")
        XCTAssertEqual(try vault.loadAccessToken(), "synthetic-local-test-only")
        try vault.storeAccessToken("replacement-test-only")
        XCTAssertEqual(try vault.loadAccessToken(), "replacement-test-only")
        try vault.deleteAccessToken()
        XCTAssertNil(try vault.loadAccessToken())
    }

    func testProductionRendererAndDashboardAppearanceMatrix() async throws {
        let destination = URL(fileURLWithPath: "/private/tmp/augment-captures")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "AugmentRender.\(UUID())")!
        let store = AugmentFixtureClient.store(mode: "partial", defaults: defaults)
        store.setDashboardVisible(true)
        defer { store.stop() }
        for _ in 0..<100 {
            if store.state.snapshot != nil && !store.modelsLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotNil(store.state.snapshot)
        XCTAssertEqual(store.models?.models(by: .output).count, 4)
        for mode in [DSAppearanceMode.light, .dark] {
            let summary = AugmentPresentation.organizationContinuity(store.state.snapshot!)
            let insights = VStack(spacing: 10) {
                StreakContinuityStrip(
                    summary: summary,
                    brand: .augment,
                    accent: .purple,
                    currentDayIsUnknown: AugmentPresentation.organizationEndpointIsUnknown(store.state.snapshot!),
                    presentation: .organizationActivity,
                    onOpen: {}
                )
                AIUsageDailyIntensityCard(
                    buckets: AugmentPresentation.intensityBuckets(store.state.snapshot!),
                    accent: .purple,
                    unavailableBucketIDs: AugmentPresentation.unavailableIntensityBucketIDs(store.state.snapshot!),
                    isPartial: store.state.snapshot!.isPartial,
                    marksUnknownDays: true,
                    title: "Daily intensity · Output",
                    metricLabel: "output tokens",
                    timeZone: AugmentUTC.calendar.timeZone
                )
                .frame(height: 110)
            }
            .padding(16)
            .frame(width: 440, height: 220)
            let insightsData = try render(insights, mode: mode, size: CGSize(width: 440, height: 220))
            try insightsData.write(to: destination.appendingPathComponent("organization-insights-\(mode.rawValue).png"))

            for variant in ["standard", "contrast", "transparency", "motion", "grayscale"] {
                let content = DockHoverChrome(pointerEdge: .bottom, panelSize: CGSize(width: 440, height: 650)) {
                    AugmentHoverDashboardView(
                        store: store,
                        chartColor: DockColor(red: 0.75, green: 0.24, blue: 0.92)
                    )
                }.frame(width: 440, height: 650).saturation(variant == "grayscale" ? 0 : 1)
                let data = try render(content, mode: mode, size: CGSize(width: 440, height: 650), variant: variant)
                XCTAssertGreaterThan(data.count, 10_000)
                try data.write(to: destination.appendingPathComponent("dashboard-\(mode.rawValue)-\(variant).png"))
            }
            for size in [32.0, 48, 64, 128] {
                for style in [DockDisplayStyle.numeric, .chart] {
                    var appearance = AugmentDockAppearance.standard; appearance.displayStyle = style
                    let icon = DockTileView(presentation: .augment(state: store.state, appearance: appearance), animatesChanges: false)
                        .frame(width: size, height: size)
                    let data = try render(icon, mode: mode, size: CGSize(width: size, height: size))
                    XCTAssertGreaterThan(data.count, 200)
                    try data.write(to: destination.appendingPathComponent("dock-\(mode.rawValue)-\(style.rawValue)-\(Int(size)).png"))
                }
            }
        }
        let range = store.state.snapshot!.range
        let snapshot = store.state.snapshot!
        for observation in [AugmentObservation.notConfigured, .loading, .live, .stale, .unavailable, .failed] {
            let state = AugmentUsageState(snapshot: [.live, .stale].contains(observation) ? snapshot : nil,
                observation: observation, isRefreshing: observation == .loading)
            var appearance = AugmentDockAppearance.standard; appearance.metric = .billedUSD; appearance.displayStyle = .chart
            let data = try render(DockAugmentView(state: state, appearance: appearance).frame(width: 128, height: 128), mode: .light, size: CGSize(width: 128, height: 128))
            try data.write(to: destination.appendingPathComponent("dock-usd-\(observation.rawValue).png"))
        }
        // Exercise shared chart's gaps, zero, negative currency and partial fields.
        let chart = AIUsageHistoryChart(points: [
            .init(date: range.start, value: nil), .init(date: range.end, value: -Decimal(1) / 4, partial: true)
        ], hoveredDate: .constant(nil), plotHeight: 110, timezone: AugmentUTC.calendar.timeZone,
            metricLabel: "USD", allowsZeroSelection: true, formatValue: { AugmentFormatting.value($0, metric: .billedUSD) }, onSelect: { _ in })
        let data = try render(chart.padding().frame(width: 440, height: 200), mode: .light, size: CGSize(width: 440, height: 200))
        try data.write(to: destination.appendingPathComponent("chart-negative-missing.png"))
    }

    private func render<V: View>(_ content: V, mode: DSAppearanceMode, size: CGSize, variant: String = "standard") throws -> Data {
        let host = NSHostingView(rootView: DockMagicThemeRoot(content: content, appearanceMode: mode)
            .environment(\.dsAccessibilityOverrides, DSAccessibilityOverrides(reduceTransparency: variant == "transparency", increaseContrast: variant == "contrast", reduceMotion: variant == "motion")))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        host.appearance = NSAppearance(named: variant == "contrast" ? (mode == .dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua) : (mode == .dark ? .darkAqua : .aqua))
        window.appearance = host.appearance; window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.wantsLayer = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
