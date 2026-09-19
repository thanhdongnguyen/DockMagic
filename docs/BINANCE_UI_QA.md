# Binance UI update — 2026-09-17

This audit covers the approved Pinned Focus appearance update, not a redesign
of market-data behavior. The original implementation audit remains in
[design-qa.md](../design-qa.md). All captures in this audit are generated from
the native SwiftUI/AppKit production views; the evidence below distinguishes
fixture rendering from interaction and live-provider checks.

## Implemented scope

| Requirement | Result |
| --- | --- |
| UI-002 typography | Binance dashboard, chart axes/tooltips and proportional Dock text use SF Pro Rounded. Settings uses SF Pro; production previews retain Rounded. `DSTypography.Dashboard` is opt-in, so other dashboards are not migrated by this task. |
| UI-008 shared buttons | Removed the gradient outline from `DSButtonStyle` for all consumers. Solid semantic fill/outline, pressed feedback, disabled state and Reduce Motion remain. The surface parameter defaults to Settings. |
| UI-011 controls | Settings, Close search and Pin use `DSIconButtonStyle` with 36 pt hit regions. “On Dock” is separate from Pin. The native management menu has a 36 pt label and “Manage [pair]” AX name. Search has a persistent visible label. |
| UI-012 colors | Colors immediately follows live preview: Dock price, Price line / candles, Volume. Shared palette, Automatic/custom labels, persisted optional overrides and colors-only Reset Defaults. |
| UI-010 boundaries | Overrides affect the price renderer/data marks only. Chrome, status, focus, labels, surfaces and divider remain semantic. Contrast is resolved at render time (price ≥4.5:1, data ≥3:1), without rewriting saved choices. |
| UI-014 chart picker | Native segmented Line/Candlestick picker in both dashboard and Settings; range controls retain their existing behavior. |
| UI-015 Dock click | Click cancels the hover timer and closes a visible dashboard before Settings opens. Repeated Dock hover notifications are suppressed until pointer exit. |

Old configuration JSON and partial appearance fields decode with defaults;
the preferences key, watchlist ordering, pin and market controls remain intact.
Appearance-only changes bypass data reconciliation, history requests, stream
subscription changes and market-cache writes. Chart colors do not change the
Dock snapshot; its separate price-color field updates even when the price is
unchanged or missing.

## Verification results

**31 distinct tests passed**, using the latest result for each test across
focused runs: 15 Binance feature tests, 4 Binance render/live tests, 5 hover
tests, 4 native UI flows, and 3 existing Settings/AppDelegate regression tests.
See [test results and run history](binance-design/verification-2026-09-17/test-results.json),
[commands](binance-design/verification-2026-09-17/commands.txt), and
[source hashes](binance-design/verification-2026-09-17/source-hashes.json).

| Check | Evidence / result |
| --- | --- |
| Persistence and isolation | Legacy and partial JSON, appearance round trip, colors-only reset, watchlist/pin retention, empty/stale snapshot and unchanged-price color update passed. Fixture counters confirm no extra REST/history/subscription work for appearance changes. |
| Contrast | Automatic and low-contrast custom/alpha colors meet 4.5:1 for Dock price and 3:1 for data on resolved Light/Dark surfaces; stored choices remain unchanged. |
| Native UI | Select color, relaunch, reset, 36 pt Pin/Close bounds and management-menu name, Close search, Search/Add/Pin/remove, segmented chart/range synchronization, relaunch selection, 20-pair cap, empty search and Escape passed with fixtures. |
| Dock hover/click | Default 1-second dwell, repeated notifications, early exit, disabling hover, menu cancellation, and direct-click cancellation/visible-panel close passed via AppKit tests. Existing AppDelegate Settings routing test passed. |
| Live provider | Real REST/WebSocket state `Live`, 3 pairs with 289 candles each, 620 × 740 pt AppKit panel, 1024 px installed application icon; captured at 07:41:42 UTC. |
| Shared controls | General and Claude Code native Settings navigation/captures passed. Existing Light/Dark/contrast/transparency/grayscale regression render tests passed. Shared primary/neutral/destructive normal/disabled button specimens rendered in both modes. |
| Build/run | `./script/build_and_run.sh --verify` succeeded with standard project signing, independent packages/DerivedData and a separate review preference suite. The launched review app uses live Binance endpoints. [Build/run record](binance-design/verification-2026-09-17/build-run.json). |

Earlier UI runs encountered an AX authorization/connection issue and incorrect
test queries: macOS static text exposes `value`, segmented pickers expose radio
groups/buttons, and selection is a numeric radio-button value. The final four
UI flows executed successfully after correcting those assertions; no product
assertion was removed. This is not a claim of a single all-green aggregate run.

The first build/run verification built and launched successfully but returned a
false process-check failure because `/tmp` and `/private/tmp` differ as strings.
Repeating the existing script with canonical `/private/tmp` environment paths
returned exit code 0. No shared build-script change was needed.

## Visual evidence

