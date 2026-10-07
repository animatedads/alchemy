# ooRexx Speech v0.1-dev4

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
- dev1 Python crossing uses file artifacts for a conservative scalar boundary.

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
