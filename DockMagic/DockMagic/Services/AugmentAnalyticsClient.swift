import Foundation

protocol AugmentAnalyticsProviding: Sendable {
    func overview(token: String, range: AugmentDateRange) async throws -> AugmentUsageSnapshot
    func resources(token: String, range: AugmentDateRange) async throws -> AugmentResourceSnapshot
}

enum AugmentAPIError: Error, LocalizedError, Equatable {
    case authentication, permission, rateLimited, invalidPayload, incompletePagination, network, server(Int)
    var errorDescription: String? {
        switch self {
        case .authentication: "Augment rejected the token. Replace it in Settings."
        case .permission: "Augment denied Analytics access. Check Enterprise access and token permissions."
        case .rateLimited: "Augment is limiting requests. Try again later."
        case .invalidPayload: "Augment returned an unexpected analytics format or date range."
        case .incompletePagination: "The analytics download was incomplete. Previous data has been kept."
        case .network: "Could not reach Augment. Check your connection and retry."
        case let .server(status): "Augment returned HTTP \(status). Try again or check the connection."
        }
    }
    var needsConnectionAction: Bool { self == .authentication || self == .permission }
}

protocol AugmentHTTPTransport: Sendable {
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

private final class AugmentRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // The endpoint is fixed; even same-origin redirects are unnecessary for analytics.
        completionHandler(nil)
    }
}

struct AugmentURLSessionTransport: AugmentHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config, delegate: AugmentRedirectPolicy(), delegateQueue: nil)
    }
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse,
              response.url?.scheme == "https", response.url?.host == "api.augmentcode.com",
              response.url?.port == nil || response.url?.port == 443 else { throw AugmentAPIError.invalidPayload }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 8 * 1_024 * 1_024 else { throw AugmentAPIError.invalidPayload }
            data.append(byte)
        }
        return (data, response)
    }
}

actor AugmentRequestPacer {
    private var next = Date.distantPast
    private var blockedUntil = Date.distantPast
    private let now: @Sendable () -> Date
    let spacing: TimeInterval
    init(spacing: TimeInterval = 2, now: @escaping @Sendable () -> Date = { Date() }) {
        self.spacing = spacing; self.now = now
    }
    func backOff(for interval: TimeInterval) {
        blockedUntil = max(blockedUntil, now().addingTimeInterval(interval))
    }
    func wait() async throws {
        let now = now()
        guard now >= blockedUntil else { throw AugmentAPIError.rateLimited }
        let slot = max(now, next)
        next = slot.addingTimeInterval(spacing)
        if slot > now { try await Task.sleep(for: .seconds(slot.timeIntervalSince(now))) }
        try Task.checkCancellation()
        guard self.now() >= blockedUntil else { throw AugmentAPIError.rateLimited }
    }
}

struct AugmentAnalyticsClient: AugmentAnalyticsProviding {
    private let transport: any AugmentHTTPTransport
    private let pacer: AugmentRequestPacer
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    init(transport: any AugmentHTTPTransport = AugmentURLSessionTransport(),
         pacer: AugmentRequestPacer = AugmentRequestPacer(),
         sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.transport = transport; self.pacer = pacer; self.sleep = sleep
    }

    func overview(token: String, range: AugmentDateRange) async throws -> AugmentUsageSnapshot {
        let pages = try await fetch(token: token, range: range, resources: false)
        var days: [AugmentDailyBucket] = []
        var seen = Set<Date>()
        for point in pages.flatMap(\.dataPoints) {
            guard let date = AugmentUTC.date(point.startDate), point.startDate == point.endDate,
                  date >= range.start, date <= range.end, seen.insert(date).inserted else { throw AugmentAPIError.invalidPayload }
            days.append(AugmentDailyBucket(date: date, metrics: point.costMetrics.value))
        }
        return AugmentUsageSnapshot(range: range, days: days.sorted { $0.date < $1.date },
            fetchedAt: Date(), generatedAt: pages.last?.metadata.generatedAt.flatMap { ISO8601DateFormatter().date(from: $0) })
    }

