# Custom Dock / Shelf implementation QA — 2026-09-21

## Scope and current release decision

DockMagic now has an app-owned Custom Dock with a grouped Shelf segment. The
Custom Dock checks covered by this report pass on the connected macOS 26.2
host. The feature remains **not release ready** because the repository-wide UI
suite is not green, the known non-pointer Apple Dock handoff route remains
open, and macOS 14/15 plus notarization/stapling have not been exercised.

The earlier [Gate 0 research report](CUSTOM_DOCK_GATE0_QA_2026-09-20.md)
remains the source of truth for the native Dock overlap route that is not
covered by the pointer-edge stress harness.

The implemented Hybrid icon motion and its focused test evidence are recorded
in [Hybrid Magnification QA](qa/custom-dock/HYBRID_MAGNIFICATION_QA_2026-09-23.md).

## Custom Dock checks that passed

| Area | Evidence | Result |
| --- | --- | --- |
| Focused data and layout tests | Duplicate slot UUIDs and persistence, 16–128 pt normalization, all-edge overflow, reliable Trash state and recycling of one generated file | 4/4 passed |
| Shelf interaction UI | Duplicate tiles, searchable add, trailing `+`, real drag reorder, remove, hover delay, click toggle, Escape, and exact-slot dashboard anchoring | Passed |
| Accessibility denial | A denied Accessibility grant returns to Dock Active, shows recovery guidance, and persists that safe mode across relaunch | Passed |
| Accessibility audit | Xcode `.all` audit passed after labeling the hosting group and exposing the resize divider as an adjustable Slider. The system-owned Touch Bar root is excluded. | Passed |
| VoiceOver live session | VoiceOver was enabled on the built app. Finder, Apps, app tiles, Shelf, dynamic CPU/RAM value, Weather details, Now Playing, Add Feature, resize Slider and Trash were exposed with labels/values; the VoiceOver focus ring reached Shelf. VoiceOver was disabled again after the run. | Passed for exposure/focus; spoken output and Control-Option navigation chords were inconclusive through Computer Use |
| Minimized windows | A temporary local AppKit probe set a real window to `AXMinimized`; Custom Dock exposed `Restore DockMagic Minimized QA`; invoking it restored the window and removed the Dock item. Verified with Computer Use. | Passed |
| Finder pointer drops | A real Finder drag to the TextEdit tile reached the production SwiftUI drop target and the `NSWorkspace.open` completion returned success for the generated file. A second real Finder drag to Trash returned a live `NSWorkspace.recycle` destination. | Passed in standalone and final grouped runs; [screenshot](screenshots/custom-dock-interactions-2026-09-21/finder-drop-trash-2026-09-22.png) |
| Trash | Finder returned a non-unknown empty/full state. `NSWorkspace.recycle` moved only the generated QA file, returned its Trash destination, and the test restored and removed the file. Real Trash was never emptied. | Passed |
| Dashboard visual | Weather dashboard opened from the exact right-edge Shelf slot in the built app. | [Final focused-run screenshot](screenshots/custom-dock-interactions-2026-09-21/weather-dashboard-right-edge-2026-09-22.png) |
| Release signing | Release build passed with Developer ID Application `S35WXF7W5L`; `codesign --verify --deep --strict` passed; CodeDirectory contains the Hardened Runtime flag. | Passed |

## Focused reruns and defects fixed — 2026-09-22

Four focused unit/integration tests passed again on macOS 26.2: duplicate slot
identity and persistence, size normalization, all-edge essential controls, and
real Trash state/recycle/restore. The machine-readable summary is
[focused-unit-summary-2026-09-22.json](qa/custom-dock/focused-unit-summary-2026-09-22.json).

Four focused UI tests also passed together after the final fixes: the complete
Shelf add/reorder/remove/dashboard flow, the `.all` Accessibility audit, denied
Accessibility recovery, and the real Finder-to-app-to-Trash pointer path. The
run completed with 4 passed, 0 failed and 0 skipped tests in 87.7 seconds. Its
machine-readable result is
[focused-ui-summary-2026-09-22.json](qa/custom-dock/focused-ui-summary-2026-09-22.json).

### Shelf `+` and Trash click regression — 2026-09-22

A follow-up desktop check reproduced two click failures. The nonactivating
Custom Dock created its feature picker without activating DockMagic, so the
panel could remain behind the foreground application. The searchable select
also requested first responder status before its hosting window was attached.
The picker now activates DockMagic, uses a key-capable floating panel, defers
search focus by one main-actor turn, positions itself from the active Dock edge,
and clamps its frame to the visible screen.

Opening Trash no longer depends on the Finder `open trash` AppleScript that
returned `FSFindFolder error -43` on this machine. It opens the current user's
Trash URL through `NSWorkspace`, with Finder activation as a fallback. An
unknown empty/full state no longer disables the open action; it only changes
the icon/help presentation.

