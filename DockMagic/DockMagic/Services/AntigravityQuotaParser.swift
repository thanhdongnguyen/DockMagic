import Foundation

enum AntigravityQuotaParser {
    static func parse(_ data: Data, source: String, now: Date) throws -> AntigravityQuotaSnapshot? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return parse(root, source: source, now: now)
    }

    static func parse(_ root: [String: Any], source: String, now: Date) -> AntigravityQuotaSnapshot? {
        let response = root["response"] as? [String: Any] ?? root
        let user = response["userStatus"] as? [String: Any] ?? [:]
        let tier = user["userTier"] as? [String: Any] ?? [:]
        let planStatus = user["planStatus"] as? [String: Any] ?? [:]
        let planInfo = planStatus["planInfo"] as? [String: Any] ?? [:]
        let plan = AntigravityJSON.text(root["plan_tier"])
            ?? AntigravityJSON.text(tier["name"])
            ?? AntigravityJSON.text(tier["id"])
            ?? AntigravityJSON.text(planInfo["planName"])
        var groups: [AntigravityQuotaGroup] = []
        if let rawGroups = response["groups"] as? [[String: Any]] {
            for (index, raw) in rawGroups.prefix(20).enumerated() {
                let title = AntigravityJSON.text(raw["displayName"]) ?? "Model group \(index + 1)"
                let buckets = (raw["buckets"] as? [[String: Any]] ?? []).prefix(20).enumerated().map { offset, bucket in
                    parseBucket(bucket, fallbackID: "bucket-\(offset)")
                }
                if !buckets.isEmpty {
                    groups.append(AntigravityQuotaGroup(id: family(title), title: title, buckets: buckets))
                }
            }
        } else if let quotas = root["quota"] as? [String: [String: Any]] {
            var grouped: [String: [AntigravityQuotaBucket]] = [:]
            for (id, raw) in quotas.sorted(by: { $0.key < $1.key }).prefix(100) {
                var bucket = raw
                bucket["bucketId"] = id
                grouped[family(id), default: []].append(parseBucket(bucket, fallbackID: id))
            }
            groups = grouped.map { AntigravityQuotaGroup(id: $0.key, title: familyTitle($0.key), buckets: sorted($0.value)) }
        } else {
            let config = user["cascadeModelConfigData"] as? [String: Any] ?? response
            let models = config["clientModelConfigs"] as? [[String: Any]] ?? []
            var grouped: [String: [AntigravityQuotaBucket]] = [:]
            for model in models.prefix(200) {
                guard let quota = model["quotaInfo"] as? [String: Any],
                      let label = AntigravityJSON.text(model["label"] ?? model["displayName"]) else { continue }
                let lower = label.lowercased()
                guard !["image", "autocomplete", "lite"].contains(where: lower.contains) else { continue }
                let bucket = AntigravityQuotaBucket(
                    id: label, title: "Model quota", kind: nil,
                    remainingFraction: fraction(quota["remainingFraction"]),
                    resetsAt: AntigravityJSON.date(quota["resetTime"]), resetDescription: nil
                )
                grouped[family(label), default: []].append(bucket)
            }
            // Legacy tiers share a pool. Keep the most constrained known row,
            // never interpret an omitted fraction as zero or invent a duration.
            groups = grouped.compactMap { id, buckets in
                guard let chosen = buckets.min(by: { ($0.remainingFraction ?? 2) < ($1.remainingFraction ?? 2) }) else { return nil }
                return AntigravityQuotaGroup(id: id, title: familyTitle(id), buckets: [chosen])
            }
        }
        guard !groups.isEmpty else { return nil }
        // Merge repeated family groups while preserving distinct bucket IDs.
        let merged = Dictionary(grouping: groups, by: \.id).map { id, rows in
            let buckets = Dictionary(grouping: rows.flatMap(\.buckets), by: \.id)
                .compactMap { $0.value.first }
            return AntigravityQuotaGroup(id: id, title: rows[0].title, buckets: sorted(buckets))
        }.sorted { $0.id < $1.id }
        return AntigravityQuotaSnapshot(groups: merged, plan: plan, source: source, observedAt: now)
    }

    private static func parseBucket(_ raw: [String: Any], fallbackID: String) -> AntigravityQuotaBucket {
        let id = AntigravityJSON.text(raw["bucketId"]) ?? fallbackID
        let name = AntigravityJSON.text(raw["displayName"])
        let hint = "\(id) \(name ?? "") \(raw["window"] as? String ?? "")".lowercased()
        let kind: CodexRateLimitWindowKind? = hint.contains("week") || hint.contains("7d") ? .weekly
            : hint.contains("5h") || hint.contains("five-hour") || hint.contains("5-hour") ? .fiveHour : nil
        let remaining = raw["remaining"] as? [String: Any] ?? [:]
        return AntigravityQuotaBucket(
            id: id,
            title: kind == .fiveHour ? "5-hour" : kind == .weekly ? "Weekly" : name ?? "Model quota",
            kind: kind,
            remainingFraction: fraction(remaining["remainingFraction"] ?? raw["remainingFraction"] ?? raw["remaining_fraction"]),
            resetsAt: AntigravityJSON.date(raw["resetTime"] ?? raw["reset_time"] ?? remaining["resetTime"]),
            resetDescription: AntigravityJSON.text(raw["description"])
        )
    }

    private static func fraction(_ raw: Any?) -> Double? {
        guard let number = AntigravityJSON.number(raw), (0...1).contains(number) else { return nil }
        return number
    }

    private static func family(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("gemini") { return "gemini" }
        if lower.contains("claude") || lower.contains("gpt") || lower.contains("3p") { return "claude-gpt" }
        return lower
    }

    private static func familyTitle(_ id: String) -> String {
        id == "gemini" ? "Gemini" : id == "claude-gpt" ? "Claude + GPT" : id
    }

    private static func sorted(_ buckets: [AntigravityQuotaBucket]) -> [AntigravityQuotaBucket] {
        buckets.sorted {
            let lhs = $0.kind == .fiveHour ? 0 : $0.kind == .weekly ? 1 : 2
            let rhs = $1.kind == .fiveHour ? 0 : $1.kind == .weekly ? 1 : 2
            return (lhs, $0.id) < (rhs, $1.id)
        }
    }
}
