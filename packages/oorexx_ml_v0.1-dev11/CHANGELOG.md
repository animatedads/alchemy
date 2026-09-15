## v0.1-dev11

- Adds contextual wobbly-fit diagnostics: minimal restoring sets, distance-to-fit, normative wobbliness, participation, and explicit reassignment evidence.

# ooRexx ML changelog

## v0.1-dev10

- Added `MLTemporalPatternHash.cls`: cylindrical temporal pattern hashing with angle=event progress, radius=normalized channel state and height=time.
- Added explicit 3-D segment bearing, elevation and turn-angle evidence.
- Added time-shift, time-scale and absolute-time policy; contradictory scale-without-shift policy fails closed.
- Added vector-valued temporal series with stable named channels and explicit per-channel significance weights.
- Added significance-ordered temporal difference with dominant kind/channel evidence.
- Added driveable `MLTemporalPatternIndex` and corpus/query/match objects.
- Added seven regressions covering global timing invariance, local timing fluctuation, sample-density invariance, vector geometry, multichannel market state, time-origin policy and historical index branching.
- Added the self-generating cylindrical market demonstration.

## v0.1-dev9

- Added `MLPatternHash.cls`: polar, curve-relative pattern hashing for recognition where shape matters more than absolute index or amplitude.
- Source minimum becomes the polar centre, source maximum the normalized outer radius, and variable sample counts are resampled onto a fixed angular grid.
- Added explicit rotation and reversal invariance policy; reversal remains opt-in.
- Pattern identity retains quantized radius, first circular difference (slope) and second circular difference (curvature).
- Added significance-ordered pattern distance: weighted local disagreements are sorted largest-first and compared lexicographically so the largest structural difference dominates collections of smaller ones.
- Added `MLPatternCorpus`, exact-pattern buckets, `MLPatternIndex` nearest-pattern retrieval, and driveable index rollback/roll-forward.
- Added a first-class polar demo that proves offset/amplitude changes and doubled sample density hash identically while a changed turning structure moves far away.
- Added generated SVG visualization with centre=min, radius=normalized value, and angle=normalized curve progress.
- Added pattern hashing to `MLTechniqueCatalogue`.

## v0.1-dev8

- Added `MLCloseNeighbour.cls`, a significance-preserving approximate-neighbour library.
- Added ordered numeric hash dimensions with explicit domain, quantisation bins, per-dimension importance and fail-closed/clamp range policy.
- Added dominant-difference hash distance: weighted per-dimension bin differences are ordered largest-first and packed in mixed-radix form, so the largest discrepancy dominates all finer differences.
- Added `MLCloseNeighbourIndex` as a driveable historical index with rollback/roll-forward support.
- Added deterministic neighbouring-bucket multi-probe lookup, closest-first probe ordering, bounded candidate sets and fail-closed probe-bucket budgets.
- Added `MLCloseNeighbourPolicy`, optional exact Euclidean reranking, `MLExactNeighbourIndex`, and `MLCloseNeighbourAssessment` with recall@k / candidate-fraction evidence.
- Added duplicate-sample-id rejection so index candidate identity cannot silently collapse.
- Added an audio-landmark regression modelling a 6+6+6 bit temporal/frequency bucket space: exact bucket lookup misses adjacent landmarks; radius-1 multi-probe recovers them.
- Added boundary regression proving adjacent cells around a binary carry remain close.
- Added close-neighbour hashing to `MLTechniqueCatalogue`.
- Expanded suite from 34 to 42 tests; all pass under ooRexx 5.3.0 r13196.


## v0.1-dev7

- Added `MLTechniques.cls` with five pure-ooRexx reference techniques: binary logistic regression, Gaussian Naive Bayes, Gini decision-tree classification, deterministic k-means and PCA.
- All new estimator/transform objects subclass `MLDriveableObject`, so fitted state participates in existing rollback/roll-forward/branch semantics.
- Logistic regression exposes explicit positive-label semantics rather than silently assigning probability meaning from label sort order.
- Decision-tree policy is branchable state; learned tree nodes are immutable and canonically representable.
- k-means uses deterministic maximin initialisation, avoiding hidden RNG state while retaining assignments, inertia and convergence evidence.
- PCA preserves dataset sample ids and emits derived provenance with transform `PCA`.
- Added `MLTechniqueCatalogue`, `docs/TECHNIQUES.md`, a catalogue example and six new executable regressions.
- Expanded suite from 28 to 34 tests; all pass under ooRexx 5.3.0 r13196.
- Semantic Source Control v0.2.3 accepted `OorexxML / MAIN / sourceLevel 8` with 11 packages / 537 methods / 291 attributes / 0 external candidates / 0 pending proposals.

## v0.1-dev6

- Added `MLConstraints.cls`: hard constraints, constraint sets/results/assessments, fail-closed directory/search-space constraints and constrained evaluation adapter.
- Added constrained Pareto analysis/retention so infeasible candidates remain evidence but cannot enter a Pareto front or promotion set.
- Added `MLConstrainedParetoGeneticAlgorithm` with feasible-first selection, transactional checkpoints, deterministic RNG and explicit final-generation evaluation.
- Added rollback/replay regression for constrained Pareto evolution.
- Added optional Storage Fabric v0.1-dev7 bridge with value-only checkpoint/frontier exports, storage placement evidence and durable-completion evidence.
- Added byte-identical Storage Fabric dev7 qualification snapshot under `lib/StorageFabric.cls`.
- Rebased the recovered-audio integration replacement onto supplied `audio_rexx_search_v0.12-dev5` and added non-breaking Strategy P for constrained Pareto search; existing A/B/C/D/E semantics remain unchanged.
- Expanded suite to 28 executable tests; all pass under ooRexx 5.3.0 r13196.
- All ML and integration sources compile with `rexxc`.

