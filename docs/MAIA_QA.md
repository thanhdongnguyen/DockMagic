# Maia migration verification

## Weather SVG scenes — 20 September 2026

All seven generated Weather PNGs were traced into original-color SVG paths;
the PNGs are retained under [weather scene originals](design/weather-scenes/originals/).
Each asset catalog entry preserves its vector representation, and the compiled
`Assets.car` reports both `Vector` and Xcode-generated raster renditions for
all seven names. XML validation found path geometry and no embedded bitmap.

The macOS app build and test-bundle build passed. Two direct XCTest cases passed:
condition-to-scene mapping and loading all seven named assets from the app
bundle. The [SVG render smoke test](../script/verify_weather_svg.swift)
produced 105 backdrop previews (seven scenes at 48 × 48, 96 × 96 and
440 × 420, across five appearance/accessibility variants). Each
scene was distinct; sampled minimum white-text contrast was 5.33:1 Light,
8.26:1 Dark, 8.10:1 Increased Contrast and 8.62:1 grayscale. These are
offscreen reproductions of the backdrop, not end-to-end snapshots of the
glyph/text overlay or a physical Apple Dock/dashboard interaction. Two
`xcodebuild test` attempts stalled in Xcode's test host before the selected
render cases executed; those XCTest renders remain unverified. `Design.md`
lint has 0 errors and 34 orphan-token warnings.

## Codex blue data accent — 18 September 2026

The user reference resolves to sRGB #0088FF after applying its embedded Color
LCD profile. Codex now passes this data accent to quota progress, daily/hourly
charts, Ship momentum, Daily intensity, Top models and activity export. Light
uses #006BC9; inset data text uses #006BC9 Light / #008FFF Dark. Asset-based
contrast calculations give a minimum 4.59:1 for that text and 5.09:1 for the
active rank numeral. Neutral controls, status thresholds, other providers and
saved Dock colors remain independent.

Six existing focused tests passed: native dashboard/detail rendering, 4×
dashboard capture, settled gauge, all six momentum ranks, dashboard capture
appearance/edge matrix and Save/Copy/Share activity artifacts. The all-ranks
fixture now uses Codex's production data role. Light/Dark, Increased Contrast,
Reduce Transparency and grayscale output were inspected. Grayscale evidence
uses the export's raster conversion: the native offscreen grayscale host can
omit its content. These are fixture renders, not live-account or Dock-hover
interaction proof. `Design.md` lint has 0 errors and the existing 20 orphaned
token warnings; the pinned Maia resource audit passes unchanged.
`./script/build_and_run.sh --verify` built and launched the updated main app;
deep/strict codesign verification passed.

Evidence: [Dark](qa/maia/codex-blue/dashboard-dark.png),
[Light](qa/maia/codex-blue/dashboard-light.png),
[Grayscale](qa/maia/codex-blue/dashboard-grayscale.png),
[momentum ranks](qa/maia/codex-blue/momentum-ranks.png).

## Selection control follow-up — 17 September 2026

The user's follow-up removes the former native segmented-picker exception.
`DSSegmentedControl` now owns short single-choice groups in Settings and hover
dashboards. `DSSelect` owns dropdowns, including Active Dock Feature, Search
Console properties and Now Playing sources. Appearance, Clock style, shared
Dock display, GitHub, Search Console, Binance, Claude and OpenCode
selection callers retain their existing bindings and persistence. Features
without these selectors inherit the shared components without new controls.
DatePicker and system-owned dialogs remain native. A source regression test
rejects rendered `Picker`/`pickerStyle` in feature views.

Validation of this follow-up:

- Focused suite: 86 cases, 83 passed, 1 opt-in live capture skipped, 2 existing
  strict expected undo-harness failures; no unexpected failures. After keyboard
  focus changes, the five selection/gallery/all-Settings tests passed again.
- Production selection renders cover Light/Dark, Increased Contrast, Reduce
  Transparency, Reduce Motion and grayscale. All 18 Settings destinations render
  in the existing appearance matrix. The broader run also covers Binance,
  Calendar, Now Playing and provider dashboard/capture fixtures.
- Native gallery: AXPress changes selection; Left/Right skip a disabled option;
  Tab skips the disabled option; Return selects the focused option. These were
  verified by reading selected state, focused element and bound fixture value.
  The first keyboard run exposed disabled focus stops; explicit focus eligibility
  fixed them. Select popup visuals were inspected on a real window.
- Child-popover keyboard traversal and physical Dock hover remain unverified.
  Orca can capture the child popup but resolves its accessibility tree to the
  parent window. VoiceOver traversal is not claimed by these checks.
- Final main app: `./script/build_and_run.sh --verify` succeeded, and
  `codesign --verify --deep --strict` passed for `.derivedData/Build/Products/Debug/DockMagic.app`.
  The normal Settings window was opened with existing user preferences; the QA
  gallery used its separate defaults suite.
- `Design.md` lint: 0 errors, the same 20 documented orphaned-token warnings.

