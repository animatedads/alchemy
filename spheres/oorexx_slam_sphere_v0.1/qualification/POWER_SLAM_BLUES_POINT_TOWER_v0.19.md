# Power SLAM Harbour — Blues Point Tower 3D landmark v0.19

Architecture: Tom Dyer. Native ooRexx source: ChatGPT GPT-6, 2026-11-02.
Lane power-slam-harbour; ferry recognition remains in tombstone-vision.

The user identified the distinctive building west of the Sydney Harbour Bridge in a north-shore moving PTZ webcam frame as Blues Point Tower. This revision adds the known landmark to the genuine geometry, **not** an AI-generated panorama.

## Grounded measurements and limits
- Dictionary of Sydney reference: Blues Point Tower, (-33.849000568058, 151.20353302224), 83 metres **above ground**, https://dictionaryofsydney.org/building/blues_point_tower.
- Geographic marker is a published building reference, **not a surveyed roof centroid**. OSM footprint centroid differs; this requires reconciliation before metric pose admission.
- Explicit illustrative 24x20m east/north rectangular footprint, NOT_SURVEYED.
- Absolute ground level ASL unknown; `HarbourBluesPointTower~apply(scene,baseASL)` requires chosen base. For visual demonstration only the renderer sets base=0, resulting in 83m assumed ASL rooftop. **Never equate 83m AGL with surveyed rooftop ASL**.
- Adds one `BLUES_POINT_TOWER` cuboid, `BPT_BASE`, `BPT_ROOF` features and provenance/pose-admission status.
- Source renderer paints tower purple and annotates actual projected roof from model, only if present. No generative graphics.

## Test
Native ooRexx 5.3.0 r13196 actually executed: tower tests 22/22 PASS; prior panorama 36/36, wharves 145/145, Quay infrastructure 40/40, bridge vertical continuity 38/38. Total **281/281**.
Actual panorama rendered from an explicit transferred provisional north-shore/PTZ site (-33.8487411,151.214266,79m ASL). Tower bearing **268.331527deg**, ground range **991.076m**, given that SITE HYPOTHESIS. Scene: **30 cuboids**, **540 SVG polygons**, XML well formed. Native SVG rasterised to PNG by CairoSVG, no image-generation tools.

Code: `packages/oorexx_slam_v0.1/src/SlamHarbourBluesPointTower.cls`, renderer `SlamHarbourPanorama.cls`, `bin/render_ptz_blues_tower.rex`, `tests/test_blues_point_tower.rex`.

**Admission gate:** New BPT reference is a useful east-west pan anchor but not a surveyed 3D rooftop control. PTZ camera building, optical centre, zoom schedule, image pixel identity, lens intrinsics and ferry world positions remain unqualified. Next: verify tower silhouette/corners in PTZ frames and ground elevation independently; use as held-out 3D anchor rather than silently forcing camera pose.