## v0.1-dev5

- Added `MLMultiObjective.cls` with `MLObjectiveSet`, `MLObjectiveVector`, Pareto dominance relations, complete non-dominated front analysis and crowding-distance evidence.
- Added `MLParetoRetentionSelector` so bounded material retention proceeds front-by-front without inventing a scalar ranking.
- Added `MLParetoGeneticAlgorithm`, `MLParetoEvolutionGeneration` and `MLParetoGARunResult`; every generation is transactionally checkpointed and the final bred population is explicitly evaluated before a complete run returns.
- Pareto GA selection uses deterministic non-dominated rank + crowding tournaments, existing named `MLGeneticPolicy`, elitism and the journalled RNG; rollback/replay reproduces offspring and RNG state.
- Added `MLParetoSearchCandidate` and `MLParetoSearchAnalysis` for non-GA search results.
- Added recovered-audio `AudioParetoObjectives.cls`, splitting reference distance, pre-limiter over-range and post-limiter clipping into independent objectives rather than hard-wiring the experimental 18/40 penalties.
- Added a synthetic recovered-audio Pareto frontier example and five new executable regressions.
- Suite expands to 23 executable tests; all pass under ooRexx 5.3.0 r13196.
- All nine ML source classes plus the Audio Pareto integration adapter compile with `rexxc`.
- Dogfooded Semantic Source Control v0.2.3 and accepted dev5 as `OorexxML / MAIN / sourceLevel 6` (9 packages / 407 methods / 248 attributes / 0 external candidates / 0 pending proposals).

## v0.1-dev4

- Added `MLReview.cls` with immutable reviewer decisions, branchable review cases, explicit resolution/reopen lifecycle, and retained historical decision evidence.
- Added pairwise `MLPreferenceJudgement`, `MLObjectiveCalibrationSession`, calibration reports and qualification thresholds for comparing numerical objectives against human/perceptual review.
- Kept the recovered-audio 18/40 artefact penalty weights explicitly experimental until calibration evidence supports them.
- Added the full user-supplied recovered-audio `AudioSearchExperiment.rex` integration replacement using `MLGABudgetPlan`, named `MLGeneticPolicy`, `MLObjectiveFitnessAdapter` and `MLGeneticAlgorithm~run`, so the final bred generation is scored and lower-is-better sign handling is owned by ML Core.
- Corrected `MLSearchSpace~containsConfiguration` predicate inversion and added a dedicated regression for valid, out-of-domain and missing-parameter cases.
- Expanded suite from 16 to 18 executable tests; all pass under ooRexx 5.3.0 r13196.
- All eight ML source classes plus the audio integration replacement compile with `rexxc`.
- Dogfooded Semantic Source Control v0.2.3 and accepted dev4 as `OorexxML / MAIN / sourceLevel 5` (8 packages / 344 methods / 221 attributes / 0 external candidates / 0 pending proposals).

## v0.1-dev3

- Corrected complete-GA-run semantics: `MLGeneticAlgorithm~run` now evaluates and publishes the final bred population before returning; low-level `step` explicitly reports that its new population is not yet evaluated.
- Added `MLGARunResult` and `MLGeneticAlgorithm~evaluateCurrent`.
- Added named `MLGeneticPolicy` and `MLGeneticAlgorithm~fromPolicy` while retaining the compatible positional constructor.
- Added `MLGABudgetPlan` so a candidate budget is planned in evaluated populations and defaults to at least three evaluated generations.
- Added first-class search architecture in `MLSearch.cls`: objectives and score-to-fitness adapter, workspace budgets, retention policies, parameter domains/search spaces, search-space comparison, strategy specs, candidates, branchable search lanes, coordinated search experiments and qualification reports.
- Added a synthetic recovered-audio-style bounded GA example.
- Added regressions for final-offspring scoring, low-budget GA planning, objective direction, search-space comparability, 7 GiB workspace + reserve preflight and search-lane rollback/roll-forward.
- Requalified all dev2 behaviours unchanged.
- Dogfooded Semantic Source Control v0.2.3: dev3 source scans as 7 packages / 316 methods / 191 attributes / 0 external candidates / 0 pending proposals and is accepted as `OorexxML / MAIN / sourceLevel 4`.

## v0.1-dev2

- Added journalled gradient-descent optimizer state and `MLTrainingSession` / `MLTrainingRun` State-of-the-Nation coordination.
- Added `MLLinearGDRegressor` as the first iterative estimator using explicit optimizer/session state.
- Added dataset identity, provenance, stable sample ids and immutable subset derivation.
- Added reproducible holdout and k-fold plans, including deterministic journalled RNG shuffle state.
- Added validation evidence with per-fold frozen model state.
- Added non-destructive retained-branch comparison.
- Added ridge regression, k-NN, confusion matrix, MAE/RMSE/R², precision/recall/F1.
- Dogfooded Semantic Source Control v0.2.3 and accepted `OorexxML / MAIN / sourceLevel 3` with no pending external-operation proposals.

## v0.1-dev1

- Established driveable branchable ML objects, State-of-the-Nation experiments, learned generations, barriers, deterministic RNG, reference GA, exact linear regression, centroid classification and Audio ML interop contracts.
