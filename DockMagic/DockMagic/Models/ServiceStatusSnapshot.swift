import Foundation

enum ServiceStatusProviderID: String, CaseIterable, Codable, Identifiable,
    Sendable
{
    case codex
    case claudeCode

    var id: Self { self }

    var displayName: String {
        switch self {
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
        }
    }

    var statusLinkTitle: String {
        switch self {
        case .codex:
            "OpenAI status"
        case .claudeCode:
            "Claude status"
        }
    }

    var statusPageURL: URL {
        switch self {
        case .codex:
            URL(string: "https://status.openai.com/")!
        case .claudeCode:
            URL(string: "https://status.claude.com/")!
        }
    }
}

enum ServiceHealthSeverity: String, Codable, Equatable, Sendable {
    case operational
    case degraded
    case partialOutage
    case majorOutage
    case maintenance

    var isIncident: Bool {
        self != .operational
    }

    var rank: Int {
        switch self {
        case .operational:
            0
        case .maintenance:
            1
        case .degraded:
            2
        case .partialOutage:
            3
        case .majorOutage:
            4
        }
    }
}

enum ServiceIncidentPhase: String, Codable, Equatable, Sendable {
    case investigating
    case identified
    case monitoring
    case resolved
    case unknown
}

struct ServiceHealthSnapshot: Codable, Equatable, Sendable {
    let provider: ServiceStatusProviderID
    let severity: ServiceHealthSeverity
    let phase: ServiceIncidentPhase
    let incidentID: String?
    let title: String?
    let incidentURL: URL?
    let fetchedAt: Date
    let updatedAt: Date?

    static func operational(
        provider: ServiceStatusProviderID,
        fetchedAt: Date
    ) -> Self {
        ServiceHealthSnapshot(
            provider: provider,
            severity: .operational,
            phase: .unknown,
            incidentID: nil,
            title: nil,
            incidentURL: nil,
            fetchedAt: fetchedAt,
            updatedAt: nil
        )
    }
}

struct ServiceStatusIncidentSignature: Equatable, Sendable {
    let provider: ServiceStatusProviderID
    let incidentID: String?
    let title: String?
    let severity: ServiceHealthSeverity
}

enum ServiceStatusState: Equatable, Sendable {
    case loading(provider: ServiceStatusProviderID)
    case live(ServiceHealthSnapshot)
    case stale(ServiceHealthSnapshot, message: String)
    case unavailable(
        provider: ServiceStatusProviderID,
        message: String,
        lastCheckedAt: Date?
    )

    static func operational(
        provider: ServiceStatusProviderID,
        fetchedAt: Date = .distantPast
    ) -> Self {
        .live(.operational(provider: provider, fetchedAt: fetchedAt))
    }

    var provider: ServiceStatusProviderID {
        switch self {
        case let .loading(provider), let .unavailable(provider, _, _):
            provider
        case let .live(snapshot), let .stale(snapshot, _):
            snapshot.provider
        }
    }

    var snapshot: ServiceHealthSnapshot? {
        switch self {
        case let .live(snapshot), let .stale(snapshot, _):
            snapshot
        case .loading, .unavailable:
            nil
        }
    }

    var incidentSnapshot: ServiceHealthSnapshot? {
        guard let snapshot, snapshot.severity.isIncident else {
            return nil
        }
        return snapshot
    }

    var incidentSignature: ServiceStatusIncidentSignature? {
        incidentSnapshot.map {
            ServiceStatusIncidentSignature(
                provider: $0.provider,
                incidentID: $0.incidentID,
                title: $0.title,
                severity: $0.severity
            )
        }
    }
}

struct DockServiceStatusTransition: Equatable, Sendable {
    let progress: Double

    init(progress: Double) {
        guard progress.isFinite else {
            self.progress = 1
            return
        }
        self.progress = min(max(progress, 0), 1)
    }
}
