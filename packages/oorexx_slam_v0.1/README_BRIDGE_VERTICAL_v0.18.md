# Power SLAM Sydney Harbour — Bridge vertical geometry v0.18

Architecture: Tom Dyer. Corrective implementation: ChatGPT GPT-6. 2026-11-02.

**Problem:** The provisional roof-pin model (`HarbourBridgeRoofPins~apply` from v0.12) substituted four z=50–89 m photo pylon boxes and a z=48–52 m deck, but omitted the huge masonry abutments below deck. The scene visually left pylons suspended above the roadway. The 52 m deck top also differs from published NSW guidance on road deck ~49 m above water.

**Validated model change (additive opt-in):** `HarbourBridgeVertical~apply(scene)` operates only on the scene after `HarbourBridgeRoofPins~apply`. It removes the old four pylon and bridge-deck boxes, preserving all other geographic geometry, and constructs:

- 2 `ABUTMENT_S` / `ABUTMENT_N` masonry blocks, with approximate top 49 m, approximate base 5.5 m, approximate 58 m transverse and 49 m long dimensions. These connect the masonry visually and structurally below deck. Footprints and datum are not site surveyed.
- 1 `DECK` continuous box, z=46–49 m, width 49 m, length from the accepted provisional photo-pin bridge axis. The slab crosses and contacts the abutment heads.
- 4 `PYLON_TOWER_PHOTO` granite-faced upper bodies, z=49–89 m, retaining provisional 19 x 11 m roof-pin envelope. They now connect exactly at z=49 m instead of floating.
- `S_DECK`, `N_DECK`, `D`, `*_DECK_PROXY` updated to z=49m for the corrected scene; status `CORRECTED_CONTINUITY_GEOMETRY_UNSURVEYED`.

**Structural distinction:** The 2007 Transport for NSW/RTA Conservation Management Plan separates the abutment tower (below deck) from pylons starting at deck level. The government also describes the road deck about 49m over water, 49m deck *width* is a separate parameter, granite pylon tops 89m ASL, and arch crown 134m. Reference: https://www.transport.nsw.gov.au/system/files/media/documents/2023/sydney-harbour-bridge-conservation-management-plan.pdf ; https://www.nsw.gov.au/ministerial-releases/four-shades-of-grey-painting-blitz-on-sydney-harbour-bridge-ahead-of-100th-anniversary

**Qualification:** The original ooRexx roof-pin qualification 29/29 and Circular Quay qualification 40/40 still pass unchanged, while new v0.18 explicit vertical assembly tests pass 38/38 under ooRexx 5.3.0 r13196. Native `render_ptz_bridge_continuity.rex` emitted actual 360-degree SVG with 29 scene cuboids and 522 SVG polygons, XML validated, directly rasterized to PNG (no image generation). The PTZ camera XY, altitude 79m are **the unqualified 2026-11-02 transferred north-shore fixed-camera pose**; do not present as actual PTZ survey data.

**Boundaries:** This is a structural correction, not an admitted 3D survey. Ground heights, granite tower shapes, roof widths and vertical datum remain approximations. The actual steel arch is still not in the cuboid scene. Measured camera locations, true camera lens intrinsics and ferry world positions remain UNQUALIFIED. Do not propagate the z=49 photo proxies into historic camera calibrations without new re-qualification; opt in explicitly to v0.18 for visualization.

Native test commands (with ooRexx and rxmath installed):
```
REXX_PATH=<directory containing these files>:<existing Power SLAM source> rexx test_bridge_vertical.rex
REXX_PATH=<directory containing these files>:<existing Power SLAM source> rexx render_ptz_bridge_continuity.rex corrected.svg
```

## Reprojection sensitivity and independent six-variable refits (2026-11-02)

Additional native ooRexx diagnostic `test_reprojection_delta.rex` passes **25/25 checks**. For the *same unqualified camera poses*, lowering the rendered road surface 52 -> 49 m changes predicted image-y by:

| Fixed camera hypothesis | South end delta | North end delta |
|---|---:|---:|
| North-shore v0.14 | +2.92 px | +11.31 px |
| Blues tower vicinity v0.14 | +1.65 px | +2.67 px |
| Cafe Sydney 25m ASL, 2700px focal illustrative | +9.56 px | +5.91 px |

The previous *image landmark deck proxy* was z50 (not z52), so moving proxy pixels to z49 produces smaller shifts; the native output reports those separately. Positive image-y means downward in image. These values are numerical reprojections of the same XY/Z/yaw/pitch/focal and are **not fitted camera-height shifts**.

`fit_bridge_vertical_other_cameras.rex` independently refits the same four provisional photographic observations before and after the correction (25 bounded iterations per fit):

| Hypothesis | Old height | Corrected height | Independent arch holdout | Status |
|---|---:|---:|---|---|
| North shore | 79.0m | 79.0m | 39.95 -> 32.56px | BLOCKED_ARCH_HOLDOUT |
| Blues tower vicinity | 67.625m | 68.0625m | 72.71 -> 72.42px | BLOCKED_CAMERA_BOUNDARY and ARCH_HOLDOUT |

The Opera House holdout **worsens** for north shore (12.80 -> 28.62px). Blues' Salesforce Tower still misses by ~150px. These invalid outcomes make clear that updating the deck/pylon geometry cannot by itself admit a camera pose; the third-party building coordinates, optical centre, zoom, bridge crown locus and actual image correspondences still need independent qualification.

A Cafe Sydney 6-variable corrected refit was attempted, but interrupted due to excessive evaluation cost. **No accepted updated Cafe camera height is available.** The fixed-pose projection above is the only completed quantitative Cafe diagnostic for this revision.

All new diagnostics depend on `SlamHarbourOtherCameraFit.cls` from the merged v0.14 package. The new vertical scene is **opt-in** to avoid retroactively rewriting previously published test evidence without versioning. Camera height is not established by the vertical model alone; the government's approximate deck-over-water height should not be read as a surveyed ASL/AHD datum.