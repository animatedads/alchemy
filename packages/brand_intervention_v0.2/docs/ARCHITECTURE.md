# Architecture — Brand Intervention v0.2

## Responsibility

The package answers one narrow question:

> Given a current privacy-minimised journey state and a sufficiently rich,
> time-scoped evidence report, what bounded objectives and constraints are
> reasonable material for another LLM to consider?

It does not own instrumentation, identity, CRM, customer-facing rendering,
action execution or causal adjudication.

## Main objects

### `BrandInterventionContext`

Current journey residue. Customer sentiment remains labelled as assessed.

### `BrandInterventionEvidenceBinding`

Binds a reasoning-ready journey population report to an as-of time and explicit
evidence age. It embeds the entire upstream reasoning material rather than
reducing it to a status label.

### `BrandInterventionPolicy`

Controls freshness and review boundaries. Policy obligations/prohibitions are
carried into every proposal.

### `BrandInterventionProposal`

A non-executable set of controlled objectives, avoidances and obligations. No
customer prose is present.

### `BrandInterventionDecision`

Combines current state, policy, evidence and proposal into the material supplied
to a reasoning LLM. Every decision states both `GUIDANCE_NOT_EXECUTION` and
`ASSOCIATION_NOT_CAUSATION`.

### `BrandInterventionOutcomeObservation`

Captures post-intervention evidence for later comparative analysis. It cannot
promote causal status.

## Decision table

```text
Evidence condition                Decision mode         Behavioural effect
-------------------------------  --------------------  ----------------------
INSUFFICIENT                     BASELINE_ONLY         none from evidence
WEAK_SIGNAL + cohort quality OK  OBSERVE_ONLY          collect more evidence
WEAK_SIGNAL + cohort gate fail   REVIEW_REQUIRED       repair cohort evidence; no behaviour change
MATERIAL_INVESTIGATION           REVIEW_REQUIRED       review; no auto change
SUPPORTED / STRONG               REASONING_GUIDANCE    bounded objectives only
Evidence too old                 REVIEW_REQUIRED       refresh before adapting
```

## Negative invariants

1. `PROMOTIONAL_WORK` does not imply `SALESPROP`.
2. A sass association does not imply cancellation causation.
3. A sass association does not imply extreme apology.
4. Materiality alone does not permit a population-wide style rule.
5. Stale evidence does not alter behaviour.
6. Intervention outcome observation does not assert intervention success.
7. Customer identity/raw conversation does not enter this layer.
8. Another component still owns action authority and access-point firing.
9. Large/effectful/confident evidence with a failed cohort-quality gate does not become behavioural guidance.
10. Convenience or narrow sampling is not moralised as bad unless an explicit configured evidence-quality gate fails.

## Reasoning-material design

The packet is intentionally larger than a classifier label. It carries:

```text
current state
policy boundaries
as-of time / evidence age
population denominator
feature denominator
joint outcome count
observation window
classifier/taxonomy provenance
process/model release provenance
thresholds
uncertainty
cohort source / selection / sampling / deduplication provenance
cohort missingness and unresolved-eligibility counts
independent cohort-quality gate and reasons
supporting evidence
counterevidence
scope exclusions
permitted interpretations
prohibited interpretations
proposal objectives
proposal avoidances
proposal obligations
```

The aim is to let a well-meaning rewarded LLM reason from evidence rather than
blindly obey a compressed judgement.
