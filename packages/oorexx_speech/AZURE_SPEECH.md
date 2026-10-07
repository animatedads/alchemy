# Azure AI Speech provider

`SpeechMacrospaceFactory~azureDuplex(...)` creates one resident Azure Speech provider for one ooRexx speech lane.
The Python Azure SDK remains behind Python Macrospace; SIP/local-audio controllers see only the provider-neutral speech API.

Configuration precedence is constructor arguments, package-specific environment variables, then Microsoft's common quickstart variables:

- `OOREXX_SPEECH_AZURE_KEY` or `SPEECH_KEY`
- `OOREXX_SPEECH_AZURE_REGION` or `SPEECH_REGION`
- `OOREXX_SPEECH_AZURE_ENDPOINT` or `ENDPOINT` (optional for ordinary public Azure; useful for explicit/sovereign endpoints)
- `OOREXX_SPEECH_AZURE_VOICE` (optional default TTS voice)

Install the Python SDK into the Python runtime used by Macrospace:

    python3 -m pip install azure-cognitiveservices-speech

Batch TTS emits RIFF 24 kHz, 16-bit, mono PCM WAV.  Batch STT uses continuous recognition over the supplied file so it is not constrained to a single short utterance.

Credentials are deliberately not stored in the package.
