import SwiftUI

struct DockWeatherView: View {
    let state: WeatherState
    let animatesChanges: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let shape = RoundedRectangle(
                cornerRadius: side * 0.22,
                style: .continuous
            )
            let palette = WeatherPalette(state: state)

            ZStack {
                shape.fill(
                    LinearGradient(
                        colors: palette.background,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                weatherGlow(palette: palette, side: side)
                    .clipShape(shape)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.28)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(shape)
                .accessibilityHidden(true)

                weatherContent(side: side, palette: palette)

                shape.strokeBorder(
                    .white.opacity(contrast == .increased ? 0.9 : 0.5),
                    lineWidth: contrast == .increased
                        ? max(1.5, side * 0.018)
                        : max(1, side * 0.012)
                )
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .animation(animation, value: state)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weather")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.weather")
    }

    @ViewBuilder
    private func weatherContent(
        side: CGFloat,
        palette: WeatherPalette
    ) -> some View {
        if let snapshot = state.snapshot {
            VStack(spacing: -side * 0.015) {
                Image(systemName: snapshot.condition.symbolName(isDaylight: snapshot.isDaylight))
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: max(10, side * 0.29), weight: .semibold))
                    .foregroundStyle(palette.symbol)
                    .frame(height: side * 0.37)
                    .shadow(color: .black.opacity(0.20), radius: side * 0.025, y: side * 0.012)

                Text(Self.temperatureLabel(snapshot.temperatureCelsius))
                    .font(.system(size: max(11, side * 0.30), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.30), radius: side * 0.025, y: side * 0.012)

                if side >= 78, snapshot.highCelsius != nil || snapshot.lowCelsius != nil {
                    Text(highLowLabel(snapshot))
                        .font(.system(size: max(8, side * 0.085), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.86))
                }
            }
            .padding(.horizontal, side * 0.09)
            .padding(.top, side * 0.05)
        } else {
            VStack(spacing: side * 0.04) {
                Image(systemName: placeholderSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: max(11, side * 0.30), weight: .semibold))
                    .foregroundStyle(palette.symbol)

                Text(placeholderTemperature)
                    .font(.system(size: max(10, side * 0.26), weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    private func weatherGlow(
        palette: WeatherPalette,
        side: CGFloat
    ) -> some View {
        RadialGradient(
            colors: [palette.glow, .clear],
            center: UnitPoint(x: 0.08, y: 0.04),
            startRadius: 0,
            endRadius: side * 0.78
        )
            .accessibilityHidden(true)
    }

    private var placeholderSymbol: String {
        switch state {
        case .loading:
            "cloud.sun.fill"
        case .unavailable:
            "cloud.fill"
        case .idle, .live, .stale:
            "cloud.sun.fill"
        }
    }

    private var placeholderTemperature: String {
        switch state {
        case .loading:
            "…"
        case .idle, .unavailable, .live, .stale:
            "—°"
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .idle:
            "Waiting for location and Open-Meteo weather"
        case .loading:
            "Updating"
        case let .unavailable(message):
            "Unavailable, \(message)"
        case let .live(snapshot):
            snapshotAccessibilityValue(snapshot)
        case let .stale(snapshot, message):
            "Last known weather, \(snapshotAccessibilityValue(snapshot)), \(message)"
        }
    }

    private func snapshotAccessibilityValue(_ snapshot: WeatherSnapshot) -> String {
        var values = [
            snapshot.location,
            Self.accessibleTemperature(snapshot.temperatureCelsius),
            snapshot.conditionDescription
        ]
        if let high = snapshot.highCelsius {
            values.append("high \(Self.accessibleTemperature(high))")
        }
        if let low = snapshot.lowCelsius {
            values.append("low \(Self.accessibleTemperature(low))")
        }
        return values.joined(separator: ", ")
    }

    private func highLowLabel(_ snapshot: WeatherSnapshot) -> String {
        var parts: [String] = []
        if let high = snapshot.highCelsius {
            parts.append("H \(Self.temperatureLabel(high))")
        }
        if let low = snapshot.lowCelsius {
            parts.append("L \(Self.temperatureLabel(low))")
        }
        return parts.joined(separator: "  ")
    }

    private static func temperatureLabel(_ celsius: Double) -> String {
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    private static func accessibleTemperature(_ celsius: Double) -> String {
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        let unit = usesFahrenheit ? "degrees Fahrenheit" : "degrees Celsius"
        return "\(Int(value.rounded())) \(unit)"
    }

    private static var usesFahrenheit: Bool {
        Locale.current.measurementSystem == .us
    }

    private var animation: Animation? {
        guard animatesChanges, !reduceMotion else {
            return nil
        }
        return DSMotion.metricChange
    }
}

private struct WeatherPalette {
    let background: [Color]
    let glow: Color
    let symbol: Color

    init(state: WeatherState) {
        guard let snapshot = state.snapshot else {
            background = [
                Color(red: 0.18, green: 0.29, blue: 0.42),
                Color(red: 0.07, green: 0.12, blue: 0.21)
            ]
            glow = .white.opacity(0.18)
            symbol = .white.opacity(0.84)
            return
        }

        let isNight = snapshot.isDaylight == false
        if isNight {
            background = [
                Color(red: 0.15, green: 0.20, blue: 0.45),
                Color(red: 0.035, green: 0.055, blue: 0.16)
            ]
            glow = Color(red: 0.60, green: 0.72, blue: 1).opacity(0.28)
            symbol = Color(red: 0.87, green: 0.91, blue: 1)
            return
        }

        switch snapshot.condition {
        case .clear, .mostlyClear, .hot:
            background = [
                Color(red: 0.16, green: 0.65, blue: 0.96),
                Color(red: 0.02, green: 0.35, blue: 0.76)
            ]
            glow = Color(red: 1, green: 0.85, blue: 0.34).opacity(0.78)
            symbol = Color(red: 1, green: 0.91, blue: 0.45)
        case .partlyCloudy:
            background = [
                Color(red: 0.26, green: 0.64, blue: 0.89),
                Color(red: 0.15, green: 0.38, blue: 0.67)
            ]
            glow = Color(red: 1, green: 0.86, blue: 0.46).opacity(0.62)
            symbol = .white
        case .cloudy, .fog, .wind, .cold, .unknown:
            background = [
                Color(red: 0.40, green: 0.53, blue: 0.66),
                Color(red: 0.18, green: 0.29, blue: 0.43)
            ]
            glow = .white.opacity(0.32)
            symbol = Color(red: 0.92, green: 0.96, blue: 1)
        case .drizzle, .rain, .sleet:
            background = [
                Color(red: 0.22, green: 0.47, blue: 0.68),
                Color(red: 0.07, green: 0.20, blue: 0.35)
            ]
            glow = Color(red: 0.55, green: 0.83, blue: 1).opacity(0.40)
            symbol = Color(red: 0.72, green: 0.89, blue: 1)
        case .snow:
            background = [
                Color(red: 0.51, green: 0.69, blue: 0.83),
                Color(red: 0.22, green: 0.38, blue: 0.55)
            ]
            glow = .white.opacity(0.66)
            symbol = .white
        case .thunderstorm:
            background = [
                Color(red: 0.24, green: 0.25, blue: 0.51),
                Color(red: 0.065, green: 0.075, blue: 0.18)
            ]
            glow = Color(red: 0.66, green: 0.56, blue: 1).opacity(0.50)
            symbol = Color(red: 1, green: 0.85, blue: 0.34)
        }
    }
}
