import SwiftUI

struct DockNowPlayingView: View {
    let presentation: NowPlayingDockPresentation
    @Environment(\.designTheme) private var theme
    @Environment(\.dockTileShowsOuterBorder) private var showsOuterBorder
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                NowPlayingArtworkView(data: presentation.artworkData)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: side * 0.23, style: .continuous))
            }
            .overlay {
                if showsOuterBorder {
                    RoundedRectangle(cornerRadius: side * 0.23, style: .continuous)
                        .strokeBorder(theme.dockOutline, lineWidth: side * 0.007)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if presentation.canControl {
                    DSIcon(systemName: presentation.state == .playing ? "pause.fill" : "play.fill")
                        .dsFont(size: side * 0.135, weight: .semibold)
                        .foregroundStyle(theme.dockForeground)
                        .frame(width: side * 0.29, height: side * 0.29)
                        .background(theme.dockBackgroundRaised, in: Circle())
                        .overlay(Circle().strokeBorder(theme.dockOutline, lineWidth: side * 0.006))
                        .padding(side * 0.045)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now Playing")
        .accessibilityValue([presentation.state?.title, presentation.title, presentation.source.map { "in \($0.title)" }].compactMap { $0 }.joined(separator: " — "))
    }
}
