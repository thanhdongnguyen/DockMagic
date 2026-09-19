# Antigravity integration research

**Status:** Implemented  
**Verified:** 2026-09-15  
**Tested versions/plans:** Antigravity CLI (`agy`) 1.2.2; signed-in account
with separate Gemini and Claude/GPT weekly pools; Antigravity Desktop 2.12.2
and Antigravity IDE 2.5.5 were present but are not data sources.

## Recommendation

Ship a limited CLI-backed quota slice. Use the documented `agy /usage` command
for product quota. Continue to handle an already-installed documented CLI
`statusLine` bridge for passive session metadata, but do not offer new setup in
Settings. Do not restore the previous Desktop loopback adapter, inspect
credential stores, parse transcripts, or infer account quota from session
tokens.

Antigravity 2.0 Desktop token history is unsupported through documented
passive integrations as of 2026-09-16 (official 2.13.0 docs; local Desktop
2.12.2). Its documented hooks expose conversation
and model metadata but no input/output token counters; sidecars document agent
creation and messaging, not existing-session token reads. A falling model-pool
quota is not a token count. DockMagic therefore labels the token chart as
CLI-observed and leaves Desktop-only token history unavailable.

## Supported user story

A signed-in `agy` user can see each reported Antigravity model-pool quota in
the Dock, Settings, and hover dashboard. For users with an already-enabled
status-line connection, DockMagic can also show the latest plan, model, context usage,
agent state, background-task count, and a partial local daily-token chart,
top-model ranking, daily intensity, streak, and Ship momentum derived only from
activity captured through that connection. The private 30-day sample archive
lets DockMagic replay eligible activity after it restarts. Missing sources and
unobserved days remain unavailable rather than becoming zero.

## Capability dossier

