# DockMagic Rules

This file records mandatory project rules arising from user requirements,
recurring problems, and decisions that must remain consistent. It is loaded
through [AGENTS.md](AGENTS.md) and applies to every AI agent working in this
repository, within the scope of the task being performed.

## How to apply these rules

- Read this file before planning or changing the project. Identify and follow
  every rule relevant to the requested work.
- Treat active rules as requirements, not suggestions. Existing code, old
  examples, research specimens, and proposals do not grant exceptions.
- Follow the user's latest explicit direction when it changes an earlier
  project rule, subject to higher-priority instructions. Synchronize the
  affected rule and contract within the requested scope; do not silently keep
  contradictory active instructions or request approval already given.
- If instructions genuinely conflict and the current request does not resolve
  them, identify the exact conflict instead of inventing an exception. Continue
  independent work that is not affected by that conflict.
- Check applicable rules before reporting completion. State what was verified
  and what remains unverified; documentation or lint alone is not runtime proof.

## UI and design rules

All rules below are active. [Design.md](Design.md) describes the design system;
this file records the constraints that agents must obey when applying it.

### UI-001 — Apply the native token adapter

Apply the native adapter in [Design.md](Design.md): dimension values such as
`14px` represent 14 SwiftUI layout points; do not apply CSS point conversion or
display scaling. Unsuffixed color/component tokens are Light variants; `-dark`
variants are Dark. Use semantic Swift roles in feature code, not YAML hex
literals or web styling APIs.

### UI-002 — Resolve typography by surface and role

Typography is decided: all DockMagic-owned Settings, dashboard, Dock, preview
and export text uses bundled Geist through `DSTypography`/`DSFonts`. Preserve
native editing and glyph-level system fallback. System-owned UI, terminal
transcripts and supplied brand artwork retain their documented exceptions.

### UI-003 — Separate confirmed decisions from proposals

The approved visual baseline is pinned `bbVKHJo` / `base-maia`: Geist,
HugeIcons Free Stroke Rounded, Neutral, Maia geometry and opaque surfaces.
Archived research and the older motion proposal are not the active visual
policy. Do not claim documentation or source migration proves runtime QA.

### UI-004 — Synchronize and validate design changes

When design decisions change, synchronize [Design.md](Design.md), the relevant
specialized contract, and shared tokens within the requested implementation
scope. Validate format changes with
`npx --yes @google/design.md@0.4.0 lint Design.md`; resolve errors and explain
any remaining warnings. Format validation does not replace native
UI/accessibility verification.

### UI-005 — Use the native UI stack

Build native UI with SwiftUI, the existing shared design-system components,
and bundled HugeIcons Free Stroke Rounded through typed `DSIcon`. Apply web-oriented design skills only where relevant; do not
import their web stack or marketing layout rules into native dashboards.

### UI-006 — Follow the specialized design contracts

Treat [COLOR_DESIGN_SYSTEM.md](docs/COLOR_DESIGN_SYSTEM.md) as the normative
color contract and [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) as the component
and appearance contract.

### UI-007 — Keep the interface neutral-first

Keep DockMagic-owned UI neutral-first. Primary action, focus, hover and selection use the Neutral token family;
semantic color appears only for a real information, processing, warning, or
danger state and replaces the local accent when prominent.

### UI-008 — Do not add decorative gradients or palettes

Do not add `LinearGradient`, `RadialGradient`, `AngularGradient`, colored glow,
decorative tinted cards, or a new feature-local palette.

### UI-009 — Constrain icon and brand colors

Keep interface icons monochrome or hierarchical in one hue. Preserve
full-color brand assets only inside a bounded identity region.

### UI-010 — Contain renderer and data-series colors

Keep user-selected and data-series colors inside their renderer, preview,
swatch, and legend boundaries. Never reuse them for chrome, selection, focus,
buttons, or status.

Codex and Antigravity dashboard quantitative content use the approved blue data
roles from `DesignTheme`: quota progress, token charts/metrics, Ship momentum,
Daily intensity and Top models, including drill-down and export where the
provider supports them. This is a bounded data-color exception; neutral controls
and semantic warnings remain unchanged.

Verified days in every shared streak surface use `DesignTheme.streakActive` and
`onStreakActive`. This bounded green content role applies to the compact strip,
celebration and badge-detail Recent activity; it must not tint badge artwork,
pending/unknown days, chrome, controls, focus or status.

