# ooRexx Speech architecture

The package owns speech semantics, not call control and not the audio device.

```
future SIP controller / local audio controller
              |       |
      SpeechAudioSource / SpeechAudioSink
              |       |
     SpeechSTTChannel  SpeechTTSChannel
              |       |
     provider-neutral speech contracts
              |       |
  local provider       cloud provider
              \       /
       resident Python objects
          Python Macrospace
```

## Concurrency

A `SpeechTTSChannel` or `SpeechSTTChannel` is a single ordered lane. Calls on one
channel are guarded/serialized by ooRexx. Different channel objects are independent
and launch work with `Object~START`, yielding Message objects. Thus N simultaneous
SIP dialogs should normally own N duplex channel pairs (TTS + STT) and can execute
at the same time without making one giant shared provider object an accidental lock.

Provider residency is deliberately per-channel by default. Sharing one Python model
object across channels is an optimization that must be independently qualified for
that backend and Macrospace generation.

## Python boundary

`SpeechMacrospace*.cls` accepts already-projected resident Python objects. It does
not spawn Python, use JSON RPC, or own Python search paths. Macrospace remains the
owner of object identity, lifetime, thread attachment, pin/call/release and
revocation.

Dev1 uses file artifacts across the Python boundary. This is conservative and makes
cloud/local providers executable without inventing a live-PCM ABI before the SIP
and local-audio controllers exist. The semantic controller boundary is already
chunk/stream-ready and can gain a v0.2 streaming provider API without changing call
control ownership.

## Azure provider
Azure AI Speech is an implementation provider, not speech-domain authority. It is loaded as a resident Python object through Macrospace. One provider object per speech lane remains the default concurrency rule. Public Azure may use key+region; endpoint-based configuration is also accepted so deployment topology does not leak into callers.
