# Claude Code Usage Limits and Hover Dashboard

**Verified:** August 25, 2026

## Conclusion

DockMagic uses `statusLine`, a local contract documented by Anthropic, instead
of calling an internal OAuth endpoint or reading credentials. This is the
appropriate way for a directly distributed desktop app to retrieve usage
limits:

```text
Claude Code response
  -> statusLine JSON on stdin
  -> bridge extracts only rate_limits
  -> ~/.claude/dockmagic-usage.json
  -> ClaudeCodeUsageStore
  -> Settings + NSDockTile
```

Claude Code also provides `/usage`, but it is an interactive command within a
session. The command documentation describes it as a view of session cost,
plan limits, activity, and plan-specific breakdowns; it does not provide a
stable machine-readable output schema for another app to poll.

## Official contract

Anthropic's status-line documentation lists four fields:

- `rate_limits.five_hour.used_percentage`
- `rate_limits.five_hour.resets_at`
- `rate_limits.seven_day.used_percentage`
- `rate_limits.seven_day.resets_at`

`used_percentage` is the portion used in the range `0...100`; DockMagic displays
the remaining portion as `100 - used_percentage`. `resets_at` is expressed as
Unix epoch seconds.

These fields may be absent. According to the documentation, `rate_limits`
appears for Claude.ai Pro/Max after the first API response; either window may
also be absent independently. DockMagic therefore does not convert missing or
null values into `0% used` or `100% left`.

Claude Code can enforce additional model-family limits, but the documented
status-line contract exposes only the shared five-hour and seven-day windows.
DockMagic shows only fields present in that supported contract; users can run
`/usage` inside Claude Code for the richer interactive breakdown.

Official sources:

- [Claude Code status line](https://code.claude.com/docs/en/statusline)
- [Claude Code commands — `/usage`](https://code.claude.com/docs/en/commands)
- [Claude Code cost and usage](https://code.claude.com/docs/en/costs)
- [Claude Code usage-limit errors](https://code.claude.com/docs/en/errors#usage-limits)

## Hover dashboard

When Claude Code is the active Dock feature and Dock hover is enabled, the
440×304 dashboard mirrors the Codex quota hierarchy without inventing token
history that Claude Code does not publish:

- fixed 5-hour and Weekly rows show remaining percentage and reset time;
- a missing window renders as `Not reported`, never as a full allowance;
- `Next reset` selects the earliest reported reset and shows a countdown;
- `Last sync` shows both snapshot age and the local modification time;
- loading, stale, unavailable, and bridge-not-installed states preserve the
  same panel geometry and provide text plus a monochrome state symbol;
- the footer identifies `Claude Code statusLine` as the source and explains
  that updates arrive after Claude Code emits a new status line.

The dashboard uses neutral semantic surfaces and the shared action/status
roles. The full-color Claude Code logo remains contained in its identity area;
the user-selected Dock ring colors do not leak into dashboard chrome, status,
or progress bars.

## DockMagic bridge

Automatic setup is enabled by default. The first time a user selects Claude
Code as the Dock feature in General, DockMagic installs the bridge and reads
the snapshot automatically. `Settings -> Claude Code` does not show connection
controls or require manual setup. DockMagic:

1. Backs up the existing `statusLine` object.
2. Installs `~/.claude/dockmagic-statusline.sh` and points the user settings to
   the wrapper.
3. The wrapper receives JSON, uses `/usr/bin/plutil` to extract only
   `rate_limits` into a temporary file with private permissions, and then moves
   it atomically into place as the snapshot.
4. If a status-line command already exists, the wrapper runs that command again
   with the original input so its output remains unchanged.
5. When the bridge is removed, DockMagic restores the previous object and
   deletes the script, backup, and snapshot.

The bridge does not cache `cwd`, `session_id`, the transcript path, model,
prompt, or token. It does not call a model or use the network. When
`disableAllHooks` is enabled, Claude Code also disables the status line, so
DockMagic refuses to install the bridge and explains the error.

## Freshness and limitations

- The snapshot changes only when the Claude Code CLI runs the status line,
  including after a new assistant message and other documented status-line
  update triggers.
- Data older than 15 minutes is marked `stale`; it is not presented as live.
- Claude Desktop does not run the CLI status line, so it does not update this
  bridge.
- A project-level `statusLine` can override the user settings. The global bridge
  does not run in that project in this case.
- This is a subscription quota; it does not replace API-key billing or Console
  reporting.
