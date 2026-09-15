# Claude Code usage and local telemetry

**Verified:** September 12, 2026

## Architecture

DockMagic intentionally separates subscription quota from local activity:

```text
claude auth status --json ─── login state, auth method, provider
interactive Claude PTY ────── /usage → 5-hour + weekly all-models quota
Claude lifecycle hooks ────── realtime session, tool, subagent, task state
~/.claude/projects/**/*.jsonl ─ token history, models, tasks, goals
                         │
                         ▼
             ClaudeCodeUsageStore
                         │
                         ▼
          Settings + Dock tile + hover dashboard
```

The quota worker runs the user's resolved, unmodified Claude executable as:

```text
claude --safe-mode --ax-screen-reader --no-chrome
```

It uses a local Unix PTY, sends `/usage` after the prompt is ready, parses
`Current session` and `Current week (all models)`, then sends Escape. The PTY
stays alive between captures and refreshes every 60 seconds while the user is
authenticated. `claude -p "/usage"` is not used because print mode reports the
headless session rather than the user's subscription limits.

## Authentication and connection state

DockMagic executes the absolute resolved Claude binary directly, without a
shell, using `claude auth status --json`. `loggedIn: true` means the CLI has a
credential; it does not by itself mean quota is available. Settings reports:

- **Signed out** when `loggedIn` is false;
- **Signed in / loading quota** after auth succeeds but before `/usage` parses;
- **Connected** only after both 5-hour and weekly all-models quota parse;
- **Quota unavailable** for API/cloud-provider billing or a fresh `/usage`
  failure without a previous snapshot;
- **Last known** when a previous quota snapshot exists and the next capture
  fails.

The visible Settings terminal runs only the fixed command
`claude auth login --claudeai`. It is independent from the hidden quota PTY and
does not expose a general-purpose shell. The fallback `.command` file contains
only the absolute Claude path and those fixed arguments.

Settings keeps the normal connected state to one compact row: title, connection
state, last-update time, Refresh, and a More menu. **Sign Out** lives in that
menu and runs the resolved binary directly as `claude auth logout`, without a
shell. Signing out stops the quota PTY and removes the in-memory 5-hour/weekly
snapshot; local JSONL history, activity hooks, tasks, goals, and streak data are
not deleted.

## Quota capture lifecycle

- Claude Code 2.1.181 or later is required for `--ax-screen-reader`.
- The worker fixes `TERM=xterm-256color`, `LANG=en_US.UTF-8`,
  `LC_ALL=en_US.UTF-8`, and `CLAUDE_CODE_SKIP_PROMPT_HISTORY=1`.
- Its working directory is a neutral DockMagic directory under the system
  temporary directory, never the user's current repository. If Claude asks
  for workspace trust, DockMagic accepts it only when the prompt names this
  private app-owned directory.
- Only one `/usage` capture can run at a time; manual refreshes coalesce.
- Claude can first paint cached quota and then redraw only the changed rows.
  DockMagic waits for the completed redraw and prefers its final all-model
  weekly value instead of publishing the cached percentage.
- A capture times out after 15 seconds. DockMagic restarts the PTY once, then
  keeps the last snapshot as stale and waits for the next 60-second cycle.
- Sign-out, a changed executable, app shutdown, sleep recovery, or cancellation
  stops the child process with interrupt followed by terminate after a grace
  period.
- Model-specific weekly sections are ignored. Percentages are clamped to
  0–100. Unrecognized reset text produces `resetsAt = nil`, not zero quota.
- Unrecognized section structure is reported as “Claude output format
  changed”; it never becomes 0% usage.

The worker retains a bounded in-memory raw PTY buffer below 256 KB and never
writes raw terminal output to logs, analytics, or files. Persisted quota data
contains only used percentage, reset time, CLI version, and capture time.

## Local activity remains separate

Lifecycle hooks and local JSONL history continue to provide token history,
observed cost, active tasks, goals, models, and streak data. Activity filesystem
events trigger only a telemetry refresh; they never issue an additional
`/usage` command. No 5-hour or weekly value is accepted from the retired
statusLine snapshot.

DockMagic no longer installs its statusLine bridge. On migration it removes
only a bridge carrying DockMagic's ownership marker and restores the previous
user command through the existing conservative uninstall path. Activity hooks
are left untouched. A cleanup failure is visible in Settings but does not block
the PTY collector.

## Privacy and distribution

Everything remains local to the Mac. DockMagic does not read, store, proxy, or
mediate Claude credentials. The user signs in through Anthropic's unmodified
Claude Code binary. The app reads only authentication metadata and the quota
text rendered by `/usage`.

DockMagic is distributed with Developer ID signing, Hardened Runtime,
notarization, and stapling. App Sandbox remains disabled because SwiftTerm's
local PTY must launch the installed Claude child process. SwiftTerm 1.19.0 is
linked under the MIT License; see `THIRD_PARTY_NOTICES.md`.

Before broad release, confirm the local-login flow with Anthropic/legal.
Anthropic's documented exception covers an end user signing in to an
unmodified Claude Code binary; DockMagic must not turn this into hosted login
or credential intermediation.

## Primary sources

- [Claude Code slash commands](https://code.claude.com/docs/en/commands)
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Claude Code legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
