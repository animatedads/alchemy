# Sydney V5V → Power SLAM harbour-geometry adapter v0.1

Architecture: user. Implementation: ChatGPT GPT-6, 2026-11-01. This is the **tombstone-vision source-side contract**, not a second 3D solver or an accepted Power SLAM camera solution.

## Existing canonical work

- Power SLAM Rasen Falcon lane: `power-slam-harbour` (alias `power-slam`), responsible for 3D georeferenced landmarks, bridge semantics, camera pose and uncertainty.
- Ferry SLAM lane: `tombstone-vision`, responsible for V5V indexed frames, source video, camera tracks, timestamps, predicted regions and candidate ferry appearances.
- Power SLAM PR [#108](https://github.com/animatedads/alchemy/pull/108) was **merged into main** on 2026-11-01 18:52 UTC. The v0.12 roof-pin controls are *non-surveyed* interior points, not pylon centres or a camera-position certificate.
- Earlier Power SLAM v0.8 `SlamHarbourPerspectiveFit.cls` provides a six-parameter pinhole forward projection, whose inverse is tested here. v0.11 separately rejects misidentified pylon geometry. Real Café Sydney pose remains blocked.

## Source-bound V5V bridge

`PowerSlamV5VBridge.cls` loads the exact original 16-field human-reviewed ferry-candidate PSV from Streams 2 and 3 and verifies camera/source SHA, original PTS, 30-fps source-index relation, frame and crop bounds, crop RGB24 digest syntax and explicit non-admission status. The sample `observations.psv` is 12 real crop references (six per stream) from the original night-video evidence; it is **not** ferry ground truth.

`exportCandidates` produces 12 candidate rows with both original pixel and 80×45 V5V cell coordinates, preserving `OBSERVED_UNTESTED`, `CROSS_CAMERA_HYPOTHESIS_UNVERIFIED`, and `BLOCKED_UNCALIBRATED`.

`diagnosticRay` inverts `HarbourPerspectiveFit~project` under the same yaw/pitch/focal conventions, but its result remains `DIAGNOSTIC_UNCALIBRATED_RAY`. `worldIntersection` intentionally **cannot** return real-world coordinates until Power SLAM commissions and validates a pose certificate. Merely supplying a certificate-like string does not bypass the gate. No canonical SLAM graph scores, vessel identities or geographic tracks are written.

## Executed qualification

On user-provided ooRexx 5.3.0 r13196:

- **50/50** positive checks PASS, covering actual source-bound candidates, per-camera V5V cell projection, blocked world output and synthetic forward→inverse perspective recovery against the existing Power SLAM projector.
- **11/11** deliberately forged or invalid PSV files rejected (source digest, crop hash, camera ID, evidence authority, vessel identity, coordinate bounds, time, schema and duplicated observations).
- Existing independent Power SLAM v0.11 coordinate and structural tests re-executed: **19/19 + 27/27 PASS**.
- Both original video files' SHA-256 digests checked independently against the input registry.
- **Real camera pose, surveyed water-plane intersection and two-camera same-ferry identity NOT RUN/NOT QUALIFIED.** Synthetic geometry recovery is a mathematics test, not an empirical harbour calibration.

## Reproduce

Requires the existing `SlamHarbourPerspectiveFit.cls` and dependencies from Power SLAM v0.8, `rxmath`, and the user-supplied ooRexx interpreter:

```sh
OO_ROOT=/path/to/extracted/oorexx POWER_SLAM_LIB=/path/to/power_slam_v0.8 sh run_bridge_tests.sh
OO_ROOT=/path/to/extracted/oorexx sh qualify_reject.sh
```

Deterministic exported artifact: `power_slam_v5v_candidates.psv` (13 lines, including header). The original videos and source-resolution crop PNGs are not republished here. Archive with source, metadata, full test logs and SHA256 manifest: `power_slam_v5v_observation_bridge_v0.1.zip` (conversation output), SHA256 `a477f2fd9b6499b16d817d4ffbe318b3b6fbb7a7228485cd3a11ebf79607d92b`.

**Owner interface needed next:** Power SLAM must define the calibrated camera-pose certificate schema, water-plane/height uncertainty contract and multi-camera ray-consistency threshold. Until then, geometric `WORLD` fields must stay blocked and association must stay unverified. No extra coordinate fitter is introduced here.
