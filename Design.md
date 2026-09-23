---
version: alpha
name: DockMagic
description: "DockMagic Maia native design system. Pinned bbVKHJo / base-maia, Geist, HugeIcons, Neutral, opaque surfaces."
colors:
  primary: "#171717"
  primary-dark: "#E5E5E5"
  primary-foreground: "#171717"
  primary-foreground-dark: "#E5E5E5"
  on-primary: "#FAFAFA"
  on-primary-dark: "#171717"
  switch-active: "#0A84FF"
  switch-active-dark: "#0A84FF"
  on-switch-active: "#FFFFFF"
  on-switch-active-dark: "#FFFFFF"
  surface: "#FFFFFF"
  surface-dark: "#0A0A0A"
  surface-raised: "#FFFFFF"
  surface-raised-dark: "#171717"
  surface-inset: "#F5F5F5"
  surface-inset-dark: "#262626"
  on-surface: "#0A0A0A"
  on-surface-dark: "#FAFAFA"
  secondary: "#707070"
  secondary-dark: "#A1A1A1"
  outline: "#E5E5E5"
  outline-dark: "rgba(255, 255, 255, 0.1)"
  outline-strong: "#737373"
  outline-strong-dark: "#A1A1A1"
  warning: "#FF8D28"
  warning-dark: "#FF9230"
  warning-foreground: "#A94B00"
  warning-foreground-dark: "#FF9230"
  danger: "#E7000B"
  danger-dark: "#FF6467"
  danger-foreground: "#E30002"
  danger-foreground-dark: "#FF6467"
  focus: "#737373"
  focus-dark: "#A1A1A1"
  input-outline: "#E5E5E5"
  input-outline-dark: "rgba(255, 255, 255, 0.15)"
  codex-activity: "#006BC9"
  codex-activity-dark: "#0088FF"
  codex-activity-foreground: "#006BC9"
  codex-activity-foreground-dark: "#008FFF"
  streak-active: "#43A66A"
  streak-active-dark: "#57C07E"
  on-streak-active: "#121212"
  on-streak-active-dark: "#121212"
  weather-sun: "#B45309"
  weather-sun-dark: "#FBBF24"
  weather-moon: "#4338CA"
  weather-moon-dark: "#A5B4FC"
  weather-cloud: "#465C8B"
  weather-cloud-dark: "#CBCDE1"
  weather-wind: "#0F766E"
  weather-wind-dark: "#5EEAD4"
  weather-rain: "#006BC9"
  weather-rain-dark: "#42C6F7"
  weather-ice: "#027A94"
  weather-ice-dark: "#6AE4FF"
  weather-storm: "#7E22CE"
  weather-storm-dark: "#C4B5FD"
  weather-scene-sun: "#216691"
  weather-scene-sun-dark: "#15466C"
  weather-scene-moon: "#29355F"
  weather-scene-moon-dark: "#18213D"
  weather-scene-cloud: "#415773"
  weather-scene-cloud-dark: "#293C53"
  weather-scene-wind: "#256A72"
  weather-scene-wind-dark: "#184D57"
  weather-scene-rain: "#295683"
  weather-scene-rain-dark: "#1C416B"
  weather-scene-ice: "#2B697E"
  weather-scene-ice-dark: "#17495E"
  weather-scene-storm: "#4A3866"
  weather-scene-storm-dark: "#30264C"
  on-weather-scene: "#FFFFFF"
  calendar-birthday: "#C44958"
  calendar-birthday-dark: "#FF8C9A"
  calendar-holiday: "#A46508"
  calendar-holiday-dark: "#F3BF64"
  calendar-work: "#1F65A7"
  calendar-work-dark: "#7DBCF2"
