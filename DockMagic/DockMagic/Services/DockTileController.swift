import AppKit

@MainActor
protocol ApplicationIconDisplaying: AnyObject {
    var applicationIconImage: NSImage! { get set }
}

extension NSApplication: ApplicationIconDisplaying {}

struct DockClockAnimationTimeline: Equatable, Sendable {
    static let standard = DockClockAnimationTimeline(
        digitalFrameCount: 9,
        splitFlapFrameCount: 13,
        frameInterval: .milliseconds(30)
    )

    let digitalFrameCount: Int
    let splitFlapFrameCount: Int
    let frameInterval: Duration

    init(
        digitalFrameCount: Int,
        splitFlapFrameCount: Int,
        frameInterval: Duration
    ) {
        precondition(digitalFrameCount > 0)
        precondition(splitFlapFrameCount > 0)
        precondition(frameInterval >= .zero)
        self.digitalFrameCount = digitalFrameCount
        self.splitFlapFrameCount = splitFlapFrameCount
        self.frameInterval = frameInterval
    }

    func transitions(
        previousDate: Date,
        style: DockClockDisplayStyle
    ) -> [DockClockTransition] {
        let frameCount: Int
        switch style {
        case .analog:
            return []
        case .digital:
            frameCount = digitalFrameCount
        case .splitFlap:
            frameCount = splitFlapFrameCount
        }

        return (1...frameCount).map { frame in
            DockClockTransition(
                previousDate: previousDate,
                progress: Double(frame) / Double(frameCount)
            )
        }
    }
}

@MainActor
final class DockTileController {
    private let dockTile: NSDockTile
    private let application: any ApplicationIconDisplaying
    private let appearanceStore: UserDefaults
    private let iconRenderer: any DockApplicationIconRendering
    private let clockAnimationTimeline: DockClockAnimationTimeline
    private let reduceMotionProvider: @MainActor () -> Bool

    private var clockAnimationTask: Task<Void, Never>?
    private var clockAnimationID: UUID?

    private(set) var currentPresentation: DockTilePresentation
    private(set) var currentAppearanceMode: DSAppearanceMode
    private(set) var isAnimatingClock = false

    convenience init(initialPresentation: DockTilePresentation) {
        self.init(
            dockTile: NSApplication.shared.dockTile,
            application: NSApplication.shared,
            initialPresentation: initialPresentation,
            appearanceStore: DockMagicRuntimeDefaults.current
        )
    }

    init(
        dockTile: NSDockTile,
        application: (any ApplicationIconDisplaying)? = nil,
        initialPresentation: DockTilePresentation,
        appearanceStore: UserDefaults = DockMagicRuntimeDefaults.current,
        iconRenderer: (any DockApplicationIconRendering)? = nil,
        clockAnimationTimeline: DockClockAnimationTimeline = .standard,
        reduceMotionProvider: (@MainActor () -> Bool)? = nil
    ) {
        self.dockTile = dockTile
        self.application = application ?? NSApplication.shared
        self.appearanceStore = appearanceStore
        self.iconRenderer = iconRenderer ?? DockApplicationIconRenderer()
        self.clockAnimationTimeline = clockAnimationTimeline
        self.reduceMotionProvider = reduceMotionProvider ?? {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
        currentPresentation = initialPresentation
        currentAppearanceMode = DSAppearanceMode.stored(in: appearanceStore)

        // Use one canonical application icon for both the Dock and Command-Tab.
        // A custom Dock content view is flattened to the Dock backing-store
        // size, while DockIconRenderingRules preserves a 1024-pixel source.
        dockTile.contentView = nil
        render()
    }

    deinit {
        clockAnimationTask?.cancel()
    }

    func update(presentation: DockTilePresentation) {
        guard presentation != currentPresentation else {
            return
        }

        let previousPresentation = currentPresentation
        currentPresentation = presentation
        cancelClockAnimation()

        guard let animation = clockAnimation(
            from: previousPresentation,
            to: presentation
        ) else {
            render()
            return
        }

        startClockAnimation(
            previousDate: animation.previousDate,
            style: animation.style
        )
    }

    func updateAppearance() {
        cancelClockAnimation()
        currentAppearanceMode = DSAppearanceMode.stored(in: appearanceStore)
        render()
    }

    private func render(clockTransition: DockClockTransition? = nil) {
        if let image = iconRenderer.render(
            presentation: currentPresentation,
            appearanceMode: currentAppearanceMode,
            clockTransition: clockTransition
        ) {
            application.applicationIconImage = image
        }
        dockTile.display()
    }

    private func clockAnimation(
        from previousPresentation: DockTilePresentation,
        to presentation: DockTilePresentation
    ) -> (previousDate: Date, style: DockClockDisplayStyle)? {
        guard !reduceMotionProvider(),
              case let .clock(previousDate, previousConfiguration) = previousPresentation,
              case let .clock(date, configuration) = presentation,
              previousConfiguration == configuration,
              configuration.displayStyle != .analog else {
            return nil
        }

        let elapsed = abs(date.timeIntervalSince(previousDate))
        guard elapsed >= 59, elapsed <= 61 else {
            return nil
        }

        return (previousDate, configuration.displayStyle)
    }

    private func startClockAnimation(
        previousDate: Date,
        style: DockClockDisplayStyle
    ) {
        let transitions = clockAnimationTimeline.transitions(
            previousDate: previousDate,
            style: style
        )
        guard !transitions.isEmpty else {
            render()
            return
        }

        let animationID = UUID()
        clockAnimationID = animationID
        isAnimatingClock = true
        let frameInterval = clockAnimationTimeline.frameInterval

        clockAnimationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer {
                if self.clockAnimationID == animationID {
                    self.clockAnimationID = nil
                    self.clockAnimationTask = nil
                    self.isAnimatingClock = false
                }
            }

            for (index, transition) in transitions.enumerated() {
                guard !Task.isCancelled,
                      self.clockAnimationID == animationID else {
                    return
                }

                self.render(clockTransition: transition)

                guard index < transitions.index(before: transitions.endIndex) else {
                    continue
                }

                if frameInterval > .zero {
                    do {
                        try await Task.sleep(for: frameInterval)
                    } catch {
                        return
                    }
                } else {
                    await Task.yield()
                }
            }

            guard !Task.isCancelled,
                  self.clockAnimationID == animationID else {
                return
            }

            // Do not leave the Dock on a rasterized 3D transition hierarchy.
            // Publishing a settled frame removes the split-flap half layers and
            // guarantees the final digit uses the normal crisp text rendering.
            self.render()
        }
    }

    private func cancelClockAnimation() {
        clockAnimationID = nil
        clockAnimationTask?.cancel()
        clockAnimationTask = nil
        isAnimatingClock = false
    }
}
