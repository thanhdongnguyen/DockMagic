# DockMagic Repository Instructions

## Distribution

- DockMagic is distributed directly to users and will not be uploaded to or released through the Mac App Store.
- Do not assume Mac App Store distribution, App Store provisioning, or App Store-only capabilities when designing or implementing features.
- Plan production releases around Developer ID signing, Hardened Runtime, notarization, and stapling.
- Before adopting an Apple capability, verify that it is supported for Developer ID distribution. If it is unavailable, prefer a public local macOS integration or present the limitation explicitly instead of silently coupling the app to Mac App Store distribution.
- Do not add App Store-specific packaging or StoreKit behavior merely for distribution. App Sandbox is optional for direct distribution and must be evaluated against feature requirements rather than assumed.
