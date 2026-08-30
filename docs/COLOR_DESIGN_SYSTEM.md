# DockMagic Color Design System

**Status:** Normative. This document is the source of truth for color usage in
DockMagic-owned UI. It applies to Settings, hover dashboards, popovers, Dock
renderers, shared components, and any new product surface.

The goal is not to remove meaning from the interface. The goal is to make color
rare enough that it means something when it appears.

## 1. Core contract

DockMagic uses a **neutral-first, one-accent** visual language:

```text
Default surface       = neutral family + one action accent
Data comparison       = neutral family + at most two data hues
Warning/error surface = neutral family + one semantic status hue
```

A normal surface must not display several unrelated accent hues at once.
Warning, danger, information, and processing colors are states, not decoration.
When a semantic state becomes prominent, it replaces the action accent within
that local component instead of being added on top of it.

The neutral family includes Light/Dark surface, text, outline, and shadow roles.
Different neutral values and opacities create hierarchy without increasing the
chromatic color count.

## 2. Color budget

### Screen chrome

- Window backgrounds, navigation, cards, rows, dividers, labels, metadata, and
  inactive icons use neutral roles.
- One action hue may be used for the primary action, current selection, focus,
  or the most important active state.
- Hover is neutral. Hover alone does not introduce a new hue.
- A screen must not give every feature, card, row, or icon its own accent.

### Local components

- A component uses either its action accent or its semantic status color, not
  both as competing fills.
- Warning and danger colors remain local to the affected icon, label, progress
  element, or blocking message.
- Do not tint the whole card for a passive status. A full semantic fill is
  reserved for a compact badge, destructive confirmation, or blocking state
  whose meaning remains clear without color.
- If removing a color does not change meaning, remove it.

### Visible-color limit

For DockMagic-owned interface elements in a single surface:

1. Use the neutral family.
2. Add at most one persistent action hue.
3. Add at most one conditional semantic hue only when a real state requires it.

The result should normally read as two families: neutral plus accent. A third
family is exceptional and temporary. Data and brand exceptions are defined in
Section 7 and must remain visually contained.

## 3. Semantic palette

Feature code chooses a semantic role. It does not choose RGB, hex, a system
color name, or a convenient color borrowed from another feature.

The current canonical product values are:

| Family | Semantic asset | Light | Dark | Runtime role |
| --- | --- | --- | --- | --- |
| Canvas neutral | `DSSurface` | `#F5F4F2` | `#1F1E1E` | Default content background |
| Raised neutral | `DSSurfaceRaised` | `#FFFFFF` | `#1F1E1E` | Raised content surface |
| Primary text | `DSTextPrimary` | `#000000` | `#FFFFFF` | Main content and default icon |
| Action blue | `DSAction` | `#0088FF` | `#0091FF` | The single persistent product accent |
| Claude usage data | `DSClaudeCodeUsage` | `#D97757` | `#D97757` | Quota progress inside the Claude dashboard only |
| Warning orange | `DSWarning` | `#FF8D28` | `#FF9230` | Conditional warning only |
| Danger red | `DSDanger` | `#FF383C` | `#FF4245` | Conditional error/destructive state only |

These values document the existing named assets; they must not be copied into
feature code as literals. Secondary surfaces, text, outlines, on-colors, and
accessibility variants continue to resolve through semantic assets.

| Role | Purpose | Use | Do not use |
| --- | --- | --- | --- |
| Neutral surfaces | Structure and depth | Window, panel, raised/inset content, popover | Feature identity or status |
| Neutral text | Reading hierarchy | Primary, secondary, tertiary text and inactive icons | Disabled text through arbitrary low opacity |
| Action | Primary interaction | Primary action, selection, focus, active control | Decoration, every clickable control, passive metrics |
| Information | Important non-critical message | A true informational state with label or symbol | General help text or blue decoration |
| Processing | Work currently in progress | Progress indicator plus text/value | A permanent green/mint accent |
| Warning | Recoverable attention state | Stale data, degraded service, action required soon | Decorative orange cards or icons |
| Danger | Failure or destructive consequence | Error, failed connection, destructive action | General emphasis or branding |
| Data series | Quantitative differentiation | One or two series inside a chart/renderer | Settings chrome, status, unrelated icons |
| Brand asset | Identity supplied by the service | Original logo inside a bounded logo region | Tinting surrounding surfaces or controls |

