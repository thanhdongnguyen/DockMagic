import SwiftUI

struct DockCalendarView: View {
    let date: Date
    let hasItems: Bool
    var currentWeather: CalendarCurrentWeather? = nil
    @Environment(\.designTheme) private var theme
    @Environment(\.dockTileShowsOuterBorder) private var showsOuterBorder

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            VStack(spacing: side * 0.025) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .dsFont(size: side * 0.2, weight: .bold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(currentWeather == nil ? theme.informationForeground : theme.weatherSceneForeground)
                    .padding(.top, side * 0.05)
                    .frame(maxWidth: .infinity)
                    .frame(height: side * 0.23, alignment: .top)
                    .background(currentWeather == nil ? theme.surfaceInset : Color.clear)

                Text(date.formatted(.dateTime.day()))
                    .dsFont(size: side * 0.48, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(currentWeather == nil ? theme.textPrimary : theme.weatherSceneForeground)
                    .frame(height: side * 0.4)
                Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .dsFont(size: side * 0.26, weight: .bold)
                    .lineLimit(1).minimumScaleFactor(0.72)
                    .foregroundStyle(currentWeather == nil ? theme.informationForeground : theme.weatherSceneForeground)
                Spacer(minLength: side * 0.04)
            }
            .frame(width: side, height: side)
            .background {
                if let currentWeather {
                    WeatherSceneBackdrop(condition: currentWeather.condition,
                                         isDaylight: currentWeather.isDaylight)
                } else {
                    theme.surfaceRaised
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: side * 0.2))
            .overlay {
                if showsOuterBorder {
                    RoundedRectangle(cornerRadius: side * 0.2)
                        .strokeBorder(theme.outlineStrong, lineWidth: max(0.5, side * 0.012))
                }
            }
            .overlay(alignment: .topTrailing) {
                if hasItems {
                    Circle()
                        .fill(theme.danger)
                        .overlay {
                            Circle()
                                .strokeBorder(currentWeather == nil ? theme.surfaceRaised : theme.weatherSceneForeground,
                                              lineWidth: max(1, side * 0.015))
                        }
                        .frame(width: max(6, side * 0.15), height: max(6, side * 0.15))
                        .padding(.top, side * 0.075)
                        .padding(.trailing, side * 0.055)
                        .accessibilityHidden(true)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar, \(date.formatted(date: .complete, time: .omitted))")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let agenda = hasItems ? "Today has calendar items." : "Today's date."
        guard let currentWeather else { return agenda }
        return "\(agenda) Current weather: \(currentWeather.conditionDescription)."
    }
}
