# Source provenance — v0.1-dev9 native motion bridge

Dev9 is derived from the qualified `oorexx_vision_3d_reconstruction_v0.1-dev8-pose-cloud`
baseline and retains its reconstruction, hall-first, semantic-prior, metric-plan,
native camera-path and pose-cloud contracts.

New implementation authority:

- `src/Vision3DNativeMotion.cls`

New source dependencies / supplied material used for qualification:

- ooRexx Vision v0.1-dev14 V5V/high-resolution package;
- ooRexx Line Assessment v0.1-dev1 camera/Vision adapter package;
- ooRexx ML Graph v0.1-dev6 as optional presentation/debugging support;
- simultaneous user-supplied recordings `1000060609.mp4` and
  `VID_20260923_050113.mp4`.

User-established solver rules implemented by this increment:

- motion planning uses every native ~30 fps source frame, comparing N with N+1;
- camera translation is physically bounded to 3 metres/second;
- turning is time-bounded; 72 degrees in ~0.2 s is the current hard sliding
  window and 90 degrees over 0.5 s remains admissible;
- every proposed frame pose must lie on accessible floor and continuous paths
  may not cross walls;
- each video is solved independently first, then fuzzy-matched against other
  sources in one common world;
- the cameras carried side-by-side are correlated but are not assumed to have a
  fixed stereo baseline;
- known apartment topology is qualification truth only, not blind-solver input.

Qualification note:

`qualification/DUAL_CAMERA_NATIVE_5BIT_TRACE.json` is a real-video evidence
trace made from every source frame after 55x98, 5-bit luminance reduction.  It
exists to exercise and inspect native-cadence behaviour.  The extractor used
Python/OpenCV only as a qualification prototype and is not shipped as runtime
authority.

Inherited repair:

- `VisionPoseCloudTimeline.append` was changed from an eager boolean expression
  that could evaluate `frames[0]` to a guarded nested check.  This is an ooRexx
  correctness repair, not a semantic change to the pose-cloud contract.
