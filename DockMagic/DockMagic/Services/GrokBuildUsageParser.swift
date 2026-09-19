import Foundation

enum GrokBuildUsageParser {
    static let maximumPayloadBytes = 8 * 1_024 * 1_024

    static func parse(_ data: Data, expectedID: UUID) throws -> GrokBuildSessionUsage {
        guard data.count <= maximumPayloadBytes else { throw GrokBuildError.outputTooLarge }
        do {
            let wire = try JSONDecoder().decode(Session.self, from: data)
            guard wire.sessionId == expectedID, !wire.turns.isEmpty,
                  wire.turns.count <= 100_000,
                  let updatedAt = GrokBuildDates.parse(wire.updatedAt),
                  Set(wire.turns.map(\.turnNumber)).count == wire.turns.count else {
                throw GrokBuildError.invalidResponse
            }
            let total = try wire.session.normalized()
            var turns: [GrokBuildRecordedTurn] = []
            var input: Int64 = 0
            var output: Int64 = 0
            for row in wire.turns {
                guard row.turnNumber > 0,
                      let timestamp = GrokBuildDates.parse(row.endedAt),
                      timestamp <= updatedAt else { throw GrokBuildError.invalidResponse }
                let tokens = try row.counts.normalized()
                let (nextInput, inputOverflow) = input.addingReportingOverflow(tokens.input)
                let (nextOutput, outputOverflow) = output.addingReportingOverflow(tokens.output)
                guard !inputOverflow, !outputOverflow else { throw GrokBuildError.invalidResponse }
                input = nextInput
                output = nextOutput
                var models: [String: GrokBuildTokenCounts] = [:]
                var modelInput: Int64 = 0
                var modelOutput: Int64 = 0
                for (model, counts) in row.counts.modelUsage ?? [:] {
                    guard !model.isEmpty, model.utf8.count <= 256,
                          !model.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
                    else { throw GrokBuildError.invalidResponse }
                    let normalized = try counts.normalized()
                    let nextModelInput = modelInput.addingReportingOverflow(normalized.input)
                    let nextModelOutput = modelOutput.addingReportingOverflow(normalized.output)
                    guard !nextModelInput.overflow, !nextModelOutput.overflow,
                          nextModelInput.partialValue <= tokens.input,
                          nextModelOutput.partialValue <= tokens.output else {
                        throw GrokBuildError.invalidResponse
                    }
                    modelInput = nextModelInput.partialValue
                    modelOutput = nextModelOutput.partialValue
                    models[model] = normalized
                }
                turns.append(.init(number: row.turnNumber, recordedAt: timestamp,
                                   tokens: tokens, models: models,
                                   upstreamIncomplete: row.counts.usageIsIncomplete ?? false))
            }
            // Only the full-session command is accepted here. A turn selector
            // still carries whole-session totals and must not enter aggregation.
            guard input == total.input, output == total.output else {
                throw GrokBuildError.invalidResponse
            }
            return .init(id: expectedID, sourceUpdatedAt: updatedAt, total: total, turns: turns)
        } catch let error as GrokBuildError { throw error }
        catch { throw GrokBuildError.invalidResponse }
    }

    private struct Session: Decodable {
        let sessionId: UUID
        let updatedAt: String
        let session: Counts
        let turns: [Turn]
    }

