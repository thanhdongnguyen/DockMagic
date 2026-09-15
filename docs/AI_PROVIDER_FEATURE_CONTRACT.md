# AI Provider Feature Contract

**Status:** Normative  
**Baseline verified:** September 13, 2026  
**Applies to:** Research, design, implementation, and review of AI provider
features in DockMagic.

## 1. Purpose and ownership

This contract defines what DockMagic must consider when adding an AI provider,
which UI surfaces form a complete feature, and when a metric may be displayed.
It packages the common product behavior already exercised by Codex and Claude
Code without pretending that every provider exposes the same data.

This file is the durable source of truth. Provider-specific documents record
acquisition details and evidence. The repository skill at
`.codex/skills/ai-provider-integration/SKILL.md` supplies the repeatable
research and implementation workflow and must not duplicate this contract.
The dashboard UI and composition rules live in
[AI_DASHBOARD_DESIGN_SYSTEM.md](AI_DASHBOARD_DESIGN_SYSTEM.md); they do not
override this file's capability or data semantics.

When current implementation and older provider documentation disagree, verify
the running code and authoritative upstream source, then update the stale
document in the same change.

## 2. The two dimensions that must stay separate

Every datum has both a **capability status** and an **observation state**. Do not
collapse these dimensions into one optional value.

### Capability status

| Status | Meaning | UI rule |
| --- | --- | --- |
| `supported` | An allowed, sufficiently stable source exposes the datum with understood semantics. | The module may ship and must handle all observation states. |
| `unsupported` | The provider or eligible account does not expose the datum. | Omit the module. Absence is not an error. |
| `unknown` | Research has not established availability or semantics. | Do not claim support or reserve permanent UI for it. |
| `prohibited` | Collection would require secrets, prompt/response content without necessity, private endpoints, unsafe credential mediation, or an incompatible distribution capability. | Do not collect or display it; record the reason. |

Support may be conditional on CLI version, account plan, authentication method,
or an explicitly enabled local hook. Record each condition in the provider
dossier rather than treating conditional support as universal.

### Observation state

| State | Meaning | Presentation |
| --- | --- | --- |
| `notConfigured` | A required local tool, login, or permission is missing. | Explain the requirement and offer the narrow setup action. |
| `loading` | A configured source is being checked. | Keep layout stable and show processing semantics. |
| `live` | The value is valid within its freshness policy. | Show the value and timestamp/reset metadata when useful. |
| `stale` | A previous valid value exists but refresh or freshness validation failed. | Preserve the last value, label it last known/stale, and expose its age or error. |
| `unavailable` | The capability is supported but no valid value exists for this account or attempt. | Show an explicit unavailable/empty explanation where the module is important. |
| `failed` | Setup or acquisition failed and an actionable retry or correction exists. | Show the scoped error and action; do not erase unrelated live modules. |

A provider-level connection state and each data module's state may differ. For
example, quota can be unavailable while local activity history remains live.

## 3. Current feature inventory

The inventory below captures the reusable surface area, not a requirement that
future providers fabricate parity.

| Surface or module | Codex baseline | Claude Code baseline | Contract classification |
| --- | --- | --- | --- |
| Provider identity | Name, logo, optional plan | Name, logo, optional plan | Required |
| Local tool setup | CLI discovery/install/check | CLI discovery/install/update | Required when a local tool is needed |
| Authentication | Reuses the installed Codex session | Sign-in, sign-out, retry, fixed-command login log | Capability-gated |
| Dock tile | Supported quota windows as rings or numbers; weekly-only is valid | 5-hour and weekly quota as rings or numbers | Required surface; contents capability-gated |
| Settings preview | Production Dock renderer, live values, style and ring controls | Same, plus connection status/actions | Required |
| Hover header | Identity, plan/state, official service status, export | Identity, plan/state, official service status, export | Required when hover is supported |
| Quota rows | Only windows returned by the aggregate account bucket | Expected 5-hour/weekly rows; unavailable is explicit | Capability-gated |
| Daily activity | Token chart, date range, today, lifetime | 30-day Tokens/Cost selector, date range, today | Capability-gated |
| Daily drill-down | Hourly and model/token breakdown when locally available | Not currently exposed | Capability-gated |
| Usage insights | Daily intensity and top models | Daily intensity and top models | Capability-gated |
| Continuity | Current/best streak, recent days, badges, celebration | Same, maintained per provider | Capability-gated derived module |
| Ship momentum | Score/rank from eligible current-day activity | Same | Capability-gated derived module |
| Active work | No dedicated module | Sessions/tasks/goals and realtime hook setup | Capability-gated |
| Activity-card export | Save, copy, share a dedicated 1200×1200 PNG | Same | Capability-gated shared action |
| Quota-card export | Not currently shipped | Not currently shipped | Capability-gated action when provider-reported quota is available |
| Failure states | Idle, loading, live, stale, unavailable | Same data states plus detailed connection states | Required |

