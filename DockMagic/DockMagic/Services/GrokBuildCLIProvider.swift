import Foundation

struct GrokBuildCLIConfiguration: Equatable, Sendable {
    let executable: URL
    let home: URL

    func environment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var result = base
        result["GROK_HOME"] = home.standardizedFileURL.path
        result["NO_COLOR"] = "1"
        result["PATH"] = executable.deletingLastPathComponent().path + ":" + (base["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        return result
    }
}

protocol GrokBuildCLIProviding: Sendable {
    func version(configuration: GrokBuildCLIConfiguration) async throws -> String
    func usage(id: UUID, configuration: GrokBuildCLIConfiguration) async throws -> GrokBuildSessionUsage
    func billing(configuration: GrokBuildCLIConfiguration, observedAt: Date) async throws -> GrokBuildQuotaSnapshot
    func signOut(configuration: GrokBuildCLIConfiguration) async throws
}

struct GrokBuildCLIProvider: GrokBuildCLIProviding {
    let runner: any GrokBuildProcessRunning
    init(runner: any GrokBuildProcessRunning = GrokBuildProcessRunner()) { self.runner = runner }

    func version(configuration: GrokBuildCLIConfiguration) async throws -> String {
        var request = command(configuration, arguments: ["--version"])
        request.maximumOutputBytes = 4_096
        request.timeout = 10
        let result = try await runner.run(request)
        guard result.exitCode == 0, let value = String(data: result.output, encoding: .utf8),
              let match = value.range(of: #"\b\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?\b"#, options: .regularExpression)
        else { throw GrokBuildError.unsupportedSchema }
        return String(value[match])
    }

    func usage(id: UUID, configuration: GrokBuildCLIConfiguration) async throws -> GrokBuildSessionUsage {
        let result = try await runner.run(command(configuration, arguments: ["usage", id.uuidString.lowercased()]))
        guard result.exitCode == 0 else { throw GrokBuildError.commandFailed }
        return try GrokBuildUsageParser.parse(result.output, expectedID: id)
    }

    func billing(configuration: GrokBuildCLIConfiguration, observedAt: Date = .now) async throws -> GrokBuildQuotaSnapshot {
        guard GrokBuildFeatureGate.billingStartupSafetyVerified else { throw GrokBuildError.billingStartupUnverified }
        let result = try await runner.run(Self.billingRequest(configuration: configuration))
        guard result.exitCode == 0 else { throw GrokBuildError.commandFailed }
        return try GrokBuildBillingParser.parse(result.output, observedAt: observedAt)
    }

    static func billingRequest(configuration: GrokBuildCLIConfiguration) -> GrokBuildProcessRequest {
        // No shared-leader attachment or permissions escape flags.
        .init(
            executable: configuration.executable, arguments: ["agent", "--no-leader", "stdio"],
            environment: configuration.environment(), operation: .billing,
            timeout: 45, maximumOutputBytes: 512 * 1_024
        )
    }

    func signOut(configuration: GrokBuildCLIConfiguration) async throws {
        // Explicit logout is a separate official CLI entry point. Never start
        // unsafe ACP to confirm it or present exit zero as verified signed out.
        try await verifyAuthenticationCommandVersion(configuration: configuration)
        let result = try await runner.run(command(configuration, arguments: ["logout"]))
        guard result.exitCode == 0 else { throw GrokBuildError.commandFailed }
        do {
            _ = try await billing(configuration: configuration)
            throw GrokBuildError.commandFailed
        } catch GrokBuildError.authenticationRequired {
            return
        } catch GrokBuildError.unsupportedAuthentication {
            // An API-key fallback is not a remaining consumer account session.
            return
        } catch {
            throw GrokBuildError.signOutUnverified
        }
    }

    func verifyAuthenticationCommandVersion(configuration: GrokBuildCLIConfiguration) async throws {
        // The CLI can update itself after Settings last refreshed. Do not rely
        // on the displayed/cached version when launching an account mutation.
        let installed = try await version(configuration: configuration)
        guard GrokBuildFeatureGate.authenticationCommandVersions.contains(installed) else {
            throw GrokBuildError.authenticationVersionUnverified
        }
    }

    /// For the existing user-triggered terminal UI; never run automatically.
    static func loginArguments(deviceCode: Bool) -> [String] {
        deviceCode ? ["login", "--device-auth"] : ["login"]
    }

    private func command(_ configuration: GrokBuildCLIConfiguration, arguments: [String]) -> GrokBuildProcessRequest {
        .init(executable: configuration.executable, arguments: arguments,
              environment: configuration.environment(), operation: .command)
    }
}
