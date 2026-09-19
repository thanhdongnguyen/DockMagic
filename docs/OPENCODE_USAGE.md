# OpenCode local history integration

Status: implemented; automated interactive UI acceptance remains pending, 2026-09-16.
Upstream evidence: [OpenCode CLI research](OPENCODE_CLI_RESEARCH.md), pinned to
`anomalyco/opencode` v1.18.4 / `49c69c5ed3ccf706b61b3febb43c8aaff7f8325e`.

## Capability dossier

| Capability | Classification | Source and conditions |
| --- | --- | --- |
| Recorded input/output/reasoning/cache read/cache write | Supported | Allowlisted metadata in legacy `message` and V2 `session_message`; each absent/invalid bucket remains unknown |
| Daily/hourly/provider/model usage | Supported | Aggregated once by canonical source/session/message identity; Gregorian local calendar, persisted timezone |
| Retained local lifetime tokens | Supported | One chosen database, all projects/providers/models; not an account lifetime claim |
| Estimated legacy USD cost | Supported, conditional | Positive finite legacy recorded cost only; independent eligible-message coverage |
| V2 cost / unknown-zero cost | Unknown | Not included; zero does not establish free usage or billed cost |
| Streak, badges, momentum, intensity | Supported, derived | Shared algorithms, observed-only days; separate OpenCode/source namespace |
| Activity export | Supported, conditional | Positive recorded tokens today; shared activity layout, 14-day trend, no paths/IDs/model labels |
| Account quota/reset/balance/plan/upstream status | Unknown | Omitted from UI |
| Active sessions/context/permissions/realtime | Deferred | No plugins, server/SSE, or process/session probes |
| Transcript/credentials | Prohibited | Not projected, cached, logged, or exported |

The typed allowlist is `OpenCodeDashboardManifest` in `OpenCodeUsage.swift`.
Overview order: identity → daily/local total → continuity → momentum → intensity
and top models. Daily detail and export are explicit routes. No OpenCode metric
is added to another provider.

## Reader and coverage

`OpenCodeHistoryReading` returns a normalized immutable `OpenCodeUsageSnapshot`
and a day detail belonging to that snapshot. `OpenCodeHistoryReader` runs off
MainActor, opens system SQLite with `SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX`,
and uses a single read transaction for a coherent WAL snapshot. It never invokes
OpenCode database services/migrations or queries full message JSON, parts,
session counters, titles, working directories, or auth. JSON extraction checks
numeric types, rejecting booleans, strings, negatives, nonfinite values, and
out-of-range integers. Legacy records without a confirmed assistant role remain
unknown/partial even if they contain numeric token fields.

Schema recognition uses table/column metadata, independent of CLI version.
The two adapters project only identity, timestamp, provider/model, five token
buckets, and cost. V2 wins a shared session/message ID. Step totals and session
counters never participate. Full metadata reconciliation is intentional: legacy
message updates can change JSON without changing `time_updated`. Repeated reads
replace values; stable ID ordering also makes floating cost summation deterministic.

Timestamp is message `time.created` in milliseconds, with table `time_created`
as fallback. A message with unusable usage is not a zero. Days before the earliest
retained observation are unknown. Empty days within the retained span through the
read date are confirmed **local-record** zeros. Unlocated malformed records make
otherwise empty days unknown. Missing fields and skipped records retain a partial
flag. Hourly presentation covers the actual calendar day (23/24/25 elapsed hours);
future and unobserved hours are gaps. Cache read and write remain separate.

Fork/import copies with new IDs cannot be reliably identified without content or
origin metadata. They remain counted and the scope note explains this limitation.
A complete local scan does not prove complete upstream/account usage. Upstream
may itself have substituted zero for unreported fields; the label is “recorded”.

Cost is an estimate retained by legacy OpenCode, not billed spend. Missing/zero
legacy cost and all V2 cost are unavailable. Aggregates preserve eligible versus
usage-message counts; partial totals carry a partial label. The selector appears
only when the displayed 30-day window has eligible cost.