`information` and `processing` are compatibility roles, not additional
persistent accents. New UI should prefer neutral explanatory text and the
action family unless a distinct state materially improves comprehension.

The concrete palette remains owned by `ProjectTheme` and named Color Set
assets. Shared components consume `DesignTheme`; feature views must not create
their own palette.

## 4. Decision rule

Before applying a chromatic color, answer these questions in order:

1. **Does the user lose meaning if this color is removed?** If no, use a neutral.
2. **Is this the primary action, current selection, or keyboard focus?** Use the
   action role.
3. **Is this a real information, processing, warning, or danger state?** Use the
   matching semantic role and also provide text, a symbol, shape, or value.
4. **Is this color differentiating quantitative series?** Keep it inside the
   renderer and obey the data rules below.
5. **Is this an original brand asset or user-selected color?** Keep it inside
   its explicit brand, preview, swatch, or renderer boundary.
6. Otherwise, reject the color.

No component may introduce a new hue merely to feel lively, premium, layered,
or more visually interesting.

## 5. Component rules

| Element | Required treatment |
| --- | --- |
| Surface/background | Neutral semantic surface only. Content popovers and hover dashboards use an opaque semantic surface. |
| Material/glass | Navigation chrome only. It must not cause wallpaper color to become part of content hierarchy. |
| Border/divider | Neutral outline roles. No colored border unless it communicates focus, selection, or status. |
| Shadow | Neutral shadow only. No colored glow. The outer floating host owns elevation. |
| Text | Neutral text roles by default. Accent text only for links/actions; semantic text only for real status. |
| Interface icon | Monochrome or hierarchical in one hue. Default to neutral; use action/semantic color only when meaning requires it. |
| Button | Primary may use action fill. Secondary and tertiary buttons remain neutral. Destructive uses danger only for the destructive action. |
| Selection/focus | One action family through `selection…` and `focus` roles. Do not add another feature-specific tint. |
| Hover/pressed | Change neutral fill, opacity, weight, or elevation. Do not add a new hue. |
| Badge/status | Compact semantic color plus text/symbol. Do not color an unrelated container. |
| Progress | One solid hue. Track remains neutral. Warning/danger replaces the progress hue only when the progress itself is in that state. |
| Chart, one series | One solid data hue. Use opacity, stroke, labels, or markers for history and emphasis. |
| Chart, two series | At most two data hues, confined to the chart and legend. Surrounding chrome remains neutral. |
| Chart, three or more series | Prefer labels, shapes, line styles, grouping, or interaction before adding hues. Requires an explicit design review. |
| Empty/loading state | Neutral by default. Processing color is optional and local; animation or text carries the state. |

## 6. Prohibited patterns

The following are not allowed in DockMagic-owned UI:

- `LinearGradient`, `RadialGradient`, or `AngularGradient` used as product
  styling, including backgrounds, borders, progress fills, and chart fills.
- Multiple unrelated accent colors in the same card, popup, toolbar, or row.
- Full-color interface icons where a monochrome SF Symbol communicates the same
  action.
- Feature or renderer colors reused for Settings chrome, popup chrome, status,
  selection, focus, or buttons.
- Colored card backgrounds used only to make sections feel distinct.
- Colored shadows, glows, rainbow borders, or specular gradients.
- A status communicated only by red, orange, green, or another hue.
- Direct `Color.red`, `Color.blue`, RGB, hex, or asset lookup in feature views
  when a semantic `DesignTheme` role exists.
- Introducing a new Color Set before defining its semantic owner, allowed
  surfaces, Light/Dark values, and contrast evidence.

Legacy occurrences are migration debt, not precedent for new work.

## 7. Bounded exceptions

Exceptions are allowed only when color is the content rather than decoration:

- An original application/service logo may retain its authored colors inside a
  fixed logo region. Those colors do not tint nearby text, icons, or surfaces.
