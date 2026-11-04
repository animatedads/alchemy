# Power SLAM Harbour v0.21 — occlusion, bridge approach and Cahill visual barrier

Architect: Tom Dyer. Native ooRexx implementation: ChatGPT GPT-6 (2026-11-02).
Ownership lane: `power-slam-harbour`. Ferry observation lane: `tombstone-vision`.

## Model semantics
The existing 360-degree `HarbourPanorama` sorted faces far-to-near but used 72% opacity, rendering false through-solid visibility, and then drew text labels for all points regardless of whether behind structures.

The v0.21 **opt-in** renderer in `SlamHarbourOcclusion.cls`:
- overrides face painting to **100% opacity**, preserving gaps between *actual model solids*, while rendering nearer faces after farther faces;
- introduces exact 3D ray/rotated-cuboid segment intersection to reject occluded landmark labels;
- keeps legacy transparent rendering by default for historical reproducibility, with only an additive `featureVisible` hook in `SlamHarbourPanorama.cls`;
- adds 28 short approach sections, each comprised of rough **20m wide** roadway slab and **unsurveyed** retaining/berm mass, from roughly (-33.85436,151.20926,z49) through (-33.8585,151.2091,z26) to (-33.86146,151.20980,z16.5). Sixteen-odd metres over the Circular Quay station continues via existing Cahill structure. These are provisional control points and roof heights, not surveyed retaining-wall terrain.
- intentionally does NOT render the Domain Tunnel, Woolloomooloo end, northern ground transition or the west route terminus coordinate as above-ground retaining walls. An identified point on a route is not automatically a visible surface obstacle.

## Real calculation / qualification
ooRexx 5.3.0 r13196 + rxmath; six native test suites PASS **185/185**:
- 28/28 new actual ray and embankment tests
- 21/21 Opera western walkway
- 38/38 deck/abutment continuity
- 40/40 Circular Quay infrastructure
- 22/22 Blues Point Tower
- 36/36 panorama regression

Each genuine native panorama (north-shore PTZ same-building hypothesis 79m; Café Sydney 25m; Opera House western walkway 7m) draws **86 solids and 1,548 fully opaque SVG face polygons**. XML and opacity checks PASS; PNG previews are literal rasterisations of those SVGs (no generative visual content, no photographic source frames).
Measured ray visibility: Café Sydney -> STATION_C BLOCKED by CAHILL while CAHILL_C clear; Opera-west -> south bridge feature S blocked by PYLON_TOWER_PHOTO while northern bridge N clear; Blues Tower roof remains visible. Also tested the actual generated berm cuboid blocking a low ray while allowing a high ray.

## Limitations and admissions
This is opaque back-to-front SVG painter ordering **plus point ray tests**, not yet full per-pixel Z-buffer triangle clipping. The masonry pylons and road deck are opaque, but the steel arch/truss lattice is not yet modelled. Therefore some apparent "view through the bridge" gaps are absent steel structure, not verified real open cells.

The route topography, eastern interchange, berm thickness, wharf roofs, Opera House box, camera pose and camera height are not surveyed. This is an **occlusion/provenance prototype**, not accepted geographic camera or ferry localisation.

The user requested occlusion explicitly to prevent landmarks from appearing through road/bridge embankments. Do not treat these first-cut retaining masses as certified map geometry. Verify actual approach ramp support and terrain before using for high-confidence site fitting.

## Code
`packages/oorexx_slam_v0.1/src/SlamHarbourOcclusion.cls` and `SlamHarbourPanorama.cls`; test, native renderer, numeric sightline audit and reproduction shell commands in the matching package subtree. Source PNG/SVG supplied as a separately packaged deliverable, not inserted as fictional scenery.
