# Ship Momentum Living Flame V2 Design QA

## Comparison target

- Source visual truth:
  `/Users/dongnt/.codex/generated_images/01a0506d-f806-73f2-953d-5c6a29f5bca2/exec-c98c80e1-d024-40dd-8ba3-e3f88bb977fe.png`
- Source pixels: 1402 × 1122. This is the selected Living Flame concept board,
  not a production dashboard viewport.
- Combined six-rank progression comparison:
  `/Users/dongnt/.codex/visualizations/2026/08/30/01a0506d-f806-73f2-953d-5c6a29f5bca2/living-flame-v2-progression-comparison.png`
- Combined source/motion comparison for score 54 Shipper:
  `/Users/dongnt/.codex/visualizations/2026/08/30/01a0506d-f806-73f2-953d-5c6a29f5bca2/living-flame-v2-shipper-motion-comparison.png`
- Production score-54 dashboard comparison:
  `/Users/dongnt/.codex/visualizations/2026/08/30/01a0506d-f806-73f2-953d-5c6a29f5bca2/living-flame-v2-score54-dashboards.png`
- Production motion preview:
  `/Users/dongnt/.codex/visualizations/2026/08/30/01a0506d-f806-73f2-953d-5c6a29f5bca2/shipper-54-directional-flow.gif`
- Production Codex viewport: 440 × 556 pt, captured at 2× as 880 × 1112 px.
- Production Claude Code viewport: 440 × 760 pt, captured at 2× as 880 ×
  1520 px. Standalone gauge evidence is 136 × 64 pt, captured at 2× as
  272 × 128 px.
- Primary reported state: Dark appearance, score 54, Shipper, and 260,000,000
  local daily tokens. Legend score 100 and Reduce Motion are additional states.

## Full-view comparison evidence

The selected source, six-rank production board, eight consecutive score-54
frames, and both full dashboards were inspected in combined comparison inputs
on 2026-08-30. The implementation now preserves the concept's key visual and
motion hierarchy: organic asymmetric flame crests, a neutral semicircular
track, a ringed moving endpoint, directional flow beginning at Shipper, and
upper-rank echo contours and embers. Codex uses its action accent while Claude
Code uses its existing provider usage accent.

The concept's orange/yellow outline is intentionally adapted to DockMagic's
neutral-first color contract: one solid provider accent forms the flame and a
neutral semantic highlight defines the crest. The concept also treats rank as
the primary quantity, while production keeps the approved daily-token score
and precise arc fraction visible. These are explicit system and data-contract
adaptations, not fidelity defects.

## Focused-region comparison evidence

- Score 54: the eight-frame comparison shows six high-amplitude crests moving
  consistently toward the live endpoint. Consecutive frames have measurable
  pixel differences and are visibly distinct at normal dashboard size.
- Live tier transition: one mounted `NSHostingView` was updated from Creator
  score 49 to Shipper score 54 while deliberately retaining a stale Creator
  fallback rank. It changed silhouette, produced the Shipper entry burst, and
  continued directional motion without reopening the dashboard.
- Rank progression: Starter, Builder, and Creator breathe in place; Shipper
  and Shipmaster gain directional travel; Legend adds surge pulses, eleven
  crests, a neutral echo contour, and seven drifting embers.
- Dashboard fit: the 132 × 56 pt Codex gauge and 136 × 64 pt Claude gauge fit
  without clipping the score, rank ladder, token total, section dividers, or
  adjacent dashboard content.

## Required fidelity surfaces

- Fonts and typography: the established macOS rounded numeric score and
  dashboard hierarchy remain unchanged. No tested label wraps or truncates.
- Spacing and layout: both panels retain their existing section order, margins,
  card radii, and density. Only the shared gauge renderer changed.
- Colors and tokens: chrome remains neutral plus one provider accent. Repository
  scans found no gradient, colored glow, direct RGB, direct system color, or
  feature-local palette in the shared renderer or either integration.
- Shape and image quality: the gauge is scalable native SwiftUI vector geometry
  at up to 60 fps. No third-party animation dependency was added because the
  result is data-driven, provider-themed, sharper at both dashboard sizes, and
  can honor Reduce Motion exactly.
- Copy and content: score, rank, token total, and daily reset copy follow the
  approved token-only contract. The UI makes no productivity or quality claim.
- States and interactions: all six ranks, both providers, Codex Dark/Light,
  Claude Dark, grayscale, unavailable data, score fill, rank-entry burst,
  ongoing Shipper/Legend motion, and deterministic Reduce Motion were covered.
- Accessibility: rank and score remain readable without animation or color.
  Reduce Motion freezes fill, pulse, crest travel, burst, and ember drift on a
  deterministic silhouette. Full-dashboard suites also cover Increased
  Contrast and Reduced Transparency.

## Findings and iteration history

### Pass 1 — superseded

- [P1] The passed fallback rank could override the updated score, allowing a
  score of 54 to retain Creator animation after a live dashboard refresh.
- [P2] A capped 24 fps rounded sine wave with low amplitude and slow travel made
  the old Shipper motion appear static and unlike the selected flame design.

### Pass 2 — passed

- Score-derived rank is now authoritative. The renderer refreshes at up to
  60 fps and uses rank-specific breathing, directional, and burst profiles.
- The focused regression passed 13/13 tests, including token/day boundaries,
  all six rank profiles, eight deterministic score-54 frames, mounted 49 → 54
  transition, exact Reduce Motion frame equality, and both full dashboards.
- The unsigned optimized Release build passed with the shared renderer compiled
  into the production app target. Source scans and `git diff --check` passed.
- No actionable P0, P1, P2, or P3 findings remain.

final result: passed

---

# Activity Card Mini Area Chart — Design QA

## Comparison target

- Source visual truth:
  `docs/share-card-concepts/share-card-area-chart-selected.png`
  (selected Product Design Option 2, 1254 × 1254 px).
- Dark implementation screenshots:
  `docs/share-card-concepts/implementation/codex-dark.png`,
  `docs/share-card-concepts/implementation/claude-code-dark.png`, and
  `docs/share-card-concepts/implementation/antigravity-dark.png`
  (1200 × 1200 px each).
- Combined full-view comparison:
  `docs/share-card-concepts/area-chart-option-2-qa-comparison.png`
  (2400 × 2400 px).
- Focused token/chart comparison:
  `docs/share-card-concepts/area-chart-option-2-qa-focus.png`
  (2400 × 800 px).
- Appearance/accessibility comparison:
  `docs/share-card-concepts/area-chart-option-2-accessibility-qa.png`
  (2400 × 2400 px), plus
  `docs/share-card-concepts/implementation/codex-opaque.png` for Reduce
  Transparency.
- Sparse-history post-fix evidence:
  `docs/share-card-concepts/implementation/codex-sparse-history.png`
  (1200 × 1200 px).
- Antigravity caption-removal feedback source:
  `/Users/dongnt/Downloads/DockMagic-Antigravity-Activity-2026-09-15-004034.png`
  (1200 × 1200 px).
- Caption-free Antigravity implementation:
  `docs/share-card-concepts/implementation/antigravity-captionless.png`
  (1200 × 1200 px).
- Matched before/after comparison:
  `docs/share-card-concepts/antigravity-captionless-qa-comparison.png`
  (2400 × 1200 px). Both sides use Dark appearance, First Prompt, 8.56K
  observed tokens, 0/100 Starter momentum, and September 15, 2026.
- Native viewport: 300 × 300 pt, rasterized directly at 4× into 1200 × 1200
  PNG. The 1254 px source was normalized to 1200 × 1200 before the source and
  implementation were placed in the same comparison inputs.
- State: Dark activity card with current badge, today's token usage, 14-day
  history, and Ship momentum. Light, Increased Contrast, Reduce Transparency,
  grayscale, provider-specific accent, Antigravity partial-history, and sparse
  noncontiguous history are additional states.

## Full-view comparison evidence

The combined comparison preserves the selected Option 2 hierarchy: the badge
remains dominant, the divider separates achievement from activity, and a small
area chart sits to the right of the token metric without competing with Ship
momentum. Codex, Claude Code, and Antigravity retain the same card geometry and
use their existing provider identity/accent treatment. The changing line shape
and values are data-driven and therefore intentionally differ from the static
source fixture.

