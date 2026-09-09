# DockMagic Design System

## 1. Contract

The design system separates its foundation from product decisions:

```text
DesignSystem
  ├─ typography, spacing, radius, motion
  ├─ semantic roles, surfaces, controls, status/settings components
  └─ has no knowledge of RGB/hex values or specific features

ProjectTheme
  ├─ maps semantic roles to DS… Color Set assets
  └─ provides opaque fallbacks for Reduce Transparency

DockMagicThemeRoot
  └─ installs the selected theme, tint, and appearance at the scene/AppKit host boundary
```

The normative color-usage contract is defined in
[COLOR_DESIGN_SYSTEM.md](COLOR_DESIGN_SYSTEM.md). It limits normal UI to a
neutral family plus one action accent, permits semantic color only when it
carries state, and prohibits product gradients. This document defines the
broader component and appearance architecture; the color contract wins if a
legacy example conflicts with it.

Feature views do not create one-off materials, shadows, focus rings, or status
colors. Dock ring and chart colors are preferences owned by the product model
because users can change them; a renderer receives only the corresponding
appearance model as input.

## 2. Appearance

DockMagic persists three color-scheme options: **System, Light, and Dark**.
`DockMagicThemeRoot` applies the color scheme, semantic tint, and surface
contract to both the Settings scene and the Dock `NSHostingView`. Liquid Glass
is the default chrome for all three modes and applies only to navigation and
chrome; primary content remains opaque. On macOS 14 with Xcode 15.4, glass uses
a material fallback. Native `glassEffect` is only an availability-gated path
for newer toolchains and macOS versions, and it has not been verified in the
current environment.

Named assets must meet contrast requirements on opaque Light and Dark surfaces.
Dock-specific tracks, backgrounds, and outlines also require a real compositor
pass before release.

## 3. Semantic roles

- Action: `action`, `onAction`.
- Accent foreground: `…Foreground` roles are used for text and icons on
  content; bright base action and status colors are used for fills.
- Status: `information`, `processing`, `warning`, `danger`, and the
  corresponding on-color roles.
- Text: `textPrimary`, `textSecondary`, `textTertiary`.
- Structure: `focus`, `outline`, `outlineStrong`, `shadow`, `selectionFill`,
  `selectionOutline`.
- Surface: `surface`, `surfaceRaised`, `surfaceInset`, `surfaceChrome`, and four
  opaque fallbacks.
- Dock chrome: `dockTrack`, `dockBackgroundRaised`, `dockBackgroundInset`,
  `dockOutline`, `dockForeground`.

Status always uses a semantic role. CPU, RAM, Network, Storage, Codex, and
Claude Code renderer colors must not be reused as status colors because they
are personal choices and may not carry a consistent meaning outside the
renderer. The Weather condition palette is part of the renderer, while
freshness and error badges still use the semantic `warning` and `danger` roles.

Semantic roles are not permission to show every hue simultaneously. Normal
chrome is neutral plus `action`; information, processing, warning, and danger
replace the local accent only when a real state requires them. See the color
budget and bounded exceptions in `COLOR_DESIGN_SYSTEM.md`.

## 4. Foundation tokens

| Group | Contract |
| --- | --- |
| Radius | 8 / 12 / 16 / 24 pt, dynamic capsules, and concentric radii |
| Spacing | 4 / 8 / 12 / 16 / 24 / 32 pt |
| Typography | title 32, headline 20, panel 16, body/section 14, metadata 12, caption 11, metric 24 pt |
| Motion | 0.12–0.16 s feedback, 0.32 s metric changes, and bounded 0.24–0.36 s Clock digit transitions; respects Reduce Motion |
| Rows | content/action rows at least 46 pt; compact sidebar rows at least 30 pt; full-row content shapes and independent focus/selection |

The surface hierarchy is `shell → panel → raised → inset → chrome`. Nested
cards do not create their own shadows; the outer floating host owns the larger
elevation.

## 5. Settings composition

- Primary window: `1160 × 620` content plus native title-bar/capture chrome, yielding
  an initial outer size of approximately `1160 × 724`.
- Native `NavigationSplitView`, fixed `268` pt sidebar.
- Detail content is capped at `900` pt with `52` pt horizontal and `34` pt
  vertical padding.
- Destinations: General, CPU & RAM, Network, Storage, Weather, Batteries, Codex,
  Claude Code, Antigravity, and About.
