import Foundation
import XCTest
@testable import DockMagic

final class GrokBuildFoundationTests: XCTestCase {
    private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let now = GrokBuildDates.parse("2026-09-16T12:00:00Z")!
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testProductionRemainsDisabledWithoutRuntimeEvidence() {
        XCTAssertFalse(GrokBuildFeatureGate.productionEnabled)
        XCTAssertTrue(GrokBuildFeatureGate.runtimeVerifiedVersions.isEmpty)
        XCTAssertFalse(GrokBuildFeatureGate.billingStartupSafetyVerified)
        #if DEBUG
        XCTAssertEqual(GrokBuildFeatureGate.experimentalEnabled,
                       ProcessInfo.processInfo.environment["DOCKMAGIC_EXPERIMENTAL_GROK"] == "1")
        #else
        // Run this in Release with the environment flag set as well: a user's
        // environment must never expose the experimental provider in that build.
        XCTAssertFalse(GrokBuildFeatureGate.experimentalEnabled)
        #endif
    }

    func testLocalParserDoesNotAddCacheOrReasoningToTotal() throws {
        let session = try GrokBuildUsageParser.parse(payload(), expectedID: id)
        XCTAssertEqual(session.total.total, 120)
        XCTAssertEqual(session.turns.first?.tokens.cacheRead, 30)
        XCTAssertEqual(session.turns.first?.tokens.reasoning, 10)
        XCTAssertEqual(session.turns.first?.models["test-model"]?.total, 120)
    }

    func testMissingAndDefaultZeroBreakdownsRemainUnknown() throws {
        var object = try json(payload())
        object["session"] = ["inputTokens": 100, "outputTokens": 20, "totalTokens": 120]
        object["turns"] = [["turnNumber": 1, "endedAt": "2026-09-16T10:00:00Z",
                             "inputTokens": 100, "outputTokens": 20, "totalTokens": 120,
                             "cachedReadTokens": 0, "reasoningTokens": 0]]
        let parsed = try GrokBuildUsageParser.parse(data(object), expectedID: id)
        XCTAssertNil(parsed.total.cacheRead)
        XCTAssertNil(parsed.turns.first?.tokens.reasoning)
        XCTAssertTrue(parsed.turns.first?.models.isEmpty == true)
    }

    func testMalformedTotalsDuplicateTurnsAndWrongIDsAreRejected() throws {
        var object = try json(payload())
        object["sessionId"] = UUID().uuidString
        XCTAssertThrowsError(try GrokBuildUsageParser.parse(data(object), expectedID: id))
        object = try json(payload())
        let turn = try XCTUnwrap((object["turns"] as? [[String: Any]])?.first)
        object["turns"] = [turn, turn]
        XCTAssertThrowsError(try GrokBuildUsageParser.parse(data(object), expectedID: id))
        object = try json(payload())
        object["session"] = ["inputTokens": 100, "outputTokens": 20, "totalTokens": 121]
        XCTAssertThrowsError(try GrokBuildUsageParser.parse(data(object), expectedID: id))
    }

    func testPerTurnSelectorCannotBeMistakenForFullHistory() throws {
        var object = try json(payload())
        object["session"] = ["inputTokens": 200, "outputTokens": 40, "totalTokens": 240]
        XCTAssertThrowsError(try GrokBuildUsageParser.parse(data(object), expectedID: id))
    }

    func testOversizedAndNegativeTokensAreRejected() throws {
        XCTAssertThrowsError(try GrokBuildUsageParser.parse(Data(repeating: 32, count: GrokBuildUsageParser.maximumPayloadBytes + 1), expectedID: id))
        var object = try json(payload())
        object["session"] = ["inputTokens": -1, "outputTokens": 20, "totalTokens": 19]
        XCTAssertThrowsError(try GrokBuildUsageParser.parse(data(object), expectedID: id))
    }

