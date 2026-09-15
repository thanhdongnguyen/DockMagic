import Darwin
import Foundation

/// A throwing pipe constructor. Foundation's nonthrowing Pipe() can leave
/// null FileHandles when pipe(2) fails with EMFILE, which crashes on first I/O.
/// The caller closes the child's ends after Process.run(), and both ends on exit.
final class ProcessPipe {
    let fileHandleForReading: FileHandle
    let fileHandleForWriting: FileHandle

    init() throws {
        var descriptors: [Int32] = [-1, -1]
        guard Darwin.pipe(&descriptors) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        // Avoid leaking parent-owned endpoints into unrelated child processes,
        // and turn a child closing stdin into a catchable error, not SIGPIPE.
        guard fcntl(descriptors[0], F_SETFD, FD_CLOEXEC) != -1,
              fcntl(descriptors[1], F_SETFD, FD_CLOEXEC) != -1,
              fcntl(descriptors[1], F_SETNOSIGPIPE, 1) != -1 else {
            let code = errno
            Darwin.close(descriptors[0])
            Darwin.close(descriptors[1])
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        fileHandleForReading = FileHandle(
            fileDescriptor: descriptors[0], closeOnDealloc: true
        )
        fileHandleForWriting = FileHandle(
            fileDescriptor: descriptors[1], closeOnDealloc: true
        )
    }

    deinit { close() }

    func closeReadEnd() { try? fileHandleForReading.close() }
    func closeWriteEnd() { try? fileHandleForWriting.close() }

    func close() {
        closeReadEnd()
        closeWriteEnd()
    }
}
