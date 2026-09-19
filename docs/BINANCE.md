# Binance Spot in DockMagic

Binance is a market-data feature. It uses public Spot endpoints without an account, API key, wallet, or trading actions. The approved visual target is [Pinned Focus](binance-design/pinned-focus-reference.png). The color and component contracts remain normative; content is opaque, charts have no gradients, and the Dock divider is neutral.

## Dashboard and selection

Hover continuously for one second when the shared Dock hover option is enabled. Passive hover does not take keyboard focus. Clicking Search/Add opts the Binance panel into keyboard input; Escape closes the finder first, then the panel. Clicking outside dismisses it. Menus hold the panel open. Settings → Binance → Open dashboard provides the same content without Accessibility or Dock hover.

A direct Dock click cancels pending hover, closes any dashboard, and opens
Settings immediately. Hover stays suppressed until the pointer leaves the icon,
so repeated Dock notifications cannot reopen the panel over Settings (UI-015).

The pinned pair owns the large chart and Dock price. Without a pin, use the first saved pair. Pinning does not reorder the persisted watchlist. Unpinning/removing the pinned pair falls back to the first remaining pair. Search never changes selection. Each other pair has its own chart in a two-column grid. Add appends, duplicates are rejected, and the limit is 20 pairs. Move up/down changes the saved order.

Pairs are identified by their complete Binance symbol, not the coin alone. BTC/USDT and BTC/USDC are different entries. Search accepts base, quote, and pair forms, including `BTC / USDT`. Binance exchangeInfo does not provide full coin names or logos; generic assets show their ticker. Bundled BTC/ETH/SOL and Binance logos are bounded identity assets from Binance's public CDN.

## Shared preferences

`BinanceConfiguration` persists in `DockPreferencesStore` under `DockMagicBinanceConfiguration`. An empty watchlist is the default. Chart type (Line/Candlestick), range (24H), volume (off), and preferred quote (USDT) are shared by Settings and dashboard. Preferred quote only sorts search results. Dock prices adapt to the space; the dashboard retains the Decimal price without a fixed two-decimal truncation. USDT is never relabelled as USD.

| Range | Candle interval | Maximum points |
| --- | --- | --- |
| 1H | 1m | 61 |
| 24H | 5m | 289 |
| 7D | 1h | 169 |
| 30D | 4h | 181 |
| 1Y (365 days) | 1d | 366 |

The percentage beside the price always means rolling 24h, regardless of chart range. Candles use UTC bucket timestamps, with local-time tooltip labels including timezone. Hollow candles rise, filled candles fall; volume is the base asset quantity per candle. Newly listed pairs show only available history.

## Appearance and controls

Dashboard text, chart axes/tooltips, and proportional Dock text use SF Pro
Rounded. Settings controls use SF Pro; its production Dock preview and opened
dashboard retain their renderer's Rounded typography. The Pinned Focus layout
is unchanged. Icon actions have at least 36 pt hit regions and explicit labels;
the search label stays visible while typing. Closing search does not re-trigger
the search-entry gesture.
Chart type uses a native segmented picker in both Settings and dashboard
(UI-014); range and all saved market preferences retain their existing behavior.

Settings → Binance → Colors contains **Dock price**, **Price line / candles**,
and **Volume**, using the shared renderer palette. `BinanceAppearance` stores
optional `dockPriceColor`, `priceSeriesColor`, and `volumeColor` values inside
the existing configuration key. `nil` is Automatic: primary text, price-series
blue, and tertiary neutral respectively, resolved for the current theme. Old
preferences with no appearance or missing appearance fields retain their
watchlist, pin, and chart settings. Custom colors absent from the palette remain
available as the current-color swatch.

Reset Defaults resets **colors only**. Color edits update presentation immediately
without refreshing REST history, changing stream subscriptions, or writing the
market cache. The Dock snapshot includes only its price color, including empty,
loading and stale states; chart-only color edits do not invalidate the icon.
Dock, Command-Tab and Settings use the same production renderer.

