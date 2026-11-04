# Power SLAM Harbour — north-shore and Blues webcam approximate pose qualification v0.14

Architecture: Tom Dyer. Implemented: ChatGPT GPT-6. Date 2026-11-02.
Lane `power-slam-harbour`; `tombstone-vision` owns ferry detections.

## Photos and security
User-provided screenshots `1000066483.jpg` (north-shore) SHA-256 `1b3626e7e706bac2d47421617552b4ada58e07c0ce1c13b74d15c0ceeaac7312`, `1000066485.jpg` (Blues) SHA-256 `43041d255821e276c318ae2b3667be4a0344474cb95044c189a73c9eb4ce6e49`. Original photographs and local preview overlays are **not committed**. Both canvas dimensions 1536x709, with approximately 138px blank sidebars on each side. Native pinhole fit uses width 1536 with principal x768 but reports HFOV for active width 1260.

## Native unsurveyed candidate fitting
`SlamHarbourOtherCameraFit.cls` uses individually physically identified pylon roof-interior coordinates and deck proxies; 6-variable constrained non-linear search for XY, Z, yaw, pitch and focal; checks independent arch, Opera and tower correspondences. Coordinates not surveyed, deck proxies approximate.

North-shore input: user seed (-33.848849,151.213921). Output (-33.8487411,151.214266) at 79.0m ASL, yaw206.175 degrees, pitch+1.75 degrees, focal740px, active HFOV80.82 degrees. Independent errors: arch33.92px, Opera26.72px, Salesforce40.69px. **BLOCKED_ARCH_HOLDOUT**; actual supporting rooftop unverified.

Blues reference: Blues Point Tower documented (-33.8490006,151.203533), building ~83m high (Dictionary of Sydney), but webcam identity to tower **unverified**. Numerical output (-33.8488623,151.203338), z66.81m ASL, yaw150.30 degrees, pitch -1.79 degrees, focal440px, active HFOV110.14 degrees. Independent errors: arch72.54px, Opera29.09px, Salesforce151.35px. At boundary of unsurveyed envelope and **BLOCKED_ARCH_HOLDOUT**. Do not report it as a proven building or camera location.

All values approximate; no independent georeferenced camera rooftop polygon, no systematic lens distortion fit, no admitted ferry world-coordinate pose. Both are **hypotheses**, not metric localizations.

## Native qualification and executable proof
`test_other_cameras.rex`: 38/38 checks passed on ooRexx 5.3.0 r13196. `fit_other_cameras.rex`: two photo-derived four-control fits completed and reported the three independent holdout residuals. The larger unbounded all-landmark fit was stopped; do not claim convergence from it. Run `sh packages/oorexx_slam_v0.1/bin/reproduce_other_camera_fit.sh` from the repo after installing ooRexx/rxmath.

Next: georeference rooftop/foreshore boundaries, verify north-shore actual building and Blues Point camera housing; use true arch curve and correct tower assignments; evaluate prospective observations independently. Keep ferry geographic positions UNKNOWN until accepted pose with uncertainty.
