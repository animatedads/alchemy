# ooRexx ML v0.1-dev10

Driveable, branchable machine-learning, evolutionary-search, Pareto-search and review/calibration objects for ooRexx.

The defining rule remains: **models, populations, optimizers, random streams, search lanes, Pareto fronts, review cases and calibration sessions are historical objects**. They can be checkpointed, rolled backward, rolled forward and forked without silently discarding the old future.


## New in dev10 — cylindrical temporal pattern hashing

`MLTemporalPatternHash.cls` takes the dev9 polar “pattern, not number” representation into three dimensions. Angle remains normalized event progress, radius remains normalized per-channel state, and **time becomes height above the pattern plane**. Adjacent events therefore produce true 3-D direction vectors with planar bearing and temporal elevation. The retained hash adds time gaps, bearing, elevation and 3-D turn evidence to radial shape.

Temporal invariance is explicit: start-time translation can be ignored, global duration can optionally be normalized, while local timing fluctuations remain visible. Multi-channel events are first-class and are not collapsed into one scalar; a market trajectory can retain PRICE, RELATIVE, FX and VOL channels with independent declared significance.

The first-class demo deliberately creates the “you did not realise you needed this” case:

```sh
rexx examples/cylindrical_market_pattern_demo.rex examples/cylindrical_market_pattern_demo.svg
```

Two almost identical nominal-price charts separate sharply when FX/relative/volatility behaviour is included, while a numerically unrelated but affine/time-scaled economic twin collapses to the same cylindrical temporal hash. See `docs/TEMPORAL_PATTERN_HASHING.md`.


## New in dev9 — polar pattern hashing / "pattern, not number"

`MLPatternHash.cls` adds a shape-recognition hash for sequences whose **relative curve** is more important than absolute value, amplitude, source sample count or phase origin.  The source minimum is the centre of a polar grid, the maximum is normalized to the outer radius, and the sequence is resampled around a fixed set of angles.  The hash retains radial shape plus first- and second-difference geometry.

Pattern distance is significance ordered: weighted local disagreements are sorted largest-first and compared lexicographically.  A major change of bend/turn therefore dominates any collection of tiny residual differences.  Optional rotation invariance removes the arbitrary starting index; reversal equivalence is explicit opt-in policy.

The visual demo is intentionally part of the feature rather than documentation decoration:

```sh
rexx examples/pattern_hash_polar_demo.rex examples/pattern_hash_polar_demo.svg
```

It shows a `0..10` curve and a `100..200` affine copy collapsing to the **same polar hash**, the same curve at double sample density also hashing identically, a small deformation remaining near, and a changed turning structure becoming visibly and numerically far. See `docs/PATTERN_HASHING.md`.


## New in dev8 — close-neighbour hashing / "good enough" search

`MLCloseNeighbour.cls` adds an ooRexx-native approximate-neighbour library aimed at the common case where a caller needs the closest useful candidates without paying for a complete corpus scan.  It is deliberately **not** a cryptographic hash and not merely collision-probability LSH.

The central rule is: **the most significant difference creates the greatest hash distance; smaller differences remain closer**.  Numeric features are quantised into ordered coordinates.  Per-dimension differences are weighted, sorted largest-first, then encoded as a mixed-radix significance distance.  One large discrepancy therefore cannot be hidden by many small agreements, while crossing a single quantisation boundary remains a one-bin change rather than a binary-carry discontinuity.

The layer includes:

- `MLCloseHashDimension`, with declared numeric domain, bin count, significance weight and explicit `FAIL`/`CLAMP` range policy;
- `MLCloseHashSchema`, `MLCloseHash` and `MLCloseHashDifference`;
- `MLCloseNeighbourIndex`, a driveable/rollback-capable bucket index;
- ordered multi-probe neighbouring-bucket search;
- `MLCloseNeighbourPolicy` for k/radius/candidate/probe budgets and hash-vs-exact reranking;
- optional exact Euclidean reranking over the bounded candidate set;
- `MLExactNeighbourIndex` as a brute-force reference oracle;
- `MLCloseNeighbourAssessment`, reporting recall@k and average corpus fraction examined;
- an 18-bit-like audio landmark regression showing exact-bucket lookup missing adjacent frequency bins while a one-shell probe finds them.

