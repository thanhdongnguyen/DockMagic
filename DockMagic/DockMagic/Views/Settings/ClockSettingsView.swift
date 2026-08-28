import SwiftUI

struct ClockDisplayStylePicker: View {
    @Binding var selection: DockClockDisplayStyle

    var body: some View {
        Picker("Clock style", selection: $selection) {
            ForEach(DockClockDisplayStyle.allCases) { style in
                Text(style.title)
                    .tag(style)
                    .accessibilityIdentifier(
                        "settings.clock.styleOption.\(style.rawValue)"
                    )
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .accessibilityLabel("Clock style")
        .accessibilityValue(selection.title)
        .accessibilityIdentifier("settings.clock.style")
    }
}

@MainActor
struct ClockSettingsView: View {
    let date: Date
    let configuration: DockClockConfiguration
    let isActive: Bool
    let displayStyle: Binding<DockClockDisplayStyle>
    let followsSystemTimeZone: Binding<Bool>
    let timeZoneIdentifier: Binding<String>

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            previewSection
            styleSection
            timeZoneSection

            DSStatusCard(
                title: "Dock-only feature",
                detail: "Clock updates the Dock icon directly and never opens a hover dashboard.",
                systemImage: "dock.rectangle",
                role: .neutral
            )
            .accessibilityIdentifier("settings.clock.noDashboard")
        }
    }

    private var previewSection: some View {
        DSSettingsSection(
            title: "Live Dock preview",
            detail: isActive
                ? "Clock is active. Time and preference changes are applied to the Dock immediately."
                : "Clock is not active, so changes update this preview only."
        ) {
            HStack(spacing: DSSpacing.xLarge) {
                DockClockView(date: date, configuration: configuration)
                    .frame(
                        width: DSLayout.dockPreviewSize,
                        height: DSLayout.dockPreviewSize
                    )
                    .accessibilityIdentifier("settings.clock.dockPreview")

                VStack(spacing: 0) {
                    ClockPreviewValue(
                        title: "Time",
                        value: formattedTime,
                        systemImage: "clock"
                    )
                    DSDivider()
                    ClockPreviewValue(
                        title: "Location",
                        value: locationTitle,
                        systemImage: "location"
                    )
                    DSDivider()
                    ClockPreviewValue(
                        title: "Time zone",
                        value: timeZoneSummary,
                        systemImage: "globe"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var styleSection: some View {
        DSSettingsSection(
            title: "Dock display",
            detail: configuration.displayStyle.detail
        ) {
            ClockDisplayStylePicker(selection: displayStyle)
        }
    }

    private var timeZoneSection: some View {
        DSSettingsSection(
            title: "Location & time zone",
            detail: configuration.followsSystemTimeZone
                ? "Uses the Mac time zone that macOS updates for your current location."
                : "Uses the selected location without changing your Mac's system time zone."
        ) {
            VStack(spacing: DSSpacing.standard) {
                DSSettingsRow(
                    title: "Follow current location",
                    detail: "Uses the Mac's automatic time zone and requires no additional location permission.",
                    systemImage: "location.fill"
                ) {
                    Toggle(
                        "Follow current location",
                        isOn: followsSystemTimeZone
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier(
                        "settings.clock.followSystemTimeZone"
                    )
                }

                if !configuration.followsSystemTimeZone {
                    DSDivider()

                    DSSettingsRow(
                        title: "Location",
                        detail: "Choose a city-based IANA time zone.",
                        systemImage: "mappin.and.ellipse"
                    ) {
                        Picker("Clock location", selection: timeZoneIdentifier) {
                            ForEach(ClockTimeZoneCatalog.options) { option in
                                Text(option.title)
                                    .tag(option.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 280)
                        .accessibilityLabel("Clock location")
                        .accessibilityValue(locationTitle)
                        .accessibilityIdentifier("settings.clock.location")
                    }
                }
            }
        }
    }

    private var timeZone: TimeZone {
        configuration.resolvedTimeZone
    }

    private var formattedTime: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(
            format: "%02d:%02d",
            components.hour ?? 0,
            components.minute ?? 0
        )
    }

    private var locationTitle: String {
        if configuration.followsSystemTimeZone {
            return "Current location · \(DockClockFormatting.locationTitle(for: timeZone))"
        }
        return DockClockFormatting.locationTitle(for: timeZone)
    }

    private var timeZoneSummary: String {
        "\(configuration.effectiveTimeZoneIdentifier) · \(DockClockFormatting.offsetTitle(for: timeZone, at: date))"
    }
}

private struct ClockPreviewValue: View {
    let title: String
    let value: String
    let systemImage: String

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: DSSpacing.standard) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

private struct ClockTimeZoneOption: Identifiable {
    let id: String
    let title: String
}

private enum ClockTimeZoneCatalog {
    static let options: [ClockTimeZoneOption] = TimeZone
        .knownTimeZoneIdentifiers
        .map { identifier in
            let location = DockClockFormatting.locationTitle(for: identifier)
            let region = DockClockFormatting.regionTitle(for: identifier)
            let title = region.map { "\(location) — \($0)" } ?? location
            return ClockTimeZoneOption(id: identifier, title: title)
        }
        .sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
}