The strengthened Shelf interaction UI test passed with Finder frontmost before
both clicks and verified a hittable `Add Shelf feature` window plus a Finder
window titled `Trash`. A separate Computer Use run repeated both clicks with
real pointer input from Finder and confirmed that the search field became first
responder. The focused UI run passed 1/1 in 31.7 seconds, the production build
passed, and three related slot/layout unit tests passed 3/3.

The pointer test uses only a uniquely generated temporary text file. It opens
that file through a real Custom Dock app tile, moves the same file through the
real Custom Dock Trash drop target, verifies the returned destination, restores
the file, and removes the QA directory. No pre-existing file is moved or
deleted.

This run found and fixed a production responsiveness defect: Trash state used
to execute Finder AppleScript synchronously on the main actor. It now runs in a
cancelable utility task outside the main actor, updates observable state on the
main actor, and marks Trash full immediately after a successful recycle.

The desktop test also exposed two harness-only sources of flakiness. TextEdit
could restore its Open panel, and the pointer could already be inside the tile
used for a hover assertion. The test now creates a blank TextEdit document,
moves the pointer through another tile before the hover check, positions the QA
Finder window away from system overlays, and allows one bounded retry when the
macOS compositor drops a cross-application drag gesture. The production drop
path is still required to report success before the test passes.

After the user interrupted an earlier grouped Xcode run, two attempts to start
another UI session failed in Xcode itself with `Timed out while enabling
automation mode`; their test bodies did not launch. After terminating the stale
test processes and starting a fresh session, the final four-test focused run
completed successfully. This confirms the earlier timeout was transient Xcode
test infrastructure state rather than a product failure.

## Gate 0 pointer-edge stress

The actual built app was run against Apple Dock auto-hide at the physical Dock
edge. The harness restores Dock preferences through a shell `trap` on success,
failure, interrupt, or termination.

| Native Dock edge | Cycles | Result |
| --- | ---: | --- |
| Bottom | 100 | Passed |
| Left, outermost connected display | 100 | Passed after correcting the test to target the same display as the Custom Dock |
| Right, outermost connected display | 100 | Passed |

The final restoration check reported `autohide=0`, `orientation=bottom`,
`tilesize=44`, absent `autohide-delay`, absent
`autohide-time-modifier`, and no harness marker.

This establishes the pointer-edge path for 300 cycles. It does not close the
non-pointer/system-preference reveal route documented in the earlier Gate 0
report, nor does it cover Spaces, Stage Manager, sleep/wake and Dock restart
as a release matrix.

## Native versus Custom Dock geometry

Nine actual-app comparisons passed the requested 2 pt thickness threshold.
The result includes full-screen captures, element crops and JSON frame data for
both Docks:

- [Geometry evidence and measurement table](screenshots/custom-dock-geometry-2026-09-21-complete/README.md)
- Bottom: deltas 0/0/0 pt at icon sizes 30/44/60 pt.
- Left: deltas 0/2/2 pt at icon sizes 30/44/60 pt.
- Right: deltas 0/1/1 pt at icon sizes 30/44/60 pt.

Dock length is intentionally not equal because Custom Dock contains the Shelf
group. The parity target measured here is edge placement and thickness.

## UI suite status

The former LaunchServices startup hang did not recur. The complete
`DockMagicUITests` target ran to completion in 1,074 seconds:

- 61 total
- 39 passed
- 19 failed
- 3 opt-in desktop probes skipped without their markers

All three Custom Dock UI tests passed inside that full run. The 19 failures are
in existing Calendar, Antigravity, Claude, appearance, Clock, Search Console,
Now Playing, Maia and launch tests. They include stale accessibility values,
timeouts and disabled-application snapshots; therefore the repository-wide
UI gate is **failed**, even though the Custom Dock subset is green. The concise
machine-readable list is at
[full-ui-summary-2026-09-21.json](qa/custom-dock/full-ui-summary-2026-09-21.json).

## Checks still requiring a release environment

1. Repeat spoken VoiceOver navigation with a human listener. Element exposure,
   values and focus ring passed; Computer Use did not reliably deliver every
   Control-Option chord or confirm speech audio.
2. Resolve or explicitly quarantine the 19 existing full-suite failures before
   using a repository-wide green UI gate.
3. Repeat the matrix on macOS 14 and 15, and exercise Spaces, Stage Manager,
   full-screen, Dock restart, sleep/wake, permission revoke and the documented
   non-pointer Dock reveal route.
4. Notarize, staple and validate the final distributable on a clean Mac. This
   run validated Developer ID signing and Hardened Runtime only.

The feature should remain opt-in and should not be presented as complete Apple
Dock parity until these remaining gates are closed.
