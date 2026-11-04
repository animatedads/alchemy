# Tombstone Sydney v0.18 — Executed native V5V / Camera Behaviour motion evidence

**Date:** 31 October 2026. **Architecture:** user. **Implementation and qualification:** GPT-6. **Runtime:** Open Object Rexx 5.3.0 r13196 from user-supplied Debian package. **Authority state:** `OBSERVED_UNTESTED` for every result. Source media remains the authoritative evidence.

## What actually ran

Both original user-supplied videos were recovered and re-hashed:

- Manly: `1000066232.mp4`, SHA256 `2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192`.
- Other: `1000066230.mp4`, SHA256 `6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb`.

The full, previously decoded original-video-derived RGB24 feeds from the v0.15 archive had previously been qualified as byte-identical to fresh FFmpeg decoding. The source adapter only decodes/crops/resamples (1920x1080 source crop at x210, 5fps, 80x45 RGB24). No OpenCV, Python video processing, third-party tracking or semantic vessel classifier executes here.

`vision_dev22` from Library supplies unmodified `VisionSurface`, `V5VTemporalCodec`, `VisionSurfaceDelta` and `VisionChangeRegionExtractor`. The existing v0.16 `sydney_v5v_camera_motion.rex` was adapted only to load `CameraLumaQualityIndexed.cls` instead of the unavailable full Camera package. The latter loads `CameraLumaTrackIndexed.cls`; those two files contain a **manually copied, reduced source-method extract** of the actual `CameraLumaTemporalRegion`, `CameraLumaTemporalTrack`, `CameraLumaTemporalTrackSet`, `CameraLumaPrimitiveQuality` and `CameraLumaPrimitiveQualitySet` algorithms from `animatedads/alchemy` `packages/camera_behaviour_oorexx_v0.56`. Whitespace was reformatted in transcription. This is **not** an untouched canonical class file, and it is **not** qualification of `CameraCore.cls` or the complete Camera Behaviour dependency closure.

One deliberate local performance change: `CameraLumaTemporalTrackSet~trackById` uses an ID-indexed Directory instead of scanning the track array. On the real first 24 Manly frames, the original extracted array-scan and indexed variants produced **byte-for-byte identical 24-frame TSV and 364-track TSV**. Timing was 17.23s original vs 17.19s indexed, so **no performance improvement is claimed**. The complete native runs used this indexed version.

## Actual complete-source native results

| Measured field | Manly | Other |
|---|---:|---:|
| Duration at 5fps | 31.2 seconds | 26.0 seconds |
| Indexed V5V surfaces, exact | 156/156 | 130/130 |
| V5V keyframes | 16 | 13 |
| V5V deltas | 140 | 117 |
| Changed cells across every consecutive frame (including keyframe boundaries) | 5,429 | 5,451 |
| Camera four-neighbour motion regions | 4,522 | 4,492 |
| Clip-local Camera motion tracks | 2,101 | 1,868 |
| Persistent tracks (2+ observations) | 977 | 913 |
| Quality-admitted motion primitives | 436 | 481 |
| Rejected motion primitives | 1,665 | 1,387 |
| Longest motion track | 22 observations | 22 observations |
| Elapsed, single ooRexx process | 141.49 seconds | 119.67 seconds |

`V5V` exactness applies to the reduced quantized surface, **not original H.264/RGB24**. `VisionSurfaceDelta` runs across all consecutive reconstructed surfaces including codec keyframe boundaries, which is why full v0.18 changed-cell totals differ from v0.17's delta-record-only statistics. This is expected and preserves motion across a keyframe.

## Qualification

- Syntax checks via real r13196 `rexxc -s`: consumer, classes, verifier, event projection, and ranking compile.
- Native complete-source run: PASS for both.
- `verify_v5v_camera_tracks.rex`: both real receipts PASS. Checks exact per-frame chronology, source hashes, 10-frame keyframe cadence, `OBSERVED_UNTESTED` invariants, track uniqueness and chronology, gate consistency, and **total motion-region observations equal total track observations**.
- `qualify_native_tracks.sh`: 8/8 deliberate tamper cases rejected on each **real full clip**: false TESTED on frame/track, repeated frame, forged source hash, missing frame, wrong keyframe, duplicate track ID, unauthorised identity field.
- `project_track_events.rex`: 2,101 Manly + 1,868 other camera tracks projected into typed, source-linked `VISION.MOTION.QUALITY_ADMITTED` and `VISION.MOTION.QUALITY_REJECTED` event rows. This is an **evidence-only projection**, not a SLAM graph write, graph score, `TESTED` result, georegistration or vessel-identity result.
- `top_motion_tracks.rex`: outputs the 20 longest quality-admitted candidate motion fragments from each clip; **no vessel labels** are assigned. The longest admitted Manly fragment has 20 observations; the longest *any* track has 22.

## Package

- `src/`: source-method-only Camera extract, constant-time lookup experimental variant, and the existing V5V/Camera consumer with changed `::requires`.
- `tools/`: native receipt verifier, eight-case tamper runner, event projector, top-motion-fragment shortlist.
- `evidence/`: complete frame, track, event and shortlist PSV for both original clips.
- `qualification/`: original native execution logs, full receipt verification and negative-test logs.
- `MANIFEST.sha256`: hashes for all delivered source and evidence files.

To re-run, place the original `vision_dev22/src` on `REXX_PATH` alongside `src/`, then use `sydney_v5v_camera_motion_indexed.rex` with the original v0.15 full RGB24 feed, respective original source SHA, expected frame count and output file paths as in v0.16. Validate the resulting files through `verify_v5v_camera_tracks.rex` and project events only after verification. The *raw MP4s/RGB24s are deliberately excluded* from this publication.

## What is **not** established

The quality gates admit **motion fragments**; water, reflections, wakes and changing light create many fragments. **2,101 tracks does not mean 2,101 objects**. These methods do not yet recover the Manly ferry as one persistent object; the longest raw track spans only 22 reduced samples. There is no camera-world calibration, metre-based speed, independent ferry identity, or SLAM graph-tested recognition. The original OpenCV v0.11 unseeded result is kept as a separate evaluation comparator, not used as detection here.

**Next acceptance gates**: obtain and test the *complete canonical* Camera package; preserve individual region bounding boxes and frame timestamps on each track; exercise native cross-gap object continuity / high-res AOI under the existing Camera Behaviour + Vision contracts; explicitly qualify persistent ferry-vs-water hypotheses using held-out footage. Promote to SLAM `TESTED` only through its own accepted formal test authority, never by the event projection.