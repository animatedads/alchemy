# Structured Utterance Producer v0.1

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
