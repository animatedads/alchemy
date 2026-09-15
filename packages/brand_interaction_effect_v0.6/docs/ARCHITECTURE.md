# Brand Interaction Effect v0.6 Architecture


## v0.6: selection lineage before statistical interpretation

```text
source event store / analytics source
        |
        v
BrandEvidenceCohortAccumulator
  candidate deduplication
  INCLUDE / EXCLUDE / UNKNOWN
  incomplete exposure/outcome kept as missing
        |
        +--> BrandEvidenceCohortProvenance
        |      source + unit kind
        |      selection rule + sampling method
        |      inclusion/exclusion policy
        |      dedup method/key kind
        |      classifier/taxonomy
        |      outcome ascertainment
        |      selection/missingness/duplicate counts
        |      controlled limitations
        |
        v
BrandEvidenceFrame
  analyzable 2x2 counts
        |
        v
BrandEvidenceEngine
  sample/time gate
  effect-size gate
  confidence gate
  cohort-quality gate
        |
        v
scoped association evidence
```

The provenance object deliberately contains no source unit identifiers. Those opaque keys are used only for accumulator deduplication. Exclusion and unresolved-selection reasons are controlled tokens with counts.

The cohort-quality gate is deliberately narrow. It can require provenance, selected-unit analysis completeness, bounded unresolved eligibility, and an explicit selection rule. It does **not** infer that `CONVENIENCE`, a low selected percentage, or any other named sampling method is automatically biased. Those facts are evidence for downstream reasoning.

## v0.5: population weight, uncertainty and deduplication

```text
privacy-minimised interaction units
        |
        | one opaque analysis key once
        v
BrandEvidenceCohortAccumulator
        |
        v
BrandEvidenceFrame
  denominator + outcome + exposure + joint count
  time scope + classifier/taxonomy + outcome window
        |
        +--> configured size/effect thresholds
        |
        +--> BrandStatisticalEvidence
               2x2 counts
               RR + confidence interval
               risk difference + confidence interval
               explicit approximation method
        |
        v
BrandEvidenceAssessment
        |
        v
BrandEffectEvidencePacket
        |
        v
reasoning model
```

`SUPPORTED` and `STRONG` require the configured sample/time gate, an effect-size gate and (by default) confidence bounds excluding the null in the observed direction.  The uncertainty calculation is intentionally named and exposed so a downstream LLM sees the method rather than receiving the word `statistically significant` as an unexplained label.

The cohort accumulator owns deduplication and selection-accounting mechanics, but not the business rule that decides eligibility. Access-point instrumentation and customer identity remain external. Callers supply an opaque analysis-unit key plus controlled selection state/reason; the accumulator preserves the declared rule/policy ids and resulting counts without receiving customer prose.


## Native structured-evidence authority

```text
InteractionEvent v0.2
    native derived finding / intent / information use
                 |
                 v
BrandInteractionEventBridge v0.4
    filters producer string assertions
    regenerates controlled observation tags from native evidence
                 |
                 v
BrandInteractionEngine
    brand-effect assessment only
    no legal or causal promotion
```

Compatibility tags remain convenient inside Brand Interaction observations, but the bridge creates them from native evidence rather than trusting producer-authored strings. This keeps routing cheap without turning a tag into evidence authority.


```text
Agent / LLM
   |
   v
Structured Utterance
   |  purpose + customer-data lineage + brand context
   v
Interaction Event
   |  observed events + disagreeable assessments
   v
Brand Interaction Episode
   |  single-journey findings / candidate hypotheses
   |
   +------------------------------+
   |                              |
   v                              v
Statistical/Temporal Evidence   Named external causal review
   |                              |
   | population + joint counts    | authority + scope + decision ref
   | time + classifier provenance |
   | thresholds + effect size     |
   | support/counter evidence     |
   v                              v
Tone / Appropriateness Report   Causal Promotion
   |
   v
Reasoning LLM / Reputation / Legal / Commercial / Action wiring
```

## Evidence invariants

1. The denominator travels with the numerator.
2. Population class and from/to observation time are mandatory.
3. Outcome lag/window is explicit.
4. Classifier and taxonomy versions are frozen into the frame.
5. Statistical sufficiency and material significance are separate.
6. A supported aggregate claim remains `ASSOCIATION_ONLY` unless an authorised external causal process establishes more.
7. Supporting evidence is mandatory; strong claims also require counterevidence or a scope boundary.
8. Recent windows can be compared with previous and long-baseline windows rather than flattened into lifetime history.
9. Assessment disagreement is retained as provenance, not overwritten.
10. Privacy cannot become less restrictive merely because representation changed.
11. Confidence/uncertainty is exposed separately from raw sample-size sufficiency and point effect size.
12. Association intervals never promote themselves to causal authority.
13. Cohort construction deduplicates analysis units before counts become evidence.
14. Source-candidate selection, exclusion, unresolved eligibility and missingness remain visible after the 2x2 frame is built.
15. Cohort provenance can gate support, but the capture layer does not label sampling strategies as biased or causal.

## Service as Sales invariant

`PROMOTIONAL_WORK`, `REPUTATIONAL_WORK` and `RETENTION_OPPORTUNITY` describe the significance of the brand interaction.  They are not action authority and do not imply `SALESPROP` or upsell permission.

## v0.3: pre-flattening commercial-use evidence

Structured Utterance v0.2 can expose a controlled finding when customer-sensitive information structurally participates in a sales proposition. The Brand Interaction Event bridge copies Interaction Event tags but never requires the raw customer wording.

```text
Structured Utterance v0.2
  sensitive lineage
       |
       | JUSTIFIES / PERSONALISES / RISK_AVOIDANCE
       v
  SALESPROP
       |
       v
Interaction Event v0.1
  STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING
       |
       v
Brand Interaction Effect v0.3
  SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING
```

The brand finding is intentionally not a legal conclusion and not a causal statement. It says that a customer-sensitive information dependency was used in commercial persuasion according to pre-flattening structure. Whether that use is lawful, prohibited, acceptable, manipulative or merely poor judgement remains for Legal Effect, organisational policy and other authorities.

`DECLARED_INFORMATION_USE_MISMATCH` is separately preserved when the generating model's own declared use disagrees with the effective use derived from act/relation structure. This can later distinguish failures of intent, failures of language realisation and failures of downstream policy.

`BrandInteractionEngine` inherits `AlchemyObject` v0.4.3. The inherited object surface supplies identity, lifecycle telemetry, method-contract evidence and instrumentation without changing causal authority.