Evidence: [Light](qa/maia/selection/selection-light-standard.png),
[Dark](qa/maia/selection/selection-dark-standard.png),
[native segmented keyboard](qa/maia/selection/native-segment-keyboard.png),
[native select popup](qa/maia/selection/native-select-popup.png),
[native interaction records](qa/maia/selection/native-interactions.json).

## Original migration scope

Scope: approved `bbVKHJo / base-maia` native migration, 17 September 2026.
Implementation covers the current Settings destinations, dashboard compositions,
Dock renderers, production previews and exports. Full interactive acceptance is
**not yet established**: XCTest UI automation cannot initialize, and Orca cannot
reliably target child-popover keyboard focus. Main-window native interactions
were verified through Orca. Source, fixture renders, AppKit tests and physical
Dock interaction are separate evidence.

## Implemented scope

| Phase | Implemented result |
| --- | --- |
| Foundation and gallery | Pinned OKLCH palette, Geist four weights with glyph cascade, 106 template HugeIcons, opaque Light/Dark surfaces, production component gallery |
| Pilot | Codex Settings/dashboard, Binance search/chart controls, Calendar form/editor; native text editing and DatePicker retained |
| Settings | All 18 destinations (including General), About/update composition use shared typography, icons, controls, sections, renderer colors and production previews |
| Dashboards | Shared panel/header/identity, quota/metric/chart chrome, history viewport, status and export actions; provider capability and data semantics remain feature-owned |
| Dock/export | Geist and semantic frame/track/foreground; saved renderer colors preserved; activity/quota eligibility and layouts retained; legacy kind/material/font/icon styles removed |

### Shared AI history chart follow-up — 18 September 2026

Claude Code and OpenCode render daily history through
`AIUsageHistoryChart`. Claude's compatibility view only maps token/cost values
and its empty message. OpenCode passes its persisted appearance
color into the dashboard after a 3:1 contrast correction; Claude keeps its
existing clay data color. OpenCode applies the same resolved color to daily and
hourly plots. Provider-specific data semantics, metric formatting, missing and
partial states remain owned by each feature.

Focused verification passed for the shared-source contract, Codex pointer/scroll
behavior, Claude native scroller geometry across Tokens/Cost, overlay/always
visible scrollers and 360/428/548 pt widths, plus the OpenCode
Light/Dark/contrast/transparency/motion/grayscale matrices. Reviewed renders are
in `/private/tmp/dockmagic-shared-chart-qa` and
`/private/tmp/dockmagic-opencode-qa`.

The 63 registry entries are mapped or explicitly deferred in
[MAIA_COMPONENT_CATALOG.md](MAIA_COMPONENT_CATALOG.md). Deferred entries have no
current feature consumer. The snapshot and native resources are checksum-pinned;
normal builds do not fetch a registry, npm package or font.

## Verified evidence

- Native font tests resolve Regular/Medium/SemiBold/Bold PostScript names and
  produce nonzero glyphs for Vietnamese NFC/NFD, numerals and `₫` via the cascade.
- Every bundled icon and existing domain icon mapping resolves. Resource audit
  checks 220 native files, 31 Light/Dark color assets with alpha, and the immutable
  63-component registry snapshot.
- Contrast tests cover semantic text/action pairs in both appearances. The
  specific deviations from upstream Neutral are recorded in `Design.md`.
- Production gallery and component fixtures render in Light/Dark, Increased
  Contrast, Reduce Transparency, Reduce Motion and grayscale. Image review found
  and corrected appearance propagation, hidden Toggle labels and compact control
  border artifacts; capsules now use explicit circular paths.
- Settings render tests cover every destination in System/Light/Dark; connection
  cards also cover 1160 × 620, 1360 × 700 and accessibility variants. Dock render
  tests cover multiple sizes including 32, 48, 64 and 128 points.
- Fixtures distinguish measured zero, unavailable, stale, partial, error with old
  data, unsupported capabilities and nonfinite numeric input. Provider tests
  preserve activity versus quota scope and missing-day chart gaps.
- Native AppKit tests exercise Vietnamese marked-text composition, NFC/NFD paste,
  editor undo, slider arrow stepping/clamping, export menu activation inside a
  nonactivating panel and nested popup interaction leases. They do not establish
  physical Dock hover or full keyboard/VoiceOver traversal.
- Search Console renderer colors persist through a new store instance and Reset
  Defaults preserves the connection. Existing appearance/color defaults remain
  fixture-tested with separate defaults suites.
- Save/Copy/Share image tests check shared output, opaque 1200 × 1200 activity
  cards, selected metrics, latest history, four-times rasterization and preserved
  provider eligibility. Native Share UI itself remains a system adapter.

The broad serial unit run executed 616 cases: 599 passed, 10 opt-in cases
skipped, 2 strict expected harness failures and 5 failures. Four failures are
unchanged baseline behavior listed below. The fifth was an incorrect grayscale
expectation in the Clock render test: user-selected content colors must remain
colored. The expectation was corrected; its separate retest passed.

