import Observation
import ServiceManagement

enum LaunchAtLoginServiceStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

enum LaunchAtLoginState: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var isRequested: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .disabled, .unavailable:
            false
        }
    }

    var canChange: Bool {
        self != .unavailable
    }

    var detail: String {
        switch self {
        case .disabled:
            "DockMagic starts only when you open it."
        case .enabled:
            "DockMagic starts automatically after you sign in."
        case .requiresApproval:
            "Approve DockMagic in System Settings → General → Login Items."
        case .unavailable:
            "Launch at login is unavailable for this app build."
        }
    }
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var status: LaunchAtLoginServiceStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
private final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private let service = SMAppService.mainApp

    var status: LaunchAtLoginServiceStatus {
        switch service.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class LaunchAtLoginController {
    private(set) var state: LaunchAtLoginState
    private(set) var errorDescription: String?

    @ObservationIgnored
    private let service: any LaunchAtLoginServicing

    init(service: (any LaunchAtLoginServicing)? = nil) {
        let service = service ?? SystemLaunchAtLoginService()
        self.service = service
        state = Self.state(for: service.status)
    }

    func setEnabled(_ isEnabled: Bool) {
        errorDescription = nil

        do {
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorDescription = "Couldn't \(isEnabled ? "enable" : "disable") launch at login. \(error.localizedDescription)"
        }

        state = Self.state(for: service.status)
        if state.isRequested == isEnabled {
            errorDescription = nil
        }
    }

    func refresh() {
        state = Self.state(for: service.status)
        errorDescription = nil
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }

    private static func state(
        for status: LaunchAtLoginServiceStatus
    ) -> LaunchAtLoginState {
        switch status {
        case .notRegistered:
            .disabled
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        }
    }
}