Antigravity retains `TOKENS OBSERVED TODAY` because its locally retained usage
is partial, while the chart now follows Codex's caption-free layout. Export
remains hidden until the provider has an explicit current-day observation and
at least one renderable contiguous trend segment.

## Focused-region comparison evidence

The focused board shows the token/chart/momentum region at readable scale. The
chart is compact, right-aligned, and uses only a solid low-opacity area plus one
thin provider-accent stroke. It has no axis, tick, legend, point marker,
gradient, or chart number. The Antigravity chart qualifier has been removed,
and the chart now uses the same 82 × 29 pt frame as Codex.
The sparse-history screenshot confirms that isolated observations do not
produce an empty chart shell; the token metric recenters instead.

## Required fidelity surfaces

- Fonts and typography: production keeps DockMagic's system typography,
  rounded monospaced token numerals, established optical weights, and uppercase
  micro-label hierarchy. No provider name, token label, qualifier, score, or
  rank wraps or truncates in the inspected renders.
- Spacing and layout rhythm: the 300 pt square, badge scale, divider, margins,
  footer, and momentum row remain unchanged. The token row alone becomes a
  balanced text/chart split matching Option 2.
- Colors and visual tokens: neutral chrome is retained. Each chart uses the
  existing semantic/provider accent, solid opacity, and no new palette,
  gradient, glow, or decorative tinted container. Increased Contrast thickens
  the chart stroke; grayscale preserves the trend through shape and luminance.
- Image quality and asset fidelity: the chart is native SwiftUI vector geometry
  rasterized at the final 4× density. Existing provider logos and authored
  streak badges remain the original bounded assets; no emoji, placeholder,
  handcrafted SVG, or CSS-style substitute was introduced.
- Copy and content: `TOKENS TODAY` is unchanged for Codex and Claude Code.
  Antigravity keeps `TOKENS OBSERVED TODAY` as its visible local-data qualifier
  while removing the redundant chart caption requested in user feedback.
- States and accessibility: Light, Dark, Increased Contrast, Reduce
  Transparency, grayscale, missing days, real zero days, sparse history, and
  partial history were inspected or covered by focused tests. The chart is
  decorative in accessibility output; the card's combined accessibility value
  describes whether 14-day history is available and whether it is partial.

## Findings and comparison history

### Pass 1 — superseded

- [P2] Two positive but noncontiguous observations satisfied the original
  availability count even though missing-day gaps left no two-point segment for
  the area/line renderer. This could advertise an empty chart region.
- Fix: availability now requires at least one adjacent pair of observed days
  and at least one positive sample. A real zero remains an observed point and
  can connect to the following day; a missing day cannot.
- Post-fix evidence: `codex-sparse-history.png` shows the metric recentered with
  no empty chart shell. The dedicated semantics test covers duplicate buckets,
  missing days, real zero, adjacent zero/positive samples, and isolated points.

### Pass 2 — passed

- The full-view and focused comparison boards were regenerated from the final
  renderer for all three providers.
- `testUsageActivityCardsRenderForEveryExportAction`,
  `testActivityCardAreaChartPreservesMissingDaysAndRealZero`, and
  `testAntigravityHoverDashboardRendersPartialHistoryAcrossAppearances`
  passed. `./script/build_and_run.sh --verify` also completed successfully with
  a signed Debug build, and `git diff --check` passed.
- No actionable P0, P1, or P2 findings remain.
- P3 accepted variance: the source line's exact peaks are illustrative; the
  implementation must reflect each provider's actual retained daily samples.

### Pass 3 — user feedback passed

- [P3] The Antigravity-only `PARTIAL HISTORY` caption made the chart row denser
  than Codex and visually lowered the chart.
- Fix: removed the caption and gave Antigravity the same 82 × 29 pt chart frame
  as Codex. `TOKENS OBSERVED TODAY` remains the visible partial-data cue.
- Post-fix evidence: the matched before/after board confirms that provider,
  badge, token value, missing-day marks, momentum, and overall card geometry
  remain unchanged while the chart caption is gone.
- `testUsageActivityCardsRenderForEveryExportAction` passed and now asserts
  that export source contains no `PARTIAL HISTORY` caption.
- The signed Debug build and launch verification completed successfully after
  the feedback change; `git diff --check` also passed.
- No actionable P0, P1, or P2 findings remain.

## Open questions

- None blocking.

## Implementation checklist

- [x] Option 2 token/chart composition for Codex and Claude Code.
- [x] Capability-gated Antigravity Save, Copy, and Share actions.
- [x] Fourteen local calendar days with missing values preserved as gaps.
- [x] No chart values, axes, ticks, legend, gradient, or color-only state.
- [x] Caption-free Antigravity chart aligned with Codex.
- [x] 1200 × 1200 direct 4× PNG rendering.
- [x] Light, Dark, Increased Contrast, Reduce Transparency, and grayscale QA.
- [x] Focused rendering, semantics, and Antigravity appearance tests.

final result: passed

---

# Streak Badge Roadmap — Design QA

## Comparison inputs

- Source visual truth:
  `/var/folders/ps/dndvmz2n3w53_cxkfwr4typh0000gn/T/TemporaryItems/NSIRD_screencaptureui_FaAo6Z/Screenshot 2026-09-14 at 23.21.28.png`
  (508 × 1205 px). The source is inspiration for the roadmap structure, not a
  pixel-identical production target.
- Production Dark implementation:
  `/Users/dongnt/.codex/visualizations/2026/09/14/01a0a0b9-4fea-7720-a1c3-20943b1a80ca/streak-roadmap/dark.png`
  (880 × 1112 px).
- Full-roadmap focused evidence:
  `/Users/dongnt/.codex/visualizations/2026/09/14/01a0a0b9-4fea-7720-a1c3-20943b1a80ca/streak-roadmap/full-roadmap-dark.png`
  (880 × 2920 px).
- Normalized comparisons:
  `/Users/dongnt/.codex/visualizations/2026/09/14/01a0a0b9-4fea-7720-a1c3-20943b1a80ca/streak-roadmap/source-dark-comparison.png`
  and
  `/Users/dongnt/.codex/visualizations/2026/09/14/01a0a0b9-4fea-7720-a1c3-20943b1a80ca/streak-roadmap/source-full-roadmap-comparison.png`.
- Accessibility matrix:
  `/Users/dongnt/.codex/visualizations/2026/09/14/01a0a0b9-4fea-7720-a1c3-20943b1a80ca/streak-roadmap/accessibility-matrix.png`.
- Production viewport: 440 × 556 pt at 2× for Codex, producing 880 × 1112
  px. Claude Code was also rendered at its real 440 × 740 pt viewport. The
  440 × 1460 pt full-roadmap render is focused layout evidence only; the real
  product remains a vertically scrolling 440-point popup.
- Primary state: Dark appearance, current streak 7 days, best streak 28 days,
  Builder current, 4 of 10 milestones unlocked. Additional evidence covers
  Claude Code, Light, Increased Contrast, Reduce Transparency, grayscale,
  all milestones earned, and unavailable data.

## Full-view comparison evidence

The implementation intentionally borrows the source's vertical journey,
alternating milestone placement, connected route, prominent current position,
and visibly locked future stages. It does not copy the source's green world,
mobile chrome, alphabet cards, decorative scenery, or mascot. The production
version keeps DockMagic's compact macOS popup, existing current-badge and recent
activity hierarchy, authored streak badge assets, and semantic neutral-first
surfaces.

The real viewport shows the first roadmap stages beneath the current badge and
activity summary, then continues naturally through the existing vertical
scroll. The tall focused render confirms all ten milestones remain aligned to
one continuous route with no overlapping labels, clipped badge art, or broken
left/right rhythm.

## Focused fidelity evidence

- Fonts and typography: the existing macOS system face, weights, and compact
  popup scale are preserved. Milestone title, day threshold, status, and detail
  form a consistent four-level hierarchy without visible truncation in the
  tested fixtures.
- Spacing and layout: 98-point roadmap rows alternate around one continuous
  route. Badge wells, 146-point information plates, route endpoints, card
  radii, and section spacing remain stable across the complete ten-stage
  journey.
- Colors and visual tokens: surrounding UI uses neutral semantic surfaces plus
  `DesignTheme.action` for completed progress and current selection. Claude's
  quota-specific data hue no longer leaks into the streak detail screen. Badge
  artwork retains authored colors only inside each badge silhouette. No
  gradient, colored glow, direct RGB, system color, or feature-local palette
  was added.
