# RTP Instrumentation — dev7

Dev7 aligns the RTP operational event adapter with Instrumentation Mesh dev8. Explicit call correlation remains a read-side grouping key, never ownership. Each RTP event receives a privacy-safe `rtp-object:<objectId>` context ref. Explicit source `causationId` / `contextRefs` are preserved; causation is never inferred.