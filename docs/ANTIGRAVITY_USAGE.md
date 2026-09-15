# Antigravity integration research

**Status:** Implemented  
**Verified:** 2026-09-15  
**Tested versions/plans:** Antigravity CLI (`agy`) 1.2.2; signed-in account
with separate Gemini and Claude/GPT weekly pools; Antigravity Desktop 2.12.2
and Antigravity IDE 2.5.5 were present but are not data sources.

## Recommendation

Ship a limited CLI-backed slice. Use the documented `agy /usage` command for
product quota and the documented CLI `statusLine` extension for passive current
session metadata. Do not restore the previous Desktop loopback adapter, inspect
credential stores, parse transcripts, or infer account quota from session
tokens.

## Supported user story

A signed-in `agy` user can see each reported Antigravity model-pool quota in
the Dock, Settings, and hover dashboard. After enabling the optional status-line
connection, DockMagic can also show the latest plan, model, context usage,
agent state, background-task count, and a partial local daily-token chart,
top-model ranking, daily intensity, streak, and Ship momentum derived only from
activity observed while DockMagic is running. Missing sources and unobserved
days remain unavailable rather than becoming zero.

## Capability dossier

| Capability | Status | User value | Source and provenance | Exact fields | Semantics | Conditions | Freshness | Completeness | Privacy and distribution | Evidence | Test fixture |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `identity.provider` | supported | Stable Antigravity identity in navigation and data surfaces. | Product identity; official public site. | Provider ID `antigravity`; display name `Antigravity`. | Product identity, not an account identifier. | None. | Static. | Complete. | Bounded official logo only; Developer ID compatible. | `https://antigravity.google/`; verified 2026-09-14. | Static model test. |
| `cli.presence` / `cli.version` | presence supported; version supported conditionally | Explains setup and compatibility. | Official local executable and optional status-line event. | Executable name `agy`; installer validation uses `agy --version`; the hover version label uses `statusLine.version` when present. | Runnable CLI presence plus an optional provider-supplied version label. | Official installer places it at `~/.local/bin/agy`; PATH and standard local-bin discovery also apply. Version display requires a status-line event. | Presence checked at setup/recovery; displayed version is event-driven. | Complete for searched executable locations; version may be absent. | DockMagic launches the unmodified CLI and does not read its keyring. | `https://antigravity.google/docs/cli/install/` and `/cli/statusline/`; local 1.2.2 observation, 2026-09-14. | Locator, installer validation, and missing-version fixtures. |
| `auth.status` | supported conditionally | Distinguishes missing sign-in from an empty quota response and provides an in-app path to authenticate. | Official local `agy` headless command for status; official interactive `agy` session for sign-in and `/logout`. | JSON envelope `status`, `error`; successful local command has `status: "SUCCESS"`. | Connection outcome only; no credential value is returned or read. DockMagic hosts the unmodified interactive CLI in a PTY; browser sign-in and credential storage remain owned by `agy`. | `agy` must be installed. Headless mode reports signed-out state; interactive mode opens the default browser when no session exists. Sign-out requires the documented `/logout` command in the interactive session. | With each quota refresh and after the user checks authentication status. | Error wording is version-dependent; unknown failures remain generic. | Authentication stays inside `agy`, the browser, and the system keyring. | `https://antigravity.google/docs/cli/headless/` and `/cli/install/`; verified 2026-09-15. | Connected, signed-out, missing-CLI, stale, and failure states. |
| `quota.window` | supported conditionally | Primary glanceable Dock metric. | Official local `agy -p /usage --output-format json`; public `/usage` documentation plus observed 1.2.2 command payload. | `command.data.groups[].name`, `.description`, `.buckets[].id`, `.name`, `.description`, `.window`, `.remaining_fraction`, `.reset_time`. | `remaining_fraction` is remaining, not used. Each group is a separate model pool. `window == "weekly"` is 10,080 minutes. Zero is a real exhausted value. | Structured `command.data` verified in `agy` 1.2.2. Older/changed output becomes unavailable; it is not parsed from prose. | Five-minute poll; reset time comes from the provider. Previous valid quota becomes stale on failure. | Complete for buckets returned by the signed-in account; no aggregate account bucket is invented. | No prompt is sent; `/usage` is a CLI-handled slash command and reported zero model tokens in the headless envelope. Raw output is bounded and ephemeral. | `https://antigravity.google/docs/cli/commands/usage` and `/cli/headless/`; local 1.2.2 sanitized observation, 2026-09-14. | `antigravity-usage-success.json`, zero/missing/unknown-window variants. |
| `identity.plan` | supported conditionally | Useful hover context. | Official local `statusLine` JSON. | `plan_tier`. | Provider-supplied subscription label. | Optional field; appears only after a CLI status event. | Event-driven; stale after 15 minutes without a new sample. | Current observed CLI session only. | The bridge allowlists the plan label and rejects `email`, IDs, paths, and unknown future fields. | `https://antigravity.google/docs/cli/statusline/`; schema verified 2026-09-14. | Sanitized status-line fixture. |
| `usage.session.context` | supported conditionally | Shows the current conversation's context pressure and token counters. | Official local `statusLine` JSON. | `context_window.total_input_tokens`, `.total_output_tokens`, `.context_window_size`, `.used_percentage`, `.remaining_percentage`, `.current_usage.input_tokens`, `.output_tokens`, `.cache_creation_input_tokens`, `.cache_read_input_tokens`. | Session/context values, not account usage or quota. Percentages are provider-reported. Missing fields stay missing. | Optional; requires the DockMagic status-line command and at least one agent-state change. | Event-driven; stale after 15 minutes. | Latest observed session only. | Only numeric allowlisted fields are persisted in a private local cache. | `https://antigravity.google/docs/cli/statusline/`; verified 2026-09-14. | Valid, missing, invalid, and oversized samples. |
| `usage.daily.tokens` | supported conditionally | Enables partial today/30-day activity summaries and streak input. | Derived from positive deltas of successive official status-line `total_input_tokens + total_output_tokens` samples for the same session and local day. | Sanitized session key, `observed_at`, total input/output, model ID. | Locally observed input-plus-output token delta. First sample and counter decreases establish a baseline. Cross-day deltas are not assigned. | DockMagic must be running and the status-line connection enabled. | Event-driven; normalized cache retained for 30 local calendar days. | Explicitly partial; misses pre-installation, DockMagic downtime, and ambiguous cross-day activity. | No prompt/response/transcript is read. Session identifiers are SHA-256 filenames and are not exported. | Derived under the feature contract from the official status-line counters; verified design 2026-09-14. | Baseline, positive delta, reset, cross-day, idempotency fixtures. |
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
| `activity.export` | supported conditionally | Lets users share the same bounded badge, observed-token, trend, and Ship-momentum story as other providers without implying account-wide coverage. | Derived only from the normalized partial daily ledger and provider-separated streak summary. | Current earned badge, explicit current-local-day observed tokens, up to 14 local-day samples, Ship score/rank, provider identity, snapshot timestamp. | Today's value is locally observed input-plus-output tokens. Missing days remain missing; they are never converted to zero. The mini area chart has no numeric labels or caption. | Requires the optional status-line connection, an explicit current-day observation, and at least two retained daily samples with positive activity. | Rendered on demand from the latest live or retained stale snapshot. | Explicitly partial; the visible `TOKENS OBSERVED TODAY` label preserves the local-observation qualifier while the chart follows Codex's caption-free layout. | No session identifier, account identifier, path, prompt, response, task description, or raw bridge payload is exported. | Derived from the supported local ledger under the activity-card export contract; product decision verified 2026-09-15. | Activity-card renderer fixture covers 1200×1200 output, provider filename, clipboard payload, missing-day preservation, and appearance states. |

