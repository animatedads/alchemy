# Live Azure TTS evidence carried into dev5

Source: user-executed dev4 live Azure run on 2026-10-03.

Observed successful service crossing:

- ooRexx -> Python Macrospace -> Azure Speech
- Python 3.13
- voice: `en-GB-SoniaNeural`
- output artifact: RIFF/WAVE, PCM, 16-bit, mono, 24000 Hz
- observed artifact size: 213046 bytes

The live run exposed two harness/API-default defects after synthesis had already
succeeded: the omitted sink was not deterministically `.nil`; the smoke test
used variable `result` which a later `CALL STREAM` overwrote; and related
omitted optional constructor arguments could retain symbolic names.

Dev5 repairs these package-wide. The credentialled service call was not rerun in
the packaging environment; this is external execution evidence, not a relabelled
local PASS.
