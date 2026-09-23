// Standalone fallback when the Xcode test worker cannot launch:
// swiftc Models/{CalendarAgenda,CalendarWeather,WeatherSnapshot}.swift script/calendar_visual_smoke.swift -o /tmp/calendar-visual-smoke
import Foundation

struct WeatherCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

@main
enum CalendarVisualSmoke {
    static func main() {
        for condition in WeatherCondition.allCases {
            precondition(CalendarWeatherIcon.assetName(for: condition).hasPrefix("CalendarWeather"))
        }
        precondition(CalendarWeatherIcon.assetName(for: .clear, isDaylight: false) == "CalendarWeatherMoon")
        let now = Date()
        func event(_ title: String, _ calendar: String) -> CalendarEvent {
            CalendarEvent(id: title, calendarID: calendar, calendarTitle: calendar,
                title: title, start: now, end: now.addingTimeInterval(3600),
                isAllDay: false, location: nil, meetingURL: nil)
        }
        precondition(CalendarEventVisualCategory.classify(event("Mom's birthday", "Personal")) == .birthday)
        precondition(CalendarEventVisualCategory.classify(event("Day off", "Holidays")) == .holiday)
        precondition(CalendarEventVisualCategory.classify(event("Planning", "Work")) == .work)
        precondition(CalendarEventVisualCategory.classify(event("Coffee", "Personal")) == .regular)
        print("PASS: 14 weather conditions and 4 event categories")
    }
}
