# Changelog

All notable changes to DockMagic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/thanhdongnguyen/DockMagic/releases/tag/v0.1.0
