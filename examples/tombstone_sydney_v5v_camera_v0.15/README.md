# Tombstone Sydney v0.15 — native Vision/V5V + Camera Behaviour integration

This is the **first combined source implementation** of our own V5V temporal codec and our existing Camera Behaviour movement methodology on the user-provided Sydney video. Unlike the earlier v0.11–0.13 OpenCV detector, no OpenCV pixel detection, HSV segmentation or independent tracker is used. FFmpeg is only a video decoder / sample reducer.

## Source contracts

- `packages/oorexx_vision/src/Vision.cls`: actual indexed VisionSurface, delta, connected-region extractor.
- `packages/oorexx_vision/src/V5VCodec.cls`: true V5V keyframe/delta reconstruction, `EXACT_SURFACE`.
- `packages/camera_behaviour_oorexx_v0.56/CameraFFmpegMediaSource.cls`: `CameraLumaTemporalTrackSet~observeComparison` performs 4-neighbour connected motion regions and temporal association.
- `packages/camera_behaviour_oorexx_v0.56/CameraLumaBehaviourBridge.cls`: `CameraLumaPrimitiveQualitySet` gates the movement primitives by persistence, movement, reversals, edge contacts and size stability.

V5V is **not** a viewing codec: it processes a quantized 5-bit 26-value evidence surface. Exact V5V reconstruction is **not** lossless reconstruction of the original MP4.

## Actual source input

User-supplied H.264 mobile recordings `1000066232.mp4` (Manly) and `1000066230.mp4` (other), cropped at x210 to native webcam 1920×1080, sampled via native FFmpeg at 5 fps down to 80×45 RGB24 for a first mechanical test. The fixed scene palette and 4-bit/channel lookup follow already-published v0.14; this is not adaptive palette optimisation. The output records BOTH V5V changed regions and Camera Behaviour movement regions, plus canonical Camera Behaviour quality gates. All evidence is `OBSERVED_UNTESTED`; *no ferry object type is inferred from motion, palette or shape alone*.

Run from a checkout in which Vision, Camera Behaviour, AlchemyObject and ForeignRuntime are on `REXX_PATH`, with ooRexx 5.3.0 r13196. Script `run_video.sh` requires VISION_SRC and CAMERA_BEHAVIOUR_SRC and source hash.

```
VISION_SRC=packages/oorexx_vision/src \
CAMERA_BEHAVIOUR_SRC=packages/camera_behaviour_oorexx_v0.56 \
REXX_PATH='path/to/AlchemyObject:path/to/ForeignRuntime' \
sh run_video.sh 1000066232.mp4 manly.rgb manly_v5v_motion.psv 2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192
```

## Qualification status and blockers

- Both exact source hashes verified locally; 26 × 80 × 45 × 3 bytes of FFmpeg RGB24 verified for each MP4 (280800 bytes each).
- Native `rexxc` r13196 compiled the integration script (syntax only, NOT linked dependency runtime).
- **Canonical full-source runtime integration has NOT RUN:** this container has no mounted current `Vision.cls`, `V5VCodec.cls`, `CameraCore.cls`, `foreign.cls`, `AlchemyObject.cls`. Unlike v0.14's test-only reconstructed mirror, this increment refuses to represent a mirror as a fully qualified canonical test.
- The existing v0.14 narrow V5V native mirror test produced 26/26 exact indexed reconstructions; that is earlier separate evidence, NOT this integration's qualification.
- **Unknown** how much Sydney motion is coherent rather than water texture at 80×45, and unproven how many ferry tracks this method will recover. Independent gate required against exact canonical package source.

## Next work

1. Run the above combined source against the **real canonical package checkout** and compare movement-region/quality counts on both recordings.
2. Use georeferenced water-plane sampling (`APPROXIMATE_UNSURVEYED` from v0.12) so fore/mid/background physical sizes normalize before class scoring; replace repeated pixel-resize search with stable metre-grid sample locations.
3. Use `VisionHighResolutionRequest` when a candidate at 80×45 has insufficient evidence. The output video source is retained for precise crop.
4. Then pass movement evidence into SLAM as `OBSERVED_UNTESTED`; promote to `TESTED` only via SLAM's accepted explicit test authority.