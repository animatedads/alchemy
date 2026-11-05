# Face SLAM gait and local pose-provider contract — v0.1-dev2

**Architecture:** ooRexx owns observations and the analysis contract. Vision supplies frame-local evidence; `oorexx_motion_control` owns object tracks; Perception owns pose/face inference; existing ooRexx Maths and ML own numerical operators and reusable similarity/search. Face SLAM does not own person identities or assert that a candidate is a known person.

## Implemented

- `src/FaceSlamGait.cls`: 2D pose frame and joint observations, MediaPipe33/COCO17 topology mapping, geometry through `.Maths~sqrt` and `.Maths~atan2`; torso-normalised ankle displacement and projected knee angle. All results retain source, track, model digest and source PTS. Prior v0.1-dev1 structure is preserved.
- `src/FaceSlamGaitTemporal.cls`: 2D limb-motion sequence review, based on original source-global microsecond timestamps. Rejects non-monotonic time, cross-source/cross-track mixing, non-measurements, corrupt confidence and large temporal gaps. Hysteresis avoids treating small ankle-order jitter as a full reversal. It reports knee excursion and possible periodicity, **not** a recognized gait cycle, true foot-strike, step count, ground speed, or identity.
- `src/FaceSlamPosePacket.cls`: a bounded-schema text interchange from existing provider infrastructure, plus an adapter that sends a pinned source-window token to an **already projected** Python/C++ provider object. This class never launches a Python subprocess, never runs a model, and never owns Python object identity/lifetime.
- Tests: 22 geometry-contract, 17 temporal and 19 pose-packet validations (58 total), each executable on ooRexx 5.3.0 r13196. Negative tests throw and terminate on failure.

## Provider text contract

Each record is one 2D pose frame and is returned as a string by the projected provider object's `pose2dPacket(sourceWindowToken)` message. Fields are separated by `|`, records by `LF`, and the header is:

`POSE2D/1|source|camera|track|PTS_us|width|height|topology|model_digest|source_digest|NORMALIZED_IMAGE`

The records following the header are `zero_based_index|normalized_x|normalized_y|visibility`, with exactly 33 ordered records for `MEDIAPIPE33` or 17 for `COCO17`. Coordinates and confidence must be within [0,1]. Unknown topology, 3D claims, gaps, extra records or missing authority metadata fail closed. The optional final LF is accepted.

The caller must independently validate that `sourceWindowToken` grants the authorised, digest-pinned source interval and that model/source digests agree with its lease/Storage Fabric admission. **The untrusted provider's claimed source/digests cannot provide that authority on their own.** No pass-through of secret credentials or raw media into a durable job description.

A resident Python class may be loaded and projected using `.AlchemyPythonClass~loadCls(...)`; pass the projected instance to `.FaceSlamProjectedPoseProvider~new(projected)`, then invoke `~observe(opaquePinnedSourceWindowToken)`. Foreign Runtime is an alternative provider seam. None of these bridges is vendored into this package.

## Running

```
REXX_BIN=/path/to/r13196/rexx REXX_LIB_DIR=/path/to/r13196/lib bash tests/run.sh
```

The 22 geometry-contract tests contain a **test-only Maths shim**, because the full canonical `MathsBootstrap.cls` dependency was not materialized into this local execution environment. Production code calls actual `.Maths~sqrt` and `.Maths~atan2`, which remain unqualified here. The 17 temporal and 19 packet checks do not need Maths and are native ooRexx execution. The mock provider does not validate Python Macrospace or MediaPipe. A deliberately false assertion was also checked to terminate nonzero.

## Next runtime gates

1. Link canonical MathsBootstrap and run numerical equivalence/precision tests with real Maths contexts, especially for high-precision `atan2` and small knee angles.
2. Qualify actual Foreign Runtime or Python Macrospace against a resident MediaPipe33 provider with a model weight digest and full source-window lease policy.
3. Validate exact PTS/time-base conversion in Video/Vision integration, frame correspondence, person-track continuity, occlusion and camera motion; no false extrapolation through absent frames.
4. Verify side-on/front-on viewpoint effects using consented, independently annotated data; measure false periodicity and missed periodicity before any candidate review integration.
5. Keep later ML neighbour retrieval on anonymized, authorised samples. It may propose observations for human review but must not assert biometric identity without a separately authorized and validated decision process.