typography:
  settings-title:
    fontFamily: "Geist"
    fontSize: 32px
    fontWeight: 700
  settings-headline:
    fontFamily: "Geist"
    fontSize: 20px
    fontWeight: 600
  settings-panel-title:
    fontFamily: "Geist"
    fontSize: 16px
    fontWeight: 500
  settings-body:
    fontFamily: "Geist"
    fontSize: 14px
    fontWeight: 400
  settings-label:
    fontFamily: "Geist"
    fontSize: 14px
    fontWeight: 500
  settings-metadata:
    fontFamily: "Geist"
    fontSize: 12px
    fontWeight: 500
  settings-caption:
    fontFamily: "Geist"
    fontSize: 11px
    fontWeight: 400
  settings-keycap:
    fontFamily: "Geist"
    fontSize: 11px
    fontWeight: 500
  dashboard-headline:
    fontFamily: "Geist"
    fontSize: 20px
    fontWeight: 600
  dashboard-panel-title:
    fontFamily: "Geist"
    fontSize: 16px
    fontWeight: 500
  dashboard-body:
    fontFamily: "Geist"
    fontSize: 14px
    fontWeight: 400
  dashboard-label:
    fontFamily: "Geist"
    fontSize: 14px
    fontWeight: 500
  dashboard-metadata:
    fontFamily: "Geist"
    fontSize: 12px
    fontWeight: 500
  dashboard-caption:
    fontFamily: "Geist"
    fontSize: 11px
    fontWeight: 400
  dashboard-metric:
    fontFamily: "Geist"
    fontSize: 24px
    fontWeight: 700
  dock-text:
    fontFamily: "Geist"
rounded:
  sm: 6px
  md: 26px
  lg: 18px
  xl: 14px
  full: 999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  field-group: 28px
  icon-gap: 6px
components:
  settings-button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.settings-label}"
    rounded: "{rounded.md}"
  settings-button-primary-dark:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.on-primary-dark}"
    typography: "{typography.settings-label}"
    rounded: "{rounded.md}"
  settings-button-secondary:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.on-surface}"
    typography: "{typography.settings-label}"
    rounded: "{rounded.md}"
  settings-button-secondary-dark:
    backgroundColor: "{colors.surface-raised-dark}"
    textColor: "{colors.on-surface-dark}"
    typography: "{typography.settings-label}"
    rounded: "{rounded.md}"
  dashboard-button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.dashboard-label}"
    rounded: "{rounded.md}"
  dashboard-button-primary-dark:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.on-primary-dark}"
    typography: "{typography.dashboard-label}"
    rounded: "{rounded.md}"
  switch-control:
    backgroundColor: "{colors.switch-active}"
    rounded: "{rounded.full}"
  switch-control-dark:
    backgroundColor: "{colors.switch-active-dark}"
    rounded: "{rounded.full}"
  switch-thumb:
    backgroundColor: "{colors.on-switch-active}"
    rounded: "{rounded.full}"
  switch-thumb-dark:
    backgroundColor: "{colors.on-switch-active-dark}"
    rounded: "{rounded.full}"
  dashboard-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  dashboard-panel-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.on-surface-dark}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-sun:
    backgroundColor: "{colors.weather-scene-sun}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-sun-dark:
    backgroundColor: "{colors.weather-scene-sun-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-moon:
    backgroundColor: "{colors.weather-scene-moon}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-moon-dark:
    backgroundColor: "{colors.weather-scene-moon-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-cloud:
    backgroundColor: "{colors.weather-scene-cloud}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-cloud-dark:
    backgroundColor: "{colors.weather-scene-cloud-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-wind:
    backgroundColor: "{colors.weather-scene-wind}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-wind-dark:
    backgroundColor: "{colors.weather-scene-wind-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-rain:
    backgroundColor: "{colors.weather-scene-rain}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-rain-dark:
    backgroundColor: "{colors.weather-scene-rain-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-ice:
    backgroundColor: "{colors.weather-scene-ice}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-ice-dark:
    backgroundColor: "{colors.weather-scene-ice-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-storm:
    backgroundColor: "{colors.weather-scene-storm}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  weather-scene-storm-dark:
    backgroundColor: "{colors.weather-scene-storm-dark}"
    textColor: "{colors.on-weather-scene}"
    typography: "{typography.dashboard-body}"
    rounded: "{rounded.lg}"
  settings-content:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.settings-body}"
  settings-content-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.on-surface-dark}"
    typography: "{typography.settings-body}"
  dashboard-metric:
    textColor: "{colors.on-surface}"
    typography: "{typography.dashboard-metric}"
  dashboard-metric-dark:
    textColor: "{colors.on-surface-dark}"
    typography: "{typography.dashboard-metric}"
  codex-activity-value:
    textColor: "{colors.codex-activity}"
    typography: "{typography.dashboard-metric}"
  codex-activity-value-dark:
    textColor: "{colors.codex-activity-dark}"
    typography: "{typography.dashboard-metric}"
  codex-activity-inset-value:
    textColor: "{colors.codex-activity-foreground}"
    typography: "{typography.dashboard-label}"
  codex-activity-inset-value-dark:
    textColor: "{colors.codex-activity-foreground-dark}"
    typography: "{typography.dashboard-label}"
  streak-day-active:
    backgroundColor: "{colors.streak-active}"
    textColor: "{colors.on-streak-active}"
    typography: "{typography.dashboard-caption}"
    rounded: "{rounded.full}"
  streak-day-active-dark:
    backgroundColor: "{colors.streak-active-dark}"
    textColor: "{colors.on-streak-active-dark}"
    typography: "{typography.dashboard-caption}"
    rounded: "{rounded.full}"
