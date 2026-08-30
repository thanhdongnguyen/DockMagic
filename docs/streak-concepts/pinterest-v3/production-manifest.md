# Interlock Crown production manifest

## Selected source

- Visual target: `ideation/interlock-crown.png` (logo-free refinement,
  Option 3).
- Production date: 2026-08-30.
- Generation route: built-in ImageGen in stylized-concept mode.
- The selected 14-day Builder target is reused directly. The other nine assets
  were created with nine independent generation calls. Continuum received one
  targeted retry after its first result read as an infinity symbol.

## System architecture

The ten production assets are complete, service-neutral milestone symbols.
There is no central identity socket and SwiftUI does not composite a Codex or
Claude Code logo over them. Provider identity remains in the existing bounded
header region of each dashboard.

The badge artwork keeps authored cobalt, warm ivory, graphite, and copper-gold
inside its transparent silhouette. Product chrome continues to use shared
semantic `DesignTheme` roles.

## Final ImageGen prompt contract

```text
Use case: stylized-concept
Asset type: final 1024 × 1024 DockMagic streak milestone badge
Style anchor: selected Interlock Crown Option 3
Primary request: create exactly one original, front-facing, logo-free milestone
badge in the same interlocking angular-ribbon family, changing only the
milestone structure described below
Scene/backdrop: genuine transparent PNG; alpha 0 outside the artifact
Style/medium: premium machined collectible; warm polished copper-gold rim;
dark graphite chassis; warm ivory and deep cobalt hard enamel in broad solid
facets; restrained neutral object lighting; low micro-detail; readable at 48 pt
Structure: the woven ribbon geometry is the complete central symbol; one
connected silhouette with generous transparent margin
Constraints: no Codex logo, Claude logo, generic logo, letter, numeral, text,
circle, blank medallion, empty center socket, flame, circuitry, thin filigree,
gradient glow, rainbow, background, card, pedestal, external shadow, detached
fragment, multiple badges, or watermark
```

## Milestone directives and exports

| Days | Badge | Final production directive | Export |
| ---: | --- | --- | --- |
| 1 | First Prompt | Simplest compact hex; two broad ribbons cross once around a small gold keystone | `production/01-first-prompt.png` |
| 3 | Spark | Crossed ribbons plus one confident upper chevron; retain open breathing room | `production/03-spark.png` |
| 7 | Loop | One closed angular hex knot with a small graphite diamond core | `production/07-loop.png` |
| 14 | Builder | Reuse the selected full Interlock Crown target exactly | `production/14-builder.png` |
| 30 | Flow | Long swept S-weave with clear forward motion and a taller hex silhouette | `production/30-flow.png` |
| 60 | Navigator | Four directional crown points joined by one woven center; no compass glyph | `production/60-navigator.png` |
| 100 | Century | Connected triple ceremonial crown with a broad braided lower core | `production/100-century.png` |
| 180 | Architect | Tall buttress-and-spine braid with one authoritative central crown | `production/180-architect.png` |
| 365 | Keystone | Ornate five-facet crown organized around a dominant central shield/keystone | `production/365-keystone.png` |
| 730 | Continuum | Six paired ivory/cobalt facets converge into one distilled vertical graphite/copper master spine | `production/730-continuum.png` |

Matching copies are consumed by the ten `StreakBadge*.imageset` asset catalogs.

## Verification

- Every export is a 1024 × 1024 RGBA PNG with transparent corners and one
  connected artifact.
- `interlock-crown-production-contact-sheet.png` compares the selected target,
  112 pt hero art, 58 pt collection art, and 48 pt grayscale art.
- `interlock-crown-native-comparison.png` places the selected target and native
  SwiftUI renders in one comparison input: Codex Dark, Claude Code Dark, Codex
  Light, and a Codex grayscale check.
- `interlock-crown-small-sharpness-comparison.png` compares the selected source
  with the same Codex 2× viewport before and after compact-size rendering was
  made density-aware. Badge slots at 48–58 pt use pixel-preserving sampling on
  Retina and medium interpolation on 1× displays; 112–185 pt hero art keeps
  high-quality interpolation.
- Separate native attachments cover Increased Contrast, Reduced Transparency,
  unavailable, reset with Continuum retained, and the compact streak strip.
- `./script/build_and_run.sh --verify` passed.
- The app-hosted render test and both semantic-chrome/milestone-boundary tests
  passed.
