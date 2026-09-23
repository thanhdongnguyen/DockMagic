# Now Playing — implementation evidence

Status: blocked on live Automation approval and an uncontended desktop session for the remaining UI/runtime gates, 16 September 2026. Implementation is not marked complete. This file distinguishes source, fixture, native runtime and provider runtime evidence.

## Confirmed so far

- Current repository Debug build completed successfully in `/private/tmp/dockmagic-nowplaying-production-derived` (latest log: `/private/tmp/now-playing-production-build-4.log`). Outside-sandbox `codesign --verify --deep --strict` passed after the slider initialization change; Sparkle is present in the app bundle. Identity: `com.hypevibe.DockMagic`, Apple Development team `S35WXF7W5L`, Hardened Runtime enabled. This is development-signing evidence, not a Developer ID release/notarization result.
- `/private/tmp/NowPlayingQA-11.xcresult`: **5/5 shared regressions passed**: feature ordering, Settings destination mapping, Dock menu switching, hover capability selection and panel placement. The UI runner failed before test execution in that same result bundle.
- `/private/tmp/NowPlayingUnit-14.xcresult`: all **15/15 Now Playing unit/render tests passed** under the Apple Development-signed QA identity. Includes cancellation, reversed response order, 1024-pixel Dock source, artwork-error retry suppression, late artwork completion, stale command rejection and active/stopped store notification handling. Earlier run 9 passed 12/12; these are successive runs, not additional unique tests.
- Public Apple Events client typechecked under Xcode 15.4. Local Spotify and Music scripting dictionaries were inspected for command/property identifiers.
- `/private/tmp/NowPlayingUnit-2.xcresult`: 8/8 Now Playing tests passed on a signed DockMagic build. Covers stable Auto/manual resolution, monotonic elapsed time, conditional capabilities, explicit consent requests, stopping unused polling, captured command targets, state refresh after commands and independent denied sources.
- Native window render matrix exported under `/private/tmp/dockmagic-nowplaying-qa`: playing, paused, missing artwork, long title, unknown duration, no media, disconnected, denied, not running, timeout, stale and loading; Light, Dark, increased contrast, reduced transparency/motion and grayscale simulation.
- Dark, Light, long title, contrast and denied images were visually inspected. The album, disc artwork and transport are separate native elements. The selected screenshot is not embedded as UI.
- Computer Use opened the actual native fixture panel through Settings. It displayed metadata, source menu, seek, transport, volume and pin at the selected layout size.
- UI run 21 passed the denied-source recovery test and the transport/source/pin/Escape test. Its unknown-duration test failed at the immediate seek-enabled assertion. This is **2/3**, not a passing suite. Run 24 again passed recovery; its two other tests were blocked before opening the panel by another DockMagic window covering the QA window.

## Issues found and addressed

- Auto cold-start selection initially depended on provider response order. Refresh now resolves against the selection from the start of that refresh; the regression passed in the second unit run.
- SwiftUI `ImageRenderer` cannot capture AppKit menu/slider controls. Render tests now capture a native `NSHostingView` window. This also resolves correct AppKit appearances.
- The root dashboard Accessibility identifier propagated to controls. The root now has an explicit accessibility container. Computer Use verified distinct source, pin, seek, play/pause and volume identifiers in the running panel.
- First UI test run used both sources playing in Auto, which would validly switch sources after pausing one. The test now explicitly selects Spotify before exercising pause.
- Artwork transport errors previously bypassed the negative cache and could retry at every playback poll. Failures now use the same 60-second negative cache; cancellation remains retryable. The focused regression passed in QA run 9.
- Transport and volume now reevaluate snapshot freshness once per second, matching the seek control. An aged snapshot shows `Out of date`; all playback commands are disabled even while a provider refresh is pending. Run 14 verifies store rejection of every stale command; manual native QA verified the label and disabled controls.
- Tests inject a private notification center to simulate launch/quit/wake handling without posting fake workspace events to other running stores. An active store refreshes; a stopped store remains stopped. This does not substitute for a physical sleep/wake test.

## Remaining gates

| Gate | Required evidence |
| --- | --- |
| Latest source build and tests | Current-source Debug build and deep signature verification passed after the slider initialization edit. Fifteen logic/render and five shared regression tests passed in runs 14/11; full automated UI suite is not passing. See UI runs 20–24 below. |
| Native UI actions | Manual fixture proof recorded below for source menu, Pause, Next, seek, volume, pin/unpin, Space and Escape. Automated UI suite, Tab/arrow focus, outside-click and full lifecycle remain to verify. |
| Empty/error UI | Denied/Light header, source menu, pin and recovery control verified manually; unknown-duration seek disabled and volume available verified. Other recovery variants have fixture render evidence. |
| Live Spotify | Consent from DockMagic, real metadata/artwork, seconds normalization, transport and app-volume readback |
| Live Music | Independent consent, real metadata, duration/position normalization, transport, app-volume and artwork where available |
| Lifecycle | Revocation/denial, app quit/reopen and refresh after wake; no stale command or artwork applied |
| Dock and hover | Native icon, hover handoff, placement, menu suspension and feature-switch dismissal; no keyboard activation on mere hover |
| Regression and performance | Shared feature/Settings/menu/placement tests; observed request/CPU/memory behavior of the music lane |