---

# DockMagic

## Overview

DockMagic uses the approved **Maia `bbVKHJo` / `base-maia`** preset as its
visual baseline: Geist, HugeIcons Free Stroke Rounded, Neutral colors,
component-specific rounded geometry and opaque surfaces. SwiftUI and AppKit
own native behavior. This is a native adaptation, not a React/Next application.

The baseline is the [pinned registry snapshot](docs/research/shadcn-bbVKHJo-2026-09-17/README.md)
and its `SHA256SUMS.txt`, researched with shadcn 4.21.0. Builds never fetch
`latest`. Upgrading means reviewing the registry/token diff, updating resource
checksums and rerunning native QA. The archived research recommendations are
historical; this approved contract supersedes their earlier SF/blue proposal.

YAML follows Google's DESIGN.md alpha format. **1 reference CSS px = 1 SwiftUI
layout point**; display scale is applied only when rasterizing. Unsuffixed
colors are Light, `-dark` are Dark. Feature code uses semantic Swift roles,
never YAML literals. See [RULES.md](RULES.md), [color contract](docs/COLOR_DESIGN_SYSTEM.md),
[component contract](docs/DESIGN_SYSTEM.md) and [catalog](docs/MAIA_COMPONENT_CATALOG.md).
Tokens describe requirements; the [QA record](docs/MAIA_QA.md) distinguishes
source, tests, snapshots and direct UI evidence.

## Colors

The source Neutral OKLCH tokens are converted to sRGB once in foundation assets,
with alpha preserved. `ProjectTheme` maps assets to `DesignTheme`; views consume
roles. The native palette manifest records the converted values and source
provenance. No new feature-local palette is allowed.

| Source role | Native semantic role | Light / Dark source OKLCH |
| --- | --- | --- |
| background | surface | 1 / .145 |
| foreground | textPrimary | .145 / .985 |
| card, popover | surfaceRaised | 1 / .205 |
| primary | action | .205 / .922 |
| primary-foreground | onAction | .985 / .205 |
| muted, accent | surfaceInset, selectionFill | .97 / .269 |
| muted-foreground | textSecondary | .556 / .708 |
| border | outline | .922 / white 10% |
| input | inputOutline | .922 / white 15% |
| destructive | danger | .577 .245 27.325 / .704 .191 22.216 |

Primary actions, focus, hover and selection are neutral. Semantic information,
processing, warning and danger remain available only for real states. Preserve
brand artwork and user-selected renderer/data colors inside their content,
preview, swatch and legend boundaries. Never reuse data colors for controls.
Dark sidebar selection uses the neutral accent rather than the source's
chromatic sidebar-primary token.

