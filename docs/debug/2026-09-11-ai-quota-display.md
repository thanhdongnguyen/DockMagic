# AI quota display — live investigation, 11 September 2026

## Evidence from this Mac

- **Codex:** the account usage tool returned the aggregate `codex` bucket with
  a 10,080-minute primary window, 61% consumed and no secondary window. A
  separate Spark model bucket still had a 300-minute window; it must not be
  substituted for the aggregate account. DockMagic's live preview subsequently
  showed 38%, then 37% weekly remaining as usage advanced. No 5-hour aggregate exists.
- **Claude Code:** `~/.claude/dockmagic-usage.json` and the newest per-session
  status snapshot were last written on 31 August. Both recorded reset deadlines
  had passed. The reader correctly discarded those expired values. A real
  Claude Code 2.1.251 session displayed `API Usage Billing` and a managed-settings
  authentication rejection (401); `/usage` showed only session token/cost
  counters, without 5-hour or weekly percentages. This does not establish a
  working subscription or current quota. No model prompt was sent.
## Application defects and changes

1. The shared Dock presentation created both `5H` and `7D`, even when the
   account supplied only a weekly window. It now omits unsupported metrics,
   preserves each metric's configured appearance, and keeps a real 0% value.
   The empty numeric state is a neutral `QUOTA —`; it does not invent a limit.
2. Expired or missing Claude quota remains an explicit warning instead of
   being inferred from local activity data.

## Verification

- Targeted XCTest coverage included Claude expiry and missing quota plus Codex
  weekly-only and aggregate selection.
- Final build/run via `./script/build_and_run.sh --verify` succeeded. The live
  UI showed Codex `7D 37%` and the Claude missing-quota explanation.

Remaining external limitation: displaying current Claude percentages requires
the CLI and account to return current quota. The app cannot derive account
quota from local token totals or expired snapshots.
