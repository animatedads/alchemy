# Power SLAM v0.15 — Native ooRexx multi-frame fixed-landmark calibration evidence

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-02. Rasen Falcon lane `power-slam-harbour`. Tombstone Vision retains ferry recognition and motion. **No real-world camera pose has been accepted**.

## Inputs / provenance

User-provided 60-second transport streams, despite `.mkv` names:

| Stream | Raw filename | SHA-256 | Format | Camera |
|---|---|---|---|---|
| 1 | `stream1_20261102T062311Z.mkv` | `2636b416f57bcf0daff21cf5292b23ca0a791c2a3e82e32e850585d927bc2cad` | MPEG-TS H.264 AAC, 1280×720 30 fps | Western/Blues Point-style |
| 2 | `stream2_20261102T062311Z.mkv` | `bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0` | MPEG-TS H.264 AAC, 1280×720 30 fps | North-shore/Jeffrey Street-style |
| 3 | `stream3_20261102T062311Z.mkv` | `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d` | MPEG-TS H.264 AAC, 640×360 30 fps | Café Sydney |

All video streams use MPEG 90 kHz timebase and start at PTS 1.400 sec. **Matching relative PTS is not an independently proven simultaneous exposure time.** Source photographs/videos and grayscale sample bytes are **not** committed to GitHub and are not copied into this ZIP. Stream 1 displays an explicit `NOT FOR REBROADCAST` notice.

## Reproducible stream adapter

Run from a local checkout with ooRexx 5.3.0 r13196 and FFmpeg installed:

```
sh packages/oorexx_slam_v0.1/bin/run_harbour_stream_stability.sh \
  /path/stream1.mkv /path/stream2.mkv /path/stream3.mkv \
  /tmp/power-slam-stability
```

The shell script supplies **decode and 320×180 grayscale sampling only**, one image each 15 seconds, and validates four frames per stream. Only `SlamHarbourStreamStability.cls` does patch matching. 3 cameras × 4 image samples × 11 fixed ROIs -> 33 baseline-to-later comparisons. No OpenCV, no external image classifier, no synthetic-photo substitution. Native source image samples are binary luma bytes, not loaded as a photographic model.

`SlamHarbourStreamStability.cls` uses an image patch variance gate, bounded ±3-pixel search, nearest-neighbour mean-absolute luminance difference, rejects edge or changed patches, and emits a status that cannot grant a geographic camera pose. The test includes synthetic known ±pixel displacement and a uniform image rejection. Landmark anchors come from v0.14 provisional screen annotations (or visual annotations of the Café Sydney feed); the camera itself remains unsurveyed.

**Screenshot-to-feed coordinate transformation:** prior stream 1 and 2 screenshots were 1536×709 with ~138-pixel black sidebars, source active rectangle about 1260×709. Raw videos are 1280×720. Approximate map to native 320×180: `(x_old - 138) * 320/1260`, `y_old * 180/709`. Recheck this mapping if provider crop/zoom changes.

## Native results from actual three supplied streams

| Stream | Fixed ROI anchors | Later-frame comparisons | Shift at 320×180 | Mean MAD (8-bit luma) | Maximum MAD | Status |
|---|---:|---:|---|---:|---:|---|
| 1 | 3 | 9 | 9/9 zero shift | 1.54 | 2.52 | `FRAME_STABLE_POSE_UNQUALIFIED` |
| 2 | 4 | 12 | 12/12 zero shift | 0.57 | 0.92 | `FRAME_STABLE_POSE_UNQUALIFIED` |
| 3 | 4 | 12 | 12/12 zero shift | 2.60 | 5.92 | `FRAME_STABLE_POSE_UNQUALIFIED` |

ROIs correspond to bridge/pylon/crown, identified CBD/Opera skyline, or distant fixed waterfront. The patch identity is a *provisional* visual annotation, not a surveyed 3D corner. All best matches 0-pixel shift at quarter-resolution; this is **not** zero subpixel motion or an accepted 6DoF location. All 33 comparisons derived from actual recorded frames; images were not generated.

## Time observations — do not misuse

Visually transcribed fixed clock overlays at identical relative offsets into streams 1 and 2:

| Capture offset | Stream 1 clock | Stream 2 clock | Display delta |
|---:|---|---|---:|
| 7.5 sec | 17:23:06 | 17:23:01 | +5 sec |
| 22.5 sec | 17:23:21 | 17:23:16 | +5 sec |
| 37.5 sec | 17:23:36 | 17:23:31 | +5 sec |
| 52.5 sec | 17:23:51 | 17:23:46 | +5 sec |

`SlamHarbourClockEvidence.cls` qualifies this only as **`STABLE_DISPLAY_CLOCK_OFFSET_NOT_FRAME_SYNC`**, rather than claiming true capture-time offset of exactly 5 sec. Source clocks, network delivery and the devices' buffering may differ. Stream 3 has no comparable timestamp.

## Native qualification gates

- `test_stream_stability.rex`: **16/16 PASS**; native patch displacement, crop transform, no texture, out-of-bounds, invalid evidence admission.
- `test_clock_evidence.rex`: **12/12 PASS**; four stable clock readings; malformed/short/variable/rate-inconsistent evidence rejection.
- `measure_stream_stability.rex`: **33 actual fixed-patch comparisons**, three fail-closed temporal stability statuses.
- The previous v0.14 camera pose suite and v0.13 correspondence suite were rerun and passed 38/38 + 36/36. **These do not resolve the v0.14 real-world pose holdouts.**

## Next engineering work

Use stable source frames and v0.14 measured landmarks to refine true-perspective pixels and camera intrinsic/extrinsic hypotheses; control camera installation site using independent georeferenced building footprint. Separately identify the actual 3D pylon corners and arch locus, and establish per-stream capture-time mapping from shared ferry movement events if obtainable. Only then can Tombstone Vision consume a qualified camera-to-world transform. Never claim subpixel or metric accuracy from the stable 320×180 patch check.