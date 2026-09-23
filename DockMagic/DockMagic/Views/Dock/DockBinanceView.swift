import SwiftUI

@MainActor
struct DockBinanceView: View {
    let snapshot: BinanceDockSnapshot
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dockTileShowsOuterBorder) private var showsOuterBorder

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            VStack(alignment: .leading, spacing: side * 0.035) {
                HStack(spacing: side * 0.04) {
                    Text(snapshot.base)
                        .dsFont(size: side * 0.12, weight: .bold)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    if snapshot.isStale || snapshot.isUnavailable {
                        DSIcon(systemName: snapshot.isUnavailable ? "exclamationmark.triangle" : "clock")
                            .dsFont(size: side * 0.11, weight: .semibold)
                    }
                }
                .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 0)
                Text(snapshot.prefersCompactPrice || side < 48 ? snapshot.compactPrice : snapshot.price)
                    .dsFont(size: side * 0.32, weight: .bold)
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
                    .foregroundStyle(ProjectTheme.rendererColor(snapshot.priceColor, automatic: theme.textPrimary,
                        on: theme.opaqueSurfaceRaised, colorScheme: colorScheme, minimumContrast: 4.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(snapshot.quote)
                    .dsFont(size: side * 0.09, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Capsule().fill(theme.outlineStrong)
                    .frame(width: side * 0.55, height: side * 0.025)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            .padding(side * 0.12)
            .frame(width: side, height: side)
            .background(theme.opaqueSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.21, style: .continuous))
            .overlay {
                if showsOuterBorder {
                    RoundedRectangle(cornerRadius: side * 0.21, style: .continuous)
                        .strokeBorder(theme.outlineStrong, lineWidth: max(0.5, side * 0.012))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Binance Spot")
        .accessibilityValue(snapshot.accessibilityValue)
        .accessibilityIdentifier("binance.dock")
    }
}
