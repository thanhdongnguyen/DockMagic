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
