# Streaming STT — dev7

Dev7 adds provider-neutral incremental speech-to-text while preserving the
existing batch `SpeechSTTChannel~recognize()` path.

## Semantic API

```text
SpeechSTTChannel~beginRecognition(audioFormat, language, options)
    -> SpeechSTTStream

SpeechSTTStream~pushChunk(SpeechAudioChunk)
SpeechSTTStream~endInput()
SpeechSTTStream~nextEvent(timeoutMs)
SpeechSTTStream~finalResult()
SpeechSTTStream~cancel()
```

Recognition events are `SpeechSTTEvent` objects with kind `PARTIAL`, `FINAL` or
`END`.  Final events are accumulated by the stream and projected as an ordinary
`SpeechSTTResult` by `finalResult()`.

## Macrospace boundary

Bulk PCM does not pass through the scalar Python Macrospace marshaller.  The
caller supplies a short-lived raw-PCM artifact path in `SpeechAudioChunk`; the
resident Python provider synchronously copies that file into the provider's
stream input.  Macrospace carries only session ids, file paths, booleans and
small text-event descriptors.

Azure recognition text is UTF-8 encoded as hexadecimal in the descriptor so an
arbitrary transcript cannot collide with the scalar `|` field delimiter.

## Azure

`AzureSpeechProvider` uses `PushAudioInputStream` and continuous recognition.
The dev7 provider accepts raw signed 16-bit mono PCM at 8000 or 16000 Hz.
Partial Azure `recognizing` callbacks map to `PARTIAL`; committed `recognized`
callbacks map to `FINAL`; session stop maps to `END`.

The caller owns input chunk artifacts.  The Azure provider reads a chunk during
`pushRecognitionChunk()` and does not retain the chunk path afterwards.