An existing provider-specific module is evidence that the product can host that
kind of data; it is not evidence that another provider supports that data.

## 4. Provider capability dossier

Research must produce a dossier before implementation. One row represents one
independently displayable capability, not an entire API response.

Required columns:

| Field | Required content |
| --- | --- |
| Capability | Stable internal name such as `quota.window`, `usage.daily.tokens`, `usage.model`, `cost.observed`, `work.task`, or `auth.status`. |
| Status | `supported`, `unsupported`, `unknown`, or `prohibited`. |
| User value | Why this belongs in the Dock, Settings, hover, a drill-down, or nowhere. |
| Source and provenance | Exact command, public API method, documented local file/event, or allowed derived input. Classify it as official public, official local, local metadata, or derived. |
| Exact fields | Upstream field names and sample shape. Do not record credential values or raw private content. |
| Semantics | Used vs remaining, units, aggregation scope, model/account scope, time zone, currency, reset rules, and whether zero is meaningful. |
| Conditions | Minimum version, plan, login method, opt-in, permission, platform, and rate limits. |
| Freshness | Poll/event trigger, valid age, stale policy, and timestamp source. |
| Completeness | Complete/partial signal and known blind spots. |
| Privacy and distribution | Data touched, persistence, logging, authentication boundary, entitlements, and Developer ID compatibility. |
| Evidence | Primary-source link or local read-only observation, sample version, and verification date. |
| Test fixture | Sanitized fixture or reason a deterministic fixture cannot be kept. |

At minimum, investigate these capability families:

- identity and plan;
- CLI/app presence and compatible version;
- authentication and connection lifecycle;
- product quota windows and reset times;
- daily and lifetime token usage;
- input, cached input, cache write, output, reasoning, and tool-token breakdown;
- hourly detail and per-model usage;
- observed cost and currency semantics;
- session/context usage, tasks, goals, tools, and other active work;
- official service status;
- timestamps, partialness, retention, and export eligibility.

Negative findings are first-class results. Record that a provider does not
expose a five-hour window, cost, history, or tasks so later work does not repeat
the same investigation or invent a substitute.

## 5. Display contract by surface

### Feature registration and navigation

A complete feature has a stable provider identifier, display name, identity
asset, Settings destination, General feature option, help/detail copy, and an
official service-status definition when one exists. Preserve a full-color brand
asset only inside its bounded identity region; all DockMagic chrome follows the
shared design system.

### Settings

Settings must provide:

- setup/connection state and the narrow action required to progress when setup
  is provider-managed;
- a preview rendered by the production Dock renderer;
- the values represented by that preview, including explicit unavailable state;
- applicable display-style and appearance controls with reset behavior;
- last-updated/stale/error detail and retry where acquisition can fail.

Do not show sign-in, sign-out, executable, permission, or hook controls when the
provider does not require them. A setup action must run only the documented
provider command or public system flow it names; it must not become a general
shell or credential collector. A non-interactive sign-out must remain in a
stable processing state until the provider command and a signed-out status
probe both succeed; it must not expose background command output as terminal UI.

### Dock tile

The Dock is a glanceable summary, not a complete dashboard.

- Render only supported metrics with valid presentation semantics.
- Treat `0` as a real value and absence as unknown/unavailable.
- Omit unsupported quota windows. Rebalance a single window instead of drawing
  an empty second ring.
