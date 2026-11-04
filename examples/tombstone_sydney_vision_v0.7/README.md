# Tombstone Sydney vision evidence v0.7 — a real ooRexx classifier boundary

**Status:** local qualification PASS, not a claim of SLAM engine vision integration. Architecture: user. Image sources: user-supplied Sydney webcam photographs and mobile recording, 31 October 2026.

## Result (reproducible)

- 48 manually annotated screenshots objects, of which **16 traditional yellow/green ferry positive**, **15 confirmed negative** (sailboats, cruise ship, powered yachts), **17 REVIEW** (small yellow/red-white passenger vessels etc.) excluded.
- Leave-one-SOURCE-FRAME-out ooRexx visual-evidence scoring: **15 TP / 1 FN / 0 FP / 14 TN / 0 positive abstentions / 1 negative abstention**. The false negative is **P16**, a small nearly end-on yellow/green ferry. Different frames can contain the same physical ferry, so these are **correlated**; do not claim generalization accuracy or 100% recognition.
- Independent user-recorded Manly ferry recording: **6/6 manually-seeded video crops** receive a positive score. This is a single vessel and one continuous recording, not six independent examples; no video-specific negative vessel count.
- Crops are scored using numeric colour evidence computed by OpenCV from actual JPEG/video pixels; **ooRexx** performs train-frame exclusion, threshold construction, classification, abstention and metrics. The pixel extraction is NOT ooRexx and should eventually be replaced by the platform's CV provider.
- `score_support` is a heuristic feature-support ratio mapped into [0,1], **not** calibrated probability, not the `SlamStore`/SLAM tested graph-edge score and not proof.
- Synthetic four-point water-plane homography tested in **ooRexx**, with 3 unseen holdouts and worst residual approximately 2e-17 in synthetic coordinates. Real geographic calibration is **NOT_AVAILABLE**; do not use this H as the webcam calibration or warp a 3D ship's superstructure as if it were water.
- Native runtime ooRexx 5.3.0 r13196: scorer and synthetic homography PASS; **9/9** qualification controls correct, including seven reject cases.

## Data and provenance

`features.psv` and `video_features.psv` are portable numeric feature evidence. `provenance.json` records the source SHA-256s and mask-derived video crop coordinates. `samples/` carries six small extracted reference crops. User original images and ~83MB video are not republished automatically; they exist in prior local v0.3/v0.6 corpus archives. `predictions_v07.psv` records all decisions. `qualification.json` records actual processes and exit codes.

## Scoring contract

For each source-frame holdout, among positives in other frames find minimum yellow-pixel fraction Y and minimum dark-pixel fraction D, then require yellow >= 0.75Y and dark >= 0.65D. Score ratio = min(yellow/(0.75Y), dark/(0.65D)); classify ferry if >1.1, not-ferry if <0.9, otherwise abstain. Both ratios use measured pixel proportions, not absolute bounding box size. Tests were constructed after reviewing this corpus; the small held-out-frame set is an engineering smoke test, not an unbiased blind trial. It recognises traditional yellow/green ferries only.

The image reader uses HSV cutoffs H[8,38], saturation>60 and value>65 for yellow, and value<90 for dark, with fixed colour-space convention from OpenCV 8-bit HSV. No label is passed to feature computation except as evaluation metadata. Related high-saturation coloured vessels and artificial framing can confuse it; REVIEW cases must remain unscored.

## Reproduce

From this directory:

```sh
python extract_features.py      # requires actual source images/video at documented paths
./run_native.sh                # ooRexx 5.3 runtime
LD_LIBRARY_PATH=/mnt/data/oorexx_runtime/usr/local/lib /mnt/data/oorexx_runtime/usr/local/bin/rexx calibrate_water_plane.rex control_synthetic.psv holdout_synthetic.psv
python qualification.py       # 9 positive/rejection controls
```

`score_vision.rex` works directly from PSV evidence with no Python at scoring time. The synthetic homography controls are not for Sydney; a metric water-plane transformation requires known camera-plane correspondences and independently held-out surveyed points. Until then, raw-vs-water-plane-warp comparisons are **NOT_RUN**, and neither geographic velocity nor range is claimed.

## SLAM handoff

SLAM currently ingests code structure and tested evidence; no linked native vision scorer has been qualified. The correct future adapter is: source image SHA -> verified pixel evidence -> type-bound vessel candidate -> hypothesis support -> test observation + provenance -> SLAM graph ingest, with class uncertainty retained. Do not convert colour support into a SLAM TESTED edge or claim full ferry detection without its admission/provenance gates.
