import AppKit
import SwiftUI

@MainActor
struct BinanceSettingsView: View {
    let store: BinanceMarketStore
    let isActive: Bool
    @State private var previewID = UUID()
    @State private var showsDashboard = false
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: DSSpacing.section) {
            DSSettingsSection(title: "Live Dock preview", detail: isActive ? "Binance is active in your Dock." : "Choose Binance as your active feature to show its price in the Dock.") {
                HStack(spacing: DSSpacing.xLarge) {
                    DockTileView(presentation: .binance(snapshot: store.dockSnapshot), animatesChanges: false)
                        .frame(width: DSLayout.dockPreviewSize, height: DSLayout.dockPreviewSize)
                        .accessibilityIdentifier("settings.binance.preview")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(store.selectedSymbol?.pair ?? "Your market, at a glance")
                            .font(DSTypography.panelTitle)
                        Text("Pin a coin in the dashboard to keep its price in your Dock. Without a pin, the first coin is shown.")
                            .font(DSTypography.body).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open dashboard") { showsDashboard = true }
                            .buttonStyle(DSButtonStyle(emphasis: .primary))
                            .accessibilityIdentifier("settings.binance.dashboard")
                    }
                }
            }
            DSSettingsSection(title: "Colors", detail: "Automatic follows the theme. Custom colors affect only the Dock price and chart data.") {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    colorRow("Dock price", keyPath: \.dockPriceColor, automatic: theme.textPrimary, identifier: "dockPrice")
                    DSDivider()
                    colorRow("Price line / candles", keyPath: \.priceSeriesColor, automatic: theme.marketPriceSeries, identifier: "priceSeries")
                    DSDivider()
                    colorRow("Volume", keyPath: \.volumeColor, automatic: theme.textTertiary, identifier: "volume")
                    Text("Colors adjust for readable contrast in Light and Dark. Your saved choice stays the same. Preview chart colors with Open dashboard.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Spacer()
                        Button {
                            store.updateConfiguration { $0.appearance = .standard }
                        } label: { DSLabel("Reset Defaults", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(DSButtonStyle())
                        .disabled(store.configuration.appearance == .standard)
                        .help("Reset only Binance colors to Automatic")
                        .accessibilityIdentifier("settings.binance.resetAppearance")
                    }
                }
            }
            DSSettingsSection(title: "Charts", detail: "Shared by all coins. Dashboard controls update these same settings.") {
                VStack(spacing: 16) {
                    DSSegmentedControl(title: "Chart type", selection: binding(\.chartType),
                        options: BinanceChartType.allCases.map { .init(value: $0, title: $0.title) })
                    .accessibilityIdentifier("settings.binance.chartType")
                    DSDivider()
                    DSSelect(title: "Time range", selection: binding(\.timeRange),
                             options: BinanceTimeRange.allCases.map { .init(value: $0, title: $0.rawValue) }).accessibilityIdentifier("settings.binance.range")
                    DSDivider()
                    Toggle("Show volume", isOn: binding(\.showsVolume)).accessibilityIdentifier("settings.binance.volume")
                    Text("Volume is in the base asset. Hollow candles rise; filled candles fall. The percentage beside each price always measures 24 hours.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            DSSettingsSection(title: "Market data", detail: "Public Binance Spot prices. No account or API key required.") {
                VStack(alignment: .leading, spacing: 16) {
                    DSSelect(title: "Preferred quote", selection: binding(\.preferredQuote),
                             options: store.quoteAssets.map { .init(value: $0, title: $0) }, searchable: true)
                    Text("Prioritizes search results when adding coins. Existing pairs keep their quote asset; USDT prices are not USD prices.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(DSTypography.body)
        .foregroundStyle(theme.textPrimary)
        .onAppear { store.setPreview(previewID, visible: true) }
        .onDisappear { store.setPreview(previewID, visible: false) }
        .dsDialog(isPresented: $showsDashboard) {
            VStack(spacing: 12) {
                BinanceDashboardView(store: store, onSettings: { showsDashboard = false }, onClose: { showsDashboard = false })
                HStack { Spacer(); Button("Done") { showsDashboard = false } }
            }
            .padding(20)
            .frame(width: min(620, (NSScreen.main?.visibleFrame.width ?? 720) - 80),
                   height: min(740, max(400, (NSScreen.main?.visibleFrame.height ?? 840) - 100)))
            .background(theme.opaqueSurface)
        }
    }
    private func colorRow(_ title: String, keyPath: WritableKeyPath<BinanceAppearance, DockColor?>,
                          automatic: Color, identifier: String) -> some View {
        let custom = store.configuration.appearance[keyPath: keyPath]
        let selected = custom ?? ProjectTheme.resolvedColor(automatic, colorScheme: colorScheme)
        return VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack {
                Text(title).font(DSTypography.bodyEmphasis)
                Spacer()
                Text(custom == nil ? "Automatic" : "Custom · \(selected.hex)")
                    .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.binance.color.\(identifier).mode")
            }
            DSColorPalettePicker(
                selection: Binding(get: { selected.color }, set: { color in
                    // Clicking the already-selected Automatic swatch must not
                    // freeze a theme-dependent default into a custom value.
                    if custom == nil, DockColor(color).hex == selected.hex { return }
                    store.updateConfiguration { $0.appearance[keyPath: keyPath] = DockColor(color) }
                }),
                selectionHex: selected.hex,
                options: ProjectTheme.rendererColorOptions,
                accessibilityLabel: "Binance \(title) color",
                identifier: "settings.binance.color.\(identifier)",
                currentColorTitle: custom == nil ? "Automatic" : "Current custom color"
            )
        }
    }
    private func binding<Value>(_ keyPath: WritableKeyPath<BinanceConfiguration, Value>) -> Binding<Value> {
        Binding(get: { store.configuration[keyPath: keyPath] }, set: { value in store.updateConfiguration { $0[keyPath: keyPath] = value } })
    }
}
