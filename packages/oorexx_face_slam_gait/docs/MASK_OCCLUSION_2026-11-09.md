# Face SLAM — source-bound mosaic/occlusion continuation test

Date: 2026-11-09. Implementation: ooRexx 5.3.0 r13196, independent of Python inference.

## Intent

Detect a candidate loss of an anonymisation mask after a temporary occlusion. This is a diagnostic of video redaction continuity; it is not proof of a particular vendor bug and does not make biometric identity assertions. The local video is an authorised test input supplied by the user; neither video bytes, source-derived face crops, nor unblurred reference imagery are committed to public Git.

## Component boundaries

- **Vision / Motion Control**: source frame, AOI/ROI, track, occlusion and visibility evidence; no shadow temporal tracker introduced.
- **Media Object Access**: source-bound RGB24 pixels and presentation ticks, with MP4 seek and codec qualification retained upstream. `FaceSlamMosaicProbe~inspectRgb24(frame~pixels,frame~width,frame~height,x,y,w,h)` consumes a previously decoded frame; no FFmpeg call or file I/O.
- **Perception**: optional landmark/provider evidence, not assumed for this proof.
- **Face SLAM**: source-bound mask-state evidence and review-only continuity hypothesis.
- **Maths/ML**: the existing gait/landmark classes continue to use Maths; this increment uses basic integer edge-counting and does not duplicate vector, matrix or geometric transformations. Do not introduce a test-only Maths shim here.

`FaceSlamMaskContinuity` accepts frame-global integer microsecond PTS, a 64-hex source SHA-256, camera, anonymous track and model/annotation digest. It rejects out-of-order and cross-source/track observations. Two unobscured high-confidence observations are needed for a repeated observation, distinct from a first review candidate. Fully occluded frames must carry `UNKNOWN` mask state.

`FaceSlamMosaicProbe` works with RGB24 bytes, a bounded in-frame ROI and two 1-D gradient profiles. It examines periodic edges at candidate separations 7..24 pixels and reports `gridLift`, `flatFraction` and grid-spacing hypotheses. `MOSAIC_CANDIDATE` is deliberately not `CONFIRMED_MASKED`: occlusion, ROI drift, large regular texture and codec artifacts can produce false positives. A dedicated validated face/occlusion provider and calibrated thresholds are required before automated annotation can replace the manual evidence used below.

## Video benchmark (local-only)

- Source `face_blur.mp4`, SHA-256 `8e236084a0a9068037bd8dde61d0d600f6de27ee6f3d07d83250c3aef287e76c`, 1920×1080, H.264, 25 fps.
- Target: anonymous `WOMAN_WHITE_BLOUSE_A` track, **not** an identity.
- Manual visual classification: mosaic visible through frame 94 (3.76 s); frames 95–99 have strong foreground occlusion, so the presence or absence of the facial mask is **not observable**; mosaic absent on the visible face from approximately frame 100 (4.00 s) onward.
- Transition interval from last observed mosaic to first observed unmasked face: `(3.76, 4.00] s` (not necessarily the moment the filter switched).
- All pre-failure reconstruction inputs were frames 84–94; clear frames from ~100 onward are held out from reconstruction.

### RGB24 mosaic-grid audit (64×64 local face ROIs)

Frame | seconds | gridLift | flatFraction | classification
--- | ---: | ---: | ---: | ---
86 | 3.44 | 6.60 | 0.585 | MOSAIC_CANDIDATE
89 | 3.56 | 6.69 | 0.619 | MOSAIC_CANDIDATE
91 | 3.64 | 8.10 | 0.640 | MOSAIC_CANDIDATE
93 | 3.72 | 18.48 | 0.697 | MOSAIC_CANDIDATE
94 | 3.76 | 16.51 | 0.683 | MOSAIC_CANDIDATE
100 | 4.00 | 4.09 | 0.480 | INDETERMINATE
101 | 4.04 | 4.94 | 0.511 | INDETERMINATE
103 | 4.12 | 2.14 | 0.549 | INDETERMINATE

The scores are diagnostics only. No calibrated sensitivity/specificity or per-frame ground truth has yet been measured. The post-occlusion scores correctly **abstain** rather than automatically asserting `UNMASKED`.

## MP4 path

`animatedads/alchemy` draft PR #138 contains the shared ooRexx MP4 object/index and MPEG-TS H.264 native RGB frame provider. MP4 exact decoded-frame seek is **not yet qualified**. The source file has no B-frame reordering and 5-second IDR intervals, so an exact request at 3.64 s requires codec-preroll from the keyframe at 0 s even though the sample table can find the requested sample bytes. A metadata-only `planTime` must never be represented as decoded pixel access. Use the source's immutable digest and source-global PTS for the restored index.

## Qualification

Run under ooRexx 5.3.0 r13196:
```
rexx tests/test_mask_continuity.rex
rexx tests/test_mosaic_probe.rex
```
The new classes passed 22 + 6 local assertions. All 58 existing gait/temporal/pose contract assertions also passed on the same runtime. These tests do **not** qualify real MediaPipe inference, a production MP4 decoder adapter, or facial detail reconstruction from mosaics.