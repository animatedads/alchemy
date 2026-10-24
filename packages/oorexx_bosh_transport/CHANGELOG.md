# Changelog

## 0.1-dev6

- Repaired the stale environment runner: removed the deleted `test_bosh_telemetry.rex` reference and stale dev2 completion label.
- Environment qualification now compiles the BOSH core, SocketProvider adapter and Instrumentation adapter, then delegates to the current `tests/run.sh` suite.
- Requires exact caller-supplied Socket Provider and Instrumentation Mesh source roots; it no longer accepts an ambiguous class-directory path.
- Refreshed integration evidence to Socket Provider dev16, Network Transport Intentions dev3, Instrumentation Mesh dev8 and XTP dev25 development context.
- Preserved released dev5 artifact provenance; dev6 is a source reconciliation revision rather than a relabel of the dev5 ZIP.
- Recorded that first-class GitHub source for Socket Provider dev16 and Instrumentation Mesh dev8 remains an upstream publication gate.
- Kept concrete HTTP/HTTPS carrier implementation open rather than adding XTP or HTTP implementation knowledge to BOSH core.


## 0.1-dev5

- Requalified the optional observation layer for Instrumentation Mesh v0.1-dev8.
- Added bounded source-event projection for BOSH session lifecycle and failed HTTP exchanges.
- Added explicit caller-supplied correlation, causation, operation and context references; BOSH never infers them.
- Added direct `snapshot()` / `events()` source composition so one BOSH observer can be registered with Instrumentation Mesh.
- Added dev8 correlation-view qualification proving same supplied correlation groups events and absent correlation is never fabricated.
- Preserved the security/privacy boundary: endpoint URI, target domain, payload, stanza and credentials are not emitted as telemetry/event content.
- Core `BoshTransport.cls` remains free of Instrumentation Mesh, XMPP, TLS, SocketProvider and XTP dependencies.

# CHANGELOG

## 0.1-dev4

- Added a protocol-neutral upper-binding seam for namespaced BOSH body attributes.
- `BoshSession~open()` and `~exchange()` accept opaque extension-attribute directories while fencing all BOSH-owned control attributes (`rid`, `sid`, `to`, `wait`, `hold`, `ver`, `type`, `xml:lang`, default `xmlns`).
- Initial BOSH response payload is now retained and exposed through the returned logical stream; upper bindings no longer need to lose initial feature data.
- Added `BoshSession~exchange(payload, attributes)` for restart/negotiation requests that carry no ordinary payload.
- Requalified the optional instrumentation adapter against Instrumentation Mesh v0.1-dev7. BOSH still owns no telemetry store or management authority.
- Added executable upper-binding qualification. No XMPP names, namespaces or semantics were added to the BOSH core.

## 0.1-dev3

- Replaced package-local telemetry machinery with the estate Instrumentation Mesh adapter.