| Capability | Status | User value | Source and provenance | Exact fields | Semantics | Conditions | Freshness | Completeness | Privacy and distribution | Evidence | Test fixture |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `identity.provider` | supported | Stable Antigravity identity in navigation and data surfaces. | Product identity; official public site. | Provider ID `antigravity`; display name `Antigravity`. | Product identity, not an account identifier. | None. | Static. | Complete. | Bounded official logo only; Developer ID compatible. | `https://antigravity.google/`; verified 2026-09-14. | Static model test. |
| `cli.presence` / `cli.version` | presence supported; version supported conditionally | Explains setup and compatibility. | Official local executable and optional status-line event. | Executable name `agy`; installer validation uses `agy --version`; the hover version label uses `statusLine.version` when present. | Runnable CLI presence plus an optional provider-supplied version label. | Official installer places it at `~/.local/bin/agy`; PATH and standard local-bin discovery also apply. Version display requires a status-line event. | Presence checked at setup/recovery; displayed version is event-driven. | Complete for searched executable locations; version may be absent. | DockMagic launches the unmodified CLI and does not read its keyring. | `https://antigravity.google/docs/cli/install/` and `/cli/statusline/`; local 1.2.2 observation, 2026-09-14. | Locator, installer validation, and missing-version fixtures. |
| `auth.status` | supported conditionally | Distinguishes missing sign-in from an empty quota response and provides an in-app path to authenticate. | Official interactive `agy` session for sign-in; fixed headless `/logout` followed by fixed headless `/usage` for verified sign-out. | JSON envelope `status`, `error`; the follow-up usage probe must report authentication required before DockMagic presents signed-out state. | Connection outcome only; no credential value is returned or read. DockMagic hosts the unmodified interactive CLI in a PTY only for browser sign-in; sign-out runs without terminal UI. | `agy` must be installed. Interactive mode opens the default browser when no session exists. The documented `/logout` slash command must be accepted in headless mode; otherwise existing quota is retained and the failure is shown. | With each quota refresh and after sign-in; sign-out remains processing until its verification probe completes. | Error wording is version-dependent; unknown failures remain generic. | Authentication stays inside `agy`, the browser, and the system keyring. | `https://antigravity.google/docs/cli/headless/`, `/cli/install/`, and `/cli/reference/`; verified 2026-09-15. | Connected, signing-out, verified signed-out, missing-CLI, stale, and failure states. |
| `quota.window` | supported conditionally | Primary glanceable Dock metric. | Official local `agy -p /usage --output-format json`; public `/usage` documentation plus observed 1.2.2 command payload. | `command.data.groups[].name`, `.description`, `.buckets[].id`, `.name`, `.description`, `.window`, `.remaining_fraction`, `.reset_time`. | `remaining_fraction` is remaining, not used. Each group is a separate model pool. `window == "weekly"` is 10,080 minutes. Zero is a real exhausted value. | Structured `command.data` verified in `agy` 1.2.2. Older/changed output becomes unavailable; it is not parsed from prose. | Five-minute poll; reset time comes from the provider. Previous valid quota becomes stale on failure. | Complete for buckets returned by the signed-in account; no aggregate account bucket is invented. | No prompt is sent; `/usage` is a CLI-handled slash command and reported zero model tokens in the headless envelope. Raw output is bounded and ephemeral. | `https://antigravity.google/docs/cli/commands/usage` and `/cli/headless/`; local 1.2.2 sanitized observation, 2026-09-14. | `antigravity-usage-success.json`, zero/missing/unknown-window variants. |
| `identity.plan` | supported conditionally | Useful hover context. | Official local `statusLine` JSON. | `plan_tier`. | Provider-supplied subscription label. | Optional field; appears only after a CLI status event. | Event-driven; stale after 15 minutes without a new sample. | Current observed CLI session only. | The bridge allowlists the plan label and rejects `email`, IDs, paths, and unknown future fields. | `https://antigravity.google/docs/cli/statusline/`; schema verified 2026-09-14. | Sanitized status-line fixture. |
| `usage.session.context` | supported conditionally | Shows the current conversation's context pressure and token counters. | Official local `statusLine` JSON. | `context_window.total_input_tokens`, `.total_output_tokens`, `.context_window_size`, `.used_percentage`, `.remaining_percentage`, `.current_usage.input_tokens`, `.output_tokens`, `.cache_creation_input_tokens`, `.cache_read_input_tokens`. | Session/context values, not account usage or quota. Percentages are provider-reported. Missing fields stay missing. | Optional; requires the DockMagic status-line command and at least one agent-state change. | Event-driven; stale after 15 minutes. | Latest observed session only. | Only numeric allowlisted fields are persisted in a private local cache. | `https://antigravity.google/docs/cli/statusline/`; verified 2026-09-14. | Valid, missing, invalid, and oversized samples. |
| `usage.daily.tokens` | supported conditionally | Enables partial today/30-day activity summaries and streak input. | Derived from positive deltas of successive official status-line `total_input_tokens + total_output_tokens` samples for the same session and local day. The DockMagic-owned script archives the first and last sanitized sample per hashed session/local day for replay. | Sanitized session key, `observed_at`, total input/output, model ID. | Locally observed input-plus-output token delta. First sample and counter decreases establish a baseline. Cross-day deltas are not assigned. | The optional documented `statusLine` bridge must be installed and `agy` must emit events; its script can archive samples while DockMagic is closed. | Event-driven; private first/last samples, normalized daily totals, and baselines retained for 30 local calendar days. DockMagic replays 30 days on launch and two days while running. | Explicitly partial; misses pre-installation, sessions with only one sample, counter resets between endpoints, ambiguous cross-day activity, and time-zone changes between capture and replay. No account-wide backfill exists. | No prompt/response/transcript is read. History files contain only model ID, counters, time, and hashed session filenames with private permissions; they are not exported. | `https://antigravity.google/docs/cli/statusline/`; official schema verified 2026-09-15; local replay design 2026-09-15. | Sanitized archive, offline replay, restart idempotency, 30-day pruning, baseline, reset, cross-day fixtures. |
| `usage.desktop.daily.tokens` | unsupported | Would make the 30-day token chart reflect Antigravity 2.0 Desktop sessions. | Official Desktop hooks and sidecars schemas; no eligible external token source. | Hooks: conversation ID, model name, invocation index, paths; sidecars: agent creation and messaging. Neither documents input/output token counters for existing Desktop activity. | A model-pool quota fraction cannot be converted into a token count. | Desktop-only sessions; no CLI `statusLine` event. | N/A. | No documented account-wide or Desktop daily token history for DockMagic to collect. | DockMagic does not read transcripts, credential material, private Desktop loopback APIs, or language-server RPC. | `https://antigravity.google/docs/hooks`, `https://antigravity.google/docs/sidecars`, and `https://antigravity.google/docs/plans`; verified 2026-09-16. | Quota-only snapshot fixture keeps Desktop token usage unavailable and does not derive it from remaining fraction. |
| `usage.model` | supported conditionally | Shows which model produced observed local activity. | Derived alongside eligible daily deltas from `statusLine.model.id` / `.display_name`. | Original model ID and display name. | Tokens are attributed only when both delta samples retain the same model. | Same as partial daily usage. | Same as daily usage. | Partial; a model change makes that delta unattributed. | Model name only; no conversation content. | Official status-line schema; verified 2026-09-14. | Same-model and changed-model fixtures. |
| `engagement.daily_intensity` | supported conditionally | Makes the shape of recently observed activity glanceable without claiming complete account history. | Derived from the bounded `usage.daily.tokens` ledger. | Local day plus optional observed input-and-output token total. | Intensity is relative to the largest observed day in the retained 30-day window. A missing day is unknown and uses a dashed outline; it is never converted to zero. | Requires the optional status-line connection and at least one eligible positive delta. | Recomputed whenever the local ledger changes. | Explicitly partial with unobserved days distinguished structurally. | No additional data is collected or persisted. | Feature-contract derived-module rule; verified design 2026-09-14. | Presentation fixtures cover observed, unobserved, duplicate, and out-of-range days. |
| `engagement.streak` | supported conditionally | Shows continuity across locally observed Antigravity activity days and unlocks the shared badge detail. | Derived from positive `usage.daily.tokens` days through the provider-separated `TokenUsageStreakStore`. | Provider ID, local day, positive token total, first/last observation time. | A day counts only after positive locally observed activity. Repeated observations are idempotent; missing days do not become zero but break the locally observed run. | Same as partial daily usage. | Updated after each eligible usage observation. | Explicitly a locally observed streak, not an account-wide Antigravity streak. | Provider-separated SwiftData records contain no content or account identifier. | Feature-contract derived-module rule; verified design 2026-09-14. | Existing provider-isolation and idempotency fixtures plus Antigravity store coverage. |
| `engagement.ship_momentum` | supported conditionally | Provides the same bounded current-day activity indicator as Codex without presenting it as productivity. | Derived only when the partial ledger contains an explicit current-local-day token bucket. | Current local-day observed token total mapped through the shared 0...100 score and rank thresholds. | Resets each local day. If today has no observed bucket, momentum is unavailable rather than score zero. | Requires an eligible current-day positive delta. | Recomputed with the local ledger. | Explicitly partial and local; it can undercount while DockMagic is not observing. | No additional data is collected or persisted. | Feature-contract derived-module rule; verified design 2026-09-14. | Presentation fixtures require observed-today data and reject absence as zero. |
| `usage.breakdown.cache` | supported conditionally | Current-session cache context can be displayed without fabricating daily totals. | Official local `statusLine.context_window.current_usage`. | `cache_creation_input_tokens`, `cache_read_input_tokens`, plus input/output. | Current context breakdown; not assumed cumulative and not merged into account totals. | Optional status-line fields. | Event-driven. | Latest observed session only. | Numeric allowlist only. | Official status-line schema; verified 2026-09-14. | Missing and complete current-usage fixtures. |
| `work.agent_state` / `work.task_count` | supported conditionally | Shows whether a local agent is idle, working, using tools, or has background tasks. | Official local `statusLine` JSON. | `agent_state`, `task_count`, `pending_input_count`, `tool_confirmation_pending`, `artifact_count`, `execution_mode`. | Current observed session state; task count is background tasks, not total historical tasks. | Requires optional status-line connection. | Event-driven; active work expires after 30 minutes. | Current observed CLI sessions only. | Paths, transcript, email, VCS data, sandbox data, and prompt content are discarded. | Official status-line schema; verified 2026-09-14. | Idle, working, approval, and background-task fixtures. |
| `usage.lifetime`, `usage.hourly` | unsupported | Would be useful for long-term reporting, but cannot be claimed. | No eligible passive source established. | None. | No substitution from partial local deltas. | N/A. | N/A. | N/A. | Transcript parsing and private Desktop metadata are rejected. | Official `/usage` and status-line schemas do not expose account lifetime/hourly history; checked 2026-09-14. | Omission tests. |
| `usage.reasoning`, `usage.tool_tokens` | unsupported for passive integration | Avoids presenting a false token breakdown. | Headless task results expose `thinking_tokens`, but DockMagic will not manufacture a model run; status line does not expose reasoning/tool-token totals. | Headless `usage.thinking_tokens` exists only for a user-requested headless run. | Not reusable as account or passive session usage. | N/A. | N/A. | N/A. | Sending a prompt to obtain usage is prohibited. | `https://antigravity.google/docs/cli/headless/`; status-line schema checked 2026-09-14. | Omission tests. |
| `cost.observed` / currency | unsupported | Prevents invented spend estimates. | No field in eligible `/usage` or status-line schemas. | None. | No pricing-table estimate and no subscription-cost inference. | N/A. | N/A. | N/A. | No billing endpoint or credential mediation. | Official schemas checked 2026-09-14. | Omission tests. |
| `work.goal` | unsupported | Prevents fabricated goal counts. | No eligible status-line field. | None. | `task_count` is not a goal count. | N/A. | N/A. | N/A. | No transcript or private trajectory parsing. | Official status-line schema checked 2026-09-14. | Omission tests. |
| `service.status` | unknown | Provider health must not be confused with local setup. | No official Antigravity status endpoint was found. | None. | Local CLI failures are not provider incidents. | N/A. | N/A. | N/A. | Unofficial outage trackers are not embedded. | Official site/docs search, 2026-09-14. | Service-status surface omitted. |
| `activity.export` | supported conditionally | Lets users share the same bounded badge, observed-token, trend, and Ship-momentum story as other providers without implying account-wide coverage. | Derived only from the normalized partial daily ledger and provider-separated streak summary. | Current earned badge, explicit current-local-day observed tokens, up to 14 local-day samples, Ship score/rank, provider identity, last successful token-delta observation time. | Today's value is locally observed input-plus-output tokens. Missing days remain missing; they are never converted to zero. The mini area chart has no numeric labels or caption when valid. | Requires the optional status-line connection and a positive current-day observation. An adjacent known-day trend is optional; sparse history shows `NO HISTORY`, not an invented chart. | Rendered on demand from the retained local ledger; the activity timestamp is independent of `/usage` quota and session-only updates. Observations older than 15 minutes read Last known. | Explicitly partial; the visible `TOKENS OBSERVED TODAY` label preserves the local-observation qualifier while a valid chart follows Codex's caption-free layout. | No session identifier, account identifier, path, prompt, response, task description, or raw bridge payload is exported. | Derived from the supported local ledger under the activity-card export contract; sparse-history variant approved 2026-09-16. | Activity-card renderer fixture covers 1200×1200 output, provider filename, clipboard payload, one-day/missing-day preservation, and appearance states. |
| `activity.availability.export` | supported conditionally | Keeps the Codex share-image layout visible when quota exists but Antigravity has no eligible daily token observation, without pretending it is activity. | Product presentation derived from a valid normalized `agy /usage` quota snapshot; an independently eligible earned badge may come from the provider-local streak ledger, but no activity value is derived from quota. | Provider identity, quota fetch timestamp, locked or independently earned badge, unavailable token and Ship slots, neutral `NO HISTORY` cue. | `CHECKED` or `LAST KNOWN` dates come from quota; em dashes and unavailable text are absence, not zero. The chart icon is not a plotted series. | Requires at least one structured quota bucket and explicit selection in the Antigravity export manifest; it is the only Share layout when activity is absent. | Rendered on demand; fresh for five minutes, then Last known. | No token history or badge is claimed from quota; a quota-detail artifact is not offered in Share. | Same 1200×1200 redaction boundary as other export cards; no new collection, persistence, permission, or entitlement. | User-approved layout variant, 2026-09-16; quota provenance remains `agy /usage`. | Availability Dark/Light/contrast/grayscale/stale fixtures, opaque dimensions, Copy/Share bytes, and single-layout export-menu fixtures. |
| `quota.export` | supported conditionally | The detailed model-pool image remains a separate internal renderer and regression fixture, not an Antigravity Share choice. | The normalized provider-reported `agy /usage` quota snapshot. | Provider identity, each displayed model-pool name and window, remaining fraction, reported reset time, quota fetch timestamp, and omitted-pool count. | A fraction is remaining, not used; zero is exhausted and unknown reset stays unknown. At most four pools fit in one card; any remainder is stated. No activity value is inferred. | At least one structured quota bucket must exist to render the fixture; the current Antigravity export manifest excludes this mode. | Rendered only in focused regression tests from live or retained stale quota with its original fetch timestamp. | Complete for displayed pools; omitted pools are explicitly counted, not silently aggregated. | The 1200×1200 PNG contains no account identifier, session key, path, prompt, response, or raw CLI output; no new collection or entitlement. | Derived from the supported `quota.window` source and normalized snapshot; Share exclusion requested 2026-09-16. | Direct renderer regression covers PNG dimensions, stale/zero/missing reset, opaque pixels, and appearance fixtures; no user-facing menu mode. |

