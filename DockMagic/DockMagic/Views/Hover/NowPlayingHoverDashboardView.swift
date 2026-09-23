import AppKit
import SwiftUI

@MainActor
struct NowPlayingHoverDashboardView: View {
    let store: NowPlayingStore
    var isPinned = false
    var onPin: () -> Void = {}
    var onClose: () -> Void = {}
    var onSettings: () -> Void = {}
    @Environment(\.designTheme) private var theme
    @State private var seekPreview: Double?
    @State private var volumePreview: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let snapshot = store.snapshot, let track = snapshot.track, store.observation?.access == .authorized {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        NowPlayingArtworkView(data: store.artworkData)
                            .equatable()
                            .frame(width: 216, height: 216)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.outline, lineWidth: 0.5))
                        Button { NowPlayingStore.openApp(snapshot.source) } label: {
                            HStack(spacing: 5) {
                                Text("\(snapshot.state.title) in \(snapshot.source.title)")
                                DSIcon(systemName: "arrow.up.right")
                            }.dsFont(size: 12).foregroundStyle(theme.textSecondary)
                        }.buttonStyle(DSContentButtonStyle()).accessibilityIdentifier("nowPlaying.openSource")
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(track.title).dsFont(size: 21, weight: .semibold)
                            .foregroundStyle(theme.textPrimary).lineLimit(2).truncationMode(.tail)
                            .help(track.title).accessibilityIdentifier("nowPlaying.trackTitle")
                        Text(track.artist ?? "Unknown artist").dsFont(size: 16)
                            .foregroundStyle(theme.textSecondary).lineLimit(1).padding(.top, 5)
                        Text(track.album ?? "Unknown album").dsFont(size: 13)
                            .foregroundStyle(theme.textSecondary).lineLimit(1).padding(.top, 4)
                        Spacer(minLength: 12)
                        timeline(snapshot: snapshot)
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            VStack(spacing: 0) {
                                transport.padding(.vertical, 12)
                                volume(snapshot: snapshot)
                            }
                        }
                    }.frame(maxWidth: .infinity).frame(height: 242)
                }
            } else {
                emptyState.frame(maxWidth: .infinity).frame(height: 242)
            }
            if let error = store.commandError ?? store.observation?.error {
                Text(error).dsFont(size: 11).foregroundStyle(theme.warningForeground)
                    .lineLimit(2).help(error).accessibilityIdentifier("nowPlaying.error")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nowPlaying.dashboard")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Now Playing").dsFont(size: 19, weight: .semibold).foregroundStyle(theme.textPrimary)
            Spacer(minLength: 8)
            DSSelect(title: "Music source",
                selection: Binding(get: { store.configuration.selection }, set: store.select),
                options: NowPlayingSelection.allCases.map {
                    .init(value: $0, title: $0.title,
                          disabled: $0.source.map { !store.configuration.enabledSources.contains($0) } ?? false)
                }, size: .small)
                .labelsHidden().frame(width: 150)
                .help("Source: \(store.configuration.selection.title)")
                .accessibilityIdentifier("nowPlaying.source")
            Button(action: onSettings) { DSIcon(.settings, size: 16) }
                .buttonStyle(DSIconButtonStyle())
                .accessibilityLabel("Music settings")
            Rectangle().fill(theme.outline).frame(width: 1, height: 19).accessibilityHidden(true)
            Button(action: onPin) {
                DSIcon(systemName: isPinned ? "pin.fill" : "pin").dsFont(size: 16)
                    .foregroundStyle(isPinned ? theme.actionForeground : theme.textSecondary).frame(width: 24, height: 26)
            }.buttonStyle(DSContentButtonStyle()).help(isPinned ? "Unpin dashboard" : "Keep dashboard open")
                .accessibilityLabel(isPinned ? "Unpin dashboard" : "Pin dashboard")
                .accessibilityIdentifier("nowPlaying.pin")
            if isPinned {
                Button(action: onClose) { DSIcon(systemName: "xmark").frame(width: 22, height: 26) }
                    .buttonStyle(DSContentButtonStyle()).foregroundStyle(theme.textSecondary)
                    .accessibilityLabel("Close dashboard").accessibilityIdentifier("nowPlaying.close")
            }
        }.frame(height: 36)
    }

    private func timeline(snapshot: NowPlayingSnapshot) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let elapsed = seekPreview ?? snapshot.elapsed(at: ProcessInfo.processInfo.systemUptime)
            VStack(spacing: 4) {
                NowPlayingCommitSlider(value: snapshot.track?.duration == nil ? 0 : elapsed ?? 0, upperBound: snapshot.track?.duration ?? 1,
                    enabled: store.canOffer(.seek(0)), target: store.commandTarget, label: "Playback position", identifier: "nowPlaying.seek",
                    onPreview: { seekPreview = $0 }, onCommit: { value, target in store.perform(.seek(value), target: target) })
                    .frame(height: 18)
                    .help(snapshot.capabilities.seek ? "Seek within this song" : "Seeking is unavailable for this content")
                HStack {
                    Text(NowPlayingTimeFormat.string(elapsed))
                    Spacer()
                    if !snapshot.isFresh(at: ProcessInfo.processInfo.systemUptime) {
                        Text("Out of date").foregroundStyle(theme.warningForeground)
                            .help("Waiting for an updated playback status before enabling controls.")
                            .accessibilityIdentifier("nowPlaying.stale")
                        Spacer()
                    }
                    Text(NowPlayingTimeFormat.string(snapshot.track?.duration))
                }.dsFont(size: 11).monospacedDigit().foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 0) {
            transportButton("backward.end.fill", label: "Previous song", command: .previous) { store.perform(.previous) }
            Spacer(minLength: 3)
            transportButton("gobackward.\(store.configuration.skipSeconds)", label: "Back \(store.configuration.skipSeconds) seconds", command: .seek(0)) { store.skip(-1) }
            Spacer(minLength: 6)
            Button { store.togglePlayback() } label: {
                DSIcon(systemName: store.snapshot?.state == .playing ? "pause.fill" : "play.fill")
                    .dsFont(size: 21, weight: .semibold)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(theme.onAction).background(theme.action, in: Circle())
            }.buttonStyle(DSContentButtonStyle()).disabled(!store.canOffer(.play))
                .opacity(store.canOffer(.play) ? 1 : 0.45)
                .accessibilityLabel(store.snapshot?.state == .playing ? "Pause" : "Play")
                .accessibilityIdentifier("nowPlaying.playPause")
                .keyboardShortcut(.space, modifiers: [])
            Spacer(minLength: 6)
            transportButton("goforward.\(store.configuration.skipSeconds)", label: "Forward \(store.configuration.skipSeconds) seconds", command: .seek(0)) { store.skip(1) }
            Spacer(minLength: 3)
            transportButton("forward.end.fill", label: "Next song", command: .next) { store.perform(.next) }
        }
    }
    private func transportButton(_ symbol: String, label: String, command: NowPlayingCommand, action: @escaping () -> Void) -> some View {
        Button(action: action) { DSIcon(systemName: symbol).dsFont(size: 19, weight: .medium).frame(width: 30, height: 40) }
            .buttonStyle(DSContentButtonStyle()).foregroundStyle(theme.textPrimary).disabled(!store.canOffer(command))
            .help(label).accessibilityLabel(label)
    }
    private func volume(snapshot: NowPlayingSnapshot) -> some View {
        HStack(spacing: 8) {
            DSIcon(systemName: (volumePreview ?? snapshot.volume ?? 0) == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .dsFont(size: 13).frame(width: 18).accessibilityHidden(true)
            NowPlayingCommitSlider(value: volumePreview ?? snapshot.volume ?? 0, upperBound: 100,
                enabled: store.canOffer(.volume(0)), target: store.commandTarget, label: "\(snapshot.source.title) volume", identifier: "nowPlaying.volume",
                onPreview: { volumePreview = $0 }, onCommit: { value, target in store.perform(.volume(value), target: target) })
                .frame(height: 20)
            Text((volumePreview ?? snapshot.volume).map { "\(Int($0.rounded()))%" } ?? "—")
                .dsFont(size: 11).monospacedDigit().frame(width: 31, alignment: .trailing)
        }.foregroundStyle(theme.textSecondary).help("Volume in \(snapshot.source.title)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if store.isLoading || !store.connecting.isEmpty { ProgressView().controlSize(.small) }
            else { DSIcon(systemName: "music.note").dsFont(size: 35).foregroundStyle(theme.textSecondary) }
            Text(emptyTitle).dsFont(size: 19, weight: .semibold).foregroundStyle(theme.textPrimary)
            Text(emptyDetail).dsFont(size: 13).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center).frame(maxWidth: 380)
            HStack(spacing: 10) {
                if let source = store.selectedSource {
                    if store.observation?.access == .denied {
                        Button("Open Automation Settings", action: NowPlayingStore.openAutomationSettings)
                    } else if store.observation?.access == .notDetermined {
                        Button("Connect \(source.title)") { store.connect(source) }.disabled(store.connecting.contains(source))
                    } else {
                        Button("Open \(source.title)") { NowPlayingStore.openApp(source) }.disabled(!NowPlayingStore.isInstalled(source))
                        Button("Refresh") { store.reload() }
                    }
                } else {
                    ForEach(NowPlayingSource.allCases) { source in
                        Button("Connect \(source.title)") { store.connect(source) }.disabled(store.connecting.contains(source))
                    }
                }
            }.buttonStyle(DSButtonStyle())
        }
    }
    private var emptyTitle: String {
        if !store.connecting.isEmpty { return "Connecting…" }
        if store.isLoading { return "Checking music apps…" }
        guard let source = store.selectedSource else { return "Your music, one glance away" }
        switch store.observation?.access {
        case .notInstalled: return "\(source.title) is not installed"
        case .notRunning: return "Open \(source.title) to begin"
        case .denied: return "Allow access to \(source.title)"
        case .notDetermined, .none: return "Connect \(source.title)"
        case .unavailable: return "\(source.title) is not responding"
        case .authorized: return "Nothing playing"
        }
    }
    private var emptyDetail: String {
        switch store.observation?.access {
        case .denied: return "Enable DockMagic for this app under Privacy & Security → Automation."
        case .notRunning, .authorized: return "Choose a song in the music app. Its artwork and controls will appear here."
        case .unavailable: return "Check the music app, then refresh to try again."
        default: return "Connect Spotify or Apple Music on this Mac. macOS will ask before DockMagic can control either app."
        }
    }
}

