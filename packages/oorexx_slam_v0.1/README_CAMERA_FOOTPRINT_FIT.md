# Power SLAM v0.8 — joint XY/Z/yaw/pitch/focal fit, **provisional**

Architecture: Tom Dyer. Implementation: ChatGPT (GPT-6), 2026-11-01.

## Why this increment exists

The former Café Sydney 3D pinhole fitter searched only +/-10m east and north of an indexed Customs House building-centre point. This silently assumed that point was the lens location. It can exclude a real rooftop camera before fitting and force compensation into camera altitude or pitch. The model now accepts a polygon of possible camera horizontal positions and independently searches east-west and forward-back (north-south) inside it. The polygon is not a path, track or geodetic survey: it is a constrained hypothesis region.

## New source

- `SlamHarbourPerspectiveFit.cls` implements `HarbourCameraPolygon` and `HarbourPerspectiveFit` with full perspective projection and six-parameter multi-start optimisation.
- `fit_cafe_sydney.rex` runs two real-picture calibrations (bridge-only and bridge + one **unverified** Cahill-edge correspondence) against manually inspected pixels in the 1536 x 862 original photograph `1000066577.jpg`. This is automated *parameter optimisation*, not automated image feature discovery.
- `test_footprint_fit.rex` qualifies the polygon gate and synthetic forward/back and east/west recovery independently of the generating camera pose.

The built-in **80 m east-west × 64 m north-south box** centered on the indexed Customs House point is intentionally **oversized and provisional** to permit camera positions throughout the approximate building area. This is **not** the actual surveyed rooftop outline; parts of the envelope might be outside the roof or lack a view. The legitimate eventual replacement is a georeferenced polygon of accessible positions, obtained from a building plan or independently measured GIS points. Caller-supplied polygons are supported by the `fit` fifth argument and remain identified by their stated provenance.

## ooRexx test commands

With `rxmath`, the package classes and `librexx.so` available:

```sh
rexx test_footprint_fit.rex
rexx fit_cafe_sydney.rex /tmp/SLAM_OUT
```

Both emit structured observations/residuals; the second writes transparent SVG geometry overlays, one for each fit. PNG image composites are optional inspection aids, not model source or geometry truth. The source photography is not committed to GitHub.

## Observations used

Manually estimated pixels from user's 1536 x 862 Café Sydney still: S_TOP (122,278), N_TOP (770,314), S_DECK (122,379), N_DECK (770,390), with stated 6px uncertainty. The alternative fit additionally uses a hypothetical straight Cahill edge at x=500,y=736 with 15px uncertainty. Neither the pylon centre proxies nor the presumed Cahill edge is an independently surveyed image correspondence. The bridge arch crown (roughly x=447,y=190) is a **holdout**, but the current model substitutes a midpoint of 3D pylon coordinates for its true curved arch geometry; its 77px discrepancy is a warning of model insufficiency, not a direct measurement of camera error.

## What the expanded fit returns

| Input | east offset from indexed centre | north offset | Z m ASL | FOV horizontal | weighted chi² |
|---|---:|---:|---:|---:|---:|
| Four bridge controls | -14.0m | +9.9m | 48.8m | 34.2° | 2.526 |
| Bridge + hypothetical Cahill control | +19.8m | -32.0m | 31.5m | 34.5° | 13.290 |

The second result reaches the southern limit of the **provisional** search envelope. The two outputs are mutually incompatible at the required few-metre height precision. **Neither is an accepted real camera location or height.** The FOV is a fit to a simplistic, possibly inaccurate bridge geometry and provisional point matches. It is not a measured or independently validated optical FOV. The 120° crop of a 360° bearing chart is not a pinhole-camera FOV and must not be compared directly.

The synthetic regression generated seven controls from a known camera 18m east and 18m south of the indexed centre, with 27.5m ASL. Multistart estimation recovered position and height to under the declared tolerance, and the fit was gated inside the polygon. **Synthetic recovery proves an optimisation/software property, not a geographic survey claim.**

## Hard acceptance boundaries

1. Replace approximate city-centre building point with measured polygon and rooftop/exterior line-of-sight admission, including permitted lens physical placement.
2. Independently annotate the true image pylon corners, bridge arch coordinates and Cahill/viaduct image edge with confidence/identity. No invented visual correspondence.
3. Qualify bridge 3D geometry: centreline deck elevation, four pylons' horizontal positions, real arch crown coordinates (not midpoint surrogate).
4. Jointly fit and hold out several separate foreground and background controls, report parameter uncertainty and competing minima, validate against a second frame.
5. Decline height estimates at the +/-2m level until foreground and distant controls agree and camera-pose uncertainty is demonstrably within tolerance.

## Source provenance

- Lens-index reference is an approximate Customs House building-centre point from Dictionary of Sydney, **not a surveyed camera location**.
- Fifth-floor Café Sydney location: official Café Sydney and NSW visitor listings.
- Bridge coordinates are existing Power SLAM v0.1 hypothesis/source, not a newly surveyed bridge reference.
- Landmark annotations were inspected manually from the screenshot the user supplied, so results cannot be presented as fully automatic landmark detection.