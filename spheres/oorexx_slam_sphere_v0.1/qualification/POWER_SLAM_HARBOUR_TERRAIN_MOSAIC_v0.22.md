# Power SLAM Sydney Harbour — terrain mosaic and DEM ray interface v0.22

Architecture: Tom Dyer. Implementation/testing by ChatGPT GPT-6, 2026-11-02.
Lane: `power-slam-harbour`. Companion SLAM owns NSW source DEM ingestion/orthophoto stitching. Tombstone Vision owns ferry detections.

## Status
**QUALIFIED SYNTHETIC ADAPTER, REAL NSW DEM NOT RECEIVED.** User supplied imagery of tiled satellite maps and cyan land/water mask; neither contains the numerical, georeferenced AHD elevation values that the visibility engine requires. No claim of new verified Sydney terrain obstruction, camera altitude, PTZ lens pose or ferry world coordinates.

## Delivered code
`packages/oorexx_slam_v0.1/src/SlamHarbourTerrain.cls` defines:
- `HarbourTerrainTile`: reads simple typed, provenance-bearing raster data `HARBOUR_TERRAIN_TILE_V1` with explicit local ENU affine transform, AHD datum, per-cell `L:<height>`, `W` water and `X` nodata.
- `HarbourTerrainMosaic`: joins adjoining or overlapping numeric tiles; conflict in datum, local frame, land/water classification or heights (outside documented uncertainty) fails closed.
- `HarbourTerrainVisibility`: combines sampled bare-ground surface with existing `HarbourRayOcclusion~hitSegment` against the 3D bridge, tower, wharf and road solids. Returns `CLEAR`, `BLOCKED_TERRAIN`, `BLOCKED_STRUCTURE`, `UNKNOWN_*`, first local ray intercept and range, source and `METRIC_POSE_ADMISSION=NOT_ADMITTED`. No uncontrolled Python or external CV.

The local frame `SLAM_LOCAL_ENU_V1 / SCENE_33.852S_151.210E` retains the current scene's approximate tangent-plane transform; it is NOT the original NSW government CRS. The other SLAM must supply a documented, independently validated coordinate transformation and numeric ground values before adoption. Bare-earth DEM and above-ground buildings/bridge/deck are complementary, not interchangeable. The prior unverified `CAHILL_BERM` should not be double counted with terrain fill. Camera heights previously called ASL are NOT silently interpreted as AHD.

## Native proof
Local ooRexx 5.3.0 r13196 and rxmath on fixture files:
- Synthetic terrain tile/ray: **29/29 PASS** (ridge blocks low but not high; water, nodata, outside tile, datum mismatch, first-hit structure, precedence and provenance).
- Mosaic seam/rotated affine: **19/19 PASS** (two synthetic neighbours joined, height/role conflicts fail; rotated image-to-metre affine).
- Existing v0.21 opaque occlusion: **28/28 PASS**.
- Existing western Opera forecourt: **21/21 PASS**.
**Combined 97/97 PASS**.
Fixture files explicitly named `SYNTHETIC_*`; they are NOT NSW DEM, and no actual Sydney terrain sightline has been qualified. Native runner `bin/qualify_harbour_terrain.sh` operates both in the checkout and portable bundle.

## Required next interface input
1. From the map-stitching SLAM: numeric DEM tile(s), source tile ID/epoch, horizontal CRS, affine corner transformation to scene local frame, vertical AHD datum and stated accuracy, valid land/water/nodata classification and tile mask provenance. Do not infer these from supplied PNG pixels.
2. Validate same scene reference coordinate, AHD transform of every camera/landmark, AHD/ASL offset uncertainty, and sample ray intercepts over Mosman/Cremorne shoreline, Garden Island and Circular Quay roads.
3. Compare actual observed pixel features to predictions; require independent landmark holdouts and terrain/building visibility before admitting camera or ferry positions.

Tracks integration issue https://github.com/animatedads/alchemy/issues/119. All provenance and uncertainty constraints are retained.
