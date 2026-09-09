import SwiftUI

/// Shared Living Flame renderer for Codex and Claude Code. The score is the
/// source of truth for rank so a live score update can never keep stale motion.
struct ShipMomentumGauge: View {
    let score: Int?
    let rank: CodexShipRank?
    let accent: Color
    let animationTime: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.isDashboardCapture) private var isDashboardCapture
    @Environment(\.designTheme) private var theme
    @State private var animatedFraction = 0.0
    @State private var burstEnergy: CGFloat = 0
    @State private var animationEpoch = Date.now

    init(
        score: Int?,
        rank: CodexShipRank?,
        accent: Color,
        animationTime: TimeInterval? = nil
    ) {
        self.score = score
        self.rank = rank
        self.accent = accent
        self.animationTime = animationTime
    }

    private var dynamics: ShipMomentumGaugeDynamics {
        ShipMomentumGaugeDynamics.resolve(
            score: score,
            fallbackRank: rank
        )
    }

    private var targetFraction: Double {
        Double(min(max(score ?? 0, 0), 100)) / 100
    }

    private var effectivelyReducesMotion: Bool {
        isDashboardCapture || (accessibilityOverrides.reduceMotion ?? reduceMotion)
    }

    private var animatesContinuously: Bool {
        score != nil
            && !effectivelyReducesMotion
            && animationTime == nil
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1 / 60,
                paused: !animatesContinuously
            )
        ) { context in
            let time = resolvedAnimationTime(at: context.date)

            GeometryReader { proxy in
                gaugeContent(
                    in: CGRect(origin: .zero, size: proxy.size),
                    time: time
                )
            }
        }
        .onAppear {
            animationEpoch = .now
            updateFraction(initial: true)
            triggerRankBurst()
        }
        .onChange(of: score) { _, _ in
            updateFraction(initial: false)
        }
        .onChange(of: dynamics.rank) { oldRank, newRank in
            guard oldRank != newRank else { return }
            animationEpoch = .now
            triggerRankBurst()
        }
        .onChange(of: effectivelyReducesMotion) { _, isReduced in
            if isReduced {
                animatedFraction = targetFraction
                burstEnergy = 0
            } else {
                animationEpoch = .now
                triggerRankBurst()
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func gaugeContent(in rect: CGRect, time: TimeInterval) -> some View {
        // ImageRenderer does not run onAppear or the entry animation. A PNG
        // must show the settled score rather than the initial empty gauge.
        let fraction = isDashboardCapture
            ? targetFraction
            : min(max(animatedFraction, 0), 1)
        let endpoint = ShipMomentumGaugeGeometry.point(
            in: rect,
            fraction: fraction
        )
        let pulse = effectivelyReducesMotion
            ? 1
            : 1 + dynamics.endpointPulse * CGFloat(
                (sin(time * dynamics.pulseRate * 2 * .pi) + 1) / 2
            )

        ZStack(alignment: .bottom) {
            ZStack {
                ShipMomentumGaugeArcShape(fraction: 1)
                    .stroke(
                        theme.dockTrack,
                        style: StrokeStyle(
                            lineWidth: dynamics.trackLineWidth,
                            lineCap: .round
                        )
                    )

                if score != nil {
                    ShipMomentumGaugeArcShape(fraction: fraction)
                        .stroke(
                            accent,
                            style: StrokeStyle(
                                lineWidth: dynamics.activeLineWidth,
                                lineCap: .round
                            )
                        )

                    ShipMomentumFlameShape(
                        fraction: fraction,
                        dynamics: dynamics,
                        time: time,
                        burstEnergy: burstEnergy
                    )
                    .fill(accent)

                    ShipMomentumFlameCrestShape(
                        fraction: fraction,
                        dynamics: dynamics,
                        time: time,
                        burstEnergy: burstEnergy
                    )
                    .stroke(
                        theme.textPrimary.opacity(
                            dynamics.crestHighlightOpacity
                        ),
                        style: StrokeStyle(
                            lineWidth: dynamics.crestLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                    if dynamics.showsEchoContour {
                        ShipMomentumFlameCrestShape(
                            fraction: fraction,
                            dynamics: dynamics,
                            time: time - 0.085,
                            burstEnergy: burstEnergy,
                            radialOffset: 1.15
                        )
                        .stroke(
                            theme.outlineStrong,
                            style: StrokeStyle(
                                lineWidth: 0.65,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }

                    ShipMomentumEmbers(
                        fraction: fraction,
                        dynamics: dynamics,
                        time: time,
                        burstEnergy: burstEnergy,
                        accent: accent
                    )

                    if dynamics.motionMode != .breathing {
                        Circle()
                            .stroke(
                                theme.textPrimary.opacity(
                                    0.20 + Double(burstEnergy) * 0.25
                                ),
                                lineWidth: 0.75
                            )
                            .frame(
                                width: dynamics.endpointDiameter
                                    + 3 + burstEnergy * 5,
                                height: dynamics.endpointDiameter
                                    + 3 + burstEnergy * 5
                            )
                            .position(endpoint)
                    }

                    Circle()
                        .fill(theme.opaqueSurfaceInset)
                        .overlay {
                            Circle().stroke(accent, lineWidth: 2)
                        }
                        .frame(
                            width: dynamics.endpointDiameter * pulse,
                            height: dynamics.endpointDiameter * pulse
                        )
                        .position(endpoint)
                }
            }
            .scaleEffect(
                x: 1,
                y: 1 + burstEnergy * (dynamics.rankBurstScale - 1),
                anchor: .bottom
            )

            Text(score.map(String.init) ?? "—")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .padding(.horizontal, 4)
                .background(theme.opaqueSurfaceInset)
                .offset(y: 2)
        }
    }

    private func resolvedAnimationTime(at date: Date) -> TimeInterval {
        if effectivelyReducesMotion {
            return dynamics.staticTime
        }
        if let animationTime {
            return animationTime
        }
        return max(0, date.timeIntervalSince(animationEpoch))
    }

    private func updateFraction(initial: Bool) {
        if animationTime != nil {
            animatedFraction = targetFraction
            return
        }
        guard !effectivelyReducesMotion else {
            animatedFraction = targetFraction
            return
        }

        if initial {
            animatedFraction = 0
        }
        withAnimation(DSMotion.metricChange) {
            animatedFraction = targetFraction
        }
    }

    private func triggerRankBurst() {
        guard !effectivelyReducesMotion, score != nil else {
            burstEnergy = 0
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            burstEnergy = 1
        }

        Task { @MainActor in
            withAnimation(.easeOut(duration: dynamics.rankBurstDuration)) {
                burstEnergy = 0
            }
        }
    }
}

enum ShipMomentumMotionMode: Int, Equatable, Sendable {
    case breathing
    case directional
    case burst
}

struct ShipMomentumGaugeProfile: Equatable, Sendable {
    let motionMode: ShipMomentumMotionMode
    let crestCount: Int
    let flameAmplitude: CGFloat
    let activeLineWidth: CGFloat
    let trackLineWidth: CGFloat
    let endpointDiameter: CGFloat
    let endpointPulse: CGFloat
    let pulseRate: Double
    let emberCount: Int
    let travelSpeed: Double
    let breathingRate: Double
    let breathingDepth: Double
    let flickerDepth: Double
    let crestHighlightOpacity: Double
    let crestLineWidth: CGFloat
    let staticTime: Double
    let showsEchoContour: Bool
    let rankBurstScale: CGFloat
    let rankBurstDuration: Double

    static func profile(for rank: CodexShipRank) -> Self {
        switch rank {
        case .starter:
            Self(
                motionMode: .breathing,
                crestCount: 1,
                flameAmplitude: 0.8,
                activeLineWidth: 6.1,
                trackLineWidth: 6.6,
                endpointDiameter: 7,
                endpointPulse: 0.018,
                pulseRate: 0.55,
                emberCount: 0,
                travelSpeed: 0,
                breathingRate: 0.48,
                breathingDepth: 0.055,
                flickerDepth: 0.018,
                crestHighlightOpacity: 0.18,
                crestLineWidth: 0.45,
                staticTime: 0.18,
                showsEchoContour: false,
                rankBurstScale: 1.015,
                rankBurstDuration: 0.24
            )
        case .builder:
            Self(
                motionMode: .breathing,
                crestCount: 3,
                flameAmplitude: 2.0,
                activeLineWidth: 6.3,
                trackLineWidth: 6.6,
                endpointDiameter: 7.4,
                endpointPulse: 0.026,
                pulseRate: 0.62,
                emberCount: 0,
                travelSpeed: 0,
                breathingRate: 0.58,
                breathingDepth: 0.075,
                flickerDepth: 0.028,
                crestHighlightOpacity: 0.26,
                crestLineWidth: 0.5,
                staticTime: 0.24,
                showsEchoContour: false,
                rankBurstScale: 1.028,
                rankBurstDuration: 0.27
            )
        case .creator:
            Self(
                motionMode: .breathing,
                crestCount: 4,
                flameAmplitude: 3.4,
                activeLineWidth: 6.5,
                trackLineWidth: 6.6,
                endpointDiameter: 7.8,
                endpointPulse: 0.036,
                pulseRate: 0.72,
                emberCount: 0,
                travelSpeed: 0,
                breathingRate: 0.70,
                breathingDepth: 0.095,
                flickerDepth: 0.050,
                crestHighlightOpacity: 0.34,
                crestLineWidth: 0.55,
                staticTime: 0.30,
                showsEchoContour: false,
                rankBurstScale: 1.045,
                rankBurstDuration: 0.31
            )
        case .shipper:
            Self(
                motionMode: .directional,
                crestCount: 6,
                flameAmplitude: 5.2,
                activeLineWidth: 6.8,
                trackLineWidth: 6.6,
                endpointDiameter: 8.4,
                endpointPulse: 0.058,
                pulseRate: 0.88,
                emberCount: 0,
                travelSpeed: 0.82,
                breathingRate: 0.82,
                breathingDepth: 0.12,
                flickerDepth: 0.075,
                crestHighlightOpacity: 0.44,
                crestLineWidth: 0.62,
                staticTime: 0.36,
                showsEchoContour: false,
                rankBurstScale: 1.07,
                rankBurstDuration: 0.36
            )
        case .shipmaster:
            Self(
                motionMode: .directional,
                crestCount: 8,
                flameAmplitude: 6.3,
                activeLineWidth: 7.2,
                trackLineWidth: 6.6,
                endpointDiameter: 9,
                endpointPulse: 0.078,
                pulseRate: 1.02,
                emberCount: 2,
                travelSpeed: 1.12,
                breathingRate: 0.96,
                breathingDepth: 0.15,
                flickerDepth: 0.11,
                crestHighlightOpacity: 0.56,
                crestLineWidth: 0.72,
                staticTime: 0.42,
                showsEchoContour: true,
                rankBurstScale: 1.10,
                rankBurstDuration: 0.42
            )
        case .legend:
            Self(
                motionMode: .burst,
                crestCount: 11,
                flameAmplitude: 7.4,
                activeLineWidth: 7.7,
                trackLineWidth: 6.6,
                endpointDiameter: 9.6,
                endpointPulse: 0.10,
                pulseRate: 1.18,
                emberCount: 7,
                travelSpeed: 1.48,
                breathingRate: 1.12,
                breathingDepth: 0.18,
                flickerDepth: 0.16,
                crestHighlightOpacity: 0.68,
                crestLineWidth: 0.82,
                staticTime: 0.48,
                showsEchoContour: true,
                rankBurstScale: 1.14,
                rankBurstDuration: 0.50
            )
        }
    }
}

struct ShipMomentumGaugeDynamics: Equatable, Sendable {
    let score: Int?
    let rank: CodexShipRank
    let tierProgress: Double
    let profile: ShipMomentumGaugeProfile

    var motionMode: ShipMomentumMotionMode { profile.motionMode }
    var crestCount: Int { profile.crestCount }
    var activeLineWidth: CGFloat { profile.activeLineWidth }
    var trackLineWidth: CGFloat { profile.trackLineWidth }
    var endpointDiameter: CGFloat { profile.endpointDiameter }
    var endpointPulse: CGFloat { profile.endpointPulse }
    var pulseRate: Double { profile.pulseRate }
    var emberCount: Int { profile.emberCount }
    var breathingRate: Double { profile.breathingRate }
    var breathingDepth: Double { profile.breathingDepth }
    var flickerDepth: Double { profile.flickerDepth }
    var crestHighlightOpacity: Double { profile.crestHighlightOpacity }
    var crestLineWidth: CGFloat { profile.crestLineWidth }
    var staticTime: Double { profile.staticTime }
    var showsEchoContour: Bool { profile.showsEchoContour }
    var rankBurstScale: CGFloat { profile.rankBurstScale }
    var rankBurstDuration: Double { profile.rankBurstDuration }

    var flameAmplitude: CGFloat {
        profile.flameAmplitude * CGFloat(0.92 + tierProgress * 0.12)
    }

    var travelSpeed: Double {
        profile.travelSpeed * (0.94 + tierProgress * 0.12)
    }

    static func resolve(
        score: Int?,
        fallbackRank: CodexShipRank?
    ) -> Self {
        let clampedScore = score.map { min(max($0, 0), 100) }
        let resolvedRank = clampedScore.map(CodexShipRank.rank(for:))
            ?? fallbackRank
            ?? .starter
        let profile = ShipMomentumGaugeProfile.profile(for: resolvedRank)
        return Self(
            score: clampedScore,
            rank: resolvedRank,
            tierProgress: tierProgress(
                score: clampedScore,
                rank: resolvedRank
            ),
            profile: profile
        )
    }

    private static func tierProgress(
        score: Int?,
        rank: CodexShipRank
    ) -> Double {
        guard let score else { return 0 }
        let range: ClosedRange<Int> = switch rank {
        case .starter: 0...9
        case .builder: 10...29
        case .creator: 30...49
        case .shipper: 50...69
        case .shipmaster: 70...89
        case .legend: 90...100
        }
        guard range.upperBound > range.lowerBound else { return 1 }
        return Double(score - range.lowerBound)
            / Double(range.upperBound - range.lowerBound)
    }
}

private enum ShipMomentumGaugeGeometry {
    static func center(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.maxY - 4)
    }

    static func radius(in rect: CGRect) -> CGFloat {
        max(1, min(rect.width / 2 - 8, rect.height - 16))
    }

    static func point(
        in rect: CGRect,
        fraction: Double,
        radialOffset: CGFloat = 0
    ) -> CGPoint {
        let clamped = min(max(fraction, 0), 1)
        let center = center(in: rect)
        let radius = radius(in: rect) + radialOffset
        let angle = Double.pi * (1 - clamped)
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y - CGFloat(sin(angle)) * radius
        )
    }
}

private struct ShipMomentumGaugeArcShape: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return Path() }
        let segments = max(1, Int(128 * clamped))
        var path = Path()

        for step in 0...segments {
            let progress = clamped * Double(step) / Double(segments)
            let point = ShipMomentumGaugeGeometry.point(
                in: rect,
                fraction: progress
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct ShipMomentumFlameShape: Shape {
    let fraction: Double
    let dynamics: ShipMomentumGaugeDynamics
    let time: TimeInterval
    let burstEnergy: CGFloat

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return Path() }
        let segments = max(10, Int(180 * clamped))
        let outerBase = dynamics.activeLineWidth * 0.22
        let innerBase = -dynamics.activeLineWidth * 0.52
        var path = Path()

        for step in 0...segments {
            let progress = clamped * Double(step) / Double(segments)
            let local = Double(step) / Double(segments)
            let point = ShipMomentumGaugeGeometry.point(
                in: rect,
                fraction: progress,
                radialOffset: outerBase
                    + 0.55
                    + ShipMomentumFlameMath.height(
                        at: local,
                        dynamics: dynamics,
                        time: time,
                        burstEnergy: burstEnergy
                    )
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        for step in stride(from: segments, through: 0, by: -1) {
            let progress = clamped * Double(step) / Double(segments)
            path.addLine(
                to: ShipMomentumGaugeGeometry.point(
                    in: rect,
                    fraction: progress,
                    radialOffset: innerBase
                )
            )
        }
        path.closeSubpath()
        return path
    }
}

private struct ShipMomentumFlameCrestShape: Shape {
    let fraction: Double
    let dynamics: ShipMomentumGaugeDynamics
    let time: TimeInterval
    let burstEnergy: CGFloat
    var radialOffset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return Path() }
        let segments = max(10, Int(180 * clamped))
        let outerBase = dynamics.activeLineWidth * 0.22
        var path = Path()

        for step in 0...segments {
            let progress = clamped * Double(step) / Double(segments)
            let local = Double(step) / Double(segments)
            let point = ShipMomentumGaugeGeometry.point(
                in: rect,
                fraction: progress,
                radialOffset: outerBase
                    + 0.55
                    + radialOffset
                    + ShipMomentumFlameMath.height(
                        at: local,
                        dynamics: dynamics,
                        time: time,
                        burstEnergy: burstEnergy
                    )
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private enum ShipMomentumFlameMath {
    static func height(
        at progress: Double,
        dynamics: ShipMomentumGaugeDynamics,
        time: TimeInterval,
        burstEnergy: CGFloat
    ) -> CGFloat {
        let travel = travelOffset(dynamics: dynamics, time: time)
        let crestCount = Double(dynamics.crestCount)
        let primary = pulse(
            progress * crestCount - travel,
            peak: 0.30
        )
        let crestIndex = floor(progress * crestCount - travel)
        let crestVariation = 0.78 + 0.22 * sin(
            (crestIndex + Double(dynamics.rank.rawValue) * 0.37) * 2.399
        )
        let shoulder = pulse(
            progress * Double(dynamics.crestCount + 2)
                - travel * 0.68 + 0.41,
            peak: 0.38
        ) * 0.24
        let detail = pulse(
            progress * Double(dynamics.crestCount * 2 + 1)
                + travel * 0.24 + 0.73,
            peak: 0.24
        ) * 0.09
        let pointedCrest = min(
            1.12,
            primary * crestVariation + shoulder + detail
        )
        let edgeEnvelope = min(
            1,
            max(0.22, min(progress, 1 - progress) * 11 + 0.22)
        )
        let breathing = 1 + dynamics.breathingDepth * sin(
            time * dynamics.breathingRate * 2 * .pi
                + progress * .pi
        )
        let flicker = 1 + dynamics.flickerDepth * sin(
            time * (dynamics.breathingRate * 2.3) * 2 * .pi
                + progress * 17.0
        )
        let legendSurge: Double
        if dynamics.motionMode == .burst {
            let surge = max(
                0,
                sin(time * 0.78 * 2 * .pi - progress * 2.1)
            )
            legendSurge = 1 + pow(surge, 5) * 0.20
        } else {
            legendSurge = 1
        }
        let rankBurst = 1 + Double(burstEnergy) * 0.22
        let value = Double(dynamics.flameAmplitude)
            * pointedCrest
            * edgeEnvelope
            * breathing
            * flicker
            * legendSurge
            * rankBurst
        return CGFloat(max(0, value))
    }

    private static func travelOffset(
        dynamics: ShipMomentumGaugeDynamics,
        time: TimeInterval
    ) -> Double {
        switch dynamics.motionMode {
        case .breathing:
            0
        case .directional:
            time * dynamics.travelSpeed
        case .burst:
            time * dynamics.travelSpeed
                + sin(time * 0.9 * 2 * .pi) * 0.045
        }
    }

    private static func pulse(_ value: Double, peak: Double) -> Double {
        let unit = value - floor(value)
        if unit <= peak {
            let rise = max(0, unit / peak)
            return pow(sin(rise * .pi / 2), 1.65)
        }
        let fall = max(0, (unit - peak) / (1 - peak))
        return pow(cos(fall * .pi / 2), 2.10)
    }
}

private struct ShipMomentumEmbers: View {
    let fraction: Double
    let dynamics: ShipMomentumGaugeDynamics
    let time: TimeInterval
    let burstEnergy: CGFloat
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            ForEach(0..<dynamics.emberCount, id: \.self) { index in
                let seed = Double(index) * 0.173
                let age = positiveModulo(
                    time * (0.46 + Double(index % 3) * 0.055) + seed
                )
                let progress = max(
                    0,
                    fraction
                        - 0.018
                        - Double(index) * 0.012
                        + sin(time * 1.7 + Double(index)) * 0.004
                )
                let point = ShipMomentumGaugeGeometry.point(
                    in: rect,
                    fraction: progress,
                    radialOffset: dynamics.activeLineWidth / 2
                        + dynamics.flameAmplitude * 0.55
                        + 2
                        + CGFloat(age) * CGFloat(6 + index % 3 * 2)
                )
                let side = CGFloat(1.6 + Double(index % 2) * 0.65)

                Capsule(style: .continuous)
                    .fill(accent)
                    .frame(width: side, height: side * 1.45)
                    .rotationEffect(.degrees(38 + Double(index % 3) * 8))
                    .scaleEffect(1 + burstEnergy * 0.22)
                    .opacity(max(0.18, 1 - age * 0.78))
                    .position(point)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func positiveModulo(_ value: Double) -> Double {
        value - floor(value)
    }
}
