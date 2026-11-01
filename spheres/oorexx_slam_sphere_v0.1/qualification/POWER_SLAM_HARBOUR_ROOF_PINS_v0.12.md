# Power SLAM Sydney Harbour — roof-pin and camera qualification v0.12

Architect: Tom Dyer. Implemented and checked by ChatGPT GPT-6, 2026-11-01.
Rasen Falcon lane: `power-slam-harbour` (distinct from `tombstone-vision` ferry observation).
Git package: `packages/oorexx_slam_v0.1/`; open photographic-pose gate remains fail-closed.

## Source and evidence

- `SlamHarbourBridgeAudit.cls`: records and rejects the earlier four-coordinate skewed-pylon hypothesis.
- `SlamHarbourBridgeSemantics.cls`: distinguishes masonry pylons, arch trusses, abutments, deck, mapped lookouts, photographic locations, and roof pins.
- `SlamHarbourRoofPins.cls`: user-placed rooftop interior map pins:
  - NW `(-33.849759,151.211889)`
  - NE `(-33.849915,151.212276)`
  - SW `(-33.854271,151.209068)`
  - SE `(-33.854422,151.209463)`
- Screenshot IDs: `1000066729.jpg` through `1000066732.jpg`. These user photographs are **not** redistributed in the Git package.
- Geometric separations: 39.71 m and 40.14 m transverse, 565.27 m and 564.44 m longitudinal. Pylon roof pin is **not** a surveyed roof centroid/corner.

## Qualification run

Independent combined local ooRexx 5.3.0 r13196 execution (rxmath loaded), all 357 checks passed:

- bridge audit: 19
- structural semantics: 27
- synthetic footprint/camera fitter: 24
- harbour panorama SVG: 36
- wharf scene geometry: 145
- north shore: 37
- Circular Quay infrastructure: 40
- roof-pin layout: 29

**Synthetic qualification is not real-photo calibration.** The Café Sydney bridge-only candidate is ~46.66 m ASL / 31.55° HFOV; adding the assumed Cahill image edge gives ~31.28 m ASL / 34.20° HFOV. Both push against an oversized, unsurveyed Customs House rooftop envelope; the arch crown holdout still fails. Report `BLOCKED_UNVERIFIED_IMAGE_LANDMARK_CORRESPONDENCES`; no height, precise camera position, or ferry world-coordinate localisation accepted.

## Programme boundary

Power SLAM owns landmark geometry, georeferencing, observed-feature association, camera-fitting APIs and geometric calibration qualification. Tombstone Vision owns ferry recognition and motion evidence. Consumers must retain missing or conflicting pose as uncertainty, never substitute generated geographic guesses for coordinates.

## Required before claiming a solved camera

Map actual pylon roof corner polygons and Customs House roof from controlled geo-imagery; map true bridge arch/rail geometry; verify image landmark correspondences and nearby Cahill edges; fit six camera parameters against true perspective image projection; validate against independent holdouts. Maintain fail-closed status for unresolved uncertainty.
