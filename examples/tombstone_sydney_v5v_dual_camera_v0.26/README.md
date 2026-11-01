# Sydney Harbour dual-camera V5V v0.26 — full-cadence source and high-resolution lookup

Architecture: user. Execution: GPT-6, 1 November 2026. Evidence state `OBSERVED_UNTESTED`. The new camera and original camera are **independent sources**, with uncalibrated common world-plane geometry and an approximately 3-second difference between displayed clocks. No cross-camera vessel association is claimed.

## Recorded input provenance

- New camera, stream1 (Bridge LEFT), 1280x720 H.264 30fps, 60sec, original SHA256 `ce247672c487b44a7f3bd45ba828473328c6032b1d1c6bceda5044886d940593`.
- Previous camera, stream2 (Bridge RIGHT), same format, original SHA256 `220e20417cf9109cfe88c0610b7204d1f23b993ce1f06ee3b173338cfd34267d`.
- Both uploads have a `.mkv` filename but actual **MPEG-TS** container. Original files unchanged.
- Native source images carry timestamp/watermark overlays, which have been explicitly excluded from the revised motion-search masks.

## Executed results under real ooRexx 5.3.0 r13196

| Metric | Stream1 NEW | Stream2 ORIGINAL |
|---|---:|---:|
| Original V5V indexed frames | 1,800 | 1,800 |
| Source `NEXT_SOURCE_FRAME` edges | 1,799 | 1,799 |
| KEYFRAME / DELTA | 60 / 1,740 | 60 / 1,740 |
| Native V5V indexed round-trip frames | 1,800 exact | 1,800 exact |
| Packed V5V bytes | 922,343 | 922,795 |
| Conservative water-mask admitted cells of 3,600 | 601 | 460 |
| Motion components touching 3 provisional lines | 388 | 543 |
| Water-area motion components | 2,111 | 2,631 |
| Unconfirmed line seeds | 181 | 229 |
| Two-observation threshold-admitted **motion hypotheses** | 67 | 120 |
| Bounded causal follow matches | 39 | 64 |
| Future-next-original-frame search requests | 106 | 184 |
| Next-frame V5V centroid-hit boxes | 8 | 45 |
| **Actual original-resolution crop lookups fulfilled** | **106/106** | **184/184** |
| Distinct original frames used for source lookups | 101 | 171 |

**Full retained series**: 3,600 indexed V5V frames / 3,598 per-camera temporal edges, 1,845,138 bytes of native packed five-bit V5V. These are source-linked candidate nodes/edges, **not** admitted canonical SLAM SQL graph entries or software TESTED scores.

The **290 fulfilled source-resolution lookups** map 80x45 V5V cells to 1280x720 video pixels (16px/cell), with a one-cell context halo, source hash, frame index, time, exact RGB24 crop hash and `FULFILLED_UNCLASSIFIED` state. Tight search windows average **1.40% of the full 1280x720 image** (total equivalent to 4.06 full source images across the 290 requests). This is pixel-area pruning, not a CPU speedup or ferry recognition rate.

**Important source seek correction**: Direct FFmpeg seeks against incorrectly named MPEG-TS sometimes returned the wrong frame. The videos were remuxed using `-c copy` (no re-encoding) into temporary indexed real Matroska files. **8/8 independently selected sample crops from source seek were byte-identical to sequentially decoded RGB24 pixels from the untouched source files.** The other 282 lookups have SHA receipts and content, but not independent sequential comparison.

Qualifying execution: native V5V encode/reconstruct PASS 3,600/3,600; native line scanner PASS both clips; existing `V5VTripwireFollow.cls` ooRexx thresholds PASS 7/7; native ooRexx causal receipt validation PASS both clips; 8/8 local deliberately corrupted receipts rejected (four per camera). Do not infer ferry detection from motion fragments. Source-resolution review shows that a visibly moving craft can be in a crop with **zero changed V5V centroids on the next 1/30-second frame**; do not label that a negative vessel.

## Full reproducible artifact

Conversation artifact `sydney_harbour_dual_camera_v5v_v0.26.zip`, SHA256 `5faa02cca0966c96c5aa4e7555eade0c26488dd5db8eab5bccb009026564ee96` (~8.54MB). Includes 349 files: complete native executable SOURCE (C V5V codec and scanner, original ooRexx follow/validators, reusable shell replay, FFT/PTS and pixel-lookup transport), both per-view mask/gate PSV, full frame/edge/gate/water/follow/held-out evidence, 290 retrieved high-res crop PNGs plus original-RGB24 hashes, contact-sheet diagnostics, negative qualification logs, and individual file SHA256 manifest.

Original videos, temporary indexed video remuxes, the user-supplied ooRexx binary and regenerated RGB24 stream files are **excluded** from the distributed package.

### Outstanding gates

1. Teach SLAM a properly reviewed positive/negative/uncertain ferry appearance vocabulary. Do not take water/no-new-V5V-change as an automatic negative.
2. Extend native ooRexx predicted search boxes to a bounded **N-frame temporal window**, using actual timestamps, velocity and uncertainty checks rather than only the immediately following frame.
3. Calibrate the two camera views and their clocks using independent shared landmarks and observations before matching vessel identities across cameras.
4. Qualify dedicated visual-event SQL ingestion without promoting untested image observations to SLAM's code-path TESTED graph edges.

Prior v0.24/v0.25 single-view demonstrations and hand-authored gates are **not** camera-survey authority; v0.26 tightens both masks from source-video evidence but the line geometry remains provisional.