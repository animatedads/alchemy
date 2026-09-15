# ooRexx ML architecture — v0.1-dev6

## Constitution

1. A learned object has stable identity distinct from its current learned state.
2. Every meaningful state mutation is journalled.
3. Rewind never destroys a retained future.
4. A mutation after rewind creates another future from the same ancestor.
5. Coordinated learning state uses State-of-the-Nation checkpoints.
6. Stochastic replay is only reproducible when RNG state is part of the checkpoint.
7. Historical journal values are immutable values or replacement-style objects; mutable aliases are forbidden.
8. Published learned generations are immutable assessments of a particular model point.
9. Observation, feature, model output, assessment, claim and action are different semantic layers.
10. Numerical meaning belongs to ooRexx Maths; accelerators do not own precision or evidence semantics.
11. Foreign tensors/handles are runtime resources, not durable learned state.
12. Source-code identity and learned-state identity are separate timelines and may be rewound independently.
13. A training checkpoint is incomplete if it cannot reproduce continuation because optimizer/session/RNG state was omitted.
14. Dataset partitions are semantic evidence: train/test/fold membership and provenance must be recoverable.
15. Comparing branches must not silently change the live world being compared.

## Historical object model

`MLDriveableObject` composes `JournalPointedState` and exposes the journal participant contract. A named branch contains a retained journal-point head. When `rollback` moves the current branch backward, the previous branch head is named as a preserved future before the move. Subsequent mutation therefore creates a sibling child in the underlying journal tree.

`MLExperiment` wraps a `StateOfNationController`. It is the correct unit for learning procedures whose consistency spans several objects: a population + RNG, or a model + optimizer + training session. Experiment branches are checkpoint pointers covering all registered participants.

This follows the KL10/S370 recovery pattern: save enough state to continue, retain the old future, change one assumption/policy, then drive forward again.

## Training world

v0.1-dev2 formalizes a training world as three separable semantic objects:

```text
MLTrainingRun / MLExperiment
        |
        +-- model       (learned parameters / fitted state)
        +-- optimizer   (learning rate, momentum, velocity, step)
        +-- session     (epoch, step, objective, metrics, status)
```

A `MLTrainingRun` registers those participants into one State-of-the-Nation controller and creates an initial checkpoint only after registration. Rollback/roll-forward therefore restores a coherent world rather than only a model snapshot.

`MLGradientDescentOptimizer` is deliberately model-neutral. `MLLinearGDRegressor` is the first iterative consumer: each epoch updates model parameters through the optimizer and records the objective in the optional training session. The model, optimizer and session remain separate driveable objects, so State-of-the-Nation rollback restores the full trajectory rather than only the final coefficients.

`MLTrainingEvidence` materializes the semantic positions of the participating objects. It does not persist process-local handles.

## Dataset identity and provenance

`MLDataset` remains immutable at the public boundary. dev2 adds optional:

- dataset identity;
- source provenance and digest;
- feature names;
- stable sample identities.

`MLDatasetProvenance` separates the source/acquisition identity from derivation. A child subset records its parent dataset, transform and role (`TRAIN`, `TEST`, etc.).

`MLSplitter` produces explicit partition objects rather than transient array slices. When a deterministic journalled RNG is supplied, the split consumes and commits RNG state. Restoring the pre-split RNG point and executing the same split reproduces exactly the same membership.

The compatibility-generated anonymous dataset id is not evidence-grade identity. Evidence-grade callers supply a stable id and digest/provenance.

## Validation as evidence

`MLKFoldPlan` and `MLFold` are immutable plans. `MLCrossValidator` creates a new model per fold, trains it only on that fold's train dataset, evaluates the test subset, then stores a `MLFoldResult` containing:

- fold identity;
- model stable id and journal point;
- frozen learned-state snapshot;
- expected and predicted values;
- metric and metric value.

The aggregate is recorded in `MLValidationEvidence` rather than returned as a bare number.

This is deliberately compatible with later leakage barriers, model-selection evidence and distributed fold execution.

## Branch comparison

`MLBranchComparator` compares two retained named futures of one model against the same dataset. It uses retained journal points directly with controller notification disabled, evaluates each branch, and restores the original live journal point afterward. The caller's current branch and State-of-the-Nation controller position are therefore not silently changed by analysis.

A comparison result records both branch points, metric values and the preferred branch under an explicit minimize/maximize rule.

## Code versus learned state

Semantic Source Control and Journal Pointed State represent two deliberately different timelines:

- SSC: what implementation/revision of the program exists;
- ML journal: what learned/execution state an object has reached.

A historical learned generation can therefore say both “model state was at journal point P” and “the implementation lineage was source revision SR-X”. Rewinding learned state does not silently rewind code, just as KL/S370 live repair can restore machine state while retaining a repaired method implementation.

## Generation publication

