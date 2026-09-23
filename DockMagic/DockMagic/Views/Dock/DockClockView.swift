import SwiftUI

struct DockClockTransition: Equatable, Sendable {
    let previousDate: Date
    let progress: Double

    init(previousDate: Date, progress: Double) {
        self.previousDate = previousDate
        self.progress = min(max(progress, 0), 1)
    }

    var easedProgress: Double {
        progress * progress * (3 - 2 * progress)
    }
}

struct DockClockView: View {
    let date: Date
    let configuration: DockClockConfiguration
    let transition: DockClockTransition?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    init(
        date: Date,
        configuration: DockClockConfiguration,
        transition: DockClockTransition? = nil
    ) {
        self.date = date
        self.configuration = configuration
        self.transition = transition
    }

    var body: some View {
        let values = DockClockValues(
            date: date,
            timeZone: configuration.resolvedTimeZone
        )
        let activeTransition = effectiveTransition
        let previousValues = activeTransition.map {
            DockClockValues(
                date: $0.previousDate,
                timeZone: configuration.resolvedTimeZone
            )
        }
        let progress = activeTransition?.easedProgress ?? 1

        DockClockTileSurface { side in
            switch configuration.displayStyle {
            case .analog:
                DockAnalogClockFace(values: values, side: side)
            case .digital:
                DockDigitalClockFace(
                    values: values,
                    previousValues: previousValues,
                    transitionProgress: progress,
                    side: side
                )
            case .splitFlap:
                DockSplitFlapClockFace(
                    values: values,
                    previousValues: previousValues,
                    transitionProgress: progress,
                    side: side
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clock")
        .accessibilityValue(accessibilityValue(values))
        .accessibilityIdentifier("dock.clock")
    }

    private var effectiveTransition: DockClockTransition? {
        let shouldReduceMotion = accessibilityOverrides.reduceMotion
            ?? reduceMotion
        guard !shouldReduceMotion,
              let transition,
              transition.progress < 1 else {
            return nil
        }
        return transition
    }

    private func accessibilityValue(_ values: DockClockValues) -> String {
        let seconds = configuration.displayStyle == .analog
            ? String(format: ":%02d", values.second)
            : ""
        let location = DockClockFormatting.locationTitle(
            for: configuration.resolvedTimeZone
        )
        let offset = DockClockFormatting.offsetTitle(
            for: configuration.resolvedTimeZone,
            at: date
        )
        return "\(values.hourText):\(values.minuteText)\(seconds), \(location), \(offset), \(configuration.displayStyle.title)"
    }
}

private struct DockClockTileSurface<Content: View>: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides
    @Environment(\.dockTileShowsOuterBorder) private var showsOuterBorder

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
                shape.fill(theme.dockBackgroundInset)
                if showsOuterBorder {
                    shape.strokeBorder(
                        theme.dockOutline,
                        lineWidth: isIncreasedContrast
                            ? max(1.75, side * 0.019)
                            : max(1.25, side * 0.014)
                    )
                }
                content(side)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var isIncreasedContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }
}

private struct DockAnalogClockFace: View {
    let values: DockClockValues
    let side: CGFloat

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let dialRadius = side * 0.355
            let dialRect = CGRect(
                x: center.x - dialRadius,
                y: center.y - dialRadius,
                width: dialRadius * 2,
                height: dialRadius * 2
            )

            context.stroke(
                Path(ellipseIn: dialRect),
                with: .color(theme.dockTrack),
                lineWidth: max(1.5, side * (isIncreasedContrast ? 0.025 : 0.018))
            )

            for marker in 0..<12 {
                let isMajor = marker.isMultiple(of: 3)
                let angle = Double(marker) * .pi / 6 - .pi / 2
                let outerRadius = side * 0.315
                let innerRadius = side * (isMajor ? 0.266 : 0.282)
                var path = Path()
                path.move(to: point(center: center, radius: innerRadius, angle: angle))
                path.addLine(to: point(center: center, radius: outerRadius, angle: angle))
                context.stroke(
                    path,
                    with: .color(isMajor ? theme.dockForeground : theme.dockOutline),
                    style: StrokeStyle(
                        lineWidth: max(1, side * (isMajor ? 0.026 : 0.012)),
                        lineCap: .round
                    )
                )
            }

