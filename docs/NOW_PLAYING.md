# Now Playing

Native Spotify/Music integration for DockMagic, based on selected [option 3](now-playing-concepts/option-3-selected.png). Implementation and verification are in progress; see the [implementation plan](NOW_PLAYING_IMPLEMENTATION_PLAN.md) for acceptance criteria.

## User flow

Choose **Now Playing** in Settings or the Dock's **Switch Feature** menu. Enable a music app and use **Connect** to request its Automation permission. If it is not running, use **Open App**, then **Connect**. The two apps are independent. Open **Privacy & Security → Automation** to recover a denied connection.

**Open Now Playing** activates the music feature and opens a keyboard-capable panel without requiring Accessibility. Enabling Dock hover additionally requires Accessibility, as for the existing dashboards. Hover does not activate DockMagic. A click gives the panel keyboard focus. Pin keeps it open when working elsewhere; Escape or the close button dismisses it. Pin is not persisted. Switching the active feature closes it.

Auto keeps the current playing source when both apps play. At first refresh it prefers the configured source, with Spotify as the initial preference. Selecting a source never starts, pauses, transfers or otherwise changes playback. Explicit selection does not fall back to another source on error.

The central button is play/pause. Previous/next are separate from skipping 5/10/15/30/60 seconds. Volume controls the selected app's volume. Seeking is disabled when duration or position is unknown or content does not support it. Unknown values are displayed as unavailable, not zero.

When the playback snapshot is more than 12 seconds old, the panel shows **Out of date**, stops interpolating position, and disables transport, seek and volume until a fresh observation arrives. Source selection and panel controls remain available.

The Dock badge shows the transport action: pause while playing, play while paused. It is not a separate clickable target. Accessibility describes the actual state. The existing `applicationIconImage` pipeline also makes this artwork appear in Command-Tab.

## Integration contract

- `AppleEventsPlaybackClient` creates public `NSAppleEventDescriptor` requests on one serial utility queue per source. This implements the plan's Apple Events boundary directly; it avoids ScriptingBridge proxies and Objective-C exceptions, and exposes typed errors and request timeouts.
- Targets use the running process ID. Background observation never starts a music app, requests consent, executes scripts, or creates child processes. Only `connect` passes `requestPermission: true`.
- `NSAppleEventsUsageDescription` and the Hardened Runtime `com.apple.security.automation.apple-events` entitlement are included. This uses the direct distribution path; no App Store or MusicKit capability is required.
- Spotify uses the `spfy` suite. Duration is normalized from milliseconds; position is in seconds. Music uses the `hook` suite and durations/positions in seconds. These mappings are based on the installed scripting dictionaries; live verification is recorded separately.
- Every command captures source and track identity. The store rejects stale UI targets, and the provider rechecks the current track immediately before sending. Play/pause are explicit commands; failed toggles are not retried. Each event times out within 2 seconds, with an 8-second observation budget; time spent in consent is excluded.
- Seek/volume preview locally during tracking and commit the final value on release. Keyboard and accessibility slider changes also commit. Provider refresh supplies the confirmed value after success or failure.
- Polling runs only while the feature, panel, or Settings page is in use. Playing: 1 second with a panel, 4 seconds for the icon. Paused/empty: 3 seconds with a panel, 8 seconds otherwise. Launch/quit/wake notifications refresh active observations.
- Position is interpolated using system uptime while observations are fresh. Reduced Dock presentation excludes elapsed time and volume, so they do not invalidate the bitmap.
- Artwork is cached in memory, limited to 8 entries/16 MB. Incoming data is limited to 12 MB and downsampled to 768 pixels. Spotify fetches the reported HTTPS artwork URL with an ephemeral session; Music reads the current track's artwork bytes. Completion is checked against the current source/track/reference. Missing artwork keeps controls usable.
- Configuration is stored under `DockMagicNowPlayingConfiguration` in the same runtime defaults domain as the app. No music history or artwork cache is written to disk.

## Scope and evidence

Browser media, Spotify Connect remote-device management, queues, lyrics, shuffle/repeat and listening history are outside this MVP. Scripting dictionaries describe commands but do not prove all account/content variants work. Live proof must come from the signed DockMagic bundle, not a Terminal scripting session.

Debug-only `NowPlayingFixtures` supports deterministic UI and failure states. `DockMagicUITesting=1` plus `DockMagicUITestNowPlaying` selects a fixture; it is not a user-facing demo connection. Supported modes: playing, paused, longTitle, noArtwork, unknownDuration, noMedia, denied, notRunning, disconnected, unavailable, stale and loading.

## Verification commands

Run `xcodebuild` with scheme `DockMagic`, destination `platform=macOS,arch=arm64`, and `-only-testing:DockMagicTests/NowPlayingTests` or `-only-testing:DockMagicUITests/NowPlayingUITests`. Native render tests write images to `/private/tmp/dockmagic-nowplaying-qa` and attach them to the result bundle. AppKit controls are captured through an `NSHostingView` window; SwiftUI `ImageRenderer` alone cannot capture them.

This workspace has concurrent DockMagic work. Current-source builds use `/private/tmp/dockmagic-nowplaying-production-derived`; fixture tests use `/private/tmp/dockmagic-nowplaying-qa-derived` and an isolated source snapshot. Both use packages in `/private/tmp/dockmagic-nowplaying-packages`. The temporary QA copy has a distinct bundle identifier and executable name; shipping identity is unchanged. Avoid killing unrelated running DockMagic instances during runtime QA. See [QA evidence](NOW_PLAYING_QA.md) for results and remaining runtime gates.
