# SIP dev14 — Instrumentation Mesh dev7 event timeline

SIP continues to emit its authoritative `oorexx.sip.event/1` records to the injected observer fan-out. Alchemy Log remains the forensic event sink.

`SipInstrumentationSink` now additionally exposes `events()` using Instrumentation Mesh dev7 `instrumentation.event/1`. Only bounded operational lifecycle/security facts are projected: server start/stop, wire errors, authentication challenge/accept/reject, registration transitions and call transitions. Raw SIP messages, credentials, contacts, peer addresses and payloads are not copied into the Mesh event timeline.

The Mesh event keeps `SIP_SERVICE` as source authority and uses the source event ID for replay-safe identity. Collector-derived health/relationship changes remain `INSTRUMENTATION_OBSERVER` authority and must never be confused with SIP actions.

Observation time remains caller-supplied. Single Time Service v0.6 is a compatible source of authoritative instants, but SIP does not acquire it and does not make time service lifetime part of a call.