## Surface map

- Settings: a Claude Code-style authentication card for CLI installation,
  signed-out, connected, stale, and failed states; automatic connection checks
  run in the background without a visible `Checking` summary while retaining
  the applicable **Sign in** action or authenticated **Refresh** and
  **Sign Out** actions. An embedded
  official `agy` session where the user can type or paste an Antigravity code
  with standard terminal input. The terminal uses an 80-column, 18-row viewport
  and the authentication card grows with its content instead of clipping the
  terminal or its actions; background sign-out shows only processing UI
  until `/logout` is verified by `/usage`; production Dock preview without an
  installation checkmark overlay; reported quota values, freshness/error text,
  and shared display/appearance controls. The local session metrics section and
  bridge-management actions are omitted. When connected, the trailing overflow
  menu contains only Sign Out (plus the transient authentication-log toggle when
  applicable), matching the Claude Code connection card. An already-installed
  DockMagic-owned bridge remains observable; visiting Settings never changes
  its configuration.
  Every sign-in attempt creates a new terminal process. Cancelled/replaced
  terminal callbacks are ignored, and an unsuccessful terminal exit restores
  the prior connection state so the user can retry.
- Dock: up to two provider-reported quota pools. A single bucket uses the
  balanced single-ring layout. Unknown or missing buckets are not zero.