## Discovery, lifecycle, persistence

Priority: saved file → inherited `OPENCODE_DB` → inherited `XDG_DATA_HOME` and
`~/.local/share/opencode/opencode.db`. Multiple existing candidates require user
selection; databases are never combined. A GUI app cannot infer environment
variables confined to a shell startup file; select that database in Settings.
An explicit missing source stays selected with a recoverable read error.

`OpenCodeUsageStore` coalesces reads and invalidates old source/timezone results.
The production minimum between reads is 5 seconds. Database, WAL, and parent
watchers debounce changes; parent watching handles replacement/late WAL creation.
Descriptors reopen after successful reads. Fallback polling is 60 seconds while
selected/Settings visible, otherwise 300 seconds. Wake/day/timezone events refresh
when tracking is enabled. Manual Refresh and opening the dashboard work when
tracking is off. First selecting OpenCode enables background collection once;
subsequent selection preserves the user's toggle.

Cache v1 is under Application Support/DockMagic/OpenCode. File names namespace a
SHA-256 source-path identity plus timezone. Cache contains aggregate day/hour/model
metadata and hashed reconciliation IDs, never transcript, raw session/message IDs,
or database paths. Files use 0600 and directory 0700. Restoration is stale until
source reconciliation succeeds. Read errors retain the last snapshot. Clearing
cache waits for a pending cache writer and never deletes the OpenCode source.

Only optional CLI discovery runs `--version`, bounded to about three seconds.
No CLI installation or login is required to read a valid database. There is no
new dependency, entitlement, or App Store requirement; Developer ID distribution
is unchanged.

## UI and shared presentation

- Dock and Settings use the same production `DockOpenCodeView` inside
  `DockTileView`: today's K/M/B value and seven noncumulative daily area points.
  A gap breaks segments; a singleton is a dot; confirmed zeros stay on baseline.
  Stale/partial/loading/unavailable have non-color cues and exact accessibility.
- Settings keeps source selection/discovery and places manual Refresh on the same
  row as Auto-detect. It omits read/schema/CLI metadata, dashboard-preview and
  activation controls, and the former collection/cache section.
- Chart and token-number colors use independent inline `DSColorPalettePicker`
  controls and the shared renderer palette. Both persist, update the production
  Dock/preview/dashboard immediately, retain accessible selection state, migrate
  the previous single color to both roles, and reset together with Reset Defaults.
- The 440 pt dashboard uses `DockHoverChrome`, screen-height clamp and scrolling.
  OpenCode history uses the shared 30-day area-chart variant; gaps break the area
  into separate segments and partial/missing labels remain non-color cues. Other
  providers retain their existing chart styles. Shared intensity/top-model/streak/
  momentum components use compatibility inputs, with no fabricated quota snapshot.
- Detail has Back/Escape, native keyboard-accessible day buttons, independent
  loading/error, hourly chart and a bucket-driven five-field token presentation.
  A refresh regenerates the selected detail from the new snapshot; changing
  source/timezone closes the old route.
- Streak is reconciled from the currently selected source, not a persistent union
  of different databases. Initial history never requests celebration playback.
- Export reuses the exact activity renderer: opaque 1200×1200, 14-day trend,
  `LAST KNOWN`/`TOKENS OBSERVED TODAY` where needed. One cached artifact serves
  Save/Copy/Share until observation changes. Export does not include source IDs,
  paths, credentials, transcripts, or model/account identifiers.

## Verification

Evidence is deliberately separated:

