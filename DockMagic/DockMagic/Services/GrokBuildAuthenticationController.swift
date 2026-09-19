import Foundation
import Observation

protocol GrokBuildAuthenticationRunning: Sendable {
    func signIn(configuration: GrokBuildCLIConfiguration, deviceCode: Bool,
                onOutput: @escaping @Sendable (Data) -> Void) async throws -> Int32
}

struct GrokBuildAuthenticationRunner: GrokBuildAuthenticationRunning {
    static let maximumOutputBytes = 64 * 1_024
    static func request(configuration: GrokBuildCLIConfiguration, deviceCode: Bool) -> GrokBuildProcessRequest {
        .init(executable: configuration.executable,
              arguments: GrokBuildCLIProvider.loginArguments(deviceCode: deviceCode),
              environment: configuration.environment(), operation: .authentication,
              timeout: 300, maximumOutputBytes: maximumOutputBytes)
    }

    func signIn(configuration: GrokBuildCLIConfiguration, deviceCode: Bool,
                onOutput: @escaping @Sendable (Data) -> Void) async throws -> Int32 {
        try await GrokBuildCLIProvider().verifyAuthenticationCommandVersion(configuration: configuration)
        return try await GrokBuildProcessRunner().run(Self.request(configuration: configuration, deviceCode: deviceCode),
                                                    onOutput: onOutput).exitCode
    }
}

/// Owns the fixed CLI login command, not credentials or account identity.
/// The CLI owns browser/device authorization; only a fresh billing response
/// can establish the store's connected state.
@MainActor
@Observable
final class GrokBuildAuthenticationController {
    private(set) var attempt: GrokBuildSignInAttempt?
    private(set) var output = Data()
    private(set) var isCancelling = false
    private(set) var usesDeviceCode = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var acceptsOutput = false
    @ObservationIgnored private let runner: any GrokBuildAuthenticationRunning
    @ObservationIgnored private let supportedVersions: Set<String>

    init(runner: any GrokBuildAuthenticationRunning = GrokBuildAuthenticationRunner(),
         supportedVersions: Set<String> = GrokBuildFeatureGate.authenticationCommandVersions) {
        self.runner = runner
        self.supportedVersions = supportedVersions
    }

    var isRunning: Bool { attempt != nil }
    func supports(version: String?) -> Bool { version.map(supportedVersions.contains) ?? false }

    @discardableResult
    func start(store: GrokBuildUsageStore, deviceCode: Bool) -> Bool {
        guard task == nil, supports(version: store.cliVersion), let attempt = store.beginSignIn() else { return false }
        self.attempt = attempt
        output = Data()
        isCancelling = false
        acceptsOutput = true
        usesDeviceCode = deviceCode
        task = Task { @MainActor [weak self, weak store, runner] in
            var code: Int32?
            var failure: GrokBuildError?
            do {
                code = try await runner.signIn(configuration: attempt.configuration, deviceCode: deviceCode) { [weak self] bytes in
                    Task { @MainActor [weak self] in self?.receive(bytes, attempt: attempt) }
                }
                try Task.checkCancellation()
            } catch is CancellationError { failure = .cancelled }
            catch { failure = error as? GrokBuildError ?? .commandFailed }
            guard let self, self.attempt == attempt else { return }
            self.acceptsOutput = false
            // Raw login URLs/device codes are transient. Drop them on every
            // exit, including failed login, timeout, cancellation and overflow.
            self.output = Data()
            await store?.finishSignIn(attempt: attempt, exitCode: failure == nil ? code : nil, failure: failure)
            guard self.attempt == attempt else { return }
            self.attempt = nil
            self.task = nil
            self.isCancelling = false
        }
        return true
    }

    func cancel() {
        guard task != nil else { return }
        isCancelling = true
        acceptsOutput = false
        output = Data()
        task?.cancel()
        // Keep the attempt busy until owned-process teardown has finished.
        // A retry must not overlap the cancelled command against the same home.
    }

    private func receive(_ bytes: Data, attempt: GrokBuildSignInAttempt) {
        guard self.attempt == attempt, acceptsOutput, !isCancelling else { return }
        guard output.count + bytes.count <= GrokBuildAuthenticationRunner.maximumOutputBytes else {
            cancel()
            return
        }
        output.append(bytes)
    }

    deinit { task?.cancel() }
}