- Keep chart/numeric/ring choices consistent with Settings and use the same
  production renderer in the preview.
- Communicate loading, stale, and unavailable states with symbols and
  accessibility values, not color alone.
- Include provider identity in the accessibility label even if the visual tile
  relies mainly on data.

### Hover dashboard

The hover dashboard starts with identity, optional plan, data state, official
service status, and last-update/reset context. Add modules only when their
capability status warrants them:

1. quota windows;
2. current/lifetime usage and history;
3. daily detail and token breakdown;
4. intensity and model distribution;
5. streak/badges and Ship momentum derived from eligible activity;
6. active sessions, tasks, goals, or tools;
7. observed cost;
8. activity-card export.
9. quota-card export when the provider reports scoped quota but eligible activity
   is unavailable.

If a capability is supported but temporarily missing, preserve the module's
place only when it helps explain setup, loading, stale, or unavailable state.
If it is unsupported or prohibited, omit it. Failure in one optional module must
not hide valid quota or activity from another source.

Drill-down navigation must support a visible Back action and Escape. Loading,
empty, partial, and failed detail states must remain distinct. Interactive
charts require keyboard/accessibility equivalents for hover-only information.

### Service status

Provider service health is separate from local setup and data freshness. Link
only to an official status source. Never describe a missing CLI, expired local
snapshot, or unsupported plan as a provider outage.

### Activity-card export

Export is available only when the provider supplies enough non-sensitive
activity to make the card meaningful. Save, Copy, and Share must render the
same dedicated opaque 1200×1200 artifact rather than a screenshot of popup
chrome. Include provider identity, the selected activity values, and clear
stale/partial semantics; never export internal paths, account identifiers,
prompts, answers, task descriptions, or goal text.

### Quota-card export

A provider may offer Save, Copy, and Share of a dedicated quota card when a
valid provider-reported quota snapshot exists but activity-card export is not
eligible. Show each included bucket's upstream scope, window, remaining value,
and reset time when reported; identify omitted buckets explicitly if the card
cannot fit them all. Preserve last-known and source-timestamp semantics. Never
derive token activity, an aggregate account quota, or a missing reset from the
quota snapshot. Apply the same PNG resolution and redaction rules as the
activity card.

## 6. Data semantics and derivation rules

### Quota

- Model quota windows as a collection identified by upstream scope and
  duration; do not hard-code universal 5-hour and weekly availability.
- Preserve upstream `used` vs `remaining` meaning and clamp percentages only
  after parsing. Convert once in the normalized model.
- Keep an unknown reset time as `nil`; it is not an immediate reset.
- Select an aggregate account bucket only when the provider documents or the
  evidence establishes that scope. Never substitute a model-specific bucket.
- Token totals, observed cost, active tasks, or old snapshots cannot be used to
  infer product quota.

### Usage, cost, and history

- Preserve units and local-day/time-zone boundaries explicitly.
- Mark partial history and partial model coverage in the model and UI.
- Merge official and local fallback data only with a documented precedence rule
  that prevents double counting. An official bucket normally wins for the same
  period.
- Label cost as observed or estimated exactly as the source defines it. Do not
  invent pricing or estimate cost from tokens unless the product explicitly
  requests and documents that derived metric.
- Normalize model names only for presentation; retain the original identifier
  in the data layer.

### Derived engagement modules

Streaks, badges, intensity, and Ship momentum are DockMagic-derived features,
not provider facts. Their input eligibility, local-day boundary, persistence,
and missing-day behavior must be documented. Keep ledgers separated by provider
and make repeated observations idempotent.

## 7. Acquisition, privacy, and distribution

Prefer, in order:

1. documented public provider APIs or CLI protocols;
2. documented output from the user's unmodified local provider tool;
3. documented local event/hook contracts;
4. minimal local metadata with a narrow parser and explicit privacy review;
5. a documented derived value based only on eligible inputs.

Do not use private web endpoints, extract or proxy OAuth/session credentials,
read credential stores, send model prompts merely to manufacture usage, or
parse prompt/answer content when metadata is sufficient. Keep raw terminal/API
buffers bounded and ephemeral; never log raw output that may contain private
content. Persist only normalized fields that the feature actually needs.