- Detail content uses `DSSettingsSection`, `DSStatusCard`, and native `Picker`,
  `ColorPicker`, `Slider`, `LabeledContent`, and `Button` controls.
- The preview uses the production Dock renderer; there is no separate simulated
  renderer.
- Controls change preferences immediately. If the feature is active, the Dock
  updates immediately.
- General includes an appearance picker; the footer reflects the current mode.

## 6. Dock composition

- Tile geometry is always proportional to its side length and does not depend
  on the Settings preview size.
- `DockTileView` centers each tile at 824/1024 of the icon canvas width and
  height, matching the visible footprint of standard macOS icons. This inset
  applies once to all features and Settings previews without lowering raster
  resolution.
- Outer and inner rings have feature-specific default colors but share the same
  clamping model.
- Storage uses one ring. Network uses two series that diverge around a baseline,
  share a scale, and do not reuse the ring metaphor.
- Weather does not use a ring: a solid semantic background, condition symbol,
  and temperature establish reading order. H/L appears only when the tile is
  large enough to preserve the 32/48 pt layouts. Existing gradients are legacy
  migration debt and are not precedent for new renderer work.
- Tracks, backgrounds, and outlines use semantic assets.
- Progress is not communicated by color alone: the renderer provides complete
  accessibility labels and values.
- Loading, stale, and unavailable states have appropriate symbols and text
  semantics.
- Animation is enabled in previews but disabled in the AppKit Dock host.

### Dashboard image export

- Codex, Claude Code, and Antigravity PNGs contain the complete dashboard card, including its
  normal internal padding and rounded outline. External popup insets, the Dock
  pointer, window shadows, and capture menus are excluded.
- Export uses the same card layout as the live dashboard. Only the rounded
  corners are transparent; no surrounding white or transparent canvas is added.
- SwiftUI content is rasterized at 4× before encoding. Enlarging a cached
  screen-resolution bitmap is insufficient. The save menu reports the actual
  card pixel dimensions for the current Dock edge.
- Save, Copy, and Share use the same PNG. Claude Code and Antigravity preserve the selected
  Tokens/Cost metric in that image.

### Antigravity

- Use the shared usage dashboard, ring renderer, numeric tile, chart, streak,
  and Ship momentum components. The vendor logo stays in the header identity
  region. Dashboard chrome uses the shared action role.
- Settings and the hover dashboard do not expose model group selection. Legacy
  selections are cleared; Settings, Dock, and dashboard automatically select the
  group with the lowest reported remaining quota. The dashboard header omits the
  model-group/live row.
- Antigravity Settings shows connection state through one icon in the upper-right
  corner of Dock preview, matching Codex/Claude. Hover reveals details; clicking
  connects or retries. There is no separate Connection or Model quota section,
  and no Preview dashboard button.
- Show only reported quota buckets. Legacy model quota has no inferred duration;
  labels read `Model quota`/`QUOTA` and `Window not reported`.
- Missing token history and unreported costs stay unavailable; observed history
  is labeled partial. Completion and stale event expiry remove active work.

## 7. Accessibility

- Reduce Transparency replaces material with the matching opaque role.
- Increased Contrast strengthens outlines and focus indicators when supported
  by the component.
- Reduce Motion removes nonessential animation.
- Icon-only controls must have a label, help text, and stable identifier.
- Decorative backgrounds, preview ornaments, and active dots are hidden from
  the AX tree.
- A sidebar row is a single accessibility element with a stable identifier and
  an `Active` value when its feature is being displayed.
- The native menu `Picker` guarantees exactly one active feature and preserves
  keyboard and AX single-selection semantics.
- Do not place an identifier too high in a container when SwiftUI might
  propagate it to multiple descendants.

## 8. Checklist for new UI

1. Choose the owner and semantic role before writing the layout.
2. Use existing tokens and components. When something is missing, add a shared
   primitive with the appropriate hover, pressed, focus, disabled, and error
   states.
3. Apply the color budget: neutral plus one accent in normal UI, semantic color
   only for real state, monochrome interface icons, and no product gradients.
4. Test Light, Dark, and Liquid appearances; Increased Contrast; Reduce
   Transparency; Reduce Motion; pointer and keyboard input; and long content.
5. Check AX uniqueness and hittability, not just existence.
6. Render the Dock at 32/48/64/128 pt and inspect a Settings runtime screenshot.
7. Before release, observe the real system Dock at multiple sizes and positions;
   snapshots and the AX tree do not prove the compositor's final output.
