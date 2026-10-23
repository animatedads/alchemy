# SIP / RTP Instrumentation Mesh integration — dev12

Alchemy Log and Instrumentation Mesh have deliberately different jobs.

* Alchemy Log receives the exhaustive event stream for forensic/debug/audit evidence.
* `instrumentation.mesh/0.1` receives bounded operational state: health, counters,
  gauges, progress, publications and queryable history.

`SipInstrumentationSink` projects SIP-owned events only. Shared RTP has its own
`RtpInstrumentationSink`; SIP does not absorb RTP operational ownership merely
because SIP negotiated the media session.

`SipEventFanoutSink` allows the same structured event to reach Alchemy Log, SIP
instrumentation, RTP instrumentation and other read-side observers. Observer
failure is isolated and cannot fail the SIP call or RTP stream.

Metric snapshots stay aggregate and low-cardinality. Call IDs, registration IDs,
peer addresses and RTP SSRCs remain correlation/event evidence rather than being
promoted into metric dimensions.