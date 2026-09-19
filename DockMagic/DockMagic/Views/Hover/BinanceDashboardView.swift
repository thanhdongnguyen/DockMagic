import SwiftUI

@MainActor
struct BinanceDashboardView: View {
    let store: BinanceMarketStore
    var onSettings: () -> Void = {}
    var onInteraction: (Bool) -> Void = { _ in }
    var onClose: () -> Void = {}
    @State private var dashboardID = UUID()
    @State private var query = ""
    @State private var finderOpen = false
    @State private var scrollTarget: String?
    @FocusState private var searchFocused: Bool
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 12) {
            header
            searchBar
            controls
            ScrollViewReader { proxy in
                ScrollView {
                    if finderOpen { finder }
                    else if store.configuration.watchlist.isEmpty { emptyState }
                    else {
                        LazyVStack(spacing: 12) {
                            if let hero = store.selectedSymbol { card(hero, large: true) }
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(store.configuration.displayOrder.dropFirst()) { item in card(item, large: false) }
                            }
                        }
                        .padding(1)
                    }
                }
                .onChange(of: scrollTarget) { _, value in
                    guard let value else { return }
                    proxy.scrollTo(value, anchor: .center)
                }
            }
            footer
        }
        .font(DSTypography.Dashboard.body)
        .foregroundStyle(theme.textPrimary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("binance.dashboard")
        .onAppear { store.acquireDashboard(dashboardID) }
        .onDisappear { store.releaseDashboard(dashboardID); onInteraction(false) }
        .onChange(of: searchFocused) { _, focused in if focused { onInteraction(true) } }
        .onChange(of: query) { _, value in if searchFocused && !value.isEmpty { finderOpen = true } }
        .onExitCommand {
            if finderOpen { dismissFinder() } else { onInteraction(false); onClose() }
        }
    }
    private var header: some View {
        DSDashboardHeader(title: "Binance") {
            BinanceBrandIcon(size: 36)
        } actions: {
            Button(action: onSettings) { DSIcon(systemName: "gearshape") }
                .buttonStyle(DSIconButtonStyle())
                .help("Binance settings").accessibilityLabel("Binance settings")
                .accessibilityIdentifier("binance.settings")
        }
    }
    private var searchBar: some View {
        DSField(title: "Search coins or pairs") {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    DSIcon(systemName: "magnifyingglass").foregroundStyle(theme.textSecondary)
                    TextField("BTC, ETH or BTC/USDT", text: $query)
                        .textFieldStyle(.plain).focused($searchFocused)
                        .font(DSTypography.Dashboard.body)
                        .accessibilityLabel("Search coins or pairs")
                        .accessibilityIdentifier("binance.search")
                        .onSubmit { selectFirstResult() }
                        .simultaneousGesture(TapGesture().onEnded { beginSearch() })
                    if finderOpen {
                        Button { dismissFinder() } label: { DSIcon(systemName: "xmark.circle.fill") }
                            .buttonStyle(DSIconButtonStyle(visualSize: 24, hitSize: 36))
                            .help("Close search").accessibilityLabel("Close search")
                            .accessibilityIdentifier("binance.closeSearch")
                    }
                }
                .modifier(DSInputChrome(isFocused: searchFocused))
                Button { beginSearch() } label: { DSLabel("Add coin", systemImage: "plus").frame(height: 26) }
                    .buttonStyle(DSButtonStyle(emphasis: .primary, surface: .dashboard))
                    .accessibilityIdentifier("binance.add")
            }
        }
    }
    private var controls: some View {
        HStack(spacing: 8) {
            DSSegmentedControl(title: "Time range",
                selection: Binding(get: { store.configuration.timeRange }, set: { value in store.updateConfiguration { $0.timeRange = value } }),
                options: BinanceTimeRange.allCases.map {
                    .init(value: $0, title: $0.rawValue, accessibilityIdentifier: "binance.range.\($0.rawValue)")
                }, size: .small)
                .frame(width: 300)
            Spacer(minLength: 0)
            DSSegmentedControl(title: "Chart type",
                selection: Binding(get: { store.configuration.chartType }, set: { value in store.updateConfiguration { $0.chartType = value } }),
                options: BinanceChartType.allCases.map { .init(value: $0, title: $0.title) }, size: .small)
                .frame(width: 210).accessibilityIdentifier("binance.chartType")
        }
    }
    private func card(_ item: BinanceSymbol, large: Bool) -> some View {
        BinanceCoinCard(item: item, state: store.pairs[item.id] ?? BinancePairState(), configuration: store.configuration,
            large: large, onPin: { store.pin(item.id) }, onMove: { store.move(item.id, by: $0) },
            onRemove: { store.remove(item.id) }, onRetry: { store.retry() })
            .id(item.id)
            .onAppear { store.setVisible(item.id, dashboard: dashboardID, visible: true) }
            .onDisappear { store.setVisible(item.id, dashboard: dashboardID, visible: false) }
    }
    private var finder: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.configuration.watchlist.count >= BinanceConfiguration.maximumPairs {
                Text("20 pairs followed. Remove a pair to add another.").font(DSTypography.Dashboard.metadata).foregroundStyle(theme.textSecondary)
            }
            if let message = store.actionMessage { Text(message).font(DSTypography.Dashboard.metadata).foregroundStyle(theme.warningForeground) }
            resultSection("Following", rows: store.search(query, tracked: true), tracked: true)
            resultSection("Add a pair", rows: store.search(query, tracked: false), tracked: false)
            if store.catalogIsLoading { ProgressView("Loading Binance pairs…").padding(.vertical, 12) }
            if let error = store.catalogError {
                Text(error).font(DSTypography.Dashboard.metadata).foregroundStyle(theme.warningForeground)
                Button("Retry", action: store.retry).buttonStyle(DSButtonStyle(surface: .dashboard))
            } else if !store.catalogIsLoading && store.search(query, tracked: true).isEmpty && store.search(query, tracked: false).isEmpty {
                Text("No matching Spot pairs. Try a symbol such as BTC or BTC/USDT.")
                    .font(DSTypography.Dashboard.body).foregroundStyle(theme.textSecondary).padding(.vertical, 24)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private func resultSection(_ title: String, rows: [BinanceSymbol], tracked: Bool) -> some View {
        if !rows.isEmpty {
            Text(title).font(DSTypography.Dashboard.metadata).foregroundStyle(theme.textSecondary).padding(.top, 8)
            ForEach(rows) { item in
                Button { choose(item, tracked: tracked) } label: {
                    HStack(spacing: 12) {
                        BinanceAssetIcon(asset: item.baseAsset, size: 28)
                        Text(item.pair).font(DSTypography.Dashboard.bodyEmphasis)
                        Spacer()
                        DSLabel(tracked ? "Following" : "Add", systemImage: tracked ? "checkmark" : "plus")
                            .font(DSTypography.Dashboard.metadata).foregroundStyle(theme.textSecondary)
                    }.padding(.horizontal, 12).frame(height: 46)
                        .background(theme.surfaceInset, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }.buttonStyle(DSContentButtonStyle()).accessibilityIdentifier("binance.result.\(item.id)")
                    .disabled(!tracked && store.configuration.watchlist.count >= BinanceConfiguration.maximumPairs)
            }
        }
    }
    private var emptyState: some View {
        VStack(spacing: 16) {
            DSIcon(systemName: "chart.xyaxis.line").dsFont(size: 32).foregroundStyle(theme.textSecondary)
            Text("Add your first coin").font(DSTypography.Dashboard.headline)
            Text("Follow Binance Spot pairs here. Pin a coin to keep its price in your Dock.")
                .font(DSTypography.Dashboard.body).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
            Button("Add coin") { beginSearch() }.buttonStyle(DSButtonStyle(emphasis: .primary, surface: .dashboard))
            if store.catalogIsLoading { ProgressView("Loading pairs…") }
            ForEach(["BTCUSDT", "ETHUSDT", "SOLUSDT"], id: \.self) { symbol in
                if let item = store.catalog.first(where: { $0.id == symbol }) {
                    Button("Add \(item.pair)") { _ = store.add(item) }.buttonStyle(DSButtonStyle(surface: .dashboard))
                }
            }
            if let error = store.catalogError {
                Text(error).font(DSTypography.Dashboard.metadata).foregroundStyle(theme.warningForeground)
                Button("Retry", action: store.retry).buttonStyle(DSButtonStyle(surface: .dashboard))
            }
        }.padding(.vertical, 40).frame(maxWidth: .infinity)
    }
    private var footer: some View {
        VStack(spacing: 10) {
            DSDivider()
            HStack {
                Text(store.lastUpdated.map { "Updated \($0.formatted(date: .omitted, time: .shortened)) · Binance Spot" } ?? "Binance Spot")
                Spacer()
                Text(store.connection.label)
            }.dsFont(size: 11).foregroundStyle(theme.textSecondary)
        }
    }
    private func beginSearch() {
        onInteraction(true)
        finderOpen = true
        DispatchQueue.main.async { searchFocused = true }
    }
    private func dismissFinder() {
        finderOpen = false; searchFocused = false; query = ""; onInteraction(false)
    }
    private func choose(_ item: BinanceSymbol, tracked: Bool) {
        guard tracked || store.add(item) else { return }
        dismissFinder()
        scrollTarget = nil
        DispatchQueue.main.async { scrollTarget = item.id }
    }
    private func selectFirstResult() {
        if let item = store.search(query, tracked: true).first { choose(item, tracked: true) }
        else if let item = store.search(query, tracked: false).first { choose(item, tracked: false) }
    }
}

@MainActor
private struct BinanceCoinCard: View {
    let item: BinanceSymbol
    let state: BinancePairState
    let configuration: BinanceConfiguration
    let large: Bool
    let onPin: () -> Void
    let onMove: (Int) -> Void
    let onRemove: () -> Void
    let onRetry: () -> Void
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                BinanceAssetIcon(asset: item.baseAsset, size: large ? 32 : 26)
                Text(item.pair).dsFont(size: large ? 14 : 12, weight: .semibold).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if large { Text("On Dock").font(DSTypography.Dashboard.caption).foregroundStyle(theme.textSecondary) }
                Button(action: onPin) {
                    DSIcon(systemName: configuration.pinnedSymbol == item.id ? "pin.fill" : "pin")
                }
                .buttonStyle(DSIconButtonStyle(emphasis: configuration.pinnedSymbol == item.id ? .primary : .ghost))
                .accessibilityLabel(configuration.pinnedSymbol == item.id ? "Unpin \(item.pair)" : "Pin \(item.pair) to Dock")
                .help(configuration.pinnedSymbol == item.id ? "Unpin \(item.pair)" : "Pin \(item.pair) to Dock")
                .accessibilityAddTraits(configuration.pinnedSymbol == item.id ? .isSelected : [])
                .accessibilityIdentifier("binance.pin.\(item.id)")
                DSMenu {
                    DSMenuButton("Move up") { onMove(-1) }.disabled(configuration.watchlist.first?.id == item.id)
                    DSMenuButton("Move down") { onMove(1) }.disabled(configuration.watchlist.last?.id == item.id)
                    Divider()
                    DSMenuButton("Remove pair", role: .destructive, action: onRemove)
                } label: {
                    DSIcon(systemName: "ellipsis").foregroundStyle(theme.textSecondary)
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .fixedSize()
                .tint(theme.textSecondary)
                .accessibilityLabel("Manage \(item.pair)").help("Manage \(item.pair)")
                .accessibilityIdentifier("binance.menu.\(item.id)")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(state.ticker.map { BinancePriceFormat.price($0.price) } ?? "—")
                    .dsFont(size: large ? 30 : 24, weight: .bold).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(item.quoteAsset).dsFont(size: 11, weight: .medium).foregroundStyle(theme.textSecondary)
            }
            HStack(spacing: 4) {
                Text(state.ticker.map { "\(BinancePriceFormat.change($0.changePercent)) · 24h" } ?? "Waiting for price")
                if state.quotePhase == .stale { DSLabel("Stale", systemImage: "clock") }
                else if state.chartPhase == .stale { DSLabel("Chart delayed", systemImage: "clock") }
            }.dsFont(size: large ? 12 : 11, weight: .medium).foregroundStyle(theme.textSecondary)
            if state.quotePhase == .unavailable || state.quotePhase == .error {
                Text(state.message ?? "Price unavailable").dsFont(size: 11).foregroundStyle(theme.warningForeground).lineLimit(2)
                Button("Retry", action: onRetry).buttonStyle(DSContentButtonStyle()).dsFont(size: 11)
            }
            chart.frame(height: large ? 136 : 100)
        }
        .padding(large ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(RoundedRectangle(cornerRadius: DSRadius.card), kind: .raised)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("binance.card.\(item.id)")
    }
    @ViewBuilder private var chart: some View {
        if !state.candles.isEmpty {
            BinancePriceChartView(candles: state.candles, type: configuration.chartType, range: configuration.timeRange,
                showsVolume: configuration.showsVolume, compact: !large, appearance: configuration.appearance)
        } else if state.chartPhase == .loading {
            ProgressView("Loading chart…").font(DSTypography.Dashboard.metadata).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Text(state.chartMessage ?? (state.chartPhase == .ready ? "No history for this pair yet." : "Chart unavailable"))
                    .font(DSTypography.Dashboard.metadata).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
                if state.chartPhase != .ready { Button("Retry", action: onRetry).buttonStyle(DSButtonStyle(surface: .dashboard)) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BinanceAssetIcon: View {
    let asset: String
    let size: CGFloat
    @Environment(\.designTheme) private var theme
    var body: some View {
        // exchangeInfo has no logos. Unknown assets retain a truthful ticker
        // identity rather than loading arbitrary images from third parties.
        Group {
            if ["BTC", "ETH", "SOL"].contains(asset) {
                Image("BinanceAsset" + asset).renderingMode(.original).resizable().scaledToFit()
            } else {
                Text(String(asset.prefix(3)))
            .dsFont(size: size * 0.29, weight: .bold)
            .foregroundStyle(theme.textPrimary)
            .frame(width: size, height: size)
            .background(theme.surfaceInset, in: Circle())
            .overlay(Circle().strokeBorder(theme.outline))
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct BinanceBrandIcon: View {
    let size: CGFloat
    var body: some View {
        DSIdentityContainer(size: size) {
            Image("BinanceLogo").renderingMode(.original).resizable().scaledToFit()
        }
    }
}
