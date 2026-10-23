# Instrumentation Mesh dev8 alignment

SIP and shared RTP retain separate instrumentation emitters and separate authorities. Their operational events may carry the same explicit `correlation_id` (normally the SIP Call-ID), allowing `InstrumentationCorrelationView` to group them read-only.

Each adapter adds a privacy-safe object context reference (`sip-object:<objectId>` or `rtp-object:<objectId>`). Peer addresses, SIP wire text, credentials and media payloads are not added to the Mesh event timeline.

`causation_id` is passed only when the source event explicitly supplies one. Timestamp proximity, shared host, call correlation, or object relationships never fabricate causation.