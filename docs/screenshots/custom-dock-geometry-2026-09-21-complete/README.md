# Custom Dock geometry QA — 2026-09-21

Native Apple Dock and DockMagic Custom Dock were measured on the same host at each edge and icon size. The acceptance threshold is an absolute thickness delta of at most 2 pt.

| Edge | Icon | Native thickness | Custom thickness | Delta | Evidence |
|---|---:|---:|---:|---:|---|
| bottom | 30 pt | 44 pt | 44 pt | 0 pt | [Native element](bottom-30/native-element.png) · [Custom element](bottom-30/custom-element.png) · [JSON](bottom-30/measurement.json) |
| bottom | 44 pt | 58 pt | 58 pt | 0 pt | [Native element](bottom-44/native-element.png) · [Custom element](bottom-44/custom-element.png) · [JSON](bottom-44/measurement.json) |
| bottom | 60 pt | 80 pt | 80 pt | 0 pt | [Native element](bottom-60/native-element.png) · [Custom element](bottom-60/custom-element.png) · [JSON](bottom-60/measurement.json) |
| left | 30 pt | 44 pt | 44 pt | 0 pt | [Native element](left-30/native-element.png) · [Custom element](left-30/custom-element.png) · [JSON](left-30/measurement.json) |
| left | 44 pt | 52 pt | 50 pt | 2 pt | [Native element](left-44/native-element.png) · [Custom element](left-44/custom-element.png) · [JSON](left-44/measurement.json) |
| left | 60 pt | 52 pt | 50 pt | 2 pt | [Native element](left-60/native-element.png) · [Custom element](left-60/custom-element.png) · [JSON](left-60/measurement.json) |
| right | 30 pt | 44 pt | 44 pt | 0 pt | [Native element](right-30/native-element.png) · [Custom element](right-30/custom-element.png) · [JSON](right-30/measurement.json) |
| right | 44 pt | 56 pt | 55 pt | 1 pt | [Native element](right-44/native-element.png) · [Custom element](right-44/custom-element.png) · [JSON](right-44/measurement.json) |
| right | 60 pt | 56 pt | 55 pt | 1 pt | [Native element](right-60/native-element.png) · [Custom element](right-60/custom-element.png) · [JSON](right-60/measurement.json) |

All 9 configurations passed. Full-screen captures and original xcresult exports remain in each case directory. Dock lengths differ because the Custom Dock includes the Shelf group; the tested parity target is edge placement and thickness.
