# Changelog

All notable changes to DockMagic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Retained allowlisted Antigravity `statusLine` token samples for 30 days so
  DockMagic can rebuild partial daily usage after it was closed; existing
  DockMagic-owned bridge scripts are refreshed without changing CLI settings.
- Clarified that Antigravity Desktop activity can lower shared model-pool quota
  without providing token samples for DockMagic's CLI-observed activity chart.
- Added a Claude Code-style Antigravity authentication card with an embedded
  interactive `agy` session for typing or pasting a sign-in code and running
  `/logout`, and removed the installation checkmark button from the
  Antigravity Dock preview.

## [1.0.3] - 2026-09-09

### Added

- Added an Antigravity Dock integration backed by the official `agy /usage`
  command, with separate provider-reported model pools, Chart and Numbers
  tiles, a dedicated Settings page, and a hover dashboard.
- Added an opt-in Antigravity `statusLine` bridge for allowlisted local model,
  plan, context, agent, task, and partial daily-token observations, including
  provider-specific streaks.
- Added dedicated 1200×1200 activity cards for Save, Copy, and Share across
  Codex, Claude Code, and capability-gated Antigravity, featuring today's badge,
  token usage, a compact unlabeled 14-day area chart, and Ship momentum.

### Changed

- Improved cold-launch Settings presentation and coordinated recovery after
  network reconnection, system wake, and session unlock.
- Reworked Codex and Claude Code dashboard history presentation and image
  capture while preserving the selected Tokens or Cost metric.
- Adjusted Dock and Command-Tab tile geometry to match the visible footprint
  of standard macOS application icons.

### Fixed

- Fixed Dock-hover timing so repeated Dock notifications cannot shorten the
  one-second delay and leaving, opening a menu, or disabling hover cancels it.
- Fixed Antigravity usage attribution so only positive, same-session,
  same-local-day counter deltas are retained and stale sessions are not shown
  as current.
- Fixed Codex and Claude Code recovery when DockMagic starts offline or their
  local usage snapshot becomes readable later.

### Security

- Removed the Antigravity dependency on private Desktop loopback/RPC and CSRF
  material; DockMagic now invokes only the fixed official `/usage` command and
  never reads credentials, prompts, answers, or transcripts.
- Preserved unrelated status-line and legacy hook configuration while hashing
  session identifiers, allowlisting persisted fields, and refusing to
  overwrite externally changed configuration.

## [1.0.2] - 2026-09-04

### Added

- Added signed Sparkle updates from GitHub, including manual update checks,
  update-availability status, and automatic check and download preferences.
- Added automatic detection and user-space installation for the Codex and
  Claude Code CLIs when their Dock integrations are opened.

### Changed

- Expanded Codex discovery to find executables bundled inside Codex.app and
  ChatGPT.app in system and user Applications directories.
- Updated developer-tool navigation so choosing Codex or Claude Code opens the
  matching settings page and prepares its local integration.

### Fixed

- Improved active-feature picker reliability and accessibility on macOS 14.
- Fixed parsing of configured Codex data paths that contain multiple lines.

### Security

- Added HTTPS host validation, download-size limits, script validation, and
  post-install executable verification for developer-tool installers.
- Configured a dedicated Ed25519 signing key for verified Sparkle updates.

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

[Unreleased]: https://github.com/thanhdongnguyen/DockMagic/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/thanhdongnguyen/DockMagic/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/thanhdongnguyen/DockMagic/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/thanhdongnguyen/DockMagic/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/thanhdongnguyen/DockMagic/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/thanhdongnguyen/DockMagic/releases/tag/v0.1.0
