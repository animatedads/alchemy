# ooRexx Speech v0.1-dev7 qualification

Runtime: user-supplied ooRexx 5.3.0 r13196 Internal Test Version.

## Executed locally

- `test_contracts.rex` — PASS
- `test_optional_defaults.rex` — PASS
- `test_multi_channel.rex` — PASS, four batch lanes, peak 4
- `test_streaming_tts.rex` — PASS, four streaming TTS lanes, peak 4
- `test_audio_profiles.rex` — PASS, 8k/16k/24k semantic profiles
- `test_streaming_stt.rex` — PASS, four streaming STT lanes, peak 4
- `test_azure_provider_mock.py` — PASS, including Azure telephony TTS format and PushAudioInputStream STT
- `test_streaming_macrospace.rex` — PASS through Rexx-first Macrospace; TTS telephony profile crosses correctly
- `test_streaming_stt_macrospace.rex` — PASS through Rexx-first Macrospace; partial/final/end STT events cross correctly
- Python byte compilation of `oorexx_speech_providers.py` — PASS

Macrospace v0.31.7-rexxfirst2 was rebuilt against the same r13196 headers and
libraries for the crossing tests. The resulting bridge linked to
`librexxapi.so.4`, `librexx.so.4` and `libpython3.13.so.1.0`.

## Library compatibility observation

Current Library material inspected during dev7 included RTP v0.1-dev5 and SIP
v0.1-dev13. Speech does not depend on either package. RTP's decoded media
boundary uses narrowband S16LE PCM around payload types 0/8, which is why dev7
adds `telephony-8k` rather than teaching Speech about RTP packets or SIP calls.

## Not executed locally

Credentialled Azure live streaming STT. `tools/run_azure_stt_stream.sh` is
packaged for the Azure/Macrospace host where live TTS has already been proven.