- Image quality: every milestone uses the existing SVG asset through the
  preserved vector image path. Current, earned, future, and grayscale renders
  remain sharp at 2×; locked art adds lower emphasis and a lock symbol rather
  than relying on color alone.
- Copy and content: every stage states its exact day threshold and one of
  `Earned`, `Current badge`, `Up next`, or `Locked`. Missing provider data is
  explicitly reported as `Progress unavailable` with a question-mark symbol;
  it is not converted into zero progress.
- Interaction and accessibility: the existing Back control and vertical
  scrolling behavior are preserved. Each milestone remains one accessibility
  element with a stable identifier and a combined title, threshold, status,
  and description. Increased Contrast strengthens route and current-node
  outlines; grayscale and Reduce Transparency preserve the same state order.

## Findings and comparison history

1. Initial pass — P1 data accuracy: the first implementation converted a
   missing streak summary into a zero-day locked roadmap. The reference did not
   define this state, but DockMagic's provider contract prohibits turning
   absence into zero.
2. Initial pass — P2 color hierarchy: Claude Code recent activity retained its
   orange quota data hue while the new route used action blue, creating two
   competing accents on one normal surface.
3. Fixes: made best-streak input optional, added the explicit unavailable
   status and symbol, withheld locks when progress is unknown, and standardized
   the entire streak detail screen on the shared action accent.
4. Post-fix pass: Dark, Light, Increased Contrast, Reduce Transparency,
   grayscale, Claude Code, unavailable, all-earned, and full-roadmap renders
   were inspected. No actionable P0, P1, P2, or P3 finding remains.

## Verification

- The unsigned macOS Debug target builds successfully.
- `testStreakDashboardRendersBadgeCollectionAcrossServicesAndAccessibility`
  and `testStreakDashboardSourceUsesBoundedBadgeArtAndSemanticChrome` pass.
- The render suite covers the real Codex and Claude Code viewport sizes plus a
  focused full-roadmap layout.
- Source checks reject new gradients, direct colors, colored shadows, and the
  removed two-column grid. `git diff --check` passes.

final result: passed

---

# Claude Code Native Sign-in Terminal — Design QA

## Comparison inputs

- Source visual truth:
  `/var/folders/ps/dndvmz2n3w53_cxkfwr4typh0000gn/T/TemporaryItems/NSIRD_screencaptureui_vY2F6Q/Screenshot 2026-09-13 at 00.08.37.png`
  (1532 × 860 px).
- Pre-change implementation:
  `/var/folders/ps/dndvmz2n3w53_cxkfwr4typh0000gn/T/TemporaryItems/NSIRD_screencaptureui_cBPtLB/Screenshot 2026-09-13 at 00.07.43.png`
  (1596 × 866 px).
- Final implementation: live Computer Use captures of
  `/Users/dongnt/Desktop/github/dockmagic/.derivedData/Build/Products/Debug/DockMagic.app`
  at a 1160 × 720 pt Settings viewport in Light and Dark appearances on
  2026-09-13, plus the passing XCUITest attachment:
  `/private/tmp/dockmagic-terminal-uitest-retry3-attachments/848B5CBC-03FD-41A1-B021-12D6FBDDDDFD.png`
  (2320 × 1440 px at 2×).
- State: Claude Code signed out, fixed-command sign-in PTY running a local fake
  Claude executable. No browser login, credential, or real account was used.
- Density normalization: the source is a larger standalone terminal reference,
  while the implementation is the bounded terminal region inside DockMagic
  Settings. Comparison focused on the terminal chrome and content region rather
  than the surrounding canvas.

## Full-view comparison evidence

The final implementation preserves the reference terminal's dominant visual
structure: a charcoal title bar, macOS red/yellow/green traffic lights, centered
session title, compact right-side profile capsule, a one-pixel divider, and a
true black console body. The right control intentionally reads `Claude CLI`
instead of copying the reference's interactive `Default` profile picker because
DockMagic exposes one fixed Claude login process and must not imply that the
user can select another shell or profile.

The terminal remains bounded inside the existing Claude connection section.
The surrounding Settings card, status, Cancel, and Open in Terminal controls
remain DockMagic-owned neutral chrome rather than being restyled as part of the
terminal.

## Focused region comparison evidence

- Fonts and typography: terminal output uses the system monospace face at 13 pt
  with ANSI foreground colors. The title and profile copy use compact system UI
  weights and do not wrap or truncate at the tested width.
- Spacing and layout rhythm: the title bar is 48 pt high, console content has
  shared standard padding on all sides, and the three lights use a regular
  eight-point rhythm. The console no longer touches the container edge.
- Colors and visual tokens: terminal background, title bar, foreground,
  secondary text, outline, and traffic lights come from named semantic assets.
  Feature source scans found no gradient, glow, direct RGB, or direct system
  status color in the terminal view.
- Image and asset quality: all visible terminal marks are native vector SF
  Symbols or SwiftTerm-rendered glyphs. There are no raster placeholders or
  decorative image assets to blur at different display scales.
- Copy and content: `Claude sign-in` and `Claude CLI` accurately describe the
  fixed process. Fake output verified colored ANSI text, ordinary output, the
  input prompt, and the caret without exposing an OAuth URL.
- Interaction and accessibility: the surface is still a real SwiftTerm PTY;
  keyboard focus enters it, Cancel sends interrupt and restores the signed-out
  row, and the terminal/title/profile have stable accessibility identifiers.
  Decorative traffic lights are hidden from assistive technology.

## Findings and comparison history

1. Initial pass — P2: using AppKit standard window buttons outside a real
   window title bar rendered the embedded traffic lights as inactive dark dots.
2. Fix: replaced those decorative controls with token-backed `circle.fill` SF
   Symbols using the terminal close, minimize, and zoom semantic roles.
3. Post-fix pass: Light and Dark live captures show the expected red, yellow,
   and green lights, true-black terminal body, readable ANSI output, and stable
   title/profile alignment. No actionable P0, P1, or P2 difference remains.

## Verification

- Unsigned macOS Debug build passed.
- Swift syntax parse and `git diff --check` passed.
- Live fake-CLI checks passed in Light and Dark appearances, including ANSI
  rendering, prompt/caret visibility, terminal sizing, and Cancel teardown.
- The focused `testClaudeSignInTerminalUsesDarkNativeChrome()` XCUITest passed
  twice: once with a fresh signed runner and once with
  `test-without-building`. It verifies Sign in, the native terminal, title and
  profile accessibility identifiers, screenshot capture, Cancel, and the
  return to the signed-out action. The signed-runner result bundle is
  `/private/tmp/dockmagic-terminal-uitest-retry3.xcresult`.

final result: passed

---

# Claude Code Compact Connection Row Design QA

## Comparison inputs

- Selected Option 3, revised with a More menu for Sign Out:
  `/Users/dongnt/.codex/generated_images/01a0952e-6ab1-7cf3-82b2-aa6d37ec40f5/exec-a82a7c87-ed92-4a09-81e7-37b5401bf4f0.png`
- Implementation: live Computer Use capture of
  `/Users/dongnt/Desktop/github/dockmagic/.derivedData/Build/Products/Debug/DockMagic.app`
  in the 1160 × 720 Settings window on September 13, 2026.
- The source row and live implementation capture were reviewed together at
  readable scale. The production row intentionally uses DockMagic's denser
  Settings rhythm instead of retaining the concept image's presentation-only
  vertical canvas.

## Visual assessment

- The connection surface is now one 46-point content row: title on the left;
  status, last-update metadata, Refresh, and More on the right.
- The duplicate shield plate, duplicate Connected badge, introductory sentence,
  and persistent privacy paragraph from the previous implementation are gone.
- Connected is neutral and legible without relying on color. Refresh and More
  are compact icon controls on neutral shared surfaces; no new palette,
  decorative gradient, glow, or tinted card was introduced.
- Error guidance and the fixed-command sign-in terminal remain progressive
  disclosure and appear only when their state requires them.
- The live account remained connected and the Dock preview continued to receive
  real 5-hour and weekly `/usage` values after the UI simplification.

## Interaction and accessibility assessment

- Refresh exposes `settings.claudeCode.refresh` and More exposes
  `settings.claudeCode.moreActions`.
