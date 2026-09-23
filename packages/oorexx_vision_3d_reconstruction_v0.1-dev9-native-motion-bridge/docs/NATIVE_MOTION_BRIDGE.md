# Native-cadence motion bridge — dev9

The reconstruction solver now has a production-facing bridge from compact
Vision/V5V surfaces and Line Assessment evidence into the dev8 feasible pose
cloud.

## Motion loop

For every source frame, at its native timestamp:

1. `LineAssessment.assess` extracts frame-local horizontal/vertical structural
   runs from the `VisionSurface`.
2. `VisionNativeLineTracker` gives nearby like-oriented runs short-lived stable
   identities.  It does not claim permanent object identity.
3. `VisionFrameGeometryComparator` compares frame N with N+1 and records line
   midpoint displacement, angle change and apparent length ratio.
4. `VisionNativeMotionInterpreter` summarises drift, apparent expansion and
   parallax spread without pretending pixels are metres.
5. `VisionNativeMotionConstraintBuilder` creates a
   `VisionCameraStepConstraint` bounded by the hard physical policy.
6. `VisionPoseCloudSolver` propagates every surviving possible camera pose.

A ~30 fps source is therefore processed frame-to-frame.  Motion planning must
not silently use a 5 fps decimation.  The source timestamps remain authoritative
so 29.97/30.04 fps material does not acquire artificial timing drift.

## Physical feasibility

The inherited dev7/dev8 policy remains authoritative:

- translation <= 3 m/s;
- angular rate <= 360 deg/s;
- sliding turn window <= 72 degrees in about 0.2 s;
- a 90 degree turn over 0.5 s remains valid;
- camera positions must lie in accessible floor regions;
- path segments may pass through openings but not wall segments.

## Pixel motion is not metric motion

The dev9 bridge deliberately does **not** convert image displacement directly
into metres.  Without depth / calibration that would be false precision.
`VisionCameraProjectionHint` may turn common horizontal image drift into a
*defeasible* yaw suggestion when a horizontal field of view is supplied, while
the hard angular-rate envelope remains the authority.

Likewise apparent expansion + differential motion is useful evidence for
forward translation, but the metric distance envelope remains bounded by the
3 m/s physical policy until a scale anchor is available.

## Multi-camera layout feasibility

`VisionLayoutHypothesisEvaluator` rejects a proposed accessible-floor geometry
as soon as any native frame has no surviving camera pose.

`VisionDualSourceLayoutEvaluator` then fuzzy-matches independently propagated
clouds from synchronized sources.  A positive lag L means `A[L+i]` aligns with
`B[i]`.  It does not assume a rigid stereo baseline; this is appropriate for two
phones carried one in each hand.

The known apartment topology is not used by this blind path solver.  It remains
qualification ground truth.
