import AppKit
import SwiftUI

/// Keeps the native scroller inside a bounded viewport, independent of the
/// intrinsic height of the SwiftUI chart hosted in its document view.
struct DashboardNativeHistoryViewport<ID: Hashable, Content: View>: NSViewRepresentable {
    let latestID: ID?
    let viewportHeight: CGFloat
    let documentSize: CGSize
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> DashboardHistoryScrollView {
        let view = DashboardHistoryScrollView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DashboardHistoryScrollView, context: Context) {
        view.update(
            content: AnyView(
                content()
                    .fixedSize()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .environment(\.self, context.environment)
            ),
            documentSize: documentSize,
            latestID: latestID.map(AnyHashable.init)
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DashboardHistoryScrollView,
                     context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: viewportHeight)
    }
}

final class DashboardHistoryScrollView: NSScrollView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var latestID: AnyHashable?
    private var shouldScrollToLatest = true
    private var previousDocumentWidth: CGFloat = 0
    private var previousViewportWidth: CGFloat = 0
    private var idealDocumentSize: CGSize = .zero

    init() {
        super.init(frame: .zero)
        drawsBackground = false
        borderType = .noBorder
        hasHorizontalScroller = true
        hasVerticalScroller = false
        autohidesScrollers = true
        scrollerStyle = NSScroller.preferredScrollerStyle
        horizontalScrollElasticity = .automatic
        verticalScrollElasticity = .none
        hostingView.sizingOptions = []
        documentView = hostingView
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(content: AnyView, documentSize: CGSize, latestID: AnyHashable?) {
        if self.latestID != latestID {
            self.latestID = latestID
            shouldScrollToLatest = true
        }
        hostingView.rootView = content
        idealDocumentSize = documentSize
        needsLayout = true
    }

    override func layout() {
        let oldOffset = contentView.bounds.minX
        let wasAtLatest = oldOffset >= max(0, previousDocumentWidth - previousViewportWidth) - 1
        super.layout()

        let documentSize = CGSize(
            width: max(contentSize.width, idealDocumentSize.width),
            height: max(contentSize.height, idealDocumentSize.height)
        )
        if hostingView.frame.size != documentSize {
            hostingView.setFrameSize(documentSize)
        }
        let maximumOffset = max(0, documentSize.width - contentSize.width)
        let offset = shouldScrollToLatest || wasAtLatest
            ? maximumOffset : min(maximumOffset, max(0, oldOffset))
        contentView.scroll(to: NSPoint(x: offset, y: 0))
        reflectScrolledClipView(contentView)
        previousDocumentWidth = documentSize.width
        previousViewportWidth = contentSize.width
        shouldScrollToLatest = false
    }
}
