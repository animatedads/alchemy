# ooRexx Vision 3D Reconstruction v0.1-dev9 — native motion bridge

Dev9 connects the existing hall-first / semantic-metric / constraint-plan work
to the dev7/dev8 camera-path and pose-cloud solver at the **native video
cadence**.

## New in dev9

- `VisionNativeCadencePolicy` / `VisionNativeCadenceFeasibility`
  - frame N must be compared to frame N+1;
  - native timestamps are authoritative;
  - accidental 5 fps motion decimation is rejected.
- `VisionNativeLineTracker`
  - gives Line Assessment runs conservative short-term identities so line
    position, angle and apparent scale can be compared frame-to-frame.
- `VisionNativeMotionInterpreter`
  - derives common image drift, expansion and parallax spread without claiming
    pixel motion is metric motion.
- `VisionNativeMotionConstraintBuilder`
  - converts native image evidence into dev8 `VisionCameraStepConstraint`
    envelopes while enforcing <=3 m/s and angular feasibility.
- `VisionNativeMotionLoop`
  - complete `VisionSurface -> LineAssessment -> geometry comparison -> motion
    evidence -> pose constraint` inner loop.
- `VisionLayoutHypothesisEvaluator`
  - a proposed floor layout is invalid as soon as any frame has no physically
    possible camera pose.
- `VisionDualSourceLayoutEvaluator`
  - fuzzy common-layout checking for synchronized independent cameras without
    assuming a rigid hand-held stereo baseline.
- `VisionRecordedMotionTraceAdapter`
  - replay/qualification bridge so recorded native-frame evidence can drive the
    same pose-cloud contracts without making Python/OpenCV a runtime dependency.

## Important inherited repair

Dev9 repairs a dev8 `VisionPoseCloudTimeline.append` eager-boolean bug that could
index frame 0 on an empty ooRexx Array.  The first timeline frame now appends
correctly and is covered by the new layout-hypothesis tests.

## Governing solve order

```
V5V native frame N
  -> identify short-lived items / structural lines
  -> compare against frame N-1
  -> motion / expansion / parallax evidence
  -> physical camera-step envelope
  -> feasible pose cloud
  -> accessible-floor + wall/opening pruning
  -> fuzzy agreement with other camera sources
  -> only then promote surviving common geometry into a floor-plan hypothesis
```

The known real-flat facts (3–4 m hall, bathroom right, living-room doorway at the
hall end, kitchen right on living-room entry) remain qualification ground truth.
They are not fed into the blind solver.

See `docs/NATIVE_MOTION_BRIDGE.md` and
`qualification/DUAL_CAMERA_NATIVE_5BIT_TRACE.md`.
