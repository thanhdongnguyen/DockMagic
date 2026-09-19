# Grok Build usage integration research

**Status:** Experimental local collection, Settings/Dock/dashboard wiring and
derived presentation are under implementation/verification; approved V1 remains
incomplete and release-blocked. Production remains disabled.

**Re-audited:** 2026-09-17

**Explicit CLI authentication flow (2026-09-17, follow-up):** Settings now
connects Sign in with Grok, Device code, Cancel, confirmed Sign out and Check
quota to a dedicated `GrokBuildAuthenticationController` and the existing
store. This supersedes the earlier disabled-button/absent-controller checkpoint,
not the billing or production release gate. The official [authentication
guide](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/02-authentication.md)
documents `grok login`, `grok login --device-auth` and `grok logout`. Reviewed
source dispatches login/logout separately from agent initialization.

Explicit auth commands are narrowly enabled for installed **1.0.30** only.
Settings checks its observed version; the real adapters recheck immediately
before login/logout in case the CLI updated since the last scan. This allowlist
does not certify signed-in billing or all startup behavior. Newer versions in
the upstream changelog are not automatically enabled. Every operation uses the
same configured executable and `GROK_HOME`; no credential file is read, copied
or mediated by DockMagic.

Login uses a fixed direct child command with closed stdin and bounded live
stdout/stderr, rendered through SwiftTerm using the shared terminal theme. The
reviewed browser/device-code flow needs no terminal input; the view cannot run
a shell or execute terminal escape callbacks to open links/write the clipboard.
The CLI itself opens the browser. Output is ephemeral (64 KiB total cap), cleared
on every exit, and never persisted/logged. Login times out after five minutes.
Cancel, leaving Settings, disable, configuration change, sleep and app stop
cancel owned work. Attempt identity isolates old callbacks, including a retry
using the same home. Cancellation during post-login quota confirmation also
invalidates that pending quota response.

Login exit zero records **command completion**, then requests a fresh quota
check. It does not establish Connected; with the current safety gate closed,
Settings says that sign-in completed but quota is unverified. Explicit logout
runs without opening ACP when that gate is closed: successful CLI exit clears
the old in-memory quota and reports **logout completed, account status not
verified**, not verified Signed out. Only the provider's signed-out/unsupported
consumer-auth response can confirm sign-out. Local history and badges remain
independent. A failed command is distinct from a completed command whose
verification failed. Sign-out is confirmation-gated and never triggered on
Settings open, refresh or integration disable.

The installed-CLI entry-point audit passed with an unsigned disposable home:
both login help variants and `logout` exited zero and preserved synthetic
session/worktree-pool markers. It did not execute login, read credentials or
touch the user's account. This is not a live browser/device-code completion
test. Signed-in quota remains blocked by the separately reproduced ACP startup
side effect; another credential or login from the user does not resolve it.
Verification details are recorded in
`docs/fixtures/grok-build/1.0.30/authentication-flow-report.json`.

Scoped verification: Foundation **129 passed / 8 opt-in skipped / 0 failed**;
the installed-CLI entry-point audit **1/1** passed. The broad app-host/UI run
passed **81/82**: the remaining device-code test was interrupted by an unrelated
foreground Chrome window. Its isolated retry passed, and the final three
authentication interaction tests all passed. The auth-output appearance test
then passed all six variants using its own composited test window; AppKit
`cacheDisplay` had omitted SwiftTerm's layer background, while actual window
screenshots showed readable output. No provider-wide renderer workaround was
retained. These are overlapping runs, not additive unique-test counts.

The standard `build_and_run.sh --verify` workflow passed with a fresh isolated
Debug QA build and the existing real-local QA preferences suite, with no Grok
fixture environment key. Final manual Settings reinspection was not completed:
the native UI reader timed out twice. Earlier real-local preview evidence
is not treated as a fresh visual result. The unrelated `CalendarSyncTests.swift`
source was excluded from the scoped Xcode test build; this is not a full-project
test pass or a new Developer ID release/package certification.

**Real local data + Settings preview (2026-09-17, 10:03–10:12 local):**
the authorized CLI 1.0.30 real-home probe passed **1/1**, with **35,987
tokens**, one eligible root, one observed day and 29 unknown days. Unchanged
reread ran no extra usage command; forced refresh ran one and kept the same
total. There were no excluded, unavailable or quarantined sources. This is
the existing local sample, not newly generated model activity.

The existing Debug QA bundle was then run with a fresh preferences suite and
**without `DockMagicUITestGrok`**. `DockMagicUITesting=1` remains enabled for
other test composition, but Grok uses the real executable/home and production
collector/store. Only preferences are isolated: the app uses the ordinary
home-namespaced normalized cache under `Application Support/DockMagic/GrokBuild`.
No new app build, account action, ACP session or prompt was performed.

Native Settings and inline dashboard inspection confirmed CLI 1.0.30 and
`Local: live`; the 35,987-token bucket is **September 16**, not today
(September 17, Asia/Ho_Chi_Minh). Today correctly displays a dash/unknown,
including the production Dock renderer embedded in Settings. The default quota
metric remains unavailable without automatic token fallback. Top models shows
`grok-4.6-build` with 35,987 tokens; Daily intensity selects September 16 as
Best day. Current streak and today's momentum remain unavailable; best streak
is one verified day and the First Prompt badge is retained. Badge detail,
roadmap and Escape navigation were exercised. Two dashboard refreshes and an
app restart preserved totals, paths, metric and badge. No old celebration was
observed; this short interaction is not an exhaustive once-only proof.

Collection also ran while CPU & RAM remained the active Dock feature. This
does not test a newly written source/file event or sleep/wake. Monitoring was
turned off in this QA preferences suite before restart and remains off for
manual refresh; Grok stays enabled and Settings preview is left open. Dock
hover stayed off. No Accessibility/TCC settings or login state were changed.
Light screenshots were inspected in-thread; no screenshot artifacts were saved.
Actual Dock hover/compositing, new-day activity, broader source attribution,
the full appearance/accessibility matrix and live quota/auth are not verified
by this run. Production and billing gates remain closed. Report:
`docs/fixtures/grok-build/1.0.30/real-local-settings-preview-report.json`.

**Release containment/signature verification (2026-09-17, 00:39 local):**
Foundation tests compiled in Release with `DOCKMAGIC_EXPERIMENTAL_GROK=1`
passed **117**, skipped **7** opt-in cases, and failed none (124 selected).
The gate test now explicitly asserts that Release ignores the environment
flag. The same test also passed in Debug with the flag both enabled and
disabled. These are overlapping cases, not additional unique test totals.
Production, runtime-version and billing safety gates remain closed.

A fresh isolated **arm64 Release** build using Xcode 15.4 succeeded with
Developer ID signing. The ordinary `build` action initially injected
`get-task-allow` and did not supply a secure timestamp. A second successful
build used command-line-only `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` and
`OTHER_CODE_SIGN_FLAGS=--timestamp`. The resulting QA bundle has a Developer
ID certificate chain, secure timestamp and Hardened Runtime flag, lacks
`get-task-allow`, and passes `codesign --verify --deep --strict` including
Sparkle's nested code. No shared project signing settings or entitlements
were edited. The resolved graph was SwiftTerm 1.18.0, Sparkle 2.10.0 and
swift-argument-parser 1.7.2; older build entries below describe earlier runs.

This is **static artifact verification**, not a packaged Grok runtime or
release approval. The isolated identifier is
`com.hypevibe.GrokReleaseVerification.DockMagic`; the app was not launched,
archived/exported, notarized, stapled or distributed. Gatekeeper correctly
returned `rejected / source=Unnotarized Developer ID` (exit 3). No new real
CLI/account, permission or UI interaction was performed; the separate Debug
QA app remains untouched. Existing actor-isolation and SwiftTerm build-graph
warnings remain. Full-app regression, production-identifier packaging,
packaged process/file-access behavior and the live quota/auth gates are
still required. Report:
`docs/fixtures/grok-build/1.0.30/release-containment-signature-report.json`.

**Native interactive QA (2026-09-17, 00:19–00:27 local):** the isolated Debug
app `com.hypevibe.GrokUITest.DockMagic` was opened with a dedicated defaults
suite and `DockMagicUITestGrok=available`. Its collector/account/cache are
synthetic; the matching 35,987-token fixture is not a new real-source probe.
The built bundle passed `codesign --verify --deep --strict` outside the
restricted shell (the same command inside it returned `CSSMERR_TP_NOT_TRUSTED`).
This is Debug signature evidence, not Developer ID/notarization proof, and
the existing built test app was launched directly through `open`, not a fresh
standard-workflow build.

Native UI actions verified enabling Grok, explicitly choosing Tokens observed
today, the 36K preview, and setting Grok as the app's active Dock feature.
Settings exposes that active state; it is not proof of the system Dock's final
composited icon. The computer-use Dock surface timed out twice. The QA app
reports **Accessibility required** for hover. Permission was not granted or
requested from macOS; user approval was requested in chat. Production defaults
and TCC permissions remain unchanged. The QA app is left at General's permission
state for this handoff.

The production dashboard in the inline Settings viewport was operated directly:
the chart reached horizontal scrollbar values **0 and 1** using its exposed
Accessibility Scroll Left/Right actions, showing the first/last dates and
unknown markers; the generic horizontal scroll gesture initially had no effect.
Badge detail reached the bottom of its roadmap, including **Continuum, day
730**, and **Escape** returned to overview. Scrolling the overview exposed
momentum, intensity and token-ranked `fixture-grok`; the header Settings button
closed the preview. Native screenshots were inspected in this thread in Light
appearance. They are not new Dark/accessibility-variant or VoiceOver evidence,
and no persistent screenshot files were created by this manual run.

