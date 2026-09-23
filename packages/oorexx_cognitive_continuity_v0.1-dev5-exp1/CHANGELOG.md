# Changelog

## 0.1-dev5-exp1

- Add bounded, evidence-bound `COGNITIVE.DOGFOOD.OBSERVE` measurement ingestion for historical ChatGPT/Codex runs that predate native projection receipts.
- Keep dog-food observations measurement-only (`MEASUREMENT_ONLY_NOT_COGNITIVE_AUTHORITY`); they cannot directly become admitted memory.
- Add `dogfoodObservations` to the backward-compatible `cognitive.learning.request/2` bundle so Qwen receives real client/retrieval failures alongside corpus and projection evidence.
- Add the Safety29/Codex real dog-food example: successful artifact-resolution episode, reply-correlation failure, cognitive-context bypass, and corrected task-aware projection.

## 0.1-dev5-exp1

- Make context projection genuinely task-aware.
- Add deterministic relevance scoring over subject/object/relation/statement semantics.
- Exclude unrelated durable records from a task projection with `TASK_FILTER_MISMATCH` rather than deleting or compacting them.
- Preserve broad scope projection when no discriminative task is supplied.
- Add Safety29-vs-QueueRexx regression coverage.


## 0.1-dev3-exp1

- add separate dog-food trace journal for exact model projection receipts;
- add model outcome/utility feedback without mutating cognitive memory;
- add learning bundle combining corpus deltas with projection receipts and outcomes;
- bump nearline learning request/result contracts to v2;
- expose dog-food receipt/outcome operations through MCP;
- keep all measurement traces outside authoritative cognitive state.
- align Queue Fabric NACK adapter with v0.9-dev5 `(queue, packageId, claimToken, principal)` authority signature; do not pass an options table in the principal position.

## 0.1-dev2-exp1

- rename external mutation semantics from submit to propose (legacy dispatch alias retained);
- bind proposal `basisRefs` to invocation evidence manifest;
- separate origin, epistemic state and decision authority;
- add deterministic baseline record classification;
- add reason-traced context projection and exact model-input export;
- add classification explain and projection explain;
- add Queue Fabric compatible learning delta/request/result contracts;
- add provider-neutral LLMPA/model-context adapter;
- add explicit Structured Response compatibility bridge pending the actual platform package;
- expand MCP surface for dog-food observability.
