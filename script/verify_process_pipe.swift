// Compile alongside Services/ProcessPipe.swift and run as a separate process.
// RLIMIT_NOFILE is lowered only here, never in DockMagic or the XCTest host.
import Darwin
import Foundation

@main struct ProcessPipeResourceProbe {
    static func main() throws {
        // Warm up Foundation before deliberately exhausting descriptors.
        let warmup = try ProcessPipe()
        warmup.close()
        var limit = rlimit()
        precondition(getrlimit(RLIMIT_NOFILE, &limit) == 0)
        limit.rlim_cur = min(limit.rlim_cur, 64)
        precondition(setrlimit(RLIMIT_NOFILE, &limit) == 0)
        var descriptors: [Int32] = []
        while true {
            let fd = open("/dev/null", O_RDONLY | O_CLOEXEC)
            if fd == -1 { break }
            descriptors.append(fd)
        }
        precondition(errno == EMFILE)
        var caughtExhaustion = false
        do {
            _ = try ProcessPipe()
        } catch let error as POSIXError {
            caughtExhaustion = error.code == .EMFILE
        }
        descriptors.forEach { _ = Darwin.close($0) }
        precondition(caughtExhaustion, "Descriptor exhaustion must throw EMFILE")

        // Verify recovery and repeated cleanup without increasing the limit.
        for _ in 0..<1000 {
            let pipe = try ProcessPipe()
            try pipe.fileHandleForWriting.write(contentsOf: Data("ok".utf8))
            pipe.closeWriteEnd()
            let data = try pipe.fileHandleForReading.readToEnd()
            precondition(data == Data("ok".utf8))
            pipe.close()
        }
        print("PASS: EMFILE returned safely; 1,000 pipe lifecycles completed under a 64-FD limit.")
    }
}
