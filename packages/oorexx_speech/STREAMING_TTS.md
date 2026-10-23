# Streaming TTS — dev6

Dev6 adds provider-neutral incremental TTS without changing the batch WAV API.

## Semantic flow

`SpeechTTSChannel~beginSynthesis(request)` returns a `SpeechTTSStream`.

The caller repeatedly invokes `stream~nextChunk(timeoutMs)`.  The result is:

- `.nil` when no chunk arrived before the timeout;
- `SpeechAudioChunk(kind=DATA, ...)` while audio is arriving;
- one `SpeechAudioChunk(kind=END, ...)` at normal completion.

DATA chunks currently reference short-lived raw PCM files (`S16LE`, 24 kHz, mono for Azure).  After a controller consumes a chunk it calls `stream~releaseChunk(chunk)`.  `stream~cancel` explicitly terminates provider synthesis.

This artifact hop is intentional for dev6: Macrospace remains responsible for Python object identity/lifetime while bulk audio stays out of the scalar marshaller.  A future native audio buffer can replace the chunk backing without changing the channel/stream contract.

## Azure

`AzureSpeechProvider.begin_synthesis()` uses Azure Speech SDK synthesis events and `Raw24Khz16BitMonoPcm`.  Event audio is queued as it becomes available, materialized to a short-lived `.pcm` chunk, and returned through the ordinary Macrospace method surface.

Live test:

```sh
./tools/run_azure_tts_stream.sh
```

The launcher converts the aggregate raw PCM to WAV with ffmpeg when available. Set `OOREXX_SPEECH_PLAY=1` to play the completed WAV.

This dev6 test proves incremental receipt and chunk timing.  Continuous low-latency playback while chunks are arriving belongs to the forthcoming local/SIP audio controller, not to the speech provider.


## dev7 profile selection

Azure streaming TTS can now select `telephony-8k` (8 kHz PCM) or `speech-16k` through `SpeechTTSRequest~options['audioProfile']`; the default remains 24 kHz PCM.
