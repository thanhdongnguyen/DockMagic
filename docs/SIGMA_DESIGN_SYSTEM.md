# Sigma-inspired Design System for DockMagic

## 1. Scope and sources of truth

DockMagic applies the **public principles and tokens** of Sigma Design System 3
(DS3) to its own SwiftUI/AppKit design system. This is not a port, a clone, or
a claim of official compatibility with Sigma.

The hue tables in this document are reference inputs, not a license to display
the full palette in one interface. DockMagic's normative runtime color budget,
semantic usage, exceptions, and no-gradient rule live in
[COLOR_DESIGN_SYSTEM.md](COLOR_DESIGN_SYSTEM.md) and take precedence over
legacy examples in this research mapping.

Public research sources:

- [Sigma Design System](https://www.thesigma.co/designsystem) and the
  [Design System Library](https://www.thesigma.co/designsystem-library).
- Foundations: [Principle](https://www.thesigma.co/designsystem-library/foundation/principle),
  [Colors](https://www.thesigma.co/designsystem-library/foundation/colors),
  [Dark mode](https://www.thesigma.co/designsystem-library/foundation/darkmode),
  [Material](https://www.thesigma.co/designsystem-library/foundation/material),
  [Shapes](https://www.thesigma.co/designsystem-library/foundation/shapes),
  [Elevation](https://www.thesigma.co/designsystem-library/foundation/elevation),
  [Typography](https://www.thesigma.co/designsystem-library/foundation/typography),
  and [Icons](https://www.thesigma.co/designsystem-library/foundation/icons).
- Organization and components: [Card](https://www.thesigma.co/designsystem-library/components/layout-and-organizations/card),
  [Lists](https://www.thesigma.co/designsystem-library/components/layout-and-organizations/lists),
  and [Toolbar](https://www.thesigma.co/designsystem-library/components/menus-and-actions/toolbar).

Sigma DS3 is a licensed Figma library; Sigma describes product usage rights in
its [Terms of use](https://www.thesigma.co/Termsofuse). DockMagic does **not
download, embed, copy, or redistribute** Sigma's paid Figma file, component
source, icon pack, or font assets. The implementation uses only information on
the public pages and reinterprets it with SwiftUI, SF Symbols, and semantic
Color Set assets owned by DockMagic.

## 2. Adapted principles

Sigma publishes four principles: simple and intentional, attention to detail,
harmony, and consistency. DS3 describes its visual structure in three layers:

```text
Canvas
  └─ Content layer
       └─ Navigation layer
```

DockMagic maps them as follows:

| Sigma layer | DockMagic | Rule |
| --- | --- | --- |
| Canvas | Settings window background | Do not add decorative materials or shadows. |
| Content | Sections, status cards, metrics, previews, and form controls | Use solid, opaque surfaces so content remains stable and readable. |
| Navigation | Sidebar header/footer and navigation chrome | The only layer eligible for glass in every color scheme. |

Glass communicates hierarchy; it is not a texture applied to every card.
Nested content does not add its own glass or shadow. Elevation belongs to the
outer host that has a clear floating role. Nested radii use the concentric
relationship `childRadius = max(0, parentRadius - padding)`.

## 3. Public tokens and DockMagic-derived tokens

### 3.1 Confirmed by public documentation

Sigma publishes the following Light and Dark color pairs:

| Hue | Light | Dark |
| --- | --- | --- |
| Red | `#FF383C` | `#FF4245` |
| Orange | `#FF8D28` | `#FF9230` |
| Yellow | `#FFCC00` | `#FFD600` |
| Lime | `#9DCC29` | `#A0CC33` |
| Green | `#34C759` | `#30D158` |
| Mint | `#00C8B3` | `#00DAC3` |
| Teal | `#00C3D0` | `#00D2E0` |
| Cyan | `#00C0E8` | `#3CD3FE` |
| Blue | `#0088FF` | `#0091FF` |
| Indigo | `#6155F5` | `#6B5DFF` |
| Purple | `#CB30E0` | `#DB34F2` |
| Pink | `#FF2D55` | `#FF375F` |
| Brown | `#AC7F5E` | `#B78A66` |

The public neutrals map directly to semantic assets:

| Public role | Light | Dark |
| --- | --- | --- |
| Background primary | `#FFFFFF` | `#000000` |
| Background secondary | `#F5F4F2` | `#1F1E1E` |
| Background elevated | `#FFFFFF` | `#1F1E1E` |
| Text primary | `#000000` | `#FFFFFF` |
| Text secondary | `#434242` @ 60% | `#F5F3F0` @ 60% |
| Text tertiary | same base @ 30% | same base @ 30% |
| Text quaternary | same base @ 18% | same base @ 18% |
| Glass fill | `#FFFFFF` @ 80% | `#1F1E1E` @ 80% |

The public typography scale includes Billboard `80/64/48`, Title `40/32/24`,
Headline `20`, Body `16/14`, Caption `16`, and underlined links at `16/14`.
Sigma also publishes Fixed/Capsule/Concentric shape groups, two elevation
levels, and consistent line and fill icons.

### 3.2 DockMagic implementation decisions

The public pages do not provide a complete spacing scale, point-based radii,
shadow blur and offset values, blur materials, motion timing, hit targets, font
weights and line heights, or a complete state matrix. The following values are
therefore **DockMagic-derived** and must not be described as exact Sigma tokens:

| Group | DockMagic decision |
| --- | --- |
| Font | macOS system/SF fonts; do not bundle General Sans. |
| Radius | `8 / 12 / 16 / 24`, dynamic capsules; concentric radii calculated from the parent and padding. |
| Spacing | `4 / 8 / 12 / 16 / 24 / 32`. |
| In-app type | Title `32`, headline `20`, panel `16`, section/body `14`, metadata `12`, caption `11`, rounded metric `24`. |
| Motion | `0.12–0.16 s` feedback, `0.32 s` metric changes; remove nonessential animation with Reduce Motion. |
| Elevation | `none`, `primary` (`10 pt`, y `5`), and `secondary` (`5 pt`, y `2`). |
| Layout | Minimum content `1160 × 620`; sidebar `268`; maximum detail width `900`; detail padding `52×34`; standard preview `152` (Batteries uses `320`). |
| On-colors/outline/selection/shadow | Derived from contrast requirements and DockMagic context; no copying of hidden tokens. |
| Text hierarchy | Retain the public neutral bases but raise runtime alpha: secondary `80% / 60%`, tertiary `75% / 50%` (Light/Dark), so small text reaches at least `4.5:1` on content surfaces. |
| Semantic foreground | Separate accents used on content from public fills: darken foregrounds in Light and retain the bright palette in Dark; fill/on-color continues to use the public palette paired with black. |

Ring and chart colors are user-owned preferences. New defaults draw inspiration
from the public palette, but previously persisted user values are not
overwritten.

## 4. Appearance contract

The `DockMagicAppearanceMode` preference has three color schemes. Liquid Glass
chrome is integrated into all three rather than being a fourth mode:

| Mode | Color scheme | Chrome/navigation | Content |
| --- | --- | --- | --- |
| `System` | Follows macOS | Native/fallback glass | Opaque |
| `Light` | Fixed Light | Native/fallback glass | Opaque |
| `Dark` | Fixed Dark | Native/fallback glass | Opaque |

`DockMagicThemeRoot` installs the semantic theme and appearance at both the
Settings scene and the AppKit Dock host boundary. `DSSurfaceKind.chrome` is the
only surface with `isGlassEligible == true`; `shell`, `panel`, `raised`, and
`inset` always use opaque semantic fills. This keeps Canvas and Content stable
when the user changes modes and avoids chains of nested materials.

## 5. macOS 14 compatibility and native Liquid Glass

DockMagic retains its macOS 14 deployment target and builds with Xcode
15.4/Swift 5.10. Because this toolchain does not recognize the macOS 26 Liquid
Glass API, chrome currently uses the public SwiftUI `thinMaterial` together
with semantic tint, outlines, and specular edges.

The native path is isolated in `DSSurface`: it compiles only with
`compiler(>=6.2)` and then checks `#available(macOS 26.0, *)` before calling
`glassEffect`. If either the compiler or operating system does not qualify, the
code falls back to material. This native branch has not been verified with the
current compiler or runtime; repository test evidence covers only the fallback.
Do not raise the deployment target, add private APIs or entitlements, or depend
on the Mac App Store. This rule supports direct Developer ID distribution.

## 6. Component mapping

- `DSSurface` owns the material or opaque fallback, outline, semantic border,
  and elevation.
- `DSSettingsSection` creates a clear content group. `DSStatusCard` communicates
  live, loading, stale, and error states through both semantic roles and
  content, not color alone.
- `DSButtonStyle` and `DSIconButtonStyle` handle pressed and disabled states;
  interactive rows handle hover, focus, and selection. Each component respects
  accessibility preferences relevant to the states it owns.
- Native `NavigationSplitView`, `Picker`, `Toggle`, `Slider`, `ColorPicker`,
  `LabeledContent`, and `Button` preserve macOS keyboard and VoiceOver behavior.
- The Settings preview invokes the production Dock renderer; there is no second
  simulated renderer.
- SF Symbols replace paid icon assets. Decorative icons are hidden from the AX
  tree; icon-only controls have a label, help text, and identifier.

## 7. Accessibility behavior

- **Reduce Transparency:** glass fills and materials become matching opaque
  surfaces; semantic outlines remain to preserve control boundaries.
- **Increase Contrast:** outlines and focus indicators become stronger and
  thicker; states still include text or symbols instead of relying on color.
- **Reduce Motion:** nonessential press, focus, and metric animations are
  removed.
- The Dock renderer provides labels and values for CPU/RAM, Network, Storage,
  Weather, Codex, and Claude Code; loading, stale, and unavailable states have
  distinct semantics.
- A sidebar row is one accessibility element with a stable identifier and an
  `Active`/selected value; the appearance picker announces its current label
  and value.
- Native controls are preferred to preserve standard macOS keyboard navigation,
  focus, and disabled states.

Automated AX and render tests do not replace manual checks of VoiceOver,
keyboard traversal, Reduce Motion, and final system Dock compositor output.

## 8. Complete UI migration scope

### Settings owned by DockMagic

One Settings `WindowGroup` with seven destinations:

1. General — appearance and the active Dock feature.
2. CPU & RAM — preview, Chart/Numbers, colors, ring widths, and live metrics.
3. Network — preview, current throughput, interface, history, and series colors.
4. Storage — preview, capacity, Chart/Numbers, and appearance.
5. Weather — preview, freshness, permission/setup, refresh, and attribution.
6. Codex — quota preview, Chart/Numbers, CLI detection/selection, and refresh.
7. Claude Code — quota preview, Chart/Numbers, status-line bridge, and refresh.

### Dock owned by DockMagic

Seven presentations: the DockMagic logo, CPU/RAM, Network, Storage, Weather,
Codex, and Claude Code. The renderer presents live, loading, zero/empty, stale,
weekly-only, and unavailable/error states whenever the corresponding feature
has that state.

The current codebase has no `MenuBarExtra`, `NSStatusItem`, onboarding, popover,
sheet, custom alert, or custom Dock context menu. `NSOpenPanel`, the Location
permission prompt, System Settings, and the browser are macOS-owned UI;
DockMagic does not skin these surfaces.

## 9. QA matrix

| Layer | Required coverage | Evidence |
| --- | --- | --- |
| Foundation | Mode persistence/fallback, color mapping, concentric radius, and surface glass eligibility | Unit assertions |
| Appearance render | System, Light, and Dark with glass fallback; Reduce Transparency and Increased Contrast | Offscreen render + window-only image attachments + sampled-pixel difference assertions |
| Settings | Seven destinations in all three modes, appearance persistence, active-feature icon/exclusivity, Chart/Numbers controls, and production preview | Unit render + signed XCUI identifiers/values/clicks |
| Dock | Logo; CPU/RAM; Network; Storage; Weather; Codex; and Claude in valid states, all three modes, Chart/Numbers, and `32/48/64/128 pt` | Renderer matrix + non-text contrast assertions |
| Accessibility | Label/value/identifier, selected/active state, Reduce Transparency, and Increased Contrast | XCUI/AX + render/contrast assertions; disabled states, keyboard/VoiceOver, and Reduce Motion remain a manual audit |
| Build | Debug build with a macOS 14 target and Xcode 15.4; the compiler-gated native adapter does not break the older toolchain | Clean isolated DerivedData build |
| Runtime | Signed app launch, Settings open/focus, and process/Dock tile remain alive after Settings closes | Launch smoke + process/window observation |
| System compositor | Tile in the real Dock with multiple Dock sizes, positions, and wallpapers; Light/Dark | Manual screenshot/visual QA |
| Release | Developer ID, Hardened Runtime, notarization, stapling, and Gatekeeper | Release pipeline evidence |

Every report must clearly separate source review, build, unit/render, XCUI,
signed runtime, and manual compositor/VoiceOver evidence. A pass in one layer
must not be used as evidence for another; in particular, an offscreen snapshot
does not prove the final Dock pixels.
