# Power SLAM v0.22 — stitched NSW terrain integration seam

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6. 2026-11-02.
Rasen Falcon lane: `power-slam-harbour`; the other SLAM owns NSW DEM ingestion/stitching; ferry tracker: `tombstone-vision`.
Related coordination: https://github.com/animatedads/alchemy/issues/119

## Delivered

An **ooRexx-only** tile reader, affine grid sampler, overlap-aware DEM mosaic, and unified 3D visibility ray tracer. The tracer checks a source-provenance-bearing ground-height surface together with the v0.21 scene's existing oriented bridge/wharf/building/expressway cuboids. It returns clear/blocked/unknown with first local ray intercept and range; it never asserts metric camera/ferry position admission. These files are native ooRexx; the existing rxmath library is used for geometry, not Python, OpenCV or other image libraries.

**Important:** No real NSW DEM grid was provided here; only screenshots of stitched satellite tiles and a land/water raster. The supplied fixture tiles are clearly marked `SYNTHETIC`; these 48 native checks establish API and fail-closed semantics, **not surveyed Sydney visibility**. The other SLAM supplies actual georegistered numeric elevations later. No re-ingestion or re-stitching by this package.

## Mandatory tile contract — `HARBOUR_TERRAIN_TILE_V1`

```
HARBOUR_TERRAIN_TILE_V1
CRS SLAM_LOCAL_ENU_V1
FRAME SCENE_33.852S_151.210E
DATUM AHD
SOURCE <stable_source_tile_id_no_spaces>
UNCERTAINTY_M <vertical_uncertainty_metres>
ORIGIN <east_m> <north_m>
COL_VECTOR <delta_east_m> <delta_north_m>
ROW_VECTOR <delta_east_m> <delta_north_m>
SIZE <columns> <rows>
<row1: L:<height_m> | W | X separated by spaces>
...
```

Coordinates in `SLAM_LOCAL_ENU_V1` are those of **the current Power SLAM `HarbourScene~local`**: reference (-33.852°, 151.210°), easting ≈ longitude difference × 92300 metres, northing ≈ latitude difference × 111200 metres. It is a temporary **local tangent approximation**, not the original NSW government dataset CRS or a survey-proven transform. The other SLAM **must transform** original NSW tile coordinates to this local frame, recording input CRS, conversion method/version, cell resolution and tile source in its own provenance. The affine vectors support rotated tiles; raster `ORIGIN` denotes the **centre of the top-left cell**.

`DATUM AHD` is required: a previous `m ASL` camera or bridge height is **not presumed equal** to AHD. A camera ray with unresolved vertical conversion returns `UNKNOWN_VERTICAL_DATUM`. Neither an ocean depth nor a blank cell may turn into a height-zero land surface.

Cells: `L:12.3` = bare earth surface at 12.3 m AHD; `W` = water mask, **not land and not bathymetry**; `X` = unknown/nodata. Tile samples return `LAND_AHD`, `WATER_NOT_LAND`, `UNKNOWN_NODATA` or `UNKNOWN_OUTSIDE_TILE`. Water is not a land occluder, but a fixed land-camera site on water is rejected. Water surface and structures over water are separate.

`HarbourTerrainMosaic~appendTile` refuses mismatched CRS/frame/datum; samples across neighbouring tiles are accepted only when overlap roles agree and numeric ground heights agree within their *declared combined uncertainty*. Conflicting land/water, height, nodata or a missing tile yields `UNKNOWN_*`, never `CLEAR`. `SOURCE` and source resolution/uncertainty are maintained.

`HarbourTerrainVisibility~trace(tileOrMosaic,scene,cam,target,camDatum,targetDatum,ignoreBox='',landCamera=.true)` returns:
- `STATUS`: `CLEAR`, `BLOCKED_TERRAIN`, `BLOCKED_STRUCTURE`, or `UNKNOWN_*`.
- `OCCLUDER`: `TERRAIN`, a bridge/building/road-solid name, or empty.
- `FIRST_LOCAL_POINT`: an `[east_m,north_m,ray_height_m]` triple if blocked; these are local model coordinates, not surveyed geodetic points.
- `FIRST_RANGE_M`, `PROVENANCE` and `METRIC_POSE_ADMISSION = NOT_ADMITTED`.

The ray sampler uses at most half-grid sampling along a segment, with a 20,000-step bound. A terrain height within the tile's specified vertical uncertainty band of a ray is **UNKNOWN**, not a definite obstruction or clear sky. First hit is reported after checking both terrain and solid geometry; an UNKNOWN gap before an obstruction cannot be silently skipped. The first-hit location is approximated at raster sampling resolution, not subcell precision.

## Reproduction

```
REXX_BIN=rexx sh packages/oorexx_slam_v0.1/bin/qualify_harbour_terrain.sh
```

Native ooRexx 5.3.0 r13196 + rxmath: 29/29 tile/visibility checks, 19/19 mosaic/rotation/seam tests, **48/48 new checks PASS**. Also reran existing v0.21 occlusion 28/28 and Opera western-walkway 21/21 with the new class present; **97 checks total passed** for this combined compatibility check.

## Qualification still missing

1. The other SLAM must supply a **numeric, georegistered Sydney elevation tile** with verifiable source, full affine transform, datum, nodata/water mask and uncertainty. A satellite image with yellow tile outlines and a cyan mask is not sufficient to infer real heights.
2. Resolve/convert existing camera, bridge, tower and quay heights into AHD before calling the tracer for real Harbour cameras.
3. Audit terrain-vs-road/bridge fill in the approach area; `v0.21` berms remain provisional and should not be added to terrain twice.
4. Verify first terrain intercept and pixel occlusion against independent reference photographs and suitable survey controls. Do not declare ferry positions qualified from this interface alone.