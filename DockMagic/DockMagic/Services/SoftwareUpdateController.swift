import Foundation
import Observation
import Sparkle

struct SoftwareUpdateState: Equatable {
    var isConfigured: Bool
    var availableVersion: String?
    var canCheckForUpdates: Bool
    var automaticallyChecksForUpdates: Bool
    var automaticallyDownloadsUpdates: Bool
    var allowsAutomaticUpdates: Bool
}

@MainActor
protocol SoftwareUpdateClient: AnyObject {
    var state: SoftwareUpdateState { get }
    var stateDidChange: ((SoftwareUpdateState) -> Void)? { get set }

    func start()
    func checkForUpdates()
    func setAutomaticallyChecksForUpdates(_ enabled: Bool)
    func setAutomaticallyDownloadsUpdates(_ enabled: Bool)
}

@MainActor
@Observable
final class SoftwareUpdateController {
    private(set) var state: SoftwareUpdateState

    @ObservationIgnored
    private let client: any SoftwareUpdateClient

    init(client: any SoftwareUpdateClient) {
        self.client = client
        state = client.state
        client.stateDidChange = { [weak self] state in
            self?.state = state
        }
    }

    var availableVersion: String? {
        state.availableVersion
    }

    var canCheckForUpdates: Bool {
        state.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        state.automaticallyChecksForUpdates
    }

    var automaticallyDownloadsUpdates: Bool {
        state.automaticallyDownloadsUpdates
    }

    var allowsAutomaticUpdates: Bool {
        state.allowsAutomaticUpdates
    }

    func start() {
        client.start()
    }

    func checkForUpdates() {
        client.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        client.setAutomaticallyChecksForUpdates(enabled)
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        client.setAutomaticallyDownloadsUpdates(enabled)
    }

    static func production() -> SoftwareUpdateController {
        SoftwareUpdateController(client: SparkleSoftwareUpdateClient())
    }

    static func disabled() -> SoftwareUpdateController {
        SoftwareUpdateController(
            client: SoftwareUpdateFixtureClient(
                state: SoftwareUpdateState(
                    isConfigured: false,
                    availableVersion: nil,
                    canCheckForUpdates: false,
                    automaticallyChecksForUpdates: false,
                    automaticallyDownloadsUpdates: false,
                    allowsAutomaticUpdates: false
                )
            )
        )
    }

    static func uiTestFixture(
        availableVersion: String?
    ) -> SoftwareUpdateController {
        SoftwareUpdateController(
            client: SoftwareUpdateFixtureClient(
                state: SoftwareUpdateState(
                    isConfigured: true,
                    availableVersion: availableVersion,
                    canCheckForUpdates: true,
                    automaticallyChecksForUpdates: true,
                    automaticallyDownloadsUpdates: false,
                    allowsAutomaticUpdates: true
                )
            )
        )
    }
}

@MainActor
final class SoftwareUpdateFixtureClient: SoftwareUpdateClient {
    var state: SoftwareUpdateState
    var stateDidChange: ((SoftwareUpdateState) -> Void)?
    private(set) var startCallCount = 0
    private(set) var checkForUpdatesCallCount = 0

    init(state: SoftwareUpdateState) {
        self.state = state
    }

    func start() {
        startCallCount += 1
        publish()
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        state.automaticallyChecksForUpdates = enabled
        if !enabled {
            state.automaticallyDownloadsUpdates = false
        }
        publish()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        state.automaticallyDownloadsUpdates =
            enabled
            && state.automaticallyChecksForUpdates
            && state.allowsAutomaticUpdates
        publish()
    }

    func setAvailableVersion(_ version: String?) {
        state.availableVersion = version
        publish()
    }

    private func publish() {
        stateDidChange?(state)
    }
}

@MainActor
private final class SparkleSoftwareUpdateClient: NSObject,
    SoftwareUpdateClient,
    SPUUpdaterDelegate,
    SPUStandardUserDriverDelegate
{
    private var updaterController: SPUStandardUpdaterController!
    private var canCheckForUpdatesObservation: NSKeyValueObservation?
    private var availableVersion: String?
    private var didStart = false

    var stateDidChange: ((SoftwareUpdateState) -> Void)?

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    var state: SoftwareUpdateState {
        let updater = updaterController.updater
        return SoftwareUpdateState(
            isConfigured: true,
            availableVersion: availableVersion,
            canCheckForUpdates: updater.canCheckForUpdates,
            automaticallyChecksForUpdates:
                updater.automaticallyChecksForUpdates,
            automaticallyDownloadsUpdates:
                updater.automaticallyDownloadsUpdates,
            allowsAutomaticUpdates: updater.allowsAutomaticUpdates
        )
    }

    func start() {
        guard !didStart else {
            return
        }
        didStart = true
        updaterController.startUpdater()
        canCheckForUpdatesObservation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.publish()
            }
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
        publish()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
        if !enabled {
            updaterController.updater.automaticallyDownloadsUpdates = false
        }
        publish()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        publish()
    }

    func updater(
        _ updater: SPUUpdater,
        didFindValidUpdate item: SUAppcastItem
    ) {
        availableVersion = item.displayVersionString
        publish()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        availableVersion = nil
        publish()
    }

    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        update.isCriticalUpdate
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        let displayVersion = update.displayVersionString
        Task { @MainActor [weak self] in
            self?.availableVersion = displayVersion
            self?.publish()
        }
    }

    private func publish() {
        stateDidChange?(state)
    }
}
