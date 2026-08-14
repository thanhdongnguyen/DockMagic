import Foundation
import Security

protocol SearchConsoleAPIProviding: Sendable {
    func sites(
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String
    ) async throws -> [SearchConsoleSite]

    func performance(
        property: String,
        range: SearchConsoleTimeRange,
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String,
        now: Date
    ) async throws -> SearchConsoleSnapshot
}

enum SearchConsoleAPIError: LocalizedError, Equatable {
    case invalidPrivateKey
    case signingFailed(String)
    case invalidResponse
    case requestFailed(status: Int, message: String)
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            "The JSON private key could not be read. Create and import a new key."
        case let .signingFailed(message):
            "The service-account request could not be signed: \(message)"
        case .invalidResponse:
            "Google returned an invalid Search Console response."
        case let .requestFailed(status, message):
            "Google Search Console returned HTTP \(status): \(message)"
        case .missingAccessToken:
            "Google did not return an OAuth access token."
        }
    }
}

actor SearchConsoleAPIClient: SearchConsoleAPIProviding {
    static let readOnlyScope =
        "https://www.googleapis.com/auth/webmasters.readonly"

    private struct CachedToken {
        let value: String
        let expiresAt: Date
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let expiresIn: Double?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
        }
    }

    private struct SitesResponse: Decodable {
        let siteEntry: [SiteEntry]?
    }

    private struct SiteEntry: Decodable {
        let siteUrl: String
        let permissionLevel: String
    }

    private struct AnalyticsResponse: Decodable {
        let rows: [Row]?
        let metadata: Metadata?

        struct Row: Decodable {
            let keys: [String]
            let clicks: Double
            let impressions: Double
        }

        struct Metadata: Decodable {
            let firstIncompleteDate: String?
            let firstIncompleteHour: String?
        }
    }

    private let session: URLSession
    private let calendar: Calendar
    private let assertionFactory: (@Sendable (
        SearchConsoleServiceAccountMetadata,
        String,
        Date
    ) throws -> String)?
    private var cachedTokens: [String: CachedToken] = [:]

    init(
        session: URLSession = .shared,
        assertionFactory: (@Sendable (
            SearchConsoleServiceAccountMetadata,
            String,
            Date
        ) throws -> String)? = nil
    ) {
        self.session = session
        self.assertionFactory = assertionFactory
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")
            ?? .gmt
        self.calendar = calendar
    }

    func sites(
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String
    ) async throws -> [SearchConsoleSite] {
        let token = try await accessToken(
            metadata: metadata,
            privateKey: privateKey,
            now: .now
        )
        var request = URLRequest(
            url: URL(string: "https://www.googleapis.com/webmasters/v3/sites")!
        )
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await validatedData(for: request)
        let response = try JSONDecoder().decode(SitesResponse.self, from: data)
        return (response.siteEntry ?? []).map {
            SearchConsoleSite(
                siteURL: $0.siteUrl,
                permissionLevel: $0.permissionLevel
            )
        }
        .sorted { $0.siteURL.localizedStandardCompare($1.siteURL) == .orderedAscending }
    }

    func performance(
        property: String,
        range: SearchConsoleTimeRange,
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String,
        now: Date = .now
    ) async throws -> SearchConsoleSnapshot {
        let token = try await accessToken(
            metadata: metadata,
            privateKey: privateKey,
            now: now
        )
        guard let encodedProperty = property.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "-._~"))
        ), let url = URL(
            string: "https://www.googleapis.com/webmasters/v3/sites/\(encodedProperty)/searchAnalytics/query"
        ) else {
            throw SearchConsoleAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: analyticsBody(range: range, now: now)
        )

        let data = try await validatedData(for: request)
        let response = try JSONDecoder().decode(AnalyticsResponse.self, from: data)
        var points = (response.rows ?? []).compactMap { row -> SearchConsoleDataPoint? in
            guard let key = row.keys.first,
                  let date = parseAnalyticsDate(key) else {
                return nil
            }
            return SearchConsoleDataPoint(
                key: key,
                date: date,
                clicks: row.clicks,
                impressions: row.impressions
            )
        }
        .sorted { $0.date < $1.date }

        if range == .last24Hours, points.count > 24 {
            points = Array(points.suffix(24))
        }

        let incomplete = response.metadata?.firstIncompleteHour
            .flatMap(parseAnalyticsDate)
            ?? response.metadata?.firstIncompleteDate.flatMap(parseAnalyticsDate)
        return SearchConsoleSnapshot(
            property: property,
            range: range,
            points: points,
            fetchedAt: now,
            firstIncompleteDate: incomplete
        )
    }

    private func accessToken(
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String,
        now: Date
    ) async throws -> String {
        if let cached = cachedTokens[metadata.clientEmail],
           cached.expiresAt.timeIntervalSince(now) > 60 {
            return cached.value
        }

        let assertion = try assertionFactory?(metadata, privateKey, now)
            ?? signedAssertion(
                metadata: metadata,
                privateKey: privateKey,
                now: now
            )
        var request = URLRequest(url: metadata.tokenURI)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        let form = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion
        ]
        request.httpBody = form
            .sorted { $0.key < $1.key }
            .map { "\(formEncoded($0.key))=\(formEncoded($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let data = try await validatedData(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let token = response.accessToken, !token.isEmpty else {
            throw SearchConsoleAPIError.missingAccessToken
        }
        cachedTokens[metadata.clientEmail] = CachedToken(
            value: token,
            expiresAt: now.addingTimeInterval(response.expiresIn ?? 3_600)
        )
        return token
    }

    private func signedAssertion(
        metadata: SearchConsoleServiceAccountMetadata,
        privateKey: String,
        now: Date
    ) throws -> String {
        let header: [String: Any] = [
            "alg": "RS256",
            "typ": "JWT",
            "kid": metadata.privateKeyID
        ]
        let issuedAt = Int(now.timeIntervalSince1970)
        let claims: [String: Any] = [
            "iss": metadata.clientEmail,
            "scope": Self.readOnlyScope,
            "aud": metadata.tokenURI.absoluteString,
            "iat": issuedAt,
            "exp": issuedAt + 3_600
        ]
        let encodedHeader = try base64URL(JSONSerialization.data(withJSONObject: header))
        let encodedClaims = try base64URL(JSONSerialization.data(withJSONObject: claims))
        let message = Data("\(encodedHeader).\(encodedClaims)".utf8)
        let key = try secKey(fromPEM: privateKey)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .rsaSignatureMessagePKCS1v15SHA256,
            message as CFData,
            &error
        ) as Data? else {
            throw SearchConsoleAPIError.signingFailed(
                error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            )
        }
        return "\(encodedHeader).\(encodedClaims).\(base64URL(signature))"
    }

    private func secKey(fromPEM pem: String) throws -> SecKey {
        let base64 = pem
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard let data = Data(base64Encoded: base64) else {
            throw SearchConsoleAPIError.invalidPrivateKey
        }
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(
            data as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            throw SearchConsoleAPIError.signingFailed(
                error?.takeRetainedValue().localizedDescription
                    ?? SearchConsoleAPIError.invalidPrivateKey.localizedDescription
            )
        }
        return key
    }

    private func analyticsBody(
        range: SearchConsoleTimeRange,
        now: Date
    ) -> [String: Any] {
        let end = calendar.startOfDay(for: now)
        let startOffset = range == .last24Hours ? -1 : -(range.dayCount - 1)
        let start = calendar.date(byAdding: .day, value: startOffset, to: end) ?? end
        var body: [String: Any] = [
            "startDate": formatDate(start),
            "endDate": formatDate(end),
            "dimensions": [range == .last24Hours ? "hour" : "date"],
            "rowLimit": 25_000
        ]
        body["dataState"] = range == .last24Hours ? "hourly_all" : "all"
        return body
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseAnalyticsDate(_ value: String) -> Date? {
        if let isoDate = ISO8601DateFormatter().date(from: value) {
            return isoDate
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SearchConsoleAPIError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let message = Self.googleErrorMessage(data) ?? HTTPURLResponse
                .localizedString(forStatusCode: http.statusCode)
            throw SearchConsoleAPIError.requestFailed(
                status: http.statusCode,
                message: message
            )
        }
        return data
    }

    private static func googleErrorMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any],
              let error = object["error"] as? [String: Any] else {
            return nil
        }
        return error["message"] as? String
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func formEncoded(_ value: String) -> String {
        value.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "-._~"))
        ) ?? value
    }
}
