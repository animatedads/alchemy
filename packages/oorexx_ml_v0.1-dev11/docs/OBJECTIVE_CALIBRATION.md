# Objective calibration and human review

A weighted objective is an engineering hypothesis until evidence shows that its ordering corresponds to the quality humans actually care about.

For recovered audio, the current native search objective includes:

```text
0.35 * global_distance
+ 0.40 * window_median_distance
+ 0.10 * window_p25_distance
+ 0.15 * temporal_distance
+ 18 * pre_limiter_over_fraction
+ 40 * post_limiter_clip_fraction
+ low-silence penalty
```

The `18` and `40` penalty weights are not promoted here as universal truths. dev4 records the formula through `MLObjective`, then permits blind or controlled pairwise listening evidence through `MLPreferenceJudgement`.

Recommended procedure:

1. Select candidate pairs spanning close scores, large score differences and known artefact conditions.
2. Present output material without exposing the numerical score when a blind comparison is desired.
3. Record `LEFT`, `RIGHT`, `TIE` or `UNDECIDABLE`, reviewer reference, confidence, rationale and an evidence/material reference.
4. Build `MLObjectiveCalibrationReport`.
5. Apply an explicit policy threshold for minimum comparable pairs and minimum agreement.
6. If agreement is weak, branch the scoring policy, alter weights or features, and replay the same review evidence against the alternative objective rather than rewriting history.

The framework currently measures agreement; automatic fitting of objective weights is intentionally deferred. Weight fitting should itself become a branchable search/training problem with held-out review evidence so that calibration does not simply overfit the listeners used to create it.
