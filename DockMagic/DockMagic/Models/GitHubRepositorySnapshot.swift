import Foundation

struct GitHubRepositoryReference: Equatable, Hashable, Sendable {
    let owner: String
    let name: String

    init?(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("git@github.com:") {
            let path = String(trimmed.dropFirst("git@github.com:".count))
            guard let reference = Self.reference(fromPath: path) else {
                return nil
            }
            self = reference
            return
        }

        let normalizedURL = trimmed.contains("://")
            ? trimmed
            : "https://\(trimmed)"
        guard
            let components = URLComponents(string: normalizedURL),
            let host = components.host?.lowercased(),
            host == "github.com" || host == "www.github.com",
            let reference = Self.reference(fromPath: components.path)
        else {
            return nil
        }

        self = reference
    }

    var fullName: String {
        "\(owner)/\(name)"
    }

    var webURLString: String {
        "https://github.com/\(fullName)"
    }

    private static func reference(fromPath path: String) -> Self? {
        let components = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard components.count == 2 else {
            return nil
        }

        let owner = components[0]
        var name = components[1]
        if name.lowercased().hasSuffix(".git") {
            name.removeLast(4)
        }
        guard
            !owner.isEmpty,
            !name.isEmpty,
            owner.count <= 100,
            name.count <= 100,
            owner != ".",
            owner != "..",
            name != ".",
            name != "..",
            !owner.contains(where: { $0.isWhitespace || $0.isNewline }),
            !name.contains(where: { $0.isWhitespace || $0.isNewline })
        else {
            return nil
        }

        return Self(owner: owner, name: name)
    }

    private init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }
}

struct GitHubRepositorySnapshot: Codable, Equatable, Sendable {
    let repository: String
    let stars: Int
    let forks: Int
    let fetchedAt: Date

    init(repository: String, stars: Int, forks: Int, fetchedAt: Date) {
        self.repository = repository
        self.stars = max(0, stars)
        self.forks = max(0, forks)
        self.fetchedAt = fetchedAt
    }
}

extension GitHubRepositorySnapshot {
    static let designPreviewHistory: [Self] = {
        let starCounts = [
            11_980, 12_041, 12_112, 12_148, 12_235, 12_310,
            12_384, 12_422, 12_506, 12_562, 12_648, 12_742
        ]
        let forkCounts = [
            746, 749, 755, 764, 770, 775,
            781, 789, 797, 806, 816, 824
        ]
        let end = Date(timeIntervalSinceReferenceDate: 800_000_000)

        return zip(starCounts, forkCounts).enumerated().map { index, counts in
            Self(
                repository: "thanhdongnguyen/dockmagic",
                stars: counts.0,
                forks: counts.1,
                fetchedAt: end.addingTimeInterval(
                    -Double(starCounts.count - index - 1) * 15 * 60
                )
            )
        }
    }()
}
