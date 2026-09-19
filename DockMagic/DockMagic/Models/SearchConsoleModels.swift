import Foundation

enum SearchConsoleMetric: String, CaseIterable, Codable, Identifiable, Sendable {
    case clicks
    case impressions

    var id: Self { self }

    var title: String {
        switch self {
        case .clicks: "Clicks"
        case .impressions: "Impressions"
        }
    }
}

enum SearchConsoleTimeRange: String, CaseIterable, Codable, Identifiable, Sendable {
    case last24Hours
    case last7Days
    case last28Days
    case last3Months

    var id: Self { self }

    var title: String {
        switch self {
        case .last24Hours: "24h"
        case .last7Days: "7d"
        case .last28Days: "28d"
        case .last3Months: "3m"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .last24Hours: "Last 24 hours"
        case .last7Days: "Last 7 days"
        case .last28Days: "Last 28 days"
        case .last3Months: "Last 3 months"
        }
    }

    var dayCount: Int {
        switch self {
        case .last24Hours: 2
        case .last7Days: 7
        case .last28Days: 28
        case .last3Months: 90
        }
    }
}

enum SearchConsoleDisplayMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case chart
    case numbers
    case focus

    var id: Self { self }

    var title: String {
        switch self {
        case .chart: "Chart"
        case .numbers: "Numbers"
        case .focus: "Focus"
        }
    }
}

struct SearchConsoleDataPoint: Codable, Equatable, Identifiable, Sendable {
    let key: String
    let date: Date
    let clicks: Double
    let impressions: Double

    var id: String { key }

    func value(for metric: SearchConsoleMetric) -> Double {
        switch metric {
        case .clicks: clicks
        case .impressions: impressions
        }
    }
}

struct SearchConsoleSnapshot: Codable, Equatable, Sendable {
    let property: String
    let range: SearchConsoleTimeRange
    let points: [SearchConsoleDataPoint]
    let fetchedAt: Date
    let firstIncompleteDate: Date?

    var clicks: Double { points.reduce(0) { $0 + $1.clicks } }
    var impressions: Double { points.reduce(0) { $0 + $1.impressions } }

    func total(for metric: SearchConsoleMetric) -> Double {
        switch metric {
        case .clicks: clicks
        case .impressions: impressions
        }
    }
}

enum SearchConsoleState: Equatable, Sendable {
    case disconnected
    case loading(SearchConsoleSnapshot?)
    case live(SearchConsoleSnapshot)
    case stale(SearchConsoleSnapshot, message: String)
    case unavailable(String)

    var snapshot: SearchConsoleSnapshot? {
        switch self {
        case .disconnected, .unavailable:
            nil
        case let .loading(snapshot):
            snapshot
        case let .live(snapshot), let .stale(snapshot, _):
            snapshot
        }
    }

    var errorDescription: String? {
        switch self {
        case let .stale(_, message), let .unavailable(message): message
        case .disconnected, .loading, .live: nil
        }
    }
}

struct SearchConsoleServiceAccountMetadata: Codable, Equatable, Sendable {
    let projectID: String
    let privateKeyID: String
    let clientEmail: String
    let tokenURI: URL
}

struct SearchConsoleServiceAccountFile: Decodable, Equatable, Sendable {
    let type: String
    let projectID: String
    let privateKeyID: String
    let privateKey: String
    let clientEmail: String
    let tokenURI: URL

    enum CodingKeys: String, CodingKey {
        case type
        case projectID = "project_id"
        case privateKeyID = "private_key_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case tokenURI = "token_uri"
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        guard type == "service_account" else {
            throw SearchConsoleConfigurationError.invalidAccountType
        }
        guard !projectID.isEmpty, !privateKeyID.isEmpty,
              clientEmail.hasSuffix(".gserviceaccount.com"),
              privateKey.contains("BEGIN PRIVATE KEY") else {
            throw SearchConsoleConfigurationError.invalidServiceAccountFile
        }
        guard tokenURI.scheme == "https",
              ["oauth2.googleapis.com", "accounts.google.com"]
                .contains(tokenURI.host?.lowercased() ?? "") else {
            throw SearchConsoleConfigurationError.invalidTokenEndpoint
        }
    }

    var metadata: SearchConsoleServiceAccountMetadata {
        SearchConsoleServiceAccountMetadata(
            projectID: projectID,
            privateKeyID: privateKeyID,
            clientEmail: clientEmail,
            tokenURI: tokenURI
        )
    }
}

struct SearchConsoleSite: Codable, Equatable, Identifiable, Sendable {
    let siteURL: String
    let permissionLevel: String

    var id: String { siteURL }
}

struct SearchConsoleCredential: Equatable, Identifiable, Sendable {
    let id: String
    let projectID: String
    let privateKeyID: String
    let clientEmail: String
    let selectedProperty: String
    let createdAt: Date
    let isActive: Bool
}

struct SearchConsoleConfiguration: Equatable, Sendable {
    var metadata: SearchConsoleServiceAccountMetadata?
    var selectedProperty: String
    var primaryMetric: SearchConsoleMetric
    var timeRange: SearchConsoleTimeRange
    var displayMode: SearchConsoleDisplayMode
    var credentialIdentifier: String?
    var clicksColor = defaultClicksColor
    var impressionsColor = defaultImpressionsColor
    static let defaultClicksColor = DockColor(red: 0.20, green: 0.79, blue: 0.96)
    static let defaultImpressionsColor = DockColor(red: 0.64, green: 0.36, blue: 1.00)

    static let defaultValue = SearchConsoleConfiguration(
        metadata: nil,
        selectedProperty: "",
        primaryMetric: .clicks,
        timeRange: .last7Days,
        displayMode: .focus,
        credentialIdentifier: nil
    )

    var isConnected: Bool {
        metadata != nil && credentialIdentifier != nil && !selectedProperty.isEmpty
    }
}

enum SearchConsoleConfigurationError: LocalizedError, Equatable {
    case invalidAccountType
    case invalidServiceAccountFile
    case invalidTokenEndpoint
    case missingPrivateKey
    case noAccessibleProperties

    var errorDescription: String? {
        switch self {
        case .invalidAccountType:
            "The selected JSON is not a Google service-account key."
        case .invalidServiceAccountFile:
            "The service-account JSON is missing required fields or a private key."
        case .invalidTokenEndpoint:
            "The JSON contains an unsupported OAuth token endpoint."
        case .missingPrivateKey:
            "The private key is unavailable in SwiftData. Reimport the JSON key."
        case .noAccessibleProperties:
            "This service account cannot access any Search Console properties yet."
        }
    }
}

enum SearchConsoleCountFormatting {
    static func compact(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1_000_000 {
            return shortened(value / 1_000_000, suffix: "M")
        }
        if magnitude >= 1_000 {
            return shortened(value / 1_000, suffix: "K")
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    static func full(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private static func shortened(_ value: Double, suffix: String) -> String {
        let format = value >= 100 ? "%.0f" : "%.1f"
        let displayValue = value >= 100
            ? value.rounded(.toNearestOrAwayFromZero)
            : (value * 10).rounded(.toNearestOrAwayFromZero) / 10
        let rounded = String(
            format: format,
            locale: Locale(identifier: "en_US_POSIX"),
            displayValue
        )
        return rounded + suffix
    }
}
