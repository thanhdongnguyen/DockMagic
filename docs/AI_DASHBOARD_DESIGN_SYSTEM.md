# DockMagic AI Dashboard Design System

**Status:** Normative for new and changed AI dashboard UI  
**Source inventory reviewed:** September 15, 2026  
**Visual verification:** Existing repository images were inspected; the running dashboard was not verified in this review.

## 1. Purpose and authority

This contract defines how DockMagic composes AI hover dashboards and how each
module looks, behaves, and handles incomplete data. It makes shared UI changes
propagate to every dashboard that opts into the affected module, while keeping
provider capabilities and the requested product scope explicit.

Apply the documents in this order:

1. AI_PROVIDER_FEATURE_CONTRACT.md decides whether a datum may be collected,
   derived, displayed, or exported. Its capability dossier and observation
   states are authoritative.
2. COLOR_DESIGN_SYSTEM.md decides color use and bounded exceptions.
3. DESIGN_SYSTEM.md decides semantic roles, components, appearance, typography,
   spacing, surfaces, and accessibility.
4. This document decides dashboard composition, module variants, interaction,
   copy structure, and layout.
5. A provider dossier records upstream evidence. A provider dashboard manifest
   records exactly which approved modules and variants that provider uses.

This is a UI contract, not an upstream-data contract. Codex or Claude Code
having a module does not establish that another provider supports it.
The existing dashboard views are not yet composed through a runtime manifest
or extracted module catalog; this document defines the target for that work.

## 2. Two-layer architecture

The general dashboard layer owns the opaque panel, Dock pointer, identity
header, status display, section spacing, navigation, interactive state,
accessibility, and export menu. Weather and System Metrics may reuse suitable
general components without acquiring AI-only concepts.

The AI module catalog owns quota windows, daily usage, continuity, Ship
momentum, model insights, active work, token detail, and activity or quota
exports. A provider manifest selects modules from this catalog. Provider
adapters and stores continue to own acquisition, parsing, freshness,
persistence, and recovery.

The implementation should use typed Swift presentation models and explicit
composition. Do not make layout depend on arbitrary provider JSON, a list of
untyped views, or a provider-name switch inside every shared component.

## 3. Scope gate and manifest

Every independently displayable module needs all of the following:

- a user story or approved baseline requirement;
- a capability-dossier row with supported status and its plan, version,
  authentication, or opt-in conditions;
- a normalized input with scope, unit, provenance, timestamp, and completeness;
- an explicit entry in the provider dashboard manifest;
- a module specification and applicable state, interaction, and accessibility
  fixtures.

Unknown, unsupported, and prohibited capabilities are omitted. A supported
capability that is temporarily loading, stale, unavailable, or failed may keep
its place only when the module explains the state or offers a useful action.
An optional module failure must not erase another module's valid data.

The manifest is an allowlist, not a wish list. It declares ordered module IDs,
variants, source dependencies, conditional setup actions, detail routes, and
export eligibility. UI composition must not append a metric merely because a
normalized snapshot happens to contain a field. A requested and supported
module absent from the manifest, or a manifest module absent from the approved
scope, must fail the review or fixture check. A requested but unsupported,
unknown, or prohibited module is recorded as an explicit limitation instead.

Changes propagate in two distinct ways:

- A change to a shared module's rendering, state copy, accessibility, or
  layout updates every manifest that already selects that module.
- A new metric or module enters the catalog but appears in a provider only
  after its dossier and manifest explicitly select it.

## 4. Presentation data contract

Each module has its own observation state. Keep capability status separate
from live observation. Represent not configured, loading, live, stale,
unavailable, and failed states explicitly. Preserve the last valid value and
its timestamp on stale refreshes. Preserve partial coverage independently.

A daily bucket must distinguish a measured zero from a missing or unobserved
day. Missing days may appear as gaps or a marked unavailable cell; they must
not become zero-height measured bars, contribute to Best-day calculations, or
start a streak. The local calendar day and time zone must be part of the
presentation input. A provider-reported quota bucket must retain its original
scope and window; a model pool is not an aggregate account quota.

Formatting happens once in presentation. Shared views receive display-ready
units and semantic data, not raw provider payloads. A derived module records
its eligible inputs and algorithm separately from upstream facts. Observed or
estimated cost must carry the source's exact meaning and currency.

