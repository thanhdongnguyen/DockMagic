#if DEBUG
import Foundation

/// Synthetic data only. Never contacts Augment and never stores a real credential.
struct AugmentFixtureClient: AugmentAnalyticsProviding {
    var mode = "available"
    func overview(token: String, range: AugmentDateRange) async throws -> AugmentUsageSnapshot {
        if mode == "error" || token == "invalid" { throw AugmentAPIError.authentication }
        if mode == "loading" { try await Task.sleep(for: .seconds(30)) }
        let days: [AugmentDailyBucket] = mode == "empty" ? [] : range.dates.enumerated().compactMap { index, date in
            if mode == "partial", index % 6 == 3 { return nil }
            return AugmentDailyBucket(date: date, metrics: AugmentMetrics(
                input: Int64((index % 7 + 1) * 123_456), output: mode == "partial" && date == range.end ? nil : Int64(index % 5 * 2345),
                cacheRead: Int64(index * 9000), cacheWrite: 120, billedUSD: Decimal(index % 7 + 1) / 4, estimatedUSD: Decimal(index % 7 + 1) / 3))
        }
        return AugmentUsageSnapshot(range: range, days: days, fetchedAt: mode == "stale" ? Date().addingTimeInterval(-25_200) : Date(), generatedAt: nil)
    }
    func resources(token: String, range: AugmentDateRange) async throws -> AugmentResourceSnapshot {
        if mode == "detail-error" { throw AugmentAPIError.network }
        var rows: [AugmentResourceUsage] = []
        if mode != "empty" {
            for index in 1...4 {
                let metrics = AugmentMetrics(input: Int64(index * 150_000), output: Int64(index * 4500), cacheRead: 0, cacheWrite: 120,
                    billedUSD: Decimal(index) / Decimal(4), estimatedUSD: Decimal(index) / Decimal(3))
                rows.append(AugmentResourceUsage(name: "Fixture model \(index)", type: "COST_ANALYTICS_RESOURCE_TYPE_MODEL", metrics: metrics))
            }
            rows.append(AugmentResourceUsage(name: "Fixture compute", type: "COST_ANALYTICS_RESOURCE_TYPE_COMPUTE", metrics: AugmentMetrics(billedUSD: 20)))
        }
        return AugmentResourceSnapshot(range: range, resources: rows, fetchedAt: Date())
    }
    @MainActor static func store(mode: String, defaults: UserDefaults) -> AugmentUsageStore {
        AugmentUsageStore(client: AugmentFixtureClient(mode: mode),
            vault: InMemoryAugmentCredentialVault(token: mode == "setup" ? nil : "fixture-only"),
            cache: AugmentHistoryCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("augment-fixture-\(UUID())")),
            defaults: defaults, manualCooldown: 0)
    }
}
#endif
