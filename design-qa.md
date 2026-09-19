# Binance UI update — 2026-09-17

The current appearance update is documented in [Binance UI QA](docs/BINANCE_UI_QA.md), with new captures and separate fixture/runtime results. The record below is the original 2026-09-16 implementation audit and does not describe the later typography/color update.

# Original Pinned Focus audit — 2026-09-16

Status: **passed for the visual comparison and exercised native flows**. This is not a claim that every release-validation scenario has been completed.

Reference: [approved option 2](docs/binance-design/pinned-focus-reference.png). Implementation: SwiftUI, Swift Charts, AppKit panel and the shared application icon renderer. Compared the reference and rendered implementation together, then inspected the running native app with live Binance data.

## Evidence

- [Live hover panel](docs/binance-design/verification/live-hover-panel.png), [installed application/Dock icon](docs/binance-design/verification/live-installed-dock.png), [live measurements](docs/binance-design/verification/live-appkit-evidence.json).
- [Dark](docs/binance-design/verification/dashboard-dark.png), [Light](docs/binance-design/verification/dashboard-light.png), [Increased Contrast / Reduce Transparency](docs/binance-design/verification/dashboard-light-contrast.png), [grayscale](docs/binance-design/verification/dashboard-dark-grayscale.png).
- [Candles and volume](docs/binance-design/verification/dashboard-candlestick-volume.png), [grayscale candles](docs/binance-design/verification/dashboard-candlestick-volume-grayscale.png).
- [Empty](docs/binance-design/verification/dashboard-0-pairs-small-screen.png), [one pair](docs/binance-design/verification/dashboard-1-pairs-small-screen.png), [two pairs](docs/binance-design/verification/dashboard-2-pairs-small-screen.png), [20 pairs at reduced height](docs/binance-design/verification/dashboard-20-pairs-small-screen.png).
- [Loading](docs/binance-design/verification/dashboard-loading.png), [error](docs/binance-design/verification/dashboard-error.png), [stale](docs/binance-design/verification/dashboard-stale.png), [stale Dock](docs/binance-design/verification/dock-stale.png).
- [32 pt Dock](docs/binance-design/verification/dock-dark-32.png), [48 pt](docs/binance-design/verification/dock-dark-48.png), [64 pt](docs/binance-design/verification/dock-dark-64.png), [128 pt](docs/binance-design/verification/dock-dark-128.png).
- [19 focused XCTest results](docs/binance-design/verification/test-results.json), [native interaction checks](docs/binance-design/verification/manual-ui-results.json), [source hashes](docs/binance-design/verification/source-hashes.json).

The screenshot matrix uses fixtures except the explicitly named live artifacts. The native interaction checks used real REST/WebSocket data in an isolated QA bundle and preference suite. Main app preferences were restored after the initial single BTC test addition.

## Comparison and fixes

| Surface | Result |
| --- | --- |
| Layout and spacing | One hero followed by a two-column grid; fixed header/search/range/footer, scrollable chart body. Actual panel measured 620 × 740 pt. At reduced height, cards scroll instead of shrinking controls. |
| Typography | Native system font, tabular prices, explicit quote and 24h label; large price hierarchy retained. Long pair names can scale within a single line. |
| Color and surfaces | Shared semantic tokens, opaque neutral surfaces, neutral Dock divider, a single chart series hue; no gradient or glow. Brand colors stay inside identity assets. |
| Imagery and icons | Bundled Binance/BTC/ETH/SOL assets from Binance CDN. Unknown assets use ticker identity. SF Symbols provide settings, search, pin and menu controls. The small source favicon is softer than a vector mark (minor quality limitation). |
| Chart geometry | Fixed clipped right-edge time labels, overlapping constant-width candles/volume bars, and stale text colliding with time labels. Candle width follows interval spacing. Hollow/filled bodies carry direction without red/green dependence. |
| Accessibility | Fixed parent IDs overwriting descendant controls by adding explicit containment. Search/Add/pickers/pin/menu now expose distinct native IDs. Labels preserve quote, 24h, stale state and chart description. |
| Interactions | Verified add/search/pin, tracked search preserving pin, shared chart/range settings, volume, removing the pinned pair with BTC fallback, Unicode query, and two-stage Escape. |

No unresolved P0/P1/P2 visual mismatch was found in the inspected states. Minor differences from the concept are intentional: the added 1H range, native chart picker, official CDN identity variants, neutral semantic change labels, and removal of gradients/colored Dock divider according to the approved implementation plan.

## Validation boundaries

- `./script/build_and_run.sh --verify` built and launched the real worktree app successfully. A one-line MainActor dispatch fix was necessary in the concurrently added shared AI chart; other unrelated edits were retained.
- The 19 focused tests ran in a frozen project copy with independent packages and Debug ad-hoc signing. They include logic, preferences, parser/merge, late range response, demand release, error classification/Retry-After, hover timing, renderer states and an explicit live AppKit test. No production signing or Hardened Runtime setting was changed.
- The live AppKit run observed all three selected markets, 289 candles each, WebSocket `Live`, and a 1024-pixel installed icon. It is a real panel/application-icon capture, not a screenshot of the entire macOS desktop.
- XCUI automation failed before any UI test executed: `Test runner never began executing tests after launching`. Native computer-use checks above supplied interaction evidence. The XCUI test source is included but is not reported as passing.
- Actual Vietnamese IME marked-text composition, physical Dock placement on all screen edges, repeated real sleep/wake cycles and the 24-hour socket rotation still need dedicated device QA. Sleep/wake recovery and reconnect behavior have fixture/source coverage; this is not a 24-hour soak test.
- Dock views at 32/48/64/128 pt were rendered. AppKit reported a 128-pt logical tile in the live run. Compact formatting at every physical Dock magnification setting is not claimed as verified.
- Commercial market-data usage rights remain the separate unresolved item recorded in the Binance research.
