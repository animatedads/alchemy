# Media Object Access — native RGB24 pixel path (dev4, 2026-11-08)

**Architecture:** ooRexx owns MediaTsFile (PAT/PMT, 188-byte TS packets, elementary-stream PES assembly, PTS/DTS extraction, persistent source-identity-bound IDR index and bounded range planning), MediaTsVideoFrames (a requested integer 90kHz PTS, decode loop and frame selection), and MediaRgbFrame (width, height, RGB24 bytes, pixelAt and direct PPM writer). `moa_h264_codec.cpp` is a **native codec provider** using libavcodec and libswscale dynamically in-process. It never opens media files, executes FFmpeg CLI, performs network IO, seeks, nor parses the TS/MP4 container. No Python is involved.

The uploaded `.mkv`-named recordings are actually 188-byte **MPEG-TS** with H.264 PID 256 and AAC audio. They were supplied in the conversation and **are not included** in this artifact or GitHub. The code runs under the user's ooRexx 5.3.0 r13196 64-bit test runtime, with 64-bit Debian libavcodec major 61, libavutil major 59 and libswscale major 8. The native provider rejects other runtime library major versions; rebuild/requalify for other ABIs. This is a development provider, not an arbitrary FFmpeg binary wrapper. Where installed upstream dev headers exist, replace the version-pinned public ABI excerpts with matching installed headers.

## Build

    cd native
    make OOREXX_ROOT=/path/to/extracted/usr/local
    export LD_LIBRARY_PATH=/path/to/extracted/usr/local/lib:$PWD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

`::requires 'moa_h264' LIBRARY` registers the codec-only ooRexx native routines via RexxGetPackage. No `RxFuncAdd` registry use.

## Test three streams

Run from `tests/` with `REXX_PATH` pointing to `src` (all `MediaTsFile.cls`, `MediaSeekIndex.cls`, and `MediaByteSource.cls` dependencies must be present):

    cd tests
    export REXX_PATH=../src
    rexx test_three_sydney_pixels.rex /path/stream1.mkv /path/stream2.mkv /path/stream3.mkv /tmp/frames

The test performs one explicitly authorised local index build, exports a sidecar and loads it into a new reader, then requests frames at 55, 5, and 30 seconds (backward then forward hot jumps) with a maximum 1 MiB compressed range per seek. Each returned decoded frame is checked against the requested integer PTS and buffer dimensions; RGB24 pixels are read using `.MediaRgbFrame~pixelAt()`. The 30-second image is saved as raw PPM without external image tooling. The still-image preview in the conversation is a display transformation, not part of this media pipeline.

## Native test evidence, 8 Nov 2026

| Camera | Resolution | Decoded frame bytes | Raw compressed bytes per request | 5/30/55 sec |
|---|---:|---:|---:|---|
| 1 | 1280×720 | 2,764,800 | 288,768 | PASS, PASS, PASS |
| 2 | 1280×720 | 2,764,800 | 481,280 | PASS, PASS, PASS |
| 3 | 640×360 | 691,200 | 192,512 | PASS, PASS, PASS |

All nine requests returned exactly the target PTS (450000, 2700000, 4950000 ticks), original source immutable-index sidecar restored without a full scan; output frames were inspected visually. The source had 12 candidate IDR anchors per camera. The index build is O(file bytes) and is **explicitly local**; subsequent hot seeks are bounded and use binary index lookup. A 1 GiB remote object must be indexed once on a resident Storage Fabric MU, sidecar atomically published and keyed by its *immutable* source generation/content identity. The example local test identity (path + size + test marker) is not sufficient for distributed deployment.

## Limits and failures

- This is a qualified **MPEG-TS/H.264 RGB24 pixel path**, not MP4 video decode. Existing MP4 metadata/sample maps require an adapter to the same H.264 provider; fragmented MP4, SPS/PPS changes and alternate codecs must be tested independently.
- Returned frames are decoded, with codec-returned PTS and real RGB data. It is not yet a certification of *frame-exact seek for every H.264 stream*: open-GOP, B-frame reference chains, missing codec extradata and stream discontinuities must fail closed in the general case. The test was successful for the three supplied TS streams.
- Native library pins libavcodec 61, libavutil 59, libswscale 8 and assumes public AVPacket/AVFrame struct layout; do not distribute a build as ABI-universal. It uses no FFmpeg command-line or libavformat.
- TS index creation scans the full input only with resident-node permission; no remote whole-file reads and no duplicate index rebuilds on hot seeks. The test imposes a 1 MiB *compressed* range cap. A request whose GOP requires more than the range may return `.nil`; it does not silently fetch the rest of the file.
- `MediaRgbFrame~savePpm()` produces P6 PPM. This is an export for evaluation, not the V5V codec or a secondary source-of-truth image pipeline.
- Commercial redistribution of a libavcodec-dependent native plugin must comply with relevant library licensing and provide notices as required. No binary copies of FFmpeg libraries ship here.

## Files

- `src/MediaH264Frames.cls` — RGB pixel graph and codec session.
- `src/MediaTsVideoFrames.cls` — ooRexx PES feed, timestamp selecting and range budgets.
- `native/moa_h264_codec.cpp` — native compressed H.264 to RGB24 provider.
- `native/Makefile` — local build, no media framework binary or subprocess.
- `tests/test_three_sydney_pixels.rex` — three-camera 9-seek qualification with real clips provided separately.
- `tests/test_native_provider_smoke.rex` — provider open/close.

This is an addition to the existing PR #138 Media Object Access implementation, not a replacement for its MP4 edit-list and sample mapping code.