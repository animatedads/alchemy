# Native-cadence feasible pose cloud — dev8

Dev8 makes camera location a first-class constraint on floor-plan inference.
A candidate layout is invalid when any source frame cannot be assigned at least
one physically reachable camera pose consistent with the source's previous
frame.

## Inner loop

At native source timestamps (~30 fps for the current bodycam material):

1. Vision / Line Assessment identify persistent items and structural lines.
2. `VisionFrameGeometryComparator` measures frame-to-frame displacement and
   line changes.
3. Upstream motion interpretation expresses the admissible motion as a
   `VisionCameraStepConstraint` (distance, turn and travel-bearing ranges).
4. `VisionPoseCloudSolver` propagates all retained previous pose hypotheses.
5. `VisionCameraPathFeasibility` rejects speed > 3 m/s, angular-rate excess,
   inaccessible positions and wall crossings.
6. The surviving cloud is beam-pruned; no single early pose guess is made
   authoritative merely because it is locally convenient.

`VisionCameraTurnWindowFeasibility` additionally enforces the current
qualification ceiling of 72 degrees total absolute turn over about 0.2 s.
A smooth 90-degree turn over 0.5 s remains valid.

## Layout rule

The plan and the camera path are mutually constraining:

- every frame needs a feasible pose on accessible floor;
- consecutive poses must form a continuous path through openings, never walls;
- structural observations must be visible from retained poses;
- a proposed room/wall layout that empties the pose cloud is rejected.

This prevents a visually plausible plan from surviving when it requires the
camera to occupy impossible space.

## Multiple video sources

`VisionCrossSourcePoseMatcher` compares synchronized pose clouds fuzzily.  It
does not assume a rigid stereo baseline: the current pair was held in separate
hands.  Separation and heading tolerances are supplied by the qualification or
capture context.  `VisionCommonLayoutFeasibility` rejects a common-layout frame
when the two source clouds have no compatible pose pair.

The approximate known flat topology and known hall/bathroom/living/kitchen
relationships are qualification targets only.  They are not consumed by the
blind pose-cloud solve.