- Hover: identity, plan/freshness, all reported quota rows, a partial 30-day
  CLI-observed token chart with unknown days distinguished from zero, top observed models,
  daily intensity, locally observed streak/badges, partial Ship momentum,
  current-session context/cache counters, and current agent/background-task
  state. The empty token chart explicitly says Desktop token activity is not
  included; quota errors do not replace that source explanation.
- Drill-down: omitted because hourly detail is unsupported.
- Export: Save, Copy, and Share default to the partial activity card when an
  eligible current-day local token observation exists. An adjacent trend is
  optional; sparse history shows `NO HISTORY` instead of a fabricated line.
  When only a valid provider-reported quota exists, the same Codex-layout
  availability image is used, with a locked badge unless independently earned
  and explicit missing token/chart/Ship states. The Share menu has only the
  activity layout and Save, Copy, and Share actions; no quota-data mode. With
  neither source, the control remains absent.
- Service status: omitted until Google publishes an official source.

The export fixtures are sanitized design previews, not live-account captures.
The activity card has [Dark](share-card-concepts/implementation/antigravity-dark.png),
[Light](share-card-concepts/implementation/antigravity-light.png),
[Increased Contrast](share-card-concepts/implementation/antigravity-contrast.png),
and [grayscale](share-card-concepts/implementation/antigravity-grayscale.png)
versions. The [one-day sparse-history card](share-card-concepts/implementation/antigravity-activity-no-history.png)
keeps a truthful `NO HISTORY` cue. The availability layout has
[Dark](share-card-concepts/implementation/antigravity-availability-dark.png),
[Light](share-card-concepts/implementation/antigravity-availability-light.png),
[Increased Contrast](share-card-concepts/implementation/antigravity-availability-contrast.png),
[grayscale](share-card-concepts/implementation/antigravity-availability-grayscale.png),
and [Last known](share-card-concepts/implementation/antigravity-availability-stale.png)
fixtures. The [earned Builder badge with missing activity](share-card-concepts/implementation/antigravity-availability-earned-badge.png)
fixture demonstrates that a real provider-local badge can remain visible
without inventing today's tokens. The non-selected quota renderer retains
[Dark](share-card-concepts/implementation/antigravity-quota-dark.png),
[Light](share-card-concepts/implementation/antigravity-quota-light.png),
[Increased Contrast](share-card-concepts/implementation/antigravity-quota-contrast.png),
[grayscale](share-card-concepts/implementation/antigravity-quota-grayscale.png),
[Last known](share-card-concepts/implementation/antigravity-quota-stale.png),
and a [four-pool overflow fixture](share-card-concepts/implementation/antigravity-quota-four-pools-plus-omitted.png).

