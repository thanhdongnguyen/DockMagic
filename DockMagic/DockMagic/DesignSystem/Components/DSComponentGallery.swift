#if DEBUG
import SwiftUI

/// Debug-only fixture surface. Every control here is the production component.
struct DSComponentGallery: View {
    @State private var mode = DSAppearanceMode.light
    @State private var text = "Tiếng Việt · 1.234 ₫"
    @State private var secret = ""
    @State private var notes = "Nội dung nhiều dòng"
    @State private var enabled = true
    @State private var checked = false
    @State private var value = 0.4
    @State private var selection = "alpha"
    @State private var searchSelection = "ha-noi"
    @State private var radio = "one"
    @State private var segment = "chart"
    @State private var showsDialog = false
    @State private var lastAction = "Ready"
    @State private var increasedContrast = false
    @State private var reducedTransparency = false
    @State private var reducedMotion = false
    @State private var grayscale = false

    init(appearance: DSAppearanceMode? = nil) {
        _mode = State(initialValue: appearance ?? (ProcessInfo.processInfo.environment["DockMagicMaiaAppearance"] == "dark" ? .dark : .light))
    }

    var body: some View {
        DockMagicThemeRoot(content: content, appearanceMode: mode)
            .environment(\.dsAccessibilityOverrides, .init(reduceTransparency: reducedTransparency,
                increaseContrast: increasedContrast, reduceMotion: reducedMotion))
            .saturation(grayscale ? 0 : 1)
            .frame(minWidth: 1060, minHeight: 700)

    }

