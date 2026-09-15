# Legal Effect -> Evidence Promotion -> HardWorld (v0.17)

## Purpose

v0.16 made rich source evidence first-class. v0.17 makes the **promotion from evidence/assessment to a
HardWorld fact** first-class as well.

A promotion is not a legal rule and is not a HardWorld rule. It is an evidence-bearing record that says:

> this particular authority/policy/rule, evaluated over this pinned evidence closure, is entitled to propose
> this HardWorld fact in this epistemic state/value.

Application remains a separate operation.

## Domain-neutral object family

```text
EvidencePromotionBasis
EvidencePromotion
EvidencePromotionSet
EvidencePromotionBundle
EvidencePromotionApplyResult
EvidencePromotionApplier
```

`EvidencePromotionSet` rejects duplicate promotion IDs and canonicalises independent of insertion order.
When several authorised promotions agree on a target fact, HardWorld receives one fact with an
`EvidencePromotionBundle` retaining every agreeing promotion. If authorised promotions disagree on value,
HardWorld receives `CONFLICT`; one promotion is never silently chosen.

A promotion whose actual consistency grade is weaker than its minimum required consistency is skipped.
Temporal evidence quality therefore remains a hard eligibility dimension, not a score.

## Legal Effect adapter

`LegalEffectPromotionAdapter.cls` contains three distinct layers:

1. `LegalEffectGenerationSnapshot` — deterministic snapshot of the public legal generation closure;
2. `LegalEffectEvaluationInputSnapshot` — generation + action + current-context authority input;
3. `LegalEffectAssessmentEvidence` / pinned envelope — immutable evidence identity for the returned assessment.

`LegalEffectPinnedEvaluator` performs:

```text
snapshot generation/action/context
        -> evaluate Legal Effect
        -> snapshot generation/action/context again
        -> compare closure identities
        -> reject on drift
        -> reject unsupported status-reduction ambiguity
        -> issue pinned authority envelope
```

Only a pinned envelope is accepted by `LegalEffectPromotionAdapter~promotionsFrom` for authority-bearing
promotion.

## Why the extra pin is necessary

Legal Effect v0.1's `LegalRuleGeneration~seal` protects mutation through generation methods but does not
deep-freeze objects already inserted into the generation. The test can obtain a sealed norm and mutate:

```rexx
norm~conditions~append(...)
```

The same generation ID/version can then produce a different legal result. v0.17 therefore binds authority
to content, not labels.

The pin also includes action mutation sources and current-context fact sources. Any object participating in
an authority-bearing input must either be scalar/.nil or provide `algorithmCanonicalText()`. An opaque
object is rejected as `LEGAL_EVALUATION_INPUT_UNPINNABLE`.

## Order sensitivity

The v0.1 evaluator observes some collection order. v0.17 preserves order in identity wherever changing
order can change either the result or reported evidence. In particular, generation norm order and norm
jurisdiction-claim order are not sorted away.

Conversely, maps/sets that are semantically lookup collections are canonicalised by key.

## Status-reduction ambiguity

Legal Effect v0.1 does not define a general precedence relation between every matched disposition. In
particular, a combination involving REVIEW/STATUS_EFFECT and REQUIRES_OBLIGATION can depend on sequential
reduction. v0.17 refuses to turn that combination into authority with:

```text
LEGAL_STATUS_REDUCTION_AMBIGUOUS
```

unless a stabilising blocked/unresolved state already dominates the assessment.

This is intentionally conservative. A future Legal Effect version should own an explicit precedence/
conflict rule; HardWorld must not invent legal doctrine inside the adapter.

## Algorithm Relation surface

`EvidencePromotionAlgorithmProvider` exposes scalar audit relations while keeping the promotion/native
assessment objects internally reachable. Querying the relations does not apply a promotion. The explicit
applier does that later.

This permits:

```sql
SELECT target_fact, promotion_status, authority, rule_id, disposition
FROM evidence_promotions;
```

without making SQL itself an authority transition.

## Structured Relation v0.7 handoff

`LegalEffectStructuredRelationBridge` adapts `RichBusinessFact` through the v0.16 rich-evidence adapter.
Native XML/EDIFACT/X12/Git/code evidence objects remain owned by Structured Relation and reachable through
the legal fact's source evidence.

The legal bridge maps only explicit source fact states:

- KNOWN / PRESENT / PRESENT_EMPTY -> known legal fact;
- UNKNOWN -> unknown legal fact;
- CONFLICT -> conflict legal fact.

It does not reinterpret the source format as legal meaning.

## Non-claims

v0.17 does not:

- fix Legal Effect v0.1's object graph in place;
- define conflict-of-laws or legal hierarchy;
- interpret XML/X12 fields as legal concepts automatically;
- make Structured Relation findings authoritative;
- make SQL reads apply promotions;
- make LLM output executable authority.
