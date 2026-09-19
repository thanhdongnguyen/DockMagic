import XCTest
import SQLite3
#if canImport(DockMagic)
@testable import DockMagic
#endif

final class OpenCodeHistoryTests: XCTestCase {
    private var directory: URL!
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let now = Date(timeIntervalSince1970: 1_789_560_000)
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private var database: URL { directory.appendingPathComponent("fixture.db") }
    private func sql(_ sql: String) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        var error: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &error)
        let message = error.map { String(cString: $0) } ?? ""
        sqlite3_free(error)
        XCTAssertEqual(result, SQLITE_OK, message)
    }
    private func schema(_ table: String = "message") throws {
        try sql("CREATE TABLE \(table)(id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT\(table == "session_message" ? ", type TEXT" : ""));")
    }
    private func insert(id: String = "m1", session: String = "s1", tokens: String = "{\"input\":100,\"output\":20,\"reasoning\":3,\"cache\":{\"read\":40,\"write\":7}}", cost: String = "0.25", table: String = "message", at: Date? = nil) throws {
        let millis = Int64((at ?? now).timeIntervalSince1970 * 1000)
        let data = "{\"role\":\"assistant\",\"time\":{\"created\":\(millis)},\"tokens\":\(tokens),\"cost\":\(cost),\"modelID\":\"legacy\",\"providerID\":\"provider\",\"model\":{\"id\":\"v2\",\"providerID\":\"provider\"},\"text\":\"PRIVATE_TRANSCRIPT_SENTINEL\"}"
        try sql("INSERT OR REPLACE INTO \(table) VALUES ('\(id)','\(session)',\(millis),'\(data)'\(table == "session_message" ? ",'assistant'" : ""));")
    }
    private func read(_ timezone: TimeZone? = nil) throws -> OpenCodeUsageSnapshot {
        try OpenCodeHistoryReader.readSync(database: database, timezone: timezone ?? utc, now: now)
    }
    func testLegacyFiveBucketsAndRecordedCost() throws {
        try schema(); try insert()
        let result = try read()
        XCTAssertEqual(result.lifetimeTokens, 170)
        XCTAssertEqual(result.day(now)?.tokens.cacheRead, 40)
        XCTAssertEqual(result.day(now)?.tokens.cacheWrite, 7)
        XCTAssertEqual(result.cost.value, 0.25)
        XCTAssertFalse(result.cost.isPartial)
        XCTAssertEqual(result.day(now)?.messageCount, 1)
        XCTAssertEqual(result.day(now)?.sessionCount, 1)
    }
    func testV2PrecedenceDoesNotDoubleCountOrClaimZeroCost() throws {
        try schema(); try schema("session_message"); try insert()
        try insert(tokens: "{\"input\":8,\"output\":2,\"reasoning\":0,\"cache\":{\"read\":0,\"write\":0}}", cost: "0", table: "session_message")
        let result = try read()
        XCTAssertEqual(result.lifetimeTokens, 10)
        XCTAssertEqual(result.recordKeys.count, 1)
        XCTAssertNil(result.cost.value)
        XCTAssertTrue(result.cost.isPartial)
        XCTAssertEqual(result.day(now)?.models.first?.model, "v2")
    }
    func testRepeatedReadAndMessageUpdateReplaceUsage() throws {
        try schema(); try insert()
        XCTAssertEqual(try read(), try read())
        try insert(tokens: "{\"input\":10}")
        XCTAssertEqual(try read().lifetimeTokens, 10)
    }
    func testMissingAssistantRoleDoesNotInventUsage() throws {
        try schema(); try insert()
        try sql("UPDATE message SET data = json_remove(data, '$.role')")
        let result = try read()
        XCTAssertNil(result.lifetimeTokens)
        XCTAssertNil(result.day(now)?.tokens.total)
        XCTAssertNil(result.cost.value)
        XCTAssertTrue(result.isPartial)
    }
    func testStepAndSessionCountersAreNotSummed() throws {
        try schema(); try insert()
        try sql("CREATE TABLE part(data TEXT); INSERT INTO part VALUES ('{\"tokens\":{\"input\":999}}'); CREATE TABLE session(total_tokens INTEGER); INSERT INTO session VALUES(999);")
        XCTAssertEqual(try read().lifetimeTokens, 170)
    }
    func testForksWithDistinctIDsRemainCounted() throws {
        try schema(); try insert(); try insert(id: "fork", session: "copy")
        XCTAssertEqual(try read().lifetimeTokens, 340)
        XCTAssertEqual(try read().day(now)?.sessionCount, 2)
    }
    func testMissingMalformedAndBooleanAreNotZero() throws {
        try schema(); try insert(tokens: "{\"input\":true,\"output\":\"20\",\"reasoning\":-1}")
        let result = try read()
        XCTAssertNil(result.lifetimeTokens)
        XCTAssertNil(result.day(now)?.tokens.total)
        XCTAssertTrue(result.isPartial)
    }
    func testVerifiedZeroAndUnobservedDatesRemainDifferent() throws {
        try schema(); try insert(tokens: "{\"input\":0,\"output\":0,\"reasoning\":0,\"cache\":{\"read\":0,\"write\":0}}", cost: "0")
        let result = try read()
        XCTAssertEqual(result.day(now)?.tokens.total, 0)
        XCTAssertNil(result.day(now.addingTimeInterval(-86400)))
        XCTAssertNil(result.cost.value)
    }
    func testCostCoverageIsIndependent() throws {
        try schema(); try insert(); try insert(id: "m2", cost: "0")
        let result = try read()
        XCTAssertEqual(result.cost.value, 0.25)
        XCTAssertTrue(result.cost.isPartial)
        XCTAssertFalse(result.isPartial)
    }
    func testMidnightTimezoneAndDSTHaveCalendarDayAndHourIdentity() throws {
        try schema()
        let iso = ISO8601DateFormatter()
        let first = iso.date(from: "2026-03-08T09:30:00Z")!
        let second = iso.date(from: "2026-03-08T10:30:00Z")!
        try insert(at: first); try insert(id: "m2", at: second)
        let result = try read(TimeZone(identifier: "America/Los_Angeles")!)
        XCTAssertEqual(result.day(first)?.messageCount, 2)
        XCTAssertEqual(result.day(first)?.hourly.count, 2)
        XCTAssertEqual(result.day(first)?.hourly.map { result.calendar.component(.hour, from: $0.startDate) }, [1, 3])
        let midnight = iso.date(from: "2026-03-08T00:30:00Z")!
        try insert(id: "m3", at: midnight)
        XCTAssertEqual(try read().day(midnight)?.messageCount, 3)
        XCTAssertEqual(try read(TimeZone(identifier: "America/Los_Angeles")!).day(midnight)?.messageCount, 1)
    }
    func testUnknownSchemaAndMissingDatabaseAreExplicit() throws {
        XCTAssertThrowsError(try read()) { XCTAssertEqual($0 as? OpenCodeReadError, .unavailable) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.path))
        try sql("CREATE TABLE mystery (value INTEGER)")
        XCTAssertThrowsError(try read()) { XCTAssertEqual($0 as? OpenCodeReadError, .unsupportedSchema) }
    }
    func testReadonlySourceAndCachePrivacy() throws {
        try schema(); try insert()
        let before = try Data(contentsOf: database)
        let result = try read()
        XCTAssertEqual(try Data(contentsOf: database), before)
        let cache = OpenCodeHistoryCache(directory: directory.appendingPathComponent("cache"))
        try cache.save(result)
        XCTAssertEqual(cache.load(sourceID: result.sourceID, timezoneID: result.timezoneID), result)
        let data = try Data(contentsOf: cache.file(sourceID: result.sourceID, timezoneID: result.timezoneID))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("PRIVATE_TRANSCRIPT_SENTINEL"))
        XCTAssertFalse(text.contains(database.path))
        XCTAssertFalse(text.contains("\"s1\""))
        XCTAssertTrue(result.recordKeys.allSatisfy { $0.count == 64 })
        try cache.clear()
        XCTAssertEqual(try Data(contentsOf: database), before)
        XCTAssertNil(cache.load(sourceID: result.sourceID, timezoneID: result.timezoneID))
    }
    func testCorruptCacheAndNamespaceIsolation() throws {
        let cache = OpenCodeHistoryCache(directory: directory)
        try Data("corrupt".utf8).write(to: cache.file(sourceID: "a", timezoneID: "UTC"))
        XCTAssertNil(cache.load(sourceID: "a", timezoneID: "UTC"))
        XCTAssertNotEqual(cache.file(sourceID: "a", timezoneID: "UTC"), cache.file(sourceID: "a", timezoneID: "Asia/Ho_Chi_Minh"))
    }
    func testAggregationIsDeterministicAcrossManyRowsAndFloatingCosts() throws {
        try schema()
        for index in 0..<60 { try insert(id: "m\(index)", session: "s\(index)", cost: String(Double(index + 1) / 13)) }
        let first = try read()
        for _ in 0..<4 { XCTAssertEqual(try read(), first) }
    }
    func testUnlocatedMalformedRowCannotProveZeroToday() throws {
        try schema()
        try sql("INSERT INTO message VALUES ('broken','session',-1,'{}')")
        XCTAssertNil(try read().day(now)?.tokens.total)
        XCTAssertNil(try read().lifetimeTokens)
    }
    func testDiscoveryHonorsExplicitSourceEvenWhenMissing() {
        let candidates = OpenCodeSourceDiscovery.candidates(selectedPath: database.path, environment: ["OPENCODE_DB": "/another.db"], home: directory)
        XCTAssertEqual(candidates, [database])
    }
    func testReadingLiveWALIncludesCommittedRows() throws {
        try schema()
        var writer: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &writer), SQLITE_OK)
        defer { sqlite3_close(writer) }
        XCTAssertEqual(sqlite3_exec(writer, "PRAGMA journal_mode=WAL;", nil, nil, nil), SQLITE_OK)
        try insert()
        XCTAssertEqual(try read().lifetimeTokens, 170)
        XCTAssertEqual(sqlite3_exec(writer, "BEGIN IMMEDIATE;", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(try read().lifetimeTokens, 170)
        sqlite3_exec(writer, "ROLLBACK;", nil, nil, nil)
    }
}
