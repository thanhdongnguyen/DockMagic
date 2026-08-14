import Foundation
import Observation

enum GitHubPollingDefaults {
    static let interval: TimeInterval = 15 * 60
    static let retainedSampleCount = 7 * 24 * 4
}

struct GitHubRepositoryCacheEntry: Codable, Equatable, Sendable {
    let repository: String
    let history: [GitHubRepositorySnapshot]
    let etag: String?
}

protocol GitHubRepositoryHistoryCaching: Sendable {
    func load() -> GitHubRepositoryCacheEntry?
    func save(_ entry: GitHubRepositoryCacheEntry)
    func remove()
}

struct UserDefaultsGitHubRepositoryHistoryCache:
    GitHubRepositoryHistoryCaching,
    @unchecked Sendable
{
    static let cacheKey = "DockMagicGitHubRepositoryHistoryV1"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> GitHubRepositoryCacheEntry? {
        guard let data = defaults.data(forKey: Self.cacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(
            GitHubRepositoryCacheEntry.self,
            from: data
        )
    }

    func save(_ entry: GitHubRepositoryCacheEntry) {
        guard let data = try? JSONEncoder().encode(entry) else {
            return
        }
        defaults.set(data, forKey: Self.cacheKey)
    }

    func remove() {
        defaults.removeObject(forKey: Self.cacheKey)
    }
}

final class InMemoryGitHubRepositoryHistoryCache:
    GitHubRepositoryHistoryCaching,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var entry: GitHubRepositoryCacheEntry?

    init(entry: GitHubRepositoryCacheEntry? = nil) {
        self.entry = entry
    }

    func load() -> GitHubRepositoryCacheEntry? {
        lock.withLock { entry }
    }

    func save(_ entry: GitHubRepositoryCacheEntry) {
        lock.withLock { self.entry = entry }
    }

    func remove() {
        lock.withLock { entry = nil }
    }
}

@MainActor
@Observable
final class GitHubRepositoryStore {
    static let defaultPollingInterval = GitHubPollingDefaults.interval
    static let retainedSampleCount = GitHubPollingDefaults.retainedSampleCount

    private(set) var reference: GitHubRepositoryReference?
    private(set) var history: [GitHubRepositorySnapshot] = []
    private(set) var isMonitoring = false
    private(set) var isRefreshing = false
    private(set) var lastErrorDescription: String?
    private(set) var lastSuccessfulRefreshAt: Date?
    private(set) var nextRefreshAt: Date?
    private(set) var rateLimit: GitHubRateLimit?
    private(set) var hasAccessToken = false
    private(set) var credentialErrorDescription: String?

    @ObservationIgnored
    private let api: any GitHubRepositoryAPIProviding

    @ObservationIgnored
    private let vault: any GitHubCredentialVault

    @ObservationIgnored
    private let cache: any GitHubRepositoryHistoryCaching

    @ObservationIgnored
    private let pollingInterval: TimeInterval

    @ObservationIgnored
    private let now: @Sendable () -> Date

    @ObservationIgnored
    private var etag: String?

    @ObservationIgnored
    private var retryNotBefore: Date?

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRefreshID: UUID?

    init(
        api: any GitHubRepositoryAPIProviding = GitHubRepositoryAPIClient(),
        vault: any GitHubCredentialVault = KeychainGitHubCredentialVault(),
        cache: any GitHubRepositoryHistoryCaching =
            UserDefaultsGitHubRepositoryHistoryCache(),
        pollingInterval: TimeInterval = GitHubPollingDefaults.interval,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(pollingInterval > 0, "Polling interval must be positive.")
        self.api = api
        self.vault = vault
        self.cache = cache
        self.pollingInterval = pollingInterval
        self.now = now
        do {
            hasAccessToken = try vault.loadAccessToken() != nil
        } catch {
            credentialErrorDescription = error.localizedDescription
        }
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
    }

    func configure(repositoryURL: String) {
        let trimmed = repositoryURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let newReference = GitHubRepositoryReference(urlString: trimmed)
        guard newReference != reference else {
            if newReference == nil {
                lastErrorDescription = trimmed.isEmpty
                    ? nil
                    : "Enter a valid GitHub repository URL."
            }
            return
        }

        let shouldResumeMonitoring = isMonitoring
        pause()
        cancelRefresh()
        reference = newReference
        history = []
        etag = nil
        rateLimit = nil
        retryNotBefore = nil
        nextRefreshAt = nil
        lastSuccessfulRefreshAt = nil

        if let newReference {
            restoreCache(for: newReference)
            lastErrorDescription = nil
        } else if trimmed.isEmpty {
            lastErrorDescription = nil
            cache.remove()
        } else {
            lastErrorDescription = "Enter a valid GitHub repository URL."
        }

        if shouldResumeMonitoring, newReference != nil {
            start()
        }
    }

    func start() {
        guard pollingTask == nil else {
            return
        }
        guard reference != nil else {
            if lastErrorDescription == nil {
                lastErrorDescription = "Add a GitHub repository in Settings."
            }
            return
        }

        let runID = UUID()
        activeRunID = runID
        isMonitoring = true
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.activeRunID == runID else {
                    break
                }

                await self.refresh()
                guard !Task.isCancelled, self.activeRunID == runID else {
                    break
                }

                let delay = self.nextPollingDelay()
                self.nextRefreshAt = self.now().addingTimeInterval(delay)
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }

