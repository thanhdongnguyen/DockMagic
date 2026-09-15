import SwiftUI

struct DockTileView: View {
    let presentation: DockTilePresentation
    let animatesChanges: Bool
    let clockTransition: DockClockTransition?
    let serviceStatusTransition: DockServiceStatusTransition?

    init(
        presentation: DockTilePresentation,
        animatesChanges: Bool,
        clockTransition: DockClockTransition? = nil,
        serviceStatusTransition: DockServiceStatusTransition? = nil
    ) {
        self.presentation = presentation
        self.animatesChanges = animatesChanges
        self.clockTransition = clockTransition
        self.serviceStatusTransition = serviceStatusTransition
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let contentSide = side * DockIconRenderingRules.contentFraction

            tileContent
                .frame(width: contentSide, height: contentSide)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var tileContent: some View {
        switch presentation {
        case .dockMagic:
            DockMagicLogoView()
        case let .systemMetrics(snapshot, appearance, errorDescription):
            DockMetricsView(
                snapshot: snapshot,
                appearance: appearance,
                errorDescription: errorDescription,
                animatesChanges: animatesChanges
            )
        case let .network(history, appearance, errorDescription):
            DockNetworkView(
                history: history,
                appearance: appearance,
                errorDescription: errorDescription
            )
        case let .storage(snapshot, appearance, errorDescription):
            DockStorageView(
                snapshot: snapshot,
                appearance: appearance,
                errorDescription: errorDescription,
                animatesChanges: animatesChanges
            )
        case let .weather(state):
            DockWeatherView(
                state: state,
                animatesChanges: animatesChanges
            )
        case let .clock(date, configuration):
            DockClockView(
                date: date,
                configuration: configuration,
                transition: clockTransition
            )
        case let .batteries(snapshot, errorDescription):
            DockBatteryView(
                snapshot: snapshot,
                errorDescription: errorDescription,
                animatesChanges: animatesChanges
            )
        case let .github(history, appearance, errorDescription):
            DockGitHubView(
                history: history,
                appearance: appearance,
                errorDescription: errorDescription
            )
        case let .codex(state, appearance, serviceStatus):
            DockCodexView(
                state: state,
                appearance: appearance,
                serviceStatus: serviceStatus,
                serviceStatusTransition: serviceStatusTransition,
                animatesChanges: animatesChanges
            )
        case let .claudeCode(state, appearance, serviceStatus):
            DockClaudeCodeView(
                state: state,
                appearance: appearance,
                serviceStatus: serviceStatus,
                serviceStatusTransition: serviceStatusTransition,
                animatesChanges: animatesChanges
            )
        case let .antigravity(state, appearance):
            DockAntigravityView(
                state: state,
                appearance: appearance,
                animatesChanges: animatesChanges
            )
        case let .searchConsole(state, configuration):
            DockSearchConsoleView(
                state: state,
                configuration: configuration
            )
        }
    }
}

struct DockMagicLogoView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            Image("DockMagicLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: side * 0.22,
                        style: .continuous
                    )
                )
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height / 2
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DockMagic")
        .accessibilityIdentifier("dock.dockMagic")
    }
}

struct DockMetricsView: View {
    let snapshot: SystemMetricsSnapshot
    let appearance: DockRingAppearance
    let errorDescription: String?
    let animatesChanges: Bool

    init(
        snapshot: SystemMetricsSnapshot,
        appearance: DockRingAppearance = DockFeatureDefaults.systemMetricsAppearance,
        errorDescription: String? = nil,
        animatesChanges: Bool = true
    ) {
        self.snapshot = snapshot
        self.appearance = appearance
        self.errorDescription = errorDescription
        self.animatesChanges = animatesChanges
    }

