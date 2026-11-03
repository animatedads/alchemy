# Power SLAM v0.40 — Blues Point Tower rooftop camera: eastern edge corner

Architecture: Tom Dyer. Native ooRexx implementation: ChatGPT GPT-6. User requested building roof +2 m, then the easternmost roof corner.

## One native geometry authority

The **native** `HarbourBluesPointTower~catalogue` places a provisional unrotated 24 m (E–W) × 20 m (N–S) footprint at the catalogue building reference (-33.849000568058, 151.20353302224). The building's quoted 83 m is **above ground**, not a surveyed AHD roof elevation. `HarbourOcclusionPanorama~configure` currently passes an explicit illustrative 0 m ASL base to `apply`, creating a 83 m model roof.

`BLUES_PT` now uses the native catalogue's **southeast** roof corner (the southern of the two equally easternmost corners), exactly +12 m east and −10 m north of the centre in scene-local coordinates, at **model roof +2 m**, or 85 m with the current illustrative base. Site lat/lon is calculated using the existing scene-local linear approximation. There is no new independent footprint, camera altitude or structure solid.

The previous v0.39 Python render used its own 28 m × 28 m box, an unrelated centre coordinate and a +14 m/−14 m diagnostic offset. That is **not** the native scene and must not be considered the accepted pose for future native builds. Do not adjust the true scene to match those historical diagnostic measurements.

## Qualification and tests

`packages/oorexx_slam_v0.1/tests/test_blues_pt_corner_v040.rex` verifies native X/Y corner offsets and 2 m roof clearance before and after `configure`, as well as preserving North PTZ height. This model choice is not a surveyed camera installation or calibrated photo match; the existing camera pose holdouts remain unqualified. The test must be executed on ooRexx 5.3.0 with repo class dependencies before claiming a native PASS.

**Vertical scale stays 1:1.** Harbour water mask, wharves, Circular Quay station and Cahill Expressway geometry are unchanged.
