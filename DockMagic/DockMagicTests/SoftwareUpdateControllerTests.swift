import XCTest
@testable import DockMagic

final class SoftwareUpdateControllerTests: XCTestCase {
    @MainActor
    func testControllerPublishesAvailableVersionAndInvokesClient() {
        let client = makeClient(availableVersion: nil)
        let controller = SoftwareUpdateController(client: client)

        controller.start()
        controller.checkForUpdates()
        client.setAvailableVersion("1.0.2")

        XCTAssertEqual(client.startCallCount, 1)
        XCTAssertEqual(client.checkForUpdatesCallCount, 1)
        XCTAssertEqual(controller.availableVersion, "1.0.2")
        XCTAssertTrue(controller.canCheckForUpdates)
    }

    @MainActor
    func testDisablingAutomaticChecksAlsoDisablesAutomaticDownloads() {
        let client = makeClient(
            automaticallyChecksForUpdates: true,
            automaticallyDownloadsUpdates: true
        )
        let controller = SoftwareUpdateController(client: client)

        controller.setAutomaticallyChecksForUpdates(false)

        XCTAssertFalse(controller.automaticallyChecksForUpdates)
        XCTAssertFalse(controller.automaticallyDownloadsUpdates)
    }

    @MainActor
    func testAutomaticDownloadsRequireChecksAndUpdaterSupport() {
        let client = makeClient(
            automaticallyChecksForUpdates: false,
            automaticallyDownloadsUpdates: false,
            allowsAutomaticUpdates: true
        )
        let controller = SoftwareUpdateController(client: client)

        controller.setAutomaticallyDownloadsUpdates(true)
        XCTAssertFalse(controller.automaticallyDownloadsUpdates)

        controller.setAutomaticallyChecksForUpdates(true)
        controller.setAutomaticallyDownloadsUpdates(true)
        XCTAssertTrue(controller.automaticallyDownloadsUpdates)
    }

    @MainActor
    func testDisabledControllerNeverAdvertisesUpdaterActions() {
        let controller = SoftwareUpdateController.disabled()

        XCTAssertFalse(controller.state.isConfigured)
        XCTAssertNil(controller.availableVersion)
        XCTAssertFalse(controller.canCheckForUpdates)
        XCTAssertFalse(controller.allowsAutomaticUpdates)
    }

    @MainActor
    private func makeClient(
        availableVersion: String? = nil,
        automaticallyChecksForUpdates: Bool = true,
        automaticallyDownloadsUpdates: Bool = false,
        allowsAutomaticUpdates: Bool = true
    ) -> SoftwareUpdateFixtureClient {
        SoftwareUpdateFixtureClient(
            state: SoftwareUpdateState(
                isConfigured: true,
                availableVersion: availableVersion,
                canCheckForUpdates: true,
                automaticallyChecksForUpdates:
                    automaticallyChecksForUpdates,
                automaticallyDownloadsUpdates:
                    automaticallyDownloadsUpdates,
                allowsAutomaticUpdates: allowsAutomaticUpdates
            )
        )
    }
}
