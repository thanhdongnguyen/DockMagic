import Darwin
import XCTest
@testable import DockMagic

final class ProcessResourceTests: XCTestCase {
    func testInstallerLaunchFailureReturnsErrorWithoutSuspendedTimerCrash() async {
        do {
            _ = try await FoundationInstallerProcessRunner().run(
                executableURL: URL(fileURLWithPath: "/nonexistent/dockmagic-test"),
                arguments: [], environment: [:], timeout: 1
            )
            XCTFail("Expected launch failure")
        } catch {
            guard case .installerLaunchFailed = error as? DeveloperToolInstallerError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testClosedChildInputThrowsInsteadOfSendingSIGPIPE() throws {
        let pipe = try ProcessPipe()
        defer { pipe.close() }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        child.standardInput = pipe.fileHandleForReading
        try child.run()
        pipe.closeReadEnd()
        child.waitUntilExit()
        XCTAssertThrowsError(
            try pipe.fileHandleForWriting.write(contentsOf: Data("request\n".utf8))
        )
    }

    func testPipeClosesBothDescriptorsWhenReleased() throws {
        var pipe: ProcessPipe? = try ProcessPipe()
        let input = pipe!.fileHandleForReading.fileDescriptor
        let output = pipe!.fileHandleForWriting.fileDescriptor
        XCTAssertNotEqual(fcntl(input, F_GETFD) & FD_CLOEXEC, 0)
        XCTAssertNotEqual(fcntl(output, F_GETFD) & FD_CLOEXEC, 0)
        pipe = nil
        XCTAssertEqual(fcntl(input, F_GETFD), -1)
        XCTAssertEqual(fcntl(output, F_GETFD), -1)
    }

    func testCodexProviderReadsLimitsWhenChildExitsAfterResponse() async throws {
        let script = try executableScript("""
            IFS= read -r request
            printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"windowDurationMins":300,"usedPercent":37}}}}'
            """)
        defer { try? FileManager.default.removeItem(at: script) }
        let result = try await CodexAppServerRateLimitProvider(timeout: 2)
            .fetchRateLimits(executableURL: script)
        XCTAssertEqual(result.fiveHour?.usedPercent, 37)
    }

    func testCodexProviderTimesOutWithoutResponse() async throws {
        let script = try executableScript("exec /bin/sleep 10")
        defer { try? FileManager.default.removeItem(at: script) }
        let start = Date()
        do {
            _ = try await CodexAppServerRateLimitProvider(timeout: 0.15)
                .fetchRateLimits(executableURL: script)
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? CodexRateLimitProviderError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testCodexProviderCancellationStopsWaitingForChild() async throws {
        let script = try executableScript("exec /bin/sleep 10")
        defer { try? FileManager.default.removeItem(at: script) }
        let task = Task {
            try await CodexAppServerRateLimitProvider(timeout: 5)
                .fetchRateLimits(executableURL: script)
        }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testSQLiteModelUsageDrainsMoreThanOnePipeBuffer() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockMagic-SQLite-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appendingPathComponent("state.sqlite")
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        child.arguments = [database.path, """
            CREATE TABLE threads (created_at INTEGER, model TEXT, tokens_used INTEGER);
            WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<4000)
            INSERT INTO threads SELECT 1788886000, printf('model-%08d',x), x FROM n;
            """]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
        child.waitUntilExit()
        XCTAssertEqual(child.terminationStatus, 0)
        let result = CodexLocalModelUsageReader(
            sessionsRoot: root, stateDatabaseURL: database
        ).read(fetchedAt: Date(timeIntervalSince1970: 1788886000))
        XCTAssertEqual(result?.rows.count, 4000)
        XCTAssertEqual(result?.rows.first?.tokens, 4000)
    }

    private func executableScript(_ body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockMagic-Process-\(UUID()).sh")
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
}
