import Darwin
import Foundation
import XCTest
@testable import DockMagic

private final class GrokAuthenticationOutputSink: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    var bytes: Data { lock.lock(); defer { lock.unlock() }; return data }
    func append(_ bytes: Data) { lock.lock(); data.append(bytes); lock.unlock() }
}

/// Real OS processes, entirely synthetic commands. No Grok execution or auth.
final class GrokBuildProcessLifecycleTests: XCTestCase {
    func testAuthenticationStreamIncludesStderrAndDoesNotRetainOutput() async throws {
        let fixture = try script("printf 'browser instructions\\n'; printf 'device instructions\\n' >&2; exit 0")
        defer { fixture.remove() }
        let request = GrokBuildProcessRequest(executable: fixture.executable, arguments: [],
            environment: [:], operation: .authentication, timeout: 3, maximumOutputBytes: 1024)
        let output = GrokAuthenticationOutputSink()
        let result = try await GrokBuildProcessRunner().run(request) { output.append($0) }
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.isEmpty)
        XCTAssertTrue(String(decoding: output.bytes, as: UTF8.self).contains("browser instructions"))
        XCTAssertTrue(String(decoding: output.bytes, as: UTF8.self).contains("device instructions"))
    }

    func testAuthenticationOutputOverflowStopsRootAndChild() async throws {
        let fixture = try script("""
            /bin/sleep 20 &
            printf '%s %s' "$$" "$!" > "$1"
            /usr/bin/yes 'synthetic output' >&2
            """)
        defer { fixture.remove() }
        let request = GrokBuildProcessRequest(executable: fixture.executable, arguments: [fixture.pidFile.path],
            environment: [:], operation: .authentication, timeout: 5, maximumOutputBytes: 1024)
        do { _ = try await GrokBuildProcessRunner().run(request); XCTFail("Expected output cap") }
        catch { XCTAssertEqual(error as? GrokBuildError, .outputTooLarge) }
        try await assertNoRunningProcesses(fixture)
    }
    func testTimeoutStopsOwnedRootAndChildWithoutStoppingUnrelatedProcess() async throws {
        let unrelated = Process()
        unrelated.executableURL = URL(fileURLWithPath: "/bin/sleep")
        unrelated.arguments = ["20"]
        try unrelated.run()
        defer { unrelated.terminate(); unrelated.waitUntilExit() }
        let fixture = try script("""
            /bin/sleep 20 &
            printf '%s %s' "$$" "$!" > "$1"
            wait
            """)
        defer { fixture.remove() }
        var request = fixture.request
        // App-hosted parallel XCTest startup can exceed 300 ms before the
        // fixture shell reaches its first statement. Give it time to create
        // both processes; the foundation test covers short deadlines.
        request.timeout = 2
        do { _ = try await GrokBuildProcessRunner().run(request); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? GrokBuildError, .timedOut) }
        try await assertNoRunningProcesses(fixture)
        XCTAssertTrue(unrelated.isRunning)
    }

    func testCancellationStopsChildThatIgnoresTermination() async throws {
        let fixture = try script("""
            (trap '' TERM; exec /bin/sleep 20) &
            printf '%s %s' "$$" "$!" > "$1"
            wait
            """)
        defer { fixture.remove() }
        // Cancellation is measured after the fixture has created its child,
        // not while parallel app-test hosts are still starting up.
        var request = fixture.request
        request.timeout = 10
        let task = Task { [request] in try await GrokBuildProcessRunner().run(request) }
        do { try await waitForPIDFile(fixture) }
        catch {
            task.cancel()
            _ = try? await task.value
            throw error
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await assertNoRunningProcesses(fixture)
    }

    func testNormalCommandExitStillCleansBackgroundChild() async throws {
        let fixture = try script("""
            /bin/sleep 20 > /dev/null 2>&1 &
            printf '%s %s' "$$" "$!" > "$1"
            exit 7
            """)
        defer { fixture.remove() }
        let result = try await GrokBuildProcessRunner().run(fixture.request)
        XCTAssertEqual(result.exitCode, 7)
        try await assertNoRunningProcesses(fixture)
    }

    func testSmallProcessGroupInspectionIncludesTheChild() async throws {
        let fixture = try script("""
            /bin/sleep 20 &
            printf '%s %s' "$$" "$!" > "$1"
            wait
            """)
        defer { fixture.remove() }
        var request = fixture.request
        request.timeout = 10
        let task = Task { [request] in try await GrokBuildProcessRunner().run(request) }
        do {
            try await waitForPIDFile(fixture)
            let text = try String(contentsOf: fixture.pidFile)
            let root = try XCTUnwrap(text.split(separator: " ").first.flatMap { Int32($0) })
            XCTAssertTrue(GrokBuildProcessGroupInspection.containsOtherMembers(of: root),
                          "A group of two PIDs must not be divided by sizeof(pid_t) again")
        } catch {
            task.cancel()
            _ = try? await task.value
            throw error
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await assertNoRunningProcesses(fixture)
    }

    func testSuccessfulACPReplyCleansItsBackgroundChild() async throws {
        let fixture = try script("""
            /bin/sleep 20 &
            printf '%s %s' "$$" "$!" > "$1"
            IFS= read -r initialize
            printf '%s\\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}'
            IFS= read -r billing
            printf '%s\\n' '{"jsonrpc":"2.0","id":2,"result":{"config":{"creditUsagePercent":25}}}'
            wait
            """)
        defer { fixture.remove() }
        let request = GrokBuildProcessRequest(executable: fixture.executable, arguments: [fixture.pidFile.path],
            environment: [:], operation: .billing, timeout: 3)
        let result = try await GrokBuildProcessRunner().run(request)
        XCTAssertEqual(try GrokBuildBillingParser.parse(result.output, observedAt: .now).usedPercent, 25)
        try await assertNoRunningProcesses(fixture)
    }

    func testCommandReceivesLiteralArgumentsSelectedEnvironmentAndNeutralCWD() async throws {
        let fixture = try script("""
            printf '%s\\n' "$PWD" "$GROK_HOME" "$2"
            """)
        defer { fixture.remove() }
        let literal = "space ; $(must-not-execute) `also-not-execute`"
        let request = GrokBuildProcessRequest(executable: fixture.executable, arguments: [fixture.pidFile.path, literal],
            environment: ["GROK_HOME": "/synthetic selected home"], operation: .command)
        let result = try await GrokBuildProcessRunner().run(request)
        XCTAssertEqual(String(decoding: result.output, as: UTF8.self), "/\n/synthetic selected home\n\(literal)\n")
    }

    func testInvalidExecutableAndEmbeddedNULFailWithoutLaunching() async {
        let missing = GrokBuildProcessRequest(executable: URL(fileURLWithPath: "/nonexistent-grok-test"),
            arguments: [], environment: [:], operation: .command)
        do { _ = try await GrokBuildProcessRunner().run(missing); XCTFail("Expected launch failure") }
        catch { XCTAssertEqual(error as? GrokBuildError, .executableMissing) }
        let invalid = GrokBuildProcessRequest(executable: URL(fileURLWithPath: "/usr/bin/true"),
            arguments: ["bad\0argument"], environment: [:], operation: .command)
        do { _ = try await GrokBuildProcessRunner().run(invalid); XCTFail("Expected input rejection") }
        catch { XCTAssertEqual(error as? GrokBuildError, .invalidResponse) }
    }

    private struct Fixture {
        let directory: URL
        var executable: URL { directory.appendingPathComponent("fixture.sh") }
        var pidFile: URL { directory.appendingPathComponent("owned-pids") }
        var request: GrokBuildProcessRequest {
            .init(executable: executable, arguments: [pidFile.path], environment: [:], operation: .command, timeout: 3)
        }
        func remove() { try? FileManager.default.removeItem(at: directory) }
    }

    private func script(_ contents: String) throws -> Fixture {
        let fixture = Fixture(directory: FileManager.default.temporaryDirectory.appendingPathComponent("grok-process-test-\(UUID())"))
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data(("#!/bin/sh\n" + contents + "\n").utf8).write(to: fixture.executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.executable.path)
        return fixture
    }

    private func waitForPIDFile(_ fixture: Fixture) async throws {
        for _ in 0..<500 {
            if let text = try? String(contentsOf: fixture.pidFile), text.split(separator: " ").count == 2 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw NSError(domain: "GrokBuildProcessFixture", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Synthetic process failed to report its child within five seconds"])
    }

    private func assertNoRunningProcesses(_ fixture: Fixture) async throws {
        let text = try String(contentsOf: fixture.pidFile)
        let pids = text.split(separator: " ").compactMap { Int32($0) }
        XCTAssertEqual(pids.count, 2)
        for _ in 0..<100 {
            if pids.allSatisfy({ !isRunning($0) }) { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        // These identities come only from this test's freshly spawned fixture.
        // Best-effort cleanup prevents a failed assertion leaving test children.
        for pid in pids where isRunning(pid) { Darwin.kill(pid, SIGKILL) }
        XCTFail("An owned fixture process survived group teardown")
    }

    private func isRunning(_ pid: pid_t) -> Bool {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return false }
        return info.pbi_status != SZOMB
    }
}
