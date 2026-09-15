# ooRexx AI Tool Orchestrator v0.3

v0.3 preserves the v0.2 single structured-continuation contract and requalifies it against AI Access v0.5, Tool Broker v0.4, Alchemy Objects v0.7 and WLU v0.11. The package remains provider-neutral: all model work goes through Runtime Registry's canonical `model.complete` Ability route, and all tool work goes through AI Tool Broker tickets.

## Bounded flow

```text
broker offer
  -> initial model Ability (short-lived session, canonical WLU gate)
  -> AIToolPendingTurn (no session/Registry/router/WLU authority)
  -> broker prepareOffered + one-shot tool ticket
  -> canonical pinned tool Ability
  -> typed conversation:
       user(original prompt)
       assistant(original model text + original tool call)
       tool(call_id + JSON business result)
  -> one continuation model Ability
  -> final result
```

No tool definitions are offered on the continuation turn. Any further provider tool proposal is rejected as `AI_TOOL_CONTINUATION_CALL_UNSUPPORTED`; the orchestrator does not create an accidental unbounded autonomous loop. Initial multiple-tool proposals are still rejected without partial execution.

The tool business result must serialize as JSON. Only the business value is placed in the provider-neutral tool-result message; detached tool execution/WLU metadata is not fed back to the model.

## Generation and authority semantics

The model session exists only during each canonical model Ability invocation. The pending turn retains no session. Tool offers remain generation-stamped non-authority data. A V1 offer that becomes stale after V2 activation is refused before tool invocation, and a caller can re-infer against the fresh V2 schema.

## WLU evidence

The three pieces of work are separately evidenced:

- initial model: forecast 700000, actual 200000 micro-WLU;
- tool: forecast 400000, actual 100000;
- continuation model: forecast 700000, actual 500000.

Capacity denial is proven at each meaningful boundary. In particular, continuation capacity can be denied **after** initial model and tool work; the failure preserves both already-chargeable execution records and does not invoke the provider a second time.

## Dependencies

Required:
- Runtime Registry v0.13 / Ability HTTP v0.7
- AI Access v0.5
- AI Tool Broker v0.4
- Alchemy Objects v0.7
- Crypto v0.1

Optional qualification:
- Work Load Units v0.11

There is no OpenAI-specific, Secret Broker or direct network/provider-adapter dependency.
