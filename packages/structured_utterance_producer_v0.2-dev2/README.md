# Structured Utterance Producer v0.2-dev2

Provider-neutral pre-flattening handoff for `structured.utterance/0.3`.

The component closes one narrow seam: an orchestrator/producer which still knows generation intent, information lineage, semantic acts and privacy relationships can hand those native objects into a sealed generation plan. The producer materializes a sealed `StructuredUtterance` and only then renders delivery text.

It deliberately **does not reconstruct structure from a completed provider string**. `FLATTENED_REPLY_INSUFFICIENT` is a successful fail-closed result: strings such as `<<SALESPROP>>...` are text, not evidence authority.

Pipeline:

```
model/provider planning or application orchestrator
       |  generation-time typed semantic evidence
       v
StructuredUtteranceGenerationPlan
       |  seal before flattening
       v
StructuredUtteranceProducer
       +--> sealed StructuredUtterance v0.3
       +--> delivery rendering
       +--> deidentified analytic rendering
       +--> bounded production provenance
```

The plan reuses Structured Utterance's native `StructuredUtteranceSegment`, `UtteranceCommunicativeAct`, `UtteranceInformationUseEdge`, `UtteranceGenerationIntent` and lineage objects. This package does not create a second semantic taxonomy.

Provider invocation mechanics remain with AI Access/provider owners. Brand context remains descriptive evidence and never confers sales authority. Effect/causal/legal/security decisions remain downstream.


## v0.2-dev2 — Structured Response convergence

The platform architecture now makes a stricter ownership distinction: Structured Response owns the common request/result/receipt/evidence/warning/error/timing/authority envelope. This package does **not** implement or clone that envelope.

Instead, `StructuredUtteranceProductionPayload` is a typed **domain result payload** (`structured.utterance.production-result/0.1`) which can be carried by the external Structured Response API when that owning implementation is available. It contains only Structured Utterance production-domain fields and deliberately excludes common response vocabulary such as request IDs, receipts, warnings/errors, timing and authority/admission fields.

`StructuredUtteranceProducer~producePayload(plan)` is additive. Existing `produce(plan)` and API `structured.utterance.producer/0.1` remain unchanged.

This source is a development candidate. The 2026-10-23 manual publication of v0.1 was not Autobuild-qualified, and Autobuild is currently not running; fresh r13196 qualification is therefore tracked separately rather than invented in this package.


## v0.2-dev2 — fail-closed nil guard correction

ooRexx boolean `|` and `&` evaluation is eager. A guard such as
`x == .nil | \x~isA(...)` can therefore send a message to `.nil` before the
guard can return its documented controlled failure. dev2 replaces every such
public-path guard in this package with sequential checks. The API remains
`structured.utterance.producer/0.1` and the Structured Response ownership
boundary is unchanged.