Final focused run after the popup action correction: **83 cases, 80 passed, 1 opt-in skipped, 2 strict expected
harness failures, no unexpected failures**. A final geometry pass then reran all
Settings in System/Light/Dark plus the native gallery in Light/Dark: both tests
passed. `./script/build_and_run.sh --verify` built and launched the final Debug
app with the isolated `DockMagic.Maia.QA` defaults suite. Deep/strict codesign
verification passed, including nested Sparkle bundles; all four Geist fonts and
third-party notices are present. This is a local Debug verification, not release
notarization. Machine-readable results: [verification.json](qa/maia/verification.json).

Gallery artifacts: [Light](qa/maia/gallery-light.png), [Dark](qa/maia/gallery-dark.png).
Settings examples: [General Light](qa/maia/settings-general-light.png),
[Binance Dark](qa/maia/settings-binance-dark.png),
[Calendar Light](qa/maia/settings-calendar-light.png),
[Claude Dark](qa/maia/settings-claude-dark.png).
[Capture menu](qa/maia/codex-export-menu.png) and
[activity export](qa/maia/antigravity-activity-export.png).
These are production NSHostingView/ImageRenderer renders, not screenshots of
manual interaction.

## Known baseline failures and harness limits

Four unrelated startup/Claude tests also fail on the **pre-migration working-tree
snapshot**, reproduced in a separate checkout and DerivedData directory:

1. `DockMagicTests.testAppModelRunsSelectedFeatureAndBackgroundStreakCollection`
2. `DockMagicTests.testSelectingClaudeCodeInstallsCLIBeforeDockMagicBridge`
3. `StartupRecoveryTests.testClaudeAutomaticallyRecoversWhenLocalSnapshotBecomesReadable`
4. `StartupRecoveryTests.testClaudeExternalFailureRearmsAnExistingLongPollingDelay`

`ClaudeCodeUsageStore.swift`, `DockAppModel.swift` and `StartupRecoveryTests.swift`
match the pre-migration snapshot byte-for-byte. This migration does not alter
provider authentication/recovery behavior to suppress those failures.

The direct `NSTextView` undo fixture changes the editor's text correctly, but the
offscreen `NSHostingView` harness leaves the SwiftUI binding at its previous
value. An unstyled `TextField` reproduces the same result. Both comparisons keep
that assertion as a **strict expected failure**; it is not counted as end-to-end
Command-Z acceptance. The actual running gallery was subsequently verified
through Orca: Vietnamese Unicode entry, Command-Z restoration and Tab to the
secure field retain the restored value. The expected failure remains a harness
comparison, not an observed production undo defect.

XCTest UI initialization failed with `Timed out while enabling automation mode`.
CUA application selection also timed out. No XCTest UI cases ran through those
attempts. A fallback through the `computer-use` skill's Orca CLI succeeded for the
running gallery: Vietnamese Unicode entry, Command-Z, Tab, primary action,
Cancel via AXPress, Escape and Return. It exposed and verified the fix for popup
dismissal being bypassed by AXPress: `DSDialogButton`/`DSMenuButton` now include
dismissal in their actual Button action. The UI regression case also asserts
Cancel and menu-action dismissal. [Native evidence](qa/maia/native-interactions.json),
[undo after Tab](qa/maia/native-undo-after-tab.png),
[dialog](qa/maia/native-dialog.png).

Orca can capture popovers but cannot reliably target their accessibility tree or
keyboard focus (`window_not_focused`); those checks remain unverified. Still
requiring direct validation:

- Tab/Shift-Tab, arrow/Enter/Space, Escape, default/cancel and trigger focus return
  throughout real Settings and nested hover popups.
- Vietnamese input-method keystrokes, secure-input editing and long text;
  VoiceOver labels/order/state announcements. Unicode entry and Command-Z binding
  in the real main window passed the narrower checks above.
- Physical Dock click/continuous one-second hover with Accessibility permission;
  child popup interaction and key-window restoration while moving the pointer.
- Live permission/file/Share panels, real provider sign-in/sign-out and clipboard
  export. Fixture behavior does not establish live-account provider results.

## Reproduce

Use the existing Xcode package cache or resolve the pinned package graph first.
The script accepts isolated DerivedData/package paths via environment variables.

```sh
python3 script/verify_maia_resources.py
./script/test_maia_design_system.sh
./script/test_maia_design_system.sh --all-unit
./script/test_maia_design_system.sh --ui
./script/build_and_run.sh --verify
npx --yes @google/design.md@0.4.0 lint Design.md
```

Optional `TEST_RUNNER_DockMagicMaiaRenderDirectory` saves production render PNGs
outside the result bundle. To launch the debug gallery with separate defaults:

```sh
DockMagicUITesting=1 \
DockMagicUITestDefaultsSuite=DockMagic.Maia.QA \
DockMagicMaiaGallery=1 ./script/build_and_run.sh --verify
```

`Design.md` lint reports no errors. Its 20 orphaned-token warnings concern native
semantic/state roles not referenced by the interchange YAML component subset;
the roles are consumed by the Swift palette and documented native components.
They are retained rather than replaced with artificial YAML references.
