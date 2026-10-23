# Brand Narrative Directive v0.1-dev4

Connector-neutral bridge from governed Brand evidence to an external runtime narrative authority.

The public API generation remains `brand.narrative.directive/0.1`.

## dev3

v0.1-dev4 retains all dev2 projection, fresh-authority, Communications Discovery dev10, and Librarian dev4 positioning behavior and adds a revision-aware evidence seam for **Librarian v2 dev6**.

`BrandNarrativeExternalReviewAdapter~fromLibrarianChange(...)` accepts a dev6 `LibrarianChangeComparison` and snapshots the current correction/retraction graph counts without converting them into truth, omission, bias, dispatch, claim, or publication authority. `RETRACTED` is preserved as retraction evidence, explicitly **not falsity**. Branched terminal revisions are preserved through `CONFLICTED` rather than selecting a winner.

Librarian dev6's comparison object does not retain its event/proposition query identifiers. The adapter therefore requires those identifiers separately and marks them `SCOPE_BINDING=CALLER_SUPPLIED_NOT_VERIFIED_BY_COMPARISON`; the opaque `sourceRef` remains the provenance link to the upstream comparison/query. This package does not invent a stronger binding.

A Librarian conflict or retraction never changes handoff state by itself. Communications `HOLD_*` remains the external evidence hold gate; an evidence-only Communications review plus conflicted Librarian evidence can still reach only `READY_FOR_EXTERNAL_AUTHORITY_REVIEW`, never activation or publication.

The handoff remains `NO_DISPATCH` with publication authority `NONE`. Dynamic Story, Communications Management, Institutional Policy, publication, channel execution and Intention Service remain independently owned components.


## dev4: declared source lineage and current editorial review

Dev4 adds a typed adapter for Librarian v2 dev7 declared source lineage. A shared declared root is retained as `SHARED_DECLARED_ORIGIN`, not promoted to verified provenance; different roots remain `INDEPENDENCE_NOT_ESTABLISHED`. The adapter explicitly records that editorial independence, bias and causation are not established.

The current Communications Discovery boundary is dev14. Its evidence review is still `NO_DISPATCH` / `NOT_VERIFIED`, and it now makes the per-request freshness requirement particularly clear: the external narrative candidate and visible Librarian terminal revision are re-evaluated for each review. This package stores only the returned detached review snapshot; it does not confer freshness, claim approval or publication authority by retaining it.

`integration.json` requests exact ooRexx 5.3.0 r13196 compile/runtime qualification in Alchemy Autobuild and runs Claude's standards enforcer in strict mode.