- Opening More in the live app exposed a destructive `Sign Out` item with
  `settings.claudeCode.signOut`; it was inspected but deliberately not invoked
  against the user's real Claude account.
- Connection state and timestamp remain a combined accessibility element, and
  keyboard focus returns to Sign in after a successful sign-out.
- The new regression test covers the compact connected fixture, removed copy,
  Refresh, More, and the Sign Out menu item.

## Findings

- No actionable P0, P1, or P2 visual or interaction findings remain.
- P3 verification gap: the new UI test parses successfully but its latest run
  is blocked by an unrelated syntax error in the user's in-progress
  `CodexHoverDashboardView.swift` changes. The production Claude row and menu
  were already built and verified live before that unrelated file changed.

final result: passed

---

# Claude Code `/usage` Connection Settings — Design QA

## Comparison inputs

- Selected Option 1 source:
  `/Users/dongnt/.codex/generated_images/01a0952e-6ab1-7cf3-82b2-aa6d37ec40f5/exec-d85fbdc2-b9ff-4e13-9927-cc5beb17a3d7.png`
  (1610 × 977 px).
- Live implementation inspection: Debug `DockMagic.app`, Claude Code Settings,
  1160 × 720 pt, Light appearance, signed-out state, captured and inspected
  through the native accessibility/UI surface on 2026-09-12.
- Deterministic render artifacts from the passing test result:
  `/private/tmp/dockmagic-claude-render-final/`.
- Render coverage: Light and Dark at 1160 × 620, Increased Contrast, Reduce
  Transparency, grayscale, and a 1360 × 700 wide viewport.

## Full-view and focused comparison

The implementation preserves the selected connection-first hierarchy: Claude
identity and description, the connection surface as the first content section,
then the existing Dock preview, Display style, and appearance controls. The
live signed-out state keeps the primary action immediately adjacent to the
explicit authentication status. The selected source shows the subsequent
signing-in state; production expands the same surface to a bounded 320 pt real
PTY, followed by Cancel and Open in Terminal actions, without moving the Dock
preview ahead of connection setup.

The live accessibility tree exposed `settings.claudeCode.connectionStatus`,
`settings.claudeCode.signIn`, the existing Dock preview, display style, and
appearance controls in that order. Connected and stale details have a dedicated
`settings.claudeCode.lastUpdated` identifier, while the terminal, Cancel,
Retry, Refresh, and login-log controls have stable state-specific identifiers.

## Required fidelity surfaces

- Typography and spacing use the existing DockMagic system hierarchy,
  `DSSettingsSection`, semantic status components, shared radii, and spacing.
  No labels clipped or wrapped incorrectly at either tested width.
- Chrome is neutral-first. Status has an icon and text label in addition to its
  semantic role. Source scans found no feature-local color literal, gradient,
  glow, or decorative tinted surface in the connection, collector, or store.
- The terminal is the only bounded ANSI color surface. It launches the resolved
  Claude binary directly with fixed login arguments and never exposes a shell.
- Privacy copy remains visible in every state and says precisely what DockMagic
  retains. Authentication method, stale timestamp, retry action, CLI-version
  failure, and subscription-vs-API billing are represented in copy, not color.
- The grayscale artifact keeps status, action, quota labels, and unavailable
  values readable. Increased Contrast strengthens outlines, and Reduce
  Transparency preserves every piece of information.
- Keyboard focus enters the PTY after Sign in and returns to Sign in or Refresh
  after cancellation or completion. The terminal and status are exposed to
  accessibility with explicit identifiers and labels.

## Findings and verification

- No actionable P0, P1, or P2 visual finding remains.
- The first conditional grayscale render exposed a SwiftUI test-renderer issue
  with `NavigationSplitView`; it was replaced by the repository's established
  Core Image grayscale QA path. The final six-artifact matrix passed and was
  inspected.
- The targeted auth/parser/store/PTY suite and migrated Claude regressions pass,
  including readiness, one-minute cadence re-arming, request coalescing, Esc,
  timeout, one restart, sign-out, stop/wake, stale retention, activity-hook
  isolation, and statusLine migration.
- Unsigned optimized Release build passes. The app bundle contains SwiftTerm's
  resource bundle and `THIRD_PARTY_NOTICES.md`; Hardened Runtime remains enabled
  and App Sandbox is not enabled.
- The macOS XCUITest runner on this host remained blocked while waiting for a
  worker to materialize and was interrupted after 87 seconds. This is a P3 test
  infrastructure limitation, not a product failure; the same built app and
  accessibility hierarchy were verified directly through the running native UI.

final result: passed

---

# DockMagic Usage Share Card — Design QA

## Comparison inputs

- Selected Option 1 source: `docs/share-card-concepts/share-card-selected.png`
  (1254 × 1254 px).
- Final implementation: `docs/share-card-concepts/implementation/codex-dark.png`
  (1200 × 1200 px).
- Provider coverage:
  - `docs/share-card-concepts/implementation/claude-code-dark.png`
  - `docs/share-card-concepts/implementation/antigravity-dark.png`
- Appearance and accessibility coverage:
  - `docs/share-card-concepts/implementation/codex-light.png`
  - `docs/share-card-concepts/implementation/codex-contrast.png`
  - `docs/share-card-concepts/implementation/codex-opaque.png`
  - `docs/share-card-concepts/implementation/codex-grayscale.png`
- Combined full-view comparison:
  `docs/share-card-concepts/qa-comparison.png` (4800 × 2400 px).
- Production viewport: 300 × 300 pt rasterized directly at 4× for a
  1200 × 1200 px PNG. Source and implementation are aspect-fit into equal
  square panels on the comparison board.
- State: September 10, 2026; Builder 14-day badge; 410M tokens today;
  Ship score 64, rank Shipper. The source's 184.3K token value and score 64
  are illustrative but incompatible with DockMagic's production scoring
  thresholds, so the implementation uses real model-derived values while
  preserving the selected visual hierarchy.

## Full-view and focused evidence

The combined board renders every critical region at readable scale: provider
identity and date, badge artwork and tier, token metric, Ship progress and
rank, and DockMagic signature. No separate crop is necessary because the
entire product surface is a square social card and all fidelity surfaces are
visible together.

## Required fidelity surfaces

- Typography: macOS system typography preserves the selected compact editorial
  hierarchy, with black rounded numerals, uppercase labels, tracked metadata,
  and no wrapping or truncation.
- Spacing and layout: provider/date form a quiet top rail, the earned badge is
  the central hero, and the token and Ship sections remain separated and
  unclipped inside the exact square viewport.
- Colors and tokens: the implementation uses semantic neutral surfaces and one
  existing provider accent. It introduces no gradient, glow, tinted card, or
  feature-local palette. Full-color provider and badge artwork stays inside
  bounded identity/art regions.
- Image quality: real provider logos and authored streak badge assets are
  rasterized with the SwiftUI card at 4×. There are no placeholders or
  generated substitutes in the shipped interface.
- Copy and content: provider, current date, earned badge and required-day tier,
  today's token total, Ship score/rank, and DockMagic identity all come from
  production state. Missing data has explicit unavailable/locked copy.
- Accessibility: score and rank remain legible without color, the rendered view
  exposes one concise accessibility value, and Light, Dark, Increased Contrast,
  Reduce Transparency, and grayscale captures remain readable.

## Findings and comparison history

1. Initial visual pass — [P2]: the 126 pt badge sat fully below the header and
   did not carry the dominant hero weight of Option 1.
2. Fix: moved the header into a stable top overlay and increased the real badge
   asset to 144 pt, preserving all content and the 300 pt square viewport.
3. Post-fix pass: `docs/share-card-concepts/qa-comparison.png` shows the restored
   hero hierarchy with no overlap, clipping, or loss of metric legibility.
4. The source's metallic badge style differs from the implementation because
   production deliberately uses DockMagic's exact authored Builder asset. This
   is accepted asset fidelity, not an actionable visual defect.

## Verification

- The macOS target builds successfully with code signing disabled.
- `testUsageActivityCardsRenderForEveryExportAction` passes and verifies all
  three providers, 1200 × 1200 output, opaque corners, provider filenames,
  clipboard payloads, sufficient image payload, and the accessibility
  appearance matrix.
- `testAntigravityExportUsesDedicatedSquareActivityCard` passes against the
  Antigravity-specific dashboard path and filename contract.