    private struct Turn: Decodable {
        let turnNumber: UInt32
        let endedAt: String
        let counts: Counts
        enum CodingKeys: String, CodingKey { case turnNumber, endedAt }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            turnNumber = try container.decode(UInt32.self, forKey: .turnNumber)
            endedAt = try container.decode(String.self, forKey: .endedAt)
            counts = try Counts(from: decoder)
        }
    }

    private struct Counts: Decodable {
        let inputTokens: Int64
        let outputTokens: Int64
        let totalTokens: Int64
        let cachedReadTokens: Int64?
        let cacheCreationTokens: Int64?
        let reasoningTokens: Int64?
        let usageIsIncomplete: Bool?
        let modelUsage: [String: Counts]?

        func normalized() throws -> GrokBuildTokenCounts {
            let total = inputTokens.addingReportingOverflow(outputTokens)
            guard inputTokens >= 0, outputTokens >= 0, !total.overflow,
                  totalTokens == total.partialValue else { throw GrokBuildError.invalidResponse }
            for value in [cachedReadTokens, cacheCreationTokens, reasoningTokens].compactMap({ $0 }) {
                guard value >= 0 else { throw GrokBuildError.invalidResponse }
            }
            let cache = (cachedReadTokens ?? 0).addingReportingOverflow(cacheCreationTokens ?? 0)
            guard !cache.overflow, cache.partialValue <= inputTokens,
                  (reasoningTokens ?? 0) <= outputTokens else { throw GrokBuildError.invalidResponse }
            return .init(input: inputTokens, output: outputTokens, total: totalTokens,
                         cacheRead: cachedReadTokens.flatMap { $0 > 0 ? $0 : nil },
                         cacheWrite: cacheCreationTokens.flatMap { $0 > 0 ? $0 : nil },
                         reasoning: reasoningTokens.flatMap { $0 > 0 ? $0 : nil })
        }
    }
}

enum GrokBuildBillingParser {
    /// Accept the extension result only, not the full JSON-RPC envelope or
    /// the camelCase unified-log projection. Monetary history is not collected.
    static func parse(_ data: Data, observedAt: Date) throws -> GrokBuildQuotaSnapshot {
        guard data.count <= 512 * 1_024 else { throw GrokBuildError.outputTooLarge }
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            guard let config = response.config else { throw GrokBuildError.billingUnavailable }
            let percentage: Double
            if let reported = config.creditUsagePercent {
                percentage = reported
            } else if config.currentPeriod == nil, config.isUnifiedBillingUser != true,
                      let limit = config.monthlyLimit?.val, limit > 0,
                      let used = config.used?.val, used >= 0 {
                percentage = Double(used) / Double(limit) * 100
            } else { throw GrokBuildError.billingUnavailable }
            guard percentage.isFinite, percentage >= 0 else { throw GrokBuildError.invalidResponse }
            // Never fill a weekly/current window's holes with legacy monthly
            // dates or derive its percentage from the legacy monetary bucket.
            let start: Date?
            let end: Date?
            if let period = config.currentPeriod {
                start = try date(period.start)
                end = try date(period.end)
            } else {
                start = try date(config.billingPeriodStart)
                end = try date(config.billingPeriodEnd)
            }
            if let start, let end, end <= start { throw GrokBuildError.invalidResponse }
            if let type = config.currentPeriod?.type,
               type.utf8.count > 128 || type.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
                throw GrokBuildError.invalidResponse
            }
            let tier = response.subscription_tier
            if let tier, tier.utf8.count > 128 || tier.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
                throw GrokBuildError.invalidResponse
            }
            return .init(usedPercent: min(100, percentage),
                         periodType: config.currentPeriod?.type,
                         startsAt: start, resetsAt: end,
                         scope: config.isUnifiedBillingUser == true ? .sharedConsumer : .unspecified,
                         subscriptionTier: tier, observedAt: observedAt)
        } catch let error as GrokBuildError { throw error }
        catch { throw GrokBuildError.invalidResponse }
    }

    private static func date(_ text: String?) throws -> Date? {
        guard let text else { return nil }
        guard let date = GrokBuildDates.parse(text) else { throw GrokBuildError.invalidResponse }
        return date
    }

    private struct Response: Decodable {
        let config: Config?
        let subscription_tier: String?
        let on_demand_enabled: Bool?
    }
    private struct Config: Decodable {
        let creditUsagePercent: Double?
        let currentPeriod: Period?
        let monthlyLimit: Cent?
        let used: Cent?
        let billingPeriodStart: String?
        let billingPeriodEnd: String?
        let isUnifiedBillingUser: Bool?
    }
    private struct Period: Decodable { let type: String?; let start: String?; let end: String? }
    private struct Cent: Decodable {
        let val: Int64
        enum CodingKeys: String, CodingKey { case val }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // An explicitly present {} means 0 upstream. Absence of the
            // enclosing Cent remains nil; a malformed null val is not zero.
            val = container.contains(.val) ? try container.decode(Int64.self, forKey: .val) : 0
        }
    }
}
