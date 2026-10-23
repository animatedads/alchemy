# ooRexx Speech v0.1-dev9 qualification

Runtime: user-supplied ooRexx 5.3.0 r13196 debug x86-64.

Executed locally:

- PASS contracts
- PASS optional defaults / RESULT isolation
- PASS four-channel batch concurrency
- PASS streaming TTS concurrency
- PASS audio profiles
- PASS streaming STT concurrency
- PASS authoritative/local audio bridge
- PASS local controller file-backed capture/playback
- PASS local controller full-duplex activity overlap
- PASS Python provider byte compilation
- PASS shell syntax for Linux `aplay` / `arecord` launchers

The duplex regression initially exposed serialization in the dev8 stateless
`SpeechAudioPump` class methods. They were guarded on the shared class receiver.
dev9 changes both pump methods to `unguarded`; the same two 0.20-second paths
then complete together in about 0.20 seconds rather than about 0.40 seconds.

NOT_RUN locally: live ALSA hardware playback/capture and credentialled Azure
microphone/live-speaker runs.
