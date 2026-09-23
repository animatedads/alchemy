# Vision 3D Reconstruction v0.1-dev1

This package adds an evidence-aware 3D reconstruction layer above ooRexx Vision. It does not turn Vision into a conventional dense photogrammetry pipeline.

## Governing rule

Reconstruct what the recording supports. Preserve the distinction between observed, inferred, occluded and unseen geometry. Returning to the source is explicit and selective.

## Authority split

- **Vision v0.1-dev14** owns V5V surfaces, stable 2D/world coordinates and `VisionHighResolutionRequest` / `VisionRegionMaterial`.
- **ooRexx Maths v0.8** owns vector, ray, plane, camera-transform and projection mathematics.
- **Line Assessment** may provide independent compact line/run evidence.
- **Camera Behaviour** may provide camera/global-motion evidence; its activity hierarchy remains independent.
- **Vision 3D Reconstruction** owns multi-view ray evidence, triangulation acceptance, sparse 3D cell evidence, support-only roles and semantic enhancement work items.

## Progressive path

```
authoritative video
    -> lowest useful V5V observation stream
    -> line / behaviour / geometry evidence
    -> coarse camera poses and matched rays
    -> sparse adaptive grid
    -> explicit uncertainty
    -> semantic enhancement item
    -> VisionHighResolutionRequest
    -> authoritative source crop/time
    -> refine only affected geometry
```

The enhancement item is a question such as `DOOR-HINGE-AXIS / DEPTH-UNCERTAINTY`. The rectangular source region is merely how that question is serviced.

## Grid states

Stored evidence states are:

- `OBSERVED_OCCUPIED`
- `OBSERVED_FREE`
- `INFERRED_SURFACE`
- `INFERRED_FREE`

`UNSEEN` and `OCCLUDED_UNKNOWN` are semantic states that normally require no allocated sparse cell. If both free and occupied observations hit one cell, the resolved cell state is `CONFLICTING_OBSERVED`; evidence is retained rather than silently overwritten.

A cell may also have role `SUPPORT_ONLY`. A floor/table/shelf can therefore calibrate geometry and occlusion while being suppressed from a final object-only diagnostic mesh.

## Camera convention

`Vision3DCameraModel` uses explicit focal X/Y and principal point. No intrinsic parameter is silently inferred. Image Y points down; the camera ray conversion maps it to Maths Y-up. Handedness comes from `Math3DConvention`.

## First-cut limits

- Pose estimation and feature correspondence are input seams, not implemented here yet.
- No global bundle adjustment yet.
- No metric scale is fabricated. Scale must come from calibration or trustworthy dimensional evidence.
- PLY export is diagnostic only; the sparse evidence grid is authoritative.
