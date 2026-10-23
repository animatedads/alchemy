# Instrumentation

BOSH core exposes `BoshObserver` only. It does not own a metrics database or management plane.

`BoshInstrumentationAdapter.cls` optionally maps BOSH operational facts into the estate Instrumentation Mesh `instrumentation.mesh/0.1` vocabulary. dev5 is qualified against `oorexx_instrumentation_mesh_v0.1-dev8`.

Payload, identities, endpoint credentials and upper-protocol content are never published as instrumentation dimensions. Observation grants no BOSH management authority.


## Explicit correlation only (dev5)

`BoshInstrumentationObserver` can now project bounded source events through Instrumentation Mesh dev8. `correlation_id`, `causation_id`, `operation_id` and `context_refs` are constructor-supplied context and are copied verbatim. They are never synthesized from endpoint identity, timestamps, carrier selection, HTTP status, session reuse, or the contents of a BOSH/XMPP payload. The same observer object exposes `snapshot()` and `events()` so it can be registered directly as one Instrumentation source.