/// Native tracking captures the command destination once and commits on release,
/// including keyboard and accessibility adjustments. Polling never moves a dragged thumb.
private struct NowPlayingCommitSlider: NSViewRepresentable {
    let value: Double
    let upperBound: Double
    let enabled: Bool
    let target: NowPlayingCommandTarget?
    let label: String
    let identifier: String
    let onPreview: (Double?) -> Void
    let onCommit: (Double, NowPlayingCommandTarget?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider()
        slider.minValue = 0; slider.controlSize = .small; slider.isContinuous = true
        slider.maxValue = max(1, upperBound)
        slider.doubleValue = min(max(0, value), slider.maxValue)
        slider.isEnabled = enabled
        slider.target = context.coordinator; slider.action = #selector(Coordinator.changed(_:))
        slider.begin = { [weak coordinator = context.coordinator] in coordinator?.begin() }
        slider.end = { [weak coordinator = context.coordinator, weak slider] in if let slider { coordinator?.end(slider) } }
        slider.setAccessibilityLabel(label); slider.setAccessibilityIdentifier(identifier)
        return slider
    }
    func updateNSView(_ slider: TrackingSlider, context: Context) {
        context.coordinator.parent = self
        if !slider.tracking {
            slider.maxValue = max(1, upperBound)
            slider.doubleValue = min(max(0, value), slider.maxValue)
            slider.isEnabled = enabled
        }
        slider.setAccessibilityLabel(label)
    }
    final class Coordinator: NSObject {
        var parent: NowPlayingCommitSlider
        var captured: NowPlayingCommandTarget?
        init(parent: NowPlayingCommitSlider) { self.parent = parent }
        func begin() { captured = parent.target }
        func end(_ slider: NSSlider) { parent.onCommit(slider.doubleValue, captured); parent.onPreview(nil) }
        @objc func changed(_ slider: TrackingSlider) {
            if slider.tracking { parent.onPreview(slider.doubleValue) }
            else { parent.onCommit(slider.doubleValue, parent.target) }
        }
    }
    final class TrackingSlider: DSNativeSlider {
        var tracking = false
        var begin: () -> Void = {}
        var end: () -> Void = {}
        override func mouseDown(with event: NSEvent) { tracking = true; begin(); super.mouseDown(with: event); tracking = false; end() }
        override func keyDown(with event: NSEvent) { tracking = true; begin(); super.keyDown(with: event); tracking = false; end() }
    }
}
