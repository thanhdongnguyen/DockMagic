import CoreServices
import Foundation

protocol GrokBuildFileMonitoring: AnyObject, Sendable {
    func start(home: URL, onChange: @escaping @Sendable () -> Void) -> Bool
    func stop()
}

/// Grok writes nested per-session directories, so a non-recursive vnode watch
/// of the home alone is insufficient. Paths/event payloads are never retained.
final class GrokBuildFileEventMonitor: GrokBuildFileMonitoring, @unchecked Sendable {
    private final class Callback: @unchecked Sendable {
        let action: @Sendable () -> Void
        init(_ action: @escaping @Sendable () -> Void) { self.action = action }
    }
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.hypevibe.DockMagic.grok-events", qos: .utility)
    private var stream: FSEventStreamRef?

    deinit { stop() }

    func start(home: URL, onChange: @escaping @Sendable () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard stream == nil else { return true }
        guard (try? home.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
        let callback = Callback(onChange)
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(callback).toOpaque(),
            retain: { pointer in
                guard let pointer else { return nil }
                _ = Unmanaged<Callback>.fromOpaque(pointer).retain()
                return pointer
            }, release: { pointer in
                guard let pointer else { return }
                Unmanaged<Callback>.fromOpaque(pointer).release()
            }, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        guard let created = FSEventStreamCreate(kCFAllocatorDefault, { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<Callback>.fromOpaque(info).takeUnretainedValue().action()
        }, &context, [home.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags) else {
            return false
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            return false
        }
        stream = created
        return true
    }

    func stop() {
        lock.lock()
        let old = stream
        stream = nil
        lock.unlock()
        if let old {
            FSEventStreamStop(old)
            FSEventStreamInvalidate(old)
            FSEventStreamRelease(old)
        }
    }
}