The user-approved enabled state of the shared `DSSwitchStyle` is the control
extension {colors.switch-active} / {colors.switch-active-dark}; its thumb uses
{colors.on-switch-active}. This blue identifies only an enabled binary switch.
The thumb position, label and accessibility value preserve the state without
color; no other action, focus, selection, status, or feature control inherits it.

The user-approved CPU & RAM, Network, Storage, Clock, Calendar, Now Playing and Batteries
marks are authored, original-color SVG identity artwork. Their solid hues stay
inside the fixed 22 pt sidebar / Active Dock Feature logo region; they do not
establish product palette tokens or color Settings chrome, controls, focus,
status, text or selection.

The user-approved Codex and Antigravity data accent is {colors.codex-activity}
in Light and {colors.codex-activity-dark} in Dark, matching the supplied blue
reference in Dark. `DesignTheme.codexActivity` colors quota progress, token
charts, Ship momentum, Daily intensity and Top models, including daily
drill-down and export where supported.
Small data text on inset surfaces uses {colors.codex-activity-foreground} /
{colors.codex-activity-foreground-dark} via `codexActivityForeground` for at
least 4.5:1 contrast. These are product data extensions, not changes to the
pinned Maia palette. Backgrounds, controls, focus, statuses and providers with
their own documented data hues retain their existing roles; quota warning/danger
overrides the blue locally.

Verified streak days use the bounded {colors.streak-active} /
{colors.streak-active-dark} content role with a dark check from
{colors.on-streak-active}. `DesignTheme.streakActive` is shared by the compact
continuity strip, celebration view and Recent activity in the badge detail.
Inactive, unknown and pending days retain their shape and semantic treatment;
the green never colors badge artwork, chrome, controls, focus or status.

Weather condition colors are bounded content roles for the Weather condition
glyphs and their current-condition scene. Sun, moon, cloud, wind, rain, ice and
storm use matching `weather-*` glyph and `weather-scene-*` solid background
tokens in the Weather Dock tile and hover dashboard, and behind the Calendar Dock
date only for fresh current conditions. {colors.on-weather-scene} is the
legible text color on these scenes. Seven SVG skies traced from original,
generated illustrations are subdued over the solid token; the artwork suggests the condition without
carrying meaning. The glyph silhouette, description and
accessibility label/value still work in grayscale. Loading and unavailable
surfaces remain neutral. Controls, focus and freshness status retain their
semantic roles; no code-generated gradient is used.

Calendar's selected-day forecast reuses the matching solid Weather scene and
authored artwork in one bounded panel above the agenda. Eight generated,
vector-traced pictograms in `CalendarWeather*.imageset` color only the month
forecast marks and hourly strip. Month and selected-day pictograms render larger
and directly on their surfaces, without a white badge or icon border. The
month grid keeps a separate
red event/reminder dot and occupies only the 4–6 weeks needed by the displayed
month. Agenda hints use {colors.calendar-birthday} /
{colors.calendar-birthday-dark}, {colors.calendar-holiday} /
{colors.calendar-holiday-dark}, and {colors.calendar-work} /
{colors.calendar-work-dark} only as slim content markers and labeled categories.
These hints never recolor controls, selection, EventKit data, or the Dock tile.

Accessibility adaptations are explicit: focus uses .556 Light / .708 Dark,
strong boundaries use the same contrasting neutral family, Dock track is .6
in both modes and Dock outline is .145 / .922. Light secondary/tertiary foreground uses OKLCH .545 (source .556), and danger
foreground .565 .245 27.325 (source L .577), to meet 4.5:1 on inset surfaces; these do not change persisted
renderer colors. Ordinary source borders retain their subtle alpha; Increased
Contrast uses `outlineStrong`. Text targets 4.5:1 and meaningful control
boundaries/focus 3:1 after compositing. Disabled controls are visibly inactive
and cannot act. State also has text, icon, shape or selection semantics.

## Typography

Every DockMagic-owned surface uses **bundled Geist**: Settings, dashboard,
Dock renderer, production preview and export. `DSTypography` provides semantic
roles; proportional renderers use `DSTypography.font(size:weight:)`.

