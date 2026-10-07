# ooRexx Vision v0.1-dev15 repaired1

This is a conservative runtime-repair derivative of the Library package
`oorexx_vision_v0.1-dev15-v5v-codec-highres.zip`.  The public API remains
`vision/0.1`; V5V and selective high-resolution semantics are unchanged.

Repairs made for ooRexx 5.3.0 r13196:

- avoid the special `RESULT` variable as an array accumulator in AOI, track-age
  and boundary extraction paths;
- replace `.nil | object~method` expressions with explicit branches because
  ooRexx boolean operators do not short-circuit;
- repair AOI and geometry-escalation construction of the four-argument
  `VisionRegionRequest` contract and set fidelity/purpose attributes explicitly;
- use `VisionRegion~startTime` / `endTime` rather than nonexistent time accessors;
- replace unsupported numeric-object `~sqrt` with a deterministic package-local
  Newton square-root routine;
- make quadrilateral nil-contour rejection explicit before reading contour
  attributes;
- make V5V initial/keyframe selection independent of boolean short-circuiting;
- update the inherited AOI test to the declared `requestedBits` and
  `requestedValueCount` attribute names.

No lossy V5V policy was enabled and no semantic/classification authority was
moved into Vision.
- isolate inherited test assertion helpers with `PROCEDURE`; several tests used
  caller variable names (`m`, `c`) that were overwritten by `USE ARG` in the
  helper routine and therefore failed after the source defects were repaired.
