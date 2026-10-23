# SIP / Speech interop — dev15

The integration is deliberately asymmetric and object-separated.

```text
SipCallControl                  independent
SipInboundAudio -> SipSpeechRecognitionConsumer -> SpeechSTTStream
SipOutboundAudio <- SipSpeechSynthesisProducer <- SpeechTTSStream
RtpReceiver / RtpSender        independent
```

`SipSpeechRecognitionConsumer` implements the existing inbound consumer contract (`audioFrame(frame)`). It converts the decoded PCM frame to the Speech streaming artifact boundary and synchronously calls `SpeechSTTStream~pushChunk`. It does not start, stop, cancel or end the SIP call. `endInput` is explicit.

`SipSpeechSynthesisProducer` implements the existing outbound producer contract (`nextAudioFrame`). It consumes Speech TTS chunks, validates the telephony 8 kHz/mono/S16LE profile, coalesces/splits chunk boundaries into 160-sample (20 ms) RTP PCM frames, and returns `RtpAudioFrame` objects. It does not clock/pause the sender and does not cancel the Speech stream when detached.

The current Speech bulk-PCM bridge uses short-lived file artifacts. This adapter honours that API rather than inventing another Python/native PCM ABI. A future shared native audio buffer can replace the backing without changing SIP object ownership.

There is intentionally no `SipSpeechCall` or `startEverything` object. Correlation does not imply ownership.