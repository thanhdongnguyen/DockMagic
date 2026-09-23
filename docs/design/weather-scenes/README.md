# Weather scene artwork

Seven original square PNG backgrounds were generated with the built-in
`imagegen` tool, then traced to actual SVG paths (no embedded bitmap). The
`WeatherScene*.imageset` assets bundle the SVGs as original-color, preserved
vectors for the Dock tile and hover dashboard. The original PNGs remain in
[`originals/`](originals/) for provenance. No Apple Weather image or third-party
stock art is included. `WeatherSceneBackdrop` subdues the static vector art
over the corresponding opaque `DSWeatherScene*` color. Condition glyphs, text
and accessibility labels remain the source of weather meaning.

| Scene | Bundled vector | Original | Light / Dark backing |
| --- | --- | --- | --- |
| Sun | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneSun.imageset/scene.svg) | [PNG](originals/Sun.png) | `#216691` / `#15466C` |
| Moon | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneMoon.imageset/scene.svg) | [PNG](originals/Moon.png) | `#29355F` / `#18213D` |
| Cloud | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneCloud.imageset/scene.svg) | [PNG](originals/Cloud.png) | `#415773` / `#293C53` |
| Wind | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneWind.imageset/scene.svg) | [PNG](originals/Wind.png) | `#256A72` / `#184D57` |
| Rain | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneRain.imageset/scene.svg) | [PNG](originals/Rain.png) | `#295683` / `#1C416B` |
| Ice | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneIce.imageset/scene.svg) | [PNG](originals/Ice.png) | `#2B697E` / `#17495E` |
| Storm | [SVG](../../../DockMagic/DockMagic/Assets.xcassets/WeatherSceneStorm.imageset/scene.svg) | [PNG](originals/Storm.png) | `#4A3866` / `#30264C` |

## Vectorization

The 1254 px source was downsampled to 640 px to bound scene complexity, then
converted with VTracer 0.6.12 in color/stacked/spline mode (speckle 3,
color precision 7, layer difference 7, path precision 3). Cloud uses speckle 2,
color precision 8 and layer difference 3 to retain low-contrast cloud banks.
Tonal texture is approximated by layered solid-color paths, not a lossless
conversion. The source PNGs above allow direct visual comparison or re-tracing.

## Verification

Build the `DockMagic` macOS scheme, then run
`swift script/verify_weather_svg.swift /path/to/DockMagic.app /path/to/previews`.
The smoke test loads assets from the built app and renders each scene at
48 × 48, 96 × 96, and the 440 × 420 dashboard footprint in Light, Dark,
Increased Contrast, grayscale, and the solid Reduce Transparency equivalent.
It checks that all seven renders are distinct and white-on-scene contrast is
at least 4.5:1, and writes review PNGs to the chosen output directory.
`Assets.car` should report an `AssetType: Vector` entry for every scene.
The smoke test mirrors the scene composition; it does not replace the in-app
XCTest render and real Dock/dashboard visual inspection.

## Prompt set

Each asset was generated in a separate built-in imagegen call using the
`stylized-concept` use case. The common brief was: *square, opaque background
artwork for a native macOS Weather Dock tile and hover dashboard; premium
editorial weather illustration with gently layered matte shapes and fine
painterly texture; visual interest near the upper/outer edges with quiet center
and lower-middle space for white UI data; recognizable at 48 pt; dominant flat
scene color with its darker partner; no typography, numbers, UI, borders,
logos, trademarks, watermark, horizon, buildings, people, photorealism,
smooth gradients or broad bright-white fields.*

The seven subject/palette prompts were:

1. **Sun:** clear daytime sky, restrained warm sun disc, soft cloud banks;
   `#216691` and `#15466C`.
2. **Moon:** clear night sky, quiet crescent moon, sparse tiny stars and
   lower-edge clouds; `#29355F` and `#18213D`.
3. **Cloud:** calm layered overcast cloud banks and soft fog-like veils, no
   precipitation; `#415773` and `#293C53`.
4. **Wind:** elegant flowing cloud ribbons and swept wisps suggesting lateral
   motion in a static image; `#256A72` and `#184D57`.
5. **Rain:** layered dark rain clouds with delicate diagonal rain streaks, no
   lightning; `#295683` and `#1C416B`.
6. **Ice:** frosty cloud banks and sparse delicate snowflakes, no ground or
   mountains; `#2B697E` and `#17495E`.
7. **Storm:** sculpted thunderclouds, one restrained distant lightning fork
   near an outer edge, a few rain streaks; `#4A3866` and `#30264C`.