            drawHand(
                in: &context,
                center: center,
                angle: values.hourAngle,
                length: side * 0.18,
                width: side * 0.046,
                color: theme.dockForeground
            )
            drawHand(
                in: &context,
                center: center,
                angle: values.minuteAngle,
                length: side * 0.265,
                width: side * 0.032,
                color: theme.dockForeground
            )
            drawHand(
                in: &context,
                center: center,
                angle: values.secondAngle,
                length: side * 0.285,
                width: max(1.5, side * 0.011),
                color: theme.action
            )

            let hubRadius = side * 0.035
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - hubRadius,
                        y: center.y - hubRadius,
                        width: hubRadius * 2,
                        height: hubRadius * 2
                    )
                ),
                with: .color(theme.dockForeground)
            )
        }
        .frame(width: side, height: side)
    }

    private var isIncreasedContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }

    private func point(
        center: CGPoint,
        radius: CGFloat,
        angle: Double
    ) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }

    private func drawHand(
        in context: inout GraphicsContext,
        center: CGPoint,
        angle: Double,
        length: CGFloat,
        width: CGFloat,
        color: Color
    ) {
        var path = Path()
        path.move(to: center)
        path.addLine(
            to: point(
                center: center,
                radius: length,
                angle: angle * .pi / 180 - .pi / 2
            )
        )
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}

private struct DockDigitalClockFace: View {
    let values: DockClockValues
    let previousValues: DockClockValues?
    let transitionProgress: Double
    let side: CGFloat

    @Environment(\.designTheme) private var theme

    var body: some View {
        ZStack {
            VStack(spacing: -side * 0.075) {
                digitPair(
                    values.hourText,
                    previousText: previousValues?.hourText
                )
                digitPair(
                    values.minuteText,
                    previousText: previousValues?.minuteText
                )
            }

            VStack(spacing: side * 0.024) {
                Circle()
                Circle()
            }
            .foregroundStyle(theme.action)
            .frame(width: side * 0.034, height: side * 0.085)
        }
        .frame(width: side, height: side)
    }

    private func digitPair(
        _ text: String,
        previousText: String?
    ) -> some View {
        let progress = CGFloat(transitionProgress)

        return ZStack {
            if let previousText, previousText != text {
                digitText(previousText)
                    .offset(y: -side * 0.39 * progress)
                    .opacity(1 - Double(progress))

                digitText(text)
                    .offset(y: side * 0.39 * (1 - progress))
                    .opacity(Double(progress))
            } else {
                digitText(text)
            }
        }
        .frame(width: side * 0.78, height: side * 0.39)
        .clipped()
    }

    private func digitText(_ text: String) -> some View {
        Text(text)
            .dsFont(
                    size: side * 0.36,
                    weight: .heavy,
                    design: .rounded
                )
            .monospacedDigit()
            .foregroundStyle(theme.dockForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: side * 0.78, height: side * 0.39)
    }
}

