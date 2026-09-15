# Wobbly fit and distance-to-fit

A **wobbly** observation is not defined as false, noisy, unlikely, or anomalous. It is an observation whose temporary exclusion improves the fit of the **active model**. The same observation may be highly relevant to another model.

The diagnostic contract is therefore:

1. fit all observations;
2. search exclusion sets in increasing cardinality;
3. stop at the first cardinality for which fit is restored;
4. retain every restoring set at that minimal cardinality;
5. report distance-to-fit and normalized distance;
6. calculate participation across alternative minimal restoring sets;
7. compare observed wobble fraction with a declared normative distribution;
8. reassign excluded evidence explicitly (alternate track/source/model, normative clutter, measurement error, unresolved, etc.).

Exclusion is diagnostic, never deletion authority.

## Distance to fit

For observations `D`, fit criterion `C`, and exclusion set `S`, distance-to-fit is the minimum `|S|` such that `C(fit(D-S))` is satisfied. The current exact reference search is bounded by `maxRemovals` and `maxEvaluations`; exceeding the evaluation budget fails closed rather than silently becoming approximate.

## Normative wobbliness

`MLWobbleNorm` retains an empirical distribution of historical wobble fractions and reports mean, median, p95, percentile and a coarse normative classification. This distinguishes ordinary clutter/noise behaviour from a material change in the observation process.

## Reassignment

`MLWobbleReassignment` records a later semantic decision. An observation may be reassigned to another track/source/model or retained as unresolved. A restoring set is not itself evidence that the observations are wrong.

## Reference demo

`examples/wobbly_radar_demo.rex` mixes two exact linear radar tracks. Three Track-B returns make the full Track-A fit fail. The minimal distance-to-fit is three; removing those observations restores Track A exactly, and the same three observations fit Track B exactly. The demo therefore proves contextual wobbliness and explicit reassignment rather than outlier deletion.
