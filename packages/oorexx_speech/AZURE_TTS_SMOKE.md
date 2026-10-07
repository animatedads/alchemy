# Azure TTS live smoke test

This test is intentionally TTS-only. It creates one ooRexx `SpeechTTSChannel`,
constructs one resident Azure provider through Python Macrospace, calls Azure
Speech, validates the returned RIFF/WAVE artifact, and prints its path.

## Required runtime configuration

- ooRexx 5.3-compatible runtime
- Python Macrospace v0.31.7-rexxfirst2, built for the selected ooRexx/Python
- Macrospace dependency roots on `REXX_PATH` (Alchemy Objects, Foreign Runtime,
  Crypto) when they are not installed globally
- `azure-cognitiveservices-speech` installed into the Python used by Macrospace
- Azure Speech key plus region or endpoint

## Environment

```sh
export MACROSPACE_ROOT=/path/to/oorexx_python_macrospace_poc_v0.31.7-rexxfirst2
export ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8
export FOREIGN_RUNTIME_ROOT=/path/to/oorexx_foreign_runtime_v0.22.6
export CRYPTO_ROOT=/path/to/oorexx_crypto_v0.8.3

python3 -m pip install azure-cognitiveservices-speech

export OOREXX_SPEECH_AZURE_KEY='your-key'
export OOREXX_SPEECH_AZURE_REGION='uksouth'
export OOREXX_SPEECH_AZURE_VOICE='en-GB-SoniaNeural'
```

Run:

```sh
./tools/run_azure_tts.sh
```

To copy the generated WAV to a known path and play it immediately:

```sh
export OOREXX_SPEECH_OUTPUT="$HOME/azure-oorexx-tts.wav"
export OOREXX_SPEECH_PLAY=1
./tools/run_azure_tts.sh
```

Override the spoken sentence with `OOREXX_SPEECH_TEST_TEXT`.