    func testBillingUsesSnakeCaseEnvelopeAndSharedScopeOnlyWhenReported() throws {
        let quota = try billing(#"{"config":{"creditUsagePercent":42.5,"isUnifiedBillingUser":true,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","end":"2026-09-21T00:00:00Z"}},"subscription_tier":"Synthetic plan","on_demand_enabled":false}"#)
        XCTAssertEqual(quota.subscriptionTier, "Synthetic plan")
        XCTAssertEqual(quota.usedPercent, 42.5)
        XCTAssertEqual(quota.scope, .sharedConsumer)
        XCTAssertNotNil(quota.resetsAt)
        let unknown = try billing(#"{"config":{"creditUsagePercent":0},"subscriptionTier":"log-only"}"#)
        XCTAssertNil(unknown.subscriptionTier)
        XCTAssertEqual(unknown.scope, .unspecified)
        XCTAssertEqual(unknown.remainingFraction, 1)
    }

    func testBillingMissingPercentAndNullConfigDoNotBecomeZero() {
        for value in [#"{"config":null}"#, #"{"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY"}}}"#,
                      #"{"config":{"monthlyLimit":{"val":100}}}"#] {
            XCTAssertThrowsError(try billing(value)) { XCTAssertEqual($0 as? GrokBuildError, .billingUnavailable) }
        }
    }

    func testLegacyBillingPresentEmptyCentMeansZeroButAbsentCentDoesNot() throws {
        let quota = try billing(#"{"config":{"monthlyLimit":{"val":1000},"used":{}}}"#)
        XCTAssertEqual(quota.usedPercent, 0)
        XCTAssertThrowsError(try billing(#"{"config":{"monthlyLimit":{},"used":{}}}"#))
        XCTAssertThrowsError(try billing(#"{"config":{"monthlyLimit":{"val":1000},"used":{"val":null}}}"#))
        XCTAssertEqual(try billing(#"{"config":{"creditUsagePercent":100}}"#).remainingFraction, 0)
    }

    func testBillingPrefersReportedPercentageAndRejectsInvalidPeriods() throws {
        XCTAssertEqual(try billing(#"{"config":{"creditUsagePercent":20,"monthlyLimit":{"val":1000},"used":{"val":900}}}"#).usedPercent, 20)
        XCTAssertThrowsError(try billing(#"{"config":{"creditUsagePercent":20,"currentPeriod":{"start":"2026-09-20T00:00:00Z","end":"2026-09-19T00:00:00Z"}}}"#))
        XCTAssertThrowsError(try billing(#"{"config":{"creditUsagePercent":-1}}"#))
    }

    func testBillingDoesNotMixCurrentAndLegacyWindows() throws {
        let quota = try billing(#"{"config":{"creditUsagePercent":25,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","end":"2026-09-21T00:00:00Z"},"billingPeriodStart":"2026-09-01T00:00:00Z","billingPeriodEnd":"2026-10-01T00:00:00Z"}}"#)
        XCTAssertNil(quota.startsAt)
        XCTAssertEqual(quota.resetsAt, GrokBuildDates.parse("2026-09-21T00:00:00Z"))
        XCTAssertThrowsError(try billing(#"{"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY"},"monthlyLimit":{"val":1000},"used":{"val":250}}}"#))
        XCTAssertThrowsError(try billing(#"{"config":{"isUnifiedBillingUser":true,"monthlyLimit":{"val":1000},"used":{"val":250}}}"#))
    }

    func testMonthlyQuotaKeepsReportedWindowWithoutInventingOneForLegacy() throws {
        let monthly = try billing(#"{"config":{"creditUsagePercent":100,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_MONTHLY","start":"2026-09-01T00:00:00Z","end":"2026-10-01T00:00:00Z"}}}"#)
        XCTAssertEqual(monthly.periodType, "USAGE_PERIOD_TYPE_MONTHLY")
        XCTAssertEqual(monthly.remainingFraction, 0)
        let legacy = try billing(#"{"config":{"monthlyLimit":{"val":1000},"used":{"val":250}}}"#)
        XCTAssertNil(legacy.periodType)
        XCTAssertNil(legacy.resetsAt)
    }

    func testRefreshIsIdempotentAndAmendmentReplacesRatherThanAppends() throws {
        var ledger = makeLedger()
        let first = try usage(input: 100)
        for _ in 0..<3 { XCTAssertEqual(ledger.ingest(first, lineage: try lineage(), observedAt: now, calendar: calendar), .accepted) }
        XCTAssertEqual(ledger.snapshot(now: now, calendar: calendar).days.last?.tokens, 120)
        XCTAssertEqual(ledger.ingest(try usage(input: 150), lineage: try lineage(), observedAt: now, calendar: calendar), .accepted)
        XCTAssertEqual(ledger.snapshot(now: now, calendar: calendar).days.last?.tokens, 170)
    }

    func testForkSubagentOrphanAndUnknownKindsAreExcluded() throws {
        for fields in [#", "parent_session_id":"missing-parent""#, #", "session_kind":"fork""#,
                       #", "session_kind":"subagent""#, #", "session_kind":"unknown-future-kind""#,
                       #", "fork_context_source":"forked""#] {
            var ledger = makeLedger()
            XCTAssertEqual(ledger.ingest(try usage(), lineage: try lineage(extra: fields), observedAt: now, calendar: calendar), .excludedLineage)
            XCTAssertTrue(ledger.snapshot(now: now, calendar: calendar).days.allSatisfy { $0.tokens == nil })
        }
    }

    func testShrinkingCountersAreQuarantined() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(input: 150), lineage: try lineage(), observedAt: now, calendar: calendar)
        XCTAssertEqual(ledger.ingest(try usage(input: 100), lineage: try lineage(), observedAt: now, calendar: calendar), .quarantined)
        XCTAssertEqual(ledger.snapshot(now: now, calendar: calendar).days.last?.tokens, 170)
    }

    func testMissingPreviouslyObservedTurnIsQuarantinedDespiteGrowingTotal() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(), lineage: try lineage(), observedAt: now, calendar: calendar)
        var object = try json(payload(input: 200))
        var turns = try XCTUnwrap(object["turns"] as? [[String: Any]])
        turns[0]["turnNumber"] = 2
        object["turns"] = turns
        let renumbered = try GrokBuildUsageParser.parse(data(object), expectedID: id)
        XCTAssertEqual(ledger.ingest(renumbered, lineage: try lineage(), observedAt: now, calendar: calendar), .quarantined)
        XCTAssertEqual(ledger.snapshot(now: now, calendar: calendar).days.last?.tokens, 120)
    }

    func testDelayedFoldRevisesRecordedDayInsteadOfCountingBothDays() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(at: "2026-09-15T23:59:00Z"), lineage: try lineage(), observedAt: now, calendar: calendar)
        XCTAssertEqual(ledger.ingest(try usage(input: 150), lineage: try lineage(), observedAt: now, calendar: calendar), .accepted)
        let days = ledger.snapshot(now: now, calendar: calendar).days
        XCTAssertNil(days[28].tokens)
        XCTAssertEqual(days[29].tokens, 170)
    }

    func testOlderSourceCannotOverwriteRetainedGoodObservation() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(), lineage: try lineage(), observedAt: now, calendar: calendar)
        var object = try json(payload(input: 200))
        object["updatedAt"] = "2026-09-16T11:00:00Z"
        let oldSource = try GrokBuildUsageParser.parse(data(object), expectedID: id)
        XCTAssertEqual(ledger.ingest(oldSource, lineage: try lineage(), observedAt: now, calendar: calendar), .quarantined)
        // No replacement/deletion input is required to render retained history.
        XCTAssertEqual(ledger.snapshot(now: now.addingTimeInterval(60), calendar: calendar).days.last?.tokens, 120)
    }

    func testZeroModelRowsDoNotBecomeRankedModels() throws {
        var ledger = makeLedger()
        let counts = GrokBuildTokenCounts(input: 100, output: 20, total: 120,
            cacheRead: nil, cacheWrite: nil, reasoning: nil)
        let zero = GrokBuildTokenCounts(input: 0, output: 0, total: 0,
            cacheRead: nil, cacheWrite: nil, reasoning: nil)
        let session = GrokBuildSessionUsage(id: id, sourceUpdatedAt: now, total: counts,
            turns: [.init(number: 1, recordedAt: now, tokens: counts, models: ["unobserved-model": zero], upstreamIncomplete: true)])
        _ = ledger.ingest(session, lineage: try lineage(), observedAt: now, calendar: calendar)
        let snapshot = ledger.snapshot(now: now, calendar: calendar)
        XCTAssertEqual(snapshot.days.last?.tokens, 120)
        XCTAssertTrue(snapshot.days.last?.modelCoverageIsPartial == true)
        XCTAssertTrue(snapshot.topModels.isEmpty)
    }

    func testZeroRowsAndMissingDaysRemainUnknown() throws {
        var ledger = makeLedger()
        var object = try json(payload())
        let zero: [String: Any] = ["inputTokens": 0, "outputTokens": 0, "totalTokens": 0]
        object["session"] = zero
        object["turns"] = [zero.merging(["turnNumber": 1, "endedAt": "2026-09-16T10:00:00Z"]) { _, new in new }]
        _ = ledger.ingest(try GrokBuildUsageParser.parse(data(object), expectedID: id), lineage: try lineage(), observedAt: now, calendar: calendar)
        XCTAssertTrue(ledger.snapshot(now: now, calendar: calendar).days.allSatisfy { $0.tokens == nil })
    }

    func testThirtyDayWindowUsesCalendarAndCanRebucketAfterTimezoneChange() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(at: "2026-09-16T00:30:00Z"), lineage: try lineage(), observedAt: now, calendar: calendar)
        var west = calendar
        west.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let rebucketed = ledger.snapshot(now: now, calendar: west)
        XCTAssertEqual(rebucketed.days.count, 30)
        XCTAssertNil(rebucketed.days.last?.tokens)
        XCTAssertEqual(rebucketed.days[28].tokens, 120)
        XCTAssertEqual(rebucketed.topModels.first?.tokens, 120)
    }

    func testDSTUsesCalendarDaysNotFixedTwentyFourHourBuckets() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let spring = try XCTUnwrap(GrokBuildDates.parse("2026-03-09T12:00:00Z"))
        let days = makeLedger().snapshot(now: spring, calendar: local).days
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days[29].startDate.timeIntervalSince(days[28].startDate), 23 * 3_600)
    }

    func testTopModelsRanksTokensNotPrimaryModelAndExcludesExpiredRows() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(at: "2026-08-17T10:00:00Z"), lineage: try lineage(), observedAt: now, calendar: calendar)
        XCTAssertTrue(ledger.snapshot(now: now, calendar: calendar).topModels.isEmpty)
        var object = try json(payload())
        var turns = try XCTUnwrap(object["turns"] as? [[String: Any]])
        turns[0]["primaryModelId"] = "c"
        turns[0]["modelUsage"] = [
            "a": ["inputTokens": 10, "outputTokens": 20, "totalTokens": 30],
            "b": ["inputTokens": 40, "outputTokens": 0, "totalTokens": 40],
            "c": ["inputTokens": 20, "outputTokens": 0, "totalTokens": 20],
            "d": ["inputTokens": 30, "outputTokens": 0, "totalTokens": 30],
        ]
        object["turns"] = turns
        _ = ledger.ingest(try GrokBuildUsageParser.parse(data(object), expectedID: id), lineage: try lineage(), observedAt: now, calendar: calendar)
        XCTAssertEqual(ledger.snapshot(now: now, calendar: calendar).topModels.map(\.model), ["b", "a", "d"])
    }

    func testMissingModelCoverageIsPartialAndDoesNotInventModel() throws {
        var ledger = makeLedger()
        var object = try json(payload())
        var turns = try XCTUnwrap(object["turns"] as? [[String: Any]])
        turns[0].removeValue(forKey: "modelUsage")
        object["turns"] = turns
        _ = ledger.ingest(try GrokBuildUsageParser.parse(data(object), expectedID: id), lineage: try lineage(), observedAt: now, calendar: calendar)
        let snapshot = ledger.snapshot(now: now, calendar: calendar)
        XCTAssertTrue(snapshot.days.last?.modelCoverageIsPartial == true)
        XCTAssertTrue(snapshot.topModels.isEmpty)
    }

    func testLedgerRoundTripDoesNotPersistSessionIDsOrHomePaths() throws {
        var ledger = makeLedger()
        _ = ledger.ingest(try usage(), lineage: try lineage(), observedAt: now, calendar: calendar)
        let encoded = try JSONEncoder().encode(ledger)
        let string = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(string.contains(id.uuidString))
        XCTAssertFalse(string.contains("/synthetic-grok-home"))
        XCTAssertEqual(try JSONDecoder().decode(GrokBuildHistoryLedger.self, from: encoded), ledger)
        XCTAssertNotEqual(ledger.namespace, GrokBuildHistoryLedger(home: URL(fileURLWithPath: "/other-home")).namespace)
    }

    func testACPInitializesBeforeBillingAndRejectsReverseRequests() throws {
        var conversation = GrokBuildBillingConversation()
        XCTAssertTrue(String(decoding: conversation.initializeRequest, as: UTF8.self).contains("initialize"))
        guard case let .write(next) = try conversation.receive(Data(#"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}"#.utf8)) else { return XCTFail("Expected billing request") }
        XCTAssertEqual(try json(next)["method"] as? String, "_x.ai/billing")
        guard case let .write(denial) = try conversation.receive(Data(#"{"jsonrpc":"2.0","id":"reverse","method":"session/request_permission","params":{}}"#.utf8)) else { return XCTFail("Expected denial") }
        XCTAssertEqual((try json(denial)["error"] as? [String: Any])?["code"] as? Int, -32601)
        guard case let .finished(result) = try conversation.receive(Data(#"{"jsonrpc":"2.0","id":2,"result":{"config":{"creditUsagePercent":25}}}"#.utf8)) else { return XCTFail("Expected billing result") }
        XCTAssertEqual(try GrokBuildBillingParser.parse(result, observedAt: now).usedPercent, 25)
    }

    func testACPDoesNotMistakeNetworkFailureForSignedOut() throws {
        var conversation = GrokBuildBillingConversation()
        _ = try conversation.receive(Data(#"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}"#.utf8))
        XCTAssertThrowsError(try conversation.receive(Data(#"{"jsonrpc":"2.0","id":2,"error":{"code":-32603,"data":"Billing service error: HTTP 503"}}"#.utf8))) {
            XCTAssertEqual($0 as? GrokBuildError, .billingUnavailable)
        }
        XCTAssertThrowsError(try conversation.receive(Data(#"{"jsonrpc":"2.0","id":2,"error":{"code":-32000,"data":"Authentication required to fetch billing data"}}"#.utf8))) {
            XCTAssertEqual($0 as? GrokBuildError, .authenticationRequired)
        }
    }

    func testACPRejectsMismatchedIDsAndUnknownExtension() throws {
        var conversation = GrokBuildBillingConversation()
        XCTAssertThrowsError(try conversation.receive(Data(#"{"jsonrpc":"2.0","id":2,"result":{}}"#.utf8)))
        _ = try conversation.receive(Data(#"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}"#.utf8))
        XCTAssertThrowsError(try conversation.receive(Data(#"{"jsonrpc":"2.0","id":2,"error":{"code":-32601}}"#.utf8))) {
            XCTAssertEqual($0 as? GrokBuildError, .unsupportedSchema)
        }
    }

    func testProviderUsesFixedCommandsAndSelectedHome() {
        let configuration = GrokBuildCLIConfiguration(executable: URL(fileURLWithPath: "/synthetic/grok"), home: URL(fileURLWithPath: "/synthetic-home"))
        let request = GrokBuildCLIProvider.billingRequest(configuration: configuration)
        XCTAssertEqual(request.arguments, ["agent", "--no-leader", "stdio"])
        XCTAssertEqual(request.environment["GROK_HOME"], "/synthetic-home")
        XCTAssertEqual(GrokBuildCLIProvider.loginArguments(deviceCode: false), ["login"])
        XCTAssertEqual(GrokBuildCLIProvider.loginArguments(deviceCode: true), ["login", "--device-auth"])
    }

    func testUnsafeBillingStartupGatePreventsACPButExplicitLogoutIsIndependent() async {
        let runner = GrokBuildRecordingRunner(output: Data("grok 1.0.30".utf8))
        let provider = GrokBuildCLIProvider(runner: runner)
        let configuration = GrokBuildCLIConfiguration(executable: URL(fileURLWithPath: "/synthetic/grok"), home: URL(fileURLWithPath: "/synthetic-home"))
        do { _ = try await provider.billing(configuration: configuration); XCTFail("Expected startup gate") }
        catch { XCTAssertEqual(error as? GrokBuildError, .billingStartupUnverified) }
        do { try await provider.signOut(configuration: configuration); XCTFail("Expected startup gate") }
        catch { XCTAssertEqual(error as? GrokBuildError, .signOutUnverified) }
        let requests = await runner.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.arguments, ["--version"])
        XCTAssertEqual(requests.last?.arguments, ["logout"])
        XCTAssertEqual(requests.last?.environment["GROK_HOME"], "/synthetic-home")
    }

    func testChangedCLIVersionCannotRunLogout() async {
        let runner = GrokBuildRecordingRunner(output: Data("grok 1.0.34".utf8))
        let provider = GrokBuildCLIProvider(runner: runner)
        let config = GrokBuildCLIConfiguration(executable: URL(fileURLWithPath: "/synthetic/grok"), home: URL(fileURLWithPath: "/synthetic-home"))
        do { try await provider.signOut(configuration: config); XCTFail("Expected unverified auth version") }
        catch { XCTAssertEqual(error as? GrokBuildError, .authenticationVersionUnverified) }
        let requests = await runner.requests
        XCTAssertEqual(requests.map(\.arguments), [["--version"]])
    }

    func testAuthenticationRequestHasFixedArgumentsBoundsAndSelectedHome() {
        let configuration = GrokBuildCLIConfiguration(executable: URL(fileURLWithPath: "/a path/grok"),
                                                     home: URL(fileURLWithPath: "/a path/home"))
        for device in [true, false] {
            let request = GrokBuildAuthenticationRunner.request(configuration: configuration, deviceCode: device)
            XCTAssertEqual(request.executable, configuration.executable)
            XCTAssertEqual(request.arguments, device ? ["login", "--device-auth"] : ["login"])
            XCTAssertEqual(request.environment["GROK_HOME"], configuration.home.path)
            XCTAssertEqual(request.operation, .authentication)
            XCTAssertEqual(request.timeout, 300)
            XCTAssertEqual(request.maximumOutputBytes, 65_536)
        }
    }

    func testBillingStartupGateDoesNotBlockLocalUsage() async throws {
        let runner = GrokBuildRecordingRunner(output: payload())
        let configuration = GrokBuildCLIConfiguration(executable: URL(fileURLWithPath: "/synthetic/grok"), home: URL(fileURLWithPath: "/synthetic-home"))
        let usage = try await GrokBuildCLIProvider(runner: runner).usage(id: id, configuration: configuration)
        XCTAssertEqual(usage.total.total, 120)
        let requests = await runner.requests
        XCTAssertEqual(requests.first?.arguments, ["usage", id.uuidString.lowercased()])
    }

    func testRunnerEnforcesOutputLimit() async throws {
        var request = GrokBuildProcessRequest(executable: URL(fileURLWithPath: "/usr/bin/yes"), arguments: [], environment: [:], operation: .command)
        request.maximumOutputBytes = 1_024
        do { _ = try await GrokBuildProcessRunner().run(request); XCTFail("Expected output limit") }
        catch { XCTAssertEqual(error as? GrokBuildError, .outputTooLarge) }
    }

    func testRunnerTimesOutAndCancelsWithoutWaitingForSleep() async throws {
        let started = ProcessInfo.processInfo.systemUptime
        var request = GrokBuildProcessRequest(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], environment: [:], operation: .command)
        request.timeout = 0.1
        do { _ = try await GrokBuildProcessRunner().run(request); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? GrokBuildError, .timedOut) }
        request.timeout = 10
        let cancellationRequest = request
        let task = Task { try await GrokBuildProcessRunner().run(cancellationRequest) }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 5)
    }

    func testACPTimeoutStillWorksWhenPeerNeverReadsStdin() async throws {
        let request = GrokBuildProcessRequest(executable: URL(fileURLWithPath: "/usr/bin/yes"),
            arguments: [#"{"jsonrpc":"2.0","id":"reverse","method":"session/request_permission","params":{}}"#],
            environment: [:], operation: .billing, timeout: 0.2)
        let started = ProcessInfo.processInfo.systemUptime
        do { _ = try await GrokBuildProcessRunner().run(request); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? GrokBuildError, .timedOut) }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 5)
    }

    func testDiscoveryExcludesSymlinksAndDuplicateUUIDs() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        for cwd in ["one", "two"] {
            let directory = home.appendingPathComponent("sessions/\(cwd)/\(id.uuidString.lowercased())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload().write(to: directory.appendingPathComponent("usage.json"))
            try Data("{\"info\":{\"id\":\"\(id.uuidString)\"},\"session_summary\":\"must not persist\"}".utf8).write(to: directory.appendingPathComponent("summary.json"))
        }
        let result = try GrokBuildSessionDiscovery().scan(home: home)
        XCTAssertTrue(result.sources.isEmpty)
        XCTAssertEqual(result.excludedCount, 2)
        let link = home.appendingPathComponent("sessions/linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: home.appendingPathComponent("sessions/one"))
        XCTAssertGreaterThan(try GrokBuildSessionDiscovery().scan(home: home).excludedCount, 2)
    }

    func testMissingHomeIsNotEmptyHistory() throws {
        let missing = URL(fileURLWithPath: "/nonexistent-grok-home-\(UUID().uuidString)")
        XCTAssertThrowsError(try GrokBuildSessionDiscovery().scan(home: missing))
    }

    func testDiscoveryScanLimitIsReportedAndNestedBackupIsNotEligible() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = home.appendingPathComponent("sessions/backup/nested/\(id.uuidString.lowercased())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try payload().write(to: directory.appendingPathComponent("usage.json"))
        try Data("{\"info\":{\"id\":\"\(id.uuidString)\"}}".utf8).write(to: directory.appendingPathComponent("summary.json"))
        let result = try GrokBuildSessionDiscovery().scan(home: home)
        XCTAssertTrue(result.sources.isEmpty)
        XCTAssertEqual(result.excludedCount, 1)
        XCTAssertTrue(try GrokBuildSessionDiscovery(maximumEntries: 1).scan(home: home).limited)
    }

    private func makeLedger() -> GrokBuildHistoryLedger { .init(home: URL(fileURLWithPath: "/synthetic-grok-home")) }
    private func billing(_ string: String) throws -> GrokBuildQuotaSnapshot { try GrokBuildBillingParser.parse(Data(string.utf8), observedAt: now) }
    private func json(_ data: Data) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]) }
    private func data(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    private func lineage(extra: String = "") throws -> GrokBuildLineage {
        try JSONDecoder().decode(GrokBuildLineage.self, from: Data("{\"info\":{\"id\":\"\(id.uuidString)\"}\(extra)}".utf8))
    }
    private func usage(input: Int = 100, at: String = "2026-09-16T10:00:00Z") throws -> GrokBuildSessionUsage {
        try GrokBuildUsageParser.parse(payload(input: input, at: at), expectedID: id)
    }
    private func payload(input: Int = 100, at: String = "2026-09-16T10:00:00Z") -> Data {
        Data("""
        {"sessionId":"\(id.uuidString)","updatedAt":"2026-09-16T12:00:00Z",
         "session":{"inputTokens":\(input),"outputTokens":20,"totalTokens":\(input + 20)},
         "turns":[{"turnNumber":1,"endedAt":"\(at)","inputTokens":\(input),"outputTokens":20,
           "totalTokens":\(input + 20),"cachedReadTokens":30,"reasoningTokens":10,
           "modelUsage":{"test-model":{"inputTokens":\(input),"outputTokens":20,"totalTokens":\(input + 20)}}}]}
        """.utf8)
    }
}

private actor GrokBuildRecordingRunner: GrokBuildProcessRunning {
    let output: Data
    var requests: [GrokBuildProcessRequest] = []
    init(output: Data) { self.output = output }
    func run(_ request: GrokBuildProcessRequest) async throws -> GrokBuildProcessResult {
        requests.append(request)
        return .init(output: output, exitCode: 0)
    }
}