private struct DockSplitFlapClockFace: View {
    let values: DockClockValues
    let previousValues: DockClockValues?
    let transitionProgress: Double
    let side: CGFloat

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    var body: some View {
        let digits = Array(values.hourText + values.minuteText)
        let previousDigits = previousValues.map {
            Array($0.hourText + $0.minuteText)
        }
        let changedIndices = digits.indices.filter { index in
            previousDigits?[index] != nil
                && previousDigits?[index] != digits[index]
        }
        let spacing = side * 0.035
        let cellSide = (side * 0.76 - spacing) / 2

        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                flapCell(
                    digits[0],
                    previousDigit: previousDigits?[0],
                    animationProgress: localProgress(
                        for: 0,
                        changedIndices: changedIndices
                    ),
                    side: cellSide
                )
                flapCell(
                    digits[1],
                    previousDigit: previousDigits?[1],
                    animationProgress: localProgress(
                        for: 1,
                        changedIndices: changedIndices
                    ),
                    side: cellSide
                )
            }
            HStack(spacing: spacing) {
                flapCell(
                    digits[2],
                    previousDigit: previousDigits?[2],
                    animationProgress: localProgress(
                        for: 2,
                        changedIndices: changedIndices
                    ),
                    side: cellSide
                )
                flapCell(
                    digits[3],
                    previousDigit: previousDigits?[3],
                    animationProgress: localProgress(
                        for: 3,
                        changedIndices: changedIndices
                    ),
                    side: cellSide
                )
            }
        }
        .frame(width: side, height: side)
    }

    private func flapCell(
        _ digit: Character,
        previousDigit: Character?,
        animationProgress: CGFloat?,
        side cellSide: CGFloat
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: cellSide * 0.15,
            style: .continuous
        )

        return ZStack {
            shape.fill(theme.dockBackgroundRaised)
            shape.strokeBorder(
                theme.dockOutline,
                lineWidth: isIncreasedContrast
                    ? max(1.5, cellSide * 0.026)
                    : max(1, cellSide * 0.018)
            )

            if let previousDigit,
               previousDigit != digit,
               let animationProgress {
                animatedFlapDigit(
                    from: previousDigit,
                    to: digit,
                    progress: animationProgress,
                    side: cellSide
                )
            } else {
                digitText(digit, side: cellSide)
            }

            Rectangle()
                .fill(theme.dockOutline)
                .frame(height: max(1, cellSide * 0.018))
        }
        .frame(width: cellSide, height: cellSide)
    }

    private func animatedFlapDigit(
        from previousDigit: Character,
        to digit: Character,
        progress: CGFloat,
        side cellSide: CGFloat
    ) -> some View {
        let firstPhase = min(progress * 2, 1)
        let secondPhase = max((progress - 0.5) * 2, 0)

        return VStack(spacing: 0) {
            ZStack {
                digitHalf(digit, isTop: true, side: cellSide)

                digitHalf(previousDigit, isTop: true, side: cellSide)
                    .rotation3DEffect(
                        .degrees(-90 * Double(firstPhase)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.45
                    )
                    .opacity(firstPhase < 0.999 ? 1 : 0)
            }
            .frame(width: cellSide, height: cellSide / 2)
            .clipped()

            ZStack {
                digitHalf(previousDigit, isTop: false, side: cellSide)

                digitHalf(digit, isTop: false, side: cellSide)
                    .rotation3DEffect(
                        .degrees(90 * Double(1 - secondPhase)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.45
                    )
                    .opacity(secondPhase > 0.001 ? 1 : 0)
            }
            .frame(width: cellSide, height: cellSide / 2)
            .clipped()
        }
        .frame(width: cellSide, height: cellSide)
    }

    private func digitHalf(
        _ digit: Character,
        isTop: Bool,
        side cellSide: CGFloat
    ) -> some View {
        digitText(digit, side: cellSide)
            .offset(y: isTop ? cellSide / 4 : -cellSide / 4)
            .frame(width: cellSide, height: cellSide / 2)
            .clipped()
    }

    private func digitText(
        _ digit: Character,
        side cellSide: CGFloat
    ) -> some View {
        Text(String(digit))
            .dsFont(
                    size: cellSide * 0.72,
                    weight: .heavy,
                    design: .rounded
                )
            .monospacedDigit()
            .foregroundStyle(theme.dockForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(width: cellSide, height: cellSide)
    }

    private func localProgress(
        for index: Int,
        changedIndices: [Int]
    ) -> CGFloat? {
        guard let rank = changedIndices.firstIndex(of: index) else {
            return nil
        }

        let delay = CGFloat(rank) * 0.06
        let progress = CGFloat(transitionProgress)
        return min(max((progress - delay) / (1 - delay), 0), 1)
    }

    private var isIncreasedContrast: Bool {
        accessibilityOverrides.increaseContrast ?? (contrast == .increased)
    }
}

private struct DockClockValues {
    let hour: Int
    let minute: Int
    let second: Int

    init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let components = calendar.dateComponents(
            [.hour, .minute, .second],
            from: date
        )
        hour = components.hour ?? 0
        minute = components.minute ?? 0
        second = components.second ?? 0
    }

    var hourText: String { String(format: "%02d", hour) }
    var minuteText: String { String(format: "%02d", minute) }
    var hourAngle: Double {
        (Double(hour % 12) + Double(minute) / 60 + Double(second) / 3_600) * 30
    }
    var minuteAngle: Double {
        (Double(minute) + Double(second) / 60) * 6
    }
    var secondAngle: Double { Double(second) * 6 }
}