| Layer | Result | Scope / limit |
| --- | --- | --- |
| Foundation | **23/23 passed**, `./script/test_opencode_foundation.sh` | 17 reader/cache/discovery and 6 store/lifecycle tests using production source |
| Xcode unit/integration/regression | **32/32 passed**, `dockmagic-opencode-frozen-unit-2.xcresult` | 23 foundation, 4 presentation/raster/export, 5 existing Codex/Claude/shared regression tests |
| Build and launch | **Passed**, repository `script/build_and_run.sh --verify` | Fixed source snapshot; exact isolated app process confirmed, exit 0 |
| Real local SQLite | **Passed**, read-only smoke | 57 usage records, 1,766,159 recorded tokens, 26/57 messages with eligible cost; repeated snapshot equality and unchanged database bytes |
| Visual | Inspected native overview/detail and production Dock/export renders | 32/48/64 pt; Light/Dark, Increased Contrast, Reduce Transparency, Reduce Motion, grayscale; missing/zero/single-point/stale cases |
| Settings color follow-up | **Build/launch and native render fixture passed** | Shared Claude-style palette inspected in Light/Dark, Increased Contrast, Reduce Transparency and grayscale, with a selected purple swatch matching the production Dock preview. Logs: `/private/tmp/opencode-colors-build.log`, `/private/tmp/opencode-colors-visual.log`; images: `/private/tmp/dockmagic-opencode-qa/native-colors-*.png`. This is rendering evidence, not interactive UI acceptance. |
| Simplified Settings follow-up | **Build and focused tests passed**, 2026-09-18 | macOS build passed; 6 OpenCode integration/migration/render tests and 2 shared-chart regressions passed. Native Light/Dark, Reduce Transparency, Reduce Motion and grayscale Settings fixtures render the larger token value and segmented area chart. The Increased Contrast Settings capture still omits some text layers, so that artifact is not counted as visual acceptance. |
| Interactive UI automation | **Pending acceptance** | The Settings test now covers the simplified layout, independent chart/token colors, persistence and Reset Defaults. The latest attempt lost its application connection before the first assertion, so it is not UI acceptance. |
| Live V2 | Not available | V2/mixed/DST/malformed/WAL/source-switch/cache behavior is source/fixture verified; the available real database is legacy |

The prior Xcode run used a fixed copy at
`/private/tmp/dockmagic-opencode-verified-source` because other tasks were changing
shared source during compilation. OpenCode production/test files match that copy.
This does not assert that later changes to other providers have been validated.

Artifacts and logs:

- `/private/tmp/dockmagic-opencode-frozen-unit-2.xcresult`
- `/private/tmp/opencode-foundation-23.log`
- `/private/tmp/opencode-launch-verify.log`
- `/private/tmp/dockmagic-opencode-frozen-ui-2.xcresult` (UI failure evidence, not acceptance)
- `/private/tmp/dockmagic-opencode-qa` (native matrix, direct Dock rasters, 1200×1200 exports)
- `/private/tmp/dockmagic-opencode-smoke/result.json`

Direct `ImageRenderer` Dock fixtures supplement NSHostingView snapshots, which can
omit GPU text layers during capture. Export tests verify opaque 1200×1200 PNG,
identical Copy/Share bytes from one artifact, eligibility, and source-ID exclusion.

For isolated build/launch, the repository script accepts these optional paths
(default behavior remains the normal project build directory):

```sh
DOCKMAGIC_DERIVED_DATA_PATH=/private/tmp/dockmagic-opencode-frozen-derived \
DOCKMAGIC_SOURCE_PACKAGES_PATH=/private/tmp/dockmagic-opencode-packages \
/private/tmp/dockmagic-opencode-verified-source/script/build_and_run.sh --verify
```

With an isolated directory, stop/launch verification targets that exact app binary,
not another task's DockMagic instance. The remaining acceptance step is to run
`OpenCodeUITests` in an exclusive desktop automation session and inspect the
simplified Settings layout and production Dock/hover surfaces in Light and Dark.

## Operational limits

The collector scans retained metadata, not an incremental high-water stream;
very large databases may need a future metadata index/cache optimization. Import
origin deduplication, account-level cost truth, and upstream coverage are not
recoverable from the verified metadata. The V2 parser has source/fixture evidence;
the available real database uses the legacy schema. Current/last-known always
refers to the local source, not an upstream service health assertion.