### UI-011 — Use semantic colors and shared components

Use semantic `DesignTheme` roles and shared components. Do not add direct RGB,
hex, system color names, or asset lookups in feature views when a semantic
role exists. Follow the pinned catalog workflow in Design.md before adding a
component: reuse first, add a named native variant with gallery states and
verification when necessary, then compose the feature. App-owned surfaces are
opaque; native file/permission/Share/app menus keep platform presentation.

AI daily history dashboards use `AIUsageHistoryChart`; provider adapters only
map source values, missing/partial state and formatting into that component.
AI daily intensity dashboards use `AIUsageDailyIntensityCard`; provider adapters
map their integer metric, timezone, missing-day coverage and bounded data color.
Do not turn missing buckets into measured zero or rename organization analytics
as personal activity.
Each dashboard may provide its own data-series color, but that color remains
inside the plot and is never reused for controls, chrome or status.

### UI-012 — Include renderer color customization

Every new feature must include a color customization section in Settings.
Reuse `DSColorPalettePicker` with `ProjectTheme.rendererColorOptions`, as in
Claude Code Settings; persist the choice, apply it immediately to the
production renderer and live preview, and provide Reset Defaults. Expose each
independently meaningful renderer/data-series color with a clear label. A
feature is not complete without this section; selected colors must stay
within the renderer, preview, swatch, and legend boundaries in UI-010.

### UI-013 — Verify appearance and accessibility

Verify changed UI in Light, Dark, Increased Contrast, Reduce Transparency,
and grayscale. State, selection, and data must not depend on color alone.
For motion changes, also verify Reduce Motion as required by
[Design.md](Design.md).

### UI-014 — Use shared Maia selection controls

Use `DSSegmentedControl` for chart type and short, mutually exclusive choices
throughout Settings and every hover dashboard. Use `DSSelect` for dropdowns,
long option lists and searchable selection. Do not render app-owned selection
with a default SwiftUI Picker or feature-local segmented/menu styling. Preserve
bindings, disabled options, keyboard navigation and selected accessibility state.
System-owned dialogs and native date editing keep their platform behavior.

### UI-015 — Route Dock click and hover consistently

A direct click on the DockMagic Dock icon must open Settings immediately.
Hovering continuously over the icon for **1 second** may show the hover
dashboard only when the active feature has an available dashboard. If the
dashboard is visible, a click on the Dock icon must close it before opening
Settings. A click before the 1-second hover delay completes follows the direct
click behavior and cancels the pending dashboard display. When no dashboard is
available, hover must not show a substitute surface; clicking still opens
Settings.

### UI-016 — Keep Active Dock feature identities consistent

Every feature shown in the Active Dock feature selector must display the same
`DockFeatureIcon` identity used for that feature in the Settings sidebar. This
applies to the selected trigger and every row in the searchable popup. When a
feature is added or its sidebar logo changes, update the shared identity once;
do not substitute an unrelated generic symbol in the selector. Verify every
`DockFeature.availableCases` option has a visible matching identity in Light
and Dark appearances.

### UI-017 — Do not show hover-dashboard popover arrows

No DockMagic hover dashboard may render a popover arrow/callout pointer. The
shared dashboard card keeps its dimensions and shifts toward the Dock by the
former 10 pt pointer extent, so its Dock-facing edge ends at the arrow tip's
former position. Apply this through shared hover chrome for bottom and side
Dock placements; do not introduce feature-specific offsets.

## Maintaining this file

- Add a rule when the user explicitly establishes a lasting requirement or
  asks to record a recurring problem. Do not turn an unapproved proposal or
  an agent's preference into a mandatory rule.
- Give each rule a stable, unique ID, a descriptive title, a clear scope, and
  an actionable requirement. Add the reason or observed failure when known;
  do not invent incident history. Include a verification criterion when useful.
- Update the existing rule when the same requirement changes. Do not create
  competing copies; preserve IDs and do not reuse retired IDs for new rules.
- Keep the authoritative rule here and link to detailed specifications.
  Keep [AGENTS.md](AGENTS.md) as the entry point, without duplicating this
  full rule list. Add new categories when requirements extend beyond UI.
- Do not alter a rule merely to make a noncompliant implementation appear
  compliant. Keep proposals separate until the user adopts them.
