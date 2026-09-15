# Streak badge SVG pilot

Review-only vector reconstruction of First Prompt and Builder, requested on
2026-09-09. Production assets and streak views are not replaced by this pilot.

## Files

| Badge | Master SVG | Compact SVG | Existing PNG source |
| --- | --- | --- | --- |
| First Prompt | `first-prompt.svg` | `first-prompt-compact.svg` | `StreakBadgeFirstPrompt` |
| Builder | `builder.svg` | `builder-compact.svg` | `StreakBadgeBuilder` |

All four SVGs have a 1024 × 1024 viewBox and transparent canvas. They contain
only polygons and polylines with solid fills/strokes. They contain no embedded
bitmaps, gradients, filters, fonts, scripts, or external resources. The compact
variants widen the rim and internal bevels; they are experimental optical
variants, not separate milestone designs.

The original PNGs remain the visual references. These SVGs reconstruct their
geometry with deliberately simpler material shading. They do **not** reproduce
the PNGs' photographic highlights, metal texture, or every interlocking edge
exactly. Builder still reads flatter and slightly more angular than its source.

## Preview

Serve the repository root locally and open `/docs/streak-concepts/svg-pilot/`.
`index.html` compares current PNG, SVG master, and SVG compact. It includes a
24–512 CSS px size slider, fixed 32/48/58/112 px samples, Light/Dark, grayscale,
increased-outline-contrast, and locked controls. Browser interpolation differs
from SwiftUI, so the native sheets are the evidence for macOS rendering.

## Native verification

From the repository root:

```sh
node script/generate_streak_svg_pilot.mjs
bash script/verify_streak_svg_pilot.sh
```

The verifier creates an isolated temporary `.xcassets` and resource bundle,
compiles it with `actool` for macOS 14.0, and renders it using SwiftUI
`Image(name, bundle:)`. It never compiles or launches the production app.
SVG image sets use a single scale-independent resource and
`preserves-vector-representation: true`.

`asset-catalog-info.json` records four `Vector` entries, one for each SVG.
Xcode also emits cached raster renditions at 1× and 2×. Consequently, the
7.8–14.3 KB source SVG sizes must not be read as shipped catalog sizes.

The PNG column reproduces the current production interpolation rule:
up to 60 pt, `.none` at 2× and `.medium` at 1×; otherwise `.high`.
SVG columns use `.high`, without the raster-specific nearest-neighbor rule.
All three columns use the same frame and source canvas.

Evidence:

- `native-dark-2x.png`: 185 pt hero and 32/48/58/112 pt samples on Retina.
- `native-light-1x.png`: the same comparison on a 1× light surface.
- `native-contrast-2x.png`: high-contrast AppKit drawing appearance and explicit
  stronger fixture outlines.
- `native-grayscale-2x.png`: all artwork and fixtures rendered in grayscale.
- `native-locked-2x.png`: desaturation, 0.34 opacity, and a native lock symbol.
- `native-reduced-transparency-2x.png`: opaque fixture surfaces; the asset itself
  retains the transparent canvas required to fit any host background.
- `native-first-prompt-3072.png` and `native-builder-3072.png`: render at 1536 pt
  and 2×, exceeding the 1024 px authored SVG canvas.

Accessibility images are controlled review fixtures. No global accessibility
preferences were changed; these are not full production dashboard screenshots.
The headless `ImageRenderer` did not apply SwiftUI saturation filters, so the
grayscale and locked sheets are explicitly converted to a monochrome color
space after native rendering. They verify grayscale legibility, not the live
window compositor's filter behavior.
The palette stays inside each badge; review chrome uses neutral colors only.

## Assessment

Native loading and vector retention pass. SVG edges are clean in the size
comparison and enlarged output. First Prompt is close in structure; Builder
preserves the crown and crossing ribbons with simplified surfaces. Compact
variants slightly strengthen edges, but do not eliminate loss of fine detail
at 32–48 pt. Choosing master versus compact still needs visual review.

This proves the asset pipeline and provides concrete artwork for review. A
production migration would retain the existing asset names, update the raster
sampling assumption in `StreakBadgeView`, and revisit the existing source-text
tests that currently require that interpolation rule. No such migration is
included in this trial.
