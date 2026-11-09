## 9 November dev6 — bounded geometry and an evolving 50% absolute subtraction mask

ooRexx now owns `MediaRasterOps` and `MediaTemporalDifferenceMask` as
shared Media Object Access classes. The native stateless `moa_raster_ops`
provider handles only caller-owned byte-plane arithmetic; no IO, demuxing,
Python or executable FFmpeg.

- PNG, JPEG and H264 frame objects expose `crop`, `resizeToProcessing`,
  `subtractFrame` (signed 16-bit RGB/optional A) and `subtractLayer` (offset
  ROI, per-channel/mono). `MediaRasterImage` supports all four directly.
- `MediaTemporalDifferenceMask` accepts aligned processing-resolution
  images and explicitly identified times; global median photometric gain
  compensates for ambient changes; per-pixel lower-median background and
  robust temporal-noise envelope establish the **local** threshold:
  `max(minAbsolute, ceil(50% * max(referenceLuma, floor)), noiseFactor * MAD)`.
- Each new image rebuilds the model and **rescans every earlier image**:
  positive/negative and absolute difference masks retain retrospective
  discoveries. Changed model generations cannot reuse stale frame scores.
- `estimateTranslation` registers explicitly chosen stable landmark ROI
  with normalized gradients and rejects ambiguous/no-texture results.
  Validity envelopes prevent shifted black borders becoming false motion.
- Physical camera movement toward a subject can introduce scale/parallax:
  integer translation **does not** solve it. Use qualified geometry/warp
  before model comparison. Clouds remain candidates, not proven stars.
- Bounded at 16 images and 2M processing pixels; MP4/TS hot-seek contracts
  and separation of webcam time from scrubbed media timestamps are retained.

**Executed native r13196 tests:** synthetic four-frame +20% brightness and
50% mask PASS with frame-1 retrospective recovery; landmark +1 pixel shift
and +20% photometric change PASS; real JPEG skyline 0-shift registration
PASS; 5 actual Sydney JPEG exposures (03:45:21–04:46:43 AEDT) decoded,
cropped, AREA-resized and retrospectively scored PASS; real PNG RGBA
crop/resize and signed alpha difference PASS. No original images committed.
See `docs/ADAPTIVE_ABSOLUTE_SUBTRACTION_DEV6.md` and
`docs/ooRexx_r13196_qualification_20261109.log`.

---

## 9 November dev5 — PNG to RGB/RGBA and split-channel exports

In-process PNG decoding is now implemented in `MediaPngFile.cls`, with
separate `moa_png` (libpng decode only) and `moa_raster` (codec-independent
RGB/RGBA planes) native providers. ooRexx owns bounded file/range reads,
image frame objects and PGM/PPM/PAM output.

`MediaFile~open` now identifies PNG from its file signature. Both PNG RGBA32
frames and H.264 RGB24 frames expose `channelPlane('R'|'G'|'B'|'A')`,
`saveSplit(prefix)`, and `savePam(path)`, with PPM RGB available.
The four split files are binary PGM (P5), the RGB image is binary PPM (P6)
and RGBA is PAM (P7). Real PNG alpha values survive; H.264 RGB24 alpha is
synthesized as 255 (opaque).

**Native ooRexx 5.3.0 r13196 execution:** exact 2x2 fixture alpha
255/128/0/64 and R/G/B values PASS; shared H264 RGB/A planes PASS;
five user-provided 1920x1080 PNG screenshots decoded PASS; full RGBA/PPM/PGM
exports for the 20:32:17 image PASS; nine prior H264 timestamped video
seeks still PASS, including one real 1280x720 frame's R/G/B/A planes.
User images are not committed; only numerical Moonsault measurements are.
See `docs/PNG_RGBA_CHANNELS_DEV5.md`.

The image classes and two providers are source increments on this draft PR.
Use `make -f Makefile.png` in `native/`; enable `MEDIA_PNG_TESTS=1`,
`MEDIA_H264_CHANNEL_TESTS=1` or `MEDIA_SCREENSHOT_ROOT=/local/path`
when those native providers and files are available. Existing MP4/TS
metadata tests remain independent of PNG.

---

## 8 November dev4 — native H.264 decoded RGB pixels (ooRexx-owned)

