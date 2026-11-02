# Power SLAM Harbour v0.21 — visible-surface overdraw / Cahill approach

Architect: Tom Dyer. ooRexx implementation: ChatGPT GPT-6, 2026-11-02.

## Problem being fixed
Earlier SVG painter sorted faces back to front, but displayed every face at opacity 0.72 and placed landmark labels last even when physically concealed. This allowed apparently seeing through concrete/stone and drew station labels over the foreground expressway. A continuous approach away from the bridge also was missing; only the central Cahill station deck had geometry.

## Actual native changes
- `src/SlamHarbourPanorama.cls` additive `featureVisible(id,cam)` overridable hook (default true, preserving legacy), and guards in landmark annotation; Blues Point Tower optional label and colours for approach pieces.
- `src/SlamHarbourOcclusion.cls` (new): `HarbourOcclusionPanorama` (subclass of the genuine Opera-walk/quay scene) draws **opaque** faces in existing far-to-near order and uses a numeric `HarbourRayOcclusion` segment-vs-rotated-cuboid intersection to hide obscured landmark labels. Overdraw means background solid surfaces are drawn first, and closer faces physically cover their pixels. Open areas between solids remain open. **Not** a full per-pixel z-buffer; interpenetrating long solids and partial silhouette intersections may need triangle subdivision or a Z-buffer later.
- Adds 28 short segments on a provisional southern road approach from near the bridge southern masonry at (-33.85436,151.20926), z49m to The Rocks transition (-33.8585,151.2091), z26m, then to western Circular Quay station (-33.86146,151.20980), z16.5m. Each segment has a 20m-wide road slab of 2.5m thickness and an approximate *retaining/embankment occluder* extending to local z5.5m. **The exact road trajectory, real undercroft/embankment geometry, local terrain and elevations are NOT SURVEYED.** It should not be taken as proof the entire historic viaduct was an earthen berm.
- The provided southeast Woolloomooloo point, Domain Tunnel, northern bridge peak, and Milsons transition are NOT added as above-ground obstructions. The user-provided coordinate (-33.860627,151.205760) is not spliced into the above-ground approach automatically because its linkage to the other inputs is unverified.
- Keeps corrected bridge abutment/deck/pylons, station/Cahill above it, Opera House coarse box, Blues Point Tower and wharves. No ferries generated, no fake cityscape.

## Native qualification
- ooRexx 5.3.0 r13196 with rxmath: `tests/test_occlusion.rex` **28/28 PASS**: near-box occlusion, open ray, over-box ray, background visibility, ignoring own box, 28-segment geometry, ramp provenance, preserving original controls, numerical source-scene checks including real Cahill masking station and a bridge pylon masking southern point, and generated berm block hiding an actual low ray while admitting the high ray.
- Regressions (run against the same edited base render class): Opera forecourt 21/21; bridge continuity 38/38; quay infrastructure 40/40; Blues Point Tower 22/22; panorama 36/36. **185/185 combined PASS.**
- Renderer produces three independent 360-degree native-SVG panoramas from hypothetical cameras: `NORTH_PTZ` (-33.8487411,151.214266,79m ASL); `CAFE_SYDNEY` (approx. rooftop centre,25m ASL); `OPERA_WEST_WALK` (-33.856700,151.214430,7m ASL). Each has 86 solids (existing 30 + 56 approach). All 3 SVGs validate as XML; PNGs are direct rasterisations, not generated illustrations.
- Numeric sightline log shows: Cafe station centre `BLOCKED_BY_CAHILL`, Cahill top CLEAR; Opera-west south bridge marker `BLOCKED_BY_PYLON_TOWER_PHOTO`, north bridge marker CLEAR; Blues Point Tower roof marker CLEAR. These are specific point decisions, not full silhouette proof.

## Physical correctness limits
- The bridge steel arch still has no truss mesh, so one cannot yet verify all bridge openings or bridge-Opera overlap patterns. Individual cuboid faces are 100% opaque rather than ghostly semitransparent; through-bridge visibility is only via the open space not occupied by those solids.
- The overdraw is a 360° azimuth/elevation projection, not a perspective PTZ lens image. A calibrated camera pose or ferry localisation MUST remain NOT_ADMITTED.
- Retaining wall terrain is deliberately an *occlusion hypothesis* at the user's instruction. Confirm all surface/retaining wall footprints and terrain z before admitting it for visual fit/real safety-critical use.

## Reproduction
`sh packages/oorexx_slam_v0.1/bin/reproduce_harbour_occlusion.sh` with ooRexx 5.3, rxmath, SVG rasteriser optional. The native SVG render does not require Python or image generation. No user photographs or generated artwork are included.