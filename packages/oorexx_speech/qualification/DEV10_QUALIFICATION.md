# dev10 qualification

Dev10 adds `speech.duplex/0.1` full-duplex orchestration and cancellation-aware
PCM pumps. SIP/RTP and device authority remain external.

Executed locally against the supplied ooRexx 5.3.0 r13196 package:

- core/batch/streaming regression suite;
- `test_duplex_session.rex` — concurrent playback, capture-to-STT and event drain;
- `test_duplex_cancel.rex` — coordinated provider/source/sink cancellation with
  worker activities joined cleanly;
- Python Azure provider mock / byte compilation;
- shell syntax checks for all live launchers;
- strict ooRexx standards-enforcer gate on the sealed archive.

The actual live Azure full-duplex device run is packaged but NOT_RUN in this
build environment because account credentials and local audio hardware are not
available here.