## Surface map

- Settings: a Claude Code-style authentication card for CLI installation,
  signed-out, checking, connected, stale, and failed states; an embedded
  official `agy` session where the user can type or paste an Antigravity code
  with standard terminal input, or enter `/logout`; production Dock preview
  without an installation checkmark overlay; reported quota values, optional
  status-line setup, freshness/error text, and shared display/appearance
  controls.
- Dock: up to two provider-reported quota pools. A single bucket uses the
  balanced single-ring layout. Unknown or missing buckets are not zero.
- Hover: identity, plan/freshness, all reported quota rows, a partial 30-day
  token chart with unknown days distinguished from zero, top observed models,
  daily intensity, locally observed streak/badges, partial Ship momentum,
  current-session context/cache counters, and current agent/background-task
  state.
- Drill-down: omitted because hourly detail is unsupported.
- Export: Save, Copy, and Share appear only when today's local observation and
  enough retained history make the partial activity card meaningful.
- Service status: omitted until Google publishes an official source.

## State and freshness policy

CLI discovery produces a dedicated missing-CLI authentication state when `agy`
is absent. An authentication error becomes signed out, while other failures
remain distinct from stale retained quota. A refresh is `loading` only when no
previous usable data exists. Successful `/usage` quota is live for five
minutes. Status-line session data is live for 15 minutes and active work expires
after 30 minutes. If refresh fails after a valid quota, DockMagic preserves it
as stale with the scoped error. A supported field that is missing from the
current account remains unavailable; it never becomes zero.

The store coalesces refreshes, cancels child processes on stop, refreshes after
wake/network recovery, and keeps optional session telemetry independent from
quota success.

## Privacy, security, and distribution

For quota, DockMagic launches only the installed `agy` executable with the fixed
local slash command `/usage`; it does not send a model prompt. For an explicit
sign-in or sign-out action, it launches the same executable without injected
commands inside a local PTY. The user types or pastes the Antigravity code
directly into that terminal, or enters the documented `/logout`. Standard
terminal paste and the explicit Paste code action send clipboard text straight
to the PTY without retaining it in DockMagic state. DockMagic neither reads nor
deletes credentials. Authentication remains inside `agy`, the browser, and the
OS keyring. The
status-line bridge is an official extension point and allowlists only
displayable metadata. It discards `email`, raw session IDs, current/project
directories, transcript paths, VCS state, sandbox state, and unknown future
fields before writing.

The bridge preserves an existing status-line command, writes atomically with
private permissions, and restores it on disconnect when DockMagic still owns
the installed command. DockMagic persists only normalized 30-day totals,
per-model partial totals, and counter baselines needed for idempotency. No new
entitlement is required. This is compatible with Developer ID signing,
Hardened Runtime, notarization, and stapling.

## Evidence and fixtures

Primary sources:

- `https://antigravity.google/docs/cli/install/`
- `https://antigravity.google/docs/cli/headless/`
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
- Focused Xcode suite: parser separation and exact zero, missing/signed-out and
  unknown-window behavior, rejection of prose fallback, fixed CLI
  arguments/environment, status-line field allowlist and hashed session ID,
  positive same-session delta accumulation, session expiry, and the dedicated
  missing-CLI/signed-out authentication states.
- Integration tests: feature/hover registration, preference persistence, and a
  pixel-difference check between Antigravity Chart and Numbers renderers.
- Unsigned Debug build with code signing disabled.

The full visual matrix (Dock at 32/48/64/128 pt, Light, Dark, Increased
Contrast, Reduce Transparency, Reduce Motion, and grayscale), signed launch,
Developer ID/notarization, and real Dock compositor inspection remain release
verification requirements; they are not implied by the unit/build gate.