## State and freshness policy

CLI discovery produces a dedicated missing-CLI authentication state when `agy`
is absent. An authentication error becomes signed out, while other failures
remain distinct from stale retained quota. A refresh is `loading` only when no
previous usable data exists. Successful `/usage` quota is live for five
minutes. Status-line session data is live for 15 minutes and active work expires
after 30 minutes. If refresh fails after a valid quota, DockMagic preserves it
as stale with the scoped error. A supported field that is missing from the
current account remains unavailable; it never becomes zero.

The store coalesces refreshes but runs a fresh quota probe after sign-in if the
pending refresh was metadata-only or cancelled. Automatic checks remain
background-only; a refresh preserves the last settled connection presentation,
and an interrupted initial check exposes `Retry`. The store
cancels child processes on stop, refreshes after wake/network recovery, and
keeps optional session telemetry independent from quota success.
Activity-card freshness uses the last successful local token delta. A later
quota fetch or session sample without a token delta cannot change its source
date or turn Last known activity into Today's activity.
The activity-availability image is a separate quota-qualified artifact: its
`CHECKED`/`LAST KNOWN` date follows the quota fetch and five-minute freshness
policy, while token, chart, and Ship slots remain explicitly unavailable.
An earned badge may be displayed only from an independent provider-local
streak summary.

