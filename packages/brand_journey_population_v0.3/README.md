# Brand Journey Population v0.3

`Brand Journey Population` is the longitudinal/statistical evidence layer above
`Brand Journey`. It is designed to give another reasoning LLM **weight and
measure**, not a naked verdict.

It answers questions such as:

- Is `CROSS_DOMAIN_CONTEXT_LOSS` associated with abandonment in a defined class
  of Support → Billing journeys?
- Does that association change when `SERVICE_RECOVERY_ACROSS_DOMAIN` is present?
- Did the pattern materially change after a model or process release?
- Is the sample statistically sufficient, materially important, or too weak to
  support a conclusion?
- How was the analyzed denominator selected, what was excluded, and what is
  actually known about the source population?

## v0.3: provenance ownership is explicit

Two independent v0.2 continuations existed. Both were valid and both passed
against Brand Interaction Effect v0.6, but they placed provenance responsibility
in different objects. v0.3 reconciles them rather than selecting one branch and
silently discarding the other.

The ownership rule is now:

```text
BrandJourneyPopulation
    owns upstream source / sampling / dedup provenance

BrandJourneyCohortDefinition
    owns local time / classification / feature / outcome / version selection
    and outcome-ascertainment provenance

BrandJourneyPopulationAnalyzer
    composes both into BrandEvidenceCohortProvenance
```

That avoids two opposite errors:

1. pretending the cohort definition knows how an upstream data store sampled or
   deduplicated source material; and
2. losing the exact local selection rule merely because the upstream population
   source was configured separately.

`BrandJourneyPopulation~configureSourceProvenance(...)` declares controlled
source-system, analysis-unit, sampling and deduplication provenance.

`BrandJourneyCohortDefinition~configureSelectionProvenance(...)` declares the
cohort-local selection/inclusion/exclusion/outcome-ascertainment rules.

The v0.2 `configureProvenance(...)` cohort method remains supported as a legacy
full override. Its upstream fields are used only as fallback when the population
has not supplied those facts.

Unknown upstream facts stay `UNSPECIFIED`. Transformation does not create
knowledge.

## Cohort construction is evidence

Every generated `BrandEvidenceFrame` carries sealed
`BrandEvidenceCohortProvenance` describing:

- source kind/system and analysis unit;
- cohort selection rule;
- sampling method;
- inclusion/exclusion policy;
- deduplication method/key kind;
- classifier/taxonomy;
- outcome-ascertainment rule;
- source-candidate, selected, analyzable and excluded counts;
- rejected local duplicate attempts; and
- controlled limitations where provenance is genuinely unknown.

Detailed denominator exclusions remain distinct. Time, classification, feature
schema, outcome kind, classifier, taxonomy, process/model release, aggregate
outcome-window mismatch and indivisible partial buckets are not collapsed into a
single generic exclusion.

## Missing comparison groups fail analytically, not operationally

Brand Interaction Effect v0.6 correctly requires both exposed and unexposed arms
for a 2x2 association estimate. A legitimate journey cohort can nevertheless be
empty, all-exposed, or contain no exposed cases.

v0.3 represents that state as evidence:

```text
EVIDENCE_STATUS=INSUFFICIENT
REASON=STATISTICAL_COMPARISON_GROUP_REQUIRED
REASON=EXPOSED_GROUP_EMPTY
```

or:

```text
REASON=UNEXPOSED_COMPARISON_GROUP_EMPTY
```

The analysis/report still exists, with denominator, time scope, provenance,
materiality and limitations intact. A materially important one-arm case may
remain `MATERIAL_INVESTIGATION`, but it does not become a statistical
association.

The local Wilson uncertainty object exposes `COMPARISON_AVAILABLE=0` when no
valid two-arm comparison exists, preventing placeholder bounds from being
mistaken for inferential evidence.

## Core rules

1. **A denominator is scoped.** Every cohort includes time, journey
   classification, feature/outcome definition, outcome window,
   classifier/taxonomy provenance and optional process/model release constraints.
2. **Provenance follows ownership.** Upstream source facts live on the population;
   local cohort-selection facts live on the cohort definition.
3. **Unknown means unknown.** Source, sampling or dedup facts are not invented to
   make a provenance record look complete.
4. **Association is not causation.** Reports explicitly prohibit interpreting a
   journey feature as having caused an outcome.
5. **Small but important is separate from statistically established.** Existing
   Brand Interaction thresholds preserve `MATERIAL_INVESTIGATION`.
6. **Current windows are not hidden by lifetime aggregates.** Current, previous
   and long-baseline frames remain separate.
7. **Recovery is a stratum, not a causal treatment claim.** Modifier evidence can
   show differing outcomes while retaining `ASSOCIATION_ONLY`.
8. **No customer identity or raw conversation.** The bridge consumes only
   privacy-minimised `BrandJourney` findings/evidence points.
9. **Brand work is not sales authority.** `SERVICE_AS_SALES_JOURNEY` and
   `PROMOTIONAL_WORK` do not become a `SALESPROP` or a sales mandate.
10. **Rejected duplicates are evidence, not denominator inflation.** Duplicate
    attachment attempts are counted in provenance while rejected units are not
    added to source-candidate counts.

## Large populations

A 29,234-interaction report does not need 29,234 live ooRexx objects.
`BrandJourneyPopulationAggregateBucket` accepts privacy-safe grouped counts while
preserving population/outcome/exposure/joint counts, version/time scope,
materiality, modifiers and support/counter evidence.

Aggregate buckets are indivisible. Partial overlap is rejected rather than
silently prorated. A bucket with an outcome-window definition that differs from
the cohort is excluded as a denominator unit and reported separately.

Pre-aggregated buckets explicitly carry the limitation that their upstream count
provenance must be trusted or separately evidenced. Mixed individual/aggregate
unit forms also carry an upstream cross-form deduplication limitation.

## Statistical uncertainty

The final Brand Interaction Effect v0.6 assessment carries:

- 2x2 cells;
- relative-risk estimate and confidence interval;
- conservative risk-difference confidence bounds;
- continuity-correction disclosure;
- confidence null-exclusion gate; and
- cohort-quality gate.

The local Wilson-rate object remains useful journey-specific uncertainty
material, but does not replace the v0.6 inferential evidence.

## Dependencies

- ooRexx 5.3.0 r13196 behaviour profile
- Alchemy Objects v0.8
- ooRexx Crypto v0.1
- Brand Journey v0.1
- Brand Interaction Effect v0.6
- Runtime Registry v0.14 (optional runtime validation)
