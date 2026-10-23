# ooRexx Speech v0.1-dev6 qualification

Runtime used locally: user-supplied ooRexx 5.3.0 r13196 Internal Test Version.

Executed PASS:

- `tests/test_contracts.rex`
- `tests/test_optional_defaults.rex`
- `tests/test_multi_channel.rex` — four batch TTS/STT lanes, peak 4
- `tests/test_streaming_tts.rex` — four incremental TTS lanes, peak 4, END and cancel transitions
- `tests/test_azure_provider_mock.py` — batch Azure TTS/STT plus streaming DATA/END/release semantics
- `tests/macrospace/test_streaming_macrospace.rex` — Rexx-first Macrospace begin/next/release/cancel crossing
- Python byte compilation of `python/oorexx_speech_providers.py`

Streaming TTS implementation boundary:

- provider-neutral `SpeechTTSStream` / `SpeechAudioChunk` semantics are ooRexx-owned;
- Azure SDK emits raw PCM as synthesis events become available;
- Python materializes each event as a short-lived chunk file;
- Macrospace carries only scalar descriptors, not bulk audio bytes;
- controller explicitly releases consumed chunk artifacts;
- one resident Python provider per lane remains the default concurrency rule.

Not executed locally:

- credentialled Azure live streaming test.  `tools/run_azure_tts_stream.sh` is packaged for execution in the already proven Azure/Macrospace environment.
