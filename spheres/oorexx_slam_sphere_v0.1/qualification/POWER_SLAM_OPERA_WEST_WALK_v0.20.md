# Power SLAM Sydney Harbour v0.20 — Western Opera House forecourt SVG viewpoint

Architect: Tom Dyer. Implementation and qualification: ChatGPT GPT-6, 2026-11-02.
Rasen Falcon component: `power-slam-harbour`. Ferry recognition owner: `tombstone-vision`.

## Why this exists
The user asked for the existing Power SLAM cuboid-based 360-degree SVG model **as observed from the western forecourt walkway of the Opera House**, rather than an unconstrained generative Sydney illustration. The latter incorrectly duplicated Circular Quay wharves, varied bridge/Opera House bearing relationships, and placed numerous invented ferries. It is NOT evidence for geometry.

## Implemented
- `SlamHarbourOperaWestWalk.cls` subclasses the current HarbourQuayInfrastructurePanorama and provides an optional site `OPERA_WEST_WALK` at provisional (-33.856700, 151.214430), camera elevation 7m above the model datum.
- Scene explicitly reorients the old coarse Opera cuboid: length 183m along N–S, 120m across E–W, base+height unchanged. The walkway camera falls 13.0093m west of the newly oriented west face. This is not a surveyed shell, roof, walkway or coastline.
- Keeps v0.18 bridge abutments/deck/pylons, v0.19 Blues Point Tower, and existing wharf + CBD landmark solids.
- Native `render_opera_west_walk.rex` generates a complete 360-degree SVG from cuboids. No generative image or invented ferry or skyline is added.
- Camera bearings from model: Bridge South 298.767714°, Blues Point Tower 310.405823°, Bridge North 344.149954°. Camera-to-feature azimuth measured clockwise from true north; projection is an azimuth/elevation plot, not a real photographic lens.

## Evidence and limitations
Native ooRexx 5.3.0 r13196 and rxmath: `test_opera_west_walk.rex` **21/21 PASS**. Render returned `BOXES 30` and rasterised image; SVG validated XML, 540 polygons including wrapping. The immense Opera House cuboid in the near field is a modelling artefact; it is not a simulated photo of the sails.
No surveyed roof outline, camera height, eye position, shoreline land qualification, arch mesh, PTZ calibration, or ferry spatial location. Camera pose remains `NOT_ADMITTED`.
The optional box-orientation correction is limited to this view. It does not retroactively modify older calibration scene geometry.

## Reproduction
`sh packages/oorexx_slam_v0.1/bin/reproduce_opera_west_walk.sh` on a checkout with ooRexx and rxmath.
Files: `src/SlamHarbourOperaWestWalk.cls`, `tests/test_opera_west_walk.rex`, `bin/render_opera_west_walk.rex`, `bin/reproduce_opera_west_walk.sh` and README.

## Follow-up
To replace the box approximation with physical venue outlines, georegister the Opera House roof/shell features and forecourt walls and landmarks with independently verified metre coordinates. Keep real video frames, model SVG, and synthetic illustrations visibly separate in every report.
