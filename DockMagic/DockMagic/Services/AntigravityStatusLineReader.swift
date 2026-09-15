import Foundation

struct AntigravityStatusLineReader: Sendable {
    let sessionsDirectoryURL: URL
    var now: Date = .now

    func readSessions() -> [AntigravitySessionSnapshot] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: sessionsDirectoryURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" && Self.isSessionKey($0.deletingPathExtension().lastPathComponent) }
            .compactMap { url -> (URL, Date)? in
                guard let values = try? url.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                    .contentModificationDateKey
                ]),
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let size = values.fileSize,
                size > 1,
                size <= 128 * 1_024 else {
                    return nil
                }
                return (url, values.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(500)
            .compactMap { decode($0.0) }
            .filter { $0.observedAt <= now.addingTimeInterval(60) }
            .sorted { $0.observedAt > $1.observedAt }
    }

    private func decode(_ url: URL) -> AntigravitySessionSnapshot? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.schemaVersion == 1,
              payload.observedAt > 0 else {
            return nil
        }
        let observedAt = Date(timeIntervalSince1970: payload.observedAt)
        let context = payload.contextWindow.flatMap { raw
            -> AntigravityContextUsage? in
            let value = AntigravityContextUsage(
                totalInputTokens: count(raw.totalInputTokens),
                totalOutputTokens: count(raw.totalOutputTokens),
                contextWindowSize: count(raw.contextWindowSize),
                usedPercent: percent(raw.usedPercentage),
                remainingPercent: percent(raw.remainingPercentage),
                currentInputTokens: count(raw.currentUsage?.inputTokens),
                currentOutputTokens: count(raw.currentUsage?.outputTokens),
                cacheCreationInputTokens: count(
                    raw.currentUsage?.cacheCreationInputTokens
                ),
                cacheReadInputTokens: count(raw.currentUsage?.cacheReadInputTokens)
            )
            let hasValue = value.totalInputTokens != nil
                || value.totalOutputTokens != nil
                || value.contextWindowSize != nil
                || value.usedPercent != nil
                || value.remainingPercent != nil
                || value.currentInputTokens != nil
                || value.currentOutputTokens != nil
                || value.cacheCreationInputTokens != nil
                || value.cacheReadInputTokens != nil
            return hasValue ? value : nil
        }

        return AntigravitySessionSnapshot(
            id: url.deletingPathExtension().lastPathComponent,
            modelID: text(payload.model?.id, limit: 160),
            modelDisplayName: text(payload.model?.displayName, limit: 160),
            cliVersion: text(payload.version, limit: 80),
            planTier: text(payload.planTier, limit: 80),
            agentState: text(payload.agentState, limit: 40),
            executionMode: text(payload.executionMode, limit: 40),
            taskCount: integer(payload.taskCount),
            artifactCount: integer(payload.artifactCount),
            pendingInputCount: integer(payload.pendingInputCount),
            toolConfirmationPending: payload.toolConfirmationPending == true,
            context: context,
            observedAt: observedAt
        )
    }

    private func count(_ value: Int64?) -> Int64? {
        guard let value, (0...1_000_000_000_000).contains(value) else {
            return nil
        }
        return value
    }

    private func integer(_ value: Int?) -> Int? {
        guard let value, (0...1_000_000).contains(value) else { return nil }
        return value
    }

    private func percent(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(max(value, 0), 100)
    }

    private func text(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let clean = value.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        let result = String(String.UnicodeScalarView(clean))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : String(result.prefix(limit))
    }

    private static func isSessionKey(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit }
    }

    private struct Payload: Decodable {
        let schemaVersion: Int
        let observedAt: Double
        let model: Model?
        let version: String?
        let planTier: String?
        let agentState: String?
        let executionMode: String?
        let taskCount: Int?
        let artifactCount: Int?
        let pendingInputCount: Int?
        let toolConfirmationPending: Bool?
        let contextWindow: ContextWindow?

        private enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case observedAt = "observed_at"
            case model
            case version
            case planTier = "plan_tier"
            case agentState = "agent_state"
            case executionMode = "execution_mode"
            case taskCount = "task_count"
            case artifactCount = "artifact_count"
            case pendingInputCount = "pending_input_count"
            case toolConfirmationPending = "tool_confirmation_pending"
            case contextWindow = "context_window"
        }
    }

    private struct Model: Decodable {
        let id: String?
        let displayName: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    private struct ContextWindow: Decodable {
        let totalInputTokens: Int64?
        let totalOutputTokens: Int64?
        let contextWindowSize: Int64?
        let usedPercentage: Double?
        let remainingPercentage: Double?
        let currentUsage: CurrentUsage?

        private enum CodingKeys: String, CodingKey {
            case totalInputTokens = "total_input_tokens"
            case totalOutputTokens = "total_output_tokens"
            case contextWindowSize = "context_window_size"
            case usedPercentage = "used_percentage"
            case remainingPercentage = "remaining_percentage"
            case currentUsage = "current_usage"
        }
    }

    private struct CurrentUsage: Decodable {
        let inputTokens: Int64?
        let outputTokens: Int64?
        let cacheCreationInputTokens: Int64?
        let cacheReadInputTokens: Int64?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }
    }
}
