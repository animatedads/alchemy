# Tombstone Sydney Vision v0.16 — V5V/Camera Behaviour track evidence

Architecture: user. Implementation: ChatGPT GPT-6, 31 October 2026. Additive to PR #106, no change to Vision or Camera Behaviour core.

## Change from v0.15

The existing `VisionSurface`, `V5VTemporalCodec`, `VisionSurfaceDelta`, `VisionChangeRegionExtractor`, `CameraLumaTemporalTrackSet` and `CameraLumaPrimitiveQualitySet` remain the only codec/movement engines. The new `sydney_v5v_camera_motion.rex` adds a fifth required output argument, `trackFile`, writing one record per actual Camera Behaviour clip-local track rather than reporting only totals. Records include track id, first/last source frame, observation count, displacement and path in 80×45 evidence cells, admitted/rejected motion, existing quality score and rejection reason, edge share, size ratio, source hash, and `OBSERVED_UNTESTED`. No classifier or tracker is implemented locally; no track is labelled ferry without independently scored evidence.

`run_both.sh` checks each source MP4 SHA-256 and presence of seven canonical dependency sources, uses FFmpeg only as 5fps RGB24 decoder/80×45 reducer, runs native ooRexx on both recordings and retains source-frame and per-track evidence. No OpenCV. Original RGB24 is authoritative; V5V's exactness applies only to quantized indexed VisionSurface reconstruction.

## Executed test receipts

- ooRexx 5.3.0 r13196 `rexxc sydney_v5v_camera_motion.rex -s`: **rc 0**, source syntax check only.
- `sh -n run_both.sh`: **rc 0**.
- Deliberately missing canonical Vision source tree: fail closed **rc 3**, `CANONICAL SOURCE MISSING: .../Vision.cls`. This is a dependency negative test, not integration success.
- Both supplied MP4 original SHA-256 values independently verified. The previously decoded full inputs contain 156 and 130 frames at 80×45 RGB24.
- **Full native canonical V5V/Camera Behaviour integration NOT RUN** in this container. The corresponding repository class files are not mounted; outbound raw GitHub file retrieval is unavailable. No simulated source mirror or invented track count.

## Reproduce in canonical checkout

```sh
sh examples/tombstone_sydney_v5v_camera_v0.16/run_both.sh /path/1000066232.mp4 /path/1000066230.mp4 /tmp/tombstone-v016
```

Set `REXX_BIN`/`REXXC_BIN` and `LD_LIBRARY_PATH` if ooRexx is not system-installed. Repo class dependencies are loaded through `REXX_PATH`. Input frame counts should be 156 and 130 only when the exact original media hashes match. Native stdout and `*.tracks.psv` establish actual Camera Behaviour movement-track counts and quality admission.

Camera Behaviour owns association and quality, V5V owns indexed evidence; SLAM is a separate evidence-scoring consumer, not a `TESTED` graph admission. v0.12 approximate geography and v0.13 lower-hull proxy are separate layers, not part of the codec.