For local hooks or configuration edits, require provider-documented extension
points, preserve existing user configuration, mark DockMagic-owned entries,
write atomically, and provide a conservative uninstall/migration path.

The integration must remain compatible with direct Developer ID distribution,
Hardened Runtime, notarization, and stapling. Evaluate App Sandbox and every
new entitlement against the feature rather than assuming Mac App Store rules.

## 8. Architecture and lifecycle

Keep these responsibilities separate even when the first implementation is
small:

- **provider adapter:** discovery, version/auth checks, transport, parsing, and
  provider-specific errors;
- **normalized snapshot:** quota, usage, provenance, timestamps, partialness,
  and optional activity modules;
- **store:** refresh coalescing, polling/events, stale retention, cancellation,
  retry, and connection state;
- **presentation:** capability filtering, formatting, and state-to-copy mapping;
- **surfaces:** Settings, Dock, hover, drill-down, and export renderers;
- **composition:** app startup, activation, sleep/wake/network recovery,
  preferences, service status, and background-observation policy.

Adding a provider requires auditing all of the following integration points:

- provider identifier, brand, logo, Settings destination, and General picker;
- preferences, display style, appearance defaults, migration, and reset;
- model, adapter/parser, store, polling/event lifecycle, and app composition;
- Dock presentation/controller and accessibility value;
- Settings setup, preview, values, and customization;
- hover header, modules, state copy, navigation, and panel sizing;
- service-status mapping and official URL;
- export eligibility and redaction;
- unit/UI fixtures, project membership, docs, licensing, and third-party notices.

Background observation is a product decision per provider. If derived streaks
or realtime activity depend on continuous observation, document why monitoring
continues while another Dock feature is active. Stop child processes and
cancel in-flight work on sign-out, executable change, app shutdown, or relevant
system interruption.

## 9. Research and implementation gates

Research is complete only when:

- the capability dossier is filled with primary evidence and a verification
  date;
- supported account/plan/version conditions are explicit;
- missing, partial, stale, zero, and reset semantics are known;
- the authentication, privacy, persistence, and distribution boundaries are
  acceptable;
- unsupported, unknown, and prohibited metrics are recorded;
- sanitized fixtures can exercise the parser without live credentials.

Implementation is complete only when:

- every shipped module maps to a supported capability;
- setup, loading, live, stale, unavailable, failed, zero, partial, and
  supported-single-window cases are tested where applicable;
- a failure in an optional module preserves other valid data;
- the production Dock renderer drives the Settings preview;
- UI is verified in Light, Dark, Increased Contrast, Reduce Transparency,
  Reduce Motion, and grayscale;
- icon-only controls have labels, help, and stable identifiers;
- no secret, raw private response, prompt/answer content, or internal path is
  persisted, logged, displayed, or exported;
- architecture, provider dossier, privacy notes, and third-party notices match
  the shipped behavior.

## 10. Provider research report template

Use this shape for a new provider document under `docs/`:

```markdown
# <Provider> integration research

**Status:** Proposed | Blocked | Ready for implementation | Implemented
**Verified:** YYYY-MM-DD
**Tested versions/plans:** ...

## Recommendation
Ship / do not ship / ship a limited slice, with the reason.

## Supported user story
What the user can reliably learn or do in DockMagic.

## Capability dossier
<Use every required column from section 4.>

## Surface map
Settings: ...
Dock: ...
Hover: ...
Drill-down: ...
Export: ...

## State and freshness policy
Setup, loading, live, stale, unavailable, failure, polling/events, reset.

## Privacy, security, and distribution
Data touched, authentication boundary, persistence/logging, permissions,
Developer ID implications, third-party code/license.

## Evidence and fixtures
Primary sources, sanitized observations, versions, dates, and fixture paths.

## Unknowns and rejected approaches
What remains unverified and which tempting sources or inferred metrics are not
allowed.

## Verification plan
Parser, store, UI state, accessibility, recovery, and live smoke tests.
```
