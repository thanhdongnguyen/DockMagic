import SwiftUI

struct NowPlayingArtworkView: View {
    let data: Data?
    @Environment(\.designTheme) private var theme
    var body: some View {
        GeometryReader { proxy in
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
            } else {
                ZStack {
                    theme.opaqueSurfaceInset
                    DSIcon(systemName: "music.note").dsFont(size: min(proxy.size.width, proxy.size.height) * 0.3, weight: .medium)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
