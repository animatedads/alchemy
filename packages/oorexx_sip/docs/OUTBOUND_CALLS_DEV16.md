# Outbound calls — dev16

`SipClient~invite(requestUri, localUri, contactUri [, payloadType [, timeoutSeconds]])` is the first outbound user-agent call path.

Object boundary after a successful INVITE/200/ACK:

```text
SipClientDialog   signalling/dialog lifetime and BYE
SipCallControl    application control state
SipInboundAudio   application inbound PCM consumers
SipOutboundAudio  application outbound PCM producers
RtpEndpoint       carrier endpoint
RtpReceiver       RTP receive semantics
RtpSender         RTP send semantics
```

These objects share Call-ID correlation but do not share a single lifecycle. In particular, BYE does not implicitly stop STT/TTS or close RTP; the caller decides the cleanup order and may preserve downstream evidence/consumers while signalling terminates.

The dev16 offer is deliberately bounded to RTP/AVP PT 0 PCMU and PT 8 PCMA. A successful response must include an `m=audio` line. Authentication of outbound INVITE, provisional-response transaction timers, route sets, re-INVITE/UPDATE, fork handling and full RFC 3261 transaction machinery remain subsequent conformance gates.