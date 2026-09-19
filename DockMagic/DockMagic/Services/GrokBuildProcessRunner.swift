import Darwin
import Foundation

struct GrokBuildProcessRequest: Sendable {
    enum Operation: Equatable, Sendable { case command, billing, authentication }
    let executable: URL
    let arguments: [String]
    let environment: [String: String]
    let operation: Operation
    var timeout: TimeInterval = 30
    var maximumOutputBytes = GrokBuildUsageParser.maximumPayloadBytes
}

struct GrokBuildProcessResult: Sendable {
    let output: Data
    let exitCode: Int32
}

protocol GrokBuildProcessRunning: Sendable {
    func run(_ request: GrokBuildProcessRequest) async throws -> GrokBuildProcessResult
}

/// A deliberately narrow client: no model prompts, tool approvals, filesystem
/// callbacks, session loads or shell interpolation. Only explicit login has a
/// bounded stdout/stderr stream; background collection discards stderr.
struct GrokBuildProcessRunner: GrokBuildProcessRunning {
    func run(_ request: GrokBuildProcessRequest) async throws -> GrokBuildProcessResult {
        try await run(request, onOutput: { _ in })
    }

    /// Only explicit sign-in uses this bounded, ephemeral stream. It never
    /// becomes a command prompt and neither stream is logged or persisted.
    func run(_ request: GrokBuildProcessRequest,
             onOutput: @escaping @Sendable (Data) -> Void) async throws -> GrokBuildProcessResult {
        let cancellation = GrokBuildCancellation()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                try Self.execute(request, cancellation: cancellation, onOutput: onOutput)
            }.value
        } onCancel: { cancellation.cancel() }
    }

    private static func execute(_ request: GrokBuildProcessRequest, cancellation: GrokBuildCancellation,
                                onOutput: @escaping @Sendable (Data) -> Void) throws -> GrokBuildProcessResult {
        guard !cancellation.isCancelled else { throw CancellationError() }
        guard request.timeout > 0, request.timeout.isFinite, request.maximumOutputBytes > 0 else {
            throw GrokBuildError.invalidResponse
        }
        let input = try ProcessPipe()
        let output = try ProcessPipe()
        defer { input.close(); output.close() }
        let process = try GrokBuildOwnedProcess(request: request,
            input: input.fileHandleForReading.fileDescriptor, output: output.fileHandleForWriting.fileDescriptor)
        input.closeReadEnd()
        output.closeWriteEnd()
        defer { process.stop() }

        let deadline = ProcessInfo.processInfo.systemUptime + request.timeout
        let inputDescriptor = input.fileHandleForWriting.fileDescriptor
        let flags = fcntl(inputDescriptor, F_GETFL)
        guard flags >= 0, fcntl(inputDescriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            throw GrokBuildError.commandFailed
        }
        var billing = GrokBuildBillingConversation()
        if request.operation == .billing {
            try write(billing.initializeRequest, to: inputDescriptor, deadline: deadline, cancellation: cancellation)
        } else { input.closeWriteEnd() }

        var received = Data()
        var pending = Data()
        var totalBytes = 0
        var chunk = [UInt8](repeating: 0, count: 16_384)
        var eof = false
        while !eof {
            if cancellation.isCancelled { throw CancellationError() }
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw GrokBuildError.timedOut }
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor,
                                    events: Int16(POLLIN | POLLHUP | POLLERR), revents: 0)
            let ready = poll(&descriptor, 1, 50)
            if ready < 0 {
                if errno == EINTR { continue }
                throw GrokBuildError.commandFailed
            }
            guard ready > 0 else { continue }
            let count = Darwin.read(descriptor.fd, &chunk, chunk.count)
            if count == 0 { eof = true; continue }
            if count < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                throw GrokBuildError.commandFailed
            }
            totalBytes += count
            guard totalBytes <= request.maximumOutputBytes else { throw GrokBuildError.outputTooLarge }
            let bytes = Data(chunk.prefix(count))
            if request.operation == .authentication { onOutput(bytes); continue }
            if request.operation == .command { received.append(bytes); continue }
            pending.append(bytes)
            while let newline = pending.firstIndex(of: 10) {
                let line = Data(pending[..<newline])
                pending.removeSubrange(...newline)
                guard !line.isEmpty else { continue }
                let action = try billing.receive(line)
                switch action {
                case let .write(data):
                    try write(data, to: inputDescriptor, deadline: deadline, cancellation: cancellation)
                case let .finished(data):
                    input.closeWriteEnd()
                    return .init(output: data, exitCode: 0)
                case .ignore: break
                }
            }
        }
        // A process can close stdout and remain alive; wait under the same
        // deadline instead of an unbounded waitUntilExit().
        while try process.exitCode() == nil {
            if cancellation.isCancelled { throw CancellationError() }
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw GrokBuildError.timedOut }
            usleep(10_000)
        }
        guard request.operation != .billing else { throw GrokBuildError.protocolError }
        guard let exitCode = try process.exitCode() else { throw GrokBuildError.commandFailed }
        return .init(output: received, exitCode: exitCode)
    }

    /// A peer that emits reverse requests but stops reading stdin must not
    /// block cancellation/timeout while the client sends denials.
    private static func write(_ data: Data, to descriptor: Int32, deadline: TimeInterval,
                              cancellation: GrokBuildCancellation) throws {
        try data.withUnsafeBytes { bytes in
            guard let start = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                if cancellation.isCancelled { throw CancellationError() }
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw GrokBuildError.timedOut }
                var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                let ready = poll(&pollDescriptor, 1, 50)
                if ready < 0 {
                    if errno == EINTR { continue }
                    throw GrokBuildError.commandFailed
                }
                guard ready > 0 else { continue }
                let count = Darwin.write(descriptor, start.advanced(by: offset), bytes.count - offset)
                if count < 0 {
                    if errno == EINTR || errno == EAGAIN { continue }
                    throw GrokBuildError.protocolError
                }
                guard count > 0 else { throw GrokBuildError.protocolError }
                offset += count
            }
        }
    }

}