Probe budgets fail closed rather than silently truncating an arbitrary prefix of buckets.  Within an allowed probe radius, buckets are visited closest-first under the same significance metric.  Dataset sample ids must be unique, because candidate identity is evidence rather than a disposable array position.

See `docs/CLOSE_NEIGHBOUR_HASHING.md` and `examples/close_neighbour_hashing.rex`.


## New in dev7 — conventional technique breadth

`MLTechniques.cls` adds five pure-ooRexx reference techniques while preserving the existing driveable/history contract:

- `MLBinaryLogisticRegression` — two-class probabilistic classification with explicit positive-label semantics and L2 policy;
- `MLGaussianNaiveBayes` — per-class Gaussian likelihoods evaluated in log-score space;
- `MLDecisionTreeClassifier` — deterministic numeric threshold trees using weighted Gini impurity;
- `MLKMeans` — deterministic maximin-initialised clustering with retained assignments/inertia;
- `MLPrincipalComponentAnalysis` — covariance PCA using deterministic power iteration/deflation, with provenance-preserving transforms.

`MLTechniqueCatalogue` exposes this initial breadth by family. These are semantic/reference implementations: future native/NumPy/Torch acceleration may replace execution but must preserve model state, provenance, branch/replay semantics and declared numerical evidence.

## New in dev6 — hard feasibility before Pareto + Storage Fabric durability

`MLConstraints.cls` separates **hard feasibility** from optimization. A candidate that violates a hard constraint may remain available as search/evidence, but it cannot enter a Pareto front or be promoted merely because its objective vector is attractive.

New primitives include:

- `MLHardConstraint`, `MLConstraintSet`, `MLConstraintAssessment` and `MLConstraintResult`;
- `MLDirectoryFieldConstraint` and `MLSearchSpaceConstraint`;
- `MLConstrainedEvaluatorAdapter`, which evaluates hard constraints **before** expensive objective scoring and publishes no objective vector for an infeasible candidate;
- `MLConstrainedParetoResult` / `MLConstrainedParetoAnalyzer`;
- `MLConstrainedParetoGeneticAlgorithm`, with feasible-first selection, deterministic rollback/replay and complete final-generation evaluation;
- `MLConstrainedParetoRetentionSelector`, which can only promote feasible Pareto points.

Among infeasible candidates the GA may use violation-count ordering only as a search heuristic to find a path back into the feasible region. That ordering never turns an infeasible candidate into a Pareto answer.

### Recovered-audio Strategy P

The integration replacement is rebased onto the latest supplied `audio_rexx_search_v0.12-dev5` caller and adds a non-breaking Strategy `P`. It uses the dev5 recovered-audio objective vector plus explicit hard configuration/domain constraints and `MLConstrainedParetoGeneticAlgorithm`. Existing A/B/C/D/E meanings are left intact. Strategy P promotes only feasible non-dominated candidates and materializes only the bounded retained frontier.

### Storage Fabric dev7 integration

`integration/storage/MLStorageFabricBridge.cls` consumes Storage Fabric v0.1-dev7 instead of creating a private ML storage model. ML exports value-only `MLStorageCheckpointValue` and `MLDurableFrontierValue` identities; Storage Fabric remains authoritative for workspace placement, service lifecycle, replica safety, verification and durable completion. A verified copy on disposable/temporary capacity is therefore **not** durable completion.

The packaged `lib/StorageFabric.cls` is a byte-identical qualification snapshot of the supplied dev7 source, analogous to the existing Journal/Maths qualification snapshots; it is not an ML fork.

## New in dev5 — Pareto / multi-objective evolution

`MLMultiObjective.cls` adds first-class multi-objective search without forcing unlike concerns into one arbitrary scalar:

