# Changelog

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
