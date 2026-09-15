# Brand Intervention v0.2

`Brand Intervention` is the reasoning-guidance layer above `Brand Journey
Population`. It binds **time-scoped statistical/material evidence** to the
**current privacy-minimised brand journey state** and produces a bounded set of
objectives, avoidances and obligations for another reasoning agent.

It does not execute customer actions. It does not generate canned customer
prose. It does not turn association into causation.

The central rule is:

> An LLM should not be handed a naked verdict such as `SASS_BAD`. It should be
> handed enough weight, measure, time scope, counterevidence and present-state
> context to reason about whether any adaptation is justified and where it
> applies.

## Stack position

```text
Structured Utterance
        ↓
Interaction Event
        ↓
Brand Interaction Effect
        ↓
Brand Journey
        ↓
Brand Journey Population
        ↓
Brand Intervention
  current state + evidence age
  statistical/material sufficiency
  objectives + avoidances + obligations
        ↓
external reasoning / access / action component
```

## Evidence modes

Evidence status drives **what sort of reasoning is justified**, not an action:

- `INSUFFICIENT` → `BASELINE_ONLY`
- `WEAK_SIGNAL` with sound cohort basis → `OBSERVE_ONLY`
- `WEAK_SIGNAL` because the cohort-quality gate failed → `REVIEW_REQUIRED` / cohort evidence-quality review
- `MATERIAL_INVESTIGATION` → `REVIEW_REQUIRED`
- `SUPPORTED` / `STRONG` → `REASONING_GUIDANCE`
- evidence older than policy permits → `REVIEW_REQUIRED` / refresh evidence

A small but commercially important sample therefore remains worth examining
without being promoted to a population-wide behavioural rule.

## Cohort quality is not a tone signal

Brand Interaction Effect v0.6 deliberately keeps independent gates for sample/time sufficiency, effect magnitude, confidence, and cohort-selection quality. Brand Intervention v0.2 preserves that distinction.

A result can therefore have a large denominator, a material point estimate and a confidence interval excluding the null while still remaining `WEAK_SIGNAL` because nobody can establish how the cohort was selected, or because selected-unit missingness / unresolved eligibility exceeds the configured quality threshold. In that case Intervention emits `COHORT_EVIDENCE_QUALITY_REVIEW`, not tone guidance.

The proposal can ask the next reasoning layer to establish explicit cohort-selection provenance, resolve missing selected units or eligibility uncertainty, and reanalyse. It also explicitly prohibits changing behaviour from evidence whose cohort-quality gate failed. A narrow or `CONVENIENCE` sample is not automatically condemned; only the configured evidence-quality gate controls this path.

## Tonality is not a canned response generator

For a supported `HIGH_SASS` signal in unresolved support, the package can
produce objectives such as:

```text
REDUCE_DISMISSIVE_REGISTER
MAINTAIN_SERVICE_ENGAGEMENT
PRESERVE_RESOLUTION_FOCUS
```

and avoidances such as:

```text
UNILATERAL_RELATIONAL_CLOSURE
EXTREME_APOLOGY_AS_DEFAULT_RECOVERY
TREAT_ASSOCIATION_AS_CAUSATION
```

It deliberately does **not** produce `APOLOGISE_EXTREMELY`, nor does it supply a
replacement sentence. Structured Utterance remains the place where language is
realised.

## Service as Sales boundary

Brand significance is preserved:

```text
PROMOTIONAL_WORK
REPUTATIONAL_WORK
RETENTION
```

but it does not confer:

```text
OFFER_PRODUCT
SALESPROP
SALES_AUTHORITY
```

Support and delivery remain promotional/reputational brand interactions without
becoming an automatic upsell channel.

## Time is first-class

`BrandInterventionEvidenceBinding` keeps:

- decision `AS_OF_AT`
- `EVIDENCE_AGE_DAYS`
- temporal authority provenance
- the complete upstream population/temporal reasoning report

A current/previous/long-baseline report is not flattened. Model/process release
provenance and separate denominators survive into the intervention reasoning
material.

## Current-state context

`BrandInterventionContext` contains only privacy-minimised controlled material:

- current domain and journey state
- unresolved/resolved state
- assessed customer sentiment token (explicitly an assessment, not fact)
- issue severity
- journey findings such as context loss/repeat burden
- brand functions/opportunities
- obligations and prohibitions
- stable evidence points

It contains no customer identity or raw transcript.

## Measuring whether intervention helped

`BrandInterventionOutcomeObservation` records whether an external system
actually applied an intervention and what outcome followed. Its causal status is
always `ASSOCIATION_ONLY`.

`BrandInterventionPopulationBridge` turns that observation into a privacy-safe
`BrandJourneyPopulationObservation` exposure so later population analysis can
compare outcomes. The measurement loop therefore asks whether interventions are
associated with better outcomes rather than declaring that they worked because
they were recommended.

## Alchemy

Core domain objects inherit `AlchemyObject`, with disclosure-aware state,
relationships and instrumentation. Customer-safe introspection exposes the
controlled reasoning residue while upstream journey/evidence references remain
internal.

## Dependencies

- ooRexx 5.3.0 r13196 behaviour profile
- Alchemy Objects v0.8
- ooRexx Crypto v0.1 (through Alchemy Objects)
- Brand Interaction Effect v0.6
- Brand Journey v0.1
- Brand Journey Population v0.2
- Runtime Registry v0.14 (optional runtime validation)
