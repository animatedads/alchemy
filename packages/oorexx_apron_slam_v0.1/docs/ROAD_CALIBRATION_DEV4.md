# Apron SLAM v0.1-dev4 — camera/road candidate fit and plate sampling gate

## Scope and status

This adds `src/ApronRoadCalibration.cls` above the existing ApronRoadGeometry.
It evaluates hypotheses supplied by the caller against temporary, anonymous
vehicle-box observations and optional road-edge controls. It does not recognise
characters, read a plate, certify an absolute location, or ingest video.

The source-time `ptsUs` values are strict increasing integers. The first
observed PTS is used as trajectory epoch; frames use `(ptsUs-startPtsUs)/1e6`.
Large absolute timestamps therefore do not become floating-point wall-clock
seconds. Changing image dimensions or 1-second track gaps are rejected.

`ApronCalibrationTrack~close` clears all temporarily held samples and anchors.
Do not persist the track or log the observed boxes. The caller remains
responsible for secure lifecycle of the original media attachments and buffers.

## Model comparison

The object evaluates *already constructed* `ApronRoadScene` hypotheses; it
never silently infers focal length, world scale, road width or vehicle class.
Each box residual uses pixel XYWH coordinates normalised by the observation's
declared `sigmaPixels`. A road anchor supplies independently observed near/far
edge points at a declared world X. Road and box costs are block-averaged so
correlated video frames cannot drown out an independent road anchor.

Results remain named candidate models and **dimensionless residual scores,
not registration or calibration probabilities**. The result statuses are:

- `INSUFFICIENT`: under four frames or <0.25 s temporal baseline;
- `HIGH_RESIDUAL`: none of the tested hypotheses explains the observations;
- `AMBIGUOUS`: tested models fit within the declared near-tie margin;
- `UNANCHORED`: best model fits, but lacks a surveyed world-image anchor;
- `MODEL_CONSISTENT`: a tested model fits while at least one independently
  surveyed road anchor exists. This remains a provisional candidate, **not**
  a surveyed 6DoF camera solution.

An `ESTIMATED` road width/edge is documentary and can never on its own create
`MODEL_CONSISTENT`. An anchor marked `SURVEYED` must truly have independent
physical survey provenance; the class validates the declaration but cannot
certify the survey. Vehicle-dimension uncertainty, radial distortion, camera
height and lens/focal assumptions must be varied in hypothesis families.

## Plate sampling and frame choice

`ApronPlateSamplingGate` checks the physical 50 mm typical character width and
14 mm stroke against a projected 520 mm plate. The geometric eligibility
threshold requires at least 5 projected pixels per nominal character width
and 1 pixel per stroke. These are **research thresholds, not certified OCR
limits**. If the geometry falls below them, return `UNDERSAMPLED`.

Shutter exposure is separate from frame rate. Missing shutter metadata yields
`EXPOSURE_UNKNOWN`, not a default 1/fps assumption. If the predicted plate
centroid moves by more than one nominal character width during the supplied
exposure, return `MOTION_DOMINATED`. Otherwise `GEOMETRICALLY_SAMPLED` means
only that these two coarse tests do not prohibit a further experiment.

The gate never emits a probability of exact registration recognition. There
is no source frame, plate crop, font, glyph, personal data or registration
string in any test fixture or source artifact.

## Maths and interfaces

- `ApronRoadBasis~fromDegrees` calls the canonical `.Maths~angleDegrees`,
  `.Maths~sin`, `.Maths~cos`; `ApronRoadScene~platePixelDimensions` calls
  `.Maths~sqrt`. The calibration score retains squared pixel residuals, so it
  does not insert a substitute mathematical implementation.
- `ApronRoadCamera`, `ApronRoadCarBox`, `ApronRoadSection` own *domain semantics*.
- Vision/Motion Control own frame observations/tracking, and Media Object
  Access owns decoded source/frame ranges.
- External Python model providers remain behind Foreign Runtime / Macrospace.
- No live canonical MathsBootstrap linkage or real camera/plate accuracy is
  claimed in this increment; tests inject an exact synthetic orientation basis.

## Native qualification

Run `REXX_BIN=/path/to/rexx bash tests/run.sh` from the package root. The
existing six synthetic test suites remain mandatory. The dev4 suites add
positive and negative multi-hypothesis and sampling-gate tests. No private
videos, face data, plate frames, registration text or font are needed.