`MLLearnedGenerationRegistry~publish` materialises a frozen map of a driveable object's current semantic state, journal point, branch, object identity and optional `MLSourceIdentity`. Later live mutations do not change that generation.

This is the generic form of the Camera Behaviour learned-generation rule.

## Learning barriers

A `MLLearningBarrier` says that evidence/state must not be assumed continuous across a source or domain transition. The barrier is checkpointed at experiment level. Domain-specific consumers decide which learned state must reset, which may carry forward, and what evidence justifies that choice.

Examples include camera source replacement, sensor calibration change, schema change, regime change, dataset provenance discontinuity or a materially different simulator world.

## Stochastic replay

`MLDeterministicRNG` stores only committed state and draw count. `MLRNGCursor` performs a local batch of draws; the final state is journalled once when the enclosing generation/split commits. This avoids creating one journal node per random number while preserving deterministic replay.

## Conventional ML

The exact-capable regression path uses ooRexx Maths rather than private matrix code. `MLLinearRegression` is the normal-equation reference baseline. `MLRidgeRegression` adds a diagonal regularizer while deliberately leaving the intercept unregularized. Later QR/SVD implementations can replace numerical strategy without changing the semantic model.

`MLKNNClassifier` and `MLCentroidClassifier` provide Python-free classification baselines. Metrics are first-class reusable calculations, with confusion-matrix evidence available separately from operational claims.

## Evolutionary ML

A GA generation is treated like a machine instruction/event:

1. checkpoint population + RNG before generation;
2. evaluate immutable genomes;
3. derive next population through an RNG cursor;
4. atomically commit RNG and population state;
5. checkpoint after generation;
6. publish immutable evaluation evidence.

If the same before-checkpoint is restored, the same code/policy and RNG state reproduce the same future. Changing policy after restore deliberately creates an alternate retained future.

## dev3: bounded search as historical execution

Search is now a first-class historical object system rather than an outer script convention.

`MLSearchExperiment` coordinates `MLSearchLane` objects through the same State-of-the-Nation mechanism used for model/optimizer/session worlds. A lane's mutable semantic state (status, cursor, requested evaluations, distinct-evaluation count and promotion count) can therefore be checkpointed, rolled back, forked and rolled forward while the lane's immutable objective/search-space/budget/strategy contracts remain stable.

Search strategy is deliberately separate from evaluation. The same evaluator may be driven by grid, random, genetic or later strategies. Execution placement remains outside search meaning.

### GA event boundary

A low-level `MLGeneticAlgorithm~step` means:

1. checkpoint population + RNG;
2. evaluate the current population;
3. derive the next population with deterministic RNG;
4. commit RNG + next population;
5. checkpoint;
6. publish evidence for the evaluated parent population.

The newly bred population is not falsely labelled evaluated. `MLGeneticAlgorithm~run` performs one or more such breeding events and then explicitly evaluates/publishes the final population. This distinction keeps the machine-event semantics honest while making complete search runs safe by default.

### Budget versus retention

Candidate evaluation budget, workspace byte budget and retained-output count are orthogonal:

- candidate/evaluation budget controls search effort;
- workspace budget controls temporary execution footprint and launch reserve;
- retention policy controls which results are promoted/materialized.

A large search therefore need not create a large durable material footprint.

### Search-space evidence

A search result is only comparable to another search result when the parameter domains are understood. `MLSearchSpaceComparison` makes equivalence/subset/difference explicit. A deliberately narrower GA domain is valid, but it must not be described as the same experimental space as a wider grid.

## dev4: human evidence and objective calibration

ML does not collapse observation, score, assessment, human interpretation and action into one fact. dev4 adds an explicit review/calibration layer:

```text
Candidate / Model Output
        |
        +------ numerical MLObjective score --------+
        |                                           |
        `------ material presented to reviewer      |
                                                    v
                                          MLPreferenceJudgement
                                                    |
                         +--------------------------+
                         v
                              MLObjectiveCalibrationReport
                         objective ordering vs human ordering
                                                    |
                                                    v
                                   Calibration Qualification