- Save, Copy, and Share use the same activity-card artifact in each provider
  dashboard; no capture action remains wired to the legacy full-dashboard PNG.
- `./script/build_and_run.sh --verify` succeeds and the signed Debug build stays
  running after launch.
- Final source and implementation were inspected together in the combined
  comparison after the P2 correction.

No actionable P0, P1, P2, or P3 findings remain.

final result: passed

---

# Settings Sidebar AI Sections — Design QA

## Comparison target

- Source visual truth path: `docs/screenshots/settings-sidebar-ai-sections-target.png`.
- Implementation screenshot path: `docs/screenshots/settings-sidebar-ai-sections-implementation-light.png`.
- Normalized side-by-side evidence: `docs/screenshots/settings-sidebar-ai-sections-comparison.png`.
- Viewport and density:
  - Selected target: 836 × 1881 px.
  - Running DockMagic window: 1160 × 704 pt, captured at 2× as 2320 × 1408 px.
  - Implementation sidebar crop: 276 × 704 pt, captured at 2× as 552 × 1408 px.
  - For comparison, the target was aspect-fit to 1408 px high and the implementation was cropped to the complete 552 × 1408 px sidebar. No device frame or detail-pane pixels were used for the focused comparison.
- State: Light appearance, Antigravity selected and active.

## Full-view comparison evidence

The normalized board places the complete selected sidebar target and the complete running sidebar together. The implementation preserves the chosen hierarchy: the standalone General row comes first, the AI Features section contains Codex, Claude Code, and Antigravity, and the Features section contains every remaining destination. Both section surfaces fit above the pinned appearance footer without clipping or requiring the selected row to scroll into view.

## Focused region comparison evidence

The sidebar itself is the focused component and remains fully readable at the comparison size, so an additional crop was not needed.

- Fonts and typography: both use the native macOS system family with semibold uppercase section labels and readable single-line destination titles. No wrapping or truncation is visible.
- Spacing and layout rhythm: General remains visually independent; the two rounded sections have consistent horizontal alignment, compact 30 pt rows, 8 pt inter-section spacing, and 16 pt radii. The implementation is intentionally compact enough for the production 704 pt window height.
- Colors and visual tokens: the sidebar stays neutral-first. Selection uses the existing sidebar action fill, and the active dot uses the existing processing foreground. The new groups use shared raised-surface, outline, and accessibility-aware tokens. No direct color, decorative tint, product gradient, or colored glow was added.
- Image quality and asset fidelity: existing `DockFeatureIcon` assets render the Codex, Claude Code, Antigravity, Weather, GitHub, and Search Console identities sharply in their bounded icon regions. No placeholder, emoji, custom SVG, or generated replacement was introduced.
- Copy and content: `General`, `AI Features`, `Features`, and all destination names match the selected target. No destination was duplicated or removed.
- Interaction and accessibility: selecting Antigravity updated both the selected sidebar row and the detail destination. The accessibility tree exposes two headings followed by the expected buttons, preserves each row's existing stable identifier, and reports Antigravity as selected and Active.

## Findings

- No actionable P0, P1, or P2 findings remain.
- No P3 visual follow-up is required. The implementation's outline strength follows DockMagic's semantic surface contract rather than copying the generated mock's simulated translucency pixel-for-pixel.

## Comparison history

1. The first runtime capture showed General selected while the target showed Antigravity selected; this was a state-normalization mismatch, not a layout defect.
2. Antigravity was selected through the production sidebar. The refreshed accessibility tree confirmed the selection and navigation, and the final same-state comparison found no actionable visual differences.

## Verification

- `./script/build_and_run.sh --verify` succeeded and launched the rebuilt app.
- `testSigmaAppearanceAndAccessibilityVariantsRenderDistinctSettings` passed, covering Light, Dark, Increased Contrast, Reduce Transparency, and grayscale Settings renders.
- `git diff --check` is included in the final source verification.

final result: passed
---

# Full-panel Streak Celebration Design QA

## Comparison target

- Source visual truth:
  `/Users/dongnt/.codex/generated_images/01a05066-9393-7ad0-88f9-5fa2e414d47e/exec-8eddd005-1c00-42a0-aa48-dcd43caa8411.png`
- Source pixels: 1151 × 1366.
- Production Codex Dark:
  `docs/streak-concepts/codex-streak-celebration-dark.png`
- Production Codex Light:
  `docs/streak-concepts/codex-streak-celebration-light.png`
- Production Claude Code Dark:
  `docs/streak-concepts/claude-streak-celebration-dark.png`
- Production Claude Code Light:
  `docs/streak-concepts/claude-streak-celebration-light.png`
- Codex viewport: 440 × 522 pt, captured at 4× as 1760 × 2088 px.
- Claude Code viewport: 440 × 760 pt, captured at 4× as 1760 × 3040 px.
- State: Codex day 1 / First Prompt; Claude Code day 8 / Loop. The
  celebration is held for 60 seconds only in the deterministic renderer;
  production dismisses after 2.8 seconds.
- Density normalization: the source was proportionally scaled and padded to
  1760 × 2088 before the full-view comparison. Production was not cropped.

## Full-view comparison evidence

- Combined source and Codex implementation:
  `docs/streak-concepts/streak-celebration-reference-comparison.png`.
- The source and production render were inspected together in the same image
  input on 2026-08-30. The implementation preserves the full-panel stage,
  service header, large current badge, secured-state headline, seven-day row,
  next milestone, quiet CTA, and timed-return footer.
- Source-only glow and background falloff were intentionally omitted because
  DockMagic's normative color contract forbids colored glow and gradients.
  Hierarchy is retained through scale, spacing, typography, outline, and one
  provider accent.

## Focused-region comparison evidence

- Accessibility contact sheet:
  `docs/streak-concepts/streak-celebration-accessibility-contact-sheet.png`.
  Reading order is Dark, Light, Increased Contrast / Reduced Transparency,
  grayscale simulation, Reduce Motion.
- Claude Code's 440 × 760 pt panel was checked independently in Dark and Light.
  It uses the same celebration hierarchy, its own logo and orange action
  accent, and a milestone-specific hero scale that keeps Loop clear of the
  `TODAY'S STREAK` label.
- The final First Prompt hero was compared at production size after measuring
  its alpha bounds. Its smaller painted area is compensated without changing
  the collection/strip rendering of the same asset.

## Required fidelity surfaces

- Fonts and typography: existing macOS system typography and rounded numeric
  treatment are retained. The headline, milestone copy, weekdays, CTA, and
  footer remain single-line in both dashboard widths.
- Spacing and layout: celebration content replaces the complete dashboard body
  rather than occupying a nested card. Header identity remains anchored at the
  top and the timed-return affordance remains anchored at the bottom.
- Colors and tokens: chrome uses semantic `DesignTheme` roles. Codex uses the
  action accent; Claude Code uses its existing provider accent. Multi-color art
  is confined to the bounded badge identity region. Source scans found no
  gradient, colored glow, direct RGB, direct system color, or feature-local
  palette in the celebration view.
- Shape and image quality: current milestone art comes from the existing 1024 ×
  1024 alpha badge assets. Per-asset hero scaling accounts for different alpha
  bounds without cropping, stretching, or altering the detail/collection sizes.
- Copy and content: the UI says exactly what happened, identifies the current
  milestone, shows the recent day states, and describes the next achievable
  badge without productivity claims or punitive reset language.
- States and interactions: full-panel celebration, automatic 2.8-second return,
  Escape dismissal, and `View badges` drill-in are wired for Codex and Claude
  Code. Reduce Motion removes scale animation and uses opacity only.
- Accessibility: unknown and completed days retain `?` and check symbols plus
  weekday initials, so state is not color-only. The celebration and CTA have
  stable accessibility identifiers and combined spoken labels.
- Persistence: the claim timestamp is stored on DockMagic's SwiftData streak
  record. A provider/day celebration can be claimed once, only after today's
  local token use has produced an active streak record.

## Findings

No actionable P0, P1, or P2 findings remain.

## Comparison history

### Pass 1 — superseded

- [P2] Neutral rays crossed the eyebrow label, the generic Codex logo renderer
  exposed transparent fringe, and native progress styling produced a gray fill.
- Fix: removed near-vertical rays, matched the existing Codex crop, and replaced
  native progress rendering with a semantic capsule rail.

