# RTP instrumentation — dev4

`RtpInstrumentationSink` is a read-side projection of existing structured RTP
events into `instrumentation.mesh/0.1`. It has no carrier, call-control or media
mutation authority. It deliberately does not fabricate jitter/loss/rate facts;
those metrics are added only when the RTP objects calculate them authoritatively.