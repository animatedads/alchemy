# ConnectSelector dev7 — JMS exception qualification (2026-10-27)

Source artifact: `oorexx_connect_selector_v0.1-dev7.zip`
SHA-256: `146a9f89368b29c790629500dd932a881da283119b5abdeeada7bb74e5e27313`.
Older complete baseline: dev6 `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae`.
API stable: `oorexx.connect_selector/0.1`.

## Authority
ConnectSelector remains a provider-neutral invocation selector, not the owner of JMS transactions, QueueFabric leases, RTO2 promotion/fencing, RPC registry, or serialization. JMS bidirectional bridge must preserve persistence-before-ack in the inbound direction and broker-acceptance-before-queue-ack outbound.

## Dev7 exception semantics
1. Receive error: `RECEIVE_UNCERTAIN` with no QueueFabric put.
2. Queue put/execute exception: `QUEUE_COMMIT_UNCERTAIN`; no JMS ack or forced recover, because a commit may have occurred.
3. Failed queue put plus broker recover exception: `RECOVERY_UNCERTAIN`; do not claim confirmed redelivery.
4. Durable queue acceptance plus JMS ack exception: `ACK_UNCERTAIN`, preserving `accepted=true`, `durable=true`.
5. Broker send exception: `SEND_UNCERTAIN`; broker may have accepted; do not ack or nack QueueFabric.
6. Accepted outbound broker send plus QueueFabric ack exception: `QUEUE_ACK_UNCERTAIN`, preserving `accepted=true`.

Receipt messages and diagnostic announcements never expose raw exception descriptions. No silent retry after uncertain dispatch. At-least-once and idempotent consumers remain necessary.

## Qualification
Tested locally on ooRexx 5.3.0 r13196 x86_64 Linux internal debug interpreter extracted from Library. Six production classes compiled; all ConnectSelector tests passed, including real persistent QueueFabric restart, real shared SOAP/JSON-RPC object dispatch, real Instrumentation Mesh observation fault isolation, and real RTO2 dev15 Grid identity/incarnation guards against a **simulated runtime port**. Strict standards: 17 scanned, 0 errors, 0 warnings. Archive manifest and ZIP integrity verified.

Separate RFE #882 `ADDRESS` CommandHandler/prolog qualification is assigned in Rasen Falcon request REQ-00000447 to CODEX-PC as **testing only** using r13289+; r13196 is not a substitute. This dev7 checkpoint does not assert that feature's acceptance.

## Git and coordination
This document and `packages/oorexx_connect_selector_v0.1-dev7/` source/test delta are a repository checkpoint, **not** a complete GitHub import of the distributable ZIP. Do not silently conflate dev6, dev7 or the separate ADDRESS example.

Next: full 24-file source import + byte verification, broker-backed JMS integration, and authenticated live RTO2 runtime/failover evidence. Standalone QUIC Socket Provider was observed in Library but is not an implied RTO2 port qualification.
