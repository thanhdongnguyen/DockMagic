# Augment organization analytics

DockMagic reads the official Enterprise Analytics API with a service-account token entered in **Settings → AI → Augment**. The integration always queries the organization; there is no user/email selector.

1. Follow **How to get a token** in Connection; an Augment administrator creates the service account and token.
2. Enter the token and choose **Connect**. DockMagic probes a single reported UTC day before storing the credential in its own Keychain item. An empty successful response is a valid connection.
3. Select **Use Augment in Dock**. The default is Numbers showing IN and OUT for the same latest reported UTC day. Billed USD and Trend are optional.
4. Open **Preview dashboard** (a native sheet with **Done**) or hover the Dock icon to inspect 7/30/90 days (default 30), choose a metric, inspect organization continuity and Output-token Daily intensity, view model ranking and select a day for token components and billed/estimated USD.

The query ends at yesterday UTC by DockMagic policy. “Latest reported” means the latest returned daily bucket, not realtime usage or an assurance that upstream data is final. Missing values and dates stay missing; explicit zeros remain zero. A reported day remains selectable even when the selected metric is missing, so its other components can still be inspected. Cache reads/writes are separate from input/output. Model/compute breakdown is never added to overview totals.

Refresh is coalesced, with a six-hour automatic interval while selected/visible and a thirty-second manual cooldown. Requests are spaced by two seconds. Auth/permission errors require connection action; optional model failures retain overview. A failed paginated download keeps the previous complete snapshot. Stale values retain their original date and checked time.

Token replacement validates before saving, creates a new connection generation and clears the old cache. **Disconnect** cancels requests and removes the local Keychain item/cache; revoke the token on Augment separately. **Clear local history** keeps the connection. **Reset appearance** only resets the renderer. No CLI, browser session, provider credential extraction or new entitlement is required.

## Capability and implementation references

- [Provider dossier and API sources](AUGMENT_API_RESEARCH.md)
- `AugmentDashboardManifest`: identity, official status link, daily usage/detail, organization continuity, Output-token Daily intensity and model breakdown.
- Organization continuity is derived from reported UTC organization buckets. It uses the shared continuity strip but does not award badges or claim a personal streak. Positive token/cost data is active, explicit zero ends a run and an unreported date stays unknown.
- Omitted: total tokens, quota, balance, credits, realtime, lifetime, personal streak/badges, Ship momentum and export.
- `AugmentAnalyticsClient`: DAY overview / RESOURCE + TOTAL detail; Int64 tokens, Decimal USD, safe errors, pagination, backoff, fixed-origin HTTPS.
- `AugmentUsageStore`: visibility, UTC range, coalescing, generation checks, independent resource loads.
- Own normalized overview cache: Application Support/DockMagic/Augment/organization-v1.json. No raw response or credential is cached. Resource breakdown is memory-only.

## Verification log — 2026-09-16

- Foundation lane: `./script/test_augment_foundation.sh -j 2`; 19 tests passed in the standalone run. The final signed-host Xcode run passed all 22 parser/store cases, including the additional visibility/cooldown, resource coalescing and shared Retry-After cases.
- Xcode integration lane includes API/store tests, production-renderer appearance captures, isolated Keychain roundtrip in a signed host, shared-chart scroll/hover regression, and Augment Settings/dashboard UI navigation.
- Render outputs: `/private/tmp/augment-captures`; synthetic fixtures only.
- Signed-host Xcode: 26 selected tests passed (13 API, 9 store, 3 integration/render/Keychain, 1 legacy shared-chart scroll/hover regression). The UI runner in that run was interrupted during launch contention, so this is not a claim that the entire run passed. Exact selected results: [selected-tests.txt](augment-api-research/verification/selected-tests.txt).
- `./script/build_and_run.sh --verify`: exit 0, including the final run after the dashboard keyboard-focus correction; app launched and remained running. A stale Swift object mismatch in shared intensity-chart code had required a clean build earlier. No source behavior was changed to work around that linker failure. Final log: `/private/tmp/dockmagic-augment-runtime-complete.log`.
- Appearance: 33 synthetic PNG captures across Light/Dark, Increased Contrast, Reduce Transparency, Reduce Motion, grayscale, Dock 32/48/64/128 pt, numeric/trend, missing/zero and negative USD. Representative [Light dashboard](augment-api-research/verification/dashboard-light.png), [Dark increased-contrast dashboard](augment-api-research/verification/dashboard-dark-contrast.png), [64 pt Dock trend](augment-api-research/verification/dock-trend-64.png).
- UI navigation: all three cases passed across the final scoped QA runs: empty versus authentication error, selectable partial day with missing Output, and token setup → dashboard → 7-day range → all models → daily UTC detail → Escape back to history. The first run after the focus correction passed two cases; the partial-day case encountered an XCTest AX process mismatch during concurrent UI sessions, then passed its isolated retry (exit 0). Exact results: [ui-tests.txt](augment-api-research/verification/ui-tests.txt). The temporary QA project uses bundle ID `com.hypevibe.DockMagic.AugmentQA`; production bundle settings remain unchanged.
- The scoped Xcode command temporarily excluded `CalendarSyncTests.swift`, whose concurrent draft API changes blocked test compilation; the repository project was not edited to exclude it. Production build used the complete app target.
- **Live Enterprise acceptance: not verified.** No real token was supplied. Compare Input, Output, billed USD and model breakdown with Augment web for the same Organization/UTC period before claiming live-account correctness.

The working tree includes other features under development. A two-line `await` correction in EventKitCalendarProvider was necessary to unblock the shared app build; no Calendar behavior was intentionally changed for Augment.

## Continuity and intensity update — 2026-09-18

- Added organization continuity and Output-token Daily intensity through shared production components.
- Unit fixtures verify active, explicit-zero and unknown days; Light/Dark component and full-dashboard renders passed.
- Selected Augment/design-system tests (19) and provider regression tests (20) passed. Resource verification, `Design.md` lint, build/launch and strict deep code-sign verification passed.
- Evidence remains synthetic; live Enterprise-account comparison is still required.