The Media Object Access component now includes `MediaTsVideoFrames.cls` and
`MediaH264Frames.cls`. On MPEG-TS recordings, ooRexx owns the 188-byte TS
packet/PES parsing, camera-local 90 kHz presentation timestamps, source-bound
IDR sidecar index, 1 MiB range budgets and per-pixel RGB24 frame objects.
A replaceable **in-process H.264 codec provider** under `native/` returns
compressed-video pixels using libavcodec/libswscale; it performs **no file IO,
MPEG-TS/MP4 demuxing, networking, Python calls or FFmpeg executable calls**.

The native ooRexx 5.3.0 r13196 qualification executed all **9 random-access
frame requests** (55, 5 and 30 seconds, 3 Sydney H264 cameras). Each result
matched the requested PTS and returned 1280x720 or 640x360 RGB24 frame bytes,
with bounded compressed source reads of 288,768 / 481,280 / 192,512 bytes
respectively; no full-stream rescan on restored sidecar seeks. Code, native
build instructions and the exact log are in
`docs/NATIVE_H264_PIXELS_2026-11-08.md` and
`docs/NATIVE_H264_PIXELS_2026-11-08.log`.

**Not yet qualified:** arbitrary open-GOP/fragmented MP4 H.264 decoded exact
seeking; the existing MP4 sample map still needs an access-unit codec adapter.
The native provider is compiled and ABI-pinned to libavcodec 61, libavutil 59,
libswscale 8, and must be rebuilt/retested on a different codec ABI. Source
recordings/screenshots are not public Git artifacts. Keep this PR draft while
these remaining cases are addressed.

---

## 7 November dev3 — shared MPEG-TS / MP4 indexed access

The native ooRexx Media Object Access component has been extended on this branch with
**content sniffing**, MediaTsFile.cls and MediaTsWire for 188-byte MPEG-TS, and
a MediaMp4IndexSnapshot for source-bound MP4 sample-map reuse. The three Sydney
recordings end in .mkv but are **MPEG-TS** (H.264/AAC); extensions are not truth.

- MediaFile~open(source) dispatches from byte signatures; openMp4 remains supported.
- TS PAT/PMT discovery is bounded. buildIndexLocal(.true, localSizeBudget) is
  explicit and resident-node-only, never an implicit remote full scan.
- TS sidecars are source-version and size fenced; persistence is owned by
  Storage Fabric. Resumed planning is a binary search over IDR candidates.
- MP4 exportIndexText / installIndexText persist exact sample byte offsets,
  sizes, native DTS, composition PTS, elst-edited movie PTS and presentation
  lookup order. Repeated hot seeks need not rebuild 1.7 MiB of sample metadata.
- Both formats retain fail-closed decoded seekTime(EXACT) until native codec
  dependency/preroll and B-frame presentation reordering are qualified.

Run run_tests.sh under ooRexx 5.3, with MEDIA_TS_TEST_FILE set to a resident
file to include the actual MPEG-TS/sidecar regression. New tests are not yet
executed in this authoring environment (no rexx installed).
See docs/NATIVE_MPEGTS_MP4_SEEK_DEV3.md.

---

# ooRexx Media Object Access — v0.1-dev2 edit-list qualification candidate

The source remains in the `oorexx_media_object_access_v0.1-dev1` package
directory while PR #138 is in qualification. This is a structured ooRexx media
file interface, **not an FFmpeg wrapper**. Codec providers remain replaceable.

## Current implementation

- `MediaFile`, `MediaMp4File`, `Mp4Atom`, `MediaMp4Track`: bounded box
  inspection and track metadata. Seek past a 1 GiB `mdat` to find a tail `moov`
  without decoding or reading compressed payload.
- `MediaByteSource`, `MediaLazyReadSource`, `MediaStorageRangeSource`:
  zero-based, bounded absolute reads adapting existing LazyReadFile and
  Storage Fabric streaming APIs.
- `MediaMp4SampleTable`: metadata-only `stsd`, `stts`, signed/unsigned
  `ctts`, `stsc`, `stsz`, `stco`/`co64`, `stss`; sample byte offsets,
  sizes, DTS, PTS and durations in integer track ticks. Presentation lookup
  is stable-sorted independently of decode order.
