# Sydney ferry V5V v0.24: permanent detection lines and bounded follow search

Architecture: user. Implementation: GPT-6, 31 October 2026. Additive experimental motion evidence on PR #106; no V5V or SLAM authority boundary changed.

The original **948 + 780 frames** (variable original PTS) are retained in the complete indexed V5V archive. On *every frame*, the native codec reader tests configured line bands against the conservative water-only movement-admission mask. The skyline, bridge and excluded pixels remain in the archived V5V record. A triggered movement component first creates an **unconfirmed seed**. Native ooRexx thresholds require a second causal observation before forecast admission. After admission, the search is constrained to an N-range forecast box, using actual next-source-frame timestamps. New arrivals at the lines continue to be monitored while existing candidates are followed.

**Line geometry is provisional.** The three demonstration bands WEST x12, CENTRE x28, EAST x43 at water latitudes y28..41 are explicitly labelled `PROVISIONAL_NOT_USER_TRACED`; they are *not* claimed to be the exact geometry drawn by the user. Digitising those actual line endpoints is a separate commissioning gate.

## Actual executed result, both original clips

| Metric | Manly | Earlier | Combined |
|---|---:|---:|---:|
| Full V5V frames scanned | 948 | 780 | 1,728 |
| Source-linked line-band connected components | 1,147 | 1,179 | 2,326 |
| Source-linked whole-water changed components retained for follow-up | 4,869 | 5,445 | 10,314 |
| Unconfirmed gate seeds | 223 | 266 | 489 |
| Two-observation motion hypotheses passing thresholds | 164 | 185 | 349 |
| Bounded continuation matches | 42 | 56 | 98 |
| Next-actual-original-frame local lookups requested | 206 | 241 | 447 |
| Total 80x45 cells in all requested boxes | 10,264 | 12,407 | 22,671 |
| Requests whose true next frame contains any changed centroid in the box | 91 | 119 | 210 |

A prediction searches an average **50.72 cells / 3,600** or **1.41% of the entire low-resolution frame**, compared to a full-frame search for each lookup. This is a spatial work budget, not a measured video-decoding speedup. **210/447** contains *some* next-frame change, not necessarily a motion-associated object or ferry. No object identity, ferry detection rate or SLAM TESTED status is claimed.

Thresholds checked in ooRexx: two source-indexed observations; min displacement 0.65 V5V cell; velocity 1.5–22 cells/sec; max observation gap 0.45 sec; N-range 2 cells plus uncertainty; radius cap 7 cells; area cap 289 cells. Every request has both source and target original frame numbers and timestamps, V5V cell box, source SHA and `OBSERVED_UNTESTED`. A null hit does not imply a submarine or cause a hallucinated track. All lines remain monitored to reacquire new movement.

**Qualification:** ooRexx 5.3.0 r13196. Native codec scanner and independent receipt auditor pass both full original clips. 7/7 controlled threshold tests pass, and **11/11 deliberately corrupted source/timing/authority/geometry/prediction cases are rejected independently on EACH video**. Source SHA-256 of each original MP4 was verified by the fail-closed qualification runner before publishing PASS receipts.

Manly original source SHA-256: `2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192`; earlier: `6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb`.

The complete runnable implementation and evidence are in the conversation artifact `tombstone_sydney_v5v_tripwire_follow_v0.24.zip` (SHA256 `f67fd2303d742c4278f1c92ced5820dbf9b5bb6e1a3415596ba9f98ed5af344e`). It includes the native C V5V line-band scanner, actual V5V packed streams, io metadata, configurable gates, water region evidence, ooRexx forecast + threshold classes, prediction and next-frame scoring, independent receipt verifier, fail-closed source-hash wrapper, synthetic threshold and corrupt-evidence tests, complete logs and manifest. Original MP4s, interpreter binaries and source-resolution lookups are not repackaged. **This commit is the qualification record; the runnable source is currently in the delivered ZIP rather than independently published in the repo.**

Next authority gates: exact user-line geometry, second-pass original-resolution crop requests on the new future prediction boxes, appearance match against source-bound taught positive/negative ferry examples, and canonical SLAM source/vision ingress runtime qualification. **No movement at the detection lines is automatically a vessel.**