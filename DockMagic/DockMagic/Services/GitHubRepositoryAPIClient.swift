import Foundation

struct GitHubRateLimit: Codable, Equatable, Sendable {
    let limit: Int
    let remaining: Int
    let resetAt: Date?
}

enum GitHubRepositoryFetchResult: Equatable, Sendable {
    case modified(
        snapshot: GitHubRepositorySnapshot,
        etag: String?,
        rateLimit: GitHubRateLimit?
    )
    case notModified(etag: String?, rateLimit: GitHubRateLimit?)
}

protocol GitHubRepositoryAPIProviding: Sendable {
    func fetchRepository(
        _ reference: GitHubRepositoryReference,
        accessToken: String?,
        etag: String?
    ) async throws -> GitHubRepositoryFetchResult
}

enum GitHubRepositoryAPIError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case invalidAccessToken
    case repositoryNotFoundOrPrivate
    case permissionDenied(String)
    case rateLimited(resetAt: Date?)
    case serverError(status: Int)
    case invalidPayload
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "GitHub returned an invalid response."
        case .invalidAccessToken:
            "GitHub rejected the access token. Replace or remove it."
        case .repositoryNotFoundOrPrivate:
            "Repository not found, or the saved token does not have access."
        case let .permissionDenied(message):
            message.isEmpty
                ? "GitHub denied access to this repository."
                : "GitHub denied access: \(message)"
        case let .rateLimited(resetAt):
            if let resetAt {
                "GitHub rate limit reached. Requests resume after \(resetAt.formatted(date: .abbreviated, time: .shortened))."
            } else {
                "GitHub rate limit reached. Try again later."
            }
        case let .serverError(status):
            "GitHub is temporarily unavailable (HTTP \(status))."
        case .invalidPayload:
            "GitHub returned repository data in an unexpected format."
        case let .network(message):
            "Could not reach GitHub: \(message)"
        }
    }
}

struct GitHubRepositoryAPIClient: GitHubRepositoryAPIProviding, @unchecked Sendable {
    static let apiVersion = "2026-03-10"

    private struct RepositoryResponse: Decodable {
        let fullName: String
        let stargazersCount: Int
        let forksCount: Int

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case stargazersCount = "stargazers_count"
            case forksCount = "forks_count"
        }
    }

    private struct ErrorResponse: Decodable {
        let message: String?
    }

    private let session: URLSession
    private let now: @Sendable () -> Date

    init(
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.now = now
    }

    func fetchRepository(
        _ reference: GitHubRepositoryReference,
        accessToken: String?,
        etag: String?
    ) async throws -> GitHubRepositoryFetchResult {
        let url = URL(string: "https://api.github.com")!
            .appending(path: "repos")
            .appending(path: reference.owner)
            .appending(path: reference.name)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            Self.apiVersion,
            forHTTPHeaderField: "X-GitHub-Api-Version"
        )
        request.setValue("DockMagic/1.0", forHTTPHeaderField: "User-Agent")

        if let token = normalizedToken(accessToken) {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        if let etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw GitHubRepositoryAPIError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubRepositoryAPIError.invalidResponse
        }

        let responseETag = httpResponse.value(forHTTPHeaderField: "ETag")
            ?? etag
        let rateLimit = Self.rateLimit(from: httpResponse)

        switch httpResponse.statusCode {
        case 200:
            guard
                let payload = try? JSONDecoder().decode(
                    RepositoryResponse.self,
                    from: data
                )
            else {
                throw GitHubRepositoryAPIError.invalidPayload
            }
            return .modified(
                snapshot: GitHubRepositorySnapshot(
                    repository: payload.fullName,
                    stars: payload.stargazersCount,
                    forks: payload.forksCount,
                    fetchedAt: now()
                ),
                etag: responseETag,
                rateLimit: rateLimit
            )
        case 304:
            return .notModified(etag: responseETag, rateLimit: rateLimit)
        case 401:
            throw GitHubRepositoryAPIError.invalidAccessToken
        case 404:
            throw GitHubRepositoryAPIError.repositoryNotFoundOrPrivate
        case 403, 429:
            let retryAfter = Self.retryDate(from: httpResponse, now: now())
            let message = Self.errorMessage(from: data)
            if rateLimit?.remaining == 0
                || httpResponse.statusCode == 429
                || retryAfter != nil
                || message.localizedCaseInsensitiveContains("rate limit") {
                throw GitHubRepositoryAPIError.rateLimited(
                    resetAt: retryAfter ?? rateLimit?.resetAt
                )
            }
            throw GitHubRepositoryAPIError.permissionDenied(
                message
            )
        case 500...599:
            throw GitHubRepositoryAPIError.serverError(
                status: httpResponse.statusCode
            )
        default:
            throw GitHubRepositoryAPIError.permissionDenied(
                Self.errorMessage(from: data)
            )
        }
    }

    private func normalizedToken(_ token: String?) -> String? {
        guard let token else {
            return nil
        }
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func rateLimit(
        from response: HTTPURLResponse
    ) -> GitHubRateLimit? {
        guard
            let limitValue = response.value(
                forHTTPHeaderField: "X-RateLimit-Limit"
            ),
            let remainingValue = response.value(
                forHTTPHeaderField: "X-RateLimit-Remaining"
            ),
            let limit = Int(limitValue),
            let remaining = Int(remainingValue)
        else {
            return nil
        }

        let resetAt = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))
        return GitHubRateLimit(
            limit: limit,
            remaining: remaining,
            resetAt: resetAt
        )
    }

    private static func retryDate(
        from response: HTTPURLResponse,
        now: Date
    ) -> Date? {
        response.value(forHTTPHeaderField: "Retry-After")
            .flatMap(TimeInterval.init)
            .map { now.addingTimeInterval($0) }
    }

    private static func errorMessage(from data: Data) -> String {
        (try? JSONDecoder().decode(ErrorResponse.self, from: data).message)
            ?? "HTTP request failed."
    }
}