## 5. Module catalog and composition order

The default order is identity and service status, quota, daily usage,
continuity, Ship momentum, usage insights, active work, and provider-specific
detail entry points. Export is a header action when eligible. The manifest may
omit modules or choose a justified variant; it should not reorder modules
merely to fill space.

| Module ID | Input gate | Current source-reviewed baseline |
| --- | --- | --- |
| identity.header | Provider registration; plan optional | Codex and Claude Code |
| service.status | Official status source defined | Codex and Claude Code |
| quota.windows | Provider-reported scoped windows | Codex and Claude Code |
| usage.daily | Daily tokens and optional observed cost | Codex and Claude Code |
| usage.lifetime | Valid lifetime token total | Codex header |
| continuity.streak | Eligible per-provider daily activity | Codex and Claude Code |
| continuity.badges | Eligible streak ledger and milestone rules | Codex and Claude Code |
| activity.shipMomentum | Eligible current local-day token input and approved score derivation | Codex and Claude Code |
| insights.dailyIntensity | Eligible daily buckets and coverage | Codex and Claude Code |
| insights.topModels | Per-model token totals and coverage | Codex and Claude Code |
| work.active | Documented local realtime metadata and setup | Claude Code |
| detail.dailyTokens | Supported hourly or model/token breakdown | Codex |
| export.activityCard | Enough nonsensitive eligible activity | Codex and Claude Code |
| export.activityAvailability | Explicitly approved activity-layout variant with a valid source anchor and unavailable activity slots | Antigravity quota-only option |
| export.quotaCard | Valid provider-reported scoped quota and explicit manifest selection | Catalog option; not selected by Codex, Claude Code, or Antigravity Share |

The table inventories current UI, not universal support. A future provider
must receive its own evidence-backed manifest.

The source-reviewed Codex overview order is identity and service status;
reported quota windows; Daily tokens and optional lifetime total in the
header; continuity; Ship momentum; Daily intensity and Top models. Its
selected-day route provides token detail, and its eligible export is an
activity card. It has no Active work or Cost selector.

The source-reviewed Claude Code overview order is identity and service
status; expected quota-window rows; Daily usage with Tokens/Cost selector;
continuity; Ship momentum; Daily intensity and Top models; Active work.
Its eligible export is an activity card. It has no Codex-style selected-day
token detail. These are current source inventories, not a substitute for
provider dossier rows or the future typed manifests.

For each provider, keep the manifest's reviewable record beside its dossier:
ordered module ID, selected variant, exact dossier capability row, source
dependency, setup condition, detail/export eligibility, and explicitly
excluded adjacent modules. The shipped typed Swift manifest and provider
document must agree.

## 6. Shell and identity

Use DockHoverChrome and DockHoverDashboardCard as the source-reviewed shell
baseline: keep the rounded card and shadow 6 pt inside the transparent NSPanel,
use the existing 10 pt Dock pointer, 12 pt content inset, an opaque raised
surface, and an 18 pt card radius. The outer floating host owns elevation;
nested data cards use neutral inset surfaces and outlines without new shadows.

The current AI dashboard width baseline is 440 pt. Codex currently uses a
440 × 556 pt panel; Claude Code uses 440 × 740 pt with vertical scrolling.
Those heights are current examples, not new-provider constants. Compute a
height from selected modules, clamp it to the visible screen, and enable a
vertical content scroller when needed. The panel must remain usable near each
Dock edge and with long labels. In a static export render, omit popup chrome,
the pointer, controls, and scrollbars.

The identity row contains a bounded 26 × 26 pt provider logo, a readable
provider name, an optional neutral plan badge, an explicit local data-state
label when relevant, an optional valid lifetime metric, and an export control
when eligible. Keep original brand color inside the logo. Use a separate
compact service-status row with an official link when a status source exists.
Service health must not stand in for local connection or data freshness.
Label icon-only controls and assign unique provider-qualified identifiers.

The source-reviewed header uses a 17 pt bold provider name, a compact plan
badge, a 26 pt export control, and an approximately 14 pt service row. New
implementations should centralize these dimensions in shared dashboard tokens
and adapt text length instead of copying feature-local font literals.

## 7. Quota windows