    @ViewBuilder
    var body: some View {
        if appearance.displayStyle == .numeric {
            DockNumericTileView(
                values: [
                    DockNumericValue(
                        label: "CPU",
                        value: percentage(snapshot.cpuUsage),
                        color: appearance.outerColor.color
                    ),
                    DockNumericValue(
                        label: "RAM",
                        value: percentage(snapshot.memoryUsage),
                        color: appearance.innerColor.color
                    )
                ]
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("System usage")
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("dock.metrics")
        } else {
            DockRingTileView(
                outerRing: DockRingDescriptor(
                    progress: snapshot.cpuUsage,
                    color: appearance.outerColor.color,
                    width: appearance.outerWidth
                ),
                innerRing: DockRingDescriptor(
                    progress: snapshot.memoryUsage,
                    color: appearance.innerColor.color,
                    width: appearance.innerWidth
                ),
                stateSymbol: errorDescription == nil
                    ? nil
                    : "exclamationmark.triangle.fill",
                stateRole: .danger,
                animatesChanges: animatesChanges
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("System usage")
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("dock.metrics")
        }
    }

    private var accessibilityValue: String {
        var value = "CPU \(percentage(snapshot.cpuUsage)), RAM \(percentage(snapshot.memoryUsage))"
        if let errorDescription {
            value += ", last update error: \(errorDescription)"
        }
        return value
    }
}

struct DockCodexView: View {
    let state: CodexUsageState
    let appearance: DockRingAppearance
    var serviceStatus: ServiceStatusState = .operational(provider: .codex)
    var serviceStatusTransition: DockServiceStatusTransition? = nil
    let animatesChanges: Bool

    var body: some View {
        DockUsageLimitView(
            state: state,
            metrics: UsageQuotaPresentation.codex(state.snapshot),
            appearance: appearance,
            serviceStatus: serviceStatus,
            serviceStatusTransition: serviceStatusTransition,
            animatesChanges: animatesChanges,
            showsStateSymbol: true,
            accessibilityLabel: "Codex usage remaining",
            accessibilityIdentifier: "dock.codex"
        )
    }
}

struct DockClaudeCodeView: View {
    let state: ClaudeCodeUsageState
    let appearance: DockRingAppearance
    var serviceStatus: ServiceStatusState = .operational(
        provider: .claudeCode
    )
    var serviceStatusTransition: DockServiceStatusTransition? = nil
    let animatesChanges: Bool

    var body: some View {
        DockUsageLimitView(
            state: state,
            metrics: UsageQuotaPresentation.codex(state.snapshot),
            appearance: appearance,
            serviceStatus: serviceStatus,
            serviceStatusTransition: serviceStatusTransition,
            animatesChanges: animatesChanges,
            showsStateSymbol: false,
            accessibilityLabel: "Claude Code usage remaining",
            accessibilityIdentifier: "dock.claudeCode",
            usesWindowPlaceholders: true
        )
    }
}

struct DockUsageLimitView: View {
    @Environment(\.designTheme) private var theme
    let state: CodexUsageState
    let metrics: [UsageQuotaMetric]
    let appearance: DockRingAppearance
    let serviceStatus: ServiceStatusState
    let serviceStatusTransition: DockServiceStatusTransition?
    let animatesChanges: Bool
    let showsStateSymbol: Bool
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    var usesWindowPlaceholders = false

    @ViewBuilder
    var body: some View {
        ZStack {
            if appearance.displayStyle == .numeric {
                DockUsageNumericTileView(values: numericValues)
            } else {
                DockRingTileView(
                    outerRing: outerRing,
                    innerRing: innerRing,
                    stateSymbol: showsStateSymbol ? stateSymbol : nil,
                    stateRole: stateRole,
                    animatesChanges: animatesChanges
                )
            }

            if let incident = serviceStatus.incidentSnapshot {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    DockServiceStatusBeacon(
                        severity: incident.severity,
                        transition: serviceStatusTransition,
                        side: side
                    )
                    .position(x: side * 0.82, y: side * 0.18)
                }
                .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var numericValues: [DockNumericValue] {
        let resolved = Array(metrics.prefix(2))
        guard !resolved.isEmpty else {
            if usesWindowPlaceholders {
                return [
                    DockNumericValue(label: "5H", value: "—", color: appearance.outerColor.color),
                    DockNumericValue(label: "7D", value: "—", color: appearance.innerColor.color)
                ]
            }
            return [
                DockNumericValue(
                    label: "QUOTA",
                    value: "—",
                    color: theme.dockOutline
                )
            ]
        }
        return resolved.map { metric in
            DockNumericValue(
                label: metric.shortLabel,
                value: metric.remainingFraction.map(percentage) ?? "—",
                color: metric.usesSecondaryAppearance
                    ? appearance.innerColor.color
                    : appearance.outerColor.color
            )
        }
    }

    private var outerRing: DockRingDescriptor? {
        guard let metric = metrics.first else {
            return usesWindowPlaceholders ? DockRingDescriptor(
                progress: nil, color: appearance.outerColor.color, width: appearance.outerWidth
            ) : nil
        }
        return DockRingDescriptor(
            progress: metric.remainingFraction,
            color: metric.usesSecondaryAppearance ? appearance.innerColor.color : appearance.outerColor.color,
            width: metric.usesSecondaryAppearance ? appearance.innerWidth : appearance.outerWidth,
            usesSingleRingLayout: metrics.count == 1
                && (!usesWindowPlaceholders || metric.usesSecondaryAppearance)
        )
    }

    private var innerRing: DockRingDescriptor? {
        guard let metric = metrics.dropFirst().first else {
            return usesWindowPlaceholders && state.snapshot == nil ? DockRingDescriptor(
                progress: nil, color: appearance.innerColor.color, width: appearance.innerWidth
            ) : nil
        }
        return DockRingDescriptor(
            progress: metric.remainingFraction,
            color: appearance.innerColor.color,
            width: appearance.innerWidth
        )
    }

    private var stateSymbol: String? {
        switch state {
        case .idle, .loading:
            nil
        case .live:
            metrics.isEmpty ? "questionmark" : nil
        case .stale:
            "clock.badge.exclamationmark"
        case .unavailable:
            "exclamationmark.triangle.fill"
        }
    }

    private var stateRole: DSSemanticRole {
        switch state {
        case .idle, .loading:
            .neutral
        case .live:
            .processing
        case .stale:
            .warning
        case .unavailable:
            .danger
        }
    }

    private var accessibilityValue: String {
        let usageValue = switch state {
        case .idle:
            "Not connected"
        case .loading:
            "Loading"
        case let .unavailable(message):
            "Unavailable, \(message)"
        case .live:
            quotaDescription
        case let .stale(_, message):
            "Last known values, \(quotaDescription), \(message)"
        }
        guard let incident = serviceStatus.incidentSnapshot else {
            return usageValue
        }
        return "\(usageValue), \(incident.provider.displayName) service \(incident.severity.accessibilityLabel)"
    }

    private var quotaDescription: String {
        let values = metrics.compactMap { metric in
            metric.remainingFraction.map {
                "\(metric.title) \(percentage($0))"
            }
        }
        return values.isEmpty
            ? "Usage limits unavailable"
            : values.joined(separator: ", ")
    }
}

private struct DockServiceStatusBeacon: View {
    let severity: ServiceHealthSeverity
    let transition: DockServiceStatusTransition?
    let side: CGFloat

    @Environment(\.designTheme) private var theme

    var body: some View {
        let iconSize = max(8, side * 0.125)
        let containerSize = max(14, side * 0.19)

        ZStack {
            if let transition {
                Image(systemName: "exclamationmark.triangle")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(statusColor)
                    .scaleEffect(1 + 1.7 * transition.progress)
                    .opacity(echoOpacity(for: transition.progress))
            }

            Circle()
                .fill(theme.dockBackgroundInset)
                .frame(width: containerSize, height: containerSize)

            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: iconSize, weight: .black))
                .foregroundStyle(statusColor)
                .scaleEffect(badgeScale)
        }
        .frame(width: containerSize, height: containerSize)
    }

    private var statusColor: Color {
        switch severity {
        case .majorOutage:
            theme.dangerForeground
        case .degraded, .partialOutage, .maintenance:
            theme.warningForeground
        case .operational:
            theme.dockOutline
        }
    }

    private var badgeScale: CGFloat {
        guard let progress = transition?.progress else { return 1 }
        return 0.7 + 1.35 * CGFloat(progress)
    }

    private func echoOpacity(for progress: Double) -> Double {
        min(0.88, 0.18 + progress * 0.7)
    }
}

private extension ServiceHealthSeverity {
    var accessibilityLabel: String {
        switch self {
        case .operational: "operational"
        case .degraded: "degraded"
        case .partialOutage: "partial outage"
        case .majorOutage: "major outage"
        case .maintenance: "under maintenance"
        }
    }
}

struct DockRingDescriptor {
    let progress: Double?
    let color: Color
    let width: Double
    var usesSingleRingLayout = false
}

struct DockTileSurface<Content: View>: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    private var increasedContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }

