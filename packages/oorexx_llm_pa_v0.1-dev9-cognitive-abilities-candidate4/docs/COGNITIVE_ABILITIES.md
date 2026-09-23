# LLMPA Cognitive Continuity abilities

LLMPA consumes `oorexx_cognitive_continuity_v0.1-dev2-exp1` as the durable cognitive-state authority.  The package is vendored only as a sealed delivery dependency under `deps/`; its journal, admission rules, deterministic baseline classifier, projection planner and model-context exporter are not reimplemented in LLMPA.

## Boundary

```text
Codex / Gemma / ChatGPT
        |
        v
LLMPA Ability Registry (abilities.d)
        |
        v
LlmPaCognitiveRuntime / upstream LlmPaCognitiveAdapter
        |
        v
oorexx.cognitive.continuity/0.1
  admission -> durable JSONL events -> classification -> projection
```

Inference/model context is disposable and may be compacted by the client.  Durable cognitive state is not subject to a token-budget or model-context compaction rule.  A context export is regenerated from durable state.

## Registered abilities

- `cognitive.records.query` — durable admitted records in the active scope.
- `cognitive.continuity.query` — continuity and argument records.
- `cognitive.context.project` — bounded disposable projection with selection trace.
- `cognitive.context.export` — exact `cognitive.model-context/0.1` model input plus projection trace.
- `cognitive.context.explain` — reason trace for an in-process projection id.
- `cognitive.classification.explain` — memory class, classifier identity and selection reason for a durable record.
- `cognitive.learning.delta` — nearline classifier/ML feed; read-only and non-promoting.
- `cognitive.effects.propose` — typed model proposals through Cognitive Admission.

The generic registry surface is sufficient; these abilities do not require new parser branches:

```text
pa-tool abilities cognitive
pa-tool cognitive.records.query '{}'
pa-tool cognitive.context.export '{"task":"resume QueueRexx qualification","limit":24}'
pa-tool cognitive.classification.explain '{"record_id":"cog-000000001"}'
pa-tool cognitive.effects.propose '{"effects":[{"kind":"OPEN_QUESTION","subjectRef":"queuerexx","statement":"Is cross-node Queue Fabric request/reply qualified?"}]}'
```

The Queue-backed client uses the same registry:

```text
llmpa abilities cognitive
llmpa ability cognitive.context.export '{"task":"continue current work","limit":32}'
```

## Authority

`cognitive.effects.propose` always uses the configured model/worker actor.  The caller cannot choose an actor or provide authority fields.  The upstream admission service derives:

```text
origin
assertionClass
epistemicState
decisionAuthority
verificationState
```

A model-authored `DECISION` therefore remains a proposed decision unless an external authority accepts it.  A model cannot turn its own statement into `TOOL_VERIFIED` evidence.

The compatibility operator actor exists for explicit operator-origin integrations, not as a shortcut for model calls.

## Continuity

`continuity.current` v0.2 first queries durable Cognitive Continuity events.  If the legacy `LlmPaContinuityBrief` exists it is returned separately under `brief_projection` with `authority=PROJECTION_ONLY` and `regenerable=true`.

Deleting the prose brief, the current model prompt, or the chat transcript must not delete admitted cognitive state.

## Projection and classification diagnostics

The model-facing export carries both the exact input and `projectionTrace`.  A retrieval miss therefore remains distinguishable from forgetting: the underlying record remains durable, and the trace/classification surfaces allow a caller to diagnose classification/filter/budget errors.

`cognitive.context.explain` refers to an in-memory projection id and is therefore most useful through the long-lived LLMPA daemon.  A one-shot `pa-tool` process already receives the full `projectionTrace` directly from `cognitive.context.export`.

## ML boundary

`cognitive.learning.delta` exposes durable classified records to a nearline learner.  The learner may propose richer classification or skill candidates, but the online correctness path does not wait for it and learned output cannot self-admit or self-promote.
