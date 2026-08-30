# Victory Crest production manifest

## Selected source

- Visual target: `victory-crest-claude.png` (Pinterest refinement, Option 1).
- Frame anchor: `victory-crest-frame.png`.
- Production date: 2026-08-30.
- Generation route: ten independent built-in ImageGen calls; no CLI/API fallback.

## System architecture

The production set uses ten service-neutral frame assets and deterministic
runtime service marks:

- Codex: `CodexBadgeLogo` (the existing mark with only low-alpha checker noise
  removed for the badge-sized export).
- Claude Code: `ClaudeCodeLogo`.
- The service mark occupies 22% of the rendered badge side inside the blank
  graphite medallion. Image generation never redraws either logo.

This produces a complete Codex set and a complete Claude Code set without
duplicating twenty nearly identical frame files.

## Shared ImageGen prompt contract

```text
Use case: stylized-concept
Asset type: final 1024 × 1024 DockMagic milestone badge FRAME
Input image: the selected Victory Crest frame is the exact style anchor
Primary request: create exactly one original milestone frame in the same broad
faceted family, changing only the milestone structure described below
Scene/backdrop: genuine transparent PNG; alpha 0 outside the connected artifact
Style/medium: premium machined collectible; warm polished copper-gold rim; dark
graphite chassis; warm ivory and deep cobalt hard-enamel in large solid regions;
restrained neutral object lighting; low micro-detail; readable at 48 pt
Center safe zone: exactly one centered blank graphite circular medallion,
approximately 28–34% of the canvas, with no content inside and no geometry
crossing it; reserved for deterministic Codex/Claude Code logo overlay
Constraints: one connected front-facing artifact; generous margin; no text,
letters, numerals, logo, glyph, flame, circuitry, thin filigree, colored glow,
rainbow, background, card, pedestal, external shadow, multiple badge, detached
fragment, or watermark
```

## Milestone directives and exports

| Days | Badge | Production directive | Frame export |
| ---: | --- | --- | --- |
| 1 | First Prompt | Simplest compact hex; one ivory rising chevron; two cobalt base facets | `01-first-prompt.png` |
| 3 | Spark | Two nested chevrons; four cobalt facets; brighter copper edge | `03-spark.png` |
| 7 | Loop | Double rim; one closed broad six-segment cobalt/ivory rhythm | `07-loop.png` |
| 14 | Builder | Integrated shoulder braces; reinforced base plinth; wider silhouette | `14-builder.png` |
| 30 | Flow | Swept side facets; stepped lower chevrons; visible upward motion | `30-flow.png` |
| 60 | Navigator | Integrated north/east/west/south crown points; no literal compass icon | `60-navigator.png` |
| 100 | Century | Connected three-point crown; ceremonial shoulders; thick double rim | `100-century.png` |
| 180 | Architect | Twin buttress shoulders rise into one tall central crown | `180-architect.png` |
| 365 | Keystone | Deep double shell; exactly five upper facets with a dominant keystone | `365-keystone.png` |
| 730 | Continuum | One connected wide double-hex; six large inward-facing facets | `730-continuum.png` |

The generated staging files live in `production/`. Matching copies are consumed
by the ten `StreakBadge*.imageset` asset catalogs.

## Verification

- Every frame is a 1024 × 1024 RGBA PNG with genuine alpha.
- Every frame is one connected artifact with transparent corners and no stray
  component.
- The blank medallion remains centered across all ten frames.
- `victory-crest-production-contact-sheet.png` compares the selected source,
  both service marks at 112 pt, paired 58 pt collection assets, and paired 48 pt
  grayscale assets.
- `victory-crest-native-comparison.png` places the selected source and the
  app-hosted SwiftUI renders in one comparison input. The native evidence uses
  440 pt wide panels captured at 2× in Codex Dark, Codex Light, Codex
  grayscale-check, and Claude Code Dark states.
- The targeted app-hosted render test passed for all nine attachments,
  including Increased Contrast, Reduced Transparency, unavailable, reset, and
  compact-strip states.