- `MLObjectiveSet` and `MLObjectiveVector` preserve each objective and its direction independently;
- dominance is explicit: `LEFT_DOMINATES`, `RIGHT_DOMINATES`, `EQUIVALENT` or `NON_DOMINATED`;
- `MLParetoAnalyzer` computes complete non-dominated fronts and crowding distance;
- `MLParetoRetentionSelector` fills bounded retention front-by-front while preserving diversity;
- `MLParetoSearchCandidate` carries configuration, vector evidence and material references;
- `MLParetoGeneticAlgorithm` uses deterministic rank/crowding tournament selection, crossover/mutation, elitism, State-of-the-Nation checkpoints and complete final-generation evaluation;
- `MLParetoEvolutionGeneration` ties every evaluated frontier to a branch and checkpoint;
- rollback/replay reproduces both offspring and RNG state exactly.

The design intentionally says **Pareto-ranked GA**, not full NSGA-II conformance. It uses non-dominated rank plus crowding and explicit elitism while keeping the simpler historical-object lifecycle established by ooRexx ML.

### Recovered-audio customer

`integration/audio/AudioParetoObjectives.cls` separates the current recovered-audio scalar into three visible concerns: recovered-reference distance, pre-limiter over-range fraction and post-limiter clipping. The earlier 18/40 artefact penalty weights therefore remain a calibratable scalar policy rather than being smuggled into the definition of audio quality. Human review can choose among non-dominated frontier candidates without altering their objective evidence.

See `docs/MULTI_OBJECTIVE_GA.md` and `examples/pareto_audio_frontier.rex`.

## Retained from dev4

### Human review is evidence, not an overwrite

`MLReview.cls` adds a generic review layer inspired by the POI/Shuttle and forensic-audio work:

- `MLReviewDecision`: immutable reviewer decision with reviewer reference, subject identity, confidence, rationale, evidence reference and policy identity;
- `MLReviewCase`: branchable review state with `PENDING`, `REVIEWED` and `RESOLVED` lifecycle;
- review decisions are append-only evidence inside the case history;
- `reopen()` clears the current resolution but **does not delete the earlier decision evidence**;
- rollback can return to the world before a review while retaining the reviewed future as a branch.

This keeps model output, human interpretation and policy action as separate objects.

### Pairwise perceptual/objective calibration

`MLPreferenceJudgement` and `MLObjectiveCalibrationSession` provide a direct way to test whether a numerical objective agrees with people reviewing the actual outputs.

For recovered audio this is deliberately pairwise: a listener can compare candidate A with candidate B and record `LEFT`, `RIGHT`, `TIE` or `UNDECIDABLE`. `MLObjectiveCalibration` then compares that preference with the ordering implied by the declared `MLObjective` and produces `MLObjectiveCalibrationReport` evidence:

- total judgments;
- comparable judgments;
- undecidable judgments;
- concordant/discordant judgments;
- objective-vs-human agreement rate;
- per-pair comparison evidence.

`MLObjectiveCalibrationQualification` applies explicit minimum comparison-count and agreement thresholds. The framework therefore **does not bless scoring weights merely because they look plausible**. In particular, the recovered-audio `18*pre_limiter_over + 40*post_limiter_clip` penalties remain an experimental objective until listening/calibration evidence supports them.

### Real recovered-audio Strategy C migration

`integration/audio/AudioSearchExperiment.rex` is a full replacement of the user-supplied native Rexx audio search caller, updated to the corrected dev3/dev4 GA contract:

- `MLGABudgetPlan~forCandidateLimit(...)` plans evaluated generations within the declared candidate budget;
- `MLGeneticPolicy` names the GA controls;
- `MLObjective` owns the `MINIMIZE` direction;
- `MLObjectiveFitnessAdapter` owns score-to-fitness sign conversion;
- the domain evaluator exposes `score()` rather than manually negating fitness;
- `MLGeneticAlgorithm~run(...)` evaluates the final bred population before returning.

