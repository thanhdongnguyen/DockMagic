# DockMagic Repository Instructions

## Distribution

- DockMagic is distributed directly to users and will not be uploaded to or released through the Mac App Store.
- Do not assume Mac App Store distribution, App Store provisioning, or App Store-only capabilities when designing or implementing features.
- Plan production releases around Developer ID signing, Hardened Runtime, notarization, and stapling.
- Before adopting an Apple capability, verify that it is supported for Developer ID distribution. If it is unavailable, prefer a public local macOS integration or present the limitation explicitly instead of silently coupling the app to Mac App Store distribution.
- Do not add App Store-specific packaging or StoreKit behavior merely for distribution. App Sandbox is optional for direct distribution and must be evaluated against feature requirements rather than assumed.

## UI and color

- Treat `docs/COLOR_DESIGN_SYSTEM.md` as the normative color contract and `docs/DESIGN_SYSTEM.md` as the component and appearance contract.
- Keep DockMagic-owned UI neutral-first. Normal UI uses one action accent; semantic color appears only for a real information, processing, warning, or danger state and replaces the local accent when prominent.
- Do not add `LinearGradient`, `RadialGradient`, `AngularGradient`, colored glow, decorative tinted cards, or a new feature-local palette.
- Keep interface icons monochrome or hierarchical in one hue. Preserve full-color brand assets only inside a bounded identity region.
- Keep user-selected and data-series colors inside their renderer, preview, swatch, and legend boundaries. Never reuse them for chrome, selection, focus, buttons, or status.
- Use semantic `DesignTheme` roles and shared components. Do not add direct RGB, hex, system color names, or asset lookups in feature views when a semantic role exists.
- Verify changed UI in Light, Dark, Increased Contrast, Reduce Transparency, and grayscale. State, selection, and data must not depend on color alone.