The runtime link's exact destination,
[Grok Build Status](https://status.x.ai/grok-build), was separately verified to
serve the provider-specific official page. This does not verify the native
browser-launch click, introduce machine-readable status polling, or authorize
an Operational badge. Actual Dock hover/compositor, complete keyboard/VoiceOver,
transient-banner click, live lifecycle and release gates remain open.
Report: `docs/fixtures/grok-build/1.0.30/native-navigation-verification-report.json`.

**Durable retention verification (2026-09-17, 00:08 local):** synthetic
observations now exercise **3,650 consecutive days** with disk restarts every
360 days, followed by expiry of all detailed token/model records. Activity
witnesses, the best verified streak, earned badge and consumed celebration
claims survive persistence and five timezone reprojections without replay.
Each observation imports at most its own 30-day window; this is accumulated
history, not a backfill beyond the approved window. A separate case revises an
old turn after detailed-cache expiry and confirms the stable witness identity,
retained badge, unknown gap and once-only claim after restart. An intentionally
oversized synthetic cache write preserves the previously saved badge/cache and
allows a later valid write; it does not silently truncate durable history.

The opt-in high-volume case passed with **1,095 days × 100 turns/day**:
**109,500 durable witnesses**, **3,000 detailed turns** in the current 30 days,
and **8,995,766 bytes** on disk (below the existing 32-MiB cap). It exposed
repeated calendar conversion per turn. Grok now deduplicates local day starts
before constructing canonical day indices; the timestamp eligibility filter
still runs first. The optimized result matches per-turn projection for **128
combinations** of DST/leap/skipped-date fixtures, eight timezones, and clock
rollback. Shared legacy-provider code and cache schema are unchanged.

On this machine's Debug harness, one snapshot fell from **0.878 s to 0.162 s**
(about 5.4× faster); final save/load took **1.31/1.22 s**. These are individual
synthetic measurements, not a real-account soak, UI frame-time guarantee or
unbounded-history certification. The durable witness ledger still grows with
turns and retains the documented 32-MiB failure policy. No compaction or loss
of old verified days was introduced.

Verification: focused **5/5 including the opt-in stress case**; final
Foundation **117 passed, 7 skipped, 0 failed** (124 selected; six live probes
and the separately exercised stress case are opt-in); isolated app-hosted
Grok/legacy-streak **82 passed, 1 stress case skipped, 0 failed** (83 selected).
The sets overlap. The first fixture build hit Swift 5.10's expression
type-check timeout; splitting its nested map into explicit loops fixed the
test harness, not a production failure. No UI interaction, real CLI/account,
system-clock change or release-package verification was performed.
`CalendarSyncTests.swift` remains excluded from the focused Xcode command.
Report: `docs/fixtures/grok-build/1.0.30/retention-stress-verification-report.json`.

**User-approved sequencing change (after 17:25):** the user explicitly approved
continuing local/UI implementation behind the Debug-only experimental flag
while billing stays unavailable. This supersedes the earlier before-UI gate,
not the full-module production release gate. No unsafe billing/authentication
route is enabled by this approval.

The user-supplied `/usage` screenshot labels the plan **X Premium** and window
**Weekly limit**, displays **0%** and **September 21, 17:34** for reset. The
screen does not explicitly state a timezone. Session input **35,879** (including
**6,144 cached**) plus output **108** (including **54 reasoning**) equals
**35,987**, matching the live local probe. This is a manual display cross-check,
not an automated quota/schema fixture. No percentage, plan or reset from this
image is hard-coded into application snapshots. Sanitized transcription:
`docs/fixtures/grok-build/1.0.30/manual-usage-screen-report.json`.

Experimental composition now uses `GrokBuildSettings`,
`GrokIntegrationController`, `GrokBuildPresentation`, `DockGrokBuildView`,
`GrokBuildSettingsView` and `GrokBuildHoverDashboardView`. The typed
`GrokBuildDashboardManifest` selects local daily tokens, coverage-aware
continuity/roadmap, the existing Ship momentum formula, intensity and Top
models. Quota is an explicit unavailable explanation without a fabricated
window; account plan is not inferred. The neutral G identity mark is a temporary
experimental mark, not an official brand asset.

`DOCKMAGIC_EXPERIMENTAL_GROK=1` exposes the feature in Debug only. Users must
explicitly enable collection in Settings. The default Dock metric is quota
(unavailable); Tokens observed today is a separate user selection. Settings
preview uses the same `DockTileView` case as the live Dock. Existing providers'
streak display keeps its default behavior; Grok explicitly selects unknown-today
copy and preserves the shared earned-badge roadmap. Shared chart compatibility
values always carry the explicit unknown-day set.

Authentication buttons are visibly disabled with the startup-safety reason.
They do not start a shell, login, logout or billing process. Completing the
official terminal authentication controller remains a release requirement.

**Sign-in callback isolation:** store authentication attempts now carry a unique
in-memory identity and the exact executable/home configuration. Repeated starts
are rejected while a login is active; completion consumes only its matching
attempt. Stop/reconfiguration invalidates the attempt, so a delayed success or
cancel callback cannot complete a later retry, even with the same home. Exit
zero still requires a fresh successful quota probe; local history and source
freshness remain independent. This is state-machine work using synthetic CLI
tests, not an implementation or live verification of the terminal controller.
Three reproductions failed with five assertions before the fix. The final
Foundation run passed **113 tests**, skipped **6 opt-in probes**, and failed
none (119 selected). The isolated Debug app-hosted integration/derived/legacy
streak run passed **78/78**; these sets overlap. No UI interaction rerun, real
Grok command, account action, standard-workflow relaunch or release-package
verification was performed. `CalendarSyncTests.swift` remains excluded from
the focused app test build; unrelated actor-isolation warnings remain.
Verification: `docs/fixtures/grok-build/1.0.30/auth-attempt-isolation-report.json`.

**Identity asset research (23:49 local):** the official
[brand guidelines](https://x.ai/legal/brand-guidelines) point to
`https://data.x.ai/logos/SpaceXAI_Grok_Assets.zip` and require the provided
artwork without alteration. The direct download returned HTTP 403; the browser
attempt did not provide a retrievable artifact. No official logo was imported,
no substitute was sourced elsewhere, and no artwork/notice change is claimed.
The neutral experimental mark remains. This does not change any capability or
release gate.

**Token appearance completed (23:27 local):** Settings now has the required
`DSColorPalettePicker` using `ProjectTheme.rendererColorOptions`, persisted in
the independent `DockMagicGrokBuildAppearance` preference. One explicitly
labelled token data color applies to the production Dock token number, the
same Settings preview renderer, daily history bars, Daily intensity and Top
models. It does not color quota/unknown/disabled values, status, controls,
badge artwork or momentum. No new quota series or provider capability is
implied. Changing color does not restart acquisition. Reset Defaults restores
the default color and number style while retaining the chosen metric,
executable/home, enabled state and monitoring policy.

The saved swatch remains unchanged. The shared theme resolver composites alpha
and adjusts low-contrast renderer colors against the explicit Light/Dark
surface (4.5:1 for Dock numerals, 3:1 for chart/insight base colors). These
numeric checks do not certify every intensity shade, a whole-screen WCAG
audit or VoiceOver. Other providers retain the shared chart's default color
and partial-opacity behavior unless they explicitly pass a data-color override.

Verification: **12/12** Grok app-hosted presentation cases, **7/7** synthetic
UI cases, and **44/44** targeted shared-provider regression cases passed. The
contrast case is included in both app-hosted sets; counts are not unique.
Native Settings/Dock/hover/badge captures with purple selected were reviewed
in Light, Dark, Increased Contrast, Reduce Transparency, Reduce Motion and
grayscale. Runtime screenshots also show the live preview changing to purple
and returning to blue on Reset Defaults; the UI test verifies persistence
across relaunch. Unknown, disabled and quota Dock captures remain byte-identical
when the chosen color changes. Full-desktop screenshots remain local, not
sanitized fixtures. No real Grok CLI, home, credential, billing or auth action
was used by this verification. `CalendarSyncTests.swift` remains excluded from
the focused Xcode commands, so this is not a full-app regression/release pass.
Report: `docs/fixtures/grok-build/1.0.30/token-appearance-verification-report.json`.

**Recorded-time eligibility correction (23:42 local):** a new regression audit
found a real inconsistency: a turn up to five minutes ahead of collection time
could previously enter the token chart, while the activity ledger rejected it.
An unchanged fingerprint then prevented the missing activity witness from ever
being reconsidered. Four tests failed against that implementation before the
fix; they now pass. New future-dated turn revisions are quarantined without
replacing the last good ledger, then retried after bounded backoff even when
the file has not changed. The metadata-only five-minute `sourceUpdatedAt`
allowance does not make future turn timestamps eligible. A turn that completes
during a scan can therefore be deferred to the next eligible refresh rather
than counted early.

Clock rollback hides cached turns/models ahead of `now` without deleting their
UTC ledger. Older experimental cache rows ahead of their own `observedAt`
remain excluded from tokens and activity imports until a successful source
reread; an unavailable source does not retroactively validate them. Successful
revalidation updates the existing identity, repairs its activity witness, and
restores normal unchanged-file reuse without double counting.

Final Foundation verification: **109 passed, 6 opt-in probes skipped, 0 failed**
(115 selected). The final app-hosted integration/derived/legacy-streak subset
passed **74/74**. An earlier build in this continuation passed **75/75** including
all 7 UI cases; that UI run precedes the final legacy-cache eligibility guard,
which is covered by the final Foundation/app-hosted runs. The overlapping sets
are not unique test totals. No view layout changed in this correction, no real
system clock/timezone changed, and the focused Xcode runs still exclude
`CalendarSyncTests.swift`; this is not a full-app/release-package pass.

The final authorized real-local probe at **23:39 local** also passed: CLI
**1.0.30**, **1 readable root**, **35,987 tokens**, model **grok-4.6-build**,
**29 unknown days**, and no unavailable/quarantined source. Initial collection
and forced reread each ran one `grok usage`; unchanged refresh ran none. Only
`--version`, `usage` and minimal metadata were used; no agent, prompt, session
request, login/logout or credential read. The upstream HEAD was rechecked and
remains `482711333c7195dc16a272777f86086d615e2afb`; the known ACP startup-safety
blocker has not been removed. All production/runtime/billing gates remain
closed. Report: `docs/fixtures/grok-build/1.0.30/timestamp-eligibility-verification-report.json`.

**Local/UI verification (21:38 local):** Foundation **96 passed, 6 opt-in live
probes skipped, 0 failed** (102 selected). App-hosted Grok presentation/derived
plus targeted legacy streak/routing/momentum checks **38 passed, 0 failed**.
The sets overlap and must not be added as unique tests. `CalendarSyncTests.swift`
was excluded from this focused Xcode invocation because unrelated Calendar work
was changing concurrently; this is not a full-app regression pass.

Native Settings, Dock sizes and hover/badge viewports were captured and reviewed
in Light, Dark, Increased Contrast, Reduce Transparency, Reduce Motion and a
grayscale simulation. Initial capture attempts were rejected: a saturation
modifier was not captured, and `drawingGroup` dropped native scroll/controls.
The final harness keeps native rendering and applies the existing QA-style
Core Image grayscale simulation with pixel checks. It does not change system
accessibility preferences. Fixtures are synthetic, not live quota. This capture
run alone does not verify interaction; subsequent route results are recorded
below. Full keyboard/focus/VoiceOver and Dock interaction remain separate gates.
Report and local artifact references:
`docs/fixtures/grok-build/1.0.30/experimental-ui-verification-report.json`.

**Interactive harness (22:06 local):** `GrokUITests` now exercises flag-off,
explicit Dock metric selection, unavailable quota, empty/error local history,
badge Back/Escape and new-activity celebration. `GrokUIFixtures` is Debug-only
and selected only in the existing UI-test composition: its CLI, collector,
monitor and cache are inert/synthetic and never use the real Grok home.
An xcconfig-only bundle-ID override isolates the test app from other running
DockMagic apps; defaults use a unique test suite. Production identifiers and
feature gates are unchanged.

The first interactive run passed flag-off, but the other three cases did not
pass. One assertion incorrectly read macOS `AXLabel` instead of `AXValue` and
has been corrected. The same run captured a disabled application accessibility
tree; other UI runners were active. A focused empty/error rerun could not find
the preview quota accessibility node. These are **not a passing route or
accessibility verification**. The empty-state screenshot does show unknown
tokens/momentum, `?` intensity days and unavailable quota. The updated tests
compile with `build-for-testing`; an exclusive desktop run is still needed to
separate input interference from remaining product/test defects. Teardown now
terminates the owned test app even after an assertion failure.

A `test-without-building` run at 22:07–22:09 initially found no competing
UI runners, but another runner started during it. That run's result was
**1 passed / 3 failed**; do not classify the three failures as resolved or
attribute all of them to interference without an uncontested rerun. Result:
`/private/tmp/dockmagic-grok-interactive-exclusive.xcresult` (the name does not
prove exclusivity). The task-owned Grok app and runner were absent after the
run; no other app was terminated by this work.

**Subsequent focused diagnosis (22:13–22:21 local):** the Settings case also
failed while no other UI runner was observed. Its recording shows the Grok
popover visibly displaying 36K, but that popover's contents are absent from the
XCTest accessibility tree. A selected Apple-menu AX item and disabled app tree
were not proof that the system menu was open; that earlier interpretation is
withdrawn. Adding explicit dashboard accessibility containers alone did not
repair this presentation boundary. Settings preview now expands inline using
the existing OpenCode pattern, with the same `DockHoverChrome` and production
dashboard view and a Done button. The next focused run passed the daily-token
and quota assertions and reached the streak-control query. This intermediate
result did not yet establish a passing UI suite.

**Navigation fixes and regression (22:35–22:47 local):** a concrete dashboard
container preserves child accessibility identities, the Grok streak strip
exposes its button role, and shared badge detail has an opt-in Escape shortcut
with the legacy default unchanged. The inline preview fits the Settings
viewport and retains an explicit Done action. The four-case UI suite passed
at 22:37 (`/private/tmp/dockmagic-grok-ui-navigation-suite.xcresult`). A fresh
Foundation run again passed **96 tests, with 6 opt-in live probes skipped**.

The expanded run at 22:40–22:43 selected 22 tests: **16 app-hosted/shared tests
passed**, and **4 of 6 UI tests passed**. New loading-cancellation and
stale-data-retention cases passed. The Settings failure trace queried
`com.hypevibe.DockMagic.NowPlayingQA` instead of the owned test app, so this
attempt is not exclusive-desktop evidence. The celebration assertion observed
the banner, but AX scrolling outlasted its 2.8-second lifetime before the click.
The once-only notification test now waits for dismissal and checks that refresh
does not replay it; badge navigation is tested through its persistent control.
The production banner duration is unchanged. A focused rerun of both failing
cases passed **2/2**, including badge Back/Escape and preview Done dismissal.
This does not claim reliable clicking of the transient banner in every viewport.

**Final six-case UI run (22:49 local): 6 passed / 0 failed** on the same built
test app (`/private/tmp/dockmagic-grok-ui-six-final.xcresult`). Scope: feature
flag off, explicit quota/token selection, unavailable quota, empty/error local
history, badge Back/Escape, preview Done dismissal, once-only celebration,
cancel while loading, and retained stale tokens without quota fallback.
Preflight/postflight found no other UI runner; no continuous exclusivity
monitor was used. The owned test app and runner were absent after completion.
These are synthetic UI cases, not new real-account or release-package evidence.

**Calendar lifecycle correction (23:02 local):** manual-only collection no
longer leaves the visible day buckets unchanged until refresh/resume. App
composition observes `NSCalendarDayChanged` and `NSSystemTimeZoneDidChange`
and requests a cached UTC-ledger reprojection independently of the active Dock
feature. It does not run the CLI, scan source files, check billing or change
`collectedAt`, source age or the last source-attempt timestamp. Resume uses the
same path. Calendar observers/tasks respect suspend/stop, and the next real
collection still detects the last collection timezone to recover a shifted
30-day window edge when available. Pruning invalidates scan reuse, so a clock
or timezone reversal followed by an authorized refresh also recovers that edge
when source fingerprints have not changed.

Projection is serialized with collection and celebration writes. It expires
30-day token/model details, retains durable activity/badges, clears an obsolete
pending celebration, and does not mark an initial import complete. A claim
whose disk write spans a timezone/day change remains consumed but is not
delivered as an old-day banner. A cache-write failure keeps in-memory data and
the warning, with a retry path. Reconfiguration cannot publish an old home's
projection into a new home.

Nine new Foundation cases cover midnight, 23/25-hour DST days, timezone round
trip, 90-day detail expiry, pending/claimed celebrations, in-flight collection,
save failure/retry, initial-import timing, unchanged-fingerprint recovery and
home replacement during a write.
The final Foundation suite is **105 passed / 6 opt-in live probes skipped /
0 failed** (111 selected). The app-hosted notification/composition and legacy
streak subset is **12 passed / 0 failed**; the final expanded app-hosted run at
23:07 also includes all 43 Grok integration cases and passed **55/55**. The
integration cases overlap Foundation and are not additional unique tests.
An initial barrier implementation
spun on a completed claim task; a one-second sample identified the loop, and
moving task cleanup before completion fixed it before these final passes.
Only the two owned stuck test processes were terminated. These tests inject
calendar/clock and a private notification center; they do not change macOS
timezone or prove real machine sleep/wake, real quota, or release packaging.
Evidence: `docs/fixtures/grok-build/1.0.30/calendar-lifecycle-verification-report.json`.
The six synthetic UI cases also passed at 23:05, despite another runner starting
after preflight; this is not exclusive-desktop evidence. That UI build precedes
the small scan-reuse invalidation follow-up, which is separately covered by
Foundation and app-hosted integration tests. No view layout changed here.

The 22:42 native matrix was exported and visually reviewed again: six appearance
variants, Settings, Dock sizes, hover and unknown-today badge detail. It uses
native accessibility overrides and Core Image grayscale simulation, not changes
to system preferences or a VoiceOver session. Images and SHA-256 references
are recorded in the verification report. Full-desktop XCTest captures are kept
local because they may include unrelated windows; they are not sanitized fixtures.

This run resolved the current workspace pins (Sparkle 2.10.0, SwiftTerm 1.18.0,
swift-argument-parser 1.7.2) into a fresh task-owned package cache after the
previous cache lost its Sparkle XCFramework. It did not change package pins.
The older package/build evidence elsewhere in this dossier remains dated
evidence, not the dependency graph of this run.

Visual review added opt-in `?` markers for unobserved Grok intensity days;
legacy provider defaults are unchanged. Manual-only mode now resumes cached
projections without starting CLI collection; explicit Refresh remains usable.
No standard-workflow relaunch was performed in this continuation because its
current `pkill -x DockMagic` would interrupt parallel app work. Developer ID
packaged validation remains a separate release gate.

**Real-token verification (17:22 local):** after the user completed a real
Grok turn, the installed 1.0.30 CLI and production discovery/parser/collector
accepted **1 root session, 35,987 tokens**, recorded on September 16 in
`Asia/Ho_Chi_Minh`. The token-ranked model is **`grok-4.6-build` (35,987)**;
model coverage is complete for this observed day's eligible data, not for the
account. The other **29 days remain unknown** and overall history is partial.
There were no excluded, unavailable or quarantined usage sources, and no scan
limit was reached. Metadata inspection found 2 summaries but only 1 usage file;
a summary without usage does not contribute tokens.

The focused live test passed: initial collection ran one `usage` command,
unchanged refresh ran none, and a **forced CLI reread** ran one and preserved
both daily and model totals. This is real local-token and stable re-ingestion
evidence for this sample, not proof of multi-day history, fork/resume/delayed
fold behavior, signed-in quota, or UI. No prompt/session request, agent startup
or credential read occurred. The first attempt was blocked by the execution
sandbox's Swift compiler-cache permissions; the permitted rerun succeeded.
The added test initially used tuple-array equality unavailable in Swift 5.10;
an element-wise comparison fixed that test-only compile error, and the final
focused rerun passed **1 test / 0 failures**. Production source and release
gates were not changed. The reviewed report, including normalized daily/model
evidence but no identifiers or conversation, is
`docs/fixtures/grok-build/1.0.30/real-home-local-usage-report.json`.

**Earlier user-authorized real-home check (17:00 local):** the user reported completing
Grok login. The installed CLI still reports 1.0.30. The real-home metadata scan
found **1 summary file and 0 usage files**; no eligible root could be read, no
`usage` command was issued, and all 30 daily buckets remain **unknown**, not
zero. The local probe passed its empty-scan/idempotence checks, but that is not
real-token parser/attribution evidence. Authentication is still user-reported:
no real-home agent or billing request was started, and no credential was read.

The subsequent synthetic-only diagnostic isolated why sandboxed startup fails
on this machine: `runtime-socket deny resolution failed`, because
`/var/run/docker.sock` is a symlink. The CLI refuses startup before ACP. No
Docker path/configuration was changed, and no sandbox protection was disabled.
This failure is not a sign-out or invalid-login result. The production quota
gate remains closed. Reviewed reports are in
`docs/fixtures/grok-build/1.0.30/real-home-local-scan-report.json` and
`docs/fixtures/grok-build/1.0.30/acp-sandbox-diagnostic-report.json`.

**Official-source follow-up:** the public `main` source still rejects a
symlink endpoint in `materialize_runtime_socket_deny_paths_from`, and the
upstream test `materialized_socket_paths_reject_endpoint_symlinks` explicitly
requires that rejection. The official changelog currently labels 1.0.30
(September 11) as latest. No verified official fix was found in these sources;
that is not a claim about every unpublished build. The metadata-only recheck
at that time still found 1 summary and 0 usage files (superseded by the real-token
check above). Do not remove the Docker socket link,
disable its deny policy, install a third-party fork, or turn off the production
safety gate to force this probe through. [S21] [S22] [S23]

**New blocking finding:** installed CLI 1.0.30 deletes stale
`worktree_pool/<instance>/` data during ACP `initialize`, before any session or
prompt, even with `GROK_WORKTREE_AUTO_GC=0`. This was reproduced only on
test-owned synthetic homes; no real user worktree or credential was touched.
Account polling and its logout confirmation are now hard-gated by
`billingStartupSafetyVerified = false`, including in experimental builds.
Logging in alone does **not** resolve this blocker. Do not run the account-home
probe until a safe official startup route has been verified. A subsequent
isolated 1.0.30 probe tried `read-only`, `strict`, and a documented custom
profile: all refused startup after failing to apply their sandbox in this test
environment. Preserving the marker by never reaching ACP is not a working
billing route. [S17]

**Reviewed source:** `xai-org/grok-build` commit
`482711333c7195dc16a272777f86086d615e2afb` (2026-09-15), rechecked against
remote HEAD. The shell package at that commit declares **1.0.32**; the public
changelog reviewed separately lists releases through **1.0.30**. These
declarations alone were not runtime evidence. Separately, the public stable **1.0.30
(04b7ffed98c6)** binary has now been installed and probed as described below.

**Earlier full-suite verification:** the expanded isolated suite had **98 passed /
1 signed-in probe skipped / 0 failures** (99 selected): 37 foundation, 33
collection/store/cache, 18 continuity/legacy regression, 7 OS-process lifecycle
and 3 installed-CLI unsigned probes passed. The startup-audit test passing
means it captured a reproducible **unsafe-startup result**, not that billing
is release-ready. The final seven app-hosted process tests and standard Debug
build/launch also passed; full app-hosted run details are recorded below. These results
do not establish real-history attribution, signed-in quota, Grok UI or
production-packaged behavior.

The later focused sandbox-candidate audit passed as an **audit**, with three
negative candidate results and a functioning unsandboxed control. It is a
separate check, not a new full-suite run or a production safety certification.

**Installation (explicitly requested by the user):** public stable 1.0.30 was
installed at `~/.grok/bin/grok`, with a `~/.local/bin/grok` link already on PATH.
No credential was read/copied, no login was started, no existing file was
overwritten, and shell configuration was not changed. The binary SHA-256 is
`d53b6e543e482716236748914331db50145c696ac7af91f1ebdedcf5654cfecb`.
Both x.ai and its official GCS fallback supplied the same bytes.
`codesign --verify --strict` passed **outside the execution sandbox**, with
Developer ID `X.AI Corporation (5Y6N3AJ54S)` and runtime enabled. The initial
in-sandbox `invalid signature` result was an environment limitation, not a
confirmed defective binary. No re-signing, quarantine removal or security
bypass was used. This verifies the CLI binary, not DockMagic's release package.

## Approved V1 and implementation checkpoint (2026-09-16)

The approved plan supersedes the earlier recommendation to ship a session-only
prototype. V1 requires **tokens, a 30-day partial history chart, quota, Ship
momentum, streak/badges, badge roadmap, Settings, Daily intensity and Top
models**, all verified before release. The user subsequently approved local/UI
work before ACP proof, with quota unavailable and production still blocked.

- `GrokBuildUsage.swift`: normalized local and quota types, unknown daily
  buckets, coverage, and a hard-disabled production gate. The verified CLI
  version set is empty. `DOCKMAGIC_EXPERIMENTAL_GROK=1` registers experimental
  Settings/Dock/hover surfaces in Debug only; it does not certify a capability.
- `GrokBuildUsageParser.swift`: bounded `grok usage` and snake_case billing
  decoding, missing/zero handling, counter validation, model coverage and
  separate current-versus-legacy quota windows. Cache/reasoning are subsets,
  not additional tokens. No cost/history-of-billing collection.
- `GrokBuildSessionDiscovery.swift`: bounded metadata discovery in the CLI's
  exact `sessions/<cwd>/<id>` layout; minimal lineage decoding; unsafe links,
  nested backups and ambiguous UUIDs excluded. No transcript acquisition.
- `GrokBuildHistoryAggregator.swift`: root-only, session/turn-identity ledger;
  idempotent replacement, monotonic revision checks, quarantine results,
  30-day recorded-at bucketing, unknown gaps, timezone rebucketing and Top 3
  token-ranked models. Codable records use a hashed home/session namespace.
  Zero/default-only model rows do not enter Top models.
- `GrokBuildLocalUsageProvider.swift`, `GrokBuildHistoryCache.swift`,
  `GrokBuildFileEventMonitor.swift`, `GrokBuildObservation.swift` and
  `GrokBuildUsageStore.swift`: persistent home-scoped collection, metadata
  revalidation before commit, bounded scan/retry, separate local/quota state,
  recursive file events with debounce and a 15-second scan fallback, 5-minute
  quota cache/15-minute stale policy, coalescing and cancellation. Missing
  CLI/home recovery and late callbacks from a previous home are covered by
  tests. App composition/preferences are connected through
  `GrokIntegrationController`, independently of the active Dock feature.
  Runtime composition verification is tracked separately below. Quota is
  memory-only. The detailed token/model cache
  remains limited to 30 days; durable activity is stored separately below.
- `GrokBuildActivityLedger.swift` and the opt-in `.observedOnly` mode of
  `TokenUsageStreakCalculator`: positive root/turn observations retain hashed
  identity and UTC timestamps, without durable token/model/content details.
  Unknown days do not become inactive or bridge a run; unknown today exposes
  an optional current streak. Existing milestones and earned best are retained
  beyond the detailed cache window. Initial import updates achievements without
  celebrations; timezone changes rebucket activity without replay. Claims are
  persisted before presentation, and ordered cache I/O prevents a cancelled
  generation's late write from racing reconfiguration. The legacy calculator
  mode remains the default for existing providers. Shared streak/detail/roadmap
  UI is connected with an opt-in unknown-current-day presentation for Grok.
  This minimal witness ledger grows with observed turns and shares the 32-MiB
  cache safety cap; exceeding that cap reports a persistence warning rather
  than silently discarding earned history. The bounded long-term/high-volume
  stress verification above now covers 3,650 daily observations and a separate
  109,500-turn history, including disk restart, pruning and quota-independent
  badges. Larger histories are not certified by that test and the 32-MiB
  capacity limit remains explicit.
- `GrokBuildProcessRunner.swift` and `GrokBuildCLIProvider.swift`: direct fixed
  arguments, configured `GROK_HOME`, ACP initialize then `_x.ai/billing`, no
  session creation/load/prompt, denial of reverse requests, bounded output,
  nonblocking writes, timeout/cancellation and dedicated process-group teardown
  using public Darwin `posix_spawn` APIs. Root and inherited-group children are
  tested on normal exit, timeout, cancellation and ACP completion, including
  a child ignoring SIGTERM and an unrelated process that must survive.
  Explicit login/device-code/logout now connect to the authentication controller
  and Settings; see the later auth-flow checkpoint above. Agent startup effects
  audited in unsigned synthetic homes include destructive stale-pool cleanup;
  automatic billing remains blocked. Explicit logout has a separate entry point
  and cannot claim verified sign-out without a status response.
  Daemonized/detached descendants and signed-in or
  configured-home effects remain unverified. Group tests do not prove these
  absent. `proc_listpgrppids` count handling was corrected so small process
  groups receive the bounded SIGTERM grace period before SIGKILL.
- `GrokBuildFoundationTests.swift`, `GrokBuildLiveProbeTests.swift`, and
  `script/test_grok_foundation.sh`: dependency-independent verification using
  the actual production source files. Synthetic fixture checks are not real
  account evidence. Successful opt-in probes save allowlisted evidence in a
  private temporary directory, never raw billing responses or credentials.

### Module manifest checkpoint

This is the implementation/release matrix. The explicit experimental runtime
allowlist is `GrokBuildDashboardManifest` in `GrokBuildSettings.swift`.
The capability dossier below retains source-level semantics; a source-backed
field does not imply its product module is verified.

| V1 module | Current evidence / implementation | Required before enabling |
| --- | --- | --- |
| Tokens and 30-day chart | CLI 1.0.30 real local root: 35,987 tokens on 1 day; 29 days unknown. Cached and forced rereads idempotent. Shared chart connected with explicit missing-day set; fixture presentation and app-composition tests pass. Native fixture QA reached both chart endpoints. Real local Settings preview confirms the September 16 bucket, unknown September 17, and stable totals after two refreshes/restart. | Broader live attribution/coverage (resume/fork/delayed folds), actual Dock interaction and hardware pointer/trackpad behavior. |
| Quota | CLI 1.0.30 signed-out probe passed, but startup deletes synthetic stale pool data; production adapter now fails closed. | Safe official startup route first, then signed-in fixture, plan/window cross-check and detached-descendant cleanup. |
| Settings/auth | Experimental Settings and matching Dock preview connected. Real local preview and preference restart checked. Explicit browser/device login, cancellation, confirmed logout, bounded SwiftTerm output and post-command verification are now wired. CLI 1.0.30 command entry points audited in a disposable unsigned home; command completion never substitutes for verified account status. | Real-account browser/device completion, signed-in logout/post-login quota and configured-home startup/descendant audit; file-picker and complete keyboard/VoiceOver testing. |
| Ship momentum | Shared formula/card connected to eligible today tokens only; unknown remains unavailable, partial is labelled observed. Presentation tests and native appearance matrix pass. Real local preview confirms unavailable momentum on an unknown today. | Actual Dock/live lifecycle verification and complete accessibility review. |
| Streak/badge/roadmap | Coverage-aware calculator, durable ledger and once-only claims implemented and fixture-tested; shared detail/roadmap connected. Fixture UI verifies Back/Escape and once-only notification. Native Settings preview QA scrolled to the final 730-day badge and returned with Escape. Bounded long-term/high-volume retention and disk restart pass; see the 2026-09-17 report and explicit 32-MiB limit. | Real source attribution, transient-banner click, actual Dock and live lifecycle proof. |
| Daily intensity | Shared renderer connected to the same 30-day buckets and explicit unknown-day set. Missing-day markers and Best day are fixture-tested/native-reviewed. Real local preview selects September 16 / 35,987 tokens and leaves unknown days unavailable. | Broader live history and actual Dock/accessibility interaction. |
| Top models | Shared renderer connected to token-ranked Top 3; real sample attributes 35,987 tokens to `grok-4.6-build`, now also verified in the real local Settings preview. Missing model coverage is explicit and exercised by fixture UI. | Broader live multi-model/partial coverage and actual Dock/accessibility interaction. |
| Identity/service link | Neutral experimental identity and official Grok Build status-page link connected, no Operational badge. Native AX destination and public provider-specific page checked on 2026-09-17. | Final identity asset, native browser-launch click and final appearance verification. |

Out of V1: cost chart, lifetime/account-wide tokens, hourly drill-down, Active
work, Share/export, Management API and status-line hook. Credential extraction
and private-endpoint/browser scraping fallbacks remain prohibited. Full fork
tree reconciliation is not attempted: fork/copy/subagent/orphan ledgers are
excluded as separate contributions. Eligible parents contribute only the
ledger actually recorded under their own identity, including any folds it
already contains. Coverage is always partial, never a complete account total.

### Remaining implementation and release blockers

1. **Startup safety blocked:** `initialize` removes test-owned stale pool
   markers with default settings and with `GROK_WORKTREE_AUTO_GC=0`; it also
   creates configuration/docs/logs/session-search index files. No safe
   official read-only startup option has been verified. Do not enable polling,
   patch user config, copy credentials into a scratch home, or substitute a
   private endpoint. Fixtures are in `docs/fixtures/grok-build/1.0.30/`.
   The reviewed source's built-in `read-only` sandbox profile still grants
   write access to Grok home; its name is not evidence that it prevents this
   cleanup. The new 1.0.30 strict/custom runtime audit used homes outside OS
   temp grants and a separate empty working directory. All three sandboxed
   candidates failed to apply their profile and refused startup before ACP;
   the unsandboxed control reached the expected auth error and removed its
   fake stale-pool marker. This environment-specific failure does not prove
   those profiles are universally unsupported, but it establishes no usable
   workaround here. The production safety gate remains closed. [S19] [S20]
2. **Before enabling billing/release:** resolve the startup-safety blocker, then verify billing with
   the user's existing official login and confirm account type, capture its
   sanitized fixture and audit detached children. The user has now reported
   signing in; do not ask for another login merely because sandbox startup
   fails. No account plan or connected quota schema is certified. Login/parse
   success alone is insufficient.
3. Verify the connected preferences/lifecycle and executable/home selection.
   The explicit CLI auth controller is now implemented through the separately
   reviewed login/logout entry points; it does not bypass the ACP safety gate.
   Real-account completion and post-command quota confirmation remain unverified.
   Store unit/integration tests do not substitute for sleep/wake/shutdown tests
   in the actual app composition.
4. Verify the connected shared UI and derived modules without changing Codex,
   Claude Code or Antigravity behavior. Durable activity/calculator fixtures
   pass; fixture Settings/badge routes and native render variants now have
   execution evidence. Actual Dock interaction, full keyboard/VoiceOver,
   transient-banner click and live lifecycle remain separate gates.
5. **App test build and standard launch have passed:** a fresh DerivedData
   resolved the earlier missing Sparkle artifact. Expanded Grok and targeted
   legacy regression checks are detailed below. The standard workflow uses
   `bash script/build_and_run.sh --verify` and normal `.derivedData`; this is
   Debug runtime evidence, not a release-package gate. `Package.resolved` was
   absent at the initial inspection; after the standard build it matches the
   tracked pins again, without a manual dependency edit. The tested resolved
   graph remains SwiftTerm 1.18.0, Sparkle 2.9.6 and swift-argument-parser 1.7.2.
6. Complete UI/accessibility variants, regression suite, existing build/run
   workflow and Developer ID/Hardened Runtime packaged validation. The
   2026-09-17 isolated arm64 Release build and static signature checks above
   pass, but do not cover final packaging, notarization/stapling, Gatekeeper
   acceptance or packaged Grok runtime. Only then remove the release gate;
   no partial-module production release.
7. **Settings color customization is now implemented and verified** as detailed
   in the token-appearance report above. It uses the shared palette, persistence
   and Reset Defaults, applies to bounded token renderers/preview only, and does
   not restart collection or change connection settings. This closes the new
   `AGENTS.md` color-section requirement, not the outstanding full-V1 gates.

### Reproduce the checks

Foundation suite (does not install Grok, read credentials, log in, or change the
user's Grok home):

```sh
bash script/test_grok_foundation.sh
```

Unsigned local probe against an explicitly selected **installed** CLI (creates
a temporary synthetic Grok home and strips inherited authentication environment):

```sh
GROK_PROBE_EXECUTABLE=/absolute/path/to/grok \
  bash script/test_grok_foundation.sh \
  --filter GrokBuildLiveProbeTests.testInstalledCLIReadsSyntheticLocalUsageWithoutAuthentication
```

User-authorized real local history check (no agent, billing, login/logout, or
cache persistence in the user's home; only lineage metadata and `usage`):

```sh
GROK_PROBE_EXECUTABLE=/absolute/path/to/grok \
GROK_PROBE_LOCAL_HOME=/absolute/path/to/user-authorized-grok-home \
  bash script/test_grok_foundation.sh \
  --filter GrokBuildLiveProbeTests.testInstalledCLIReadsAuthorizedRealLocalHistory
```

This test refuses agent commands and strips authentication environment from
its local-only child. It checks both unchanged cached refresh and forced CLI
reread against stable metadata; `forcedRefreshVerified` requires readable roots
and no forced-read coverage failures. Its retained report contains aggregate
coverage/counts, not session IDs, titles, paths or conversations. No history
means a completed scan, not a successful test of real token payloads.

Optional sandbox-candidate audit (not a safe-startup approval): select an
existing test-output parent **outside** OS temporary-directory grants. It
creates and removes uniquely named synthetic home/workspace pairs under that
parent, and changes no existing configuration. `off` is the isolated positive
control only; it must never become a fallback when a profile fails.

```sh
GROK_PROBE_EXECUTABLE=/absolute/path/to/grok \
GROK_PROBE_SANDBOX_PARENT=/absolute/path/to/test-output \
  bash script/test_grok_foundation.sh \
  --filter GrokBuildLiveProbeTests.testInstalledCLISandboxCandidatesInSyntheticHomes
```

Billing probe is **currently safety-blocked in code**, even with these opt-in
variables. The following is the future invocation only after safe startup is
verified and the user signs in with the official CLI and chooses this
account/home (`ACCOUNT_KIND`: `consumer`, `api-key`, `sso`, `other`; the latter
modes may legitimately fail consumer billing). Do not flip the safety gate
just to run the probe:

```sh
GROK_PROBE_EXECUTABLE=/absolute/path/to/grok \
GROK_PROBE_BILLING=1 \
GROK_PROBE_BILLING_HOME=/absolute/path/to/grok-home \
GROK_PROBE_ACCOUNT_KIND=consumer \
  bash script/test_grok_foundation.sh \
  --filter GrokBuildLiveProbeTests.testInstalledCLIAccountBillingWithoutCreatingSession
```

Probe artifacts explicitly record `releaseVerified: false` for billing while
the side-effect/lifecycle/account gates are unresolved. Do not commit
live fixtures without reviewing their allowlisted content. Neither probe sends
a model prompt, creates a session or performs automatic login/logout.

## Recommendation

Use the documented local command as the source boundary for the approved
experimental root-only aggregate; do not ship a narrower prototype as full V1:

```text
grok usage <session-id>
grok usage <session-id> <turn-number>
```

The command exposes persisted token/cost telemetry, but **not an exact account
bill, complete machine-wide activity ledger, or account-wide token history**.
It was introduced in 1.0.14; that release note does not establish that every
field in the current source existed, or behaved identically, in 1.0.14. Gate the
installed version and actual schema before using any field. [S1] [S2] [S3]

Keep three sources separate:

- **Local usage:** retained session/turn snapshots returned by `grok usage`.
  They include inherited history and folded subagent spend, but omit some side
  calls and may lag background completion.
- **Account credits:** the first-party ACP extension `_x.ai/billing` is a
  source-backed candidate, not a verified stable external integration. Its
  history is monetary, not token history.
- **Live session/context:** ACP session usage and status-line output describe
  agent-process state. They are not interchangeable with persisted totals or
  account quota.

Do **not** enable a global today total, 30-day chart, streak, Ship momentum, or
activity export until attribution, deduplication, revisions, and missing-data
handling are proven. “Today's total” is not a safe fallback when cross-session
deduplication is unresolved; session details are.

## Audit corrections

This section supersedes the previous version of this report.

| Previous conclusion | Corrected finding | Consequence |
| --- | --- | --- |
| Ready for limited implementation, including derived daily history. | Per-session data has an official source; correctness of cross-session aggregation remains unproven. | Overall status is Proposed. |
| Billing response uses `subscriptionTier`. | Wire envelope uses `subscription_tier` and `on_demand_enabled`; only nested `config` uses camelCase. The camelCase top-level names belong to a log projection. | Fix the decoder; the isolated Serde probe confirmed this. [S4] |
| Billing history is an available period series. | `BillingPeriodUsage` drops the newer `history[].period`; it keeps only legacy `billingCycle` and cent amounts. | Some rows cannot be assigned a reliable period. [S4] |
| No product breakdown exists. | A backend-shaped source fixture includes `productUsage`, but the CLI's typed projection drops it. | Unsupported through this CLI response, not proven absent upstream. [S4] |
| Turn rows are immutable, exact turn-end events. | A repeated incoming turn can accumulate more usage and replace `endedAt`. The timestamp is generated during persistence. | Treat rows as revisionable snapshots, not event IDs or exact call times. [S3] [S5] |
| Timestamp-plus-counter fingerprints safely deduplicate forks. | A copied prefix and its later revised parent row no longer match; turn numbers also can be renumbered. | Fingerprinting alone does not prove unique spend. [S3] [S6] |
| Excluding all subagents gives complete parent totals. | Background spend folds later; a parent file already flushed may not reflect it until another persistence event. | Excluding children can undercount; including both can overcount. [S5] [S7] |
| Every resume copies history; rewind truncates usage. | Same-session resume can retain the ID and extend totals. Copy/fork paths can copy or truncate; ordinary rewind is not established as truncating usage. | Do not infer refunds or universal copy behavior. [S3] [S6] |
| ACP usage requires a process/session owned by DockMagic and cannot reach a TUI session. | Shared-leader mode can host sessions across clients. Residency in the reachable agent matters, not who created the session. | Cross-client access and non-interference still need runtime verification. [S8] [S9] |
| Status-line commands only run on state changes. | Command mode also supports `refresh_interval`; timer runs reuse the previous state payload. | Timer execution does not itself refresh token/quota data. [S10] |
| No Grok Build-specific status component was established. | An official Grok Build status page exists. | A scoped status link is supported; automated feed parsing is still unverified. [S11] |
| Management API is inherently prohibited. | It is a public, separately authorized team API with a different account/product scope. | Out of scope for this consumer integration, not categorically prohibited. [S12] |
| Selectively decoding `summary.json` means never reading summaries. | File bytes can contain titles/summaries even when the parser discards those keys. | Document transient exposure honestly; do not retain/log content. |
| Missing fields can always be distinguished from zero in command output. | Upstream deserialization defaults missing numeric usage counters to zero before re-serialization. | Output alone can lose original missingness; no universal “zero means observed zero.” [S3] |

## Supported user story

The approved V1 shows **Tokens observed locally** over the last 30 days from
eligible retained/observed root sessions, with unknown gaps, model coverage and
recorded-at timestamps. Account credits remain independent from that local
history. Experimental surfaces are now connected behind the Debug flag; the
implementation/release matrix above is authoritative. Do not claim that local
observations cover every billed call, device, account or Grok product.

Unified shared-pool labeling is justified when
`isUnifiedBillingUser == true`; absence or false must not silently become
“shared allowance.” Account failure must not erase valid local session data.

## Capability dossier

Statuses follow [AI_PROVIDER_FEATURE_CONTRACT.md](AI_PROVIDER_FEATURE_CONTRACT.md).
`supported` below identifies an established source/meaning, not a completed
DockMagic implementation or a successful live-account test. Fixture entries
are **required tests**, unless explicitly marked executed.

For local sources, privacy policy **L** means: fixed CLI arguments; bounded,
ephemeral output; no credential or conversation-log acquisition; retain only
necessary normalized metadata. For ACP, **A** additionally requires a reviewed
agent lifecycle and CLI-owned authentication. Developer ID packaging remains
unverified for both.

| Capability | Status | User value | Source and provenance | Exact fields | Semantics | Conditions | Freshness | Completeness | Privacy and distribution | Evidence | Test fixture |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `identity.provider` | supported | Provider navigation. | Official product identity. | Proposed internal ID `grokBuild`; name `Grok Build`. | Product, not account. | None. | Static. | Identity only. | Bounded brand region; shared design system. | [S1] | Identity/registration. |
| `cli.presence/version` | supported | Setup and compatibility checks. | Official local executable. | Path; `grok --version` output. | Presence is not sign-in. | Discoverable/configured binary; 1.0.14 introduced usage, current fields need schema checks. | Setup/recovery/version change. | Configured search locations only. | L. | [S2], source version. | Missing/old/unknown version. |
| `identity.plan` | unknown | Optional plan label. | First-party ACP candidate. | `subscription_tier`. | Signed-in account tier; not inferred from model. | Compatible billing extension/account. | Separate account refresh. | Optional field. | A. | [S4]; Serde probe executed. | Missing/tier changes; live capture pending. |
| `auth.status/lifecycle` | unknown | Explain account connection. | Agent authentication and billing auth gate. | ACP auth methods/error; no validated dedicated status contract in this dossier. | CLI presence/local history do not prove account auth. | Account/auth-mode verification pending. | Probe/recovery. | Signed-out, expired, API-key and authorization errors must stay distinct. | A; no credential extraction. | [S4] [S13] | Sign-in/out/expiry/recovery; pending. |
| `usage.session.tokens` | supported | Session-level reported totals. | Official local `grok usage <id>`. | `session.inputTokens/outputTokens/totalTokens/modelCalls/turnCount`. | Retained ledger; total=input+output; inherited usage included. | Compatible fields; retained file. | Persisted snapshot, not continuous live stream. | Side calls, background lag, older defaults; no account binding. | L. | [S1] [S3] [S7] | Normal/resume/missing/partial/defaulted fields. |
| `usage.turn.tokens` | supported | Recorded turn details. | Same command; optional turn selector. | `turns[].turnNumber/endedAt` and flattened counters. | Revisionable recorded deltas; timestamp is persistence time. | Compatible schema. | Can be amended on repeated incoming turn. | Not exact per-call time or unique cross-session events. | L. | [S3] [S5] | Amendments, zero-delta write, renamed turn, midnight. |
| `usage.breakdown.cache` | supported | Cache detail for session/turn. | Local normalized usage. | `cachedReadTokens/cacheCreationTokens`. | Included in input; never add again to total. | Backend reports category; missing originals may default to 0. | With snapshot. | Reporting coverage is backend/version dependent. | L. | [S3] [S14] | Reported values, unsupported/defaulted zero. |
| `usage.reasoning` | supported | Reasoning detail. | Local normalized usage. | `reasoningTokens`. | Reported output breakdown; not extra tokens to add. | Model/backend signal needed. | With snapshot. | Zero may lack provenance. | L. | [S3] [S14] | Known positive, missing/defaulted, unknown model. |
| `usage.tool_tokens` | unsupported | Avoid fake tool metrics. | No separate category in researched usage schema. | None. | Tool text can affect model input/output; no independent tool-token counter established. | N/A. | N/A. | Not exposed here. | No content parsing to reconstruct it. | [S3] | Module omitted. |
| `usage.model` | supported | Per-session model distribution. | Local usage. | `modelUsage[modelId]`, `primaryModelId`. | Primary model is selected by model-call count, then total tokens; not necessarily most tokens. | Model map present. | With snapshot. | Side-call exclusions and older missing maps. | L; retain original model ID. | [S3] [S7] | Conflicting call-count/token ranking; missing map. |
| `cost.observed` | supported | Reported ledger cost. | Local usage. | `costUsdTicks/costIsPartial/usageIsIncomplete`. | 10^10 ticks/USD; not subscription credits or account bill. | Positive reported cost; partial UI only with explicit semantics. | With snapshot. | Missing cost is unknown; false partial flag is not proof of cost coverage. | L; financial aggregate. | [S3] [S7] [S14] | Positive/missing/partial/incomplete/nonpositive. |
| `usage.daily.tokens` / today | supported for partial local observations | Experimental 30-day local chart. | Root-only revision ledger over official `grok usage` snapshots. | `endedAt`, minimal lineage and revised counters. | Recorded-at day, not true model-call day or account total. | CLI 1.0.30 local sample and synthetic coverage checks; unknown gaps and exclusions mandatory; production gate remains closed. | File events plus bounded metadata scans; manual-only when monitoring is off. | Fork/copy/subagent/orphan contributions excluded; delayed parent folds may undercount. | L; home-scoped cache. | [S3] [S5] [S6] [S7]; real local report above. | Parser/history/derived suites executed; broader live attribution pending. |
| `usage.hourly` | unknown | Future recorded-at drill-down. | Same proposed derivation. | `endedAt`. | Hourly bucketing is possible but has the same timing/lineage limitations as daily. | Separate product scope and validation. | Same as daily. | No authoritative call-time hourly series. | L. | [S3] [S5] | Midnight/DST/long turn; pending. |
| `usage.lifetime/account_tokens` | unsupported | Avoid misleading account/lifetime totals. | No eligible account-wide source established by local usage or billing. | None. | Local retained/observed aggregate is not lifetime or current-account total. | Do not substitute local sum. | N/A. | Other homes/devices/accounts/deleted sessions absent. | No cloud scraping. | [S3] [S4] | Omission/scope labels. |
| `quota.window` | unknown | Candidate account-credit gauge. | First-party ACP `_x.ai/billing`, not a stable external contract established here. | `config.creditUsagePercent/currentPeriod`; legacy `monthlyLimit/used/billingPeriodStart/billingPeriodEnd`; `isUnifiedBillingUser`. | Used percentage; weekly/monthly only when reported. Shared pool only with evidence. | Compatible authenticated consumer mode; no universal plan/auth coverage proven. | Proposed 5-minute cache; not a provider rate-limit guarantee. | Optional fields/config; no token conversion. | A. | [S4] [S13]; no live response. | Missing/0/100/legacy/unknown period/auth errors. |
| `billing.amounts/history` | unknown | Candidate spend detail, not token chart. | Same ACP projection. | `on_demand_enabled`; `config.onDemandCap/onDemandUsed/prepaidBalance/history[]`; `*.val`. | USD cents; history may have `billingCycle` but loses newer `period`. | Compatible source and usable period attribution. | With account snapshot. | Missing amount is not 0; present `Cent {}` means 0. | A; do not persist by default. | [S4]; Serde probe executed. | Empty Cent, absent amount, undated history. |
| `quota.product_breakdown` | unsupported | Avoid Build-only quota claims. | Current CLI typed projection drops backend `productUsage`. | None after projection. | Does not imply backend/website lacks breakdown. | Different eligible contract required. | N/A. | Not available via this response. | No private endpoint workaround. | [S4] [S15] | Assert field is dropped; executed. |
| `usage.session.live` | unknown | Optional live details. | First-party ACP `_x.ai/session/usage`. | Request `sessionId`; response `usage` as `PromptUsage`. | In-memory ledger; resets in a fresh agent process; not persisted history. | Session resident in reachable agent/shared leader; access behavior unverified. | Request-time. | Scoped ledger, partial cost scrubbed. | A; do not load sessions solely to collect history. | [S8] [S9] | Existing shared session vs standalone, restart; pending. |
| `usage.status_line/context` | supported | Opt-in current-session telemetry, not default history collector. | Documented local command hook. | `context_window.*`, `cost.*`, `session_id`, `trigger`. | Context percentage is not quota; process/live counters differ from persisted history. | Explicit config opt-in and supported version. | State updates plus optional timer replay of last payload. | Current agent-state view only. | L; config conflict/uninstall and broader payload privacy review. | [S10] | Timer replay, missing ledger, resume; pending. |
| `work.active/tasks/goals` | unknown | Optional future modules. | Not established as eligible structured collection in this usage audit. | None selected. | Recent tokens do not prove active work. | Separate research/scope. | N/A. | N/A. | Do not collect task/prompt content. | Deferred, not asserted absent upstream. | Omission. |
| `service.status.link` | supported | Official scoped incident information. | Public Grok Build status page. | `https://status.x.ai/grok-build`. | Provider health, not local auth/CLI health. | Link only in initial scope. | Website controlled. | Automated status feed/parser still unknown. | Public URL. | [S11], opened 2026-09-16. | Correct URL; no invented live badge. |
| `activity.derived` | supported for observed local scope | Streak/badges, Ship momentum and Daily intensity. | Eligible daily buckets plus durable activity witnesses. | Today tokens; verified active dates; retained earned milestones. | DockMagic-derived token activity, not productivity or provider facts. | Coverage-aware unknown-day handling, shared formulas/artwork, Debug experimental gate. | With local observation; calendar rebucketing must not replay celebrations. | Inherits local-source blind spots; initial backfill limited to 30 days. | No conversation or account identifiers in activity ledger. | Executed Grok derived suite and shared-provider regression. | Unknown gaps, backfill, badge retention, claim persistence executed; full UI flow pending. |
| `activity.export` | unsupported in V1 | No export action. | No approved Grok export pipeline. | None. | Existing provider exports do not grant Grok capability. | Separate product scope and verification required. | N/A. | N/A. | No IDs, paths, prompts or account details exported. | Approved V1 exclusions. | Export omitted. |
| `api.team.history` | supported for separate team API scope | Possible future API-team integration. | Official public Management API. | `POST /v1/billing/teams/{team_id}/usage`; request-selected analytics units/time series. | Team API analytics, not established consumer Build token history. | Separate management key with required ACLs and explicit product authorization. | API-defined. | No cross-product equivalence established. | Out of scope here; do not request a key for consumer quota. | [S12] | Separate integration only; none in this report. |
| `private.credential_collection` | prohibited | None. | Credential stores/private web endpoints/browser sessions. | No fields allowed. | Not a permissible fallback. | Never needed for proposed local flow. | N/A. | N/A. | No extraction/proxying; CLI owns auth. | Local provider contract. | Privacy assertions. |

## Persisted usage contract and limits

The following is a **synthetic one-turn example**, not a captured account
payload. Optional cost, model information, and false flags are deliberately
omitted. Both summaries describe the same recorded usage:

```json
{
  "sessionId": "00000000-0000-0000-0000-000000000001",
  "updatedAt": "2026-09-16T08:00:00Z",
  "session": {
    "inputTokens": 1200,
    "outputTokens": 300,
    "cachedReadTokens": 400,
    "cacheCreationTokens": 50,
    "reasoningTokens": 120,
    "totalTokens": 1500,
    "modelCalls": 2,
    "turnCount": 1
  },
  "turns": [{
    "turnNumber": 1,
    "endedAt": "2026-09-16T08:00:00Z",
    "inputTokens": 1200,
    "outputTokens": 300,
    "cachedReadTokens": 400,
    "cacheCreationTokens": 50,
    "reasoningTokens": 120,
    "totalTokens": 1500,
    "modelCalls": 2,
    "turnCount": 1
  }]
}
```

Important decoder and presentation rules:

- `grok usage <id> 3` returns the **whole-session** `session` summary and only
  turn 3 in `turns`. Do not read `session` as turn 3's cost/tokens. [S2]
- Omitted `costIsPartial`/`usageIsIncomplete` decode as false upstream;
  omitted cost remains unknown. False flags do not certify complete account,
  device, background, or backend coverage.
- Missing numeric counters in the stored schema default to zero. By the time
  the CLI emits JSON, original missingness can be lost. For older/unknown
  schemas or backends, do not advertise an unqualified known-zero breakdown.
- Upstream `reported_cost_ticks` filters nonpositive cost to absent. A zero
  cost signal cannot automatically mean free usage. If every call lacks cost,
  `costIsPartial` can still be false. [S7] [S14]
- `modelCalls` counts recorded model calls; persisted `turnCount` counts
  persisted rows. Live `PromptUsage.numTurns` is a different projection.
- The ledger records main-loop calls and folded subagent totals. Its source
  explicitly excludes compaction and other side calls from
  `record_main_loop_call`. “Reported session ledger” is more accurate than
  “all billed usage.” [S7]
- The schema contains no authenticated account ID. A home may retain sessions
  from different sign-ins or restores; model IDs may include custom backends.
  Do not attach the current billing account's identity to all local history.

## Why local daily history remains partial

The upstream files are not a globally unique append-only event log.

1. **Inheritance:** forks/copies can retain a parent prefix. Ordinary resume
   can keep the same session ID and extend persisted totals; do not treat every
   resume as a new copy.
2. **Revision:** `apply_turn_internal` can grow an existing row and replace its
   `endedAt`; a zero-delta repeat can change `updatedAt` without changing the
   row. A colliding inherited turn number can be renumbered.
3. **No stable event ID:** `sessionId + turnNumber` cannot identify an inherited
   event across sessions. Exact whole-row hashes fail after one copy changes.
   For example, a child retains a 100-token row while the parent later revises
   that row to 120: summing unequal fingerprints yields 220, not 120.
4. **Subagents:** parent ledgers fold child spend, but background completion can
   occur after the parent file was persisted. Source control flow permits a
   delayed or absent flush if no later turn persists; this is a source-derived
   risk, **not a reproduced live failure**. Blindly including children can
   overcount; excluding them can undercount. Parent ledger `incomplete == false`
   does not resolve this gap.
5. **Timing:** `endedAt` is assigned with `Utc::now()` during persistence.
   A long turn or later revision can cross a day boundary. Both daily and
   hourly charts would be **recorded-at** views, not exact consumption-time
   analytics.
6. **Truncation/deletion:** the copy path can call `retain_turns_through`.
   This is not evidence that ordinary `/rewind` refunds or deletes spent
   tokens. Source disappearance or truncation must not be interpreted as
   negative spend in a durable observed ledger. [S3] [S5] [S6] [S7]

The approved implementation chooses **durable locally observed history**, not
merely currently retained files: accepted revisions replace prior turns,
abnormal reductions are quarantined, and source deletion does not erase
observations. Detailed token/model data rolls off after 30 days; activity and
earned milestones are separate and retained. Homes, not quota accounts, define
the local namespace.

Discovery inspects `<grok-home>/sessions` and narrowly decodes
`summary.json` lineage fields `info.id`, `parent_session_id`, `forked_at`,
and `session_kind`. These are internal metadata, not a stable public API.
Reading the file exposes its bytes transiently, including discarded summary
fields; it is incorrect to promise that no summary bytes are read. Missing
metadata, unknown kinds, remote restores, unstamped copies and orphan children
must stay ambiguous. The earlier whole-row-fingerprint recipe remains rejected;
the approved V1 uses stable session/turn identities and a root-only eligibility
rule. It does not reconcile complete fork trees or establish account-wide
attribution, and broader real-source cases remain release checks.

## Billing/ACP candidate: correct wire contract

The registered handler name is `x.ai/billing`; ACP custom methods carry an
underscore on the wire, so a raw JSON-RPC client uses `_x.ai/billing`.
Initialization metadata does **not** advertise this method as a dedicated
billing capability. A version/schema probe must handle `MethodNotFound`,
authentication failure, timeout and absent config; do not infer support from
successful `initialize` alone. [S4] [S9] [S13] [S16]

Synthetic result object (not the enclosing JSON-RPC response):

```json
{
  "config": {
    "creditUsagePercent": 42.5,
    "currentPeriod": {
      "type": "USAGE_PERIOD_TYPE_WEEKLY",
      "start": "2026-09-14T00:00:00Z",
      "end": "2026-09-21T00:00:00Z"
    },
    "isUnifiedBillingUser": true,
    "onDemandUsed": {"val": 120},
    "history": [{"onDemandUsed": {"val": 80}}]
  },
  "on_demand_enabled": false,
  "subscription_tier": "Synthetic plan"
}
```

The undated history row is intentional: newer backend-shaped `period` data is
discarded by the current typed projection, as is `productUsage`. The CLI does
not pass through unknown backend fields. `{"config": null}` is also a possible
serialized shape. [S4]

Quota rules:

- Prefer a present, finite `creditUsagePercent`; convert used to remaining
  once, with validated/clamped percentage presentation.
- Only use legacy `used.val / monthlyLimit.val` when both values are present
  and the denominator is positive. `currentPeriod` alone proves no percentage.
- Present `Cent {}` defaults to zero; absent `used` or absent percentage does
  **not**. Do not copy upstream display helpers that default missing quota to 0.
- Keep unknown period type/reset unknown. Never invent a five-hour window.
- `isUnifiedBillingUser == true` establishes shared consumer-pool scope.
  Otherwise use a conservative account-credit label with unknown/legacy scope;
  do not assert either shared usage or Build-only usage without further proof.
- The billing auth gate requires an xAI-authenticated context; it can retrieve
  current-or-expired credentials. The handler alone does not prove guaranteed
  automatic refresh. API-key and Team/Enterprise behavior need separate
  verification; unsupported auth is not automatically signed out. [S13]

For a future isolated probe, `grok agent --no-leader stdio` is a candidate
transport: initialize, request billing, and shut down; no session creation,
session load or model prompt is needed for this handler. **Not executed here.**
Review initialization first: source includes launch-MCP setup, managed
gateway/tool discovery and background refresh work. Starting an agent is not
guaranteed side-effect-free simply because no prompt is sent. Do not add
`--always-approve`, alter the user's shared leader, or stop a process DockMagic
does not own. [S9] [S13]

Conversely, session usage requires a resident session in the reachable agent.
Shared-leader mode means it is too strong to say DockMagic must have created
that session or that an existing TUI session is inherently inaccessible. Whether
a non-invasive cross-client probe is reliable remains unverified. [S8] [S9]

## Status line is an optional alternative, not quota

The official hook supports state-triggered updates and `refresh_interval`
(1–86,400 seconds in the reviewed source). Timer runs replay the last payload;
they do not independently obtain fresh session counters. Current context
percentage measures context pressure, not account allowance. [S10]

Do not use the same decoder semantics for all token fields:

- `context_window.session_input_tokens` is the full input count.
- `context_window.session_usage.input_tokens` is the non-cache component;
  adding `cache_read_input_tokens` and `cache_creation_input_tokens` produces
  full input.
- Persisted `grok usage` `inputTokens` already includes cache categories.
- Live/process cost can reset on resume in a fresh agent; persisted history
  retains earlier usage.

The hook is not selected as the default collector because it requires explicit
configuration, may conflict with an existing status line, and carries extra
metadata such as paths. This is a product/privacy choice, not a claim that the
hook cannot refresh periodically.

## Surface map

All surfaces below are **proposals**, not implemented or visually verified.

- **Settings:** CLI path/version, compatible-source checks, local session
  availability, custom Grok home, explicit recorded-data limitations. Account
  actions wait for a verified auth lifecycle. Keep local and account freshness
  separate.
- **Dock:** no invented percentage or today aggregate. Until quota or daily
  usage passes its gates, use an honest unavailable/setup state; a standalone
  per-session prototype does not yet satisfy a full provider launch.
- **Hover:** identity/status link → quota → daily tokens → continuity/badge →
  Ship momentum → Daily intensity and Top models. No cost, hourly or Active
  work module. Badge detail reuses Back/Escape and the shared roadmap.
- **Export:** explicitly out of V1; do not expose Save/Copy/Share actions.
  All implemented surfaces must follow
  [AI_DASHBOARD_DESIGN_SYSTEM.md](AI_DASHBOARD_DESIGN_SYSTEM.md).

## State and freshness policy

These are proposed DockMagic policies, not upstream polling promises:

- Use file events as invalidation hints, with bounded/coalesced metadata scans
  while the integration and monitoring are enabled, even when another Dock
  feature is selected. A 15-second fallback is a starting hypothesis
  to benchmark, not a verified requirement. Refresh changed sessions only.
- Preserve both source `updatedAt` and collector `observedAt`. Parsing an old
  snapshot successfully does not prove current session activity, complete
  history, or fresh quota. A retained closed-session record can still be valid
  as a historical snapshot.
- Source/read/command failure preserves the last valid scoped snapshot as
  stale. No prior observation is unavailable or a scoped acquisition failure,
  never an invented zero. Unsupported schema is not a provider outage.
- For any future billing prototype, start with a five-minute cache and explicit
  refresh with backoff/coalescing; validate acceptable polling with the actual
  provider contract. Account refresh never updates local-history freshness.
- Sign-out/account changes must not relabel unbound local history as belonging
  to the newly active account. Cancel only DockMagic-owned probes.

## Privacy, security, and distribution

Invoke the configured executable directly with fixed arguments, not through an
interpolated shell command. Bound stdout/stderr, runtime, file size and scan
work; reject unsafe traversal/symlink discovery and revalidate identity. CLI
resolution and concurrent file replacement need tests; a preliminary path check
does not provide a blanket guarantee over the CLI's subsequent reads.

Do not directly acquire credentials, conversation logs, prompts, answers or tool
output. Any lineage parser must discard nonessential fields without logging
raw buffers. File paths and identifiers may be handled internally for discovery
and deduplication; do not display/export them or claim they were never touched.
No broad guarantee is made about internal logging/telemetry or file reads by
the provider CLI itself; audit the actual command lifecycle.

The ACP candidate leaves authentication inside the user's installed CLI. No
private backend request, browser scraping, credential forwarding, model prompt
for telemetry, or automatic user-config modification is allowed.

Ordinary local process/filesystem integration has no identified Mac App
Store-only dependency. Developer ID, Hardened Runtime, process launch, file
access, notarization and lifecycle still need validation on the packaged app;
this audit did not verify them. The reviewed upstream package declares
Apache-2.0. Invoking the installed CLI does not vendor its code; copying code
would require appropriate license/notice review.

## Evidence and executed checks

All source references below are pinned to the reviewed commit; live public
documentation was reviewed on 2026-09-16.

- **Source review:** usage command/schema/persistence/tests, fork-copy path,
  rewind path, subagent ledger/fold path, billing types/handler/auth gate,
  ACP initialization/shared leader, status-line guide and public status/API
  documentation.
- **Executed isolated Serde probe:** Rust stable 1.87.0; serde 1.0.219,
  serde_json 1.0.140, indexmap 2.9.0; `cargo +stable run --offline --quiet`
  exited 0. Build script extracted exact upstream type-declaration blocks,
  not rewritten substitutes, and supplied only the small zero-check helper.
  Harness: `/private/tmp/grok-build-audit.wK0qBR` (temporary audit artifact,
  not a committed DockMagic test).
- **Assertions passed:** snake_case billing envelope; camelCase nested config;
  unknown `productUsage` and history `period` dropped; present empty Cent
  becomes 0; missing percentage remains absent; missing config becomes null;
  missing usage numeric fields become 0; false flags, absent cost and empty
  model maps are omitted.
- **Not executed:** full upstream build/tests, signed-in Grok account handshake,
  model calls, real-history attribution tests, the entire DockMagic test suite,
  Grok UI/accessibility or production-packaged validation. No signed-in billing payload was captured.
  A synthetic schema probe is not live-account evidence.
- **Initial implementation tests (2026-09-16, superseded by expanded suite below):** 34 foundation XCTest cases
  passed against production source via the isolated SwiftPM harness; two live
  probes skipped. Covered schema, missingness, quota windows, revision/resume
  identity, rejected lineage, retained observations, timezone/DST, model
  ranking, bounded metadata discovery and real helper-process output/timeout/
  cancellation including stdin backpressure. This does not establish cleanup
  of Grok-spawned descendants or production filesystem-watch behavior.
- **Initial app-hosted Grok tests:** initial `xcodebuild test` failed during setup on
  the absent cached Sparkle XCFramework. Resolving in place did not repair it;
  running the same project/scheme with fresh DerivedData
  `/private/tmp/dockmagic-grok-build.1hwPNYeD` did: 34 passed, 2 live probes
  skipped. No package version changed. The fresh resolved framework was copied
  into the missing cache location without overwriting existing files.
  `plutil -lint` passed for project membership. Existing unrelated Swift 6
  isolation warnings were left unchanged.
- **Expanded app-hosted suite (2026-09-16):** 70 passed, 2 then-existing live
  probes skipped. The command selected `GrokBuildFoundationTests`,
  `GrokBuildIntegrationTests`, `GrokBuildProcessLifecycleTests` and
  `GrokBuildLiveProbeTests` with normal `.derivedData`. One initial process
  fixture failed because its 300-ms deadline expired before the shell wrote
  its PID file; the fixture now has a 2-second startup budget while the separate
  short-timeout test remains unchanged. The rerun passed. Result bundle:
  `.derivedData/Logs/Test/Test-DockMagic-2026.09.16_15-56-06-+0700.xcresult`
  (use the current Xcode log index if the bundle has been pruned).
- **Installed CLI 1.0.30 probes:** the unsigned-local probe passed first against
  the verified downloaded binary, then against the installed binary. A third
  opt-in test was added for unsigned ACP billing; it passed in about 1.96s,
  returning the exact authentication-required error after initialize/billing.
  The selected live suite now has 2 passed / 1 signed-in probe skipped.
  `docs/fixtures/grok-build/1.0.30/` retains only synthetic usage input and
  allowlisted evidence. No session was created/loaded and no prompt was sent.
  Installation sources: [official installer](https://x.ai/cli/install.sh).
  Process-group semantics: [Apple posix_spawnattr_setpgroup](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/posix_spawnattr_setpgroup.3.html).
- **Earlier combined harness run:** `GROK_PROBE_EXECUTABLE=.../grok swift test`
  using the staged `script/grok-foundation/Package.swift` completed with
  **72 passed / 1 signed-in billing probe skipped / 0 failures** (73 selected).
  This is 70 non-account tests plus the two unsigned installed-CLI probes,
  not 72 live-account checks. Elapsed test time was about 9.25 seconds.
- **Durable continuity continuation:** added 18 tests for legacy baseline,
  unknown gaps, 30-day import, revisioned UTC activity witnesses, durable
  earned best, timezone rebucketing, home separation and no celebration replay.
  Four new store tests cover persisted claims, failed-write retry, concurrent
  refresh/claim and reconfiguration during a blocked atomic write. The last
  test failed against the previous implementation (stale cache restore and
  duplicate claim), then passed after ordered persistence was introduced.
  The expanded harness passed **94 / skipped 1 / failed 0** (95 selected).
- **Startup safety audit (2026-09-16):** actual installed CLI 1.0.30 was run
  through the production transport in two fresh unsigned homes, with synthetic
  live/dead-owner pool markers. `initialize` plus `_x.ai/billing` removed the
  dead-owner pool in both default mode and `GROK_WORKTREE_AUTO_GC=0`, while
  preserving the live-owner marker. It added config, embedded documentation,
  logs, agent metadata and a session-search SQLite index; no session ledger
  was created and no prompt/session request was sent. The initial audit
  incorrectly treated the existence of the `sessions/` index directory as
  session creation; it now checks actual session-record paths. The corrected
  audit repeated successfully and retained only path metadata in
  `docs/fixtures/grok-build/1.0.30/acp-startup-side-effects-report.json`.
  This proves the route is not read-only, not that cleanup is a CLI bug.
  The shared public-source startup path calls stale-pool cleanup independently
  of the newer auto-GC policy. [S17]
- **Process grace-period correction:** Apple libproc's `proc_listpgrppids`
  returns a PID count, not a byte count. A new root-exits/child-flushes-on-TERM
  regression failed before correction, then passed after removing the second
  division by PID size. That flush fixture was timing-sensitive in parallel
  app-hosted execution, so it was replaced with a deterministic real-OS
  two-member process-group inspection test. All seven final process lifecycle
  cases pass in both harnesses; actual detached Grok descendants still require
  separate evidence. [S18]
- **Sandbox-candidate audit:** the additional focused probe completed on
  installed 1.0.30 with each fresh synthetic home outside `/tmp`, `/var/tmp`,
  and macOS per-user temp paths, and `--cwd` pointed at a separate empty
  directory. The unsandboxed control reached `authenticationRequired` and
  deleted its stale-pool marker. `read-only`, `strict`, and custom
  `dockmagic-audit` (`extends = "strict"`, explicit pool `deny`) each refused
  startup with sandbox-application failure; all kept the marker and created
  no session ledger. Diagnostic reruns used only the same fake homes and
  retained allowlisted error categories, never raw terminal output. An early
  custom fixture used JSON's slash escape, which TOML does not accept; that
  fixture was corrected and the final four-case audit repeated. The final
  selected test passed, but **no candidate reached the billing auth gate**;
  do not count this as successful sandboxed ACP. Reviewed metadata is saved in
  `docs/fixtures/grok-build/1.0.30/acp-sandbox-candidates-report.json`. This is
  an environment-specific startup failure, not proof of a universal provider
  defect. No app code, user config or release gate changed in this audit. [S20]
- **Real-home continuation after user login:** one selected local-history
  probe passed, with 0 `usage` invocations because no persisted usage files
  existed. A separate metadata-only count found one summary file. No real
  token, quota, connected account or account type is certified by this result.
  A focused synthetic sandbox rerun also completed and retained the fixed
  sandbox-application error: the Docker socket endpoint is a symlink. Only
  this bounded non-sensitive diagnostic line is retained, not arbitrary CLI
  output. These are focused tests, not a rerun of the full suite. No actual
  account-home billing request was made, and no security mechanism or Docker
  installation was changed.
- **Latest safety-gated harness:** **98 passed / 1 account probe skipped /
  0 failures** (99 selected). New tests establish that billing and sign-out
  launch no process while the startup gate is closed, and local usage remains
  readable. This full run was repeated after the final process-group test
  replacement at 16:46 local time. The passing startup audit is negative
  capability evidence.
- **Safety-gate app-hosted checks:** the parallel run selected 104 tests:
  103 passed and the child-flush fixture described above failed its bounded
  grace deadline. That fixture passed when isolated, but was replaced instead
  of relaxing production process-teardown timing. The final focused lifecycle
  rerun passed **7/7**. Result bundles are
  `/private/tmp/dockmagic-grok-startup-safety-20260916.xcresult` (initial run),
  `/private/tmp/dockmagic-grok-grace-diagnostic-20260916.xcresult` (isolated
  diagnostic), and
  `/private/tmp/dockmagic-grok-process-count-20260916.xcresult` (final seven).
  The entire 104-test selection was not rerun after replacing that fixture.
- **Continuity app-hosted verification:** the first parallel run selected 175
  tests: 173 passed, the opt-in Claude account probe skipped, and one Grok
  cancellation test failed before its synthetic helper had written its PID
  file. Its startup wait is now five seconds, with a separate cancellation
  deadline; production timeout behavior is unchanged. The focused rerun
  passed all **45** tests (33 store/cache, 6 process lifecycle, 6 shared
  streak/momentum formula regressions). Result bundles are
  `/private/tmp/dockmagic-grok-activity-20260916-1620.xcresult` (first run) and
  `/private/tmp/dockmagic-grok-claim-rerun2-20260916.xcresult` (passing rerun).
  These are temporary local artifacts, not committed account evidence.
- **Targeted existing-provider regressions:** 76 passed and the explicitly
  opt-in Claude live-account test skipped across `TokenUsageStreakStoreTests`,
  `ClaudeCodeUsageConnectionTests` and `AntigravityFeatureTests` (77 selected).
  Seven additional Codex quota/token/Ship momentum and existing streak-formula
  tests passed. This is **83 passing regressions**, not the entire test suite
  and not live-account verification of any provider.
- **Latest regression rerun:** 86 passed / 1 opt-in Claude account probe skipped
  (87 selected), across the same three provider/streak suites, seven
  `ProcessResourceTests`, and three Codex quota/history parser tests. No
  existing provider implementation was changed by this Grok continuation.
- **Standard build/run:** `bash script/build_and_run.sh --verify` exited 0
  after `BUILD SUCCEEDED` and opening the rebuilt app from `.derivedData`.
  This was an Apple Development-signed Debug build with runtime enabled,
  **not** a Developer ID/notarized release validation. No Grok UI was exposed.
  This command was rerun successfully after adding the collector/store and
  process-group runner to the app target, and again after adding the durable
  continuity model and ordered persistence on 2026-09-16. It passed again after
  the startup safety gate and PID-count correction, with the existing package
  versions unchanged. Existing unrelated Swift actor-isolation warnings remain.

[S1]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-pager/docs/user-guide/17-sessions.md
[S2]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-pager/src/usage_cmd.rs
[S3]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/usage_file.rs
[S4]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/extensions/billing.rs
[S5]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/persistence.rs
[S6]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/storage/jsonl/copy.rs
[S7]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-chat-state/src/usage.rs
[S8]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/extensions/usage.rs
[S9]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-pager/docs/user-guide/15-agent-mode.md
[S10]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-pager/docs/user-guide/25-status-line.md
[S11]: https://status.x.ai/grok-build
[S12]: https://docs.x.ai/developers/rest-api-reference/management/billing
[S13]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/extensions/auth_gate.rs
[S14]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-sampling-types/src/conversation.rs
[S15]: https://docs.x.ai/grok/faq
[S16]: https://agentclientprotocol.com/protocol/v1/extensibility
[S17]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/worktree_pool.rs
[S18]: https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.c
[S19]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-sandbox/src/paths.rs
[S20]: https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-pager/docs/user-guide/18-sandbox.md
[S21]: https://raw.githubusercontent.com/xai-org/grok-build/main/crates/codegen/xai-grok-sandbox/src/runtime_sockets.rs
[S22]: https://raw.githubusercontent.com/xai-org/grok-build/main/crates/codegen/xai-grok-sandbox/src/runtime_sockets_tests.rs
[S23]: https://x.ai/build/changelog

Additional primary evidence:

- [1.0.14 introduction of usage](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/changelogs/1.0.14.md)
- [Source package version/license](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/Cargo.toml)
- [Public changelog](https://x.ai/build/changelog)
- [Usage revision/resume test cases, inspected not run](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/usage_file_tests.rs)
- [Turn completion and usage flush](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/acp_session_impl/turn.rs)
- [Subagent fold application](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-chat-state/src/actor/mutations.rs)
- [Rewind implementation](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/session/acp_session_impl/rewind.rs)
- [Shared leader](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/leader/mod.rs)
- [Extension wire-name prefix](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/leader/protocol.rs)
- [ACP initialization metadata and startup work](https://github.com/xai-org/grok-build/blob/482711333c7195dc16a272777f86086d615e2afb/crates/codegen/xai-grok-shell/src/agent/mvp_agent/acp_agent.rs)
- [Public status-line documentation](https://docs.x.ai/build/features/status-line)
- [Management key authorization](https://docs.x.ai/developers/management-api-guide)

## Unknowns and rejected approaches

- Released CLI schema compatibility and a sanitized real session payload remain
  unverified; source package 1.0.32 is not release-runtime proof.
- No complete or unique global daily ledger has been established. No
  source-backed workaround justifies inventing today's total.
- Billing extension stability, allowed polling, auth expiry/recovery, plan
  coverage, account identity and agent startup side effects remain open.
- A real provider incident feed/parser has not been validated. The official
  Grok Build page is sufficient for a link, not an invented live status badge.
- Use the documented `grok usage` boundary, not direct `usage.json` decoding
  as the default product contract. Any metadata discovery is a separate narrow
  compatibility/privacy dependency.
- Do not parse `/usage` TUI prose, infer credit percentage from local tokens or
  observed cost, or reinterpret monetary history as token history.
- Management API team analytics are outside this integration's consumer scope.
  Separate user-authorized team support could be researched later; the public
  API itself is not a prohibited source.

## Verification plan

1. **Per-session parser:** retain sanitized fixtures from explicitly tested
   installed versions. Cover normal/empty/missing usage, per-turn selector,
   unknown fields, malformed/oversized output, optional/defaulted categories,
   model ranking and partialness. Do not convert missing evidence into 0.
2. **Collector/lifecycle:** prove bounded scans, custom `GROK_HOME`, safe direct
   process execution, cancellation/timeouts, executable changes, atomic
   replacement, duplicate IDs, symlinks and file read errors. Benchmark scans
   before choosing polling. Capture no content or credentials.
3. **Global-history gate:** test repeated import, inherited prefixes, parent
   revision after fork, resumed process counters, turn renumbering, orphan and
   delayed subagents, deleted/truncated sources, midnight/time-zone/DST,
   multiple homes/accounts and restored sessions. Define exactly which scope
   and completeness claims survive these cases; otherwise keep V1 disabled.
4. **Billing gate:** review startup and protocol framing, then explicitly test
   isolated initialization/billing without prompting. Verify wire keys,
   MethodNotFound, null config, missing percentage versus true 0/100, weekly,
   monthly, legacy, expired/signed-out/API-key and consenting plan cases.
   No auto-top-up mutation or separate management key belongs in this probe.
5. **Store/surfaces:** only implement supported manifest entries; test independent
   local/account states, source versus observation timestamps, stale retention,
   account changes and recovery. If launched as a full provider, complete
   Settings preview, Dock, hover, help, service link and registration.
6. **Release/UI gates:** build/test the implementation; verify production Dock
   preview and all shipped UI in Light, Dark, Increased Contrast, Reduce
   Transparency, Reduce Motion and grayscale; check accessibility, absence of
   out-of-scope export actions, Developer ID execution and third-party notices.

**Decision:** Keep production disabled. Collection, cache and store are
implemented and tested, not the full provider. CLI 1.0.30 unauthenticated
synthetic local usage, one real local root and signed-out ACP are verified,
but real-account quota and the full release gates remain incomplete.
Experimental local UI work is permitted by the later user approval above.