The integration source remains Rexx-authoritative and compiles with `rexxc`; actual DSP execution still requires the separate `AudioSearchNative.cls` provider/runtime from the recovered-audio project.

### Search-space containment repair

Dogfooding the new search objects exposed an inversion bug in dev3 `MLSearchSpace~containsConfiguration`: a valid in-domain value could be rejected while an out-of-domain value could pass. dev4 corrects that predicate and adds a dedicated regression for valid, invalid and missing-parameter configurations.

## Existing GA/search foundation retained

- final bred populations are explicitly evaluated by `MLGeneticAlgorithm~run`;
- low-level `step()` still means evaluate-current + breed-next and marks the new population as unevaluated;
- deterministic journalled RNG and transactional generation rollback;
- named `MLGeneticPolicy`;
- bounded `MLGABudgetPlan`;
- `MLObjective` and objective-direction adapter;
- `MLWorkspaceBudget` and `MLRetentionPolicy`;
- explicit `MLParameterDomain` / `MLSearchSpace` / comparison;
- branchable `MLSearchLane` and coordinated `MLSearchExperiment`;
- immutable candidate/evaluation evidence.

## Existing conventional-ML foundation retained

- branchable `MLDriveableObject` and State-of-the-Nation `MLExperiment`;
- model + optimizer + training-session rollback/roll-forward;
- immutable learned generations and learning/source barriers;
- dataset/sample provenance, deterministic holdout and k-fold plans;
- validation evidence and non-destructive branch comparison;
- exact-capable linear/ridge regression, iterative linear gradient descent, centroid and k-NN classification;
- confusion matrix, MAE, RMSE, R², precision, recall and F1;
- Audio ML model/tensor interop seams.

## The historical-object pattern

The design intentionally follows the KL10/S370 style:

```text
checkpoint S0
     |
     +---- original future ---- S1 ---- S2
     |
     `---- alternative branch - S1' --- S2'
```

Training, evolution, reviewer decisions and calibration evidence all participate in the same history discipline. Rewinding is therefore an experimental operation, not destructive file replacement.

## Dependencies

Turnkey qualification snapshots remain under `lib/`:

- `JournalPointedState.cls` from `oorexx_journal_pointed_state_v0.1`;
- `Maths.cls` and `MathsBootstrap.cls` from ooRexx Maths v0.7.

The bundled files remain byte-identical to the supplied authoritative dependency packages. They are qualification snapshots, not forks.

## Qualification

Run:

```sh
./run_tests.sh
```

dev9 has **49 executable tests**. All 42 dev8 regressions remain green. The seven new pattern-hash regressions cover affine offset/amplitude invariance, sample-density invariance, significant-vs-small curve differences, rotation policy, reversal policy, polar angle/radius geometry, and driveable pattern-index rollback/roll-forward.

The polar demonstration is also executed during qualification and generates `examples/pattern_hash_polar_demo.svg`. Its canonical evidence shows the `0..10` base and `100..200` affine copy have identical hashes, doubled source sample density has an identical hash, a small deformation has dominant difference 20, and an altered turning structure has dominant difference 110 under the demonstration policy.

All constrained-Pareto, Storage, Audio, review, GA, search, training, validation, close-neighbour and conventional-ML behaviours remain green.

All **16 source/integration compile surfaces** compile with the supplied ooRexx 5.3.0 r13196 `rexxc`. Semantic Source Control v0.2.3 accepts dev9 as `OorexxML / MAIN / sourceLevel 10` with 13 packages / 726 methods / 291 attributes / 0 external candidates / 0 pending proposals.

## Wobbly fit diagnostics

Dev11 adds contextual fit-restoration analysis: find the smallest set of observations that must be reconsidered for an active model to fit, quantify distance-to-fit, compare wobble fraction with an empirical norm, and explicitly reassign valid evidence to alternate tracks/sources/models rather than deleting it. See `docs/WOBBLY_FIT.md` and `examples/wobbly_radar_demo.rex`.