    private let content: (CGFloat) -> Content

    init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let shape = RoundedRectangle(
                cornerRadius: side * 0.22,
                style: .continuous
            )

            ZStack {
                shape.fill(
                    LinearGradient(
                        colors: [
                            theme.dockBackgroundRaised,
                            theme.dockBackgroundInset
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            theme.dockOutline.opacity(
                                increasedContrast ? 1 : 0.88
                            ),
                            theme.dockOutline.opacity(
                                increasedContrast ? 0.82 : 0.58
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: increasedContrast
                        ? max(1.5, side * 0.018)
                        : max(1.25, side * 0.014)
                )

                content(side)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct DockNumericValue {
    let label: String?
    let value: String
    let color: Color
}

struct DockUsageNumericTileView: View {
    let values: [DockNumericValue]

    @Environment(\.designTheme) private var theme

    var body: some View {
        DockTileSurface { side in
            let usesSingleValueLayout = values.count == 1
            // A weekly-only tile can use the full vertical space. Two-window
            // tiles stay compact enough for `5H 100%` and `7D 100%` to fit.
            let fontSize = side * (usesSingleValueLayout ? 0.20 : 0.17)
            let horizontalPadding = side * (usesSingleValueLayout ? 0.04 : 0.06)

            VStack(spacing: max(1, side * 0.03)) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    if let label = value.label {
                        if usesSingleValueLayout && label.count > 3 {
                            VStack(spacing: side * 0.03) {
                                Text(label)
                                    .font(.system(size: side * 0.12, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.dockOutline)
                                Text(value.value)
                                    .font(.system(size: side * 0.30, weight: .bold, design: .rounded))
                                    .foregroundStyle(value.color)
                                    .monospacedDigit()
                            }
                        } else {
                            (
                                Text(label)
                                    .foregroundColor(theme.dockOutline)
                                + Text(" \(value.value)")
                                    .foregroundColor(value.color)
                            )
                            .font(
                                .system(
                                    size: fontSize,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                            .lineLimit(1)
                        }
                    } else {
                        Text(value.value)
                            .font(
                                .system(
                                    size: fontSize,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                            .lineLimit(1)
                            .foregroundColor(value.color)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
        }
    }
}

struct DockNumericTileView: View {
    let values: [DockNumericValue]

    @Environment(\.designTheme) private var theme

    var body: some View {
        DockTileSurface { side in
            let fontSize = max(8, side * 0.215)

            VStack(spacing: max(1, side * 0.035)) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    HStack(alignment: .firstTextBaseline, spacing: side * 0.045) {
                        if let label = value.label {
                            Text(label)
                                .font(
                                    .system(
                                        size: fontSize,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .foregroundStyle(theme.dockOutline)
                                .frame(width: side * 0.29, alignment: .trailing)
                        }

                        Text(value.value)
                            .font(
                                .system(
                                    size: fontSize,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                            .foregroundStyle(value.color)
                            .frame(
                                maxWidth: .infinity,
                                alignment: value.label == nil ? .center : .leading
                            )
                    }
                }
            }
            .padding(.horizontal, side * 0.09)
        }
    }
}

struct DockRingTileView: View {
    let outerRing: DockRingDescriptor?
    let innerRing: DockRingDescriptor?
    let stateSymbol: String?
    let stateRole: DSSemanticRole
    let animatesChanges: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    private var increasedContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }

    private enum Layout {
        static let outerDiameter: CGFloat = 0.86
        static let innerDiameter: CGFloat = 0.52
        static let singleDiameter: CGFloat = 0.72
        static let minimumLineWidth: CGFloat = 3
    }

    var body: some View {
        DockTileSurface { side in
            ZStack {
                if let outerRing {
                    ring(outerRing, side: side)
                        .frame(
                            width: side * diameter(for: outerRing, isOuter: true),
                            height: side * diameter(for: outerRing, isOuter: true)
                        )
                }

                if let innerRing {
                    ring(innerRing, side: side)
                        .frame(
                            width: side * Layout.innerDiameter,
                            height: side * Layout.innerDiameter
                        )
                }

                if let stateSymbol {
                    Image(systemName: stateSymbol)
                        .font(.system(size: max(8, side * 0.12), weight: .bold))
                        .foregroundStyle(theme.color(for: stateRole) ?? theme.dockOutline)
                        .padding(max(3, side * 0.035))
                        .background {
                            Circle().fill(theme.dockBackgroundInset.opacity(0.9))
                        }
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func ring(
        _ descriptor: DockRingDescriptor,
        side: CGFloat
    ) -> some View {
        let lineWidth = max(
            Layout.minimumLineWidth,
            side * CGFloat(descriptor.width)
        )

        return ZStack {
            Circle()
                .stroke(
                    increasedContrast
                        ? theme.dockOutline
                        : theme.dockTrack,
                    lineWidth: lineWidth
                )

            if let progress = descriptor.progress {
                let progress = normalized(progress)
                if progress >= 1 {
                    Circle().stroke(descriptor.color, lineWidth: lineWidth)
                } else if progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            descriptor.color,
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .animation(animation, value: descriptor.progress)
    }

    private func diameter(
        for descriptor: DockRingDescriptor,
        isOuter: Bool
    ) -> CGFloat {
        if descriptor.usesSingleRingLayout {
            return Layout.singleDiameter
        }
        return isOuter ? Layout.outerDiameter : Layout.innerDiameter
    }

    private var animation: Animation? {
        guard animatesChanges, !reduceMotion else {
            return nil
        }
        return DSMotion.metricChange
    }

    private func normalized(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 1)
    }
}

private func percentage(_ value: Double) -> String {
    min(max(value, 0), 1).formatted(
        .percent.precision(.fractionLength(0))
    )
}
