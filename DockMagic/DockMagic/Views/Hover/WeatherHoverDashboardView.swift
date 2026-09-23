import AppKit
import SwiftUI

@MainActor
struct WeatherHoverDashboardView: View {
    let state: WeatherState
    let locationPlaceholder: String?
    var now: Date = .now

    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            header

            if let snapshot = state.snapshot {
                currentConditions(snapshot)

                Rectangle()
                    .fill(sceneDivider)
                    .frame(height: 0.5)
                    .accessibilityHidden(true)

                forecastSection(snapshot)
                attribution
            } else {
                unavailableContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weather dashboard")
        .accessibilityIdentifier("dockHover.weather")
    }

    private var header: some View {
        HStack(spacing: 9) {
            Group {
                if let weatherApplicationIcon = Self.weatherApplicationIcon {
                    Image(nsImage: weatherApplicationIcon)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    DSIcon(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.multicolor)
                        .dsFont(size: 23, weight: .semibold)
                }
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Weather")
                    .dsFont(size: 17, weight: .bold)
                    .foregroundStyle(primaryForeground)

                HStack(spacing: 4) {
                    DSIcon(systemName: "mappin.and.ellipse")
                        .symbolRenderingMode(.monochrome)
                        .dsFont(size: 8, weight: .semibold)
                        .accessibilityHidden(true)

                    Text(locationLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .dsFont(size: 9, weight: .medium)
                .foregroundStyle(secondaryForeground)
            }

            Spacer(minLength: 6)

            if let status = statusPresentation {
                HStack(spacing: 3) {
                    DSIcon(systemName: status.systemImage)
                        .symbolRenderingMode(.monochrome)
                        .dsFont(size: 8, weight: .semibold)
                        .accessibilityHidden(true)

                    Text(status.title)
                        .dsFont(size: 8.5, weight: .semibold)
                }
                .foregroundStyle(statusForeground(status))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(height: 40)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dockHover.weather.header")
    }

    private func currentConditions(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                DSIcon(
                    systemName: snapshot.condition.symbolName(
                        isDaylight: snapshot.isDaylight
                    )
                )
                .dsFont(size: 45, weight: .medium)
                .foregroundStyle(
                    snapshot.condition.sceneGlyphColor(
                        isDaylight: snapshot.isDaylight,
                        in: theme,
                        colorScheme: colorScheme
                    )
                )
                .frame(width: 54, height: 58)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(temperatureLabel(snapshot.temperatureCelsius))
                        .dsFont(size: 38, weight: .bold)
                        .foregroundStyle(primaryForeground)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(snapshot.conditionDescription)
                        .dsFont(size: 11, weight: .bold)
                        .foregroundStyle(primaryForeground)
                        .lineLimit(1)

                    if let feelsLike = snapshot.feelsLikeCelsius {
                        Text("Feels like \(temperatureLabel(feelsLike))")
                            .dsFont(size: 9, weight: .medium)
                            .foregroundStyle(secondaryForeground)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current weather")
            .accessibilityValue(currentAccessibilityValue(snapshot))

            Rectangle()
                .fill(sceneDivider)
                .frame(width: 0.5, height: 88)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    todayTemperature(
                        title: "High",
                        value: snapshot.highCelsius
                    )

                    Rectangle()
                        .fill(sceneDivider)
                        .frame(width: 0.5, height: 31)
                        .padding(.horizontal, 9)
                        .accessibilityHidden(true)

                    todayTemperature(
                        title: "Low",
                        value: snapshot.lowCelsius
                    )
                }

                Rectangle()
                    .fill(sceneDivider)
                    .frame(height: 0.5)
                    .accessibilityHidden(true)

                HStack(spacing: 10) {
                    currentMetric(
                        title: "Humidity",
                        value: percentageLabel(snapshot.relativeHumidity),
                        systemImage: "humidity"
                    )

                    currentMetric(
                        title: "Wind",
                        value: windLabel(snapshot.windSpeedKPH),
                        systemImage: "wind"
                    )
                }
            }
            .frame(width: 170)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Today's details")
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .accessibilityIdentifier("dockHover.weather.current")
    }

    private func todayTemperature(
        title: String,
        value: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .dsFont(size: 8.5, weight: .semibold)
                .foregroundStyle(secondaryForeground)

            Text(temperatureLabel(value))
                .dsFont(size: 15, weight: .bold)
                .foregroundStyle(primaryForeground)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func currentMetric(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                DSIcon(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 8, weight: .semibold)
                    .accessibilityHidden(true)

                Text(title)
                    .dsFont(size: 8, weight: .semibold)
            }
            .foregroundStyle(secondaryForeground)

            Text(value)
                .dsFont(size: 11, weight: .bold)
                .foregroundStyle(primaryForeground)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func forecastSection(_ snapshot: WeatherSnapshot) -> some View {
        let days = Array(snapshot.forecast.prefix(7))

        return VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("7-day forecast")
                    .dsFont(size: 11.5, weight: .bold)
                    .foregroundStyle(primaryForeground)

                Text(forecastRangeLabel(days))
                    .dsFont(size: 8.5, weight: .medium)
                    .foregroundStyle(secondaryForeground)

                Spacer(minLength: 4)
            }
            .frame(height: 18)

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    WeatherHoverForecastDay(
                        forecast: day,
                        isToday: Calendar.current.isDate(
                            day.date,
                            inSameDayAs: now
                        ),
                        temperatureLabel: temperatureLabel,
                        percentageLabel: percentageLabel,
                        sceneBackground: snapshot.condition.sceneColor(
                            isDaylight: snapshot.isDaylight,
                            in: theme
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(
                        "dockHover.weather.forecast.day.\(index)"
                    )

                    if index < days.count - 1 {
                        Rectangle()
                            .fill(sceneDivider)
                            .frame(width: 0.5, height: 134)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 138)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("dockHover.weather.forecast")
    }

    @ViewBuilder
    private var unavailableContent: some View {
        VStack(spacing: 9) {
            Spacer(minLength: 24)

            switch state {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)

                Text("Updating weather")
                    .dsFont(size: 13, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Text(
                    locationPlaceholder
                        ?? "Locating you and loading the week ahead."
                )
                .dsFont(size: 10, weight: .medium)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            case let .unavailable(message):
                DSIcon(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 25, weight: .medium)
                    .foregroundStyle(theme.dangerForeground)
                    .accessibilityHidden(true)

                Text("Weather unavailable")
                    .dsFont(size: 13, weight: .bold)
                    .foregroundStyle(theme.textPrimary)

                Text(message)
                    .dsFont(size: 10, weight: .medium)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

            case .live, .stale:
                EmptyView()
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dockHover.weather.unavailable")
    }

    private var attribution: some View {
        HStack(spacing: 4) {
            Text("Weather data by")
                .foregroundStyle(secondaryForeground)

            Link("Open-Meteo", destination: Self.attributionURL)
                .foregroundStyle(primaryForeground)
                .underline()
                .buttonStyle(.plain)
                .accessibilityLabel("Open-Meteo weather data")

            Text("·")
                .foregroundStyle(secondaryForeground)

            Link("CC BY 4.0", destination: Self.licenseURL)
                .foregroundStyle(primaryForeground)
                .underline()
                .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .dsFont(size: 8.5, weight: .medium)
        .frame(height: 14)
        .accessibilityIdentifier("dockHover.weather.attribution")
    }

    private var locationLabel: String {
        state.snapshot?.location
            ?? locationPlaceholder
            ?? "Current location"
    }

    private var primaryForeground: Color {
        state.snapshot == nil ? theme.textPrimary : theme.weatherSceneForeground
    }

    private var secondaryForeground: Color {
        state.snapshot == nil
            ? theme.textTertiary
            : theme.weatherSceneForeground.opacity(0.9)
    }

    private var sceneDivider: Color {
        state.snapshot == nil
            ? theme.outline
            : theme.weatherSceneForeground.opacity(0.32)
    }

    private func statusForeground(_ status: WeatherHoverStatusPresentation) -> Color {
        guard let snapshot = state.snapshot else {
            return status.foreground(theme)
        }
        return ProjectTheme.rendererColor(
            nil,
            automatic: theme.warning,
            on: snapshot.condition.sceneColor(
                isDaylight: snapshot.isDaylight,
                in: theme
            ),
            colorScheme: colorScheme,
            minimumContrast: 4.55
        )
    }

    private var statusPresentation: WeatherHoverStatusPresentation? {
        switch state {
        case .idle, .loading, .live:
            nil
        case .stale:
            WeatherHoverStatusPresentation(
                title: "Saved forecast",
                systemImage: "clock.badge.exclamationmark",
                role: .warning
            )
        case .unavailable:
            WeatherHoverStatusPresentation(
                title: "Unavailable",
                systemImage: "exclamationmark.triangle.fill",
                role: .danger
            )
        }
    }

    private func temperatureLabel(_ celsius: Double?) -> String {
        guard let celsius, celsius.isFinite else { return "—" }
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    private func percentageLabel(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func windLabel(_ kilometersPerHour: Double?) -> String {
        guard let kilometersPerHour, kilometersPerHour.isFinite else { return "—" }
        let value = usesFahrenheit
            ? kilometersPerHour * 0.621_371
            : kilometersPerHour
        let unit = usesFahrenheit ? "mph" : "km/h"
        return "\(Int(value.rounded())) \(unit)"
    }

    private var usesFahrenheit: Bool {
        Locale.current.measurementSystem == .us
    }

    private func forecastRangeLabel(_ days: [DailyWeatherForecast]) -> String {
        guard let first = days.first?.date, let last = days.last?.date else {
            return ""
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day()))–\(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func currentAccessibilityValue(_ snapshot: WeatherSnapshot) -> String {
        var values = [
            temperatureLabel(snapshot.temperatureCelsius),
            snapshot.conditionDescription
        ]
        if let feelsLike = snapshot.feelsLikeCelsius {
            values.append("feels like \(temperatureLabel(feelsLike))")
        }
        return values.joined(separator: ", ")
    }

    private static let attributionURL = URL(string: "https://open-meteo.com/")!
    private static let licenseURL = URL(
        string: "https://open-meteo.com/en/licence"
    )!

    private static let weatherApplicationIcon: NSImage? = {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.weather"
        ) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.isTemplate = false
        return icon
    }()
}

private struct WeatherHoverStatusPresentation {
    let title: String
    let systemImage: String
    let role: DSSemanticRole

    func foreground(_ theme: DesignTheme) -> Color {
        switch role {
        case .warning:
            theme.warningForeground
        case .danger:
            theme.dangerForeground
        case .information:
            theme.informationForeground
        case .processing:
            theme.processingForeground
        case .neutral:
            theme.textSecondary
        }
    }
}

private struct WeatherHoverForecastDay: View {
    let forecast: DailyWeatherForecast
    let isToday: Bool
    let temperatureLabel: (Double?) -> String
    let percentageLabel: (Double?) -> String
    let sceneBackground: Color

    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 5) {
            Text(dateLabel)
                .dsFont(size: 9, weight: isToday ? .bold : .semibold)
                .foregroundStyle(
                    theme.weatherSceneForeground.opacity(isToday ? 1 : 0.9)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 12)

            DSIcon(systemName: forecast.condition.symbolName())
                .dsFont(size: 25, weight: .medium)
                .foregroundStyle(
                    ProjectTheme.rendererColor(
                        nil,
                        automatic: forecast.condition.conditionColor(in: theme),
                        on: sceneBackground,
                        colorScheme: colorScheme,
                        minimumContrast: 3.05
                    )
                )
                .frame(height: 31)
                .accessibilityHidden(true)

            VStack(spacing: 1) {
                Text(temperatureLabel(forecast.highCelsius))
                    .dsFont(size: 14, weight: .bold)
                    .foregroundStyle(theme.weatherSceneForeground)

                Text(temperatureLabel(forecast.lowCelsius))
                    .dsFont(size: 10, weight: .semibold)
                    .foregroundStyle(theme.weatherSceneForeground.opacity(0.9))
            }
            .monospacedDigit()

            HStack(spacing: 2) {
                DSIcon(systemName: "drop")
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 7.5, weight: .semibold)
                    .accessibilityHidden(true)

                Text(percentageLabel(forecast.precipitationChance))
                    .monospacedDigit()
            }
            .dsFont(size: 8, weight: .medium)
            .foregroundStyle(theme.weatherSceneForeground.opacity(0.9))
            .lineLimit(1)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 128)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dateLabel: String {
        if isToday { return "Today" }
        return forecast.date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var accessibilityLabel: String {
        [
            isToday
                ? "Today"
                : forecast.date.formatted(.dateTime.weekday(.wide).month().day()),
            forecast.conditionDescription,
            "high \(temperatureLabel(forecast.highCelsius))",
            "low \(temperatureLabel(forecast.lowCelsius))",
            "precipitation \(percentageLabel(forecast.precipitationChance))"
        ].joined(separator: ", ")
    }
}
