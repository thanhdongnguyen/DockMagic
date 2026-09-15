---
name: ai-provider-integration
description: Research, design, implement, or review an AI usage provider in DockMagic. Use when adding a provider, deciding which quota/activity metrics it can expose, or checking that its Settings, Dock, hover, state, privacy, and test coverage satisfy the repository contract.
---

# AI Provider Integration

Use the repository's durable provider contract to produce an evidence-backed
vertical slice. Do not treat feature parity with Codex or Claude Code as proof
that an upstream provider exposes the same data.

## Required context

Before taking provider-specific action, read
[the AI Provider Feature Contract](../../../docs/AI_PROVIDER_FEATURE_CONTRACT.md)
completely. Read `docs/COLOR_DESIGN_SYSTEM.md` and `docs/DESIGN_SYSTEM.md` before
changing UI. Read `docs/AI_DASHBOARD_DESIGN_SYSTEM.md` completely before
designing, implementing, or reviewing a dashboard or its module manifest.
Read `docs/ARCHITECTURE.md` before changing composition, lifecycle, or
persistence. Read only the provider-specific documents and source files
needed for the current provider.

The contract is authoritative. Update it only for a product-wide invariant;
keep upstream commands, versions, fields, caveats, and evidence in a separate
provider document.

## Choose the requested mode

### Research or feasibility

1. Inspect the existing Codex and Claude Code feature slices to understand
   DockMagic's available surfaces and normalized concepts.
2. Research current primary provider sources. Prefer official public docs,
   public schemas, documented CLI output, and documented local extension
   points. Record source URL or local command, version/plan, and verification
   date.
3. If local inspection is in scope, use read-only probes first. Do not expose
   secrets or raw prompt/answer content in output, logs, fixtures, or docs.
4. Fill the contract's capability dossier. Classify every candidate datum as
   supported, unsupported, unknown, or prohibited and keep capability status
   separate from runtime observation state.
5. Produce the provider research document from the contract template. End with
   a clear recommendation: full slice, limited slice, more research, or reject.
6. When a dashboard is in scope, propose an explicit provider module manifest
   using the dashboard contract. Identify requested modules that cannot ship
   and existing modules that must remain out of scope.

Do not write implementation merely because research found a possible source
unless the user also requested implementation.

### Implementation

1. Require an adequate dossier or create/update it as part of the task.
2. Inspect the worktree and preserve unrelated user changes.
3. Implement the smallest complete vertical slice across every applicable
   integration point listed in the contract. Keep provider acquisition quirks
   in the adapter and normalize semantics before presentation.
4. Gate optional modules by proven capability. Never infer missing quota,
   convert absence to zero, hide partialness, substitute model-specific limits,
   or let one optional-source failure erase other valid data.
5. Reuse the design system, dashboard module catalog, and production Dock
   renderer. Select only dossier-supported modules in the provider manifest.
   Add provider-specific UI only when source, semantics, or setup genuinely
   differ.
6. Add sanitized parser fixtures and state-transition tests, then run focused
   tests plus the broadest practical build/test gate for the change.
7. Verify affected UI modes and accessibility states required by the contract.
   If a mode cannot be observed locally, report it explicitly rather than
   claiming verification.
8. Update the provider document, architecture/privacy text, licenses, and
   third-party notices to match the implemented behavior.

### Review

Trace every displayed value back to its capability-dossier row and source.
Check each rendered module against the provider manifest and the dashboard
contract, including excluded modules and shared-component states.
Report actionable findings first. Pay particular attention to invented or
mis-scoped quota, zero-vs-missing handling, stale-data loss, partial history,
credential access, private endpoints, raw-content logging, direct-distribution
compatibility, missing UI surfaces, and tests that only cover the live path.

## Completion report

Summarize:

- the supported user story and recommendation;
- supported, conditional, unsupported, unknown, and prohibited capabilities;
- surfaces added or intentionally omitted;
- data provenance, freshness, privacy, and distribution implications;
- tests and appearance/accessibility checks actually performed;
- unresolved upstream or account-dependent limitations.
