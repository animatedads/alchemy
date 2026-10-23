# Local audio controller — dev9

`SpeechLocalAudioController` owns only speech-stream orchestration.

Playback:

```
SpeechTTSStream -> SpeechLocalAudioController -> SpeechFifoPCMSink -> aplay/device
```

Capture:

```
arecord/device -> SpeechFifoPCMSource -> SpeechLocalAudioController -> SpeechSTTStream
```

FIFO endpoints are an initial COTS integration mechanism, not the semantic API.
A native ALSA, PipeWire, Windows or other device provider may implement the same
`SpeechPCMSource` / `SpeechPCMSink` contracts later.

## Linux live adapters

`tools/run_azure_tts_live_playback.sh` attaches `aplay` to a FIFO and lets the
controller write Azure TTS chunks while they arrive.

`tools/run_azure_stt_live_microphone.sh` attaches `arecord` to a FIFO for a
bounded capture interval and feeds those chunks to Azure streaming STT.

These shell launchers are deployment adapters only. They do not alter the ooRexx
speech semantic API and can be replaced by native device providers later.
