# Validation

Qualified on 2026-08-26 with **Open Object Rexx 5.3.0 r13196 — Internal Test Version**.

## Executable tests

9/9 pass:

1. direct Staff Channel service submission through Staff Authority Service;
2. durable maker/checker approval resume;
3. service command idempotency;
4. write-ahead `READY_FOR_CORE` persistence and restart-safe Core retry;
5. typed service-state restart recovery;
6. at-least-once event outbox retry;
7. permanent Queue Fabric typed-command recovery;
8. Relationship Case -> Relationship Adapter -> Staff Channel Service -> Staff Authority Service -> Core Banking full chain;
9. runtime module contract.

## Write-ahead fault probe

A Core port is deliberately made unavailable after Staff Authority succeeds. The service has already persisted `READY_FOR_CORE`; no money moves. A new service instance loads that exact work and replaying the same service command completes the same Core command once.

## Static compilation

All **6/6** package `.cls` files pass `rexxc` under the same runtime/dependency closure. The complete command/test transcript is retained in `VALIDATION_TRANSCRIPT.txt`.