    func resources(token: String, range: AugmentDateRange) async throws -> AugmentResourceSnapshot {
        let pages = try await fetch(token: token, range: range, resources: true)
        var rows: [AugmentResourceUsage] = [], seen = Set<String>()
        for point in pages.flatMap(\.dataPoints) {
            guard point.startDate == AugmentUTC.string(range.start), point.endDate == AugmentUTC.string(range.end),
                  let group = point.groupByValues, let name = group.resourceDisplayName,
                  let type = group.resourceType else { throw AugmentAPIError.invalidPayload }
            let row = AugmentResourceUsage(name: name, type: type, metrics: point.costMetrics.value)
            guard seen.insert(row.id).inserted else { throw AugmentAPIError.invalidPayload }
            rows.append(row)
        }
        return AugmentResourceSnapshot(range: range, resources: rows, fetchedAt: Date())
    }

    private func fetch(token: String, range: AugmentDateRange, resources: Bool) async throws -> [AugmentAnalyticsPage] {
        guard !range.dates.isEmpty, range.dates.count <= 90 else { throw AugmentAPIError.invalidPayload }
        var pages: [AugmentAnalyticsPage] = [], cursor: String?, seen = Set<String>()
        // Bounded work per refresh; a cap is failure, never a silently truncated total.
        for _ in 0..<100 {
            try Task.checkCancellation()
            var request = URLRequest(url: URL(string: "https://api.augmentcode.com/analytics/v0/cost-analytics")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AugmentAnalyticsRequest(
                startDate: AugmentUTC.string(range.start), endDate: AugmentUTC.string(range.end),
                groupByKeys: resources ? ["COST_ANALYTICS_GROUP_BY_RESOURCE"] : [],
                granularity: resources ? "COST_ANALYTICS_TIME_GRANULARITY_TOTAL" : "COST_ANALYTICS_TIME_GRANULARITY_DAY", cursor: cursor))
            let data: Data
            do { data = try await send(request) }
            catch is CancellationError { throw CancellationError() }
            catch let error as AugmentAPIError where error.needsConnectionAction { throw error }
            catch { throw pages.isEmpty ? error : AugmentAPIError.incompletePagination }
            let page: AugmentAnalyticsPage
            do { page = try JSONDecoder().decode(AugmentAnalyticsPage.self, from: data) }
            catch { throw AugmentAPIError.invalidPayload }
            guard page.metadata.effectiveStartDate == AugmentUTC.string(range.start),
                  page.metadata.effectiveEndDate == AugmentUTC.string(range.end),
                  page.metadata.returnedDataPointCount == page.dataPoints.count else { throw AugmentAPIError.invalidPayload }
            pages.append(page)
            guard page.pagination.hasMore else { return pages }
            guard let next = page.pagination.nextCursor, !next.isEmpty, seen.insert(next).inserted else { throw AugmentAPIError.incompletePagination }
            cursor = next
        }
        throw AugmentAPIError.incompletePagination
    }

    private func send(_ request: URLRequest) async throws -> Data {
        for attempt in 0..<3 {
            try await pacer.wait()
            let data: Data, response: HTTPURLResponse
            do { (data, response) = try await transport.perform(request) }
            catch is CancellationError { throw CancellationError() }
            catch let error as URLError where error.code == .cancelled { throw CancellationError() }
            catch let error as AugmentAPIError { throw error }
            catch { throw AugmentAPIError.network }
            switch response.statusCode {
            case 200: return data
            case 401: throw AugmentAPIError.authentication
            case 403: throw AugmentAPIError.permission
            case 429:
                let retry = Self.retryDelay(response.value(forHTTPHeaderField: "Retry-After"), now: Date())
                let delay = max(retry, pow(2, Double(attempt)) * 10) + Double.random(in: 0...1)
                // Share the server cooldown across overview, models and manual refresh.
                await pacer.backOff(for: delay)
                // Very long server cooldowns require a later user/automatic refresh.
                guard attempt < 2, retry <= 300 else { throw AugmentAPIError.rateLimited }
                try await sleep(delay)
            case 500...599 where attempt < 2:
                try await sleep(pow(2, Double(attempt)) * 2)
            default: throw AugmentAPIError.server(response.statusCode)
            }
        }
        throw AugmentAPIError.rateLimited
    }

