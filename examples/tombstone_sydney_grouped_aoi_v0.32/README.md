# Sydney Harbour V5V v0.32 — Native grouped AOI with Power SLAM landmark caution

**Date:** 2 November 2026. **Architecture:** user. **Implementation/qualification:** GPT-6. **Status:** `OBSERVED_UNTESTED`; this is a grouping and source-resolution retrieval experiment, **not** a general ship detector or surveyed harbour geometry.

## What actually ran

This is an additive continuation of v0.31, using the **same original V5V five-bit source-indexed data** and its 60 unclassified, causally chosen candidate squares. No labelled ship positions, future frames, Power SLAM hypothetical poses or matching outcomes enter the native grouping algorithm.

`source/v5v_merge_static_v032.c` validates the full 1,800-frame per-video native V5V receipt, exact blob offsets and 30-frame keyframe cadence; it decodes the original indexed pixels at t, t−150 and t−300. Each current timestamp's five proposed search squares are grouped by a ≥30-cell intersection of their lookup rectangles, using transitive union-find. Each group is the tight bounding box of its members. The source-to-world projection is intentionally **disabled**.

| Recording | Original V5V proposals | Grouped regions | Previously requested cells | Grouped rectangle cells | Exact union cells |
|---|---:|---:|---:|---:|---:|
| Cruise, Camera 2 | 15 | 9 | 3,712 | 3,237 | 3,012 |
| Cruise, Camera 3 (Café Sydney) | 15 | 4 | 3,808 | 2,555 | 2,312 |
| Normal, Camera 2 | 15 | 6 | 3,776 | 2,996 | 2,603 |
| Normal, Camera 3 | 15 | 9 | 3,744 | 3,135 | 3,036 |
| **Total** | **60** | **28** | **15,040** | **11,923** | **10,963** |

Net reduction in *requested rectangular pixel area*: **3,117 / 15,040 = 20.72%** across the fixed set of 12 frames. This counts repeated pixels in the original separate requests; it is *not* 20.72% of whole-video computation. The 28 merged ROIs are different sizes, from the same original 1280×720 and 640×360 sources; original full video remains immutable.

## Source-resolution second pass

The same original four user-uploaded videos from 2 November 2026 were SHA-256 checked:

- Camera2 cruise: `6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830`
- Camera3 cruise: `c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e`
- Camera2 normal: `bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0`
- Camera3 normal: `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d`

Exactly 9 source RGB24 frames per video were decoded sequentially (original indices 150,300,450,600,750,900,1050,1200,1350) and **28/28 grouped ROIs** retrieved at exact original pixel offsets via existing native `crop_raw.c`. Existing native `ship_structure_native.c` and `rgb_motion_structure.c` measured all 28 original-RGB24 groups against the earlier 5s/10s frames. Every crop has a source SHA, frame/PTS, bounding rectangle and RGB crop SHA.

**Independent full replay from all four original videos:** recompiled all native tools from source; the 28 region/crop/feature receipts and all grouping outputs are **byte-identical** to the initial v0.32 run, and the native ooRexx receipt checker passes. Both the historical source and new ROI data remain unchanged.

## Strict geometry boundary / Power SLAM

Power SLAM v0.12 has actual four user-roof-interior pylon controls and a harbour landmark model, **but not an admitted physical camera pose or 3D-to-image homography**. There is no legitimate basis for projecting a 3D bridge mask into the active images yet. To expose the overlap problem safely, the native grouper consults the older **approximate image-plane** Harbour Bridge region for Café Sydney from the source-bound v0.27a registration, `[3,43)×[7,25)` in its 80×45 grid. This is **not a projection from Sammy's 3D world** and is not a verified bridge segmentation. Groups overlapping it receive `UNSURVEYED_LANDMARK_OVERLAP_REVIEW` rather than rejection. Camera2 remains `UNKNOWN_UNSURVEYED`. **Some true ship areas overlap this approximate bridge region, so discarding all such candidates would create false negatives**.

The original t−5s/t−10s V5V keyframes give separate stable-upper, changing-upper and changing-water observations per group. The shoreline/bridge mask and temporal observations are **advisory**, not a vessel verdict. World output remains `BLOCKED_UNCALIBRATED`; every candidate stays `UNCLASSIFIED_GROUP|OBSERVED_UNTESTED`.

## Measured post-selection quality, not recognition accuracy

Compared **only after grouping** to the manually reviewed reference rectangle (which was not supplied to the grouper):

- Camera2 cruise: best group covers approximately **99%, 100%, 100%** of the reviewed reference object region at original frames 450/900/1350.
- Café Sydney cruise: best group covers approximately **60%, 53%, 65%**. A single v0.31 proposal previously covered only ~23–28% of that much larger region. This is still **incomplete object coverage**, especially at lower hull/waterline.
- On the existing experimental temporal threshold (both changes ≥0.05, dynamic-bright ≥0.02): Camera3 cruise **4/4 flagged**, Camera3 normal **0/9 flagged**. Camera2 cruise **0/9** and normal **0/6**, so Camera2 must **ABSTAIN**. These thresholds were developed on these recordings; they are not independent classification results.

## Native executable and fail-closed qualification

- `source/v5v_merge_static_v032.c` — packed native 5-bit V5V and source-linked region grouping.
- `source/crop_raw.c`, `source/ship_structure_native.c`, `source/rgb_motion_structure.c` — unchanged native source-resolution crop and appearance/temporal measurement tools from v0.31.
- `source/verify_grouped_v032.rex` — independent native ooRexx 5.3.0 r13196 receipt verifier cross-checking all original proposals against grouped membership, exact union pixel area, source-frame geometry, original image crop registration, time and evidence authority.
- `source/qualify_v032.sh` — **16/16 deliberately corrupt/forged cases rejected** (source, time, member and union accounting, TESTED, false ship, false surveyed pose, RGB digest/size, malformed keyframe, corrupt mask, etc.).
- `source/replay_v032.sh` — full four-original-video replay, with native decoding and per-crop source RGB; requires the original user videos, FFmpeg/GCC, ooRexx and v0.31 fixture directory or the equivalent bundled `v031` layout.

The `fixtures/` and `evidence/` subfolders in this archive are copies of necessary V5V source, masks and original unlabelled v0.31 proposals, NOT the original videos. The `results/` folder contains all 28 grouped-region PSV and cropped RGB SHA receipts, 28 actual packed RGB crops, diagnostic image, native outputs and qualification log. `MANIFEST.sha256` permits independent ZIP integrity checking.

**Important:** the first-party exact recognition layer must still distinguish foreground vessel from ship-adjacent bridge/shore and test against truly new video. Geolocation and cross-camera same-vessel confirmation depend on qualified Power SLAM pose/uncertainty, not these 2D boxes.
