# Azure Speech dev3 qualification

Target runtime: user-supplied ooRexx 5.3.0 r13196 debug DEB.

Executed locally:
- Python provider module byte-compilation: PASS
- Deterministic mocked Azure Speech SDK provider regression: PASS
  - key + region configuration
  - explicit endpoint configuration
  - TTS output format selection: RIFF 24 kHz / 16-bit / mono PCM
  - TTS voice selection
  - continuous file STT aggregation
  - STT language selection
- ooRexx `test_contracts.rex`: PASS
- ooRexx `test_multi_channel.rex`: PASS, peak=4
- ooRexx `examples/four_channels.rex`: PASS

Not executed:
- Live Azure network call: NOT_RUN. No Azure Speech credential was supplied to this build environment.
- Real `azure-cognitiveservices-speech` SDK import: NOT_RUN. The Azure SDK is not installed in this build environment; the deterministic SDK-surface mock is used for structural qualification.

No credential or endpoint secret is embedded in the release.
