# Power SLAM: real-image horizontal qualifier, v0.2

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01. Additive experiment to Power SLAM v0.1. Does not modify accepted SLAM runtime contracts or upstream source.

## What is now read from the three source screenshots

Source: user-supplied photographs in the ChatGPT conversation (not redistributed). Each coordinate is an approximate, manually annotated **horizontal** landmark pixel in the full 1,536-pixel-wide screenshot; not an optical centre or a surveyed world point. Landmark identity is verified from the topological arrangement of Sydney Harbour Bridge and Opera House. Image-level uncertainty remains approximately 15–35 pixels; centre of the mapped structure may differ from selected visible skyline position.

| Image | Landmark X observations (pixels) | Role |
|---|---|---|
| 1 (bridge left, Opera under span) | N=185, O=575, S=685 | Inverse unknown camera site; lens focal length also unknown |
| 2 (Opera left, bridge on right) | O=276, S=906, N=1255 | Inverse unknown camera site; lens focal length also unknown |
| 3 (Café Sydney rooftop, bridge) | S=70, N=770 | **Known** camera geographic location, independently constrains lens zoom |

The image 3 control site is Customs House, 31 Alfred Street, Circular Quay, Sydney, verified by NSW Government. Its representative *building centre* coordinates (-33.862128338141, 151.21083913743) come from Dictionary of Sydney. Rooftop camera offset and camera height/pitch are not measured. The first two photographs' camera locations remain UNKNOWN. No inference is made from moving ferries or wakes.

Sources: https://www.nsw.gov.au/visiting-and-exploring-nsw/locations-and-attractions/customs-house ; https://dictionaryofsydney.org/building/customs_house

## Mathematics added

`SlamHarbourObserved.cls` adds `HarbourPhotoPose`. `fitHorizontal(mask, observations, focalSamples, imageWidth, gridStep, maxResults, maxRms)` uses only explicit image horizontal landmark measurements, searches **eligible mask cells only**, solves yaw from first landmark via existing `HarbourScene~aim`, enumerates focal samples, projects other landmarks, calculates image-pixel horizontal residual and retains *all* sampled matches under an absolute threshold count. All candidate matches are `HYPOTHESES_NOT_LAND_QUALIFIED`; no world camera coordinate is accepted without a georegistered real coastline mask. They cannot be used as a source of geographic truth.

`calibrateAt(knownCameraXY, twoOrMoreLandmarks, focalSamples, width, maxRms)` performs control-point calibration independently of unknown-site inversion. It cannot infer a site from a pair of landmarks; it scans focal lengths and returns the admissible **interval**, not one arbitrarily selected unique lens.

For the provided photographs on the v0.1 **demonstration-only** land rectangles and focal samples 500–4000px:

* View 1: 700 sampled (location, focal) combinations within horizontal 35px RMS; best approximately (x=-1100m,y=+650m,f=1100px), horizontal RMS 0.99px. This coordinate has NOT been land-qualified. The score is only agreement with three manually annotated horizontal image pixels; many different points fit.
* View 2: 117 combinations under that threshold; best approximately (x=+875m,y=+575m,f=1250px), horizontal RMS 2.66px. Again NOT land-qualified; no site asserted.
* View 3: known Customs House coordinate yields best focal sample 2700px, squared horizontal residual 62.46px² for two pylon samples; multiple neighbouring focal samples meet the intentionally wide 55px RMS threshold. The figure is focal **pixels in the un-cropped 1536px screenshot coordinate system**, not millimetres or unique intrinsic camera calibration.

These count summaries are **not probabilities**, and `f=2700px` may reflect camera zoom or the difference between true pylon centres and visual annotations. They do not prove that images 1/2 share a lens or physical site.

## Security and epistemic gates

* Strictly at least three distinct known static landmarks for UNKNOWN camera site; with only two, status is `INSUFFICIENT_LANDMARKS` even if they seem visually distinctive.
* Known camera location is provided explicitly to calibration. It must NOT be obtained by inverting two unknown landmarks and pretending the location is known.
* Horizontal-only fits do not solve elevation, pitch, occlusion, lens distortion or shoreline. No 3D pose certified from v0.2.
* Manual demo rectangles may contain harbour water. **They are NOT a coastline mask; all resulting unknown-camera matches are labelled not land-qualified.** This is the required response until a *georegistered, verified land raster* is attached.
* Field-of-view must be inferred separately for each view; the Café Sydney feed appears zoomed relative to the other two.
* No screen source photographs are committed or redistributed, especially the stream marked “NOT FOR REBROADCAST”.

## Run

From the directory containing `SlamHarbourPose.cls`, `SlamHarbourObserved.cls` and `test_harbour_observed.rex`:

```sh
REXX_PATH="$PWD" rexx test_harbour_observed.rex .
```

This test also synthesises fresh observations from a known camera and focal length to ensure the variable-focal solver can recover both, and deliberately supplies contradictory image pixel observations to assert a clean refusal.

## Next gate

1. Register both user-supplied Google Maps screenshots with **independent control points** and quantify mapping error, not with user-submitted locations guessed from vision.
2. Derive a conservative positive-land raster in the same projected coordinate system, classifying ambiguous shore pixels and bridges `X` (unknown). Nearby cyan blue remains water `B`. Validate against safe land and known water controls.
3. Re-run real photo constraints against that registered raster with uncertainty swept across possible camera intrinsics. Only then name candidate shore regions; require multiple independent vertical or depth features for a 3D pose.