# Codex Ship Momentum

## Product decision

The gauge below **Daily tokens** is a daily token-activity indicator, not a
productivity score or a global percentile. It answers one narrow question:

> How much Codex token activity has the user accumulated today?

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

## Supported data

DockMagic continues to launch the user's installed `codex app-server --stdio`.
The initialized connection requests `account/usage/read` for account token
activity and daily buckets. The Ship momentum score uses only the bucket for
the current local calendar day. Some Codex versions publish only completed days
in the aggregate response. In that case, DockMagic fills today from local
`token_count` session metadata. If the aggregate already contains today, its
official bucket wins; the two sources are never added together.

Other dashboard features can still request thread metadata for model-usage
attribution. Thread, task, and sub-agent counts do not contribute to Ship
momentum.

## Daily score

The score resets by construction at the start of each local calendar day. The
evaluation uses the current local date rather than the snapshot date, so a
stale snapshot cannot carry yesterday's score into today. It does not compare
today with prior days. When token history is available but today's bucket is
empty, the score is `0`.

Each token band maps to the existing score band and rank. Within levels 1–5,
integer arithmetic increases the score linearly with today's token total:

| Daily tokens | Score | Rank |
| --- | ---: | --- |
| `0..<10M` | `0...9` | Starter |
| `10M..<50M` | `10...29` | Builder |
| `50M..<200M` | `30...49` | Creator |
| `200M..<500M` | `50...69` | Shipper |
| `500M...1B` | `70...89` | Shipmaster |
| `>1B` | `100` | Legend |

For a bounded level:

```text
score = score floor
      + floor(
          (today tokens - token floor)
          × (score ceiling - score floor)
          / (token ceiling - token floor)
        )
```

`1B` remains in level 5. Any value strictly above `1B` enters level 6 and
receives the maximum score. Negative source values are clamped to zero. If the
daily token-usage surface itself is unavailable, the gauge shows unavailable.

The formula has no universal target, team benchmark, or invented percentile.
More tokens are treated as activity, not as quality or efficiency.

## Visual and accessibility contract

- The shared **Living Flame Meter** is used by both Codex and Claude Code.
  Codex uses its action accent and Claude Code uses its existing usage accent;
  the gauge geometry, score, rank, and accessibility behavior stay identical.
- One solid provider accent fills the completed arc and flame silhouette. The
  remaining track, surface, outline, and score use neutral semantic roles.
- No gradient, colored glow, traffic-light band, or feature-local palette is
  introduced.
- Flame energy rises monotonically from Starter through Legend: crest count,
  crest height, line weight, endpoint pulse, motion speed, rank-entry burst,
  and (at the upper ranks) echo contour and embers all increase. Legend has the
  strongest silhouette with eleven crests and seven drifting embers.
- The numeric score, flame silhouette, endpoint ring, ascending rank steps,
  active rank name, and today's token total preserve meaning without color.
- The current step is the only accented rank. Completed and future steps use
  neutral weight and position instead of introducing a league-color palette.
- While visible, the vector renderer refreshes at up to 60 fps. Starter,
  Builder, and Creator breathe in place; Shipper and Shipmaster add clearly
  directional flame travel; Legend adds surge pulses, an echo contour, and
  drifting embers. A score change animates the fill and a rank change triggers
  a short burst. The score is authoritative when resolving the animation tier,
  so a live update cannot retain a stale rank profile. With Reduce Motion
  enabled, all continuous motion, pulsing, ember drift, and entry bursts stop
  on a deterministic final silhouette.
- Help and accessibility copy state that the gauge uses today's tokens, resets
  daily, and is not a productivity rating.
- The gauge is drawn as scalable SwiftUI vector geometry, so it remains sharp
  at both dashboard sizes and does not require a raster asset.

## Known limitation

Token volume is not proof that work shipped and does not measure quality or
efficiency. A future outcome-based version would need an explicit supported
signal such as completed tasks, merged changes, release frequency, or change
lead time. Until then, the current gauge must remain named and described as
momentum.