- A color picker or swatch gallery may show many choices because choosing color
  is the task. All surrounding UI remains neutral.
- User-selected Dock renderer colors remain inside the renderer, its preview,
  and its color controls. They do not become semantic status or chrome colors.
- A two-series chart may use two data hues when labels, shapes, or positions
  alone are insufficient. Its legend must repeat the series names.
- Claude Code quota progress may use `DSClaudeCodeUsage` as its single data
  hue inside the dashboard quota rows and chart. It must not tint chrome, text,
  selection, or status; warning and danger replace it at their thresholds.
- Streak milestone badge artwork may use multiple authored solid colors because
  the collectible identity is the content. Those colors stay inside the badge
  silhouette; they must not become SwiftUI palette tokens or tint the
  surrounding card, text, navigation, progress,
  selection, focus, or status. Locked badges also use a lock symbol, label,
  lower emphasis, and grayscale-safe structure. Badge artwork must not use
  colored glow, a rainbow border, or code-rendered product gradients.
- Photography, weather imagery, and other content media are not UI palette
  tokens, but their container and controls still follow this contract.
- System-owned macOS UI keeps its native appearance.

Any new exception must be documented here. A feature-local comment or an
allowlist entry is not sufficient by itself.

## 8. Accessibility and appearance

- Text and meaningful icons must meet at least `4.5:1` contrast for normal text
  and `3:1` for large text. Control boundaries and meaningful non-text graphics
  must meet at least `3:1` against adjacent colors.
- Color never carries state alone. Pair it with text, a symbol, shape, position,
  line style, or accessible label/value.
- Light and Dark values are semantic counterparts, not simple inverted RGB.
- Increased Contrast strengthens boundaries without adding hues.
- Reduce Transparency replaces material with the matching opaque neutral role.
- Grayscale must preserve reading order, selection, progress, and status.
- Disabled content remains legible and is distinguished by control state, not
  arbitrary opacity alone.

## 9. Ownership and implementation

```text
Named Color Set assets
  -> ProjectTheme maps product values to semantic roles
  -> DesignTheme exposes roles to shared components
  -> shared components render states
  -> feature views provide content and semantic intent
```

- Add or change concrete color values only in named Color Set assets and
  `ProjectTheme`.
- Add a semantic role only when it will be shared and its meaning is stable
  across features.
- Prefer extending an existing shared component over styling a feature view.
- Renderer appearance models may own user-configurable data colors, but those
  values stop at the renderer/preview boundary.
- Brand assets remain assets; do not extract a palette from them for UI chrome.

## 10. Review and enforcement

Every UI change that introduces or changes color must include:

1. The semantic role and owner of each chromatic color.
2. A visible-color count for the affected surface.
3. Confirmation that no gradient or colored glow was added.
4. Light and Dark screenshots of the real affected state.
5. Increased Contrast, Reduce Transparency, and grayscale checks when relevant.
6. Evidence that status, selection, and data remain understandable without
   color alone.
7. A source scan for new gradients, direct colors, and feature colors leaking
   outside their boundary.

A review must reject the change when the author cannot explain what user
meaning would be lost by removing an added color.

## 11. Migration policy

This contract applies immediately to all new UI and changed UI. Existing color
debt must not be copied into new components.

As of 2026-08-25, production Swift contains eight legacy gradient constructors
across five files. They should be removed in this order:

1. Shared `DesignSystem` components.
2. Dock Weather, Battery, and Metrics renderers.

The Codex hover dashboard has completed this migration and must remain at zero
product gradients.

Until the legacy count reaches zero, repository checks should reject any
increase. After migration, any product gradient is a hard failure unless this
document is explicitly amended first.

## 12. Definition of done

A color change is complete only when:

- the surface is neutral-first and stays within its color budget;
- every chromatic color has one semantic or content-specific purpose;
- interface icons are monochrome unless a bounded exception applies;
- no product gradient, colored glow, or decorative tinted card was added;
- status and selection remain understandable in grayscale;
- Light, Dark, and relevant accessibility appearances were inspected; and
- the implementation uses shared semantic roles rather than feature-local
  visual constants.