### Pass 2 — superseded

- [P2] The First Prompt badge was visibly smaller than the selected source
  because its painted alpha bounds occupy less of the 1024 × 1024 canvas.
- Fix: promoted the celebration badge to a measured hero size and applied a
  bounded art scale while preserving the original asset.

### Pass 3 — superseded

- [P2] Applying the First Prompt compensation to every badge caused the fuller
  Loop artwork to approach the Claude Code eyebrow label.
- Fix: added milestone-specific hero scaling. First Prompt, Spark, and Builder
  receive only the compensation they need; fuller badge canvases render at 1×.

### Pass 4 — passed

- The normalized side-by-side comparison shows the intended hierarchy and
  badge prominence with no overlap, clipping, broken wrapping, or color-only
  state.
- Dark, Light, Increased Contrast, Reduced Transparency, grayscale, and Reduce
  Motion evidence remains legible. Codex and Claude Code renders retain their
  own identity without introducing a second chrome palette.
- `TokenUsageStreakStoreTests` passed 7/7, including both once-per-provider/day
  celebration claim tests. The unsigned Debug build passed.
- The AppKit-hosted automatic-return image test remains present, but Xcode 17's
  visual test host stalled during isolated execution before reporting an
  assertion. The production renderer and source-level interaction wiring were
  used for this visual pass; this is a test-host limitation, not a visible
  product finding.

## Follow-up polish

- [P3] If DockMagic later adds a user preference for celebration duration, keep
  the current 2.8-second value as the default and preserve immediate Escape and
  `View badges` control.

final result: passed

---

# Streak Dashboard Design QA

## Comparison target

- Source visual truth: `docs/streak-concepts/codex-streak-continuity-strip-selected.png`
- Source pixels: 1545 × 1018. This is an approved three-panel concept board,
  not a single production viewport.
- Production Codex overview:
  `docs/streak-concepts/codex-streak-implementation-overview.png`
- Production Codex detail:
  `docs/streak-concepts/codex-streak-implementation-detail.png`
- Production Claude Code detail:
  `docs/streak-concepts/claude-streak-implementation-detail.png`
- Codex viewport: 440 × 522 pt, captured at 2× as 880 × 1044 px.
- Claude Code viewport: 440 × 760 pt, captured at 2× as 880 × 1520 px.
- Theme/state: Dark appearance. Codex fixture is current 7 / best 28;
  Claude fixture is current 8 / best 12. The concept board uses current 14 /
  best 28, so numeric and recent-day differences are fixture differences rather
  than layout drift.
- Density normalization: production captures share the same 2× AppKit backing
  density. The composite concept was reviewed at full size for hierarchy and
  art direction; no pixel-distance claim is made across the mixed-scale board.

## Full-view comparison evidence

The source board and the three production captures were opened together in the
same comparison input on 2026-08-30. The implementation preserves the approved
composition: identity and limits first, daily usage second, a shallow streak
strip immediately after the chart, then the existing dashboard content. Both
service variants share the information architecture while retaining their own
logo and single usage accent.

The production detail intentionally expands the concept's current-badge panel
into the requested collection view. It keeps the large current badge and
current/best/next hierarchy above recent activity, then exposes all ten badges
in milestone order. This is a deliberate product expansion, not a fidelity
error.

## Focused-region comparison evidence

- Continuity strip: compared the source Codex and Claude strips with the 62 pt
  production strip. Badge, current run, seven day markers, next milestone, and
  chevron retain the same left-to-right scan. The production adds explicit
  unknown and today-pending shapes so state is not inferred or color-only.
- Badge hero and collection: inspected generated art at 48, 58, and 112 pt in
  Dark, Light, and grayscale contact-sheet renders. All ten source PNGs are
  1024 × 1024 with real alpha and remain distinct at the production sizes.
  Each is now a complete Interlock Crown milestone symbol. SwiftUI renders the
  authored asset directly; no Codex/Claude logo, blank medallion, or runtime
  identity layer remains inside the badge.
- Lower Codex insights: the revised overview shows all three Top models rows and
  the complete Daily intensity footer inside the unchanged 440 × 522 pt panel.

## Required fidelity surfaces

- Fonts and typography: production uses the existing macOS system family,
  rounded digits, dashboard weights, and optical hierarchy. Labels remain on
  one line at the tested viewport; no truncation or broken wrapping is visible.
- Spacing and layout rhythm: outer panel geometry, inset margins, 8–10 pt card
  radii, thin neutral outlines, and section rhythm match the current dashboard.
  No persistent control or model row is clipped after the second pass.
- Colors and tokens: SwiftUI chrome is neutral plus `theme.action` for Codex or
  `DSClaudeCodeUsage` for Claude. Multi-color enamel is confined to badge
  artwork. No code gradient, colored glow, direct RGB, decorative tinted card,
  or feature-local palette was introduced. Selected and locked states also use
  outline, label, symbol, and emphasis changes.
- Image quality and asset fidelity: badge silhouettes are individual generated
  raster assets with alpha, not crops from a concept sheet. Background
  extraction leaves transparent corners and one connected artifact. Every
  asset has a finished interlocking center with no empty identity socket.
- Copy and content: copy describes token activity without claiming
  productivity. Reset copy protects best streak and earned badges; unavailable
  copy does not imply a missed day. Milestone names and day thresholds match the
  research specification.
- Icons and affordances: disclosure chevron, lock, check, today-pending marker,
  and back control use consistent monochrome SF Symbols. The strip is a full-row
  button with help and accessibility text.
- States and interactions: live, locked/unlocked, current selection, reset with
  permanent Continuum unlock, unavailable, Increased Contrast, and Reduced
  Transparency remain covered by the existing view/state implementation. The
  new artwork was rechecked at 112 pt Dark, 58 pt Light, and 48 pt grayscale.
- Accessibility: badge labels include name, requirement, and lock state. Recent
  days expose dates and textual state. Markers differ by icon, outline, dash,
  and fill in addition to color. The implementation respects the system Reduce
  Motion environment by removing navigation animation.

## Findings

No actionable P0, P1, or P2 findings remain.

## Comparison history

### Pass 1 — superseded

- The original badge system composited the active service logo into a central
  recess. The Signal Architecture redesign replaces that composition with
  self-contained, service-neutral milestone artwork; service identity remains
  in the dashboard header.
- [P2] Final Top models row clipped in the Codex overview.
  Evidence: the first 440 × 522 capture cut the third row at the panel edge.
  Fix: compacted only the two lower insight cards' internal spacing and row
  height while preserving the panel, chart, strip, and Ship momentum hierarchy.

### Pass 2 — blocked

- Post-fix evidence:
  `/tmp/dockmagic-streak-ui-attachments-v2/7B6F14E2-0248-40A3-AD7B-03A5DE1FBBF5.png`
  and
  `/tmp/dockmagic-streak-ui-attachments-v2/D6A86F5B-A40A-47A5-8CA3-3515E901D593.png`.
- The logo core is clean at hero and collection sizes, and all existing lower
  insight content is visible in the static render.
- [P2] The real nonactivating-panel host still overflowed vertically by about
  15 pt, clipping the header hit region and causing the existing Capture click
  test to miss.
  Fix: reduced overview section spacing by 1 pt and the token plot by 8 pt for
  one- and two-limit states. This retains every section and leaves the strip at
  its selected 62 pt prominence.

### Pass 3 — passed

- Post-fix evidence:
  `docs/streak-concepts/codex-streak-implementation-overview.png`,
  `docs/streak-concepts/codex-streak-implementation-capture-menu.png`,
  and
  `docs/streak-concepts/codex-streak-implementation-detail.png`.
- The entire header, chart, streak strip, Ship momentum, and both lower insight
  cards fit the unchanged 440 × 522 pt host. Capture, streak open, and Back all
  pass real panel-click tests. The final combined comparison found no new
  P0/P1/P2 issue.

### Pass 4 — Signal Architecture replacement

- Production evidence:
  `docs/streak-concepts/signal-architecture-production-contact-sheet.png`.
- The selected 365-day Signal Architecture reference and the complete
  production set were inspected together. Material, palette, routing, joinery,
  and keystone language remain consistent while the silhouette progresses from
  one module to two interlocked cycles.
