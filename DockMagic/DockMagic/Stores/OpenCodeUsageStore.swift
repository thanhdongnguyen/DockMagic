import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class OpenCodeUsageStore {
    private(set) var state = OpenCodeUsageState()
    private(set) var candidates: [URL] = []
    private(set) var database: URL?
    private(set) var selectedPath: String?
    private(set) var backgroundEnabled: Bool
    private(set) var cliVersion: String?
    private(set) var cacheMessage: String?
    private(set) var selected = false
    private(set) var settingsVisible = false
    @ObservationIgnored private let reader: any OpenCodeHistoryReading
    @ObservationIgnored private let cache: OpenCodeHistoryCache
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let minimumRefreshInterval: TimeInterval
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var configuredTimezoneID = TimeZone.current.identifier
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var watchers: [DispatchSourceFileSystemObject] = []
    @ObservationIgnored private var notifications: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var lastRead: Date?
    @ObservationIgnored private var cacheLoaded = false
    @ObservationIgnored private var running = false
    @ObservationIgnored private var watchedSource: URL?
    @ObservationIgnored private var pendingRefresh = false

    init(reader: any OpenCodeHistoryReading = OpenCodeHistoryReader(), cache: OpenCodeHistoryCache = .init(),
         defaults: UserDefaults = .standard, minimumRefreshInterval: TimeInterval = 5) {
        self.reader = reader
        self.cache = cache
        self.defaults = defaults
        self.minimumRefreshInterval = max(0, minimumRefreshInterval)
        selectedPath = defaults.string(forKey: "DockMagicOpenCodeDatabase")
        backgroundEnabled = defaults.bool(forKey: "DockMagicOpenCodeBackground")
        discover()
    }

    func discover() {
        candidates = OpenCodeSourceDiscovery.candidates(selectedPath: selectedPath)
        let source = candidates.count == 1 ? candidates[0] : nil
        if source != database {
            generation += 1
            refreshTask?.cancel(); refreshTask = nil
            cacheLoaded = false
            lastRead = nil
            database = source
            state = OpenCodeUsageState()
            restartMonitoring()
        }
        if source == nil {
            state.observation = candidates.count > 1 ? .needsSelection : .notConfigured
        }
    }

    func chooseDatabase(_ url: URL?) {
        selectedPath = url?.standardizedFileURL.path
        defaults.set(selectedPath, forKey: "DockMagicOpenCodeDatabase")
        discover()
        refresh()
    }

    func setSelected(_ value: Bool) {
        let changed = selected != value
        selected = value
        if value && !defaults.bool(forKey: "DockMagicOpenCodeUsed") {
            defaults.set(true, forKey: "DockMagicOpenCodeUsed")
            backgroundEnabled = true
            defaults.set(true, forKey: "DockMagicOpenCodeBackground")
        }
        start()
        if changed { restartMonitoring() }
        if value && changed { refresh() }
    }

    func setSettingsVisible(_ value: Bool) {
        settingsVisible = value
        start()
        restartMonitoring()
        if value { discover(); refresh(); discoverCLI() }
    }

    func setBackgroundEnabled(_ enabled: Bool) {
        backgroundEnabled = enabled
        defaults.set(enabled, forKey: "DockMagicOpenCodeBackground")
        restartMonitoring()
        if enabled { refresh() }
        else if state.snapshot != nil { state.observation = .stale }
    }

    func start() {
        guard !running else { return }
        running = true
        for (center, name) in [(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
                               (NotificationCenter.default, NSNotification.Name.NSSystemTimeZoneDidChange),
                               (NotificationCenter.default, NSNotification.Name.NSCalendarDayChanged)] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.backgroundEnabled else { return }
                    self.refresh()
                }
            }
            notifications.append((center, token))
        }
        restartMonitoring()
        if backgroundEnabled { refresh() }
    }

    func stop() {
        running = false
        generation += 1
        refreshTask?.cancel(); refreshTask = nil
        state.isRefreshing = false
        if state.snapshot != nil { state.observation = .stale }
        stopMonitoring()
        for (center, token) in notifications { center.removeObserver(token) }
        notifications.removeAll()
    }

    func refresh() {
        if database == nil { discover() }
        guard let database else { return }
        if configuredTimezoneID != TimeZone.current.identifier {
            configuredTimezoneID = TimeZone.current.identifier
            generation += 1
            refreshTask?.cancel(); refreshTask = nil
            state = OpenCodeUsageState()
            cacheLoaded = false
            lastRead = nil
        }
        if refreshTask != nil { pendingRefresh = true; return }
        if state.snapshot?.timezoneID != TimeZone.current.identifier {
            cacheLoaded = false
            state.snapshot = nil
        }
        let delay = max(0, min(minimumRefreshInterval, minimumRefreshInterval - Date.now.timeIntervalSince(lastRead ?? .distantPast)))
        let token = generation
        let timezone = TimeZone.current
        let reader = reader
        let cache = cache
        let loadCache = !cacheLoaded
        cacheLoaded = true
        state.isRefreshing = true
        if state.snapshot == nil { state.observation = .loading }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            if loadCache {
                let cached = await Task.detached(priority: .utility) {
                    cache.load(sourceID: OpenCodeSourceDiscovery.identifier(for: database), timezoneID: timezone.identifier)
                }.value
                guard token == self.generation, !Task.isCancelled else { return }
                if let cached { self.state.snapshot = cached; self.state.observation = .stale }
            }
            do {
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                guard token == self.generation, !Task.isCancelled else { return }
                self.lastRead = .now
                let snapshot = try await reader.read(database: database, timezone: timezone, now: .now)
                guard token == self.generation, !Task.isCancelled else { return }
                self.state = OpenCodeUsageState(snapshot: snapshot, observation: .current, isRefreshing: true)
                self.lastRead = .now
                let cacheError = await Task.detached(priority: .utility) { () -> String? in
                    do { try cache.save(snapshot); return nil }
                    catch { return "Local history is available, but DockMagic could not save its cache." }
                }.value
                guard token == self.generation, !Task.isCancelled else { return }
                self.cacheMessage = cacheError
                self.installWatchers() // reopen descriptors after atomic DB/WAL replacement
            } catch {
                guard token == self.generation, !Task.isCancelled else { return }
                self.state.observation = self.state.snapshot != nil ? .stale
                    : (error as? OpenCodeReadError == .unsupportedSchema ? .unsupportedSchema : .unavailable)
                self.state.message = error.localizedDescription
                self.state.isRefreshing = false
            }
            self.state.isRefreshing = false
            self.refreshTask = nil
            if self.pendingRefresh {
                self.pendingRefresh = false
                self.scheduleRefresh()
            }
        }
    }

    func detail(day: Date, snapshot: OpenCodeUsageSnapshot) async throws -> OpenCodeDailyDetail {
        try await reader.detail(day: day, snapshot: snapshot)
    }

    func clearCache() {
        // Invalidate pending readers/writers before clearing. Await the previous task so it cannot recreate the cache.
        generation += 1
        let previous = refreshTask
        previous?.cancel(); refreshTask = nil
        state = OpenCodeUsageState(observation: .notConfigured, message: "DockMagic cache cleared. Refresh to read local history again.", isRefreshing: true)
        cacheLoaded = true
        let cache = cache
        let token = generation
        refreshTask = Task { [weak self] in
            await previous?.value
            guard let self, token == self.generation, !Task.isCancelled else { return }
            let error = await Task.detached { () -> String? in
                do { try cache.clear(); return nil } catch { return "DockMagic could not clear its cache." }
            }.value
            guard token == self.generation, !Task.isCancelled else { return }
            self.cacheMessage = error
            self.state.isRefreshing = false
            self.refreshTask = nil
        }
    }

    private func scheduleRefresh() {
        guard backgroundEnabled, running else { return }
        debounceTask?.cancel()
        let minimum: TimeInterval = selected || settingsVisible ? 5 : 300
        let delay = max(0.4, min(minimum, minimum - Date.now.timeIntervalSince(lastRead ?? .distantPast)))
        debounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            self?.refresh()
        }
    }

    private func restartMonitoring() {
        stopMonitoring()
        guard running, backgroundEnabled else { return }
        installWatchers()
        let interval = selected || settingsVisible ? 60 : 300
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(interval)) } catch { return }
                self?.discover()
                self?.refresh()
            }
        }
    }

    private func stopMonitoring() {
        pollTask?.cancel(); pollTask = nil
        debounceTask?.cancel(); debounceTask = nil
        watchers.forEach { $0.cancel() }; watchers.removeAll()
        watchedSource = nil
    }

    private func installWatchers() {
        watchers.forEach { $0.cancel() }; watchers.removeAll()
        guard running, backgroundEnabled, let database else { return }
        watchedSource = database
        for url in [database, URL(fileURLWithPath: database.path + "-wal"), database.deletingLastPathComponent()] {
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .attrib, .extend], queue: .main)
            source.setEventHandler { [weak self] in Task { @MainActor in self?.scheduleRefresh() } }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            watchers.append(source)
        }
    }

    private func discoverCLI() {
        guard cliVersion == nil else { return }
        Task { [weak self] in
            let version = await Task.detached(priority: .utility) { () -> String? in
                let home = FileManager.default.homeDirectoryForCurrentUser
                let paths = [home.appendingPathComponent(".opencode/bin/opencode").path, "/opt/homebrew/bin/opencode", "/usr/local/bin/opencode"]
                guard let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
                let process = Process(); let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: path); process.arguments = ["--version"]
                process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
                do { try process.run() } catch { return nil }
                for _ in 0..<30 where process.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
                if process.isRunning { process.terminate(); return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0, data.count < 256 else { return nil }
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.value
            self?.cliVersion = version
        }
    }
}
