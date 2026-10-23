# ooRexx Speech v0.1-dev11

Provider-neutral concurrent TTS and STT (also usable under the user's `SST` naming)
for ooRexx.

Highlights:

- multiple TTS/STT channel objects execute concurrently via ooRexx activities;
- one ordered lane per channel, rather than global serialization;
- explicit future SIP/local-audio source/sink boundary;
- Python is controlled through resident Macrospace objects, not subprocess scripts;
- local provider module: Piper TTS + faster-whisper STT;
- cloud provider module: configurable OpenAI SDK TTS/STT;
- cloud model names remain configuration rather than semantic API constants;
- batch Python crossing uses file artifacts for a conservative scalar boundary;
- dev6 adds provider-neutral incremental TTS streams and Azure raw-PCM chunk delivery;
- dev7 adds provider-neutral streaming STT plus 8k/16k/24k audio profiles for clean telephony composition.

## Macrospace wiring

Load `python/oorexx_speech_providers.py` through the current Python Macrospace,
construct one resident provider object per speech lane, and wrap it with:

- `SpeechMacrospaceTTSProvider`
- `SpeechMacrospaceSTTProvider`
- or `SpeechMacrospaceDuplexProvider`

The package intentionally does not prescribe the exact Macrospace loading call: the
current portfolio authority is Macrospace itself, and Speech accepts the projected
object after loading. This avoids duplicating/reimplementing Macrospace lifecycle.

## Dependencies

Required: ooRexx 5.3-compatible runtime.

Optional local Python backend: `piper-tts`, `faster-whisper`.
Optional cloud Python backend: `openai` and the account/API configuration required
by that SDK.

## dev3 — Azure AI Speech
Adds `AzureSpeechProvider` behind Python Macrospace and `SpeechMacrospaceFactory~azureDuplex`. The same Azure AI Speech resource can back both TTS and STT. Azure credentials remain external configuration. TTS output is fixed to RIFF 24 kHz/16-bit/mono PCM for the current artifact contract; file STT uses continuous recognition.


## dev4 — live Azure TTS smoke path
Adds `tests/live_azure_tts.rex` and `tools/run_azure_tts.sh`. The live test creates one real Azure-backed ooRexx TTS channel through Macrospace, requests a British-English voice, validates that the returned artifact has a RIFF/WAVE header, and prints the artifact path for playback. The test performs no SIP or STT work.


## dev5 — live Azure TTS harness repair

Dev5 repairs two defects exposed by the first successful live Azure TTS run.
Omitted optional ooRexx arguments now use explicit `USE STRICT ARG` defaults,
preventing symbolic names such as `SINK` and `AUDIOFORMAT` from leaking into
object state. The Azure smoke test stores its synthesis object in `ttsResult`
rather than Rexx's special `RESULT` variable, which can be overwritten by a
subsequent `CALL` instruction.

The user-provided live run through ooRexx -> Macrospace -> Azure Speech produced
a valid 24 kHz, mono, 16-bit PCM RIFF/WAVE artifact using en-GB-SoniaNeural.
That externally executed evidence is recorded separately from local qualification.


## dev6 — incremental TTS streaming

Dev6 keeps the batch WAV API and adds `SpeechTTSChannel~beginSynthesis()`,
`SpeechTTSStream~nextChunk()`, explicit END markers, cancellation and chunk
release.  `SpeechAudioChunk` is the controller-facing unit.  Azure synthesis
uses the SDK's as-available synthesis events with raw 24 kHz/16-bit/mono PCM.
Each event is materialized as a short-lived chunk artifact behind Macrospace;
bulk audio does not pass through the scalar foreign-object marshaller.

The r13196 qualification includes four concurrent stream lanes (`peak=4`),
end/cancel state transitions, an Azure SDK mock, and a real Rexx-first
Macrospace begin/next/release/cancel crossing.  See `STREAMING_TTS.md`.


## dev7 — streaming STT and telephony PCM profile

Dev7 adds `SpeechSTTChannel~beginRecognition()` and `SpeechSTTStream` with
incremental `pushChunk`, `endInput`, partial/final recognition events, explicit
END, cancellation and aggregate `finalResult()` semantics.

Azure uses `PushAudioInputStream` behind the resident Macrospace provider.  Raw
PCM remains outside the scalar foreign-object marshaller: Rexx passes a chunk
artifact reference, Python synchronously copies the bytes into Azure, and small
event descriptors return through Macrospace.

`SpeechAudioProfiles~telephonyNarrowband` defines 8000 Hz, mono, S16LE PCM.
Azure accepts that format directly for streaming STT and can now synthesize
directly to 8 kHz PCM with TTS option `audioProfile='telephony-8k'`.  This aligns
with the decoded narrowband PCM seam in the current RTP package without making
Speech depend on SIP, RTP or G.711 packet semantics.

See `STREAMING_STT.md` and `TELEPHONY_INTEROP.md`.

## dev8 — local PCM and authoritative Audio bridge

Dev8 adds `src/SpeechAudioBridge.cls`, a dependency-neutral PCM source/sink seam
for local audio controllers and RTP-facing composition.  It also consumes the
current Layered Audio / Storage execution-binding protocol (`localPath`,
`identityKey`, optional `release`) without requiring Layered Audio.  Durable
Audio/Storage identity is retained in Speech artifact metadata while transient
materialisation paths remain execution-only.

`SpeechAudioPump` can feed bounded raw-PCM chunks into a streaming STT session or
drain streaming TTS chunks into a PCM sink.  It deliberately owns no wall clock,
codec, RTP, SIP, or device policy; those remain controller/transport concerns.

## dev9 — local audio controller

Dev9 adds `SpeechLocalAudioController` and FIFO-backed PCM source/sink adapters.
The controller composes the existing streaming TTS/STT contracts and deliberately
leaves device ownership to a COTS backend. On Linux, the supplied live launchers
attach `aplay`/`arecord` to the FIFO endpoints. Speech therefore does not become
an ALSA/Pulse/PipeWire implementation and the same controller seam remains usable
by future native or platform-specific device providers.

## dev10 — full-duplex speech session

Dev10 adds `SpeechDuplexSession` as a transport-neutral orchestration object for
one simultaneous playback/capture speech leg.  It owns no SIP/dialog state and
no device implementation.  A caller supplies one TTS channel, one STT channel,
a PCM source and PCM sink.  The session launches synthesis playback, microphone
feeding and STT event draining as three independent ooRexx activities and joins
them into a `SpeechDuplexOutcome` containing chunk counts, recognition events
and the aggregate final transcript.

Cancellation coordinates both speech streams plus source/sink closure.  This is
the object a future SIP or local UI controller may own without importing RTP,
SIP, ALSA or Azure semantics into Speech.

## dev11 — dynamic speech intentions

Dev11 adds `SpeechIntentions.cls`. Intention discovery is deliberately transient:
every discovery reads the current `SpeechRuntime`, retains the exact live TTS/STT
channel objects, and reflects current lane state.  There is no cached permanent
action catalogue.  A busy/disappearing channel changes the next discovery, and a
duplex-session intention exists only while independent TTS and STT lanes are both
currently available.

This mirrors the current Layered Audio doctrine without making Speech depend on
Layered Audio or Intention Service.  An Intention Service adapter can consume the
fresh discovery later; natural-language interpretation remains outside Speech.