| Surface / state | Captures |
| --- | --- |
| Real Binance | [Live panel](binance-design/verification-2026-09-17/live-hover-panel.png), [installed Dock/Command-Tab image](binance-design/verification-2026-09-17/live-installed-dock.png), [measurements](binance-design/verification-2026-09-17/live-appkit-evidence.json) |
| Native interaction | [Custom color and live preview](binance-design/verification-2026-09-17/runtime-settings-custom-dark.png), [reset dashboard](binance-design/verification-2026-09-17/runtime-dashboard-reset-light.png), [shared chart Settings](binance-design/verification-2026-09-17/runtime-settings-shared-chart.png) |
| Dashboard fixtures | [Light](binance-design/verification-2026-09-17/dashboard-light.png), [Dark](binance-design/verification-2026-09-17/dashboard-dark.png), [custom candles + volume](binance-design/verification-2026-09-17/dashboard-custom-light-contrast.png), [grayscale](binance-design/verification-2026-09-17/dashboard-custom-dark-grayscale.png) |
| Full Settings content | [Automatic Light](binance-design/verification-2026-09-17/settings-automatic-light.png), [custom Dark + contrast](binance-design/verification-2026-09-17/settings-custom-dark-contrast.png), [grayscale](binance-design/verification-2026-09-17/settings-custom-dark-grayscale.png) |
| Counts / height | [0](binance-design/verification-2026-09-17/dashboard-0-pairs-small-screen.png), [1](binance-design/verification-2026-09-17/dashboard-1-pairs-small-screen.png), [2](binance-design/verification-2026-09-17/dashboard-2-pairs-small-screen.png), [20 pairs](binance-design/verification-2026-09-17/dashboard-20-pairs-small-screen.png); 3-pair layout in the normal matrix |
| Data states | [Loading](binance-design/verification-2026-09-17/dashboard-loading.png), [error](binance-design/verification-2026-09-17/dashboard-error.png), [stale](binance-design/verification-2026-09-17/dashboard-stale.png), [stale Dock](binance-design/verification-2026-09-17/dock-stale.png) |
| Custom Dock size | [32 pt](binance-design/verification-2026-09-17/dock-custom-dark-32.png), [48 pt](binance-design/verification-2026-09-17/dock-custom-dark-48.png), [64 pt](binance-design/verification-2026-09-17/dock-custom-dark-64.png), [128 pt](binance-design/verification-2026-09-17/dock-custom-dark-128.png), [grayscale](binance-design/verification-2026-09-17/dock-custom-light-grayscale.png) |
| Shared Settings/button regression | [General](binance-design/verification-2026-09-17/runtime-settings-general-light.png), [Claude Code](binance-design/verification-2026-09-17/runtime-settings-claude-light.png), [button specimens](binance-design/verification-2026-09-17/shared-buttons-light-reduce-motion.png) |

Inspected captures retain Pinned Focus hierarchy, tabular prices, explicit quote
and 24h labels, neutral dividers, distinct Pin/On Dock controls and readable
segmented options. Long Settings helpers wrap fully. Smaller-height dashboards
scroll cards beneath fixed controls instead of shrinking the header. Selected
swatches retain rings/checkmarks and candles retain hollow/filled direction in
grayscale. Brand color remains inside identity assets. The source Binance
favicon is still softer than a vector logo; this is inherited asset quality.

## Evidence boundaries

- The live panel capture calls `DockHoverPanelController.scheduleShow`
  directly. It verifies panel rendering and live data, not the system Dock
  accessibility observer or a physical pointer hover.
- Fixture render captures exercise real native views in offscreen AppKit
  windows. They are not screenshots of every physical Dock magnification or
  display arrangement.
- Increased Contrast and Reduce Transparency use the existing project
  accessibility overrides and AppKit appearances. Grayscale images convert
  the completed native raster because NSHostingView bitmap capture omits the
  GPU saturation modifier.
- Shared-button captures cover normal/disabled states and Reduce Motion
  overrides. Source review confirms the pressed-state branch; a full physical
  pressed-animation/VoiceOver pass is not implied by still images.
- Unicode text input and actual Vietnamese IME marked-text composition are
  different checks. Physical IME composition, every Dock edge and repeated
  system sleep/wake remain dedicated device-QA scenarios.
- No production signing, Hardened Runtime, package pins or unrelated feature
  edits were changed by this task. Independent packages and DerivedData avoid
  interfering with concurrent worktree builds. No publication was performed.
- Commercial data-use rights remain the separate unresolved item in
  [Binance research](BINANCE_INTEGRATION_RESEARCH.md).

Detailed input/chart/motion proposal v1 remains outside this implementation.

## Follow-up: dashboard does not open on Dock hover

On 2026-09-17, the user's Xcode Debug build was inspected separately from the
isolated review app. Read-only LLDB expressions in the restarted production
composition confirmed:

| Runtime check | Result |
| --- | --- |
| `DockMagicActiveFeature` | `binance` |
| `DockMagicDockHoverDashboardEnabled` | `true` |
| `AXIsProcessTrusted()` | `false` |

`DockHoverCoordinator.applyConfiguration` correctly stops the Dock observer
while Accessibility is not authorized, so the one-second presentation timer
cannot start. This is a permission prerequisite, not evidence of a missing
Binance dashboard route. No source, preferences, signing or system permissions
were changed during diagnosis. The app was restarted from the same Xcode
build path; the unrelated Grok review instance was left intact.

The user must authorize DockMagic in System Settings → Privacy & Security →
Accessibility. The existing coordinator rechecks authorization every five
seconds and when the app becomes active. Settings → Binance → Open dashboard
does not require Dock hover authorization. Actual Dock hover after permission
grant remains pending; native UI inspection also timed out in this session.