Render quota as a list of independently scoped, provider-reported windows.
The baseline row is 30 pt high: monochrome window icon, window and scope
label, numeric remaining percentage, the word "left", a 6 pt solid progress
track, and reset text. Reset may be unknown; show a dash or "Reset not
reported", never an invented time. A measured 0% is exhausted, not missing.

Use one solid data hue in the progress region and a neutral track. At or below
20% remaining, warning replaces the progress hue locally; at or below 5%,
danger replaces it. Keep the numeric value, text, and accessibility value so
color is never the only signal. Quota rows must announce the window, upstream
scope, remaining value, reset time or absence, freshness, and partialness.

Codex currently omits windows not returned by its account aggregate.
Claude Code currently shows "Not reported" rows for its expected 5-hour and
weekly subscription windows. These are explicit variants. A provider with
multiple model pools needs each pool named and kept separate; do not force it
into two generic rows. A single reported window must rebalance the Dock ring
and hover layout without a fake second window.

## 8. Daily usage and history

The daily-usage section has a metric title, actual date range, current or
hovered-day value, an optional metric selector, a chart, and scoped
loading/empty/stale/partial copy. Default history is the current local day
plus the previous 29 days when the source supports that range. The chart may
have fewer valid buckets; distinguish an unobserved day from observed zero.

The source-reviewed token-chart baseline uses a numeric y-axis, three neutral
grid lines, 46 pt date columns with 8 pt gaps, 27 pt solid bars, and weekday
and day labels. A hover or focus value gives the full date, exact amount,
unit, and coverage. Each column has an accessibility label and value.
Keyboard users must be able to reach any selectable bucket. Use the shared
history viewport and keep the newest bucket initially visible. A chart must
remain legible in grayscale and Increased Contrast.

Codex currently labels its variant "Daily tokens" and opens a daily detail
only for a valid positive bucket with supported detail. Claude Code currently
labels its variant "Daily usage" and offers Tokens/Cost. The selector contains
only supported metrics, exposes a selected trait, and keeps separate values,
units, availability, and cost provenance. The Cost option must identify
observed or estimated USD according to the source; it is not subscription
billing. A provider without daily detail has no implied drill-down.

## 9. Continuity and badges

The continuity strip is a single focusable action with a minimum 62 pt
source-reviewed height: 48 pt earned or locked badge artwork, current and
best streak copy, seven recent-day nodes, progress to the next badge, and a
right chevron. Active, inactive, unknown, and today-pending days use distinct
symbols, outlines, and accessibility values. Do not infer inactivity from an
unobserved day. A missing eligible ledger shows an explanation only when the
module is supported and the user can gain data.

The detail route provides a visible Back action and Escape. It contains the
current badge, current/best/next metrics, seven-day activity, and a milestone
roadmap with unlocked, current, next, and locked states. Badge artwork may
retain its authored colors inside its silhouette; surrounding chrome follows
the neutral-first color contract. A celebration may appear for a newly earned
streak, offer "View badges", and return to the overview after the current
approximately 2.8-second interval. Reduce Motion removes nonessential
effects. Earned badges remain unlocked after the current run ends.

## 10. Ship momentum

Ship momentum is an explicitly derived daily token-activity indicator. It
must not claim productivity, work shipped, quality, or an upstream provider
score. Its eligible current-day input, coverage, local-day reset, score
formula, and rank mapping must be approved and documented for the provider
before the module enters its manifest.

The source-reviewed card has a minimum 110 pt height and neutral inset
surface. It contains a 132 × 56 pt Living Flame gauge with a numeric 0–100
score, six ascending rank steps from Starter through Legend, the active rank
name, and today's eligible token total. The active step is the only accented
rank; completed and future steps use neutral form and position. The
accessibility value states score, rank, token input, and partial coverage.
The help copy says that the score resets each local day and is not a
productivity rating.

Missing eligible activity makes the score unavailable, not zero. A confirmed
zero current-day bucket may produce a real zero. A partial local observation
must say "observed" or equivalent in the card and export. The vector gauge
may animate only when motion is enabled; Reduce Motion and image export use
a deterministic settled silhouette.

## 11. Daily intensity and Top models

The source-reviewed insight pair occupies two neutral inset cards side by
side at a 440 pt panel width. The present 90 pt height is a baseline; grow
or scroll content for longer labels and accessibility text rather than
silently clipping it.

