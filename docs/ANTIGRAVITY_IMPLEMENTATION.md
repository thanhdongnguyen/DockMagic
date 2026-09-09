# Antigravity integration

Antigravity is available in the feature picker, Dock context menu, Settings,
and the Dock hover dashboard. Its colors, display style, quota group, usage
cache, and streak ledger are independent of Codex and Claude Code.

## Use

1. Open Antigravity and sign in. In DockMagic, open Settings → Antigravity.
2. Select **Show in Dock** and choose **Chart** or **Numbers**.
3. Opening Antigravity Settings or selecting it for the Dock prepares its local
   activity connection. The icon at the top-right of Dock preview shows status;
   hover for details or click to connect, retry, or check the connection.
4. Quota group selection is no longer exposed in Settings or the dashboard.
   DockMagic automatically uses the most constrained reported group. Old saved
   selections are cleared so an untouched Gemini pool cannot mask used Claude/GPT
   quota.
5. Enable the existing Dock hover option in General to open the dashboard.
   The capture menu saves or copies a PNG and opens the macOS sharing picker.

The bridge's disconnect operation restores the previous status-line configuration and removes
only DockMagic's unchanged hook group. It keeps observed history. Desktop quota
continues to work while Antigravity is running.

## Data and compatibility

| Surface | Data source and behavior |
| --- | --- |
| Quota | Current user's loopback language server; current quota summary with legacy model quota fallback. A missing fraction remains unavailable. |
| Windows | Five-hour/weekly labels are used only when explicitly identified. Older IDEs show `Model quota` and `Window not reported`. |
| Grouping | Gemini and Claude/GPT pools; automatic chooses the lowest reported remaining fraction. Legacy model rows are represented by the most constrained row in the family. |
| Tokens and top models | Local generator usage metadata, transcript token metadata, or positive deltas from observed CLI session counters. Sources are deduplicated per session. History is explicitly partial and limited to the last 30 calendar days. |
| Cost | Only native reported USD amounts. No pricing table or estimated subscription cost. Current installed desktop version does not report this field. |
| Active work | Local trajectory status and observational hooks. Idle/completed work and events older than 30 minutes disappear. Prompt text, tool arguments, and answers are excluded. |
| Streak and Ship momentum | Existing shared components, driven by observed Antigravity token usage and a separate `antigravity` streak ledger. No retroactive streaks inferred from unavailable history. |
| Goals | Unavailable when Antigravity does not report them. No fabricated goal count. |
| Recovery | Thirty-second polling, debounced local file events, coalesced refresh, cancellation on stop, last-known cache, and refresh after wake/reconnection. |

Antigravity Desktop 2.12.2 omits `chatStartMetadata.createdAt` for new generator
usage. When the reported conversation or generating turn starts and ends on the
same local calendar day, DockMagic attributes its real token counters to that day
and records `date_precision: day`. Previously recorded days remain stable when a
conversation continues later. Ambiguous multi-day history stays unassigned;
polling time is never substituted for usage time. `responseModel` supplies the
actual model name when the numeric model enum is a placeholder. History caches
carry a parser version so an old empty parse is backfilled after an upgrade.
Only generator metadata is requested, with `includeMessages: false`.

The loopback endpoints are a compatibility adapter, not a stable public API.
Unsupported responses retain a last-known snapshot with a visible stale state;
without a snapshot the UI provides an unavailable state and recovery guidance.

## Local files and privacy

- CLI configuration: `~/.gemini/antigravity-cli/settings.json`.
- Observational hooks: `~/.gemini/config/hooks.json`, owned group
  `dockmagic-antigravity`. No permission-gating `PreToolUse` hook is installed.
- Private bridge and sanitized observations:
  `~/.gemini/dockmagic-antigravity/` (directories `0700`, files `0600`).
- Snapshot: `~/Library/Application Support/DockMagic/antigravity-usage.json`.
- Recent observations and RPC metadata are retained for at most 32 days, with
  limits on session and record counts. All displayed history is marked partial.

