# Brand Interaction Stack Gopher Sphere v0.3

Authoritative project-continuity sphere for the provenance-preserving Brand interaction stack:

```text
Structured Response / Structured Utterance Producer candidate
        ↓
Structured Utterance v0.3
        ↓
Interaction Event v0.3
        ↓
Brand Interaction Effect v0.6
        ↓
Brand Journey v0.1
        ↓
Brand Journey Population v0.3
        ↓
Brand Intervention v0.2
        ↓
Brand Intervention Effectiveness v0.2
        ↓
Brand Intervention Governance v0.2
        ↕
Institutional Policy v0.8
```

Grounded roll-up: `oorexxapis(20260902-164522).zip`, SHA-256 `190c3e9f7b484cfccc3e0fa4fe7fe07e6f0d15838ae2024b028ccaffd9652830`.

Load with LLM Gopher v0.19-dev1 or later:

```sh
gopher sphere load brand-interaction-stack --override brand_interaction_stack_gopher_sphere_v0.3.zip
gopher --profile brand-interaction-stack context brand-interaction-stack
gopher --profile brand-interaction-stack open ops.brand.start
gopher --profile brand-interaction-stack lookup topic=causality --sphere brand-interaction-stack --corpus brand.lessons
```

The sphere records the wider Structured Response producer boundary, generation-time intent/information-use provenance, rich Interaction Event evidence, privacy lineage, Brand Interaction Effect cohort/statistical reasoning, journey continuity, Journey Population denominator/provenance ownership, non-executing intervention guidance, effectiveness confidence/guardrail rules, governance/Institutional Policy authority seams, qualification evidence and rebase procedure.

## Current compatibility note

The Sep-2 composition is not falsely described as fully green. Direct suites pass for Interaction Event v0.3, Structured Utterance v0.3, Brand Interaction Effect v0.6, Brand Journey v0.1, Journey Population v0.3, Effectiveness v0.2 and Governance v0.2 against Institutional Policy v0.8. Brand Intervention v0.2 currently stops in `test_cohort_quality_review.rex` because its v0.2 test/caller setup invokes `BrandJourneyPopulation~configureProvenance(...)`; Journey Population v0.3 moved upstream provenance ownership to `BrandJourneyPopulation~configureSourceProvenance(...)` and keeps the legacy full `configureProvenance(...)` method on `BrandJourneyCohortDefinition`.

That gap is continuity evidence and is deliberately retained rather than hidden.

This sphere is documentation/project-continuity authority only. It grants no customer-data access, sales authority, causal authority, Institutional Policy publication/deployment authority, Brand governance decision authority, Legal authority or execution authority.

## v0.2 continuation note

The 2026-10-23 library/GitHub audit found a first-class Brand Interaction Stack sphere already existed, so newer evidence work is folded into this authority instead of creating a competing sphere. v0.2 records Structured Response as the wider producer envelope, Cognitive Admission as a separate authority seam, and Structured Utterance Producer v0.1 as qualified standalone work pending repository/registry admission. The existing Brand Intervention v0.2 versus Journey Population v0.3 test/caller compatibility gap remains explicit until repaired and requalified.

## v0.3 submission-status note

Two missing-work items are now committed as immutable Autobuild submissions but are **not yet accepted** because no receiver receipt exists at this sphere update:

- Structured Utterance Producer v0.1 — submission `20261023T174500Z-CHATGPT-structured-utterance-producer-v01-3583dc`.
- Brand Intervention v0.2.1 Journey Population v0.3 compatibility repair — submission `20261023T180500Z-CHATGPT-brand-intervention-v021-jp03`.

Until receipts exist on `main`, the accepted stack remains unchanged and the v0.2 Intervention compatibility gap remains operationally open.