            guard let self, self.activeRunID == runID else {
                return
            }
            self.activeRunID = nil
            self.pollingTask = nil
            self.isMonitoring = false
            self.nextRefreshAt = nil
        }
    }

    /// Pauses the 15-minute timer without cancelling a manual refresh that
    /// was initiated from Settings.
    func pause() {
        activeRunID = nil
        pollingTask?.cancel()
        pollingTask = nil
        isMonitoring = false
        nextRefreshAt = nil
    }

    func stop() {
        pause()
        cancelRefresh()
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        guard let reference else {
            if lastErrorDescription == nil {
                lastErrorDescription = "Add a GitHub repository in Settings."
            }
            return
        }

        let refreshID = UUID()
        activeRefreshID = refreshID
        isRefreshing = true
        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.performRefresh(reference: reference, id: refreshID)
        }
        refreshTask = task
        await task.value
    }

    func saveAccessToken(_ token: String) throws {
        try vault.storeAccessToken(token)
        hasAccessToken = true
        credentialErrorDescription = nil
        etag = nil
        persistCache()
    }

    func removeAccessToken() throws {
        try vault.deleteAccessToken()
        hasAccessToken = false
        credentialErrorDescription = nil
        etag = nil
        persistCache()
    }

    private func performRefresh(
        reference: GitHubRepositoryReference,
        id: UUID
    ) async {
        defer {
            if activeRefreshID == id {
                activeRefreshID = nil
                refreshTask = nil
                isRefreshing = false
            }
        }

        do {
            let token = try vault.loadAccessToken()
            hasAccessToken = token != nil
            credentialErrorDescription = nil
            var result = try await api.fetchRepository(
                reference,
                accessToken: token,
                etag: etag
            )
            try Task.checkCancellation()
            guard activeRefreshID == id, self.reference == reference else {
                return
            }

            if case .notModified = result, history.last == nil {
                etag = nil
                result = try await api.fetchRepository(
                    reference,
                    accessToken: token,
                    etag: nil
                )
                try Task.checkCancellation()
                guard activeRefreshID == id, self.reference == reference else {
                    return
                }
            }

            apply(result, reference: reference)
        } catch is CancellationError {
            return
        } catch {
            guard activeRefreshID == id, self.reference == reference else {
                return
            }
            lastErrorDescription = error.localizedDescription
            if case let GitHubRepositoryAPIError.rateLimited(resetAt) = error {
                retryNotBefore = resetAt
            }
            if error is GitHubCredentialVaultError {
                credentialErrorDescription = error.localizedDescription
            }
        }
    }

    private func apply(
        _ result: GitHubRepositoryFetchResult,
        reference: GitHubRepositoryReference
    ) {
        let refreshedAt = now()
        switch result {
        case let .modified(snapshot, responseETag, responseRateLimit):
            append(snapshot)
            etag = responseETag
            rateLimit = responseRateLimit
            lastSuccessfulRefreshAt = snapshot.fetchedAt
        case let .notModified(responseETag, responseRateLimit):
            guard let previous = history.last else {
                return
            }
            append(
                GitHubRepositorySnapshot(
                    repository: previous.repository,
                    stars: previous.stars,
                    forks: previous.forks,
                    fetchedAt: refreshedAt
                )
            )
            etag = responseETag
            rateLimit = responseRateLimit
            lastSuccessfulRefreshAt = refreshedAt
        }

        retryNotBefore = nil
        lastErrorDescription = nil
        persistCache(repository: reference.fullName)
    }

    private func append(_ snapshot: GitHubRepositorySnapshot) {
        let oldestRetainedDate = now().addingTimeInterval(-7 * 24 * 60 * 60)
        history = Array(
            (history + [snapshot])
                .filter { $0.fetchedAt >= oldestRetainedDate }
                .suffix(Self.retainedSampleCount)
        )
    }

    private func restoreCache(for reference: GitHubRepositoryReference) {
        guard
            let entry = cache.load(),
            entry.repository.caseInsensitiveCompare(reference.fullName)
                == .orderedSame
        else {
            return
        }

        let oldestRetainedDate = now().addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = entry.history.filter {
            $0.fetchedAt >= oldestRetainedDate
        }
        history = Array(recent.suffix(Self.retainedSampleCount))
        etag = history.isEmpty ? nil : entry.etag
        lastSuccessfulRefreshAt = history.last?.fetchedAt
    }

    private func persistCache(repository: String? = nil) {
        guard let reference else {
            return
        }
        cache.save(
            GitHubRepositoryCacheEntry(
                repository: repository ?? reference.fullName,
                history: history,
                etag: etag
            )
        )
    }

    private func nextPollingDelay() -> TimeInterval {
        let rateLimitDelay = retryNotBefore
            .map { max(0, $0.timeIntervalSince(now())) }
            ?? 0
        return max(pollingInterval, rateLimitDelay)
    }

    private func cancelRefresh() {
        activeRefreshID = nil
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
    }
}