/// Spawn into a dedicated process group *before* exec, not a racing setpgid()
/// after Foundation.Process.run(). No shell, leader attachment or global pkill.
/// The root is left waitable until group teardown, reserving its PID/PGID so a
/// completed short-lived command cannot make cleanup target a reused PID.
private final class GrokBuildOwnedProcess {
    private let pid: pid_t

    init(request: GrokBuildProcessRequest, input: Int32, output: Int32) throws {
        guard request.executable.isFileURL, request.executable.path.hasPrefix("/"),
              !request.executable.path.utf8.contains(0),
              request.arguments.allSatisfy({ !$0.utf8.contains(0) }),
              request.environment.allSatisfy({ !$0.key.contains("=") && !$0.key.utf8.contains(0) && !$0.value.utf8.contains(0) })
        else { throw GrokBuildError.invalidResponse }
        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw GrokBuildError.commandFailed }
        defer { posix_spawn_file_actions_destroy(&actions) }
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else { throw GrokBuildError.commandFailed }
        defer { posix_spawnattr_destroy(&attributes) }
        var emptySignals = sigset_t()
        sigemptyset(&emptySignals)
        var defaultSignals = sigset_t()
        sigfillset(&defaultSignals)
        let flags = Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)
        guard posix_spawnattr_setflags(&attributes, flags) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0,
              posix_spawnattr_setsigmask(&attributes, &emptySignals) == 0,
              posix_spawnattr_setsigdefault(&attributes, &defaultSignals) == 0,
              posix_spawn_file_actions_adddup2(&actions, input, STDIN_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, output, STDOUT_FILENO) == 0,
              // Do not initialize an agent in a user's repository implicitly.
              posix_spawn_file_actions_addchdir_np(&actions, "/") == 0 else { throw GrokBuildError.commandFailed }
        let stderrResult = request.operation == .authentication
            ? posix_spawn_file_actions_adddup2(&actions, output, STDERR_FILENO)
            : posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)
        guard stderrResult == 0 else { throw GrokBuildError.commandFailed }
        let strings = [request.executable.path] + request.arguments
        let variables = request.environment.map { "\($0.key)=\($0.value)" }
        var arguments = strings.map { strdup($0) } + [nil]
        var environment = variables.map { strdup($0) } + [nil]
        defer { arguments.forEach { free($0) }; environment.forEach { free($0) } }
        guard arguments.dropLast().allSatisfy({ $0 != nil }), environment.dropLast().allSatisfy({ $0 != nil }) else {
            throw GrokBuildError.commandFailed
        }
        var child: pid_t = 0
        let result = posix_spawn(&child, request.executable.path, &actions, &attributes, &arguments, &environment)
        guard result == 0, child > 0 else { throw GrokBuildError.executableMissing }
        pid = child
    }

    func exitCode() throws -> Int32? {
        var info = siginfo_t()
        var result: Int32
        repeat { result = waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT) } while result < 0 && errno == EINTR
        guard result == 0 else { throw GrokBuildError.commandFailed }
        guard info.si_pid == pid else { return nil }
        return info.si_code == CLD_EXITED ? info.si_status : 128 + info.si_status
    }

    func stop() {
        // Descendants normally inherit this group. Detached/daemonized children
        // still require the separate real-CLI startup/cleanup audit.
        Darwin.kill(-pid, SIGTERM)
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        while ProcessInfo.processInfo.systemUptime < deadline {
            if (try? exitCode()) != nil, !GrokBuildProcessGroupInspection.containsOtherMembers(of: pid) { break }
            usleep(10_000)
        }
        Darwin.kill(-pid, SIGKILL)
        let reapDeadline = ProcessInfo.processInfo.systemUptime + 1
        var status: Int32 = 0
        while ProcessInfo.processInfo.systemUptime < reapDeadline {
            let result = waitpid(pid, &status, WNOHANG)
            if result == pid || (result < 0 && errno == ECHILD) { return }
            usleep(10_000)
        }
        // A kernel-blocked child must not hold the acquisition task forever.
        // Reap only this still-owned PID when the kernel releases it.
        let ownedPID = pid
        DispatchQueue.global(qos: .utility).async {
            var status: Int32 = 0
            while waitpid(ownedPID, &status, 0) < 0 && errno == EINTR { }
        }
    }

}

