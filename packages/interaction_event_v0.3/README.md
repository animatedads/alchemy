# Interaction Event v0.3

## v0.3 — native structured evidence seam

v0.3 closes the interface gap introduced by Structured Utterance v0.3 and consumed by Brand Interaction Effect v0.6. `InteractionEvent` now carries first-class native pre-flattening evidence objects:

- `InteractionInformationUseEvidence` — how customer/other information was used by a communicative act, including source lineage/privacy floor, declared use and effective use.
- `InteractionGenerationIntentEvidence` — the intended act/register/outcome and the information-use evidence it relied on.
- `InteractionDerivedFinding` — controlled analyzer findings with opaque evidence references.

These are evidence objects, not free-text metadata. Identifiers, authority fields, use/intent/finding values and evidence references are constrained to opaque tokens/scalars so prose cannot be hidden in a supposedly safe field. Attachment seals each native evidence object, and the parent event seals/canonicalises it as part of the event residue. Duplicate native evidence identifiers are rejected.

The deidentified projection preserves the analytically useful structure while removing a customer-bearing `sourceRef`; the source privacy class, lineage kind, effective use, intended act and derived finding remain available. This lets downstream effect reasoning detect, for example, sensitive-information commercial repurposing without receiving the underlying customer wording.

Compatibility tags may still exist for cheap routing, but downstream authority belongs to the native evidence objects. This is intentionally compatible with Structured Utterance v0.3 and Brand Interaction Effect v0.6.

The Alchemy substrate remains compatible with the v0.7 adoption surface and is qualified against the current v0.8 baseline; Runtime Registry integration is qualified against v0.14.

## v0.2 — Alchemy object substrate

v0.2 adopts `AlchemyObject` v0.4.3 for the evidence-bearing aggregate objects rather than rebuilding lifecycle, telemetry, state disclosure, introspection and relationship evidence locally. `InteractionEvent`, `InteractionContentElement`, `InteractionAssessment`, `InteractionLink` and `InteractionCaptureLibrary` are Alchemy objects. Raw interaction content and customer-linked references are registered `SECRET`; semantic event identity remains disclosure-bounded. Capture, assessment attachment, link creation, event sealing and privacy projection leave inherited instrumentation evidence. Relationships are recorded as detached identity evidence so telemetry does not keep domain objects alive.

The operational boundary is unchanged: access-point instrumentation remains external, assessments remain assessments rather than facts, and causal candidates remain `CANDIDATE_NOT_PROVEN`.

`Interaction Event` is an independent ooRexx model and capture library for rich interaction events.

It is deliberately **not** an instrumentation framework. Chat/UI/billing/CRM/telemetry/agent-runtime access points are owned elsewhere. Those components fire rich events into this library; this library gives them a common shape, preserves evidence and provenance, exposes stable event points, retains model assessments as assessments rather than facts, links behaviour to later steps/outcomes without silently claiming causation, and produces customer-data-reduced projections.

## Why this exists

A useful commercial/reputation/legal record needs to preserve far more than `customer sentiment = negative`.

Example sequence:

- agent says `I'm done.`;
- a communication-style assessor reports high `SASS`, `ABRUPTNESS`, `DISMISSIVENESS`, and `CLOSURE_STRENGTH`;
- subscription management is opened;
- cancellation is entered and confirmed;
- the chat is exported/deleted;
- a negative external communication is later observed.

The library can retain all of that and expose the agent response as a `CANDIDATE_TRIGGER`, while keeping causal status `CANDIDATE_NOT_PROVEN` unless a separate authorised component promotes it.

## Core invariants

1. **Access points are external.** `accessPointId` records where an event was fired, but this package does not instrument chat, web UI, billing, CRM, social surfaces, or telemetry.
2. **Events are rich and append-only.** Events seal before capture and expose stable `INTERACTION_EVENT:<eventId>` points.
3. **Assessments are not facts.** Multiple sentiment/style/engagement assessments may attach to the same event and disagree.
4. **Controlled assessment values.** Assessment values and dimensions are token/scalar fields. Prose explanations belong in privacy-tagged detail elements, preventing a model from smuggling customer text into an apparently safe score field.
5. **Privacy is element-level.** Raw content is split into tagged elements with semantic type, origin, privacy class, retention class, optional abstraction, source reference/span, and confidence.
6. **Unknown privacy fails closed.** A de-identified projection drops `UNKNOWN` content even if somebody supplied a tempting abstraction.
7. **Customer-specific raw data can disappear while semantic residue remains.** A serial/name/address can be removed while `SUPPLIED_NETWORK_EQUIPMENT`, `REPEATED_PRODUCT_FAILURE_WITHIN_RECENT_PERIOD`, complaint/semantic-act and assessed frustration remain.
8. **Links express evidence and candidate causality.** `PRECEDES`, `RESPONDS_TO`, `STEP_OF`, `OUTCOME_OF`, `RECOVERY_FROM`, `EVIDENCE_FOR`, and `CANDIDATE_TRIGGER` are first-class.
9. **Causal claims are explicit.** Candidate links use `CANDIDATE_NOT_PROVEN`; the library never upgrades temporal association into causation on its own.
10. **Absence is an event when observed.** Thirty minutes with no mouse/scroll/navigation/data-pull while keepalive remains present can be captured as `ENGAGEMENT_ABSENCE`; a model may then separately assess `POSSIBLE_DISENGAGEMENT`.
11. **Downstream domains stay separate.** Reputation Effect, Legal Effect, Shannon, analytics, or commercial-action engines consume projected events/points; they own their own decisions.
12. **Runtime publication is registry-compatible.** `InteractionEventRuntimeModule` can be staged by Runtime Registry.

## Privacy classes

- `PUBLIC`
- `ORGANISATION`
- `DERIVED_NONCUSTOMER`
- `CUSTOMER_PSEUDONYMOUS`
- `CUSTOMER_SPECIFIC`
- `CUSTOMER_SENSITIVE`
- `UNKNOWN`

The default `DEIDENTIFIED_ANALYTIC` projection retains raw `PUBLIC`, `ORGANISATION`, and `DERIVED_NONCUSTOMER` values. Customer classes are emitted only through an explicitly supplied `abstractValue`. `UNKNOWN` always drops. `DROP` always drops. `ABSTRACT_ONLY` requires an abstraction.

This is intentionally suitable for LLM-derived material: if an LLM repeats or invents customer-specific content, the generated content element must carry the corresponding privacy class. The safe analytical fields (`assessmentType`, categorical `value`, dimensions) are deliberately constrained to tokens/scalars.

## Representative API

```text
event.addInformationUse(evidence)
event.addGenerationIntent(evidence)
event.addDerivedFinding(finding)
captureEvent(event)
attachAssessment(assessment)
pointFor(eventId)
linkEvents(...)
markCandidateTrigger(...)
assessmentsFor(eventId)
linksFrom(eventId)
linksTo(eventId)
eventsForCorrelation(correlationId)
projectEvent(eventId, policy)
```

## Running

Validated with the supplied ooRexx 5.3.0 r13196 debug build.

```sh
export REXX=/path/to/rexx
export RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.13
./run_tests.sh
```

`RUNTIME_REGISTRY_ROOT` is optional; when present the staging/activation/acquisition test is run.
