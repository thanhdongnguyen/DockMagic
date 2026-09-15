# AI Share Activity Card Layout

**Status:** Normative layout contract for DockMagic AI provider activity-card images.
**Baseline:** The current Codex and Claude Code Share images and their shared activity-card renderer, reviewed on September 15, 2026.

This document defines the image produced by the provider dashboard's Save, Copy, and Share activity-card actions. It governs composition, visual hierarchy, content slots, state variants, and export checks. It does not grant permission to collect or display a metric. The provider capability and export eligibility rules in AI_PROVIDER_FEATURE_CONTRACT.md decide whether each value may appear. AI_DASHBOARD_DESIGN_SYSTEM.md owns dashboard module selection; DESIGN_SYSTEM.md owns shared components and appearance; COLOR_DESIGN_SYSTEM.md owns color roles. Those contracts take precedence if an existing image conflicts with them.

## 1. Reference images and scope

The two source-reviewed dark fixtures use the same layout and renderer:

- [Codex activity card](share-card-concepts/implementation/codex-dark.png)
- [Claude Code activity card](share-card-concepts/implementation/claude-code-dark.png)

The [Antigravity activity-card fixture](share-card-concepts/implementation/antigravity-dark.png)
uses this same layout with the required `TOKENS OBSERVED TODAY` label for its
partial local ledger. It is an implementation fixture, not evidence of a live
Antigravity account or a new source capability.

The fixture values, earned badges, and dates are examples, not design-system constants or live-account evidence. Both fixtures are 1200 × 1200 pixels and have fully opaque alpha. They establish the current visual hierarchy: bounded provider identity, large central badge, today's token amount with a small trend, Ship momentum, and a quiet DockMagic footer.

This contract covers the **activity card**. A quota card is a separate artifact with a separate content layout, even when it uses the same canvas and export actions. A new provider does not gain activity-card eligibility or any slot merely because Codex and Claude Code use this layout.

## 2. Canvas and reading order

Render a dedicated 300 × 300 pt SwiftUI composition directly at 4× into an opaque 1200 × 1200 PNG. The image is square, flat, and self-contained. Use the resolved opaque surface role across the entire canvas. Exclude popup material, Dock pointer, window shadow, menu, capture control, and other dashboard chrome. Keep the visual content within 14 pt horizontal insets and an 8 pt bottom inset. Use one consistent composition for Save, Copy, and Share within an export attempt.

The fixed reading order is:

| Zone | Current baseline geometry | Required content and behavior |
| --- | --- | --- |
| Header | 11 pt top inset; 22 pt high; 14 pt side insets | Provider logo and name on the left; a compact source-date/freshness label on the right. |
| Badge hero | Main stack begins 18 pt from top; 144 pt badge artwork | Centered badge artwork. The badge remains the dominant graphic, below and visually clear of the header. |
| Badge text | Immediately below the artwork | Small CURRENT BADGE label, one-line earned title, and earned-day subtitle. |
| Divider | 0.5 pt neutral rule; 5 pt after badge subtitle | Separates the badge story from the daily metric. |
| Daily tokens | 3 pt after divider | Large token amount on the left and optional 14-day mini chart on the right; label directly below the amount. |
| Ship momentum | 5 pt after daily tokens | Small label and horizontal progress track on the left; score and rank aligned on the right. |
| Footer | 4 pt after momentum | Centered, tertiary DockMagic wordmark. |

These measurements document the shared Codex/Claude implementation and are the default for providers using this card. Keep the slot order, relative prominence, and canvas dimensions stable. Adjust only the internal fit of variable content within its slot; never add an extra row, legend, dashboard module, or decorative panel to fill space.

## 3. Header and provider identity

The logo occupies a bounded 22 × 22 pt identity region with a 6 pt rounded clip. Preserve the original logo colors only inside this region. Codex currently uses optical oversizing of its vector asset within the clip; that asset-specific adjustment is not a rule for other brands. Place the provider display name immediately beside the logo with an 8 pt gap. The baseline name is 15 pt bold, primary text.

The right-hand date is 7.5 pt bold, tracked, secondary text with monospaced digits. Current fresh cards read TODAY · MMM D, YYYY; stale cards read LAST KNOWN · MMM D, YYYY. The date must come from the appropriate source snapshot and the user's local calendar, with truthful freshness semantics. Do not replace a missing or old snapshot with an invented current date. Make provider names and dates fit inside the header without clipping or colliding. If a long name cannot fit, use an approved compact display name or a tested text fit strategy; do not move the date into a new row.

## 4. Badge hero

Use the shared StreakBadgeView artwork, centered at the current 144 pt baseline. Badge colors may remain inside the authored collectible silhouette. The surrounding canvas, labels, and metric chrome remain neutral.

Below the artwork, render CURRENT BADGE in small tracked secondary text (current baseline 7 pt). The earned badge title is the principal text line: current baseline 20 pt black weight, uppercase, single line, with controlled scale-down for longer localized names. The final subtitle is 7.5 pt tracked secondary text and states the actual earned duration, such as 14-DAY BADGE. If no badge was earned, show the locked/default badge treatment with READY TO BEGIN and NO BADGE YET. A missing badge is not an earned first badge. Do not synthesize a streak or badge from activity that the provider cannot support.

## 5. Today's token amount and optional trend

The amount is the largest numeric text on the card: current baseline 33 pt black rounded text with monospaced digits. Use compact K, M, and B formatting while preserving the underlying value for accessibility. A known reported zero is 0; unavailable is an em dash. Never convert an absent bucket to zero.

