# Changelog

All notable changes to DockMagic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-09-04

### Added

- Added live service-health monitoring for Codex and Claude Code using their
  official public status feeds.
- Added status and incident-phase details to the Codex and Claude Code hover
  dashboards, with links to the corresponding provider status page.
- Added a semantic Corner Beacon on Dock tiles when a provider is degraded or
  unavailable, including a one-time incident animation and Reduce Motion
  support.

### Changed

- Added cached status snapshots, stale and unavailable states, adaptive polling,
  and refreshes after launch and system wake.
- Limited provider incident matching to the relevant Codex or Claude Code
  components so unrelated service incidents do not trigger false alarms.

## [1.0.0] - 2026-08-31

### Added

- Added optional Accessibility-backed Dock-hover dashboards for CPU and memory,
  Weather, Codex, and Claude Code, including live process metrics, forecasts,
  quota details, and local usage insights.
- Added an offline Clock Dock tile with Analog, Digital, and Split-flap styles,
  system or custom IANA time zones, and Reduce Motion behavior.
- Added local Codex and Claude Code token histories, model breakdowns, Ship
  momentum, active-work details, and provider-specific availability states.
- Added separate persisted Codex and Claude Code usage streaks with milestone
  badges, continuity views, and accessible celebration states.
- Added Launch at Login support for the directly distributed macOS app.

### Changed

- Expanded the Claude Code bridge to use documented status-line,
  subagent-status-line, and lifecycle-hook data together with privacy-bounded
  local transcript metadata.
- Improved Codex daily usage recovery when the app-server aggregate omits the
  current day, without reading conversation content.
- Reworked Settings, shared components, semantic colors, contrast behavior, and
  UI-test coverage for the expanded feature set.
- Improved Dock rendering, hover positioning, process sampling, and live/stale
  state handling across metrics providers.

## [0.1.0] - 2026-08-23

### Added

- Added a Batteries Dock tile and Settings page for the Mac and connected
  accessories, with live connection updates and layouts for up to four devices.
- Added GitHub repository stars and forks with chart and number displays,
  seven-day history, conditional refreshes, and optional Keychain-backed access
  tokens for private repositories or higher rate limits.
- Added a preliminary Google Search Console integration with service-account
  profiles, property selection, clicks and impressions, configurable time
  ranges, three Dock display modes, and cached results.

### Changed

- Reworked the active-feature picker and Settings navigation for the expanded
  Dock feature set.
- Rendered one canonical high-resolution application icon for both the Dock and
  Command-Tab, with a documented rendering contract for every dynamic tile.
- Added the public location entitlement required for Weather authorization in
  Developer ID distributions.

### Fixed

- Improved dynamic icon sharpness and consistency between the Dock and
  Command-Tab.
- Removed generated Xcode build products from version control and ignored
  repository-local Derived Data directories.

[1.0.1]: https://github.com/thanhdongnguyen/DockMagic/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/thanhdongnguyen/DockMagic/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/thanhdongnguyen/DockMagic/releases/tag/v0.1.0
