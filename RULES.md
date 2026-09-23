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

The enabled track of the shared `DSSwitchStyle` is the user-approved blue
control-state exception. It uses the dedicated switch semantic roles only; it
does not establish a blue action, focus, selection, status, or feature palette.

### UI-008 — Keep decorative color bounded

Do not add `LinearGradient`, `RadialGradient`, `AngularGradient`, colored glow,
decorative tinted cards, or a new feature-local palette. The Weather scene
backgrounds specified by UI-021 are the sole condition-driven surface
exception, including their reuse behind the Calendar Dock date and inside the
selected-day Calendar forecast: use shared solid
tokens beneath quiet static artwork. Do not add
code-generated gradients; natural tonal variation inside the authored Weather
images does not establish a UI gradient role.

### UI-009 — Constrain icon and brand colors

Keep interface icons monochrome or hierarchical in one hue. The user-approved
generated Calendar forecast pictograms may use their authored weather colors
only in the month grid and selected-day forecast; they never color controls or
replace condition text/accessibility labels. The user-approved
CPU & RAM, Network, Storage, Clock, Calendar, Now Playing, and Batteries identities may
use their authored solid colors only inside the fixed Settings/sidebar and
Active Dock Feature logo region. Preserve full-color brand assets only inside
a bounded identity region; neither kind of artwork may tint surrounding text,
selection, controls, surfaces, focus, or status.

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
opaque except the outer Custom Dock surface, which may use a public macOS
material to follow Apple Dock appearance. The approved Shelf segment has no
independent fill or nested material: two semantic hairline dividers group its
existing Dock tiles and trailing dashed `+` within the one continuous Custom
Dock surface. Shelf feature tiles suppress only their outer tile outline in
both Light and Dark appearances; internal renderer strokes, indicators and the
trailing `+` border remain intact. Controls, Settings and dashboards retain
semantic Maia surfaces; Reduce Transparency must resolve the outer surface to
an opaque neutral color. Native file/permission/Share/app menus keep platform
presentation.

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

### UI-018 — Keep shared sliders thumbless

`DSSlider` and its `DSNativeSlider` derivatives render a value track without a
visible thumb. Preserve the native knob geometry for pointer hit-testing,
keyboard adjustment and accessibility; feature views must not add a local thumb
or replace the shared slider solely to draw one.

### UI-019 — Preserve Dock Active and Shelf mode semantics

DockMagic offers two exclusive modes: Dock Active shows one selected feature in
the app's Apple Dock tile; Shelf shows a Dockset-like Custom Dock segment with a
trailing square, rounded, dashed-border `+` tile. Adding a feature replaces the
current `+` position with that feature's **existing Dock tile presentation** and
appends `+` one slot to the right (or next in Dock-edge order). The same feature
may be added more than once: each occurrence has its own stable slot identity
for reorder, removal, focus and dashboard anchoring, while provider data may be
shared. The Shelf context removes the feature tile's outer outline in Light and
Dark while preserving its content, surface, internal strokes and state marks.
Do not substitute a new icon-and-label summary for the Dock renderer.
The Custom Dock is a separate app-owned surface; do not claim it is a native
subview of Apple Dock. Validate its visual placement and window behavior before
calling Shelf complete. Existing `UI-015` behavior applies to the DockMagic
icon in Dock Active mode.

Hybrid magnification applies only to ordinary Custom Dock items: Finder, Apps,
applications, overflow, stacks, minimized windows and Trash. It uses a 1.32×
peak with cosine neighbor falloff and treats the Shelf segment as a hard
boundary. Shelf slots, the trailing `+`, Shelf dividers and the resize divider
must remain fixed. Transform only artwork or thumbnails; button geometry,
pointer hit targets, running indicators, context menus, drag/drop targets and
accessibility frames stay at their original positions. Reduce Motion suppresses
the transform even when the saved magnification toggle is on.

### UI-020 — Keep the Calendar Dock tile date-led with a current-day indicator

The Calendar Dock tile shows only the abbreviated weekday, day number,
abbreviated month, and a conditional prominent red notification dot at the
top-right corner. Never render event/reminder times, titles, or other agenda
details in the tile; those belong in the hover dashboard. Show the dot when a
selected calendar event occurs at any time today or an unfinished due reminder
is included, even if an event has already ended. Use `DesignTheme.danger` only
for this bounded indicator; it must not tint nearby text, icons, or surfaces.
The tile's accessibility value must state when today has calendar items, so the
condition is not conveyed by color alone. Verify the composition across Dock
sizes and accessibility appearances.
The tile may use UI-021's shared Weather scene as a decorative background only
when the current condition is no older than 45 minutes. Without Location access
or fresh current data it remains neutral; daily forecast codes never drive it.
Date and dot must remain legible and dominant over the scene.

### UI-021 — Encode Weather conditions in bounded glyphs and scenes

Weather's Dock tile and hover dashboard use the shared semantic Weather
condition palette for the condition glyph and a matching token-backed scene:
sun, moon, cloud, wind, rain, ice, and storm. Show the scene only for live or
last-known weather; loading and unavailable surfaces stay neutral. Calendar's
Dock tile may reuse the same scene for fresh current weather under UI-020, never
for a selected date's forecast. The Calendar dashboard may use that shared
scene behind its selected-day forecast and hourly strip; this never changes
the Dock tile's current-condition rule. Subdued static SVG artwork may add weather
atmosphere over the solid token, but must remain
subordinate to information, with accessible high-contrast text and glyphs after
compositing in Light, Dark and Increased Contrast. Forecast glyphs may each use
their own condition color against the current scene. Controls, selection, focus,
and stale/error statuses retain their semantic roles. The glyph shape,
condition text, and accessibility label/value must identify weather without
relying on color or decorative art. Verify small Dock sizes, Reduced
Transparency and grayscale as well.

### UI-022 — Give Calendar content bounded, readable color

In the Calendar dashboard, dates with an event or included reminder show a
red dot independent of weather icons. Preserve the date, selected state, and
accessible item count. Forecast days use the approved generated SVG condition
pictograms; dates without forecast have no weather pictogram. Birthday,
holiday, and work agenda rows may use dedicated Calendar content-color roles
for a slim marker and explicit category label. Category inference is only a
visual hint and never changes EventKit data. All other agenda rows remain
neutral. Verify the grid and agenda in Light, Dark, Increased Contrast and
grayscale; event/reminder actions must remain usable. Calendar weather
pictograms in the date grid and selected-day details are prominent and render
without white icon badges or borders. Keep the condition label and hourly
values readable against the shared Weather scene.

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