    static func retryDelay(_ header: String?, now: Date) -> TimeInterval {
        guard let header else { return 10 }
        if let seconds = TimeInterval(header), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: header).map { max(0, $0.timeIntervalSince(now)) } ?? 10
    }
}

private struct AugmentAnalyticsRequest: Encodable {
    let startDate: String, endDate: String
    let groupByKeys: [String]
    let granularity: String
    let cursor: String?
    let pageSize = 1000
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date", endDate = "end_date", groupByKeys = "group_by_keys", granularity, cursor, pageSize = "page_size"
    }
}

struct AugmentAnalyticsPage: Decodable {
    struct Point: Decodable {
        let startDate: String, endDate: String
        let costMetrics: Metrics
        let groupByValues: Group?
        enum CodingKeys: String, CodingKey { case startDate = "start_date", endDate = "end_date", costMetrics = "cost_metrics", groupByValues = "group_by_values" }
    }
    struct Group: Decodable {
        let resourceDisplayName: String?, resourceType: String?
        enum CodingKeys: String, CodingKey { case resourceDisplayName = "resource_display_name", resourceType = "resource_type" }
    }
    struct Pagination: Decodable {
        let hasMore: Bool
        let nextCursor: String?
        enum CodingKeys: String, CodingKey { case hasMore = "has_more", nextCursor = "next_cursor" }
    }
    struct Metadata: Decodable {
        let effectiveStartDate: String, effectiveEndDate: String
        let generatedAt: String?
        let returnedDataPointCount: Int
        enum CodingKeys: String, CodingKey { case effectiveStartDate = "effective_start_date", effectiveEndDate = "effective_end_date", generatedAt = "generated_at", returnedDataPointCount = "returned_data_point_count" }
    }
    struct Metrics: Decodable {
        let value: AugmentMetrics
        enum CodingKeys: String, CodingKey {
            case input = "input_tokens", output = "output_tokens", cacheRead = "cache_read_tokens", cacheWrite = "cache_write_tokens"
            case billed = "billed_amount_usd", estimated = "estimated_customer_cost_usd"
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func token(_ key: CodingKeys) throws -> Int64? {
                guard c.contains(key), try !c.decodeNil(forKey: key) else { return nil }
                let value: Int64
                if let number = try? c.decode(Int64.self, forKey: key) { value = number }
                else {
                    let string = try c.decode(String.self, forKey: key)
                    guard let integer = Int64(string) else { throw AugmentAPIError.invalidPayload }
                    value = integer
                }
                guard value >= 0 else { throw AugmentAPIError.invalidPayload }
                return value
            }
            func money(_ key: CodingKeys) throws -> Decimal? {
                guard let string = try c.decodeIfPresent(String.self, forKey: key) else { return nil }
                guard string.range(of: "^-?[0-9]+(\\.[0-9]+)?$", options: .regularExpression) != nil,
                      string.filter(\.isNumber).count <= 38,
                      let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { throw AugmentAPIError.invalidPayload }
                return value
            }
            value = try AugmentMetrics(input: token(.input), output: token(.output), cacheRead: token(.cacheRead),
                cacheWrite: token(.cacheWrite), billedUSD: money(.billed), estimatedUSD: money(.estimated))
        }
    }
    let dataPoints: [Point]
    let pagination: Pagination
    let metadata: Metadata
    enum CodingKeys: String, CodingKey { case dataPoints = "data_points", pagination, metadata }
}
