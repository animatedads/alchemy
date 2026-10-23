# RTP dev6 — Instrumentation Mesh dev7 event timeline

RTP remains independent from SIP and owns its own instrumentation identity. `RtpInstrumentationSink~events()` now exposes bounded `instrumentation.event/1` observations for endpoint/receiver/sender lifecycle and dropped-frame warnings.

Per-frame traffic remains metrics, not an event flood. Payload, peer identity and audio content are never placed in the Mesh event timeline. Alchemy Log remains the forensic plane.

Observation time is supplied externally. Single Time Service may provide an authoritative instant but is not a runtime dependency of RTP.