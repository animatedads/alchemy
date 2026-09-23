# Dev8 pose-cloud qualification

The new dev8 tests are synthetic feasibility tests.  They deliberately do not
feed the known apartment topology or known hall dimensions into the solver.

Validated contracts:

- native-step propagation preserves a non-empty feasible cloud;
- transitions remain under 3 m/s and respect explicit wall/opening geometry;
- 90 degrees over 0.5 s passes the sliding turn-window policy;
- 90 degrees inside 0.2 s fails the 72-degree turn-window bound;
- two synchronized, separately-carried camera clouds can be matched with fuzzy
  separation and heading tolerances rather than a rigid stereo baseline;
- inherited reconstruction, floor, semantic-prior, metric-plan and Wire3D tests
  continue to pass.

The next integration step is to build `VisionCameraStepConstraint` directly
from the real native-cadence V5V/Line Assessment evidence stream, then retain
or reject proposed floor layouts by whether the resulting cloud remains
non-empty for every frame.
