# Tombstone Sydney Vision v0.8 — evidence boundary

Architecture: Tom Dyer. Additive CV experiment. ooRexx code + native qualification by ChatGPT GPT-6, 31 October 2026. **Not a change to SLAM core, and not yet a SLAM visual-recognition run.**

## Results and independently verified data

The existing narrow colour scorer remains unchanged in classification behaviour: reference frame-held-out **TP 15, FN 1 (end-on P16), FP 0, TN 14, negative abstentions 1**; 17 review cases excluded; six seeded Manly-video crops score positive. These are correlated views, not independent ferries. Its decision statistic is a colour-support indicator, **not** a probability, a SLAM tested graph-edge score, or proof of identity.

A reproducibility error was found: v0.7 `predictions_v07.psv` has two identical 38-line blocks due to **append on repeated runs**. The v0.8 scorer uses `stream predictions,'c','open write replace'` and produces exactly 38 lines on each repeated run, with original classification totals unchanged. The strict adapter rejects the duplicated historical file.

`vision_evidence_adapter.rex` takes the v0.7 reference and video features, the newly scored `predictions_v08.psv`, and the pinned original-file hashes `sources.sha256.psv`. It validates **all** input rows before writing any evidence and replaces its own output on successful replay (55 lines on each run). It yields **54 OBSERVED_UNTESTED observations: 37 scored, 17 REVIEW_ONLY**, with crop hash, source hash, fold/correlation label, class hypothesis and explicit `UNSURVEYED_WATER_PLANE`. No evaluation truth labels are exported to the runtime evidence. The adapter does not mutate any SLAM state.

Native ooRexx 5.3.0 r13196: **17/17 adapter qualification controls PASS**, consisting of one positive test, one repeated-output idempotence test and 15 deliberate corruptions rejected without an output file (including duplicate historical prediction, review-score promotion, forged support, wrong fold, altered numeric features, invalid hashes and video identity). Independently verified **17/17 uploaded original-source SHA-256 hashes** and **54/54 pixel-derived crop PNG hashes**. Image processing that extracts HSV features remains in OpenCV; the scorer, strict evidence adapter and the test decisions are native ooRexx. The Python qualification driver invokes the native interpreter and checks source hashes; it is not an image recogniser.

## Run

From this v0.8 directory, with ooRexx libraries on `LD_LIBRARY_PATH`, and the v0.7 `features.psv`/`video_features.psv` copied here or referenced by relative path:

```sh
rexx score_vision.rex ../tombstone_sydney_vision_v0.7/features.psv ../tombstone_sydney_vision_v0.7/video_features.psv
rexx vision_evidence_adapter.rex ../tombstone_sydney_vision_v0.7/features.psv ../tombstone_sydney_vision_v0.7/video_features.psv predictions_v08.psv sources.sha256.psv vision_observations_v08.psv
```

The adapter will refuse malformed, missing, duplicate or conflicting evidence with exit code 2. The original uploaded photos and video are required to *independently* recheck the source hashes; the numeric fixture alone cannot demonstrate pixel origin. The complete local v0.8 archive includes the reference features, native test driver, original duplicate-file regression fixture, observation output, logs and six small video crops. The PR branch carries the source code and pinned original-file digests.

## Boundaries and next gate

- No SLAM Store ingestion or promotion to `TESTED` has occurred. The observation schema awaits SLAM source-owner review; do not merge the adapter into SLAM core without acceptance.
- Fixed-camera harbour geometry has **no surveyed four-point water-plane solution**. Synthetic homography arithmetic was qualified in v0.7; no real metres/pixel, vessel distance, real-world speed or raw-vs-geometry-normalised score comparison is claimed.
- Ferry and image viewpoint correlation must remain explicit. The known end-on P16 miss and ambiguous low-profile passenger craft stay unresolved.
- Autobuilder is offline; Git source publication is not deployment.

Repo: `animatedads/alchemy`. Review: PR #106. Rasen Falcon lane: `tombstone-vision`.
