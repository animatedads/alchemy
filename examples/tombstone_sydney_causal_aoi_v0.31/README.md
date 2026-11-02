# Sydney Harbour V5V v0.31 — causal automatic AOI lookup and temporal evidence

**Architecture:** user. **Native/Rexx implementation:** GPT-6, 2 November 2026. **Authority:** `OBSERVED_UNTESTED`. This is an experimental test of V5V-selected source-resolution search, **not** an independently qualified cruise-ship detector.

## Concrete advance over v0.30

v0.30 correctly measured source-pixel appearance features but used preselected, hand-reviewed fixed image regions. Here the native five-bit V5V source selects the search squares **without reading the hand-labelled ship rectangles or vessel labels**. Only the packed 80×45 indexed keyframes at original frame t, t−150 and t−300 and the existing provisional water mask are used. The selector tests 12×12-cell regions adjacent to the waterline, scores 5/10-second image-index changes, local palette edges and diversity, suppresses overlapping candidates and returns five ranked regions per test frame. It looks at frames **450, 900, 1350** from the two cameras' original cruise and normal captures (four videos).

**60/60** proposals generated (four clips, three frames each, five AOIs). Each is converted into an exact source-resolution RGB crop, with a two-cell context halo. The mean crop area is **6.963%** of the original image; maximum **7.111%**. Those are pixel-area budgets, not measured decoding CPU savings. 60/60 original crop SHA-256 and dimensions independently verified; 4/4 original video SHA-256 verified.

The proposals are evaluated *after selection* against the previous manually reviewed ship regions. In Camera 2, at least one V5V-selected crop covers approximately **98%, 98%, 100%** of the old ROI in three cruise frames; in Café Sydney's Camera 3 individual proposals capture only fragments of the much larger ship, as expected from fixed-size source regions. This is not independent-video blind recognition; the two clip periods and camera-specific masks were known to the project before this experiment.

## Actual native + ooRexx appearance test

Native C reuses `ship_structure_native.c` and additionally measures exact source pixel changes from original frame t versus t−150 and t−300. ooRexx r13196 `verify_v031.rex` associates each source/crop digest, frame/PTS, pixel/cell box and feature row, and refuses corrupted or status-promoted evidence.

| Actual observation (15 selected crops each) | Old v0.30 static-appearance support | Exploratory 5/10-second temporal anomaly |
|---|---:|---:|
| Camera 2 cruise | 2 | **0** |
| Camera 2 normal | 3 | **0** |
| Café Sydney cruise | 15 | **14** |
| Café Sydney normal | 9 | **0** |

This demonstrates **why v0.30's fixed-crop classifier cannot transfer unchanged**: 9/15 normal Café Sydney proposals have misleading bright structure. Temporal contrast appears much more informative in Café Sydney but **not** in Camera 2; it must abstain. A temporal-anomaly flag does not claim vessel identity. The thresholds (persistent change ≥0.05, dynamic bright fraction ≥0.02) were chosen during this experiment, **not preregistered or independently validated**. Do not present 14/15 versus 0/15 as a general detection accuracy estimate.

## Corrected source-pixel precision

The old direct FFmpeg YUV420 `crop` filter silently rounded the odd source origins (365,365) to (364,364) and (225,95) to (224,94). The corrected coordinates exactly reproduced **all four historical frame-900 RGB digests**. v0.31's `crop_raw.c` uses direct RGB pixel offsets; no implicit YUV420 crop rounding is possible.

## Qualification and reproducibility

- **4/4** original video source SHA, full native V5V selector replay **byte-identical 4/4**.
- **60/60** selected original RGB crop digests/sizes, source pixel metrics and time-contrast receipts.
- Full `replay_v031.sh` rerun against all four unchanged MPEG-TS source videos reproduced all 60 structural, 60 temporal and 60 ooRexx decision rows **byte-for-byte**.
- **15/15** deliberate false-status, forged-source, ROI/timestamp, conservation, V5V-bitstream and source-mask corruptions rejected.
- All geographic locations `BLOCKED_UNCALIBRATED`, physical vessel identity unresolved, no SLAM code-path `TESTED` scores.

Complete C and ooRexx source, replay scripts, packed V5V fixtures, precise RGB crops, receipt PSV and validation reports, masks, sample diagnostic and SHA manifest are delivered in the conversation archive `sydney_v5v_causal_aoi_v0.31.zip`, SHA-256 `bc361b79e99f274e6a928ccebf64f761ce7a8b0f65cd7b7a1aeeae57f8b19fb1` (~5.5 MB). Original source movies are not redistributed. Source replay requires the four originals and an ooRexx r13196 binary.

**Next:** held-out independent harbour traffic with labelled vessel position; multiscale adjacent proposal association; static-landmark compensation for Camera 2; explicit abstain thresholds; Power SLAM 3D position only after its camera pose and uncertainty are qualified.
