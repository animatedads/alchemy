# Changelog

## v0.3

- Requalified the bounded one-tool/one-continuation orchestration contract against AI Access v0.5, Tool Broker v0.4, Alchemy Objects v0.7 and Work Load Units v0.11.
- Preserved generation-stamped stale-offer handling and separate initial-model/tool/continuation execution evidence.
- No direct provider, Secret Broker, network or unbounded agent-loop behavior was added.

## 0.2

- Advanced dependencies to AI Access v0.4 and AI Tool Broker v0.3.
- Added exactly one provider-neutral structured continuation model turn after successful tool execution.
- Continuation messages bind the serialized tool business result to the original provider `call_id`; tool execution metadata is not fed back to the model.
- Continuation sends no tool definitions and rejects any further tool proposal with `AI_TOOL_CONTINUATION_CALL_UNSUPPORTED`.
- Added separate continuation model-generation and WLU execution evidence.
- Added continuation-capacity denial acceptance proving already-performed initial model/tool work remains evidenced/chargeable while the second provider invocation never occurs.

## 0.1

- Added provider-neutral `AIToolOrchestrator` above AI Access v0.3 and AI Tool Broker v0.2.
- Added two-stage `infer()` / `dispatch()` workflow and stable-case `runOnce()` convenience method.
- Model inference uses Runtime Registry v0.13 `routePinnedAbility()` and never calls a provider adapter directly.
- Model Ability sessions are short lived and are released before a pending turn is returned.
- Added plain `AIToolPendingTurn`, `AIToolRunResult` and `AIToolOrchestrationOutcome` data/result objects.
- Added explicit one-tool-per-turn policy; multiple provider tool calls are rejected without partial execution.
- Added generation-race qualification: V1 offer -> model inference -> V2 activation -> `AI_TOOL_OFFER_STALE` -> fresh V2 execution.
- Preserved detached model and tool WLU execution evidence independently.
- Added model- and tool-capacity denial tests proving denial before the relevant dynamic invocation.
- Added non-content Alchemy instrumentation and source authority boundaries.