| Role | Size / weight |
| --- | --- |
| Settings title | 32 / Bold |
| Headline | 20 / SemiBold |
| Panel title | 16 / Medium |
| Body, input | 14 / Regular |
| Button, label | 14 / Medium |
| Section title | 14 / SemiBold |
| Metadata | 12 / Medium |
| Caption | 11 / Regular |
| Metric | 24 / Bold |

Regular, Medium, SemiBold and Bold OTFs are pinned to Geist revision
`10dc7658f13c38a474cde201bb09a4617267545b`, bundled under `MaiaFonts`, and process
registered before UI or renderer creation. PostScript names are verified by
tests. CoreText's system cascade supplies missing glyphs such as `₫`; it does
not substitute the entire font. Test Vietnamese NFC/NFD, numerals and long
strings. Use monospaced digits for changing numbers, native line metrics and
wrapping rather than shrinking important labels.

System-owned permission, file, Share and app menus keep system typography.
Embedded terminal transcripts retain a monospaced font for terminal cell
alignment. Brand text inside supplied artwork remains untouched. These are
content/platform exceptions, not precedent for feature UI.

## Layout

Use spacing 4/8/12/16/24/32, field gap 12, field-group gap 28 and icon gap 6.
`DSCard` owns header, description/actions composition, content and footer
padding: 24 regular, 16 small. Feature views do not rebuild card chrome.

Settings starts at 1160 × 620 pt content, sidebar 268, detail maximum 900,
horizontal padding 52 and vertical padding 34. Rows retain full hit areas.
Controls default to 36 pt visual height; compact 24/32 pt variants still have
a minimum 36 pt interaction target. Icons default to 16 pt within that target.

Dashboards use `DockHoverChrome`, shared metric/quota/history/chart modules and
provider capability decisions. Daily AI histories use `AIUsageHistoryChart`;
provider adapters normalize values, missing/partial state and labels without
drawing their own bars, axes or hover behavior. Callers may provide a bounded
data-series color for their plot. Preserve each renderer's data algorithm and
chart geometry. Do not create values merely to equalize provider layouts.
Hover dashboard cards do not display a popover arrow. Their unchanged card
geometry shifts toward the Dock through shared chrome by the former pointer
extent, placing the Dock-facing card edge at the former arrow-tip position.
Daily intensity uses `AIUsageDailyIntensityCard`; callers supply the metric label,
timezone, missing bucket IDs and data color. Continuity may reuse
`StreakContinuityStrip` only with a named presentation that preserves whether the
source represents a personal streak or organization-level reported activity.
Dock geometry remains proportional at 32/48/64/128 pt. Preview uses the same
production renderer. Export uses its dedicated 1200 × 1200 layout and one
artifact for Save/Copy/Share; activity and quota eligibility remain distinct.
The Calendar Dock tile presents only abbreviated weekday, day number and
abbreviated month, plus a bounded `danger` dot when today's selected events or
unfinished due reminders exist. Agenda details stay in the hover dashboard;
the date remains visible without Calendar or Reminders access. A shared Weather
scene may sit behind this date when current conditions are at most 45 minutes
old. With no Location access or stale data the background stays neutral; the
date and red dot remain the focal, contrast-safe content.

Dock click opens Settings immediately. Continuous hover for one second opens
only a supported dashboard; a click cancels pending hover or closes an open
dashboard before opening Settings. Popup interaction leases keep a dashboard
alive while its menu, select or dialog is open.

Dock Active and Shelf are exclusive modes. Dock Active keeps one feature on the
DockMagic icon in Apple Dock. Shelf is a Dockset-like, app-owned Custom Dock
segment: each slot uses that feature's existing `DockTileView` presentation,
including repeated features, but suppresses the tile's outer outline in both
Light and Dark appearances so the tile belongs to the continuous Custom Dock
surface. Internal renderer strokes, state marks and the rounded square dashed
`+` remain visible; the `+` stays last as new slots are added. Hover targets and
focus belong to stable slot IDs. The Shelf uses the Custom Dock's one continuous
adaptive material with no independent
fill or nested blur; two semantic hairline dividers mark its boundaries. The
previous companion panel beside Apple Dock, with separate icon-and-label
summaries, does not satisfy Shelf. See the latest Shelf study before changing
Dock or Settings behavior.

