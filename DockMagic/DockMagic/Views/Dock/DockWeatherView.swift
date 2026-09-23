import SwiftUI

struct DockWeatherView: View {
    let state: WeatherState
    let animatesChanges: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dockTileShowsOuterBorder) private var showsOuterBorder

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let shape = RoundedRectangle(
                cornerRadius: side * 0.22,
                style: .continuous
            )

            ZStack {
                shape.fill(
                    state.snapshot.map {
                        $0.condition.sceneColor(
                            isDaylight: $0.isDaylight,
                            in: theme
                        )
                    } ?? theme.dockBackgroundRaised
                )
                if let snapshot = state.snapshot {
                    WeatherSceneBackdrop(
                        condition: snapshot.condition,
                        isDaylight: snapshot.isDaylight
                    )
                    .clipShape(shape)
                }
                weatherContent(side: side)

                if showsOuterBorder {
                    shape.strokeBorder(
                        theme.dockOutline.opacity(contrast == .increased ? 1 : 0.8),
                        lineWidth: contrast == .increased
                            ? max(1.5, side * 0.018)
                            : max(1, side * 0.012)
                    )
                }
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
        side: CGFloat
    ) -> some View {
        if let snapshot = state.snapshot {
            VStack(spacing: -side * 0.015) {
                DSIcon(systemName: snapshot.condition.symbolName(isDaylight: snapshot.isDaylight))
                    .dsFont(size: max(10, side * 0.29), weight: .semibold)
                    .foregroundStyle(
                        snapshot.condition.sceneGlyphColor(
                            isDaylight: snapshot.isDaylight,
                            in: theme,
                            colorScheme: colorScheme
                        )
                    )
                    .frame(height: side * 0.37)

                Text(Self.temperatureLabel(snapshot.temperatureCelsius))
                    .dsFont(size: max(11, side * 0.30), weight: .bold)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(theme.weatherSceneForeground)

                if side >= 78, snapshot.highCelsius != nil || snapshot.lowCelsius != nil {
                    Text(highLowLabel(snapshot))
                        .dsFont(size: max(8, side * 0.085), weight: .semibold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(theme.weatherSceneForeground.opacity(0.9))
                }
            }
            .padding(.horizontal, side * 0.09)
            .padding(.top, side * 0.05)
        } else {
            VStack(spacing: side * 0.04) {
                DSIcon(systemName: placeholderSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .dsFont(size: max(11, side * 0.30), weight: .semibold)
                    .foregroundStyle(theme.dockForeground)

                Text(placeholderTemperature)
                    .dsFont(size: max(10, side * 0.26), weight: .bold)
                    .foregroundStyle(theme.dockForeground)
            }
        }
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
        guard celsius.isFinite else { return "—°" }
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    private static func accessibleTemperature(_ celsius: Double) -> String {
        guard celsius.isFinite else { return "Temperature unavailable" }
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

/// Static vector artwork is subdued over a semantic solid scene color.
/// The scene remains decorative; glyphs and labels carry all weather meaning.
struct WeatherSceneBackdrop: View {
    let condition: WeatherCondition
    let isDaylight: Bool?

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { proxy in
            let role = condition.colorRole(isDaylight: isDaylight)
            ZStack {
                role.sceneColor(in: theme)

                role.sceneArtwork()
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(
                        contrast == .increased || proxy.size.width < 64
                            ? 0.45 : 0.7
                    )
                    .blendMode(.multiply)
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