    private var content: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maia · bbVKHJo").font(DSTypography.headline)
                    Text("Geist / HugeIcons / Neutral").font(DSTypography.metadata)
                }
                Spacer()
                Button("Light") { mode = .light }.accessibilityIdentifier("maia.light")
                Button("Dark") { mode = .dark }.accessibilityIdentifier("maia.dark")
                Text(lastAction).font(DSTypography.metadata).accessibilityIdentifier("maia.lastAction")
            }
            HStack(spacing: 16) {
                Toggle("Increased Contrast", isOn: $increasedContrast)
                Toggle("Reduce Transparency", isOn: $reducedTransparency)
                Toggle("Reduce Motion", isOn: $reducedMotion)
                Toggle("Grayscale", isOn: $grayscale)
            }.toggleStyle(DSCheckboxStyle())
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], alignment: .leading, spacing: 16) {
                    selectionControls
                    form
                    actions
                    dataStates
                    typography
                    iconCatalog
                }
                .padding(4)
            }
        }
        .padding(24)
        .background(ProjectTheme.current.surface)
        .accessibilityIdentifier("maia.gallery")
        .dsAlert("Delete fixture?", isPresented: $showsDialog) {
            DSDialogButton("Cancel", role: .cancel) { lastAction = "Cancelled" }
            DSDialogButton("Delete", role: .destructive) { lastAction = "Deleted" }
        } message: { Text("This only changes the gallery fixture.") }
    }

    private var actions: some View {
        DSSettingsSection(title: "Actions", detail: "Variants, focus, disabled and loading") {
            HStack {
                Button("Primary") { lastAction = "Primary" }.buttonStyle(DSButtonStyle(emphasis: .primary))
                    .accessibilityIdentifier("maia.primary")
                Button("Secondary") {}.buttonStyle(DSButtonStyle(emphasis: .secondary))
                Button("Outline") {}.buttonStyle(DSButtonStyle(emphasis: .outline))
            }
            HStack {
                Button("Ghost") {}.buttonStyle(DSButtonStyle(emphasis: .ghost))
                Button("Link") {}.buttonStyle(DSButtonStyle(emphasis: .link))
                Button("Delete") { showsDialog = true }
                    .buttonStyle(DSButtonStyle(emphasis: .primary, intent: .destructive))
                    .accessibilityIdentifier("maia.dialog")
                Button {} label: { DSIcon(.plus) }.buttonStyle(DSIconButtonStyle())
                    .accessibilityLabel("Add fixture")
            }
            HStack {
                Button("Disabled") { lastAction = "Incorrect disabled action" }.disabled(true)
                    .accessibilityIdentifier("maia.disabled")
                Button {} label: { DSLoadingState(title: "Saving…") }.disabled(true)
                DSMenu {
                    DSMenuButton("Copy fixture") { lastAction = "Copied" }
                    DSMenuButton("Unavailable") {}.disabled(true)
                    Divider()
                    DSMenuButton("Remove", role: .destructive) { lastAction = "Removed" }
                } label: { DSLabel("Actions", icon: .more) }
                .accessibilityIdentifier("maia.menu")
            }
        }
    }

    private var form: some View {
        DSSettingsSection(title: "Fields") {
            DSField(title: "Name", helper: "Native editing, selection, clipboard and undo") {
                DSTextInput(title: "Name", text: $text).accessibilityIdentifier("maia.input")
            }
            DSField(title: "Token", error: secret.isEmpty ? "Enter a token to continue" : nil) {
                DSSecureInput(title: "Token", text: $secret).accessibilityIdentifier("maia.secure")
            }
            DSTextArea(title: "Notes", text: $notes).accessibilityIdentifier("maia.textarea")
        }
    }

    private var selectionControls: some View {
        DSSettingsSection(title: "Selection") {
            DSSegmentedControl(title: "Dock display", selection: $segment, options: [
                .init(value: "chart", title: "Chart", accessibilityIdentifier: "maia.segment.chart"),
                .init(value: "disabled", title: "Unavailable", disabled: true, accessibilityIdentifier: "maia.segment.disabled"),
                .init(value: "numbers", title: "Numbers", accessibilityIdentifier: "maia.segment.numbers")
            ]).accessibilityIdentifier("maia.segment")
            Text(segment).accessibilityIdentifier("maia.segment.value")
            DSSegmentedControl(title: "Disabled selection", selection: .constant("line"), options: [
                .init(value: "line", title: "Line"), .init(value: "candlestick", title: "Candlestick")
            ], size: .small).disabled(true)
            DSSelect(title: "Option", selection: $selection, options: [
                .init(value: "alpha", title: "Alpha"), .init(value: "beta", title: "Beta"),
                .init(value: "disabled", title: "Unavailable", disabled: true)
            ]).accessibilityIdentifier("maia.select")
            DSSelect(title: "City", selection: $searchSelection, options: [
                .init(value: "ha-noi", title: "Hà Nội"), .init(value: "hcm", title: "Hồ Chí Minh"),
                .init(value: "da-nang", title: "Đà Nẵng")
            ], searchable: true).accessibilityIdentifier("maia.searchSelect")
            Toggle("Enable feature", isOn: $enabled).accessibilityIdentifier("maia.switch")
            Toggle("Include details", isOn: $checked).toggleStyle(DSCheckboxStyle())
                .accessibilityIdentifier("maia.checkbox")
            DSSlider(value: $value, in: 0...1, step: 0.1).frame(height: 36)
                .accessibilityLabel("Fixture level").accessibilityIdentifier("maia.slider")
            DSRadioGroup(title: "Density", selection: $radio,
                         options: [.init(value: "one", title: "Default"), .init(value: "two", title: "Small")])
        }
    }

    private var dataStates: some View {
        DSSettingsSection(title: "Data states") {
            HStack {
                DSMetricCard(title: "Measured zero", icon: .chart, state: DSMetricValue.percent(0))
                DSMetricCard(title: "Unknown", icon: .help, state: DSMetricValue.percent(nil))
            }
            DSMetricCard(title: "Partial history", icon: .history,
                         state: .partial(.init(formatted: "12,450", unit: "tokens"), detail: "Some days unavailable"))
            DSMetricCard(title: "Last known value", icon: .clock,
                         state: .failed("Refresh failed", lastValue: .init(formatted: "48%", fraction: 0.48)))
            DSLoadingState()
            DSEmptyState(title: "No observations", detail: "Data appears after activity is reported.")
        }
    }

    private var typography: some View {
        DSSettingsSection(title: "Typography and chart anatomy") {
            Text("Aa · Tiếng Việt · 0123456789 · ₫").font(DSTypography.headline)
            Text("Regular / Medium / SemiBold / Bold").font(DSTypography.body)
            DSChartFrame(title: "Usage", detail: "Fixture · no provider data") {
                DSProgress(value: 0.62, title: "Usage")
                DSChartLegend(title: "Reported usage", color: ProjectTheme.current.action)
                DSChartTooltip { Text("September 17"); Text("62% reported").monospacedDigit() }
            }
        }
    }

    private var iconCatalog: some View {
        DSSettingsSection(title: "Bundled vector icons") {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 10), spacing: 10) {
                ForEach(DSIconName.allCases, id: \.rawValue) { icon in
                    DSIcon(icon, size: 20).help(icon.rawValue).accessibilityLabel(icon.rawValue)
                }
            }
        }
    }
}
#endif
