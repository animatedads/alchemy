# ooRexx Vision v0.1-dev11 — Termux live event test bed

This package carries the complete Vision dev10 class surface forward and adds a
mobile-native FFmpeg acquisition boundary plus the first live event vocabulary.

## Mobile boundary

`native/libvision_ffmpeg.so` is built *on the phone* against Termux's installed
FFmpeg ABI.  It owns only network/media decode and reduction to a fixed RGB24
frame.  It does not identify people, blobs, gestures or events.

The first executable adapter `build/vision_ffmpeg_source` links the same native
implementation and writes exact frame transactions to stdout.  This lets the
test bed run before binding the three C entry points through Foreign Runtime.
The library ABI is intentionally only:

- `vision_ffmpeg_open`
- `vision_ffmpeg_next_rgb24`
- `vision_ffmpeg_close`

The live semantic path remains:

camera -> native FFmpeg -> ~4K frame -> Vision codec -> Line Continuity ->
Movement/persistence -> Vision events.

## Termux

    ./install-termux.sh
    ./bench/live_capture.sh 'https://192.168.188.25:4444/video/mjpeg' 10

For 55x73 RGB24 each complete native transaction is 12045 bytes.  The test
fails if the byte stream ends between frame boundaries.

No Python is required.  Queue Fabric and Storage Fabric are intentionally not
required for this first single-phone qualification.

## dev12 package boundary

Temporal tracking/event interpretation has been removed from Vision. Vision
emits frame-local observations only. `oorexx_motion_control` consumes those
observations and owns track/movement/persistence state.

## dev13 native live corrections

- short live tests are measured from the first decoded source frame rather than
  counting network/probe startup against the requested duration;
- output cadence advances on a fixed requested clock to avoid timestamp drift;
- MJPEG full-range YUVJ input is normalized to its non-deprecated layout with
  explicit full-range swscale colour handling;
- the Termux build no longer requires the optional `file` utility;
- the qualification expects about `seconds * fps` complete frame transactions
  and still requires a zero-byte remainder.