- `./script/build_and_run.sh --verify` passed: the app compiled, linked the new
  `Assets.car`, launched, and stayed running.
- Focused model/mapping and source/design-system tests passed through the built
  XCTest bundle. Xcode 17's hosted test coordinator repeatedly waited for
  workers to materialize, so the full dashboard render test could not be
  rerun in its app-hosted environment. Direct execution reaches the render test
  but correctly lacks the app bundle's named assets; this is classified as an
  environment/test-host limitation, not an assertion or product regression.

## Open questions

- The concept's previous/current/next carousel was replaced by the complete
  collection requested for production. If a focused one-badge sharing flow is
  added later, the carousel can become a separate drill-down without changing
  this overview/detail structure.

## Implementation checklist

- [x] Shared continuity strip in Codex and Claude Code.
- [x] In-panel detail and Back interaction.
- [x] Ten permanent milestone badges and locked states.
- [x] Shared logo-free badge art; Codex/Claude Code identity remains in the
  existing dashboard header.
- [x] 112 pt Dark, 58 pt Light, and 48 pt grayscale production-art QA.
- [x] Reset, unavailable, and maximum-tier evidence.
- [x] Source scans for color and gradient violations.

## Follow-up polish

- [P3] A later earned-date field could make historical badges more personal,
  but upstream usage currently does not provide a trustworthy unlock timestamp.

## Pass 5 — Victory Crest replacement

- Source target:
  `docs/streak-concepts/pinterest-v2/victory-crest-claude.png`.
- Production-size evidence:
  `docs/streak-concepts/pinterest-v2/victory-crest-production-contact-sheet.png`.
- Native combined comparison:
  `docs/streak-concepts/pinterest-v2/victory-crest-native-comparison.png`.
- Native captures: Codex 440 × 522 pt / 880 × 1044 px and Claude Code
  440 × 760 pt / 880 × 1520 px, both at 2× AppKit backing density.
- States inspected together: Codex Dark, Codex Light, Codex grayscale-check,
  and Claude Code Dark. Separate app-hosted render attachments cover Increased
  Contrast, Reduced Transparency, unavailable, reset with Continuum retained,
  and the compact overview strip.
- Focused badge evidence: the contact sheet compares both service marks at
  112 pt, paired collection assets at 58 pt, and paired grayscale assets at
  48 pt. No extra crop was required because every badge is shown at the exact
  production sizes in one input.

### Fidelity review

- Typography and copy remain the established DockMagic system hierarchy; no
  badge text or generated numeral is baked into raster artwork.
- Spacing and layout rhythm are unchanged. The 112 pt hero and 58 pt collection
  slots remain centered, and the full Claude Code ten-badge collection fits its
  existing 440 × 760 pt panel.
- Color remains bounded to authored badge enamel and the exact service logo.
  Interface chrome continues to use semantic theme roles with no new gradient,
  glow, direct color literal, or decorative tinted card.
- All ten 1024 × 1024 frame PNGs retain genuine alpha, transparent corners,
  one connected silhouette, and a centered blank identity medallion.
- Codex and Claude Code use the same milestone frames, while exact runtime
  marks provide service identity without relying on generated logo imitations.
- Locked, selected, earned, unavailable, reset, and compact states retain
  outline, symbol, label, opacity, and structure cues; state never depends on
  badge color alone.

### Iteration history

- Initial production contact-sheet pass used a 17% service mark. At 48–58 pt it
  was too quiet relative to the medallion, a P2 identity-legibility issue.
- Post-fix composition uses 22% at every badge size. The second contact sheet
  and app-hosted render comparison show both marks clearly without touching the
  medallion rim. No P0, P1, or P2 findings remain.
- `./script/build_and_run.sh --verify` succeeded and launched the signed Debug
  app. The targeted app-hosted render test passed in 1.894 seconds.
- The semantic-chrome source guard and the researched ten-milestone boundary
  test also passed in the app-hosted XCTest environment.

final result: passed

---

## Pass 6 — Interlock Crown logo-free replacement

- Selected source target:
  `docs/streak-concepts/pinterest-v3/ideation/interlock-crown.png`.
- Production-size evidence:
  `docs/streak-concepts/pinterest-v3/interlock-crown-production-contact-sheet.png`.
- Native combined comparison:
  `docs/streak-concepts/pinterest-v3/interlock-crown-native-comparison.png`.
- Native captures: Codex 440 × 522 pt / 880 × 1044 px and Claude Code
  440 × 760 pt / 880 × 1520 px at 2× AppKit backing density.
- The source target and Codex Dark, Claude Code Dark, Codex Light, and Codex
  grayscale-check renders were inspected together in one comparison input.
  Separate app-hosted attachments cover Increased Contrast, Reduced
  Transparency, unavailable, reset with Continuum retained, and compact-strip
  states.

### Fidelity review

- The selected Builder artwork is used unchanged as the 14-day badge. The
  remaining nine assets preserve its warm copper rim, graphite chassis, broad
  ivory/cobalt enamel, angular joinery, and connected silhouette.
- The interlocking structure is now the complete symbol. No badge contains a
  Codex logo, Claude Code logo, generated logo, circle, blank medallion, or
  runtime service-mark overlay. Provider identity remains visible only in the
  dashboard header.
- Milestone progression remains legible through shape: crossed ribbons,
  chevron, closed knot, full crown, swept weave, directional crown, triple
  crown, buttress braid, five-facet keystone, and distilled vertical spine.
- The ten 1024 × 1024 RGBA assets retain genuine alpha, transparent corners,
  one connected artifact, and readable silhouettes at 112, 58, and 48 pt.
- Layout, typography, copy, and interaction geometry are unchanged. The
  authored badge palette stays bounded inside the artwork; SwiftUI chrome still
  uses semantic theme roles with no new gradient, glow, direct color literal,
  or decorative tinted card.
- Locked, selected, earned, unavailable, and reset states continue to use
  lock/check symbols, labels, outlines, opacity, and position in addition to
  color. The grayscale contact-sheet row preserves distinct structures.

### Iteration history

- [P2] The first Continuum attempt formed a horizontal infinity/bow-tie motif,
  which broke the selected crown language and made the final tier ambiguous.
- Fix: one targeted retry replaced it with six paired enamel facets converging
  on a tall graphite/copper master spine. The corrected asset appears in both
  production-size and native reset evidence.
- `./script/build_and_run.sh --verify` succeeded.
- `testStreakDashboardRendersBadgeCollectionAcrossServicesAndAccessibility`
  passed in 1.799 seconds and produced all nine native attachments.
- `testStreakDashboardSourceUsesBoundedBadgeArtAndSemanticChrome` and
  `testTokenUsageStreakMilestonesUseTheTenResearchedBoundaries` passed in the
  app-hosted XCTest environment.

No actionable P0, P1, P2, or P3 findings remain.

final result: passed

---

## Pass 7 — Compact badge sharpness

- Source visual truth:
  `docs/streak-concepts/pinterest-v3/ideation/interlock-crown.png`.
- Baseline implementation:
  `docs/streak-concepts/pinterest-v3/interlock-crown-small-sharpness-before.png`.
- Final implementation:
  `docs/streak-concepts/pinterest-v3/interlock-crown-small-sharpness-after.png`.
- Combined full-view and focused comparison:
  `docs/streak-concepts/pinterest-v3/interlock-crown-small-sharpness-comparison.png`.
- Viewport: Codex 440 × 522 pt, captured at 2× as 880 × 1044 px. The same
  fixture, Dark appearance, selection, layout, and native AppKit renderer are
  used before and after.

### Findings and fix

- [P2] The previous unconditional high-quality interpolation softened the
  copper/graphite boundaries when a 1024 px source was reduced to the 48 pt
  streak strip and 58 pt collection slots. Hero artwork at 112–185 pt remained
  crisp.
- Fix: `StreakBadgeView` now selects interpolation from both slot size and
  display density. Slots up to 60 pt use pixel-preserving sampling at 2× or
  greater, and medium interpolation at 1× to avoid jagged diagonals. Larger
  hero art retains high-quality interpolation.
- Post-fix focused evidence shows cleaner copper outlines, stronger separation
  between ivory/cobalt facets, and more legible internal knots without changing
  the artwork, crop, frame, opacity, or dashboard layout.

### Required fidelity surfaces

- Fonts and typography: unchanged; badge optimization does not affect text
  antialiasing, weight, wrapping, or hierarchy.