Existing status-line commands receive their original stdin. Existing unrelated
settings and hooks are preserved. Malformed settings are never overwritten;
external changes to DockMagic's configuration produce a conflict instead of
silently replacing them. Uninstall preserves an externally replaced status line.

CSRF credentials remain in memory and are sent only to `127.0.0.1`. The local
self-signed certificate exception applies only to that address, and redirects
are refused. DockMagic does not read Google OAuth credentials, request model
responses, or persist prompts, answers, headers, tool arguments, or conversation
titles. The full-color Antigravity logo is confined to the identity region. It uses
the transparent PNG from the [official press assets](https://antigravity.google/press)
and preserves its original colors in both Light and Dark appearances.

## Verification

Usage fix on 2026-09-09: all 20 Antigravity tests passed. Against the running
Desktop 2.12.2 app, the repaired cache contained 219,583 tokens for September 9
(Asia/Ho_Chi_Minh), attributed to `claude-opus-4-6-thinking`. Automatic selection
chose the Claude/GPT weekly pool at 31.0612% remaining; the running Dock preview
displayed 31%. Repeated refresh preserved the token total without duplication.
The new regressions cover hidden legacy selection, missing generator timestamps,
local-day boundaries, resumed conversations, stable historical dates, and parser
cache migration. No trajectory content was needed for the fix.

Settings simplification on 2026-09-09: all 16 Antigravity tests passed, including
automatic connection setup, retry after a failed check, preservation of the active
Dock feature, and unchanged custom configuration on recheck. The connection icon
was inspected in Light, Dark, Increased Contrast, Reduce Transparency, and
grayscale renders; native Settings controls and the connection action were also
checked in the running app in Light and Dark. ImageRenderer does not render native
segmented controls or sliders, so its Settings fixtures cover the SwiftUI regions.

The focused suite covers quota formats, grouping, missing/invalid fields,
same-user process discovery, metadata deduplication, bridge install/restore,
external config edits, sanitization, cumulative counter resets/model changes,
stale active work, cached history, cancellation/coalescing, recovery, independent
preferences/streaks, and nonblank PNG export.

Visual fixtures cover Light, Dark, Increased Contrast, Reduce Transparency,
grayscale, missing cost, stale/unavailable state, and Dock Chart/Numbers at
32/48/64/128 pt. They are generated in
`/private/tmp/dockmagic-antigravity-qa/` by
`AntigravityFeatureTests.testRenderDashboardAndDockAppearanceMatrix`.
The live card and 4× PNG use the same content and card layout.

Validation on 2026-09-08: all 270 unit tests passed with parallel testing
disabled. Fifteen Antigravity tests passed again after the final bridge and
small-Dock refinements; the existing Codex/Claude numeric-Dock regressions also
passed. `script/build_and_run.sh --verify` built and launched successfully.
The two executable-locator fixtures now ignore real Homebrew installations on
the test host. QA images are also copied to `.derivedData/antigravity-qa/`.

On 2026-09-08, the local adapter read real quota from Antigravity.app 1.23.2 on
macOS 26.2. Settings displayed the quota, updated the selected group from the
dashboard, switched Chart/Numbers, and installed the activity integration.
Both legacy model quota and the server's newer weekly bucket were observed.
Preferences survived relaunch. The native capture menu and Antigravity save
panel were exercised; PNG pixels and file writing are verified by automated
capture tests. Native Dock inspection through the automation tool timed out,
so hover routing relies on the shared panel integration and render tests.
The account's available local conversation metadata was outside the 30-day
window, so the live recent-token chart correctly showed zero rather than
fabricated activity. Lifecycle and usage with active sessions are fixture-tested.

## Sources

- [Official CLI status line](https://antigravity.google/docs/cli/statusline/)
- [Official lifecycle hooks](https://antigravity.google/docs/hooks/)
- [Official IDE hooks](https://antigravity.google/docs/ide/hooks/)
- [Local quota protocol reference](https://github.com/steipete/CodexBar/blob/main/docs/antigravity.md)
- [Generator metadata schema reference](https://github.com/getagentseal/codeburn/blob/main/src/providers/antigravity.ts)