## Privacy, security, and distribution

For quota, DockMagic launches only the installed `agy` executable with the fixed
local slash command `/usage`; it does not send a model prompt. Explicit sign-in
launches the same executable without injected commands inside a local PTY. The
user types or pastes the Antigravity code directly into that terminal. Standard
terminal paste and the explicit Paste code action send clipboard text straight
to the PTY without retaining it in DockMagic state. Explicit sign-out runs the
fixed headless `/logout` command without terminal UI, then uses `/usage` only to
confirm that the cached account session is gone. DockMagic neither reads nor
deletes credentials itself. Authentication remains inside `agy`, the browser,
and the OS keyring. The
status-line bridge is an official extension point and allowlists only
displayable metadata. It discards `email`, raw session IDs, current/project
directories, transcript paths, VCS state, sandbox state, and unknown future
fields before writing.

The bridge preserves an existing status-line command and writes atomically with
private permissions. Its separate 30-day archive keeps only the first and last
sample time, model ID, and input/output counters for each hashed session/local
day. The DockMagic-owned script prunes older day directories, and DockMagic
prunes them again on launch and on each later local day, even without a new CLI
event. Launch also refreshes that owned script without changing the CLI setting.
DockMagic additionally
persists normalized 30-day totals, per-model partial totals, and counter
baselines needed for idempotency. Archived endpoint samples can recover some
activity while the app was closed, but a single sample, counter reset, or
ambiguous cross-day interval cannot be reconstructed.
Antigravity Settings never installs, removes, or otherwise reconfigures an
existing bridge. No new entitlement is required. This is compatible with
Developer ID signing, Hardened Runtime, notarization, and stapling.

## Evidence and fixtures

Primary sources:

- `https://antigravity.google/docs/cli/install/`
- `https://antigravity.google/docs/cli/headless/`
- `https://antigravity.google/docs/cli/reference/`
- `https://antigravity.google/docs/cli/commands/usage`
- `https://antigravity.google/docs/cli/statusline/`
- `https://antigravity.google/docs/hooks`

Local read-only probes on 2026-09-14:

