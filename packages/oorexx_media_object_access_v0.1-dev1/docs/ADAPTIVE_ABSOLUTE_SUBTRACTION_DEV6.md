# Media Object Access dev6 — bounded geometry and evolving absolute subtraction mask

**Native execution:** ooRexx 5.3.0 r13196 on Ubuntu. All new image-analysis execution authority remains ooRexx; the in-process `moa_raster_ops` C++ library is a stateless pixel arithmetic provider. No Python, OpenCV, ffmpeg executable, libavformat or file IO is in that provider.

## API and pixel semantics

```rexx
ref     = .MediaRasterOps~asImage(pngFrame)   /* RGB24 / RGBA32 */
roi     = ref~crop(138,0,1260,600)          /* preserve native channels */
work    = roi~resizeToProcessing(315,150,'AREA')
change  = work~subtractFrame(previousFrame)   /* signed 16-bit per RGB channel */
absolute = change~magnitude                    /* max abs delta over channels */
redOnly = work~subtractLayer(.MediaRasterLayer~new(plane,w,h,1),0,0,'R')

history = .MediaTemporalDifferenceMask~new(315,150,50,12,16,3)
ignored = history~addFrame(work1,'2026-11-10T03:45:21+11:00')
ignored = history~addFrame(work2,'2026-11-10T04:05:09+11:00')
/* The third and fourth images rebuild the background. */
ignored = history~addFrame(work3,'2026-11-10T04:05:41+11:00')
ignored = history~addFrame(work4,'2026-11-10T04:41:17+11:00')
firstAgain = history~scoreAt(1) /* retrospective: uses all FOUR frames */
mask = firstAgain~changeMask   /* 0 or 255 per pixel */
bright = firstAgain~positiveMask /* only positive brightening */
dark = firstAgain~negativeMask   /* only darkening */
```

- `crop(x,y,w,h)` uses zero-based source coordinates and fails outside bounds. `resizeToProcessing(w,h,'AREA')` uses pixel-footprint area averaging, not top-left sample dropping; `BILINEAR` and `NEAREST` are explicit alternatives. RGB and alpha are resampled independently (not alpha compositing).
- `subtractFrame(other, includeAlpha=.false)` returns **signed 16-bit big-endian** per-channel `current - other`; negatives remain negative. `deltaAt(x,y,channel)` retrieves signed integer; `magnitude` returns 8-bit max absolute channel change. For alpha changes both images must be RGBA32 and `includeAlpha=.true`.
- `subtractLayer(layer,x,y,channel='X',includeAlpha=.false)` subtracts an RGB/RGBA image or a mono layer into an offset ROI; non-overlap returns zero. Single-plane layers select R/G/B/A/Y. No alpha compositing or opacity multiplication is implied.
- Original alpha is retained by PNG; JPEG and H.264 synthesize A=255. Four split PGM R/G/B/A planes, RGB PPM and RGBA PAM remain available unchanged from dev5.

## Adaptive absolute background model

For a succession of **registered** luma frames `I_i`:

1. Each added frame is photometrically aligned to the first via a robust median of ratios from mid-tone samples. Example: global +20% gain gives normalisation gain approximately `0.833333`. Highly saturated and very dark pixels are excluded from the gain estimator. The gain and original sample identity are retained.
2. Per pixel, compute `B(x,y)` as the *lower median* of the available normalised samples. A star occupying one position in one of four images does not become part of the static building/sky background.
3. Derive a robust temporal-noise plane `N(x,y)` as the lower median absolute deviation from `B`.
4. **Your 50% threshold is a local-relative threshold:** `T(x,y) = max(12, ceil(0.50 * max(B(x,y), 16)), 3*N(x,y))` intensity levels. These constants are independently configurable. A uniform city light at level 120 tolerates up to 60 levels change; a faint sky baseline of 30 tolerates 15 levels; a stellar spot jumping from near-black to 220+ exceeds it.
5. Each frame is scored again against the **new** model: `D_i = abs(I_i - B)`; `mask_i = (D_i > T)`; also preserve separate positive/negative change planes.
6. Adding frame 3 or 4 invalidates cached scores, rebuilds the model, and therefore permits discoveries in frame 1 that were not accepted before. No old score is silently re-used after a model update. `modelGeneration` exposes this change.
7. A source shifted outside its own borders is **invalid**, not black scene content: every sample has a matching validity plane; invalid pixels cannot create false transient detections in the temporal score.

**Important:** this detects moving bright *candidates*, not stars by itself. Clouds, moving insects, aircraft, changed lights and camera artefacts can also exceed `T`. Moonsault applies temporal trajectory, morphology, cloud/sky masks and catalogue matching separately.

## Registration / camera movement

`MediaRasterOps~estimateTranslation(reference, frame, roiX,roiY,roiW,roiH,maxShift)` estimates an **integer** pixel shift using a caller-selected, stable, textured **landmark ROI** (not the moving sky). It uses normalised edge gradients to tolerate global illumination changes. The score is returned with the shift and sample count; texture-deficient or ambiguous cases **fail closed**. Synthetic +1 pixel shift with +20% ambient light recovered dx=-1, dy=0; the real Sydney building ROI recovered dx=0, dy=0 (score 0.052 on normalized gradients). The caller applies the shift via `translateBy`, or can use `MediaTemporalDifferenceMask~addRegisteredFrame(...)`. Registration validity planes suppress missing image border pixels.

A camera physically moving toward a subject can produce scale and parallax, which integer translation **cannot** correct. Use explicit crop/resize with known geometry or a separately qualified affine/homography/3-D registration provider before temporal subtraction. Do not treat an unregistered view as meaningful differences.

## Resource and media-fabric contract

- `MediaTemporalDifferenceMask` accepts at most 16 samples of at most 2,000,000 pixels per registered processing frame (e.g., 315x150), not unbounded 4K full-frame history.
- Processing data are bounded in caller-owned byte planes; the native provider has **no file/network access**. Original MP4/TS remains indexed/range-readable by the existing Media Object Access component. This does not change the MP4 hot-seek contract.
- PNG, JPEG and H264 frames all share `crop`, `resizeToProcessing`, `subtractFrame`, `subtractLayer` instance methods and the independent `.MediaRasterOps` class methods.
- **Webcam clock vs player PTS:** scrubbed selections preserve each supplied webcam timestamp explicitly; do not interpolate astronomical time across playback-slider jumps.

## Native qualification

Run from `tests/` with `REXX` and native library path configured:

```sh
rexx test_temporal_mask.rex
rexx test_registration.rex
rexx test_real_jpeg_geometry.rex
rexx test_sydney_jpeg_registration.rex
rexx test_sydney_five_jpeg_temporal.rex /mnt/data /path/to/output
```

All five passed on the supplied r13196 runtime. In the five *real* Sydney screenshots, sky-region bright-change counts are 556, 66, 65, 2, 2; lower-scene bright-change counts are 22, 0, 2, 14, 22 (processing 315x150, upper/lower split y=72). The first frame's large sky count includes moving clouds; it is **not** 556 stars. Reported gain was 1.000000 for the five real JPEG samples, whose overall measured illumination did not require a global change; the separate synthetic test explicitly exercises the +20% gain case.

Remaining qualification: scale/parallax and subpixel image registration, local nonuniform illumination adaptation, Moonsault cloud rejection and astrometric identification. Do not promote this absolute mask to a celestial heading on its own.