# ooRexx Vision v0.1-dev5
Movement integration over corrected lattice authority.

Adds VisionTrackTransform, VisionTrackObservation, VisionTrackEvidenceAccumulator,
VisionPersistentRegion and VisionRegionAssociation.

Static complementary phases accumulate in WORLD coordinates. Moving observations
must be transformed into TRACK coordinates before accumulation. Samples retain
timestamp, age and confidence. Persistence is evidence, not HUMAN/FACE/OBJECT
classification.

Distributed execution remains VisionProcessor + Queue Fabric + Storage Fabric.

## repaired1 qualification repair

This derivative preserves API `vision/0.1` and the dev5 architecture, while fixing
runtime defects exposed by ooRexx 5.3.0 r13196 qualification:

- avoid non-short-circuit `.nil | object~method` expressions;
- avoid the reserved/special `RESULT` variable name for mutable collections;
- construct `VisionRegionRequest` through its declared four-argument initializer,
  then set requested spatial/value fidelity through its public attributes;
- use `VisionRegion~startTime` / `endTime` rather than nonexistent aliases;
- align the AOI test with the declared `requestedBits` / `requestedValueCount` API.

No classification or video-decoding semantics are added by this repair.
