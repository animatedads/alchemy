# Cognitive Continuity v0.1-dev2-exp1 architecture

This is an executable dog-food cut of the v0.5 Cognitive Continuity / Memory Fabric design.

```text
online path
  Structured Response / agent proposal
        -> cognitive admission
        -> append-only journal
        -> typed projections
        -> exact model-context export
        -> ChatGPT / Codex / LLMPA / MCP

nearline path
  journal delta
        -> cognitive.learning.request/1
        -> Queue Fabric
        -> HF / Colab / local / LLM analysis worker
        -> cognitive.learning.result/1 proposals
        -> later admission/integration
```

## Core invariants

- Inference context may compact. Durable cognitive state does not.
- Classification and knowledge integration are constructive operations, not compaction.
- Model/ML output proposes; it does not self-admit or self-verify.
- Authenticated identity, origin, epistemic state and decision authority are server-derived.
- `basisRefs` must appear in the invocation evidence manifest.
- A model-facing projection is disposable and contains an explicit selection trace.
- Nearline learning is Queue Fabric triggered and cannot block the online cognitive path.
- Learning results are proposals only.

## Experimental limitation

The supplied 2026-09-15 API roll-up contains the strict structured-generation machinery used by FlyLo but no obvious standalone platform Structured Response package/class to link here. `CognitiveStructuredResponseBridge` is therefore an explicitly marked compatibility shim, not a new common response authority. Replace it with the platform Structured Response implementation when that package is supplied/published.
