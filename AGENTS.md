# DockMagic Repository Instructions

## Mandatory project rules

- Read [RULES.md](RULES.md) before planning or changing the project. It is a mandatory part of these repository instructions and records lasting user requirements and recurring problems that must not be repeated.
- Apply every rule relevant to the task and check compliance before reporting completion. Maintain rule IDs and requirements in `RULES.md`; do not duplicate the full rule list here.

## Distribution

- DockMagic is distributed directly to users and will not be uploaded to or released through the Mac App Store.
- Do not assume Mac App Store distribution, App Store provisioning, or App Store-only capabilities when designing or implementing features.
- Plan production releases around Developer ID signing, Hardened Runtime, notarization, and stapling.
- Before adopting an Apple capability, verify that it is supported for Developer ID distribution. If it is unavailable, prefer a public local macOS integration or present the limitation explicitly instead of silently coupling the app to Mac App Store distribution.
- Do not add App Store-specific packaging or StoreKit behavior merely for distribution. App Sandbox is optional for direct distribution and must be evaluated against feature requirements rather than assumed.

## Design Markdown

- For UI work, read [Design.md](Design.md) after `RULES.md`. It follows Google's DESIGN.md alpha format: YAML contains active design tokens; the eight Markdown sections explain their scope, native mapping, and usage. Keep this structure and valid `{group.token}` references when editing it.
- Follow the mandatory [UI and design rules in RULES.md](RULES.md#ui-and-design-rules), including typography, native token mapping, color boundaries, component reuse, customization, and verification.
