# Dev3 WAIT / RELEASE — native media source handoff

Provenance: full dev3 ZIP SHA-256 `45108698e6b7166df4181aa4b4008c55479593f1e3a82266542db1029e9c9298`.

The worker continuously writes 1280×720 YUV420P frames at 24 fps and 48 kHz, two-channel s16le audio (2000 stereo samples per frame, 8000 bytes). It owns the V4L2 and PipeWire-compatible output handles throughout the session.

**WAIT/HOLD:** Repeat the configured idle picture and silence. Queue and current-scene cursors do not advance. **RELEASE:** Resume at the same scene position without disconnecting the browser camera or microphone.

Queue admission requires absolute, non-symlink regular files with exact I420/PCM byte extent. Repeat the check when the worker reaches the item. This detects missing or changed lengths; it does *not* attest content identity or preserve immutable file descriptors after admission.

Foreign Runtime `start` name collision is resolved by explicit `native~invokeArray('start', .array~new)` in the ooRexx wrapper.

Build with `make -C native clean all` and qualify using `python3 tests/test_native_hold.py`. Live openSUSE use requires `/dev/video0` (v4l2loopback), `service_audio` PulseAudio-compatible sink, `service_mic` remap source, ooRexx 5.3 and qualified Foreign Runtime v0.22.6, and staged original demo media supplied separately.

The source handoff does not include live assets, a presentation grant, a public network listener or claims of WhatsApp interoperability. Production needs explicit service/user/session authorisation, scoped disclosure permissions, expiry, audit, asset hashing, redaction, and live A/V clock measurements.
