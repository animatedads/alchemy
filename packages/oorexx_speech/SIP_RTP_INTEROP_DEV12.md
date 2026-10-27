# SIP/RTP compatibility qualification — dev12

Dev12 does **not** add another SIP/RTP adapter. SIP dev15 already owns the
published `sip.speech.bridge/0.1` translation seam in `sip_speech.cls`, while RTP
dev7 owns `RtpAudioFrame` and packet/codec semantics.

Speech dev12 therefore adds a cross-package regression that loads those real
packages and proves the existing ownership split still composes:

```text
RtpAudioFrame -> SipSpeechRecognitionConsumer -> Speech STT chunk stream
Speech TTS chunk stream -> SipSpeechSynthesisProducer -> RtpAudioFrame
```

The test checks:

- inbound 8 kHz mono S16LE PCM is delivered byte-for-byte to the Speech STT
  chunk contract and the temporary artifact is removed after synchronous
  consumption;
- explicit `endInput` remains Speech-stream lifecycle rather than SIP call
  lifecycle;
- outbound Speech chunks are coalesced/split into 160-sample (20 ms) RTP PCM
  frames without leaking Speech chunk boundaries into RTP framing;
- payload types 0 (PCMU) and 8 (PCMA) remain accepted by the SIP adapter while
  Speech continues to expose decoded PCM only;
- Speech chunk release is called exactly once for each consumed DATA chunk;
- independent adapter instances retain independent counters/state.

No SIP signalling, UDP socket, RTP network transmission, Azure call, or local
audio device is exercised by this regression. Those remain separately owned
and separately qualified.