Custom Dock uses the approved Hybrid magnification preset for Finder, Apps,
applications, overflow, stacks, minimized windows and Trash. The item under the
pointer reaches a nominal 1.32× scale; neighbors use cosine falloff over a
radius of 1.75 × icon size, normally producing about 1.08–1.11× for the first
neighbor. Motion uses `interactiveSpring(response: 0.16,
dampingFraction: 0.88, blendDuration: 0.04)` with the visual anchor toward the
screen: up from a bottom Dock, right from a left Dock and left from a right Dock.
The panel never expands. The engine reduces scale only when needed to keep
artwork within panel bounds or on its own side of the Shelf.

The Shelf is a hard motion boundary: its feature slots, trailing `+` and both
semantic dividers do not scale, shift or propagate magnification. The resize
divider is also fixed. Only artwork or a window thumbnail transforms; the
Button, pointer hit target, running indicator, context menu, drag/drop target
and accessibility frame retain their original geometry. Reduce Motion resolves
every transform to identity while preserving the user's saved magnification
choice. New Custom Dock configurations enable this preset; a saved choice is
retained and legacy data without the field decodes to the former disabled state.

## Elevation & Depth

All app-owned surfaces are **opaque**, including sidebar, chrome, popup and
hover panel. The outer Custom Dock surface alone may use a public macOS
material so it responds to wallpaper and appearance like a Dock surface;
its Shelf group remains part of that continuous surface and uses semantic
hairline dividers instead of another fill or material. Under Reduce Transparency the
Custom Dock outer surface resolves to an opaque neutral role. System/Light/Dark
selects a palette for every other surface. Do not add glass elsewhere,
code-generated gradients, colored glow or tinted cards outside the bounded
Weather scene artwork described above. The floating host alone owns shadow:
primary radius 10/y 5, secondary radius 5/y 2. Nested metrics and charts use
spacing and borders without stacked shadows.

## Shapes

| Element | Geometry |
| --- | --- |
| Button, input, select | capsule; default height 36, horizontal padding 12 |
| Card, dashboard panel | radius 18 |
| Textarea, inset | radius 14 |
| Checkbox | 16 square, radius 6 |
| Switch | 32 × 18.4, thumb 16; enabled track uses the dedicated blue switch role |
| Slider | track 12, no visible thumb; native tracking and keyboard retain the hidden knob geometry |
| Small/keycap, row | radius 6, 8 |

The complete radius scale is 6/8/10/14/18/22/26. YAML `md` maps to control,
`lg` to card, `xl` to textarea; names are interchange roles, not a linear size
ordering. Concentric geometry uses `max(0, parentRadius - padding)`. Data marks,
ring arcs and brand silhouettes retain their domain geometry.

## Components

| Need | Shared implementation |
| --- | --- |
| Buttons | `DSButtonStyle(emphasis:intent:size:)`, `DSIconButtonStyle`; loading composes spinner plus disabled interaction |
| Label/helper/error | `DSField`; native text editing through `DSInputStyle`, `DSTextInput`, `DSSecureInput`, `DSTextArea` |
| Selection | `DSSwitchStyle`, `DSCheckboxStyle`, `DSRadioGroup`, `DSSegmentedControl`, `DSSelect` with optional search |
| Slider | `DSSlider` / `DSNativeSlider`, thumbless Maia drawing with native tracking, keyboard and AX |
| Popup | `DSMenu`, `dsPopover`, `dsDialog`, `dsAlert`; per-window presentation/focus leases |
| Content | `DSCard`, status badge/card, loading/empty/error, `DSProgress`, `DSMetricCard` |
| Settings | `DSSettingsSection`, action/link/connection rows, renderer palette and production preview |
| Dashboard | shared shell, header, identity, plan badge, metric/quota/history cards, `AIUsageHistoryChart`, chart frame/legend/tooltip |
| Icons | typed `DSIconName` + `DSIcon`; bundled HugeIcons Free Stroke Rounded template vectors |

