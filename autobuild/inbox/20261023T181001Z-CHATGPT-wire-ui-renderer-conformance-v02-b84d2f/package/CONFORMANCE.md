# Wire UI cross-renderer semantic conformance v0.2

## Authority

Application truth is outside renderers. Web, Swing, GTK/Direct Linux and Android own native presentation and ephemeral interaction mechanics only.

## Required agreement

All four must preserve:

1. exact `definitionId@version` and immutable content identity;
2. authoritative snapshot/patch revision order;
3. event-time `renderedRevision`;
4. stable application item identity, never row ordinal;
5. bounded `RangeRequested(start,count)` demand, with source traversal owned outside renderer;
6. exact opaque server `workspaceContext` when a workspace-bound action is emitted;
7. semantic activation rather than toolkit-event synthesis;
8. exact published ResourceRef with no renderer-authored URL/copy;
9. positive-list observation subscription semantics;
10. fail-closed deauthorisation/stale/invalid conditions.

Renderer-specific styling is allowed. It cannot manufacture application actions or infer business/lifecycle authority.

## Current status

See `STATUS.json`. All real adapters remain open; this is intentionally not represented as four-renderer PASS.