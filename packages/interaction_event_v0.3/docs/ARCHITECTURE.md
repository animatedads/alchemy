# Architecture — Interaction Event v0.3

```text
 chat   web-ui   billing   crm   telemetry   agent-runtime
   \       |        |       |       |            /
    +------ external access-point/instrumentation layer ------+
                              |
                              | capture/fire
                              v
                +-----------------------------+
                | Interaction Event v0.3      |
                |                             |
                | rich event model            |
                | evidence + provenance       |
                | assessments                 |
                | event points + links        |
                | privacy-aware projections   |
                | append-only capture library |
                +-----------------------------+
                    |       |       |       |
                    v       v       v       v
               reputation  legal  Shannon  analytics/actions
```

The package is a semantic capture boundary, not a universal customer model and not a telemetry collector.

## Native pre-flattening evidence

Structured language generation knows more than the final string. v0.3 preserves three controlled evidence families on the event itself:

```text
Structured Utterance
    information-use edge  ──> InteractionInformationUseEvidence
    generation intent     ──> InteractionGenerationIntentEvidence
    analyzer finding      ──> InteractionDerivedFinding
                                  |
                                  v
                         Interaction Event v0.3
                                  |
                                  v
                    Brand Interaction Effect v0.6
```

The evidence is deliberately token/scalar-only. Raw customer wording remains in privacy-bearing content elements upstream; a native information-use object can say `CUSTOMER_SENSITIVE + COMMERCIAL_PERSUASION` without copying the sensitive fact itself.

Deidentified projection keeps the structured fact that sensitive information was used and how it was used, while blanking the customer-bearing source reference. Transformation therefore preserves reasoning value without conferring privacy safety on the original source.


## Customer-data reduction

All text-bearing/detail material is represented as `InteractionContentElement` with privacy and retention classification. LLM-generated explanations use exactly the same element type as customer-supplied content, so model output does not receive a privacy exemption.

`InteractionAssessment` reserves its categorical `value` and dimensions for controlled tokens/scalars. Natural-language explanation must be attached as detail elements and therefore participates in projection/redaction.

This allows a full internal event to contain customer-specific evidence while a downstream analytical projection retains only non-customer semantic residue.

## Causal discipline

`InteractionLink` distinguishes link kind from causal status. A temporal or behavioural chain can be strong evidence without becoming a causal fact. `markCandidateTrigger()` always creates `CANDIDATE_TRIGGER / CANDIDATE_NOT_PROVEN`.

A downstream causal or governance component may later create a new, separately sourced link/assessment. The original evidence remains unchanged.

## Style and commercial effect

Communication style is an assessment profile, not a hard-coded good/bad rule. Dimensions can include `SASS`, `ABRUPTNESS`, `DISMISSIVENESS`, `WARMTH`, `CLOSURE_STRENGTH`, `RELATIONAL_REGISTER`, etc. Context and later behaviour determine whether those features are useful, harmless, or commercially disastrous.

Thus the human-facing explanation “you lost the order because you used too much sass” can be rendered from structured evidence without making `SASS` itself the stored causal fact.
