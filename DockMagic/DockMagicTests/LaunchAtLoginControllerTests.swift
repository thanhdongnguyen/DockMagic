import XCTest
@testable import DockMagic

final class LaunchAtLoginControllerTests: XCTestCase {
    @MainActor
    func testControllerRegistersAndUnregistersMainApp() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.state, .disabled)
        XCTAssertFalse(controller.state.isRequested)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertTrue(controller.state.isRequested)
        XCTAssertNil(controller.errorDescription)

        controller.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertFalse(controller.state.isRequested)
        XCTAssertNil(controller.errorDescription)
    }

    @MainActor
    func testControllerKeepsToggleOnWhileApprovalIsRequired() {
        let service = FakeLaunchAtLoginService(
            status: .notRegistered,
            statusAfterRegister: .requiresApproval
        )
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertEqual(controller.state, .requiresApproval)
        XCTAssertTrue(controller.state.isRequested)
        XCTAssertNil(controller.errorDescription)

        controller.openSystemSettings()
        XCTAssertEqual(service.openSystemSettingsCallCount, 1)
    }

    @MainActor
    func testControllerSurfacesRegistrationFailure() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.registerError = StubLaunchAtLoginError.denied
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertEqual(controller.state, .disabled)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertTrue(
            controller.errorDescription?.contains("Denied by user") == true
        )
    }

    @MainActor
    func testControllerRefreshesExternalSystemStatus() {
        let service = FakeLaunchAtLoginService(status: .notFound)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.state, .unavailable)
        XCTAssertFalse(controller.state.canChange)

        service.status = .enabled
        controller.refresh()

        XCTAssertEqual(controller.state, .enabled)
        XCTAssertTrue(controller.state.canChange)
    }
}

private enum StubLaunchAtLoginError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Denied by user."
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginServiceStatus
    var statusAfterRegister: LaunchAtLoginServiceStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSystemSettingsCallCount = 0

    init(
        status: LaunchAtLoginServiceStatus,
        statusAfterRegister: LaunchAtLoginServiceStatus = .enabled
    ) {
        self.status = status
        self.statusAfterRegister = statusAfterRegister
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSystemSettingsCallCount += 1
    }
}
