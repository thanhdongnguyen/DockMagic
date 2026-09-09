# DockMagic Command-Tab Rendering Rules

This document is the rendering contract for every dynamic DockMagic icon shown
in the Dock and in Command-Tab. It applies to all current presentations and to
every presentation added later.

## Why this contract exists

`NSApplication.applicationIconImage` is normalized by AppKit from the logical
point size of the assigned `NSImage`. A 128-point image is therefore installed
as roughly 256 pixels on a 2x display even if the source image contains larger
representations. Command-Tab then has no downsampling headroom, so text, rings,
and rounded borders look soft.

DockMagic uses a 512-point logical canvas rendered at 2x. The resulting
1024-pixel source is the same top-end raster size used by a standard macOS app
icon and gives an approximately 256-pixel Command-Tab icon 4x supersampling.

## Mandatory pipeline rules

1. Every `DockTilePresentation` must render through
   `DockApplicationIconRenderer`. A feature must not install its own app icon.
2. The logical canvas is exactly 512 by 512 points.
3. The source raster is at least 1024 by 1024 pixels (`scale == 2`).
4. Render through `ImageRenderer.cgImage`, then construct
   `NSImage(cgImage:size:)` with a 512-point logical size.
5. Use non-linear color rendering and a transparent canvas. Do not introduce
   an intermediate JPEG or other lossy format.
6. Keep `NSDockTile.contentView` unset. A custom content view may be flattened
   at the current Dock backing-store size and reused softly by Command-Tab.
7. Do not rely on multiple `NSImage` representations to survive assignment to
   `applicationIconImage`; AppKit is allowed to canonicalize them.
8. Disable metric animations during rasterization. A frame must represent a
   stable data state, not an in-between animation sample.
9. Center the visible tile in an 824/1024 fraction of the canvas, leaving
   100/1024 transparent space on each edge. `DockTileView` owns this layout
   for every presentation and Settings preview; feature renderers must not
   add the inset again. Keep the 512-point canvas and 1024-pixel raster intact.
   The bundled AppIcon generator uses the same body inset. This matches the
   opaque bounds measured in the system Notes and Calculator icons.

The executable values and validation helpers live in
`DockIconRenderingRules.swift`. Change those values only together with the
integration tests and a real Command-Tab capture.

## UI construction rules

- Build geometry from the square tile `side`; avoid layouts tuned only for a
  32-, 64-, or 128-point preview.
- Prefer SwiftUI shapes, `Canvas`, text, and SF Symbols. They remain vector-like
  until the single final rasterization step.
- Raster assets must contain enough source pixels for their canonical coverage:
  `minimum source pixels = 1024 * fraction of tile width`. A full-tile bitmap
  must therefore be at least 1024 pixels wide and high.
- Use `.interpolation(.high)` for raster assets that are scaled. Never upscale
  a small bitmap and expect the 1024-pixel output canvas to restore detail.
- Primary text and numbers should use semibold or heavier weights. Use compact
  formatting and deterministic layouts before falling back to aggressive text
  shrinking.
- At a 256-pixel Command-Tab target, primary strokes should finish at 2 pixels
  or wider and decorative grid lines at 1 pixel or wider.
- Do not apply `blur`, a post-render `scaleEffect`, or `drawingGroup` to the
  complete tile. Decorative shadows may be used only behind an independently
  sharp foreground symbol or text layer.
- Primary information must not depend on low opacity. Keep muted labels at
  sufficient contrast and verify the increased-contrast environment.
- Align repeated chart and ring geometry consistently. Rounded line caps are
  preferred for progress endpoints; thin square caps expose subpixel jitter.

## Current asset audit

Only `DockMagicLogo` is a raster asset used by a Dock presentation. Its source
is 1254 by 1254 pixels, so it satisfies the full-tile 1024-pixel rule. Codex,
Claude Code, GitHub, Search Console, batteries, network, storage, weather, and
system metrics use text, SwiftUI geometry, `Canvas`, or SF Symbols in their Dock
presentations. Their settings-page logos are outside this pipeline.

## Required verification for Dock UI changes

1. Render at least one state for every `DockTilePresentation` through the
   canonical renderer and verify a 512-point image with at least 1024 pixels.
2. Assign a representative rendered image to the real
   `NSApplication.applicationIconImage` and verify the installed representation
   against the active display scale. A spy setter is not sufficient.
3. Run the Dock rendering and controller unit tests.
4. Capture Command-Tab on a 2x display for light, dark, numeric, chart, error,
   and loading states affected by the change.
5. Compare selected and unselected Command-Tab states. Selection tint is an OS
   effect; a source image that is already soft in both states is a DockMagic
   rendering defect.
6. Check render cost for presentations refreshed every second. Preserve the
   1024-pixel contract; optimize state updates or renderer reuse instead of
   lowering resolution.

## Exception rule

An exception requires all three: a documented AppKit limitation, before/after
Command-Tab captures, and a test that protects the best achievable output. A
smaller canvas is not an acceptable performance shortcut.
