# DockMagic Maia Design System

Normative component and appearance contract. Start with [Design.md](../Design.md)
and [RULES.md](../RULES.md). [MAIA_COMPONENT_CATALOG.md](MAIA_COMPONENT_CATALOG.md)
maps the pinned 63 web primitives to native implementations or explicit deferrals.
See [MAIA_QA.md](MAIA_QA.md) for evidence, not assumed parity.

## Architecture

- Foundation: `DesignTheme`, `ProjectTheme`, `DSFonts`, `DSTypography`, `DSIconName`,
  geometry, motion, appearance and accessibility. OKLCH conversion happens here.
- Primitive: source-owned native components under `DesignSystem/Components`.
- Composition: shared Settings and dashboard modules under `Views/Shared`.
- Features own data, formatting, capability, persistence and actions. Components
  receive bindings/presentation models, never network clients, stores or defaults.

## Appearance and resources

System/Light/Dark persist as before. `DockMagicThemeRoot` installs Geist, neutral
tint, controls and a complete palette at every scene, popup and offscreen-render
boundary. All surfaces are opaque. No glass, gradients or tinted cards.

Codex and Antigravity pass `codexActivity` into the shared quota, chart,
momentum, intensity and model components. `codexActivityForeground` is the
accessible small data text variant on inset surfaces. Optional `accentForeground` on
`CodexShipMomentumCard` and `valueForeground` on `ShipMomentumGauge` separate
data text from fills while preserving neutral defaults for other callers.
The same data accent continues into supported daily detail and activity export;
controls and status keep their existing semantic roles.

Geist Regular/Medium/SemiBold/Bold are bundled and registered before UI. The
font cascade falls back per missing glyph (including ₫). HugeIcons Free Stroke
Rounded 4.3.3 template vectors are bundled, typed and checksum-pinned. Native
menus, file/permission/Share panels and terminal transcript typography are the
only platform/content exceptions; brand artwork retains authored colors.

## Component API

- `DSButtonStyle(emphasis:intent:size:)`: primary/secondary/outline/ghost/link;
  normal/destructive; 24/32/36/40 pt variants with minimum 36 pt hit area. Loading
  composes an accessible spinner and disables repeated action. No `kind:` adapter.
- `DSField`: visible label, helper/error and AX linkage. Native TextField and
  SecureField keep editing, IME, selection, clipboard and undo. `DSInputStyle`
  and `DSInputChrome` share 36 pt capsule geometry; textarea radius is 14.
- `DSSwitchStyle`, `DSCheckboxStyle`, `DSRadioGroup`, `DSSlider`: native activation
  and accessibility with shared state styling. Sliders retain native tracking.
- `DSSegmentedControl(title:selection:options:size:)` owns all short single-choice
  controls, including chart type, appearance, metric and range (UI-014). It uses
  Maia inset/raised surfaces, neutral focus, selected AX state and arrow navigation
  that skips disabled options. Value controls explicitly opt into editing focus,
  so Tab traversal does not depend on the system preference for ordinary buttons;
  disabled choices cannot receive focus. See Apple
  [focus interactions](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)).
  Features never rebuild segment chrome.
- `DSSelect` accepts typed selection/options, disabled options, details/icons,
  optional search, a custom option-identity builder and a rich trigger builder;
  focus, arrow navigation and Escape
  are shared. All app-owned dropdowns use this path, including Active Dock Feature,
  Search Console properties and Now Playing sources. Active Dock Feature passes
  the shared `DockFeatureIcon`, keeping every popup row identical to its Settings
  sidebar identity (UI-016).
- `DSMenu`, `dsPopover`, `dsDialog`, `dsAlert`: native presentation, shared Maia
  content, window-scoped interaction leases, Escape, default/cancel actions and
  focus restoration. The AppKit boundary handles presentation/focus only.
- `DSContentButtonStyle`: content/navigation activation with shared pressed, disabled and focus states; `DSSelectionSummary` supplies the named 48 pt rich-select trigger.
- `DSDialogButton` and `DSMenuButton` own action plus dismissal. Use them inside the shared popup builders; dismissal must not rely on a PrimitiveButtonStyle, which AXPress can bypass.
- `DSCard` / `dsCard`: header/content/footer slots, 24 pt regular or 16 pt compact padding,
  18 pt radius. Description/actions belong in the shared header composition.
- `DSDataState`: loading, available, empty, unavailable, stale, partial, failed
  with lastValue. Nil/NaN/infinity never become zero. `DSProgress` accepts optional
  values; feature presentation supplies scope, units and freshness.

## Settings and dashboard composition

Settings content starts at 1160 × 620 pt; sidebar 268, detail maximum 900, padding
52 horizontal/34 vertical. All 18 destinations share typography, controls,
sections, rows and production preview. Renderer color sections use the shared
palette, keep existing arbitrary saved colors visible and include Reset Defaults.

