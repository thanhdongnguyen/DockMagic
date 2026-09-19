import SwiftUI

struct DockCalendarView: View {
    let date: Date
    let events: [CalendarEvent]
    let configuration: CalendarConfiguration
    let access: CalendarAccess
    var isLoading = false
    var hasError = false
    @Environment(\.designTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            VStack(spacing: side * 0.025) {
                Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                    .dsFont(size: side * 0.095, weight: .bold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: side * 0.18)
                    .background(theme.surfaceInset)

                if configuration.layout == .date {
                    dateNumber(side: side, scale: 0.48)
                        .frame(height: side * 0.55)
                    Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .dsFont(size: side * 0.1, weight: .semibold)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    if configuration.layout != .nextEvent {
                        HStack(alignment: .firstTextBaseline, spacing: side * 0.045) {
                            dateNumber(side: side, scale: 0.27)
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .dsFont(size: side * 0.12, weight: .semibold)
                                .foregroundStyle(theme.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .frame(height: side * 0.27)
                        .padding(.horizontal, side * 0.1)
                    }
                    agenda(side: side)
                }
                Spacer(minLength: side * 0.04)
            }
            .frame(width: side, height: side)
            .background(theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.2))
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.2)
                    .strokeBorder(theme.outlineStrong, lineWidth: max(0.5, side * 0.012))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar, \(date.formatted(date: .complete, time: .omitted))")
        .accessibilityValue(configuration.layout == .date ? "Today's date" : accessibleAgenda)
    }

    private func dateNumber(side: CGFloat, scale: CGFloat) -> some View {
        Text(date.formatted(.dateTime.day()))
            .dsFont(size: side * scale, weight: .bold)
            .monospacedDigit().foregroundStyle(theme.textPrimary)
    }

    @ViewBuilder private func agenda(side: CGFloat) -> some View {
        if access != .fullAccess || hasError || isLoading && events.isEmpty {
            VStack(spacing: side * 0.05) {
                DSIcon(systemName: hasError ? "exclamationmark.triangle" : access == .fullAccess ? "arrow.triangle.2.circlepath" : "lock")
                    .dsFont(size: side * 0.16, weight: .semibold)
                Text(hasError ? "Unavailable" : access == .fullAccess ? "Loading" : "Connect")
                    .dsFont(size: side * 0.1, weight: .semibold)
            }
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if events.isEmpty {
            Text("No more items")
                .dsFont(size: side * 0.12, weight: .medium)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, side * 0.08)
                .frame(maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: side * 0.025) {
                ForEach(Array(events.prefix(configuration.layout == .dateAndAgenda ? 2 : 1))) { event in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.timeLabel(now: date))
                            .dsFont(size: side * 0.075, weight: .semibold)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                        Text(event.title)
                            .dsFont(size: side * (configuration.layout == .nextEvent ? 0.16 : 0.095), weight: .bold)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(configuration.layout == .nextEvent ? 2 : 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, side * 0.09)
        }
    }

    private var accessibleAgenda: String {
        if access != .fullAccess { return access.message }
        if hasError { return "Calendar unavailable" }
        if isLoading && events.isEmpty { return "Loading events" }
        return events.isEmpty ? "No more items today" : events.map { "\($0.title), \($0.timeLabel(now: date))" }.joined(separator: "; ")
    }
}
