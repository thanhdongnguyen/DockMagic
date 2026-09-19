import Foundation

/// A transaction over one Grok home. Metadata is re-scanned after CLI reads,
/// before any revision is committed. An interrupted transaction never replaces
/// the caller's last good cache. UUID/path values remain ephemeral.
struct GrokBuildLocalUsageProvider: GrokBuildLocalCollecting {
    let cli: any GrokBuildCLIProviding
    let discovery: any GrokBuildSessionDiscovering
    let maximumCommandsPerScan: Int
    let maximumScanDuration: TimeInterval

    init(cli: any GrokBuildCLIProviding = GrokBuildCLIProvider(),
         discovery: any GrokBuildSessionDiscovering = GrokBuildSessionDiscovery(),
         maximumCommandsPerScan: Int = 100, maximumScanDuration: TimeInterval = 60) {
        self.cli = cli
        self.discovery = discovery
        self.maximumCommandsPerScan = max(1, maximumCommandsPerScan)
        self.maximumScanDuration = max(1, maximumScanDuration)
    }

    func collect(configuration: GrokBuildCLIConfiguration, cache input: GrokBuildHistoryCache,
                 now: Date, calendar: Calendar, force: Bool = false) async throws -> GrokBuildLocalCollection {
        guard input.ledger.namespace == GrokBuildHistoryLedger(home: configuration.home).namespace else {
            throw GrokBuildError.invalidHome
        }
        var cache = input
        var activity = cache.activity ?? .importing(cache.ledger, at: now, calendar: calendar)
        activity.beginObservation(at: now, calendar: calendar)
        let scan = try discovery.scan(home: configuration.home)
        let roots = scan.sources.filter { $0.lineage.isUnambiguousRoot }
        var coverage = GrokBuildHistoryCoverage()
        coverage.excludedSessions = scan.excludedCount + scan.sources.count - roots.count
        coverage.scanWasLimited = scan.limited
        var pending: [(source: GrokBuildSessionSource, usage: GrokBuildSessionUsage)] = []
        var unavailableKeys = Set<String>()
        var quarantinedKeys = Set<String>()
        var unchanged: [GrokBuildSessionSource] = []
        var commands = 0
        let started = ProcessInfo.processInfo.systemUptime
        for source in roots {
            try Task.checkCancellation()
            let key = cache.ledger.sessionKey(source.id)
            if !force, let retry = cache.retries[key], retry.fingerprint == source.fingerprint,
               now < retry.retryAfter {
                if retry.quarantined { quarantinedKeys.insert(key) }
                else { unavailableKeys.insert(key) }
                continue
            }
            // Earlier experimental caches could accept a turn ahead of their
            // observedAt while omitting its activity witness. Re-read that
            // source once through the current eligibility checks even if its
            // file fingerprint is unchanged. Never manufacture activity from
            // the inconsistent cache, or bypass its retry backoff.
            let needsTimestampRevalidation = cache.ledger.sessions[key].map { record in
                record.turns.contains { $0.recordedAt > record.observedAt }
            } ?? false
            if !force, !needsTimestampRevalidation, cache.retries[key] == nil, cache.fingerprints[key] == source.fingerprint {
                unchanged.append(source)
                continue
            }
            guard commands < maximumCommandsPerScan,
                  ProcessInfo.processInfo.systemUptime - started < maximumScanDuration else {
                coverage.scanWasLimited = true
                unavailableKeys.insert(key)
                continue
            }
            commands += 1
            do {
                let usage = try await cli.usage(id: source.id, configuration: configuration)
                try Task.checkCancellation()
                guard try discovery.fingerprint(directory: source.directory) == source.fingerprint else {
                    throw GrokBuildError.sourceChanged
                }
                pending.append((source, usage))
            } catch is CancellationError { throw CancellationError() }
            catch {
                unavailableKeys.insert(key)
                recordFailure(key: key, fingerprint: source.fingerprint, now: now, cache: &cache)
            }
        }
        try Task.checkCancellation()
        let finalScan = try discovery.scan(home: configuration.home)
        coverage.scanWasLimited = coverage.scanWasLimited || finalScan.limited
        let finalSources = Dictionary(uniqueKeysWithValues: finalScan.sources.map { ($0.id, $0) })
        coverage.excludedSessions = max(coverage.excludedSessions,
            finalScan.excludedCount + finalScan.sources.filter { !$0.lineage.isUnambiguousRoot }.count)
        for source in unchanged where finalSources[source.id] != source {
            unavailableKeys.insert(cache.ledger.sessionKey(source.id))
        }
        for (source, usage) in pending {
            try Task.checkCancellation()
            let key = cache.ledger.sessionKey(source.id)
            guard finalSources[source.id] == source else {
                unavailableKeys.insert(key)
                recordFailure(key: key, fingerprint: source.fingerprint, now: now, cache: &cache)
                continue
            }
            switch cache.ledger.ingest(usage, lineage: source.lineage, observedAt: now, calendar: calendar) {
            case .accepted:
                activity.recordAccepted(usage, lineage: source.lineage, at: now, calendar: calendar)
                cache.fingerprints[key] = source.fingerprint
                cache.retries.removeValue(forKey: key)
            case .excludedLineage: coverage.excludedSessions += 1
            case .quarantined:
                quarantinedKeys.insert(key)
                recordFailure(key: key, fingerprint: source.fingerprint, now: now, cache: &cache, quarantined: true)
            }
        }
        let retainedKeys = Set(finalScan.sources.map { cache.ledger.sessionKey($0.id) })
        if !finalScan.limited {
            unavailableKeys.formUnion(Set(cache.ledger.sessions.keys).subtracting(retainedKeys))
            cache.fingerprints = cache.fingerprints.filter { retainedKeys.contains($0.key) }
            cache.retries = cache.retries.filter { retainedKeys.contains($0.key) }
        }
        cache.ledger.prune(now: now, calendar: calendar)
        activity.finishObservation(at: now, calendar: calendar)
        cache.activity = activity
        coverage.unavailableSources = unavailableKeys.count
        coverage.quarantinedSessions = quarantinedKeys.count
        cache.coverage = coverage
        cache.collectedAt = now
        cache.calendarIdentifier = calendar.timeZone.identifier
        let readableRoots = finalScan.sources.filter {
            $0.lineage.isUnambiguousRoot && cache.fingerprints[cache.ledger.sessionKey($0.id)] == $0.fingerprint
                && cache.retries[cache.ledger.sessionKey($0.id)] == nil
        }.count
        return .init(cache: cache, snapshot: cache.ledger.snapshot(now: now, calendar: calendar, coverage: coverage),
                     readableRootCount: readableRoots)
    }

    private func recordFailure(key: String, fingerprint: String, now: Date, cache: inout GrokBuildHistoryCache, quarantined: Bool = false) {
        let old = cache.retries[key]
        let attempts = old?.fingerprint == fingerprint ? min(10, (old?.attempts ?? 0) + 1) : 1
        let delay = min(300, 15 * pow(2, Double(attempts - 1)))
        cache.retries[key] = .init(fingerprint: fingerprint, attempts: attempts, retryAfter: now.addingTimeInterval(delay), quarantined: quarantined)
    }
}
