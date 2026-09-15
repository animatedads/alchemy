# Product / risk / coverage rating - AJI v0.10

AJI retains the v0.5+ structure in which product definition and product-rating program say **what is insured** and pin the exact coverage plan used by the shared rating engine.

```text
ProductDefinition
   | risk schema + allowed coverage schema
   v
ProductRatingProgram
   | exact coverage -> ratePlanRef pins
   | composite functionRef
   v
RiskObject[] -> CoverageSelection[] -> RatingEngine -> scoped ProductRatingResult
```

PI, Home and Car remain schemas rather than invented production actuarial rates.

## Mid-term pinned-program mode

The v0.9 `ProductRatingBook~ratePinnedProgram(...)` entry point remains the mid-term pricing path in v0.10. This entry point is intentionally different from resolving the currently effective product program: the caller supplies the exact existing `programRef` already locked to the policy term.

The transaction layer uses this for BEFORE/AFTER exposure re-rating. Policy inception remains the term's rate-resolution context while each coverage selection receives the explicit transaction-period proration. Both sides therefore use the same exact product program, tables, factor rules and executable coverage functions.

Unknown/missing/ambiguous table dimensions continue to fail closed. No mid-term transaction is allowed to fall back to a newer program merely because the effective date is later in the term.
