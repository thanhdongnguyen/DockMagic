import XCTest
@testable import DockMagic

actor AugmentTestTransport: AugmentHTTPTransport {
    var responses: [(Int, Data, [String: String])]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [(Int, Data, [String: String])]) { self.responses = responses }
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw AugmentAPIError.network }
        let response = responses.removeFirst()
        return (response.1, HTTPURLResponse(url: request.url!, statusCode: response.0, httpVersion: nil, headerFields: response.2)!)
    }
}

private final class AugmentPacerClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date()
    func read() -> Date { lock.withLock { date } }
    func advance(_ interval: TimeInterval) { lock.withLock { date = date.addingTimeInterval(interval) } }
}

final class AugmentAnalyticsTests: XCTestCase {
    let range = AugmentDateRange(start: AugmentUTC.date("2026-09-14")!, end: AugmentUTC.date("2026-09-15")!)
    func page(_ points: [[String: Any]], more: Bool = false, cursor: String? = nil) throws -> Data {
        var pagination: [String: Any] = ["has_more": more]
        if let cursor { pagination["next_cursor"] = cursor }
        return try JSONSerialization.data(withJSONObject: ["data_points": points, "pagination": pagination,
            "metadata": ["effective_start_date": "2026-09-14", "effective_end_date": "2026-09-15", "returned_data_point_count": points.count]])
    }
    func point(_ date: String = "2026-09-15", metrics: [String: Any]) -> [String: Any] {
        ["start_date": date, "end_date": date, "cost_metrics": metrics]
    }
    func client(_ transport: AugmentTestTransport) -> AugmentAnalyticsClient {
        let clock = AugmentPacerClock()
        return AugmentAnalyticsClient(transport: transport, pacer: AugmentRequestPacer(spacing: 0, now: { clock.read() }), sleep: { clock.advance($0 + 0.01) })
    }
    func testExactTokenStringDecimalAndMissingArePreserved() async throws {
        let transport = AugmentTestTransport([(200, try page([point(metrics: ["input_tokens": "9007199254740993", "output_tokens": 0, "billed_amount_usd": "0.123456789012345678"])]), [:])])
        let value = try await client(transport).overview(token: "synthetic", range: range)
        XCTAssertEqual(value.latest?.metrics.input, 9_007_199_254_740_993)
        XCTAssertEqual(value.latest?.metrics.output, 0)
        XCTAssertNil(value.latest?.metrics.cacheRead)
        XCTAssertEqual(value.latest?.metrics.billedUSD, Decimal(string: "0.123456789012345678"))
        XCTAssertTrue(value.isPartial)
        XCTAssertNil(value.day(range.start))
        let requests = await transport.requests
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requests[0].httpBody!) as? [String: Any])
        XCTAssertNil(body["filters"])
        XCTAssertEqual(body["group_by_keys"] as? [String], [])
        XCTAssertEqual(body["granularity"] as? String, "COST_ANALYTICS_TIME_GRANULARITY_DAY")
    }
    func testPaginationNeverDoubleCountsAndIncludesCursor() async throws {
        let transport = AugmentTestTransport([
            (200, try page([point("2026-09-14", metrics: ["input_tokens": 4])], more: true, cursor: "next"), [:]),
            (200, try page([point(metrics: ["input_tokens": 7])]), [:])])
        let value = try await client(transport).overview(token: "synthetic", range: range)
        XCTAssertEqual(value.days.map(\.metrics.input), [4, 7])
        let requests = await transport.requests
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requests[1].httpBody!) as? [String: Any])
        XCTAssertEqual(body["cursor"] as? String, "next")
    }
    func testRepeatedCursorAndDuplicateDaysFail() async throws {
        for repeated in [true, false] {
            let data = try page([point(metrics: ["input_tokens": 4])], more: repeated, cursor: "same")
            let transport = AugmentTestTransport(repeated ? [(200, data, [:]), (200, data, [:])] : [(200, try page([point(metrics: [:]), point(metrics: [:])]), [:])])
            do { _ = try await client(transport).overview(token: "synthetic", range: range); XCTFail("Must reject ambiguous aggregation") }
            catch { XCTAssertTrue(error is AugmentAPIError) }
        }
    }
    func testOverflowNegativeAndMalformedMoneyFail() async throws {
        for metrics: [String: Any] in [["input_tokens": "9223372036854775808"], ["output_tokens": -1], ["billed_amount_usd": "2garbage"], ["input_tokens": 1.5]] {
            let transport = AugmentTestTransport([(200, try page([point(metrics: metrics)]), [:])])
            do { _ = try await client(transport).overview(token: "synthetic", range: range); XCTFail("Invalid scalar accepted") }
            catch { XCTAssertEqual(error as? AugmentAPIError, .invalidPayload) }
        }
    }
    func testEmptyResponseIsNotZero() async throws {
        let transport = AugmentTestTransport([(200, try page([]), [:])])
        let value = try await client(transport).overview(token: "synthetic", range: range)
        XCTAssertTrue(value.days.isEmpty); XCTAssertNil(value.latest)
    }
    func testAuthErrorsDoNotRetryAndErrorBodiesAreNotExposed() async throws {
        for (status, expected) in [(401, AugmentAPIError.authentication), (403, .permission)] {
            let transport = AugmentTestTransport([(status, Data("private@example.invalid secret".utf8), [:])])
            do { _ = try await client(transport).overview(token: "synthetic", range: range); XCTFail() }
            catch { XCTAssertEqual(error as? AugmentAPIError, expected); XCTAssertFalse(error.localizedDescription.contains("private@")) }
            let count = await transport.requests.count
            XCTAssertEqual(count, 1)
        }
    }
    func testRateLimitRetriesAndStopsAfterThree() async throws {
        let transport = AugmentTestTransport(Array(repeating: (429, Data(), ["Retry-After": "10"]), count: 3))
        do { _ = try await client(transport).overview(token: "synthetic", range: range); XCTFail() }
        catch { XCTAssertEqual(error as? AugmentAPIError, .rateLimited) }
        let count = await transport.requests.count; XCTAssertEqual(count, 3)
        XCTAssertEqual(AugmentAnalyticsClient.retryDelay("17", now: .now), 17)
    }
    func testModelsExcludeComputeAndRankChosenMetric() async throws {
        let points = [("Model A", "MODEL", 4), ("Compute", "COMPUTE", 100), ("Model B", "MODEL", 7)].map { name, type, value in
            ["start_date": "2026-09-14", "end_date": "2026-09-15", "cost_metrics": ["output_tokens": value],
             "group_by_values": ["resource_display_name": name, "resource_type": "COST_ANALYTICS_RESOURCE_TYPE_\(type)"]] as [String: Any]
        }
        let transport = AugmentTestTransport([(200, try page(points), [:])])
        let value = try await client(transport).resources(token: "synthetic", range: range)
        XCTAssertEqual(value.models(by: .output).map(\.name), ["Model B", "Model A"])
        XCTAssertEqual(value.resources.count, 3)
    }
    func testNumericInt64NullAndRetryAfterDate() async throws {
        let transport = AugmentTestTransport([(200, try page([point(metrics: ["input_tokens": Int64.max, "output_tokens": NSNull(), "billed_amount_usd": "-0.25"])]), [:])])
        let value = try await client(transport).overview(token: "synthetic", range: range)
        XCTAssertEqual(value.latest?.metrics.input, Int64.max)
        XCTAssertNil(value.latest?.metrics.output)
        XCTAssertEqual(value.latest?.metrics.billedUSD, -Decimal(1) / 4)
        let now = ISO8601DateFormatter().date(from: "2026-09-16T00:00:00Z")!
        XCTAssertEqual(AugmentAnalyticsClient.retryDelay("Wed, 16 Sep 2026 00:01:00 GMT", now: now), 60)
    }
    func testFailureOnSecondPageNeverPublishesPartialOverview() async throws {
        let transport = AugmentTestTransport([(200, try page([point(metrics: ["input_tokens": 1])], more: true, cursor: "next"), [:])])
        do { _ = try await client(transport).overview(token: "synthetic", range: range); XCTFail() }
        catch { XCTAssertEqual(error as? AugmentAPIError, .incompletePagination) }
    }
    func testMismatchedEffectiveRangeAndMissingCursorFail() async throws {
        var wrong = try JSONSerialization.jsonObject(with: page([])) as! [String: Any]
        wrong["metadata"] = ["effective_start_date": "2026-09-13", "effective_end_date": "2026-09-15", "returned_data_point_count": 0]
        for (data, expected) in [(try JSONSerialization.data(withJSONObject: wrong), AugmentAPIError.invalidPayload), (try page([], more: true), .incompletePagination)] {
            let transport = AugmentTestTransport([(200, data, [:])])
            do { _ = try await client(transport).overview(token: "synthetic", range: range); XCTFail() }
            catch { XCTAssertEqual(error as? AugmentAPIError, expected) }
        }
    }
    func testRateLimitCooldownAlsoBlocksOtherQueriesUntilExpiry() async throws {
        let clock = AugmentPacerClock()
        let pacer = AugmentRequestPacer(spacing: 0, now: { clock.read() })
        await pacer.backOff(for: 3600)
        do { try await pacer.wait(); XCTFail("A second query must honor Retry-After") }
        catch { XCTAssertEqual(error as? AugmentAPIError, .rateLimited) }
        clock.advance(3601)
        try await pacer.wait()
    }
    func testUTCDoesNotFollowLocalMidnightAndRangeLengths() {
        let now = ISO8601DateFormatter().date(from: "2026-09-16T00:30:00+07:00")!
        for days in [7, 30, 90] {
            let value = AugmentDateRange.reported(days: days, now: now)
            XCTAssertEqual(AugmentUTC.string(value.end), "2026-09-14")
            XCTAssertEqual(value.dates.count, days)
        }
        XCTAssertNil(AugmentUTC.date("2026-02-30"))
    }
}