`DockHoverChrome` owns the common panel/elevation and the shared no-arrow
placement: the card keeps its dimensions and shifts into the former 10 pt
pointer space toward the Dock. Shared quota, momentum,
intensity, top-model cards, history viewport and plan badge live outside provider
views. `AIUsageDailyIntensityCard` owns the reusable 30-day intensity grid,
unknown-day marks, tooltip and timezone-aware labels. `AIUsageHistoryChart` owns
daily AI axes, bars, scrolling, hover, keyboard
focus, missing/partial state and accessibility. Provider adapters only normalize
their source values and formatting. The caller supplies the bounded data color:
Codex blue, Claude clay, or the contrast-resolved OpenCode/Augment appearance
color. Chart frames, legends and tooltips share chrome; data algorithms remain
specific to system history, market candles, activity, quota and calendar data.
Media and brand content remain within identity/artwork bounds.

`StreakContinuityStrip` has separate personal-streak and organization-activity
presentations. The organization variant shares geometry and day-state rendering
without showing personal badges or claiming realtime/user-level continuity.
All active day nodes are rendered by the shared `StreakDayNode` with
`DesignTheme.streakActive` and `onStreakActive`, including the compact strip,
celebration and badge-detail Recent activity. The green is confined to verified
day content; badge artwork, inactive/unknown/pending states and chrome retain
their existing roles.

Capability eligibility comes before composition. Account quota, local activity,
account authentication and data freshness are independent. Unsupported fields
are absent or explicitly unavailable. Stale/error states may retain last valid
data with a qualifier; never manufacture provider parity.

Dock click opens Settings immediately. Hover waits one continuous second and
only opens a supported dashboard. Popup leases include nested child windows,
prevent automatic hiding, restore key window/focus, and release monitors on close.
Repeated hover events do not replace the root of a live interacting dashboard.

## Dock and exports

Dock geometry stays proportional and previews use production renderers. Ring,
network, weather, calendar and market content retain their data semantics.
Neutral frame/track/outline and Geist apply everywhere; persisted renderer colors
remain unchanged. Export uses Geist and the same semantic colors, with the
existing eligibility/layout policy below.

### Activity card image export

- Codex, Claude Code, and Antigravity export a purpose-built activity card;
  popup insets, window shadows, capture menus, and the full
  dashboard layout are excluded.
- The 300 × 300 pt SwiftUI card is rasterized directly at 4× before encoding
  into an opaque 1200 × 1200 PNG. Enlarging a cached screen-resolution bitmap
  is insufficient. The save menu reports the fixed activity-card dimensions.
- Save, Copy, and Share all render the same dedicated `1200 × 1200` activity
  card with the provider identity, current earned badge, today's token total,
  and Ship momentum score/rank. The card uses neutral chrome plus the provider's
  existing single accent; badge colors stay inside the artwork silhouette.
- A compact, unlabeled 14-day area chart sits beside the token total. It uses a
  solid low-opacity fill plus a single accent stroke, with no gradient, axes,
  ticks, legend, or chart numbers. Missing calendar days remain gaps rather
  than becoming zero.
- Antigravity's activity card is available when the optional local bridge has
  an eligible current-day token observation. A meaningful 14-day chart uses
  the same caption-free treatment as Codex; sparse history instead shows a
  neutral `NO HISTORY` cue, not an invented plot. The token label remains
  `TOKENS OBSERVED TODAY` so local observation is not presented as complete
  provider history.
- When Antigravity has a reported `/usage` quota but not enough local activity,
  the header export control defaults to an activity-availability image using
  the Codex layout: locked badge unless independently earned, unavailable
  token and Ship values, neutral
  `NO HISTORY` cue, and quota-sourced `CHECKED`/`LAST KNOWN` date. Save, Copy,
  and Share expose only the activity layout, with no quota-data mode. The
  separate quota-detail renderer remains available for regression fixtures
  but is not selected in Antigravity's export manifest. Neither layout
  substitutes quota for token activity.

## Accessibility and future work

Text targets 4.5:1 and focus/meaningful boundaries 3:1 after compositing. Increased
Contrast strengthens outlines; Reduce Transparency retains opaque surfaces;
Reduce Motion removes transforms. Selection, disabled, validation and stale
state have non-color cues. Native single-selection, file, Share and permissions
retain their platform semantics. See Design.md for documented preset adaptations.

Before adding a component: reuse → inspect pinned catalog → add native primitive
and named variant → production gallery fixtures/state tests → integrate feature.
Do not add unused web-library equivalents. Verify Vietnamese/long strings,
keyboard/focus/AX, data edge cases, minimum sizes and all appearance variants.
