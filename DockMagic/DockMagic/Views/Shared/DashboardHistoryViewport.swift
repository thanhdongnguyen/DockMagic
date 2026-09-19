import AppKit
import SwiftUI

private struct DashboardCaptureKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isDashboardCapture: Bool {
        get { self[DashboardCaptureKey.self] }
        set { self[DashboardCaptureKey.self] = newValue }
    }
}

/// Export the same trailing chart viewport without a native scroll view or an
/// onAppear callback, neither of which is available to SwiftUI ImageRenderer.
struct DashboardHistoryViewport<ID: Hashable, Content: View>: View {
    let latestID: ID?
    var viewportHeight: CGFloat? = nil
    var documentSize: CGSize? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.isDashboardCapture) private var isDashboardCapture

    var body: some View {
        if isDashboardCapture {
            GeometryReader { geometry in
                content()
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .topTrailing
                    )
            }
            .clipped()
        } else if let viewportHeight, let documentSize {
            DashboardNativeHistoryViewport(
                latestID: latestID,
                viewportHeight: viewportHeight,
                documentSize: documentSize,
                content: content
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    content()
                }
                .onAppear {
                    scrollToLatest(using: proxy)
                }
                .onChange(of: latestID) { _, _ in
                    scrollToLatest(using: proxy)
                }
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let latestID else { return }
        proxy.scrollTo(latestID, anchor: .trailing)
    }
}
