# Power SLAM: Sydney Harbour rigid-landmark camera pose qualification

**Architecture:** Tom Dyer. **Isolated implementation and tests:** ChatGPT (GPT-6), 2026-11-01. This is a proposed additive SLAM component, not a change to existing SlamStore, SlamComposer, Piledriver, or Body Slam. Tested with the user's ooRexx 5.3.0 r13196 internal-test interpreter.

## Objective

Determine the *set* of physically admissible camera positions from fixed 3D landmarks and image measurements. **The camera must be on land:** a pixel classified as harbour blue, unknown, or off-map is never eligible. Rank feasible hypotheses by photographic reprojection error, retain ambiguity, and refuse any fit beyond an absolute threshold. No LLM-authored location is accepted as a geometrical observation.

## Physical anchors and model

Local metric coordinates: origin (lat -33.852, lon 151.210), x=east, y=north; approximations of 92,300 m/longitude-degree and 111,200 m/latitude-degree are adequate for this *small local test* and should be superseded by a consistent projected CRS for surveying.

| Feature | Latitude | Longitude | Derived model |
|---|---:|---:|---|
| Bridge north pylon pair | -33.85003 | 151.21209 | Two solid boxes, each 14 x 14 x 89 m, side-offset by 20 m |
| Bridge south pylon pair | -33.85454 | 151.20926 | Two solid boxes, each 14 x 14 x 89 m, side-offset by 20 m |
| Bridge deck | Between both end pairs | Between both end pairs | Single box, approximately 570 x 49 x 5 m, base at 52 m |
| Opera House | -33.8566674153 | 151.2152213360 | One white box, approximately 183 x 120 x 65 m, base 4 m |

These **cuboid dimensions/centres are simplifications**, not surveyed footprints. North and south pylon pair coordinates represent mapped structures, not the exact centres of their four individual towers. The bridge does not include an arch, and the Opera House does not include sails; that is deliberate for this test.

Sources:
- Bridge north pylons: https://mapcarta.com/W156584774
- Bridge south pylons: https://mapcarta.com/W382401361 ; NSW tender confirms approximately -33.854505, 151.208843 for the southern pylon: https://www.australiantenders.com.au/tenders/611065/supply-and-install-of-air-compressor-at-sydney-harbour-bridge
- Opera House lat/lon: Heritage NSW https://apps.environment.nsw.gov.au/dpcheritageapp/ViewHeritageItemDetails.aspx?ID=5054880
- Opera House simplified dimensions: https://en.wikipedia.org/wiki/Sydney_Opera_House
- Customs House known control site: https://dictionaryofsydney.org/building/customs_house

## Input and computation

Input observations are feature identifiers and image pixel coordinates `['N', u, v]`, `['S', u, v]`, `['O', u, v]`. Exact pixel centroids, camera calibration (focal length), camera height and a georeferenced land raster are needed to qualify the *real* photographs. This increment separately runs three **synthetic** cameras to prove inversion. For a given land cell:

1. Infer yaw algebraically from its position relative to the first observed landmark and its measured horizontal image coordinate (no trigonometric library required).
2. Infer the vertical optical shift from that landmark, with specified camera height and focal length.
3. Pinhole-project all landmark points in the coarse 3D scene into image pixels; reject points behind the camera.
4. Compute sum of squared 2D pixel residuals and rank the feasible land cells. Never accept a candidate with RMS pixel error greater than `maxRms`. Never silently replace a missing georeferenced land mask with a real-world land claim.

The `inOrder` necessary condition uses signed 2D cross products and is independent of yaw and focal length (provided the landmarks can be seen within the same front-facing field of view). This makes left/right silhouette reasoning testable without identifying a camera.

### Shoreline mask

`HarbourLandMask~loadRasterAscii(file, xMin, xMax, yMin, yMax)` accepts a geo-referenced categorical mask from a map image. The first line is `HARBOUR_LAND_MASK_V1 W H`, followed by H rows of exactly W characters each, north first: **L** = documented land, **B** = blue water, **X** = unknown. Only `L` may admit a camera. The west, east, south and north bounding coordinates must come from a trusted geo-registration of the supplied map; do not infer them from the image itself. Pixels outside the bounding rectangle are refused. A loaded raster *overrides* demonstration rectangles.

The checked-in test uses a small artificial raster to prove this rule, and separate conservative demonstration land rectangles around Waverton/Balls Head, Kirribilli and Customs House. **Those rectangles are not a complete or survey-grade coastline. No fitted position is claimed in a user's actual map until a valid georeferenced mask is supplied.**

### Initial three live-image ordering constraints (visual annotation only)

- Screenshot 1: in image left-to-right order, N pylon region, Opera House, S pylon region: `N < O < S`. Candidate western/northwestern land sector *consistent*, not a proved camera site.
- Screenshot 2: Opera House, S pylon region, N pylon region: `O < S < N`. Candidate northeastern/northern shore sector *consistent*, not proved.
- Screenshot 3 (Café Sydney): S pylon region, N pylon region: `S < N` (Opera House off-screen). The user separately supplies the camera site, Level 5, Customs House, Circular Quay. That gives a calibration/checkpoint, not a position inferred by the solver.

All left-right annotations are subject to confirming which of the two visually overlapping pylons corresponds to the north/south end in the original full-resolution frame. Moving ferries, wake lines, shadows and cloud edges must not be used as fixed landmark bearings.

## Qualification evidence

Run in package root:

```sh
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
rexx tests/test_harbour_pose.rex /tmp
```

Or run `rexx test_harbour_pose.rex .` when `SlamHarbourPose.cls` is in the same directory.

**2026-11-01:** **35/35 PASS**, using ooRexx 5.3.0 r13196. The tests verify: four pylons + deck + Opera House; metric landmark geometry; west/northeast/south silhouette ordering; land-positive and blue/unknown-negative raster cells; exact synthetic pose recovery at the selected grid cells; water-candidate exclusion; waterborne control producing no acceptable land fit; grossly impossible reprojection rejected; renderer uses the same scene shapes. Synthesised view wireframes are produced as `western.svg`, `northeastern.svg`, `southern.svg` in the selected output directory.

The synthetic zero-position error is expected for closed-loop observations from this exact model and grid. **It is not an error estimate for the actual photographs.**

## Next acceptance conditions

- Digitise/georeference the user-provided map's true water/land boundary, including boats/wharves/structures that are **not** permissible stable ground unless explicitly approved. Mask must be source-verified.
- Annotate real photo landmark pixel coordinates with uncertainty, using a named stable point on each pylon and Opera House box; derive camera intrinsics from image/FOV or fit an explicit plausible interval.
- Fit the three views independently, then cross-validate predicted bridge-to-Opera arrangement; include line-of-sight occluders and geographic elevation when needed.
- Return disjoint feasible polygons and confidence/ambiguity, not fabricated point locations. Handle cameras whose image crop excludes one landmark with adequate alternative constraints.
- Once qualified, connect this additive pose/path contract into the existing SLAM task/evidence store with provenance and tests; current standalone class does **not** assert integration into `SlamStore` or the Alchemy codec.
