# Sydney Harbour — multiple SLAM engines evidence interface v0.34

Architecture: user. Implementation: ChatGPT GPT-6, 2 November 2026.

## Sources supplied in this continuation

Five distinct, cryptographically tracked source representations are recorded in `source_registry.psv`:

- User's cyan/white 458x336 segmentation raster (source image SHA256 in registry). It looks like a water/land topology, but the semantic class and world location are **not independently supplied or validated**. 80x45 cyan diagnostic raster mask has 1,650 cells. This is **NOT** an admitted per-camera water-motion mask.
- 1200x814 satellite-image screenshot with nested yellow tile annotations (`s01`, etc.). Screen coordinates are not satellite tile geographic transform parameters. Individual tiles require their own source geotransforms and overlap correspondences for any map registration. The screenshot by itself cannot assign pixel longitude/latitude.
- 2048x512 Power SLAM 360-degree render from a **north-shore PTZ same-building camera hypothesis**, illustrative elevation **79m ASL** (NOT surveyed). This is the renderer's model space, not an original camera image.
- 2048x512 Power SLAM 360-degree render for **Café Sydney / Customs House**, illustrative elevation **25m ASL** (NOT surveyed). Model bearing wrap at 0/360 is explicitly handled.
- A real V5V 80x45 indexed archive of **1,800 Café Sydney source frames** from the 2 November cruise-ship recording (original source SHA256 in registry), previously qualified in the ferry-SLAM branch.

All file SHA256 values refer to the exact user-supplied or original source files. Original screenshot/MP4 bytes are deliberately **not re-bundled**.

## Native ooRexx implementation

`CrossSlamEvidence.cls` registers typed source identity, dimensions, coordinate systems, and authority states. `imageBox` and `screenOverlap` support **same-image** overlap only. It explicitly refuses screenshot-to-actual-camera pixel transforms and world positions when the relevant photo correspondences, image georegistration, optical-centre pose or tile geotransforms are unavailable.

360-degree angular distances are circular; `358°` and `2°` are 4° apart. `bearingSectorContains` handles a sector crossing the 0/360 seam. `panoramaObservation` is **ILLUSTRATIVE_MODEL_HYPOTHESIS**, never a physical viewing ray.

`mask_screenshot80.rex` uses ooRexx to convert an FFmpeg-area-filtered RGB24 **screenshot** into 80x45 cyan-class bits; `verify_mask80.rex` validates class count, source hash, all 45 binary rows and the `SCREEN_RASTER_UNREGISTERED` authority guard.

`verify_native_v5v.rex` validates the complete 1,800 real camera source frame records against original PTS, original source SHA256, exact frame order, temporal keyframe schedule, mask change-count conservation and the actual packed `.v5b` payload length; it specifically **refuses** applying the Café Sydney MODEL_360_PANORAMA as a calibrated camera-to-world transform.

### Power SLAM canonical dependencies and important boundaries

Existing canonical geometry engine **Power SLAM v0.21**, not copied/replaced here: `packages/oorexx_slam_v0.1/src/SlamHarbourOcclusion.cls`, `SlamHarbourPanorama.cls` (qualification sphere `POWER_SLAM_HARBOUR_OCCLUSION_v0.21.md`). It now offers *opt-in* fully opaque cuboid painting and `HarbourRayOcclusion~firstHit`, with labelled solid occlusion tests. This is not full photographic per-pixel Z-buffering. Its bridge steel truss lattice, roadway retaining geometry, PTZ dynamic camera poses and exact Cafe Sydney lens remain unqualified. A rendered model occlusion must **flag**, not automatically delete, real V5V vessel evidence.

No `WORLD` coordinate or same-vessel identity is admitted by this bridge: a screenshot, tile mosaic, model panorama and V5V raster are not in a shared coordinate system without independently qualified transformations. Harbour bridge/sailboat/large-ship geometry must remain `OBSERVED_UNTESTED` and `BLOCKED_NO_QUALIFIED_TRANSFORM` at this stage.

## Executed qualification

- User source screenshot SHA256: **4/4 PASS**.
- Real Café Sydney V5V source provenance: **1,800/1,800 frame nodes**, **60/60 KEYFRAME** and **1,740/1,740 DELTA** records, source PTS, source SHA256, packed payload bytes **924,929**, PASS.
- Native ooRexx source/cross-engine checks: **22/22 PASS**.
- OoRexx mask screenshot reduction and independent lineage: **45 rows, 1,650/3,600 cyan cells PASS**.
- Deliberately forged or bad input cases: **12/12 REJECTED**, including falsely surveyed panoramas, fake geotransforms, forged TESTED, cross-source screen overlap, identity promotion and altered mask lineage.

Executable reproduction with installed ooRexx 5.3 r13196 + ffmpeg:

```
sh run_qualification.sh mask.png mosaic.png north-pano.png cafe-pano.png cafe-sydney.nodes.psv cafe-sydney.v5b
```

The raw 80x45 RGB fixture is an unregistered screenshot reduction; it is not a simulation of camera water pixels. Real camera `source→world` requires Power SLAM's independent camera-pose and uncertainty certificate plus actual screenshot/map-to-video correspondences.

## Integration next

1. Obtain *tile* geographic bounds/geotransforms and common pixel/control-point pairs, not just mosaic annotation rectangles.
2. Tie exact camera screenshot pixels to Power SLAM projected/occlusion-model features (image coordinate + known landmark 3D point); admit camera pose only after held-out reprojection residual qualification.
3. Use camera-specific motion layers to preserve all V5V source pixels and exclude only validated stationary background, with occlusion flags rather than automatic removal of ships in front of bridge solids.
4. Carry same-vessel hypotheses as source-linked `OBSERVED_UNTESTED`; promote only through geometry+appearance+time gates.