## Build environment notes

Multiple DockMagic tasks and app instances were active in the same workspace. A UI rebuild encountered an in-progress Grok mapping, and a later build lost a shared Sparkle artifact. These are separate from the passing Now Playing unit run. No unrelated feature changes were reverted.

Now Playing dependencies were successfully resolved into `/private/tmp/dockmagic-nowplaying-packages`. Earlier runs used SwiftTerm 1.18.0, Sparkle 2.9.6 and swift-argument-parser 1.7.2. The latest production build and QA resolution use Sparkle 2.10.0 within the project's existing version range; its version was read from the built framework's Info.plist.

A source snapshot under `/private/tmp/dockmagic-nowplaying-qa-source` changes only its copied app bundle identifier to `com.hypevibe.DockMagic.NowPlayingQA` for UI isolation. The repository retains `com.hypevibe.DockMagic`. QA identity evidence will be labeled separately from production-identity TCC evidence. The source snapshot and build outputs are temporary verification artifacts, not a new shipping target.

### QA runs 5–9

Runs 5–7 found stale copies of shared Calendar/AI chart fixture files in the temporary source snapshot. The already-corrected repository versions were copied into that snapshot; these files were not edited by the Now Playing lane.

Run 8 compiled successfully and both bundles passed `codesign --verify --deep --strict`. Tests did not execute: the UI runner timed out during bootstrap and the unit-test host failed at launch. The crash report for `DockMagic` PID 97444 identified a DYLD Sparkle Team ID mismatch in the ad hoc test environment. This is not a passing test result. Computer Use also timed out when inspecting that runner (`-10005: timeoutReached`).

Run 9 assigns distinct bundle identifiers to the copied test targets and uses `ENABLE_HARDENED_RUNTIME=NO` only as an `xcodebuild` override in the temporary Debug QA lane, allowing XCTest framework injection with ad hoc signing. Repository build/distribution settings are unchanged. This lane does not prove Developer ID + Hardened Runtime behavior.

### Native UI follow-up and permission gate

UI run 9 reached the actual test cases, but all three stopped before opening the panel. The failure screenshot showed the Now Playing sidebar row below the visible scroll area. Computer Use then opened that same Settings destination successfully in the QA app. Tests now target the sidebar containing the Now Playing row and move the cursor over it before scrolling.

Run 10 also encountered an unexpected application termination during interaction, with no matching crash report found. Concurrent tasks use process-name-based stop commands. Run 11 therefore gives only the copied application executable the distinct name `DockMagicNowPlayingQA`, in addition to the existing QA bundle identifiers. This mitigates a suspected external termination source; it does not establish the cause of every failed UI action.

Automatic approval review rejected the real **Connect Spotify** action because the user had not specifically approved granting Spotify-control access. An approval question for local Spotify/Apple Music Automation testing was sent. No live connection, playback command or permission grant was performed after this rejection. Fixture tests and build verification remain independent of that approval.

The offscreen native capture shows a missing header in some later render cases. Subsequent stable native inspection confirmed the denied-state header and recovery control; offscreen captures retain the limitation described below. The reviewed [Dark fixture render](now-playing-concepts/native/dashboard-dark.png) and [128-point Dock render](now-playing-concepts/native/dock-128.png) are saved in the repository.

A one-second stack sample of UI runner PID 19604 in run 11 showed it blocked in `_libsecinit_appsandbox` before test execution (`/private/tmp/nowplaying-runner-sample.txt`). The runner had ad hoc signing and Xcode-generated App Sandbox entitlements. A subsequent QA attempt will use the verified Apple Development signing configuration; the sample alone does not establish a product crash or permission problem.

## Manual native fixture evidence

Run 12's UI runner again did not begin test execution during the observation window. Only that xcodebuild process was interrupted (exit 75) to permit manual verification. Its compiled app was then launched directly, signed with Apple Development, under the QA identity and `DockMagicNowPlayingQA` executable. Music data remained synthetic through `DockMagicUITestNowPlaying`.

Computer Use verified the following in the running panel:

- Settings → Now Playing → Open; no Accessibility grant needed for explicit open.
- Pin changed to Unpin and exposed Close; the panel remained available across source-menu interactions.
- Manual Spotify selection, Pause → Play, seek to 60 seconds with `1:00` readback, and volume 30% with label readback.
- Next changed the track to `Through the pines` and position to `0:00`.
- Switching to Apple Music showed `Evening in motion` and that source's independent 65% volume.
- Space paused Apple Music's fixture; Escape dismissed the pinned panel and returned to Settings.
- A separate Light/denied fixture displayed the header, source picker, pin, denial message and Open Automation Settings button. No real permission was changed.
- A separate Light/unknown-duration fixture displayed normal primary text after the panel settled, unknown end time `—:—`, disabled seek/back/forward controls, and an enabled volume slider. The unknown-duration thumb was then adjusted in source to rest at zero instead of its artificial upper bound. Both current-source and QA builds passed, both bundles passed outside-sandbox deep signature verification, and Computer Use confirmed the final seek control was disabled with value `0`.
- A Dark/stale fixture from run 14 displayed `Out of date` between the elapsed and duration labels. Native Accessibility reported disabled previous, back, play/pause, forward, next, seek and volume controls while source, pin and close stayed available. Clicking Unpin dismissed the panel and returned to Settings in this observation; it does not prove every mouse-exit or outside-click path.

Native Accessibility combines the title, artist and album into a single text element with identifier `nowPlaying.trackTitle`. UI tests now wait for that element and check its text contains the expected title, rather than assuming a separate exact-title element. This correction is based on observed native structure; it is not a passing automated UI result.

The corrected UI test target compiled successfully in `build-for-testing` run 19 (`/private/tmp/now-playing-ui-build-19.log`); the resulting QA app passed outside-sandbox deep signature verification. An earlier build-only attempt was blocked by sandbox temporary-file access and then a missing cached `Sparkle.xcframework`. The incomplete artifact and its stale metadata were preserved separately; SwiftPM restored the artifact in the isolated QA package directory. The official archive's SHA-256 matched SwiftPM's declared checksum. This recovery did not require changing product code or weakening signing. No additional UI execution result is claimed from `build-for-testing`.

## UI runs 20–24 and current blocking conditions

- Run 20 reached all three UI tests. XCTest incorrectly reported the offscreen Now Playing row as hittable; the screenshot showed the click landing in the appearance footer. The helper now checks the row's full frame is inside the sidebar viewport before clicking and explicitly activates the QA app.
- Run 21 passed recovery and the complete transport/source/pin/Escape case. The unknown-duration case reported an enabled seek control immediately after opening. The native slider now initializes its bounds, value and enabled state in `makeNSView`, and the test waits for the expected accessibility state.
- Run 22's incremental app bundle omitted `Sparkle.framework`. Crash reports `DockMagicNowPlayingQA-2026-09-16-225822.ips` and `...-225929.ips` identify DYLD `Library missing`; the fallback framework in Build/Products had a different Team ID. Only this test process was interrupted after the cause was confirmed. This was a launch failure, not a slider assertion result.
- Clean `build-for-testing` run 23 restored the embedded Sparkle framework without a product-source or signing-policy workaround. The rebuilt QA app passed deep signature verification. The repository's separate production build 4 also succeeded and retained its framework.
- Run 24 passed denied-source recovery. The unknown-duration and transport tests failed because their sidebar row was not hittable. The failure screenshot shows another DockMagic window, with Grok Build and CPU & RAM active, covering the QA window. The test's own accessibility tree still identified its separate QA process. A fresh run requires an uncontended desktop; unrelated app instances were not closed.
- Manual Computer Use on the final clean QA build, suite `DockMagicNowPlayingManualQA10`, confirmed Light/unknown-duration: title and header visible, seek disabled at value `0`, back/forward disabled, duration `—:—`, and enabled play/pause and volume. This confirms the native state but does not convert run 24 into a passing automated test.

Live Automation approval has remained unanswered across three consecutive goal turns. No real Connect, grant/revoke, transport, seek or volume action was retried. The remaining provider, real Dock/hover, physical lifecycle and performance gates stay open; fixture evidence does not satisfy them. The implementation goal is blocked pending that approval and a desktop session suitable for the remaining native QA.

The first capture of a newly opened panel may omit static text before it settles. Reopening/pinning and taking a stable capture showed the text correctly. Offscreen matrix captures still have this limitation; they must not substitute for stable native screenshots.

## Preview handoff

The currently pinned preview is the Light/unknown-duration fixture, suite `DockMagicNowPlayingManualQA10`, from the final clean QA build. Its source menu, album, playback controls and volume were verified in Computer Use. This preview uses synthetic data; it does not imply real Spotify/Music authorization. The local executable is `/private/tmp/dockmagic-nowplaying-qa-derived/Build/Products/Debug/DockMagic.app/Contents/MacOS/DockMagicNowPlayingQA`.