- `agy --version` returned `1.2.2`.
- `agy help` documented `--print`, `--output-format`, `--print-timeout`, and
  related headless flags.
- `agy -p /usage --output-format json --print-timeout 30s` returned a success
  envelope with `num_turns: 0`, zero headless model tokens, and structured
  `command.data.groups[].buckets[]` for `gemini-weekly` and `3p-weekly`.

Fixtures contain only synthetic provider labels, fractions, reset timestamps,
and numeric session metadata. They contain no real email, paths, identifiers,
prompts, answers, or credentials.

## Unknowns and rejected approaches

- The `command.data` extension to the documented headless envelope is verified
  in 1.2.2 but is not fully enumerated on the public `/usage` page. Therefore
  support is version/schema-gated and never falls back to parsing prose.
- The public docs define `/logout` and standalone headless slash-command
  execution separately, but do not show a headless `/logout` example. DockMagic
  therefore requires both a success envelope and a signed-out `/usage` probe,
  and preserves existing quota on any ambiguous result. Automated validation
  did not run `/logout` against the developer's real signed-in account.
- It is unknown whether Google will publish an official Antigravity service
  status feed.
- Desktop loopback endpoints, CSRF material, local language-server RPC, private
  generator metadata, transcripts, credential files, and OAuth/session tokens
  are rejected.
- Headless model requests are not used to manufacture usage data.
- Session tokens are not promoted to account lifetime totals or product quota.

## Verification performed

- Read-only real probe: `agy` 1.2.2 returned the separate `gemini-weekly` and
  `3p-weekly` structured buckets with zero generated model turns/tokens.
  A 2026-09-15 `/usage` probe exited successfully in about six seconds with
  account output suppressed; this checked CLI responsiveness, not live Settings
  rendering or the returned quota schema.
- Focused Xcode suite: parser separation and exact zero, missing/signed-out and
  unknown-window behavior, rejection of prose fallback, fixed CLI
  arguments/environment, non-interactive fixed `/logout`, verified sign-out
  state transition, cancelled sign-in probe retry, interrupted `Checking`
  recovery, status-line field allowlist and hashed session ID, private 30-day
  first/last archive, restart replay without double counting, positive
  same-session delta accumulation, session expiry, and the dedicated
  missing-CLI/signed-out authentication states.
- Integration tests: feature/hover registration, preference persistence, and a
  pixel-difference check between Antigravity Chart and Numbers renderers.
- The Antigravity hover dashboard and its activity export reuse the approved
  Codex blue data roles for quota progress, token values/history, Ship momentum,
  Daily intensity, and Top models. Controls, status, warnings, and chrome retain
  their semantic colors.
- Quota-only Share test: a signed-in snapshot without local token observations
  displays a single activity-layout export menu. Its opaque 1200×1200
  availability image retains badge/chart/Ship zones with explicit missing-data
  cues; the Save artifact, clipboard bytes, and temporary file consumed by the
  macOS Share presenter agree. The non-selected quota renderer is separately
  tested for a real zero fraction, unknown reset time, stale rendering, and
  appearance regression without a public menu option. Light, Dark, Increased
  Contrast, Reduce Transparency, Reduce Motion, and grayscale variants were
  generated; availability images, the earned-badge/missing-token variant, and
  Dark/Light single-layout hover menus were visually inspected.
- Focused signed UI tests: the authentication terminal and actions fit inside
  Settings in Light and Dark; connected state transitions through visible
  `Signing out` progress without a terminal surface, then returns to the
  `Sign in with Antigravity` action. Test fixture screenshots do not establish
  that the real `agy` sign-in prompt is rendered, so that remains a live check.
- Settings UI tests in Light and Dark: the local session metrics section and
  bridge-management actions are absent even when a legacy bridge is installed.
  A connected card uses its More Actions menu for Sign Out only. The
  cross-destination Settings test also passed with Antigravity quota controls
  still available.
- Unsigned Debug build with code signing disabled.

The full visual matrix (Dock at 32/48/64/128 pt, Light, Dark, Increased
Contrast, Reduce Transparency, Reduce Motion, and grayscale), signed launch,
Developer ID/notarization, and real Dock compositor inspection remain release
verification requirements; they are not implied by the unit/build gate.