HugeIcons Free 4.3.3 assets are a selected subset, pinned with package and file
checksums and MIT attribution. A typed enum is the public API. The compatibility
symbol resolver handles existing domain/persisted symbol names; it never draws
SF Symbols for app-owned UI. Add actual required icons through the import
script and catalog, not remote runtime loading.

Native system menus, permission/file dialogs and Share panels remain native.
All app-owned selection uses `DSSegmentedControl` for short option groups
(including chart type) or `DSSelect` for dropdown/search per UI-014. The segment
list adapts pinned Maia tabs: inset capsule track, raised selected segment,
neutral focus/border and Geist labels. Regular height is 36 pt; compact segments
keep a 36 pt hit target. Arrow keys skip disabled options; Enter/Space activates
the focused button. Rich select triggers share the same popup/search/focus path.
Date/time editing retains
native calendar/locale behavior within shared fields. Text editing preserves
IME, selection, paste and undo. Escape closes popups, default/cancel actions
use native key equivalents, and focus returns to the trigger. Nested popups
belong to the hover interaction region; monitors are removed when it closes.

Presentation models distinguish loading, available, empty, unavailable, stale,
partial and error with retained data. Nil, NaN and infinity are unavailable,
not zero. Components receive values/bindings/actions and never read provider
stores, call networks or persist defaults. Feature code owns formatting,
capability, freshness, data acquisition and persistence.

Feedback: button press 120 ms, row hover 160 ms, focus 140 ms; Reduce Motion
removes movement, including Custom Dock magnification. Value changes retain existing domain-aware motion; do not
animate unavailable data from zero. Static Dock/export renders use final frames.
The older motion proposal is historical where it contradicts these approved
geometry/typography decisions; unimplemented chart-motion proposals remain
proposals.

`DSContentButtonStyle` is the transparent content variant for chart marks,
calendar/media controls and navigation rows: it preserves content geometry and
selection, adds shared pressed/disabled feedback and a neutral focus ring.
`DSMetricCard` uses 24 pt values. Export menus use the shared 208 pt-wide
`DSExportActions`, with 36 pt minimum action rows and optional layout caption.

**Future component workflow:** check the shared library first → compare the
pinned 63-component catalog → implement a native primitive in DesignSystem →
add production gallery states and verification → compose the feature from it.
Name and document every new variant. Deferred catalog items have no current
consumer; do not build unused components solely for web-library parity.

Popup actions use `DSDialogButton` / `DSMenuButton`; their actual Button action
includes dismissal, so Accessibility activation follows the same path as mouse
and keyboard. Do not implement dismissal only in a PrimitiveButtonStyle.

The named `DSSelectionSummary` rich-select variant uses a 48 pt trigger with
identity, title and description; its popup uses `DSSelect` with the shared selection/search keyboard path.
The Active Dock feature selector supplies `DockFeatureIcon` through the select's
option-identity builder, so its trigger, every searchable popup row and the
Settings sidebar use the same feature logo.

## Do's and Don'ts

- Reuse semantic roles and production components; preserve renderer colors,
  provider capability and persisted preferences.
- Verify Light/Dark, Increased Contrast, Reduce Transparency/Motion, grayscale,
  keyboard/AX, Vietnamese IME/paste/undo, long labels and minimum window size.
- Test zero, absent/invalid, partial/stale, permission failure and retained data.
- Keep source/build, automated test, render snapshot and real Dock/UI evidence
  separate. See the QA record for actual results and unresolved environment limits.
- Do not reintroduce SF/blue/glass as app UI policy beyond the documented
  `DSSwitchStyle` enabled-track exception; do not add decorative gradients,
  local palettes, unsupported provider parity, or fabricated zero observations.
- Keep source, bundle resources, catalog and documents synchronized; run
  `npx --yes @google/design.md@0.4.0 lint Design.md` after format changes.