Contrast correction stays in the renderer (Dock price ≥4.5:1, chart marks ≥3:1)
and does not alter the saved color. Backgrounds, ticker/quote labels, divider,
focus, buttons and status remain semantic. Price line, candlestick and hover
point share one color; volume has its own. Hollow/filled candle bodies preserve
direction without color. Chart colors can be inspected via Open dashboard.

The shared `DSButtonStyle` now has solid fills/outlines for all features; Binance
dashboard buttons explicitly opt into its Rounded surface typography.

## Data ownership and lifecycle

`BinanceMarketStore` owns observable per-pair quote/chart states and a separate Dock snapshot. REST and WebSocket clients are actors behind injected protocols. Public REST uses `data-api.binance.vision` (`exchangeInfo`, `ticker/24hr`, `klines`); the single combined WebSocket uses `data-stream.binance.vision`. Foundation owns transport. Swift Charts owns drawing.

The store merges by symbol/interval/open time, rejects older updates, and does not reopen closed candles. Range changes invalidate outstanding chart requests. REST candle timestamps use request start time so late snapshots cannot supersede intervening stream events. Main-actor UI updates are coalesced at one second; candles do not directly invalidate the application icon renderer.

Dashboard demand subscribes ticker for the watchlist and candles for visible/lazily prefetched cards plus the hero. Closing dashboards retains only the selected ticker while Binance is active. An inactive feature without a dashboard or Settings preview stops networking. Multiple dashboard hosts use independent demand tokens. Sleep/wake and network restoration resynchronize snapshots and chart gaps.

Control messages are serialized at least 650ms apart. The socket pings every 20s with a 10s response deadline, rotates before 24 hours, and reconnects with bounded exponential delay plus jitter. While disconnected, REST snapshots and visible charts refresh every 30s. REST 429/418 respects Retry-After; access restriction errors stop retrying until explicit Retry. No domain switching bypasses restrictions.

Quote receipt age and socket health are separate. Quotes older than 60s become stale without using silence alone to restart the socket. Last-known data remains attached to the same pair; absence is `—`, never zero. A successful catalog can establish unavailable pairs; failed or malformed catalog requests cannot establish delisting. Recoverable errors remain local to their quote/chart.

The disposable cache is versioned, bounded to 8 MiB, and written at most once per 10s. Catalog refreshes after six hours. Cache older than 24 hours is discarded. Cached prices/charts load as stale and refresh from the provider. Preferences are separate from this cache.

## Verification

Focused XCTest classes: `BinanceFeatureTests`, `BinanceRenderTests`, `DockHoverDelayTests`; UI flows: `BinanceUITests`. Renderer captures default to `/tmp/binance-captures`. The DEBUG-only fixture provider is opt-in through existing UI-test launch infrastructure and never replaces failed live requests in production.

The [live client probe](research/binance-2026-09-16/implementation/live-client-probe.swift) compiles against the implementation's model/REST/stream files, without linking the app. Its [recorded result](research/binance-2026-09-16/implementation/live-client-results.json) verifies real public REST and stream traffic, not every regional network or a 24-hour connection.

The initial implementation verification (2026-09-16) passed 19 focused tests,
including live REST/WebSocket panel and installed-icon capture. Its native
computer-use checks covered Search/Add/Pin, shared settings, removal fallback,
Unicode and two-stage Escape; XCUI automation did not start in that run.
The [2026-09-17 UI update QA](BINANCE_UI_QA.md) records the new typography,
colors, segmented controls, shared-button regression checks and their separate
runtime evidence and remaining limits.

See [design QA and its remaining validation limits](../design-qa.md), [test results](binance-design/verification/test-results.json), and [live AppKit measurements](binance-design/verification/live-appkit-evidence.json). Commercial distribution rights remain a separate unresolved item in [the integration research](BINANCE_INTEGRATION_RESEARCH.md).

## Asset sources

- Binance: https://bin.bnbstatic.com/static/images/common/favicon.ico (converted to PNG, unchanged artwork).
- BTC: https://bin.bnbstatic.com/static/assets/logos/BTC.png
- ETH: https://bin.bnbstatic.com/static/assets/logos/ETH.png
- SOL: https://bin.bnbstatic.com/static/assets/logos/SOL.png

Identity assets retain their respective owners' marks; no color from them is used for controls, selection, or surfaces.