```

The preferred calibration primitive is pairwise comparison rather than asking a reviewer to invent a precise absolute score. `UNDECIDABLE` is first-class and excluded from the agreement denominator rather than being forced into a false preference.

Review state is historical. A case may be resolved, rewound to before the decision, branched under another reviewer/policy, and both futures retained. Reopening a case does not erase prior decisions.

This follows the same doctrine as Camera Behaviour and Project Shuffle: AI/ML output is evidence or advisory classification; policy and reviewed claims are separate objects.

## dev5: Pareto worlds

A scalar objective remains useful when its tradeoffs are intentional and calibrated. It is not the only search model. When objectives are meaningfully independent, dev5 preserves them in an `MLObjectiveSet` and evaluates candidates into `MLObjectiveVector` evidence.

`MLParetoAnalyzer` assigns non-dominated fronts. Rank 1 means no evaluated candidate is known to be strictly no-worse on every objective and better on at least one. Crowding distance is retained as diversity evidence inside a front; it is not a replacement objective.

`MLParetoGeneticAlgorithm` applies the same historical execution doctrine as the scalar GA: coordinated checkpoints, deterministic RNG, transactional rollback, retained futures and explicit final-generation evaluation. Selection prefers lower Pareto rank, then higher crowding distance. No weighted sum is invented by the framework.

The recovered-audio adapter demonstrates the intended boundary. Reference resemblance and clipping/over-range evidence are kept separate. Human review may choose a frontier tradeoff; that review is a new historical evidence object, not a retroactive change to the measured objective vector.


## dev6: feasibility is not an objective

Hard constraints are evaluated before Pareto ranking. They cover requirements that must not be traded away for quality, cost or performance: source/schema validity, legal/security/runtime eligibility supplied by authoritative components, declared search-space membership, workspace feasibility and domain invariants.

```text
Candidate
   |
   v
Hard Constraint Set
   |
   +-- infeasible --> retained violation evidence / search heuristic only
   |                 never Pareto-ranked, never promoted
   |
   `-- feasible ----> objective evaluation --> Pareto fronts --> bounded retention
```

`MLConstrainedEvaluatorAdapter` deliberately checks the constraint subject before invoking `scores()`. This permits fail-closed rejection before expensive DSP/training/inference work. Infeasible evaluations publish no objective vector, preventing accidental downstream ranking.

`MLConstrainedParetoGeneticAlgorithm` preserves the historical-machine lifecycle. Feasible records always outrank infeasible records for selection. If a generation contains no feasible candidate, violation count may order infeasible records only to guide breeding toward feasibility. That search heuristic never confers Pareto or promotion status.

### Storage boundary

ML does not claim that a checkpoint is durable merely because it was serialized or copied. `MLStorageCheckpointValue` and `MLDurableFrontierValue` are value-only identities suitable for transport/storage. `MLStorageFabricBridge` delegates placement and durable-completion decisions to Storage Fabric v0.1-dev7.

A disposable or non-stable workspace may be excellent execution capacity. It is not a durable replica. When Storage Fabric reports mandatory output commit bytes, ML completion must remain pending until the required safe/stable verified replica exists.

This is the same authority discipline used elsewhere in the ooRexx ecosystem: ML owns model/search semantics; Storage Fabric owns storage safety; Job-to-Node Allocation owns hard node eligibility.


## Conventional technique layer (dev7)

`MLTechniques.cls` broadens the reference catalogue without creating a second object model. Logistic regression, Gaussian Naive Bayes, decision trees, k-means and PCA are all driveable objects and therefore inherit the same checkpoint/rollback/branch semantics as the earlier regression and GA objects. Unsupervised transforms consume `MLDataset` so sample identity and provenance survive feature-space changes. Pure ooRexx remains the semantic/reference path; acceleration belongs behind an observationally-equivalent provider seam.


## Close-neighbour hashing layer (dev8)

Approximate neighbour lookup is a semantic ML facility rather than an audio-only optimisation. `MLCloseHashSchema` maps ordered numeric features into quantised coordinates. Hash distance is significance-preserving: weighted coordinate differences are sorted largest-first and encoded in a mixed-radix score, making the dominant discrepancy authoritative over finer differences.

`MLCloseNeighbourIndex` is itself driveable historical state. Multi-probe lookup enumerates neighbouring cells, orders them by the same significance metric, and can rerank the resulting bounded candidate set with exact Euclidean distance. `MLExactNeighbourIndex` is retained as an oracle, and `MLCloseNeighbourAssessment` reports recall@k and candidate fraction so "good enough" can be qualified rather than asserted.

The design deliberately avoids ordinary binary packed-hash subtraction: adjacent numeric cells must remain adjacent even when a conventional binary representation would cross a carry boundary.

## dev9 pattern identity layer

Pattern hashing is deliberately separate from scalar neighbour hashing. `MLCloseNeighbour` says which numeric coordinates are near; `MLPatternHash` says which **curves have the same relative geometry** after declared invariances. The canonical reference representation is a circular polar grid with source minimum at the centre, normalized radius, fixed angular resampling, and significance-ordered radius/slope/curvature differences. Pattern indexes remain driveable historical objects.

## Cylindrical temporal pattern identity (dev10)

Pattern identity can include time without collapsing time into sample index. A temporal pattern maps event progress to angle, per-channel normalized state to radius, and event time to cylinder height. Adjacent events create 3-D direction vectors with bearing/elevation/turn evidence. The cylinder is circular in its pattern plane but open in time; no synthetic last-to-first temporal segment is created.

Multi-channel temporal state remains vector-valued. Domain policy may assign significance to channels, but the implementation does not pre-scalarize PRICE/FX/relative/volatility or analogous domain variables. Significance-ordered difference retains the dominant discrepancy kind/channel as evidence.