Daily intensity shows up to 30 local days in a 15-column grid, five levels
from zero through peak, a Best-day label, date endpoints, and a contained
legend. A pointer tooltip and accessibility value provide exact day and
tokens. Unobserved days are marked, excluded from Best, and never treated as
zero. Partial coverage is visible in title/help copy.

Top models shows at most three models ranked by token total for the stated
period. Each row has rank, readable model name, a small solid proportional
bar, and token amount. Name normalization is presentation-only; raw model IDs
remain in data. Empty and partial model coverage have explicit copy.
Do not rank by request count, cost, or a different window while labeling the
card "Top models by tokens".

## 12. Active work and local setup

Active work is a capability-gated local metadata module, not a generic
dashboard placeholder. The current Claude Code variant shows a title and
count, a documented hook-setup explanation and action when needed, compact
task/goal rows when observed, and a scoped empty or failed state. A row
currently has a 40 pt baseline and includes a monochrome state icon, title,
detail, and textual state. Processing, warning, and danger colors apply only
to real states.

The setup action must name the documented provider extension point and
preserve user configuration. A hook failure remains inside Active work and
does not suppress valid quota or usage modules. Raw prompt/answer content is
not a dashboard input. Task names and goal text, when allowed locally, never
enter export images.

## 13. Detail routes

A detail route has a visible Back action, Escape behavior, provider-qualified
accessibility label, and independent loading, empty, partial, and failed
states. It must not inherit a supported-looking breakdown from another
provider's view.

The current Codex daily-token detail contains the selected local date, total
token metric, an hourly chart, and conditional Input, Output, Cached input,
Reasoning, Tool, and per-model token breakdowns. Each subfield appears only
when its source and semantics are established. A failed detail read preserves
the valid daily account bucket and shows the scoped error; it does not blank
the overview's other modules.

## 14. Export controls and artifacts

An eligible header export control opens one shared menu with Save, Copy, and
Share. It exposes its type as "activity card", an approved "activity layout",
or "quota card", its output size,
an error within the menu, Escape dismissal, and unique provider-qualified
identifiers. Rendering, clipboard, save, and share use the same artifact
bytes for one export attempt.

The activity card is a dedicated opaque 300 × 300 pt SwiftUI composition
rasterized at 4× to 1200 × 1200 PNG. It contains bounded provider identity,
earned badge or a truthful empty badge state, today's eligible token amount,
an optional caption-free 14-day mini trend, Ship momentum score/rank when
eligible, and a source date or Last known/partial label. Do not include
popup chrome, pointer, menu, account ID, internal path, prompt, answer,
task description, or goal text.

AI_SHARE_ACTIVITY_CARD_LAYOUT.md defines the activity card's visual zones,
geometry, state variants, and Codex/Claude Code reference images.

If a valid provider-reported scoped quota exists, the optional quota card uses
the same dimensions and actions, including as a separate export mode when
eligible activity also exists. It
shows each included bucket's scope, window, remaining value, reported reset,
and last-checked/last-known semantics. If the artifact cannot include all
buckets, identify omitted buckets. Quota never stands in for token activity.

Antigravity's explicitly selected activity-availability option is a distinct
artifact and the only Share layout when activity is absent but quota exists.
It reuses the
Codex activity-card geometry with a locked badge unless an independently
eligible badge was earned, unavailable token/Ship
values, a neutral `NO HISTORY` cue instead of a plotted chart, and a
quota-sourced `CHECKED` or `LAST KNOWN` date. Antigravity's Share menu exposes
only the activity layout and its Save, Copy, and Share actions. The separate
quota-detail renderer is not selected in Antigravity's current export manifest.

## 15. Appearance and accessibility

Use semantic DesignTheme roles and the existing surface hierarchy. Normal
chrome is neutral with one action accent. Provider logos stay in their
identity region. User-selected and data colors stay in charts, quota
progress, Dock renderers, previews, swatches, and legends. Semantic warning
or danger replaces the local accent only for a real state. The existing
Claude usage-color exception is bounded by COLOR_DESIGN_SYSTEM.md; source
uses outside that boundary are migration issues, not new precedent. No
product gradients, decorative tinted cards, or colored glow.

