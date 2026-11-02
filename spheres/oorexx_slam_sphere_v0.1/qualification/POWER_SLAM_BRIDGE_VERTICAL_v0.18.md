# Power SLAM Harbour — corrected bridge vertical continuity v0.18

Architecture: Tom Dyer. Implementation/testing: ChatGPT GPT-6, 2026-11-02.
Lane: power-slam-harbour. Ferry recognition: tombstone-vision.

## Physical defect
Previous roof-pin bridge scene drew four upper 50–89m pylons but omitted the two masonry abutment towers below the road. The deck slab was z48–52m with upper surface at 52m (not the NSW Government approximate road deck 49m above water). Camera optical geometry has been improperly compared against disconnected-looking pylon and deck structures.

TfNSW conservation management plan distinguishes stone abutment towers below deck from four stone pylons above deck, and an arch truss separate from the deck.
- https://www.transport.nsw.gov.au/system/files/media/documents/2023/sydney-harbour-bridge-conservation-management-plan.pdf
- https://www.nsw.gov.au/ministerial-releases/four-shades-of-grey-painting-blitz-on-sydney-harbour-bridge-ahead-of-100th-anniversary

## Corrected model, explicit opt-in
`SlamHarbourBridgeVertical.cls` takes a `HarbourQuayInfrastructurePanorama` scene after `HarbourBridgeRoofPins~apply` and rebuilds its bridge as:
- Two masonry abutment solids, *approximate* z5.5–49m, dimensions 49m long x 58m wide;
- One deck slab, approximate z46–49m, 49m wide;
- Four upper granite towers z49–89m.
The two abutments and four pylons physically connect through the deck. No survey precision or ASL/AHD datum equivalence is asserted.
Arch crown landmark stays z134m; steel arch geometry not yet constructed.
Output: 29 model cuboids; actual native ooRexx panorama SVG 522 valid polygons and a direct rasterisation PNG, no generative imagery.

## Native qualification 5.3.0 r13196
- Vertical scene assembly: 38/38 PASS, including slab touch, lower masonry and roof tops.
- Fixed-camera before/after projection sensitivities: 25/25 PASS.
- With fixed provisional camera poses, lowering road *surface* from z52 to z49 moves apparent southern and northern deck edges in photograph pixels, respectively:
  - North shore: +2.92 and +11.31 px
  - Blues Point tower vicinity: +1.65 and +2.67 px
  - Café Sydney illustrative 25m ASL 2700px focal: +9.56 and +5.91 px.
- Separate image-point deck proxies lower only 50->49m and have smaller shifts.

## Full six-variable diagnostic refit, not accepted
The original 1536x709 photo annotations were reused for both old and corrected scenes with 25 solver iterations; landmark measurements and camera search bounds are **unsurveyed**:
- North shore height 79m before -> 79m after; arch holdout improves 39.95 -> 32.56px BUT Opera House worsens 12.80 -> 28.62px. Remains `BLOCKED_ARCH_HOLDOUT`.
- Blues tower vicinity 67.625m before -> 68.0625m after (+0.4375m); arch holdout 72.71 -> 72.42px and Salesforce stays ~150px away. Remains `BLOCKED_CAMERA_POSITION_BOUNDARY` and arch mismatched.
- Café Sydney original southern SE/northern NE fit 42.125m, arch holdout 35.1px; corrected full fit exceeded runtime and did not complete. No valid new height estimate.

**Not qualified:** new bridge heights are approximate relative to water, not surveyed geodetic elevations; outline/roof pin dimensions unsurveyed, original camera pixels and physical pylon identity provisional. Camera XY/Z/yaw/pitch/focal and ferry-world positions MUST remain UNKNOWN/UNQUALIFIED until holdouts and roof boundary independently validate.

Sources, tests and reproducible renderer: `packages/oorexx_slam_v0.1/README_BRIDGE_VERTICAL_v0.18.md`; `bin/render_ptz_bridge_continuity.rex`.
