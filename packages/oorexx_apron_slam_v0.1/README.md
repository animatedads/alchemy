# Apron SLAM v0.1-dev1 — controlled drive-by glyph laboratory

## Purpose

A forward model for **known** UK number-plate characters passing a calibrated
camera on a simple 3D vehicle box. This is the first layer of Apron SLAM ANPR:
it makes the image degradation explainable before inverse plate reading is
attempted. It is not a conventional OCR module and does not claim to read
real registrations yet.

## Architecture and ownership

- `ApronOrientation`: yaw-to-basis constructor delegates `sin`/`cos` to the
  canonical ooRexx Maths `.Maths~angleDegrees`, `.Maths~sin`, `.Maths~cos`.
  Test fixture orientation bases are supplied independently, not calculated
  by a replacement trigonometric implementation.
- `ApronCamera`: ideal pinhole optical axis +Y, X right, Z up, rectilinear
  projection. Focal lengths are in pixels, dimensions in pixels, world in m.
- `ApronCarBox`: simple 4.3 m × 1.8 m × 1.5 m bounding box, 520 × 111 mm
  plate, positioned on the front face. It does not claim to model a specific
  make of car or all legal plate placements.
- `ApronDriveBy`: per-frame source time and per-shutter sub-exposure projection
  of glyph corners (79 mm high, usually 50 mm wide; I and 1 are narrow).
- `bin/generate_motion.rex`: native ooRexx deterministic numerical export;
  output is 36 glyphs × five speeds × three yaws × three ranges × two frame
  rates × two shutter settings × nine samples = **58,320** projected quads.
- `tools/reference_raster.py`: **independent OFFLINE raster qualification oracle**
  consuming ooRexx geometry. It is NOT called by ooRexx and is NOT a runtime
  Python bridge. Production providers must use existing ooRexx Foreign Runtime
  or Python Macrospace bridge, never `python ...` subprocess glue.
- Codec processing, bitrate, Bayer sampling, rolling shutter, camera rotation,
  lens distortion, exposure gain, distance/heading error and occlusion are
  **future** stages. No H.264 bitrate qualification is claimed in this dev1.

## Physical assumptions

- Camera: 1920×1080, fx=fy=1200 px, optical centre at pixel (960,540),
  camera height 1.5 m, no lens distortion, global shutter.
- Vehicle plate centre: height 0.55 m, plate 520×111 mm, box 4.3×1.8×1.5 m.
- Test camera ranges at t=0: 8, 12 and 20 m. Initial lateral X=-1 m.
- Vehicle travels with outward front-plate normal, yaw 0°,30°,60°, toward
  camera. Speeds 0,20,40,60,80 km/h.
- Frame rates 25 and 50 fps; shutter exposure 1 ms and 10 ms, completely
  independent of the frame period; nine evenly spaced temporal integration
  points (trapezoidal weighting is not yet implemented; uniform quadrature).
- These are synthetic **per-frame sampled motions**, not a real tracked car.

## Font, licensing, and source data

The user-supplied `uk_number_plate.zip` contains `UKNumberPlate.ttf`. Gareth
Attrill's website permits personal use and requests that commercial use be
arranged by contact. The user has contacted the author. The font is **never
included** in this repository, generated archive, or fixture data. The
standalone reference tool requires `APRON_FONT_ZIP` pointing to the local user-
supplied asset; it reads the TTF in memory. Glyphs are bounded by prescribed
physical dimensions but the author's font is not calibrated for road-legal
plates. `A-Z+0-9` is a **glyph test alphabet**, not a claim all these letters
appear in current UK registrations.

UK registration dimensions: GOV.UK DVLA information / Road Vehicles (Display of
Registration Marks) Regulations 2001, Schedule 4. These dimensions guide
geometry, not an assertion that this font produces road-compliant plates.

## Execution

```sh
REXX_BIN=/path/to/rexx tests/run.sh
cd bin
/path/to/rexx generate_motion.rex ../results/glyph_motion.csv
cd ..
APRON_FONT_ZIP=/path/to/uk_number_plate.zip python3 tools/reference_raster.py
```

The second command is ooRexx-owned source geometry. The optional Python step
is a deliberately separate *offline oracle* to inspect whether the numerical
projections correspond to plausible raster sampling; it is not the deployed
inference pipeline.

## What the model already demonstrates

At a 12 m range and 30° yaw, 10 ms shutter, the simulated average *projected
motion within the exposure* increases from 0 px at 0 km/h through 2.49, 5.14,
7.97 and 10.99 px at 20, 40, 60, 80 km/h respectively. These values do not
infer actual vehicle speed from a video.

The offline sharper-than-shutter reference test compares each of 36 blurred
single-glyph images to 36 sharp templates under *exactly known geometry*.
At 80 km/h this naive method returns the correct first candidate for 1/36
synthetic glyphs. This is a diagnosis of model mismatch, **not** a real-world
ANPR benchmark. For the next stage, search should use *blurred* forward
candidate templates and independent holdout samples with uncertain speed,
exposure, angle, depth and compression.

## Qualification boundaries

- ooRexx 5.3.0 r13196: `test_geometry.rex` 18 PASS, `test_guards.rex` 14 PASS.
- Source `ApronOrientation~fromYawDegrees` is wired to canonical Maths but not
  yet directly qualified with the full Maths library in this sandbox.
- Grid export: 6,480 scenarios, 58,320 projected corners-quads.
- Offline pixel reference: 1,080 scenarios (36 glyphs × 5 speeds × 3 yaws ×
  2 exposures) at 12 m/25 fps; current artefacts are idealised grayscale.
- No OCR accuracy, motion inverse-solving, codec qualification, or field
  recognition is claimed. Only synthetic fixtures are present.

## Next acceptance gates

1. Canonical Maths full-library native test and coordinate frame conversion
   from SLAM450 world/camera, including arbitrary calibrated camera 6DoF.
2. Replace offline raster oracle with a resident font/bitmap rendering provider
   through approved Alchemy runtime; no font redistribution.
3. Add controlled physical exposure integration, rolling shutter, compression
   at actual target bitrates (using Media Object Access), frame timing and
   image source identity.
4. Hold out intermediate, previously unseen speeds/angles/distances and score
   all 36 inverse candidates with uncertainty, per-glyph ambiguity and abstain.
5. Multi-frame character track fusion: account for correlations and preserve
   every source frame and model digest.
## 11 November 2026 — dev4 road calibration and Gopher sphere candidate

`ApronRoadCalibration.cls` scores ephemeral source-time box observations against candidate camera/vehicle models and optional independently surveyed road-edge anchors. It reports `INSUFFICIENT`, `HIGH_RESIDUAL`, `AMBIGUOUS`, `UNANCHORED`, or `MODEL_CONSISTENT`, none of which is a plate match probability. `ApronPlateSamplingGate` reports geometric undersampling, unknown exposure, and motion domination; frame rate is not shutter duration. The source-time integer clock is monotonic, track buffers are cleared on close and no real footage/plate/font enters Git. Tests: 147/147 synthetic ooRexx r13196, plus six static checks for `spheres/apron_slam_gopher_sphere_v0.1/`. See `docs/ROAD_CALIBRATION_DEV4.md`. The Gopher pack is a candidate, not a registered sphere. Canonical MathsBootstrap integration and measured real-camera calibration remain unqualified.
