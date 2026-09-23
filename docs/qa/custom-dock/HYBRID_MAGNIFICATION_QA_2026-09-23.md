# Hybrid Magnification QA — 2026-09-23

## Scope

This record covers the approved Hybrid magnification preset in DockMagic's
app-owned Custom Dock. It does not change Apple Dock or the Shelf dashboard
contract. The production scope is Finder, Apps/Launchpad, application items,
overflow, stacks, minimized windows and Trash. Shelf slots, the trailing `+`,
Shelf dividers and the resize divider are excluded.

## Implemented contract

- Peak scale: 1.32×.
- Falloff: cosine over `1.75 × iconSize`; the first neighboring item is about
  1.08–1.11× at current Dock spacing.
- Motion: `interactiveSpring(response: 0.16, dampingFraction: 0.88,
  blendDuration: 0.04)`.
- Anchor: upward for bottom Dock, rightward for left Dock, leftward for right
  Dock.
- The panel frame is fixed. Main-axis displacement is clamped to the panel and
  its side of the Shelf; cross-axis scale is reduced if the available thickness
  cannot contain the nominal peak.
- Only artwork or a minimized-window thumbnail transforms. The Button, hit
  target, running dot, context menu, drag/drop target and accessibility frame
  retain their original geometry.
- Reduce Motion returns identity transforms while retaining the saved toggle.
- New configurations default to enabled. Explicit saved values are retained;
  legacy payloads without the field decode to disabled.

## Automated evidence

| Check | Evidence | Result |
| --- | --- | --- |
| Persistence | New, explicit false and legacy-missing-field encode/decode cases | Passed |
| Scale and falloff | Peak 1.32×, first neighbors near 1.10×, distant item 1.0× | Passed |
| Shelf boundary | Pointer over Shelf returns identity; groups before/after Shelf do not influence one another | Passed |
| Bounds and directions | 16/30/44/60/128 pt on bottom/left/right, including panel ends and Shelf-adjacent items | 15/15 combinations passed |
| Disabled and Reduce Motion | Both paths return identity and no active item | Passed |
| Calculation budget | 2,000 resolves over 80 items completed in 0.513 s in the final Debug test, about 0.26 ms/resolve | Passed for the pure engine against the 8.3 ms 120 Hz budget |
| Live UI geometry | Finder and Trash hover; their AX/Button frames, Shelf group and `+` frames remain unchanged | Passed |
| Live Reduce Motion | Finder hover remains idle and Settings explains the suppression | Passed |
| Resize regression | Pointer drag grows and shrinks the nonactivating Custom Dock through the fixed divider | Passed |
| Shelf regression | Search/add, duplicate slots, 400 ms dashboard hover, click/Escape, reorder/remove and Trash open | Passed |
| Release build | Unsigned Release configuration compiled successfully; the Release binary contains none of the DEBUG UI-test probe identifiers | Passed |

The final six focused unit tests passed in:

`Test-DockMagic-2026.09.23_00-29-18-+0700.xcresult`

The final four focused UI tests passed in:

`Test-DockMagic-2026.09.23_00-27-33-+0700.xcresult`

The final unsigned Release build passed with Xcode 26.2 and the macOS 26.2 SDK.
This confirms Release compilation and DEBUG probe exclusion; it is not a
Developer ID signing, notarization or stapling run.

Visual evidence:

- [Peak magnification Dock crop](hybrid-magnification-artifacts/hybrid-magnification-peak-dock.png)
- [Full-screen capture](hybrid-magnification-artifacts/hybrid-magnification-peak.png)
- [Export manifest](hybrid-magnification-artifacts/manifest.json)

The earlier combined run exposed an expanded Finder accessibility frame. The
artwork was then moved into a noninteractive, accessibility-hidden background
layer, and the final test verified stable Finder and Trash frames. The same
shared composition is used by applications, overflow, stacks and minimized
windows.

## Runtime and limits

The run used the connected Apple silicon Mac on macOS 26.2 with the Debug app.
The pure engine is comfortably below one 120 Hz frame, and the live sweep did
not trigger a layout loop. This run is not an Instruments frame-time trace and
does not establish end-to-end 120 Hz rendering on every display. macOS 14 and
15 runtime checks, VoiceOver speech with a human listener, multi-display sweep
recording, Developer ID notarization and stapling remain part of the release
matrix in the parent Custom Dock QA report.

`Design.md` lint completed with zero errors. It reported 40 existing
`orphaned-tokens` warnings across the broader design token file; this motion
change introduced no new token and does not depend on any of those warnings.