Centralize dashboard typography, spacing, and control sizes using shared
roles. Existing 7–9 pt feature-local chart and metadata text should be
evaluated for readability when extracted; it is not a general token. Long
provider or model names, localized copy, larger accessibility text, and
keyboard focus must remain usable.

Inspect Light, Dark, Increased Contrast, Reduce Transparency, Reduce Motion,
and grayscale. Verify pointer, keyboard, Escape/Back, AX label and value
uniqueness, hit targets, loading/empty/stale/partial/failure states, and real
panel clipping. Source inspection, build/tests, image rendering, and live
visual inspection are distinct evidence; report which were actually done.

## 16. Adding or changing a module

1. Record the requested user story and exact scope. Identify adjacent metrics
   that are intentionally out of scope.
2. Fill or update the provider capability dossier with primary evidence and
   conditions. Mark unsupported, unknown, and prohibited findings explicitly.
3. Write or update the module specification: ID, input semantics, variant,
   layout, copy, states, interactions, accessibility, export, and fixtures.
4. Add or change a shared typed component only when the semantics are common.
   Keep genuine provider acquisition or detail differences in adapters or
   provider-specific views.
5. Explicitly select the module in each eligible provider manifest. Review
   all manifests affected by a shared visual change; do not auto-enable a new
   capability across providers.
6. Verify source-to-UI mapping, zero versus missing, partial and stale states,
   scope, layout, accessibility, appearance, and applicable Dock/Settings
   preview or export behavior. Update architecture and provider docs when the
   shipped implementation changes.

## 17. Illustrative Grok manifest

This is a scope example, not a claim about current Grok capabilities. If a
future Grok dossier establishes eligible daily token buckets and a trustworthy
current local-day token total, a requested Grok dashboard may select
identity.header, service.status when an official source exists, usage.daily
in its Daily tokens variant, activity.shipMomentum with an approved derivation,
and an activity export only if the artifact has enough eligible input.

The Daily tokens section would display the actual covered date range, numeric
y-axis, daily bars, today's or focused day's exact token value, and visibly
marked missing days. The Ship momentum card would show the numeric score,
Living Flame gauge, six-rank ladder, rank name, today's eligible tokens, and
partial/local-day copy. A daily drill-down appears only if hourly and
breakdown capabilities are separately proven and requested.

Quota, Cost, Top models, Active work, streak, badges, and detail routes remain
outside that example manifest unless the user requests them and the provider
dossier supports them. If daily token capability is unknown or unavailable,
the two requested activity modules cannot be shipped as if data existed; the
research report must state the limitation and propose the supported slice.

## 18. Source-reviewed inventory and known migration gaps

The current Codex and Claude Code hover views share DockHoverChrome,
UsageLimitHoverRow, streak views, the Ship momentum gauge/card, intensity,
Top models, and activity-card rendering. Their header, export menu,
navigation state, and daily-usage composition still repeat code. Codex has
a daily-token drill-down; Claude Code has a Tokens/Cost selector and Active
work. These differences are capability gates, not cosmetic inconsistencies.

Before relying on the new shared components, audit the current source for
the Codex-specific export identifier in the Codex view, Claude's daily
bucket fallback that can turn a missing day into zero, Claude's stale-state
header copy, and Claude usage-color application outside the documented
bounded exception. The older ARCHITECTURE.md Claude status-line section
also needs reconciliation with the newer Claude local-usage implementation
before it serves as implementation evidence.

Source-reviewed files:

- [CodexHoverDashboardView.swift](../DockMagic/DockMagic/Views/Hover/CodexHoverDashboardView.swift)
- [ClaudeCodeHoverDashboardView.swift](../DockMagic/DockMagic/Views/Hover/ClaudeCodeHoverDashboardView.swift)
- [StreakDashboardViews.swift](../DockMagic/DockMagic/Views/Hover/StreakDashboardViews.swift)
- [ShipMomentumGaugeView.swift](../DockMagic/DockMagic/Views/Hover/ShipMomentumGaugeView.swift)
- [CodexDailyTokenDetailView.swift](../DockMagic/DockMagic/Views/Hover/CodexDailyTokenDetailView.swift)
- [CodexDashboardCaptureService.swift](../DockMagic/DockMagic/Services/CodexDashboardCaptureService.swift)
- [DockHoverCoordinator.swift](../DockMagic/DockMagic/Services/DockHoverCoordinator.swift)