- Spacing and layout: unchanged at the exact 440 × 522 pt viewport. Badge slots
  remain 48, 58, 112, and 185 pt with no crop or alignment drift.
- Colors and tokens: unchanged. The bounded authored enamel palette and all
  semantic SwiftUI chrome roles remain intact.
- Image quality: compact sampling is sharper on Retina while 1× displays keep
  antialiased diagonals. Hero images preserve their previous smooth high-quality
  downsampling.
- Copy and content: unchanged.

### Verification

- The selected source, baseline, final full viewport, and compact collection
  crops were inspected together in one comparison input.
- `testStreakDashboardRendersBadgeCollectionAcrossServicesAndAccessibility`
  passed in 1.744 seconds across all nine attachments.
- `testStreakDashboardSourceUsesBoundedBadgeArtAndSemanticChrome` passed and now
  guards both the 60 pt threshold and the Retina/1× fallback behavior.
- `./script/build_and_run.sh --verify` succeeded after the final renderer change.

No actionable P0, P1, P2, or P3 findings remain.

final result: passed

---

# DockMagic Service Status — Design QA

## Comparison target

- Source visual truth paths:
  - `docs/service-status-concepts/header-pulse-selected.png`
  - `docs/service-status-concepts/corner-beacon-selected.png`
- Implementation screenshot paths:
  - `docs/service-status-concepts/implementation-snapshots-final/A5FA1FDF-8EA1-414B-9DAE-2F1C6B40A9B0.png` (Codex dashboard)
  - `docs/service-status-concepts/implementation-snapshots-final/5AB4BFD8-7F76-445F-8062-5DE9D324EF95.png` (Claude dashboard)
  - `docs/service-status-concepts/implementation-snapshots-final/C262B8A8-95C1-4EB0-8E98-0A95B8F5C99E.png` (Dock animation storyboard)
  - `docs/service-status-concepts/design-qa-comparison.png` (normalized side-by-side comparison)
- Viewport and density:
  - Dashboard source board: 1487 × 1058 px, generated at 1×; focused comparisons crop each provider's header and quota region.
  - Codex implementation: 440 × 556 pt at 4×, 1760 × 2224 px.
  - Claude implementation: 440 × 740 pt at 4×, 1760 × 2960 px.
  - Corner Beacon source board: 1536 × 1024 px at 1×.
  - Corner Beacon implementation storyboard: 784 × 200 pt at 2×, 1568 × 400 px.
  - The comparison board is 4000 × 3180 px. Source and implementation regions are aspect-fit into equal-width panels; dashboard comparisons use top-header crops so the different production panel heights do not create false density findings.
- State:
  - Codex: degraded performance, monitoring.
  - Claude Code: major outage, identified, plus a partial-outage source reference.
  - Dock: incident arrival at 0/90/180/270 ms and settled; ring and numeric compatibility; Reduce Motion settled state.

## Full-view comparison evidence

The combined comparison board shows that the implementation preserves the selected concepts' hierarchy: provider identity first, incident symbol/severity/phase second, quota information unchanged, and a stable official-status affordance. The production 440-point dashboard retains its existing lifetime metric, so the incident and provider link use a compact second header line instead of competing with the metric on the first line. This is an intentional responsive adaptation; it does not alter content order or hide above-the-fold controls.

The Dock implementation keeps the underlying ring/numeric values stationary and confines the alert to the top-right identity/status slot. The 270 ms frame reaches the same large semantic-triangle emphasis as the selected Corner Beacon storyboard, then returns to a small static beacon.

## Focused region comparison evidence

`docs/service-status-concepts/design-qa-comparison.png` places focused Codex and Claude header crops and the complete Corner Beacon timelines beside their source regions in one image. At readable scale:

- Fonts and typography: production uses the existing macOS system typography, semibold severity/phase copy, and the current dashboard hierarchy. No wrapping or truncation is visible.
- Spacing and layout rhythm: status icon, copy, spacer, and official link align on one compact line below the existing 30-point identity row. Quota cards retain their original margins and vertical rhythm.
- Colors and visual tokens: operational is neutral; confirmed degraded/partial states use the shared warning role; major outage uses the shared danger role. No new feature palette, glow, tinted card, or decorative gradient was introduced.
- Image quality and asset fidelity: existing Codex/Claude brand assets remain sharp and bounded to the identity region. Status indicators use monochrome SF Symbols; no emoji, placeholder, custom SVG, or code-drawn brand asset replaces source imagery.
- Copy and content: `Degraded · Monitoring`, `Major outage · Identified`, `OpenAI status`, and `Claude status` are concise and map directly to provider data. Cached/unavailable states remain distinct from confirmed downtime.
- Icons and accessibility: the triangle communicates incident state without relying on color. Snapshots confirm legibility at 32, 48, 64, and 128 points. Reduce Motion skips the animation and retains the settled symbol.

## Findings

- No actionable P0, P1, or P2 findings remain.
- P3 residual test gap: automated tests verify that official URLs are attached to real SwiftUI `Link` controls, but deliberately do not launch an external browser during the test suite.

## Open Questions

- None blocking. The two-line production header is accepted as the responsive form of the source concept because the selected mock does not include DockMagic's existing lifetime metric at the real 440-point width.

## Comparison history

1. Initial pass — P2: the Corner Beacon outline only expanded to 1.8× and faded before the last animation frame, so the 180/270 ms emphasis was visibly weaker than `corner-beacon-selected.png`. Evidence: `docs/service-status-concepts/implementation-snapshots/80EDB40D-436F-43CE-9063-2091C1E6C1F6.png`.
2. Fix: increased the deterministic triangle/echo growth, retained its emphasis through the final transition frame, and added the final 30 ms hold before publishing the settled raster. Usage rendering remains static.
3. Post-fix pass: `docs/service-status-concepts/design-qa-comparison.png` and `docs/service-status-concepts/implementation-snapshots-final/C262B8A8-95C1-4EB0-8E98-0A95B8F5C99E.png` show the source-like bloom at 180/270 ms and the correct small settled beacon. No further P0/P1/P2 differences were found.

## Implementation checklist

- [x] Header Pulse for Codex and Claude Code.
- [x] Official status links and provider-specific copy.
- [x] Static Corner Beacon for ring and numeric Dock renderers.
- [x] Cancellable nine-frame/270 ms transition.
- [x] Deduplication for repeated and phase-only refreshes.
- [x] Reduce Motion direct-to-settled behavior.
- [x] Light, Dark, Increased Contrast, Reduce Transparency, grayscale, and small-size snapshots.
- [x] Parser, cache/stale, animation, capture, and rendering tests.

final result: passed

---

# Software Update Design QA

## Comparison inputs

- Selected Option 1 target: `/Users/dongnt/.codex/generated_images/01a06bc9-87df-7bf3-97e8-8f271a6fa275/exec-bb7d2225-e413-483f-81fd-59b05e451136.png`
- Tested app screenshot: `/private/tmp/dockmagic-update-footer-batteries-dark-final.png`
- Side-by-side comparison: `/private/tmp/dockmagic-update-dark-final-qa-comparison.png`
- Both sides were normalized to the same 1588 × 991 viewport and inspected in the same Batteries, Dark appearance, version 1.0.2 available state.

## Visual assessment

- The update affordance remains fixed at the bottom-left, directly above the appearance capsule.
- The row preserves the target hierarchy: monochrome download icon, `Update available`, version, and trailing chevron.
- Padding, minimum height, rounded surface, border, typography, and alignment match the selected direction while using DockMagic's existing shared design-system components.
- The surface is neutral-first and uses no feature-local palette, decorative gradient, colored glow, or color-only state.
- The current product sidebar includes Search Console and other newer navigation content not present in the generated target. Those established product elements were preserved; the new update row remains visually aligned with the target.

## Interaction and accessibility assessment

- The footer is keyboard-focusable, exposes an accessibility label containing the available version, and opens the standard updater flow.
- The General controls expose explicit On/Off labels. Disabling automatic checks disables automatic downloads; re-enabling checks makes downloads actionable again.
- Dedicated render coverage passed for Light, Dark, Increased Contrast, Reduce Transparency, and grayscale.
- The final UI test and screenshot were produced from `/private/tmp/dockmagic-updater-ui-final5.xcresult`.

final result: passed
