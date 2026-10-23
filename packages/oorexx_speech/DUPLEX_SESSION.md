# Full-duplex speech session — dev10

`SpeechDuplexSession` composes the existing provider-neutral pieces:

```
                   SpeechDuplexSession
                  /         |          \
                 /          |           \
        TTS playback   capture -> STT   STT event drain
             |              |                |
        SpeechPCMSink   SpeechPCMSource   PARTIAL/FINAL/END
```

The three paths execute on independent ooRexx activities.  The session itself
owns only lifecycle/join/cancellation.  SIP remains signalling authority, RTP
remains packet/media-framing authority, and the attached local-audio backend
remains device-clock authority.

## Main API

- `start(ttsRequest, recognitionFormat, language, options, captureBytes, playbackTimeoutMs, eventTimeoutMs)`
- `wait()` -> `SpeechDuplexOutcome`
- `cancel()`

`SpeechDuplexOutcome` exposes playback/capture chunk counts, the ordered STT
events and the aggregate `SpeechSTTResult` / `finalText`.

## Live Azure/local-device qualification

`tools/run_azure_duplex_live.sh` starts one `aplay` reader and one `arecord`
writer, constructs separate resident Azure Macrospace providers for TTS and STT,
and runs one `SpeechDuplexSession`.  The default profile is `speech-16k` so both
directions use the same raw PCM format.  This is a qualification harness, not a
claim that Speech owns ALSA.