- `MediaMp4Track~mapSamples` returns an in-memory map and
  `MediaMp4Track~planTime(ticks)` returns an **unverified decoder seek
  candidate**. `rangesForPlan` creates a bounded, coalesced list of
  physical sample byte spans rather than expanding across interleaved audio
  or unrelated media.
- `MediaRangeCacheSource`: optional fixed-budget read-through LRU over
  any MediaByteSource, with source identity and size fencing. No automatic
  sequential prefetch; repeated in-cache hot jumps do not re-fetch bytes.
- `MediaSeekIndex`: separate integer-tick binary-search primitive for
  prevalidated random access points.

## Deliberately NOT qualified

There is **no claim of exact frame seeking**. `MediaMp4Track~seekTime`
still rejects execution. An MP4 `stss` sync marker is a **candidate**:
codec reference chains (H.264/H.265 open GOP, B-frame dependencies), decoder
priming, and presentation frame delivery need codec-provider qualification.

Current limitations also include: complex movie edit-list `elst` timeline
transforms (fail closed), fragmented MP4 `moof`/`trun` and growing
recordings (fail closed), `stz2`, dependency/roll groups, CENC, external
references, persisted sidecar index loading, source generation recovery and
audio/video multi-track timeline synchronization. `stsz` sample count is
bounded at 2 million for the in-memory working index; no arbitrary stream
size is silently accepted.

`MediaStorageRangeSource` inherits the transport and source-identity
strength of its Storage Fabric provider. The existing `LazyReadFile`
identity is **path and size**, which is not strong enough alone to qualify
a persistent cross-node media index. Storage Fabric authoritative immutable
versions/content identities must be used for distributed evidence.

## Tests

Run from the package `tests/` directory under ooRexx 5.3:

```sh
rexx test_sparse_mp4.rex
rexx test_seek_index.rex
rexx test_mp4_sample_table.rex
rexx test_mp4_co64.rex
rexx test_mp4_elst.rex
rexx test_mp4_track_elst.rex
rexx test_media_cache_1gb.rex
```

The first two dev1 tests were reported **PASS on a local ooRexx 5.3
runtime** after fixing trailing `::requires` directives; that correction
is now committed. The dev2 tests and revised edit-list code require **fresh native qualification**
in the author's environment, which has no `rexx` executable. Rasen Falcon
test request REQ-00003273 asks CODEX-PC for read-only native qualification.

The synthetic 1 GiB fixtures model enormous source sizes with virtual
byte sources, not 1 GiB of allocated memory. They test metadata byte
traffic and bounds, not actual compressed decoding or remote link latency.

See `docs/DESIGN.md` for boundaries and full acceptance matrix.

## 5 November real-recording review and new edit support

Claude (Opus 5.5) independently reported that 4/5 native ooRexx dev2 tests
passed on ooRexx 5.3.0 r13196; the cache test failed on an omitted
superclass `::requires`. That dependency has now been fixed and Claude
reports the retest PASS (16,384 bytes from a synthetic 1 GiB source).

On real camera TP08, the reviewer compared 63,524 A-law packets against
FFprobe and found exact `byteOffset`/`sizeBytes` correspondence; the
constant 8,010 ticks at 90 kHz difference came from `elst`. This dev2
increment now handles `elst` v0/v1, a leading empty segment, and one or
more nonoverlapping unity-rate media segments with integer-expressible
track timestamps. It modifies movie presentation PTS, not media DTS or
sample byte address. Repeated/overlapping edits, nonunity playback speed,
and fractional track-tick boundaries remain explicitly unsupported.

`tests/test_mp4_elst.rex` covers +89 ms, trimmed media start and signed64
empty edit on a synthetic logical 1 GiB MP4. The new implementation has
**not yet been qualified against the resident TP08**; the review predates
these changes. Run the seven-test runner and then verify on the actual file.

A real 256 MiB camera MP4 reported 1,753,168 bytes of metadata reads to
construct the index, with approximately 22 seconds of ooRexx CPU time.
Persisting a source-version-fenced sample index remains essential for true
repeated hot jumps.

`tests/test_mp4_track_elst.rex` exercises the full native MP4 class route from
`moov/mvhd` through `trak/edts/elst` to a 1 GiB sparse sample mapping with
an unchanged byte address, rather than calling the table parser directly.
