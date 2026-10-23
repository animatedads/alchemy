# Local audio / Layered Audio bridge — dev8

The bridge is deliberately protocol based.

- `SpeechPCMFileSource`: raw PCM file -> bounded `SpeechAudioChunk` artifacts.
- `SpeechPCMFileSink`: `SpeechAudioChunk` artifacts -> one raw PCM file.
- `SpeechAudioPump~sourceToRecognition`: source -> streaming STT.
- `SpeechAudioPump~synthesisToSink`: streaming TTS -> sink.
- `SpeechAuthoritativeAudioInput`: consumes an execution binding exposing
  `localPath()` and optionally `identityKey()` / `release()`.
- `SpeechAuthoritativeAudioOutput`: consumes an output binding exposing
  `localPath()` and optionally `markWriting()`.

Layered Audio / Storage retains durable identity and publication authority.
Speech sees a transient local path only for the duration of execution and keeps
its durable identity as metadata; it never writes the path back into the Audio
object graph.

RTP remains independent.  RTP may expose decoded S16LE PCM to a controller,
which can implement the same source protocol.  Speech neither parses RTP nor
encodes PCMU/PCMA.

## Qualification boundary

The dev8 package was checked against the current Library `layered_audio_oorexx_v0.22-dev3`
storage/execution protocol.  The bridge intentionally consumes only the public
capabilities it needs (`localPath`, optional `identityKey`, `release`, and
`markWriting`) and therefore does not import Layered Audio classes or Storage
Fabric implementation details.
