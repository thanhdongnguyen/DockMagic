# Claude Code Local Telemetry Dashboard

**Verified:** August 28, 2026

## Architecture

DockMagic uses Claude Code's documented local surfaces rather than private
OAuth endpoints or terminal scraping:

```text
Claude native statusLine ─────── quota, model, cost, context, session
Claude native subagentStatusLine ─ visible subagent/task state
~/.claude/projects/**/*.jsonl ─── timestamps, model token usage, tasks, goals
                    │
                    ▼
        ClaudeCodeLocalTelemetryReader
                    │
                    ▼
        ClaudeCodeUsageStore → Dock tile + 440×760 hover dashboard
```

`claude-agent-acp` is not a passive attachment API for unrelated Claude CLI
sessions. It starts and owns Agent SDK sessions. DockMagic therefore uses the
same underlying Claude native data sources directly. This keeps existing CLI
sessions observable without launching duplicate paid model turns.

## Real fields used

From `statusLine` JSON:

- `rate_limits.five_hour` and `rate_limits.seven_day`: consumed percentage and
  reset epoch;
- `model.id` and `model.display_name`;
- `cost.total_cost_usd`, duration, API duration, and changed-line totals;
- `context_window`: total input/output, window size, percentages, and current
  input/output/cache-read/cache-creation token counts;
- `session_id`, optional `session_name`, `agent.name`, and Claude Code version.

From `subagentStatusLine` JSON:

- visible task `id`, `name`, `type`, `status`, description, label, start time,
  token count/samples, and last tool when present.

From local Claude transcripts:

- assistant record timestamp, UUID, session ID, model ID, and the four usage
  counters (`input_tokens`, `output_tokens`, cache read, cache creation);
- native task lifecycle system events;
- native `active_goal` condition, iterations, reason, timing, budget, and state
  when the installed runtime emits them.

DockMagic ignores synthetic model records and deduplicates assistant UUIDs.
The 30-day chart and model ranking include input, output, cache-read, and
cache-creation tokens because all four are actual counters reported by Claude.

## Cost semantics

DockMagic never applies a hard-coded model price. Cost is shown only when
Claude's native `cost.total_cost_usd` field is present. The status-line bridge
keeps the latest cumulative snapshot per observed session, so the dashboard can
sum observed session totals by the day each session was last observed. A cost
is attributed to a model only when local transcript evidence shows that the
whole session used exactly one model; mixed-model sessions remain unattributed
instead of being assigned to the last model. The dashboard labels these values
`observed est.` and `partial`: sessions that ran before installation, sessions
outside the observed snapshot set, mixed-model sessions, or environments where
Claude omits cost are not silently reconstructed.

## Ship momentum

Ship momentum uses the same DockMagic formula as the Codex dashboard. It
compares the latest seven calendar days with the prior seven:

1. compute the current share of the two-week token total;
2. compute the current share of the two-week root-session count;
3. average those two shares and scale to `0...100`;
4. map the score to Spark, Builder, Maker, Shipper, Accelerator, or Vanguard.

It is an activity trend, not a productivity or quality rating. Claude local
session counts are marked partial because deleted, moved, or unavailable
transcripts cannot be counted.

## Bridge lifecycle

When Claude Code is selected, DockMagic:

1. backs up both existing `statusLine` and `subagentStatusLine` settings;
2. installs two executable wrappers under `~/.claude/`;
3. chains the user's original commands with the original JSON stdin unchanged;
4. atomically writes global and per-session snapshots with `0600` file
   permissions inside `0700` directories;
5. restores both original settings and removes only DockMagic-owned files on
   uninstall.

The wrappers do not call a model and do not use the network. `disableAllHooks`
and workspace trust also gate status-line execution, so a missing first
snapshot is reported as unavailable rather than guessed.

## Privacy boundary

Everything described here remains on the Mac. The raw documented status-line
payload can contain local paths such as `cwd` and `transcript_path`; snapshots
are therefore private files. The transcript reader parses JSON records but does
not consume user prompt text, assistant answer text, thinking, or tool output.
It reads only telemetry fields and explicit task descriptions / active-goal
objectives needed for the Active work section. DockMagic never reads Claude
OAuth credentials.

## Freshness and limitations

- Status and subagent snapshots update only when Claude Code invokes the
  configured commands. A project-level override can prevent the global bridge
  from running.
- Visible subagent rows are treated as live for five minutes after their last
  native observation; terminal task events remove completed work.
- The local history window is 30 days for tokens/models and 14 days for Ship
  momentum. Files older than 120 days or larger than 64 MiB are skipped.
- Claude Desktop does not emit Claude Code status-line input.
- Subscription quota and native session cost are different measurements; the
  dashboard labels each independently.
- Native `statusLine` does not publish the final SDK `stop_reason`, structured
  authentication/quota/context errors, recovery actions, or a subagent
  transcript. DockMagic therefore does not invent these fields. It shows local
  bridge/stale/unavailable state and active task metadata only.
- `claude-agent-acp` can observe richer result and task events for Agent SDK
  sessions that it starts and owns, but it cannot passively attach to unrelated
  native Claude CLI sessions. DockMagic intentionally does not launch duplicate
  paid turns merely to obtain those events.

## Primary sources

- [Claude Code status lines and subagent status lines](https://code.claude.com/docs/en/statusline)
- [Claude Code commands](https://code.claude.com/docs/en/commands)
- [Claude Code cost and usage](https://code.claude.com/docs/en/costs)
- [`claude-agent-acp` source](https://github.com/agentclientprotocol/claude-agent-acp)
- [`claude-agent-acp` native goal mapping](https://github.com/agentclientprotocol/claude-agent-acp/blob/main/src/goal-extension.ts)
