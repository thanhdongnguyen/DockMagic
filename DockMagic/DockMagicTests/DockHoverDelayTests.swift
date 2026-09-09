import AppKit
import XCTest

@testable import DockMagic

final class DockHoverDelayTests: XCTestCase {
    @MainActor
    func testDashboardRequiresOneSecondDespiteRepeatedDockNotifications() async throws {
        let model = makeModel(feature: .codex)
        let controller = DockHoverPanelController()
        let anchor = try makeAnchor()
        defer { controller.hide() }

        let start = ContinuousClock.now
        controller.scheduleShow(anchor: anchor, appModel: model)
        XCTAssertFalse(controller.isVisible)
        while start.duration(to: .now) < .seconds(2) {
            // AX selection changes and health checks must not restart the delay.
            controller.scheduleShow(anchor: anchor, appModel: model)
            if controller.isVisible {
                XCTAssertGreaterThanOrEqual(start.duration(to: .now), .seconds(1))
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Continuous hover should reveal the dashboard after one second.")
    }

    @MainActor
    func testLeavingBeforeDeadlineCancelsAndReentryStartsAFullDelay() async throws {
        let model = makeModel(feature: .claudeCode)
        let controller = DockHoverPanelController(showDelay: .milliseconds(400))
        let anchor = try makeAnchor()
        defer { controller.hide() }

        controller.scheduleShow(anchor: anchor, appModel: model)
        try await Task.sleep(for: .milliseconds(200))
        controller.scheduleHide()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(controller.isVisible, "A brief hover must never open the dashboard.")

        controller.scheduleShow(anchor: anchor, appModel: model)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(controller.isVisible, "Separate hovers must not accumulate dwell time.")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(controller.isVisible)
    }

    @MainActor
    func testOpeningDockMenuCancelsPendingDashboard() async throws {
        let model = makeModel(feature: .codex)
        let controller = DockHoverPanelController(showDelay: .milliseconds(100))
        let coordinator = DockHoverCoordinator(
            appModel: model, permissionController: DockHoverPermissionController(),
            panelController: controller)
        defer { coordinator.stop() }

        controller.scheduleShow(anchor: try makeAnchor(), appModel: model)
        coordinator.dockMenuWillOpen()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(controller.isVisible, "The pending hover must not cover the Dock menu.")
    }

    @MainActor
    func testDisablingHoverBeforeDeadlinePreventsPresentation() async throws {
        let model = makeModel(feature: .claudeCode)
        let controller = DockHoverPanelController(showDelay: .milliseconds(100))
        defer { controller.hide() }

        controller.scheduleShow(anchor: try makeAnchor(), appModel: model)
        model.preferences.isDockHoverDashboardEnabled = false
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(controller.isVisible)
    }

    @MainActor
    private func makeModel(feature: DockFeature) -> DockAppModel {
        let suite = "DockMagicTests.HoverDelay.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = feature
        preferences.isDockHoverDashboardEnabled = true
        preferences.automaticallyConfigureClaudeCode = false
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return DockAppModel(
            preferences: preferences,
            streakStore: TokenUsageStreakStore(
                modelContainer: TokenUsageStreakStore.inMemoryContainer()))
    }

    @MainActor
    private func makeAnchor() throws -> DockHoverAnchor {
        let screen = try XCTUnwrap(NSScreen.main)
        return DockHoverAnchor(
            iconFrame: CGRect(x: screen.frame.midX, y: screen.frame.minY, width: 64, height: 64),
            screen: screen, pointerEdge: .bottom)
    }
}
