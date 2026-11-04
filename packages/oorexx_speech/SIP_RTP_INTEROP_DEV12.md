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


## Independent native qualification

CODEX-PC independently ran the dev12 regression on ooRexx 5.3.0 r13196 against exact Git commit `e65b97548b7d444719726c8554a2cbc51621662d`.

- RTP native build: PASS.
- Regression, invoked with `bash tools/run_sip_rtp_interop.sh`: PASS.
- No SIP signalling/network calls, UDP transmission, Azure access or local-device access were made.
- The direct `./tools/run_sip_rtp_interop.sh` invocation exited 126 because the Git executable bit was missing; dev13 corrects that packaging defect.

Independent evidence SHA-256 values:
- `tests/test_sip_rtp_interop.rex`: `85bd001be3da4f042b2d468bcaa45d02bf79988ee04b24c3e2642c4f4326631d`
- SIP `src/sip_speech.cls`: `14e28eaed79eefd056a3c6a8e124506d4d09a670d60097664f96d9762b132b2e`
- RTP `src/rtp.cls`: `5f8a1d2a26749b2e4565b321dd2044bd8ca805e680b7c67d06e32215faee4dde`
