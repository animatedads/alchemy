# ooRexx Service Video Playout v0.1-dev3 — source publication

This is the source-only GitHub handoff of the complete dev3 development delivery, not a claim of production approval.

**Full delivery:** `oorexx_service_video_playout_v0.1-dev3.zip`, SHA-256 `45108698e6b7166df4181aa4b4008c55479593f1e3a82266542db1029e9c9298`.

The resident Linux C11 media worker emits 1280×720 YUV420P at 24 fps to V4L2 `/dev/video0` and 48 kHz signed PCM stereo to PipeWire-PulseAudio `service_audio` feeding `service_mic`. ooRexx with Foreign Runtime v0.22.6 coordinates scenes and implements WAIT, HOLD, RELEASE and stop. Browser consumers use normal camera/microphone interfaces.

## Build and hardware-free qualification

```sh
make -C native clean all
python3 tests/test_native_hold.py
```

The test suite exercises media preflight, WAIT/RELEASE, mid-scene HOLD/resume and missing media detection with temporary file outputs. No hardware is required.

For an openSUSE browser demo, obtain the separately delivered full dev3 ZIP's `assets/` directory, run `bash tools/prepare_live.sh`, then launch `rexx run_live_control.rex` from `tests/` with the qualified ooRexx/Foreign Runtime environment. A VLC V4L2 preview only shows video, not the separate virtual microphone.

## Deliberate omissions

The source repository excludes original video clips, reports/images, compiled `.so`, runtime outputs and the bundled NotNotes vendor ZIP. They belong to separately owned asset/dependency distributions. The source-only test does not require those assets.

**Safety boundary:** `approveMediaDemo` is only a synthetic-fixture development gate. Real invoices, customer information and reports require upstream session-specific disclosure authorisation and audit. The native media worker cannot grant that authority. ConnectSelector is optional; Queue Fabric is not required.

See `docs/DEV3_WAIT_RELEASE.md` for operating and qualification boundaries.
