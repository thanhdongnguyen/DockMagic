import Foundation

protocol ServiceStatusProviding: Sendable {
    func fetchStatus(
        for provider: ServiceStatusProviderID
    ) async throws -> ServiceHealthSnapshot
}

enum ServiceStatusAPIError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case serverError(status: Int)
    case invalidPayload(provider: ServiceStatusProviderID)
    case missingComponent(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The status provider returned an invalid response."
        case let .serverError(status):
            "The status provider returned HTTP \(status)."
        case let .invalidPayload(provider):
            "\(provider.displayName) status data used an unexpected format."
        case let .missingComponent(name):
            "The status page no longer exposes the \(name) component."
        case let .network(message):
            "Could not reach the status provider: \(message)"
        }
    }
}

struct ServiceStatusAPIClient: ServiceStatusProviding, @unchecked Sendable {
    private struct ClaudeSummary: Decodable {
        let components: [ClaudeComponent]
        let incidents: [ClaudeIncident]
    }

    private struct ClaudeComponent: Decodable {
        let id: String
        let name: String
        let status: String
    }

    private struct ClaudeIncident: Decodable {
        let id: String
        let name: String
        let status: String
        let updatedAt: String?
        let shortlink: String?
        let components: [ClaudeComponent]?
        let incidentUpdates: [ClaudeIncidentUpdate]?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case status
            case updatedAt = "updated_at"
            case shortlink
            case components
            case incidentUpdates = "incident_updates"
        }
    }

    private struct ClaudeIncidentUpdate: Decodable {
        let affectedComponents: [ClaudeAffectedComponent]?

        enum CodingKeys: String, CodingKey {
            case affectedComponents = "affected_components"
        }
    }

    private struct ClaudeAffectedComponent: Decodable {
        let code: String
        let name: String
    }

    private static let openAIStatusURL = URL(
        string: "https://status.openai.com/feed.rss"
    )!
    private static let claudeStatusURL = URL(
        string: "https://status.claude.com/api/v2/summary.json"
    )!
    private static let claudeCodeComponentID = "yyzkbfz2thpt"

    private let session: URLSession
    private let now: @Sendable () -> Date

    init(
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.now = now
    }

    func fetchStatus(
        for provider: ServiceStatusProviderID
    ) async throws -> ServiceHealthSnapshot {
        let url = switch provider {
        case .codex: Self.openAIStatusURL
        case .claudeCode: Self.claudeStatusURL
        }
        let data = try await fetchData(from: url)
        let fetchedAt = now()

        switch provider {
        case .codex:
            return try Self.parseOpenAIStatus(
                data,
                fetchedAt: fetchedAt
            )
        case .claudeCode:
            return try Self.parseClaudeStatus(
                data,
                fetchedAt: fetchedAt
            )
        }
    }

    static func parseOpenAIStatus(
        _ data: Data,
        fetchedAt: Date
    ) throws -> ServiceHealthSnapshot {
        let parserDelegate = OpenAIStatusRSSParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            throw ServiceStatusAPIError.invalidPayload(provider: .codex)
        }

        let incidents = parserDelegate.items.compactMap { item -> ServiceHealthSnapshot? in
            let phase = incidentPhase(from: item.description)
            guard phase != .resolved else {
                return nil
            }

            let affectedComponents = openAIComponents(from: item.description)
                .filter { isCodexComponent($0.name) }
            let titleMentionsCodex = item.title
                .localizedCaseInsensitiveContains("Codex")
            guard !affectedComponents.isEmpty || titleMentionsCodex else {
                return nil
            }

            let reportedSeverity = affectedComponents
                .map(\.severity)
                .max { $0.rank < $1.rank }
            let severity: ServiceHealthSeverity
            if let reportedSeverity, reportedSeverity != .operational {
                severity = reportedSeverity
            } else {
                // An unresolved Codex incident remains degraded even if the
                // feed temporarily omits component impact details.
                severity = .degraded
            }

            let incidentURL = normalizedIncidentURL(item.link)
            let incidentID = item.guid
                .flatMap(normalizedIncidentURL)
                .map(\.lastPathComponent)
                ?? incidentURL?.lastPathComponent

            return ServiceHealthSnapshot(
                provider: .codex,
                severity: severity,
                phase: phase,
                incidentID: incidentID,
                title: item.title.nilIfEmpty,
                incidentURL: incidentURL,
                fetchedAt: fetchedAt,
                updatedAt: rssDate(item.pubDate)
            )
        }

        guard let incident = incidents.max(by: { lhs, rhs in
            if lhs.severity.rank != rhs.severity.rank {
                return lhs.severity.rank < rhs.severity.rank
            }
            return (lhs.updatedAt ?? .distantPast)
                < (rhs.updatedAt ?? .distantPast)
        }) else {
            return .operational(provider: .codex, fetchedAt: fetchedAt)
        }

        return incident
    }

    static func parseClaudeStatus(
        _ data: Data,
        fetchedAt: Date
    ) throws -> ServiceHealthSnapshot {
        let summary: ClaudeSummary
        do {
            summary = try JSONDecoder().decode(ClaudeSummary.self, from: data)
        } catch {
            throw ServiceStatusAPIError.invalidPayload(provider: .claudeCode)
        }

        guard let component = summary.components.first(where: {
            $0.id == claudeCodeComponentID
                || $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare("Claude Code") == .orderedSame
        }) else {
            throw ServiceStatusAPIError.missingComponent("Claude Code")
        }

        guard let severity = severity(fromComponentStatus: component.status) else {
            throw ServiceStatusAPIError.invalidPayload(provider: .claudeCode)
        }
        guard severity.isIncident else {
            return .operational(provider: .claudeCode, fetchedAt: fetchedAt)
        }

        let incident = summary.incidents
            .filter { claudeIncident($0, affects: component) }
            .max {
                (iso8601Date($0.updatedAt) ?? .distantPast)
                    < (iso8601Date($1.updatedAt) ?? .distantPast)
            }

        return ServiceHealthSnapshot(
            provider: .claudeCode,
            severity: severity,
            phase: incident.map { incidentPhase(from: $0.status) } ?? .unknown,
            incidentID: incident?.id,
            title: incident?.name.nilIfEmpty,
            incidentURL: incident?.shortlink.flatMap(URL.init(string:)),
            fetchedAt: fetchedAt,
            updatedAt: iso8601Date(incident?.updatedAt)
        )
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.setValue("DockMagic/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(
            "application/json, application/rss+xml, application/xml;q=0.9, */*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw ServiceStatusAPIError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceStatusAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceStatusAPIError.serverError(
                status: httpResponse.statusCode
            )
        }
        return data
    }

    private static func incidentPhase(
        from htmlOrValue: String?
    ) -> ServiceIncidentPhase {
        let value = htmlOrValue?.lowercased() ?? ""
        if value.contains("monitoring") { return .monitoring }
        if value.contains("identified") { return .identified }
        if value.contains("investigating") { return .investigating }
        if value.contains("resolved") { return .resolved }
        return .unknown
    }

    private static func severity(
        fromComponentStatus value: String
    ) -> ServiceHealthSeverity? {
        switch value
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) {
        case "operational":
            .operational
        case "degraded performance", "degraded":
            .degraded
        case "partial outage":
            .partialOutage
        case "major outage", "full outage":
            .majorOutage
        case "under maintenance", "maintenance":
            .maintenance
        default:
            nil
        }
    }

    private static func openAIComponents(
        from description: String?
    ) -> [(name: String, severity: ServiceHealthSeverity)] {
        guard let description else { return [] }
        let pattern = #"<li>\s*([^<]+?)\s*\(([^)]+)\)\s*</li>"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let range = NSRange(description.startIndex..., in: description)
        return expression.matches(in: description, range: range).compactMap {
            match in
            guard match.numberOfRanges == 3,
                  let nameRange = Range(match.range(at: 1), in: description),
                  let statusRange = Range(match.range(at: 2), in: description),
                  let severity = severity(
                    fromComponentStatus: String(description[statusRange])
                  ) else {
                return nil
            }
            return (
                String(description[nameRange]).trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                severity
            )
        }
    }

    private static func isCodexComponent(_ name: String) -> Bool {
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.contains("codex")
            || normalized == "cli"
            || normalized == "vs code extension"
    }

    private static func claudeIncident(
        _ incident: ClaudeIncident,
        affects component: ClaudeComponent
    ) -> Bool {
        if incident.components?.contains(where: {
            $0.id == component.id
                || $0.name.caseInsensitiveCompare(component.name) == .orderedSame
        }) == true {
            return true
        }

        return incident.incidentUpdates?.contains(where: { update in
            update.affectedComponents?.contains(where: {
                $0.code == component.id
                    || $0.name.caseInsensitiveCompare(component.name)
                        == .orderedSame
            }) == true
        }) == true
    }

    private static func normalizedIncidentURL(_ value: String?) -> URL? {
        guard let value else { return nil }
        return URL(
            string: value.replacingOccurrences(
                of: "status.openai.com//incidents",
                with: "status.openai.com/incidents"
            )
        )
    }

    private static func rssDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }

    private static func iso8601Date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

private final class OpenAIStatusRSSParser: NSObject, XMLParserDelegate {
    struct Item {
        var title = ""
        var link: String?
        var guid: String?
        var pubDate: String?
        var description: String?
    }

    private(set) var items: [Item] = []
    private var currentItem: Item?
    private var currentElement: String?
    private var currentText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" {
            currentItem = Item()
        }
        guard currentItem != nil else { return }
        currentElement = elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentItem != nil else { return }
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard currentItem != nil,
              let value = String(data: CDATABlock, encoding: .utf8) else {
            return
        }
        currentText += value
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard var item = currentItem else { return }
        let value = currentText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch elementName {
        case "title":
            item.title = value
        case "link":
            item.link = value
        case "guid":
            item.guid = value
        case "pubDate":
            item.pubDate = value
        case "description":
            item.description = value
        case "item":
            items.append(item)
            currentItem = nil
        default:
            break
        }

        if currentItem != nil {
            currentItem = item
        }
        currentElement = nil
        currentText = ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
