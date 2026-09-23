# Dock feature identities

The seven original-color SVGs in `DockMagic/DockMagic/Assets.xcassets` are the
production identities used by the Settings sidebar and Active Dock Feature
selector. They are designed for a 22 pt presentation and retain vector
representation at every rendered size.

| Feature | Production asset | ImageGen color reference |
| --- | --- | --- |
| CPU & RAM | `DockFeatureCPUAndRAM` | `references/exec-720f1e34-ffcf-4ecd-a66e-4341172da309.png` |
| Network | `DockFeatureNetwork` | `references/exec-1161e015-30f4-4697-a28a-e6142b85e121.png` |
| Storage | `DockFeatureStorage` | `references/exec-153ac647-44e4-4b24-aeee-ae2e66b8fb56.png` |
| Clock | `DockFeatureClock` | `references/exec-5188eedd-5a77-4c5a-884a-2367a3a4b8bf.png` |
| Calendar | `DockFeatureCalendar` | `references/exec-b2ad0838-ee0d-438f-b818-d7fc2c44701e.png` |
| Now Playing | `DockFeatureNowPlaying` | `references/exec-06ee4eaf-903d-4acd-8e1b-187dbcb91a46.png` |
| Batteries | `DockFeatureBatteries` | `references/exec-93bd633a-ad2c-4331-a093-b3081bb070d9.png` |

The references are the final built-in ImageGen pass, preserved for visual
provenance. SVGs were redrawn from those concepts with flat fills—no gradients,
shadows, background containers, or raster tracing artifacts—so Xcode can use
them as original-color vector artwork in both appearances.
