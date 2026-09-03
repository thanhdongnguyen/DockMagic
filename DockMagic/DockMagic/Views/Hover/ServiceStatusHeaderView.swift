import SwiftUI

struct ServiceStatusHeaderView: View {
    let state: ServiceStatusState

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(statusForeground)
                .accessibilityHidden(true)

            Text(statusTitle)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(statusForeground)
                .lineLimit(1)

            Spacer(minLength: 6)

            Link(destination: state.provider.statusPageURL) {
                HStack(spacing: 3) {
                    Text(state.provider.statusLinkTitle)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 7.5, weight: .bold))
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Open \(state.provider.statusPageURL.absoluteString)")
            .accessibilityIdentifier(
                "serviceStatus.\(state.provider.rawValue).link"
            )
        }
        .frame(maxWidth: .infinity, minHeight: 14)
        .contentShape(Rectangle())
        .help(helpText)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(state.provider.displayName) service status")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(
            "serviceStatus.\(state.provider.rawValue)"
        )
    }

    private var statusTitle: String {
        switch state {
        case .loading:
            return "Checking status"
        case let .unavailable(_, _, lastCheckedAt):
            if let lastCheckedAt {
                return "Status unavailable · checked \(lastCheckedAt.formatted(date: .omitted, time: .shortened))"
            }
            return "Status unavailable"
        case let .live(snapshot):
            return liveTitle(snapshot)
        case let .stale(snapshot, _):
            return "\(liveTitle(snapshot)) · Cached"
        }
    }

    private func liveTitle(_ snapshot: ServiceHealthSnapshot) -> String {
        let severity = switch snapshot.severity {
        case .operational: "Operational"
        case .degraded: "Degraded"
        case .partialOutage: "Partial outage"
        case .majorOutage: "Major outage"
        case .maintenance: "Maintenance"
        }
        guard snapshot.severity.isIncident else { return severity }

        let phase: String? = switch snapshot.phase {
        case .investigating: "Investigating"
        case .identified: "Identified"
        case .monitoring: "Monitoring"
        case .resolved: "Resolved"
        case .unknown: nil
        }
        return [severity, phase].compactMap { $0 }.joined(separator: " · ")
    }

    private var systemImage: String {
        switch state {
        case .loading:
            "ellipsis.circle"
        case .unavailable:
            "questionmark.circle"
        case let .live(snapshot), let .stale(snapshot, _):
            switch snapshot.severity {
            case .operational:
                "checkmark.circle"
            case .maintenance:
                "wrench.and.screwdriver.fill"
            case .degraded, .partialOutage, .majorOutage:
                "exclamationmark.triangle.fill"
            }
        }
    }

    private var statusForeground: Color {
        guard let snapshot = state.snapshot else {
            return theme.textTertiary
        }
        switch snapshot.severity {
        case .majorOutage:
            return theme.dangerForeground
        case .degraded, .partialOutage, .maintenance:
            return theme.warningForeground
        case .operational:
            return theme.textSecondary
        }
    }

    private var helpText: String {
        switch state {
        case let .live(snapshot), let .stale(snapshot, _):
            return snapshot.title ?? statusTitle
        case let .unavailable(_, message, _):
            return message
        case .loading:
            return "DockMagic is checking the official provider status page."
        }
    }

    private var accessibilityValue: String {
        switch state {
        case let .unavailable(_, message, _):
            "\(statusTitle). \(message)"
        case let .live(snapshot), let .stale(snapshot, _):
            [statusTitle, snapshot.title].compactMap { $0 }
                .joined(separator: ". ")
        case .loading:
            statusTitle
        }
    }
}
