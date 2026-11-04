# Power SLAM Sydney Harbour — Opera House western walkway view v0.20

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6. Date: 2026-11-02.

This is **native ooRexx geometric SVG output** from the existing Power SLAM scene, not a generative image, external photograph, composited harbour panorama or surveyed point-cloud.

## Viewpoint and geometry

- User instruction: west side of the Opera House coarse cuboid, on the forecourt/walkway.
- Provisional camera: latitude -33.856700, longitude 151.214430, camera elevation 7m above the *model* sea-level datum.
- Model's Opera House centre is retained; the old 183m-long rectangle is re-oriented north–south and its 120m side east–west for this deliberately illustrative walkway scene. This is not a surveyed footprint or shell reconstruction.
- The camera is 13.0093m west of the model cuboid's western face.
- Existing Power SLAM v0.18 bridge deck/abutment correction and v0.19 Blues Point Tower cuboid are retained.
- Bridge S bearing 298.7677 degrees; Blues Point Tower 310.4058 degrees; Bridge N 344.14995 degrees (degrees clockwise from north).
- 360-degree horizontal bearing/elevation projection (+55 to -35 degrees vertical), **not pinhole photography**; depth/occlusion only coarse face sorting. No bridge arch mesh, photographic landscape, person, ferries, or atmospheric scenery is invented.
- The Opera box occupies a large part of the eastern panorama because the camera sits only approximately 13m from its bounding face. This is an expected artefact of a flat 65m-high coarse cuboid, **not** a photographic prediction of how the Opera House shells appear from the path.

## Reproducibility

`bin/reproduce.sh` requires ooRexx 5.3.0 with rxmath and writes a native SVG with all model-derived polygons. The expected output is:

```
OPERA_WEST_WALK PASS 21 checks
POWER_SLAM_OPERA_WEST_VIEW GENERATED_FROM_OOREXX
CAMERA -33.856700 151.214430 7 m_ASL_PROVISIONAL
OPERA OPERA_AXIS_NORTH_SOUTH_UNSURVEYED DISTANCE_FROM_WEST_FACE_M 13.009300
STATUS WEST_OF_CORRECTED_OPERA_BOX_NOT_GEOREGISTERED_LAND FOOTPRINT_NOT_SURVEYED
BOXES 30
```

No new photographic calibration, roof survey, coastline admission, or ferry world-coordinate measurement is claimed. Do not compare or use a photorealistic LLM illustration as a reference geometry.

## Qualification

- Native ooRexx 5.3.0 r13196: **21/21** west-walk qualification checks passed.
- SVG produced by the ooRexx render script; PNG is a direct rasterisation of it. The 360-degree SVG has 30 cuboids and 540 model-face polygons (including 0/360-degree wrap copies).
- This is a new **viewpoint and optional reorientation**, not a modification of the baseline Opera House cuboid for other cameras.

## Files

- `src/SlamHarbourOperaWestWalk.cls` scene and venue camera viewpoint.
- `tests/test_opera_west_walk.rex` native qualification.
- `bin/render_opera_west_walk.rex` native 360 SVG rendering.
- `bin/reproduce.sh` native replay.

Qualification owner: Rasen Falcon lane `power-slam-harbour`; ferry tracking remains `tombstone-vision`.