# Architecture — Brand Intervention Governance v0.2

```text
Brand Intervention Effectiveness v0.2
   current / previous / baseline
   primary + guardrail outcomes
   denominators + uncertainty
   assignment/release provenance
              |
              v
Brand Intervention Governance evidence binding
              |
              +---------------------------+
                                          |
Institutional Policy v0.6                 |
   reviewed fixed release                 |
   publication authority                  |
   deployment lifecycle/topology          |
   progressive version selection          |
              |                           |
              v                           |
BrandInterventionGovernancePolicySelection|
   exact policy id/version/identity        |
   deployment identity                     |
   publication assurance/evidence          |
   domain-owned rule-set payload           |
              |                           |
              +-------------+-------------+
                            v
Brand Intervention Governance Engine
   bounded, non-executing recommendation
   association-only interpretation
   no single utility score
                            |
                            v
Named external governance authority
   records decision
   positive exposure decisions require
   institutionally managed recommendation
                            |
                            v
External access/action component
   (not in this package)
```

## Ownership boundary

Institutional Policy owns **selection mechanics**: publication, effective dates, authority, lifecycle, deployment topology and progressive version rollout.

Brand Intervention Governance owns **domain semantics**: what evidence states mean for `MEASURE_MORE`, `HOLD_BASELINE`, review, pilot, expansion, continuation, withdrawal and regression review.

The governance package therefore consumes an Institutional Policy resolution and preserves it; it does not copy Institutional Policy's authority or deployment algorithms.

## No implicit operative policy

The low-level `recommend(binding, rules)` API is deterministic and remains useful for tests/counterfactuals, but requires an explicit sealed rule set and marks the recommendation unmanaged.

The managed path is:

```text
BrandInterventionGovernancePolicySelection~fromCatalog(...)
BrandInterventionGovernanceEngine~recommendUnderInstitutionalPolicy(...)
```

This prevents a component-local default from silently becoming an operative institutional decision basis.

## Decision boundary

A named domain authority remains separate from Institutional Policy publication/deployment authority. v0.2 does not merge those roles.

A recommendation created from unmanaged rules cannot seal a positive exposure-increasing decision. This is a consumer-side invariant: it ensures that `APPROVE_CONTROLLED_PILOT`, `APPROVE_LIMITED_EXPANSION`, and `CONTINUE_CURRENT` are not recorded as operative governance decisions unless the rule set was actually resolved through Institutional Policy.

Containment/no-change decisions remain recordable because they do not grant increased exposure, and execution remains external in every case.