Use TOKENS TODAY when the eligible source represents the selected day's complete account bucket. Use TOKENS OBSERVED TODAY when the source is partial local observation. The label is directly below the number in small tracked secondary text (current baseline 7.5 pt, or 6.5 pt for the longer partial label). The amount and label occupy one coherent left block.

The chart is an optional 82 × 29 pt area/line graphic in an 88 pt trailing slot. It has no title, axes, ticks, numbers, legend, or gradient. It samples 14 consecutive local-calendar days ending today. Unknown days remain missing and break the line; a known zero remains a zero point. Use one solid bounded data hue for the line and a low-opacity fill, with a neutral dashed cue for missing samples. The current baseline uses a 1 pt line and 0.18 fill opacity, strengthened to 1.25 pt and 0.28 in Increased Contrast. The current renderer shows a trend only if it has a positive sample and at least one adjacent pair of known days. If that condition is not met, remove the chart slot and center the token block; do not show an empty chart scaffold or imply a flat zero trend.

The mini chart is decorative in the visual hierarchy. The accessible card value must say whether a 14-day history is present, partial, or unavailable.

## 6. Ship momentum

Place SHIP MOMENTUM in 7.5 pt tracked secondary text above a 7 pt high horizontal capsule track. The track is a neutral outline role; the filled length is proportional to an eligible score from 0 through 100. Its current border is 0.75 pt, strengthened to 1.5 pt in Increased Contrast. The right block shows the numeric score as X / 100 and its uppercase textual rank, aligned to the track area. Current baseline text sizes are 12.5 pt for the score and 7.5 pt for the rank. The rank repeats the meaning of the score in text, so color alone never communicates the result.

Ship momentum is a derived activity metric and appears only when its provider-specific evidence and computation are valid. If the card remains eligible but momentum is unavailable, show — / 100 and UNAVAILABLE; do not render 0 / 100 from absence. Do not substitute quota percentage, token trend, or another provider's scoring model for this slot.

## 7. Color, type, and appearance

Use semantic theme roles for the opaque surface, primary/secondary/tertiary text, divider, and neutral track. Keep the visual hierarchy through size, weight, position, and labels. Brand artwork remains bounded to the identity logo and badge silhouette. The mini chart may use one data hue inside its renderer; the momentum fill must use a color role permitted by COLOR_DESIGN_SYSTEM.md. Do not introduce a provider-local palette, gradient, glow, tinted card, or brand-colored chrome.

The current Claude Code fixture uses its terracotta usage hue in the mini chart and momentum fill. That is an observation of the existing renderer, **not** permission to extend the named Claude quota color role beyond the boundaries in COLOR_DESIGN_SYSTEM.md. When modifying this renderer or adding another provider, resolve any role mismatch against the color contract and refresh the fixtures as needed.

The card must remain legible in Light, Dark, Increased Contrast, Reduce Transparency, and grayscale. Increased Contrast strengthens small chart strokes and progress outlines. The badge, token amount, freshness, score, and rank remain understandable without hue. A static export does not depend on animation or hover state.

## 8. Content and state matrix

| State | Required image treatment |
| --- | --- |
| Eligible fresh activity | TODAY date label; actual earned/empty badge state; eligible token amount; optional meaningful chart; eligible momentum. |
| Stale snapshot | LAST KNOWN with the source date; preserve only valid last-known values and do not imply live activity. |
| Partial observed history | TOKENS OBSERVED TODAY; chart only for known adjacent samples; accessible description identifies partial history. |
| No earned badge | Locked/default badge treatment; READY TO BEGIN; NO BADGE YET. |
| Known zero tokens | Show 0 and preserve known zero samples; chart visibility still follows the meaningful-trend rule. |
| Missing token amount | Show an em dash only if other non-sensitive activity still makes export eligible; otherwise do not offer an activity card. |
| Missing trend | Center the token block and omit the chart slot. |
| Missing momentum | Show — / 100 and UNAVAILABLE only when the remaining activity card is eligible. |
| No eligible activity | Do not export an empty activity card. A separately eligible provider-reported quota may use a quota card under its own contract. |

Every slot uses data from the selected provider and its declared scope. Do not include account identifiers, internal paths, prompts, answers, task or goal descriptions, raw transcript content, or private setup diagnostics in the image. Source failures belong to the affected slot or export action and must not be presented as a provider outage without evidence.

## 9. Accessibility and export verification

Treat the raster card as one accessible item. Its label names the provider and daily activity card. Its value states badge, actual or unavailable token amount, trend availability/partiality, and Ship momentum score/rank or unavailability. Hide decorative logo, artwork, divider, chart, and progress geometry from separate accessibility traversal.

Before adopting or changing this layout, verify:

1. The provider capability manifest and activity-card export eligibility permit every populated slot.
2. Save, Copy, and Share produce the same dedicated artifact for one attempt, with correct source date, values, and provider identity.
3. The PNG is exactly 1200 × 1200 pixels and all alpha values are opaque; it was rendered at 4× rather than enlarged from a screen bitmap.
4. Long provider/badge names, large token values, stale and partial labels, zero and missing values, sparse chart history, and unavailable momentum fit without collision or false implication.
5. Light, Dark, Increased Contrast, Reduce Transparency, and grayscale preserve hierarchy and meaning.
6. Visual review compares the new card with the Codex and Claude Code references, while recording whether the evidence is a source review, fixture render, or live runtime capture.

When a shared layout change is intended for every participating activity card, update the shared renderer and all provider fixtures in the same change. Adding a new content slot or changing a metric's meaning requires an explicit design-system revision and provider capability review; it does not propagate automatically to providers that lack that data.