/// Metadata-only inspection. Kept separate so the PID-count invariant can be
/// tested without depending on a shell signal handler's scheduling latency.
enum GrokBuildProcessGroupInspection {
    static func containsOtherMembers(of pid: pid_t) -> Bool {
        var members = [pid_t](repeating: 0, count: 256)
        let size = Int32(members.count * MemoryLayout<pid_t>.stride)
        let count = proc_listpgrppids(pid, &members, size)
        // A failed or truncated query is not evidence that the group is empty.
        // Unlike proc_listpids, this wrapper returns a PID count, not bytes.
        // Dividing again would hide small groups and cut their grace period.
        guard count > 0, count < members.count else { return true }
        return members.prefix(Int(count)).contains { $0 > 0 && $0 != pid }
    }
}

private final class GrokBuildCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }; return cancelled
    }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

struct GrokBuildBillingConversation {
    enum Action { case write(Data), finished(Data), ignore }
    private var initialized = false

    var initializeRequest: Data {
        // Fixed, non-sensitive JSON. ACP uses newline-delimited JSON-RPC.
        Data((#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{},"clientInfo":{"name":"DockMagic","version":"research"}}}"# + "\n").utf8)
    }

    mutating func receive(_ line: Data) throws -> Action {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["jsonrpc"] as? String == "2.0" else { throw GrokBuildError.protocolError }
        if object["method"] != nil {
            // The client advertises no reverse capabilities and never approves
            // an agent request. Notifications need no response.
            guard let id = object["id"] else { return .ignore }
            let reply: [String: Any] = ["jsonrpc": "2.0", "id": id,
                                       "error": ["code": -32601, "message": "Method not supported"]]
            var data = try JSONSerialization.data(withJSONObject: reply)
            data.append(10)
            return .write(data)
        }
        guard let id = object["id"] as? Int, id == (initialized ? 2 : 1) else {
            throw GrokBuildError.protocolError
        }
        if let error = object["error"] as? [String: Any] {
            if error["code"] as? Int == -32601 { throw GrokBuildError.unsupportedSchema }
            // Only the explicit first-party auth-gate diagnostics qualify as
            // signed-out/unsupported auth. Network/schema/HTTP errors do not.
            let detail = error["data"] as? String ?? ""
            if detail == "Authentication required to fetch billing data" {
                throw GrokBuildError.authenticationRequired
            }
            if detail == "Billing data requires auth with grok.com. Run `grok login` to authenticate." {
                throw GrokBuildError.unsupportedAuthentication
            }
            throw GrokBuildError.billingUnavailable
        }
        guard let result = object["result"] as? [String: Any] else { throw GrokBuildError.protocolError }
        if !initialized {
            guard result["protocolVersion"] as? Int == 1 else { throw GrokBuildError.unsupportedSchema }
            initialized = true
            return .write(Data((#"{"jsonrpc":"2.0","id":2,"method":"_x.ai/billing","params":{}}"# + "\n").utf8))
        }
        return .finished(try JSONSerialization.data(withJSONObject: result))
    }
}
