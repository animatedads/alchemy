# Vision / V5V sphere — ownership and Camera Behaviour boundary
Version: 2026-10-23
Status: documented; runtime integration with Camera Behaviour pending
Authority: Vision source package, not a replacement for Camera Behaviour

## Intention
Represent video as processable spatial observations while preserving source provenance, temporal reconstruction and selective higher-resolution requests. The original video remains authoritative; reconstructed VisionSurface evidence is a projection.

## Semantic objects
- VisionSurface: packed N-bit spatial samples, V declared values, value model, sourceRef, region, timestamp and generation.
- VisionPackedValues: exact packed sample storage.
- V5VFrameRecord: sequence, timestamp, recordType (KEYFRAME or DELTA), payload and changedCount.
- V5VTemporalCodec: temporal encoder/decoder, keyframe cadence and independent reconstruction state.
- LineAssessment: frame-level horizontal/vertical line-run evidence; no tracking authority.
- VisionRegionRequest / VisionRegionMaterial: explicit region/time refinement and evidence linkage.

## Invariants
1. Producer buffers cannot mutate an admitted keyframe or the codec's temporal base.
2. A decoder's returned KEYFRAME surface cannot mutate the archived record payload.
3. A decoder's returned surface cannot mutate the decoder's next temporal base.
4. Temporal DELTA reconstruction is exact relative to the admitted VisionSurface, not a promise of lossless original RGB video.
5. Spatial coordinates, observation time, sourceRef and generation survive snapshotting.
6. No inferred semantic identity from contour closure or geometric proximity alone.

## Separation of responsibility
Vision owns frame representation, spatial measurements, reconstruction and refinement requests.
LineAssessment owns structural frame evidence.
Camera Behaviour owns temporal tracks, nested regions, direction and scene-aware motion interpretation. FCVehicleMotion is an FC/FD-specific consumer, not a general dependency.
Queue Fabric transports durable work intent and references; Storage Fabric retains material. Neither is a compulsory dependency for local Vision invocation.

## Qualification
Dev20 archive: oorexx_vision_v0.1-dev20-keyframe-ownership.zip. The prior qualification record reports 14/14 ooRexx 5.3.0 r13196 test files passing and standards enforcer 0 errors / 53 warnings. Those are historical archive results, not CI on this GitHub commit.
The repository V5VCodec.cls has now been advanced to keyframe and temporal snapshot semantics. Remaining source/test reconciliation against the archive is required. Camera Behaviour integration and live camera tests remain unqualified.

## Next acceptance
- Reconcile all package files and dev20 tests with GitHub.
- Execute all tests against the checked-out GitHub tree.
- Test FFmpeg frames and V5V reconstructed frames through identical Camera Behaviour inputs.
- Compare nested boxes, tracks, direction, line continuity and selective AOI results.
- Record explicit behavioural tolerances for lossy thresholds; no silent threshold-based semantic claims.
