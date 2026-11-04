> **Connect Selector integration update:** The Connect Selector is intended to
> own the direct/JSON-RPC/Queue choice. This document is retained as a proposed
> **durable job semantic contract**, not as an instruction to build a second
> JSON-RPC-to-Queue route picker. See `CONNECT_SELECTOR_INTEGRATION.md`.

# Durable service admission contract (connector implementation NOT claimed)

This is a **server-side** implementation specification. It does NOT alter the JSON-RPC Fabric core, does not import Queue Fabric on the Python client and does not guess Queue Fabric's current ooRexx method signatures. Before writing the concrete adapter, pin and inspect the accepted Queue Fabric source/API.

## Published and governed operation types

| Operation kind | Example contract name | Server response | Notes |
|---|---|---|---|
| Immediate request | `catalog.lookup` | result JSON or explicit fault | May use direct invocation, not compulsory Queue Fabric |
| Durable submission | `jobs.submit` | `{job_id, accepted, state, correlation_id}` | Queue Fabric admission + genuine persisted receipt required |
| Job status | `jobs.status` | server-defined current state and state revision | Not the same as the previous RPC response |
| Job result | `jobs.result` | result only when terminal; else defined not-ready response | Contract-specific retention semantics |
| Cancellation | `jobs.cancel` | acknowledged cancellation request or conflict | No guarantee already-running work stopped |
| Event notification | `events.hint` | no JSON-RPC response | Not a durable Queue Fabric event subscription |

## Required gateway checks

1. Bind caller identity via authenticated transport / established Alchemy service authority; do not accept client-supplied authority assertions as proof.
2. Enforce named method allowlist + validated JSON schema/version + permitted scope, before touching Queue Fabric.
3. For mutation, require service-defined idempotency key and fingerprint/identity scope; reuse the same durable job receipt on exact replay, reject conflicting replay.
4. Map *real Queue Fabric admission rejection* to an application fault. Return `accepted=true` only after the Queue Fabric contract confirms durable admission. A successful RPC write alone is not proof.
5. Preserve real job ID, timestamps/state revision and error domain. Poll/status must observe the authoritative job state, not reconstruct it from cached HTTP state.
6. Retain cancellation and lifetime rules of the queue provider. For status waiters, bound execution and client timeout independently.
7. Publish versioned structured schemas and conformance tests. No hidden connector failover after timeout. `Queue Fabric` remains optional for immediate services.
8. Emit safe diagnostics via optional Instrumentation Mesh (correlation/operation/outcome, no credential or payload logging).

## Suggested separation

```
JsonRpcDispatcher (existing)
  -> PublishedOperationHandler (explicit service contract)
      -> ServiceAuthority/Policy
      -> ImmediateOperationPort (direct local handler)
      -> DurableJobPort (adapter to accepted Queue Fabric provider)
```

The Python consumer sees one coherent SDK; a server-side service chooses durable vs immediate semantics per operation, never by transport accident.
