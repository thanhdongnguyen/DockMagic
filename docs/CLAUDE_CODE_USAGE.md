# Claude Code Local Telemetry Dashboard

**Verified:** August 28, 2026

## Architecture

DockMagic uses Claude Code's documented local surfaces rather than private
OAuth endpoints or terminal scraping:

```text
Claude native statusLine ─────── quota, model, cost, context, session
Claude lifecycle hooks ────────── realtime session, tool, subagent, task state
~/.claude/projects/**/*.jsonl ─── timestamps, model token usage, tasks, goals
                    │
                    ▼
        ClaudeCodeLocalTelemetryReader
                    │
                    ▼
        ClaudeCodeUsageStore → Dock tile + 440×740 hover dashboard
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

From Claude Code lifecycle hook JSON:

- session start/end, prompt submission, stop, permission, and notification
  events;
- tool start/success/failure and the documented tool name;
- subagent start/stop and teammate idle events;
- native task creation/completion, task ID, and task subject.

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
uses only token activity from the current local calendar day and resets on the
next day:

1. `0..<10M` tokens maps linearly to score `0...9` and Starter;
2. `10M..<50M` maps to `10...29` and Builder;
3. `50M..<200M` maps to `30...49` and Creator;
4. `200M..<500M` maps to `50...69` and Shipper;
5. `500M...1B` maps to `70...89` and Shipmaster;
6. more than `1B` maps to score `100` and Legend.

Claude's daily total includes input, output, cache-read, and cache-creation
tokens from non-synthetic assistant usage records in local transcripts. Root
session and task counts do not contribute. It is an activity indicator, not a
productivity or quality rating.

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

## Realtime Active work hooks

Active work is opt-in. Until its event integration is present, the dashboard
shows **Enable realtime tracking**. Clicking it merges one DockMagic-owned,
asynchronous command handler into every supported Claude lifecycle event. It
does not replace, reorder, or rewrite handlers owned by other tools. Repeated
installation is idempotent, and uninstall removes only DockMagic's handler.

The handler stores a bounded set of at most 500 small event records under
`~/.claude/dockmagic-activity-events`. A filesystem event monitor refreshes the
store after a 75 ms debounce; the normal 15-second poll remains as a fallback.
Session end, task completion, and subagent stop events remove the corresponding
work from the active set.

## Privacy boundary

Everything described here remains on the Mac. The raw documented status-line
payload can contain local paths such as `cwd` and `transcript_path`; snapshots
are therefore private files. The transcript reader parses JSON records but does
not consume user prompt text, assistant answer text, thinking, or tool output.
It reads only telemetry fields and explicit task descriptions / active-goal
objectives needed for the Active work section. DockMagic never reads Claude
OAuth credentials.

Activity-hook payloads are reduced before persistence. DockMagic keeps only the
event name, generated observation time, sanitized session/agent/task IDs, task
subject, agent type, tool name, notification type, and teammate name. Prompt
text, transcript paths, working directories, tool inputs/results, assistant
responses, and hook error payloads are never written to the activity-event
directory. Files use `0600`; the containing directory uses `0700`.

## Freshness and limitations

- Status snapshots and Active work events update only when Claude Code invokes
  the configured commands. A project-level override can prevent the global
  integration from running.
- Hook-backed active rows expire after 30 minutes without a lifecycle event;
  terminal task, subagent, and session events remove completed work sooner.
- The local history window is 30 days for tokens/models. Ship momentum uses
  only today's bucket. Files older than 120 days or larger than 64 MiB are
  skipped.
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
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code commands](https://code.claude.com/docs/en/commands)
- [Claude Code cost and usage](https://code.claude.com/docs/en/costs)
- [`claude-agent-acp` source](https://github.com/agentclientprotocol/claude-agent-acp)
- [`claude-agent-acp` native goal mapping](https://github.com/agentclientprotocol/claude-agent-acp/blob/main/src/goal-extension.ts)
