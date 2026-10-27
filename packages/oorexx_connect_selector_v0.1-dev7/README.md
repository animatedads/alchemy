# ConnectSelector v0.1-dev7 — source checkpoint and qualification

Complete, distributable replacement archive: `oorexx_connect_selector_v0.1-dev7.zip`
SHA-256: `146a9f89368b29c790629500dd932a881da283119b5abdeeada7bb74e5e27313` (24 files, 23 members hashed in MANIFEST.sha256).
API: `oorexx.connect_selector/0.1`.
Interpreter tested: ooRexx 5.3.0 r13196 (Linux x86_64 debug package).

## Qualified change from dev6
The injected JMS port can throw after observable side-effects. Dev7 catches a narrow, effect-sensitive set of broker/queue exceptions and returns:
- `RECEIVE_UNCERTAIN`: receive exception, no queue operation attempted
- `QUEUE_COMMIT_UNCERTAIN`: QueueFabric put/dispatch exception, no JMS ack/forced recover
- `RECOVERY_UNCERTAIN`: JMS recover exception after a rejected queue operation
- `ACK_UNCERTAIN`: durable queue acceptance preceded a thrown JMS ack; durable=true
- `SEND_UNCERTAIN`: broker send exception, no ack/nack of claimed queue item
- `QUEUE_ACK_UNCERTAIN`: broker accepted, queue ack exception, accepted=true

Exception diagnostics report only RC, SIGL, condition code and a redacted-detail-presence indicator; exception description/payloads/credentials never appear in the returned receipt. The broker may already have accepted an outbound send; no automatic resend, provider switch, or immediate nack is authorized.

## Reproducible evidence
- Six production ooRexx classes compile with `rexxc`.
- All existing and six new negative JMS exception checks pass; complete pinned dependency-backed ConnectSelector regression passes.
- Actual persistent QueueFabric dev6 journal restart and durable ack pass.
- Actual RPC Service Core dev1, SOAP Binding dev2, JSON-RPC dev3, Alchemy Objects 0.8.2, Crypto 0.8.3, Instrumentation Mesh dev7 integration passes.
- Fifteen actual RTO2 Grid **dev15** MU/MI membership checks pass, with a simulated runtime port.
- Strict ooRexx standards checker: 17 files scanned, 0 errors, 0 warnings.
- MANIFEST.sha256 verification and ZIP integrity: PASS.

## Boundaries / missing work
This repository subtree is a **dev6→dev7 source/test patch and qualification record**, not the complete 24-file source import. Full distributable source is in the named archive, pinned by SHA-256. Import complete source and re-qualify its exact byte contents before treating this GitHub subtree as the authoritative executable release.

No live JMS broker or transaction/interoperability test; no live RTO2 failover, promotion or direct-socket invocation; no network security or gRPC streaming qualification. RFE #882 ADDRESS CommandHandler needs ooRexx r13289+ and is being qualified separately; r13196 cannot prove it.

See `spheres/connect_selector_gopher_sphere_v0.1/qualification/CONNECT_SELECTOR_DEV7_JMS.md`.
