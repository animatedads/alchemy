# Apron SLAM — road, camera and cuboid projection (v0.1-dev3)

This additive package models a straight finite-width road, an oblique elevated camera and a moving vehicle cuboid with a blank UK-sized plate plane. All geometry is in metres. Rendering is source-bound and uses explicit camera intrinsics and shutter duration. This module DOES NOT contain actual recordings, plates, registration strings, vehicle identifiers, or extracted crops.

## Owner boundaries

- Apron SLAM owns semantic objects: road section, vehicle hypothesis, plate plane, source-relative vehicle trajectory and reprojection residuals.
- Alchemy Maths remains the implementation authority for trigonometric angle creation and projected-distance magnitude calculations: `ApronRoadBasis~fromDegrees` uses `.Maths~angleDegrees`, `~sin` and `~cos`; `ApronRoadScene~platePixelDimensions` uses `.Maths~sqrt`.
- For synthetic tests, a caller can inject an already validated sine/cosine orientation basis and use squared distances; no new Maths implementation or fake Maths authority is shipped.
- Motion Control owns temporal tracks and source timestamps, Vision/Perception own frame-level observations, Media Object Access owns source-bound media I/O, and SLAM owns choosing and scoring hypotheses. No independent Python process or video decoder is part of this package.

## Classes

- `ApronRoadBasis`: yaw/pitch/roll direction cosines; `fromDegrees` via Alchemy Maths.
- `ApronRoadCamera`: pinhole camera, world-to-image projection, single radial distortion coefficient, explicit elevation.
- `ApronRoadSection`: a road strip described by physical width and lateral centre; returns two metre-coordinate edges.
- `ApronRoadCarBox`: length/width/height and plate-plane dimensions, all in metres; emits 3D vertices and a blank 4-corner plate polygon.
- `ApronRoadScene`: moving box, projected 2D envelope, plate quad, pixel dimensions and source-relative shutter displacement; per-observation squared reprojection residual. No frame contents or plates are retained.

## Coordinate and time contract

World X runs along the road; Y runs across it; Z is up. Camera is at world (0,0,H). Vehicle is moving toward decreasing X. Source-relative `seconds` must be nonnegative; source-global integer PTS conversion remains owned by the existing media/motion adapters. The shutter is an independently specified microsecond interval, bounded by the selected frame period. The camera may have nonzero yaw, pitch and roll. For a wide-angle lens the single coefficient `k1` is a preliminary geometry parameter, not a complete distortion model or an accepted calibration.

## Calibration and recognition boundaries

This package supplies a forward geometry and scoreable model, NOT a fitted camera solution or a recognised registration. The real camera pose and lens must be qualified before metric range or plate-recognition confidence are asserted. `~projectedBoxAt` maps a cuboid: actual silhouettes differ, so shape residuals are not statistical probabilities. Absolute monocular scale is ambiguous unless physical dimensions and/or road width, camera elevation or surveyed anchor points are supplied. High-angle oblique views strongly foreshorten the plate: larger vehicle boxes do not imply better readable plates.

No licence font bytes, real clips, registration identifiers, crops, extracted plate images or per-clip observations are included in the source package.

## Synthetic tests

```sh
cd tests
REXX_BIN=/path/to/rexx ./run.sh
```

Under ooRexx r13196: 27 geometry/exposure checks plus 21 fail-closed checks = 48 PASS. `fromDegrees` and `platePixelDimensions` require canonical MathsBootstrap and have not been exercised with that dependency in this environment; the synthetic tests inject a unit orientation basis and evaluate squared dimensions instead. Real inference, camera calibration, MP4 seek and OCR are not qualified by these tests.
