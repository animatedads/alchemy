# Power SLAM Harbour — Cartography Evidence Intake v0.18

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6. 2026-11-02.
Rasen Falcon lane: `power-slam-harbour`.
This is the *consumer-side* experimental contract for Claude's early Top Rope SLAM map/image reader, **not** an implementation of Top Rope, nor an authenticated producer API.

## Problem

Top Rope is working on extracting blue Sydney Harbour water into one or more polygon(s) from two overlapping screenshots of Google Maps, which may have different zoom, translation, and map annotations. Power SLAM must not confuse an aesthetically reasonable polygon with an independently georeferenced surveyed coastline. A misplaced shoreline can falsely admit a camera in harbour water or fabricate a ferry's latitude/longitude.

## Native ooRexx interface

`SlamHarbourCartographyIntake.cls` exposes `.HarbourCartographyIntake~evaluate(imageMap)`, `~reconcile(qual1,qual2)`, `~geographicOutlines(qual)`, `~imageToGeo(qual,x,y)` and `~waterPixel(qual,x,y)`. Records are native `.directory` objects and `.array`s, with uppercase keys. `point(id,x,y,lat,lon,role,provenance)` is a convenience constructor.

An input imageMap must contain:

| Key | Type / meaning |
|---|---|
| `MAP_ID` | non-empty ID, one per map image |
| `SOURCE_SHA256` | exactly 64 lowercase hex characters of that original source screenshot |
| `WIDTH`, `HEIGHT` | source pixel dimensions, inclusive lower bounds, exclusive upper bounds |
| `CRS` | exactly `EPSG:4326` (latitude, longitude degrees) |
| `CONTROLS` | `.array` of `.directory` records: `ID`, `X`, `Y`, `LAT`, `LON`, `ROLE`, `PROVENANCE` |
| `WATER_POLYGONS` | `.array` of polygon rings, each `.array` of pixel-coordinate vertex `.array~of(x,y)`; first/last vertices must be identical |
| `BOUNDARY_SOURCE` | e.g. `ROUGH_MAP_ESTIMATE` or `VERIFIED_SURVEYED_WATER_BOUNDARY` (a **claim**, not authentication) |

Exactly **three** non-collinear `FIT` controls and **one or more independent** `HOLDOUT` controls are required per source image. Repeated feature IDs are rejected. More than three fit points is not yet supported: distribute remaining controls into HOLDOUT. Future Top Rope versions can upgrade to RANSAC/weighted least squares without changing provenance semantics. Each source image has a *separate* 2D affine fit; different map zoom is allowed.

For this Sydney-scale proof, an explicit local tangent-plane approximation converts geographic lat/lon to approximate metre offsets around (-33.85, 151.2), using east=92300m/degree, north=111200m/degree. This is a **local approximation, not surveyed CRS transformation**, and is unsuitable for claiming sub-metre geographic accuracy. The geographic conversion and rendered outlines are **estimates** only.

Independent HOLDOUT error >3 m rejects the registration. Note that this 3 m is a **software test gate**, not measured Top Rope/Google Maps accuracy. It is not a geographic error budget for real camera or ferry pose.

`reconcile()` requires different source image hashes, at least three shared control IDs, and mutual agreement of their supplied lat/lon coordinates within 3 m. An identical pixel source cannot be double-counted as independent. Qualifiers retain source hash, computed affine coefficients, holdout RMS/max, original controls and polygons. `geographicOutlines()` retains `REGISTRATION_STATUS` and the source hash alongside transformed polygon vertices.

## Hard admission boundary

A screenshot can say `SURVEYED_GEO_CONTROL` for all points, and `VERIFIED_SURVEYED_WATER_BOUNDARY` for a boundary; the program **does not trust these self-assertions**. No source-of-authority verifier/attestation has been integrated. It returns `SURVEY_CLAIM_UNVERIFIED` and `METRIC_WATER_MASK_ALLOWED=.false`. Likewise, rough maps return `REGISTERED_MAP_ESTIMATE_ONLY`. `waterPixel` always refuses ground-truth land/water statements from current intake. **Outside a water polygon is not proof of land.** Neither land admission nor geographic ferry positions can be derived directly from these outputs.

Rejects: bad/missing content address, unsupported CRS, impossible dimensions/control pixels, nonnumeric or out-of-Earth lat/lon, duplicates, collinear controls, missing holdout, wrong roles, excessive holdout error, absent/open/degenerate/self-intersecting polygons, vertices outside image, two images without matching controls, inconsistent geography.

Polygon self-intersection check handles strict crossings and zero-length edges. Collinear overlapping edges are not fully handled; such cases remain a known limitation. The pairwise check validates shared geographic IDs, not necessarily the full pixel texture, source image authenticity or polygon overlap in every region.

## Reproduction

Run from an ooRexx 5.3.0 r13196 installation:

```sh
REXX_PATH=/path/to/Power_SLAM_Cartography_v0.18 rexx /path/to/Power_SLAM_Cartography_v0.18/test_cartography_intake.rex
```

The test constructs two **entirely synthetic** 300x300 screenshots of the same fictional rectangular water region at scale 2 and scale 1 (twofold pixel zoom), with four shared landmarks. It tests independent affine registration and matching transformed coastlines. The 42 assertions passed on ooRexx 5.3.0 r13196. **No real Sydney map image has been parsed or merged in this increment.**

## Producer handoff and ownership

We asked Claude / Top Rope through Rasen Falcon `REQ-00002975` for the actual Git path, revision, ownership, and format. No confirmed producer implementation/API was available at the time of this increment. Do not claim Top Rope integration is complete or that Claude endorsed this schema. Instead, this is an independently tested proposed import boundary for later negotiation. Top Rope retains map OCR/visual parsing/drawing; Power SLAM retains geo constraints and camera calibration; Tombstone Vision retains vessel recognition and motion.

Next: receive *actual* two source screenshots and geometries from Top Rope with hashes, derive at least four independent control correspondences for each, inspect residuals, and produce a **quarantined overlay** before considering independent surveyed coastline verification. For the moving north-shore PTZ camera, background map registration and zoom/heading fitting are separate inferences; neither can authorize the other.