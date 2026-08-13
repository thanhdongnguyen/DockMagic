import SwiftUI

struct DockTileView: View {
    let presentation: DockTilePresentation
    let animatesChanges: Bool

    var body: some View {
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
        case let .codex(state, appearance):
            DockCodexView(
                state: state,
                appearance: appearance,
                animatesChanges: animatesChanges
            )
        case let .claudeCode(state, appearance):
            DockClaudeCodeView(
                state: state,
                appearance: appearance,
                animatesChanges: animatesChanges
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
    let animatesChanges: Bool

    var body: some View {
        DockUsageLimitView(
            state: state,
            appearance: appearance,
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
    let animatesChanges: Bool

    var body: some View {
        DockUsageLimitView(
            state: state,
            appearance: appearance,
            animatesChanges: animatesChanges,
            showsStateSymbol: false,
            accessibilityLabel: "Claude Code usage remaining",
            accessibilityIdentifier: "dock.claudeCode"
        )
    }
}

private struct DockUsageLimitView: View {
    let state: CodexUsageState
    let appearance: DockRingAppearance
    let animatesChanges: Bool
    let showsStateSymbol: Bool
    let accessibilityLabel: String
    let accessibilityIdentifier: String

    @ViewBuilder
    var body: some View {
        if appearance.displayStyle == .numeric {
            DockNumericTileView(values: numericValues)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(accessibilityValue)
                .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            DockRingTileView(
                outerRing: outerRing,
                innerRing: innerRing,
                stateSymbol: showsStateSymbol ? stateSymbol : nil,
                stateRole: stateRole,
                animatesChanges: animatesChanges
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private var numericValues: [DockNumericValue] {
        guard let snapshot = state.snapshot else {
            return [
                DockNumericValue(
                    label: "5H",
                    value: "—",
                    color: appearance.outerColor.color
                ),
                DockNumericValue(
                    label: "7D",
                    value: "—",
                    color: appearance.innerColor.color
                )
            ]
        }

        var values: [DockNumericValue] = []
        if let fiveHour = snapshot.fiveHour {
            values.append(
                DockNumericValue(
                    label: "5H",
                    value: percentage(fiveHour.remainingFraction),
                    color: appearance.outerColor.color
                )
            )
        }
        if let weekly = snapshot.weekly {
            values.append(
                DockNumericValue(
                    label: "7D",
                    value: percentage(weekly.remainingFraction),
                    color: appearance.innerColor.color
                )
            )
        }
        return values
    }

    private var outerRing: DockRingDescriptor? {
        guard let snapshot = state.snapshot else {
            return placeholderOuterRing
        }

        if let fiveHour = snapshot.fiveHour {
            return DockRingDescriptor(
                progress: fiveHour.remainingFraction,
                color: appearance.outerColor.color,
                width: appearance.outerWidth
            )
        }

        if let weekly = snapshot.weekly {
            return DockRingDescriptor(
                progress: weekly.remainingFraction,
                color: appearance.innerColor.color,
                width: appearance.innerWidth,
                usesSingleRingLayout: true
            )
        }

        return placeholderOuterRing
    }

    private var innerRing: DockRingDescriptor? {
        guard
            let snapshot = state.snapshot,
            snapshot.fiveHour != nil,
            let weekly = snapshot.weekly
        else {
            return state.snapshot == nil ? placeholderInnerRing : nil
        }

        return DockRingDescriptor(
            progress: weekly.remainingFraction,
            color: appearance.innerColor.color,
            width: appearance.innerWidth
        )
    }

    private var placeholderOuterRing: DockRingDescriptor {
        DockRingDescriptor(
            progress: nil,
            color: appearance.outerColor.color,
            width: appearance.outerWidth
        )
    }

    private var placeholderInnerRing: DockRingDescriptor {
        DockRingDescriptor(
            progress: nil,
            color: appearance.innerColor.color,
            width: appearance.innerWidth
        )
    }

    private var stateSymbol: String? {
        switch state {
        case .idle, .loading, .live:
            nil
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
        switch state {
        case .idle:
            "Not connected"
        case .loading:
            "Loading"
        case let .unavailable(message):
            "Unavailable, \(message)"
        case let .live(snapshot):
            quotaDescription(snapshot)
        case let .stale(snapshot, message):
            "Last known values, \(quotaDescription(snapshot)), \(message)"
        }
    }

    private func quotaDescription(_ snapshot: CodexRateLimitSnapshot) -> String {
        var values: [String] = []
        if let fiveHour = snapshot.fiveHour {
            values.append("5-hour \(percentage(fiveHour.remainingFraction))")
        }
        if let weekly = snapshot.weekly {
            values.append("weekly \(percentage(weekly.remainingFraction))")
        }
        return values.joined(separator: ", ")
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
                                contrast == .increased ? 1 : 0.88
                            ),
                            theme.dockOutline.opacity(
                                contrast == .increased ? 0.82 : 0.58
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: contrast == .increased
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
    let label: String
    let value: String
    let color: Color
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
                        Text(value.label)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    contrast == .increased
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
