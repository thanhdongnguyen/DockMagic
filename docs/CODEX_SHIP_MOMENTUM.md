# Codex Ship Momentum

## Product decision

The gauge below **Daily tokens** is a self-relative activity trend, not a
productivity score or a global percentile. It answers one narrow question:

> Is the user's Codex-assisted work cadence increasing, holding steady, or
> cooling down compared with the previous seven days?

This framing is intentional. The SPACE research warns that developer
productivity cannot be represented by one activity metric, while DORA defines
delivery throughput using actual change flow and deployments. DockMagic does
not currently observe completions, commits, releases, quality, or outcomes, so
the UI uses **Ship momentum** instead of claiming to measure productivity or
software delivery performance.

Research references:

- [OpenAI Codex app-server protocol](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)
- [The SPACE of Developer Productivity](https://www.microsoft.com/en-us/research/publication/the-space-of-developer-productivity-theres-more-to-it-than-you-think/)
- [DORA software delivery performance metrics](https://dora.dev/guides/dora-metrics/)

## Supported local data

DockMagic continues to launch the user's installed `codex app-server --stdio`.
The same initialized connection requests:

- `account/usage/read` for account token-activity summary and daily buckets;
- `thread/list` for non-archived interactive threads;
- `thread/list` for archived interactive threads.

OpenAI documents a thread as a conversation between a user and Codex. Codex
Desktop presents these conversations as tasks, so DockMagic counts root
threads as task starts. The two list calls use `created_at` descending,
`useStateDbOnly: true`, and a 500-item page. Archived and non-archived results
are combined so archiving a task does not remove it from the weekly count.

Spawned sub-agent threads have `parentThreadId` and are excluded. Ephemeral
threads are also excluded. The app reads only timestamps and relationship
metadata needed for the aggregate; it does not display or persist task titles,
prompts, turns, repository paths, or credentials.

If a page has a continuation cursor and its oldest returned task is still
inside the 14-day comparison window, the count is marked partial and displayed
with a trailing `+`. Older Codex versions that do not support either required
surface keep quota and token history working while the gauge shows an
unavailable state.

## Time windows and score

Both signals use local calendar days so they align with Codex's daily token
buckets:

- current window: today plus the preceding six calendar days;
- comparison window: the seven calendar days immediately before that.

For each signal, DockMagic computes the current period's share of the combined
14-day activity:

```text
token share = current tokens / (current tokens + previous tokens)
task share  = current tasks  / (current tasks  + previous tasks)

Ship momentum = round(100 × (token share + task share) / 2)
```

The gauge requires a non-zero 14-day total for both signals; otherwise it shows
the unavailable state instead of manufacturing a score from only one input.
Each signal receives equal weight. For matching weeks the gauge reads 50.
The score advances through six ranks. Thresholds are lower-bound inclusive;
the final rank includes 100:

- `0..<10`: Spark
- `10..<30`: Builder
- `30..<50`: Maker
- `50..<70`: Shipper
- `70..<90`: Accelerator
- `90...100`: Vanguard

The visible rank ladder shows only these names. Numeric thresholds remain an
implementation rule rather than additional dashboard copy.

The formula is deliberately self-relative. It has no universal target, team
benchmark, or invented percentile. More tokens are treated as activity, not as
quality or efficiency.

## Visual and accessibility contract

- One solid action accent fills the completed arc; the remaining track,
  surface, border, and needle use neutral semantic roles.
- No gradient, colored glow, traffic-light band, or feature-local palette is
  introduced.
- The needle, numeric score, ascending rank steps, active rank name, task count,
  and token total preserve meaning without color.
- The current step is the only accented rank. Completed and future steps use
  neutral weight and position instead of introducing a league-color palette.
- Help and accessibility copy state that the gauge is an activity trend rather
  than a productivity rating.
- The Codex hover panel expands vertically only for Codex. Claude Code and the
  other feature dashboards keep their existing compact size.

## Known limitation

A task start is not proof that work shipped. A future outcome-based version
would need an explicit supported signal such as completed tasks, merged
changes, release frequency, or change lead time. Until then, the current gauge
must remain named and described as momentum.
