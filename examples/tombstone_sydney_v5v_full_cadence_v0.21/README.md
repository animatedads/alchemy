# Sydney Ferry SLAM v0.21 — full-cadence V5V qualification

31 October 2026. Architecture: user. Source codec: ooRexx Vision dev22. Native full-cadence accelerator: C, verified against actual ooRexx V5V output.

## Executed evidence

The two original screen recordings were rehashed and decoded at their **original variable frame cadence** (no 5fps resampling), with FFprobe presentation timestamps preserved.

| | Manly | Earlier |
|---|---:|---:|
| Original frames | 948 | 780 |
| Source sequential edges | 947 | 779 |
| Keyframes / deltas | 32 / 916 | 26 / 754 |
| V5V indexed reconstructed frames | 948/948 | 780/780 |
| V5B payload bytes | 491,415 | 405,158 |
| Whole scene changed cells | 11,426 | 11,762 |
| Changed cells inside provisional water search mask | 5,528 | 6,287 |
| Changed cells outside mask, **preserved** | 5,898 | 5,475 |
| Advisory temporally structured candidate frames | 584 | 595 |

Original source SHA256: Manly `2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192`, earlier `6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb`.

The provisional water mask admits 752/3600 cells for **motion search only**, excluding skyline, bridge traffic and uncertain foreground. The full V5V surface is never masked; all scene information survives and can supply geographic reference evidence.

## Codec / temporal provenance

The native bulk accelerator follows the Vision dev22 fixed scene palette and five-bit V5V packing: 2250-byte keyframes; deltas comprise a 450-byte bit-packed changed mask and five-bit changed values. Local `.v5b` plus indexed offsets is an experiment container, **not** an announced new upstream V5V wire format.

The first **63 actual ooRexx dev22 V5V source frames** (34,346 packed payload bytes) match the native encoder output **byte for byte**, including eleven per-frame metadata fields. The native encoder independently reconstructed all 1,728 indexed frames. A pure ooRexx per-pixel full-source run was halted for execution cost; no full-run ooRexx parity is claimed.

An independent ooRexx 5.3.0 r13196 receipt verifier passed both complete node/edge sequences, including source, PTS chronology, keyframe cadence, payload offsets and allowed/blocked change conservation; three deliberate corruptions were rejected.

## SLAM boundary / next qualification

Every source frame is represented by one immutable, source-linked candidate node, with 1,726 explicit NEXT_SOURCE_FRAME edges across two separate source sequences. Observations are `OBSERVED_UNTESTED`. The data is **not yet admitted into SLAM's database or its TESTED graph**. A proposed additive `SlamVisionFrameIngress.cls` uses separate `vision_` SQL tables so visual evidence cannot accidentally become SLAM code-path scores; it syntax-compiles but requires full Rexx/SQL runtime qualification.

Temporal change screening records neighbour recurrence and connected area under the mask. `SCATTERED_OR_UNRESOLVED` is **not proven wave/chop**: it remains available for AOI review. Earlier native Camera Behaviour track-quality logic is retained as the authority for movement interpretation, not supplanted by this descriptive screen.

The full reproducible source, exact packed streams, event tables, native logs, mask, ooRexx verifier, C accelerator source and actual V5V comparison screenshots are delivered as the conversation artifact `tombstone_sydney_v5v_full_cadence_masked_slam_v0.21.zip`, SHA-256 `597a0faa819a0f2e7700f906c3b06c43f4e5b02b1bff43f981d31f4dc4446994`. Raw MP4 files are excluded.

**Next gate:** qualify canonical SLAM vision ingestion; use full original frame intervals to run Camera Behaviour continuity, reject demonstrably transient water/chop motion conservatively, escalate surviving candidates to original-resolution AOI, and test against separately taught source-linked ferry positive/negative examples with abstention. No vessel identity, harbour homography or speed is established here.
