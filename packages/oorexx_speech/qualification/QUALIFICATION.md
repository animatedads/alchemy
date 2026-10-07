# Qualification — ooRexx Speech v0.1-dev2

Runtime: user-supplied ooRexx 5.3.0 r13196 Internal Test Version.  
Runtime DEB SHA-256: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.

Python Macrospace dependency: `oorexx_python_macrospace_poc_v0.31.7-rexxfirst2.zip`  
SHA-256: `6ab77de306b9a507804fe3eb868997b3c4a53bdc2654808eeef03a1c50d59c3b`.

## Executed

- `tests/test_contracts.rex`: PASS.
- `tests/test_multi_channel.rex`: PASS; four independent ooRexx lanes overlap.
- Real Rexx-first Macrospace integration: PASS with two TTS + two STT activities,
  four separate resident Python provider objects, observed Python `peak=4`,
  `completed=4`, elapsed `0.354099` seconds for four provider bodies that each
  deliberately sleep 0.35 seconds.
- Macrospace Rexx-first bootstrap: PASS with no Python-side bootstrap.
- Macrospace Rexx-first binary CPython extension import: PASS with no `LD_PRELOAD`.
- Macrospace retained Rexx-object argument and natural Python -> Rexx callback regressions: PASS.
- `python/oorexx_speech_providers.py`: Python bytecode compilation PASS.

## Not executed / not claimed

- Piper/faster-whisper inference: NOT_RUN; backend models/packages were not installed for this qualification.
- OpenAI cloud speech call: NOT_RUN; no credentialed network call was made.
- SIP and live local-audio streaming: NOT_RUN; those controllers remain future consumers of the explicit audio source/sink seam.

The qualified concurrency contract is **lane-per-resident-provider**. A shared Python model/provider
instance is not assumed to be concurrent merely because four separate provider objects are concurrent.
