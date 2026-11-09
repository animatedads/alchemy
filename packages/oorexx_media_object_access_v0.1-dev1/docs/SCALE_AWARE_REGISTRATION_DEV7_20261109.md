# Media Object Access dev7 and Moonsault: scale-aware Sydney registration

**Date:** 9 November 2026. **Owner:** Media Object Access (raster geometry) and Moonsault (astronomical evidence). **Implementation:** ooRexx 5.3.0 r13196 classes with native in-process, stateless C++ raster arithmetic; no Python image processing, OpenCV, FFmpeg executable, file access or codec parsing in the native geometry provider.

## Why dev7

The sixth screenshot at 2026-11-09 22:08:42 AEDT is 1316x742, while the preceding five at 20:17:25–20:37:11 are 1920x1080. Resizing to a shared raster size is insufficient to guarantee identical viewpoint or capture geometry. Dev6's integer-translation model gave a -3,-3-pixel candidate with a large gradient residual. Differences due to crops, zoom, weather and cloud motion must not be called stars.

## Public ooRexx APIs

- `.MediaRasterOps~estimateSimilarity(ref, frame, roiX,roiY,roiW,roiH,maxShift,maxScalePermille,stepPermille)` returns an **unqualified** integer-ppm uniform-scale/subpixel-translation proposal. It cannot authorize image subtraction.
- `.MediaRasterOps~estimateSimilarityValidated(ref,frame, fitX,fitY,fitW,fitH,checkX,checkY,checkW,checkH, maxShift,maxScalePermille,stepPermille,maxFitPpm,maxCheckPpm,minMarginPpm)` evaluates a **disjoint held-out landmark ROI** (downtown and bridge) and sets `QUALIFIED=1` only if both scores and independent-solution margin pass the caller's thresholds.
- `.MediaRasterOps~warpSimilarity(frame,fit)` applies the validated transform using bilinear interpolation for each R/G/B/A channel. Passing an unqualified fit fails closed; explicit third argument `.true` is **diagnostic only** and is not admissible for astrometric evidence.
- `.MediaRasterOps~similarityValidity(w,h,fit)` returns an 8-bit 0/255 true source-overlap plane. Cropped-out pixels are invalid, **not** black background.
- `.MediaTemporalDifferenceMask~addSimilarityFrame(frame,identity,fit)` preserves the exact camera-transform provenance and validity mask; it refuses unqualified registrations. Existing translation and 50%-intensity model methods remain unchanged.
- `.MoonsaultFullResolutionRevisit~examine(fullFrame,coarsePositiveMask,maskW,maskH,skyRegion...)` groups coarse changes, revisits bounded 13x13 source-luma windows at **native image resolution**, and distinguishes point-like morphology from diffuse regions; it does not assign star identities.
- `.MoonsaultFullResolutionRevisit~corroborateShortInterval(before,after,x,y, minContrast, maxPixelDisplacement)` requires actual persistence; a point-like aircraft streak in one screenshot can fail this gate.

**Coordinate convention:** The output pixel `(x,y)` is obtained from target pixel `centre + ((x,y)-centre-shift)/scale`. Scale is in parts-per-million (1000000 means unchanged) and subpixel shifts in milli-pixels. This is a similarity (uniform zoom + x/y shift), **not** a complete affine/homography camera correction, a lens model, or a 3-D parallax solution. Different viewpoints and projection/rolling-shutter effects remain unqualified.

## Native executed tests

Runtime: user-supplied `ooRexx 5.3.0 r13196` Ubuntu debug build, extracted and used without system installation. Test sources under `tests/` and `moonsault/tests/`.

- Existing `test_registration.rex`, `test_temporal_mask.rex`: **PASS**, no regression in translation, 50%-intensity model, 20% photometric gain, or frame-1 retrospective recovery.
- `test_similarity_registration.rex`: **PASS** for known 1.025 uniform camera scale, +2/-1 pixel shifts and +20% brightness. Estimated 1.026, +2/-1. Independent holdout gradient scores 0.1792 / 0.1771 (synthetic intentionally has high-frequency texture and two resamplings; synthetically accepted with explicit 0.25/0.25 limits). Validity excludes out-of-frame sample under independent zoom-out test; temporal model retains scale and heldout provenance.
- `test_sydney_six_similarity.rex`: **PASS** all six readings attempted. Candidate fits are separately recorded in `outputs/sydney_six_similarity.tsv`.

| Sydney observation | Scale ppm | dx, dy (milli-pixels) | Downtown / held-out bridge residual ppm | Qualified? |
|---|---:|---:|---:|---|
| 20:17:25 | 999000 | -250, 0 | 76746 / 130071 | **No** |
| 20:24:30 | 1000000 | 0, 0 | 54750 / 54198 | **Yes** |
| 20:32:05 | 1000000 | 0, 0 | 32523 / 31686 | **Yes** |
| 20:32:17 | 1000000 | 0, 0 | 31823 / 30809 | **Yes** |
| 20:37:11 | 1000000 | 0, 0 | 0 / 0 (reference) | **Yes** |
| 22:08:42 | 1002000 | -2250, -2750 | 119196 / 141338 | **No** |

Conservative real-data thresholds: fit and disjoint heldout each at most 125000 ppm and next-best score margin at least 2500 ppm. These are **landmark-gradient**, not pixel-astrometry, residuals. **4 of 6** including reference pass. The two rejected images must not be combined for a celestial heading without improved geometry/calibration.

## Full-resolution revisit and aircraft negative control

- `test_fullres_revisit.rex`: synthetic small, compact 1-pixel source **accepted as `POINT_LIKE_UNIDENTIFIED`**; a broad 25-cell cloud mask **rejected**; a +1-pixel repeat source **corroborated**; a missing point **rejected**.
- `test_sydney_220842_fullres.rex`: 97 bright-change pixels in the earlier 329x185 50%-threshold sky region resolve into **7 coarse clusters** when grouped. At native 1316x742 image resolution, **zero** meet the compact point-shape criterion: 3 broad coarse blobs, 4 low-contrast/diffuse windows. No new star identification is claimed.
- `test_sydney_four_qualified_stars.rex`: the four geometrically accepted screenshots form the independent four-frame temporal mask. Coarse positive-change sky counts: **0 / 0 / 1 / 22**. The only compact bright region is near `(218,178)` in the 1316x742 aligned image at **20:32:17**. Its original 1920x1080 coordinate is about `(318,259)`, matching the visually observed aircraft streak. The 20:32:05 frame, 12 seconds earlier, has **3.58** local contrast levels there; the streak frame has **182.72**, so `corroborateShortInterval` returns **`TRANSIENT_REJECTED`**. The two later broad changes are diffuse. No sample is upgraded to a named star or celestial fix.

This result illustrates a real failure mode: a cropped aircraft streak can appear point-like. **Both spatial shape and temporal persistence are required**. Cloud occlusion means absence alone cannot prove an object is not astronomical; in this controlled pair the explicitly visible bright aircraft transient is rejected from star-candidate use, not assigned a definitive biological or aviation identity by software.

## Residual work

The two rejected cameras may have illumination, overlay, local geometry, cloud, zoom/parallax or screenshot resampling differences. Uniform similarity is not a physical camera-calibration model. To recover them, fit a cross-validated multi-landmark affine/homography or lens-aware model, preserve valid coverage, and then return to native original-resolution point tracking. Full Yale catalogue plate solving and unambiguous star identities remain **unqualified**. Source screenshots, cropped images and derived image masks have not been committed to the public repository.