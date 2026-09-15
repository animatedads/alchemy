# ooRexx ML roadmap

## v0.1 line — historical learning and search substrate

Implemented through dev3:

- branchable driveable objects and State-of-the-Nation experiments;
- source identity, barriers, learned generations and advisory assessments;
- deterministic RNG and replayable GA;
- complete GA run semantics with final bred population evaluation;
- named GA policy and candidate-budget planning in evaluated generations;
- first-class search objectives, workspace/retention budgets, parameter spaces and comparability;
- branchable search lanes and coordinated search experiments;
- search qualification/preflight evidence;
- exact-capable linear regression, ridge regression, centroid and k-NN classification;
- scaler and richer regression/classification metrics;
- explicit dataset identity/provenance/sample identity;
- reproducible holdout and k-fold plans, including journalled RNG shuffle state;
- validation evidence with per-fold frozen learned state;
- branch comparison without destructive checkout;
- journalled gradient-descent optimizer state;
- Python-free iterative gradient linear regression using that optimizer/session contract;
- coordinated model + optimizer + training-session rollback/roll-forward;
- Audio model/tensor compatibility seam;
- Semantic Source Control dogfooding.

Near-term v0.1 increments:

- generic candidate cache/dedup evidence and canonical configuration normalization contracts;
- explicit search-result ranking/promotion objects across lanes;
- human perceptual/reviewer evidence so numerical objectives can be calibrated rather than merely asserted;
- logistic regression and Gaussian Naive Bayes; **implemented dev7**
- explicit train/validation/test leakage and domain barriers;
- ROC/AUC and multiclass macro/micro metrics;
- model-selection/ranking objects across validation evidence;
- human label/review queue objects inherited from the video/POI review discipline;
- durable generation/checkpoint/search evidence export/import through Storage Fabric.

## v0.2 — pipelines and stronger conventional ML

- decision trees; **implemented dev7**
- random forests and boosted tree ensembles;
- PCA; **implemented dev7**
- feature selection;
- QR/SVD-backed regression and condition diagnostics;
- missing-value and categorical transforms;
- pipeline DAGs derived from Layered Audio processing graphs;
- model cards/evidence manifests;
- explicit data-domain and leakage barriers;
- learning-curve and early-stopping policy objects.

## v0.3 — evolutionary toolkit

- configurable tournament/roulette/rank selection strategies;
- multiple crossover/mutation operators;
- constrained and conditional genomes;
- first-class genotype -> normalized phenotype mapping and phenotype-key deduplication;
- multi-objective/Pareto fitness;
- island models and migration;
- branch-aware population lineage and ancestry queries;
- distributed fitness evaluation through Queue Fabric / Job-to-Node Allocation.

## v0.4+ — accelerated learning

- common tensor/material ownership moved upward from Layered Audio;
- Foreign Runtime NumPy/Torch execution providers;
- DLPack/native tensor interoperability;
- CPU/GPU placement and precision policy;
- checkpointable optimizer/model/search state suitable for remote execution;
- model/search persistence through Storage Fabric;
- optional neural-network layer while keeping ooRexx semantic ownership.

## Permanent rule

The toolkit remains useful without Python. Python/NumPy/Torch may accelerate or extend execution, but ooRexx objects own model identity, history, policy, provenance, evidence, search-space meaning and branch semantics.

## After dev4

- Fit/compare alternative weighted objectives using branchable calibration sessions, but evaluate fitted weights on held-out reviewer evidence rather than the evidence used to fit them.
- Add active-review selection (uncertain/disagreeing candidates first) without allowing the model to rewrite human evidence.
- Add logistic regression and Naive Bayes to the conventional estimator catalogue.
- Make model/generation/search/review checkpoints durable through Storage Fabric.
- Make GA fitness, validation folds and search lanes dispatchable through Queue Fabric / Job-to-Node Allocation while keeping execution placement out of semantic identity.
- Add Pareto/multi-objective evolutionary selection for cases where intelligibility, artefact level, runtime and retention cost should not be collapsed prematurely into one weighted scalar.

## After dev5

- durable Pareto generation/frontier checkpoints through Storage Fabric;
- Queue Fabric / Job-to-Node distribution of objective evaluation while preserving value-only frontier evidence;
- explicit constraint objects separate from objectives (hard feasibility must not be traded away by Pareto dominance);
- model-selection populations combining conventional ML estimators and evolutionary search;
- optional Pareto archive across generations/branches, distinct from per-generation fronts;
- human-review scheduling over frontier pairs and calibration of any later scalarization policy.


## After dev6

- Move hard security/legal/runtime node eligibility to direct Job-to-Node Allocation evidence adapters rather than duplicating those predicates in ML.
- Make `MLDurableFrontierValue` and checkpoint values first-class Storage Fabric objects with explicit content digests and transfer receipts.
- Distribute fold/fitness/candidate evaluation through Queue Fabric while retaining one semantic experiment history.
- Add model selection/ranking and conventional classification breadth only after leakage/domain-barrier contracts remain explicit.


## After dev7

- Add linear SVM / margin classifiers and calibrated probability wrappers.
- Add random forests and boosting on top of the now-qualified decision-tree semantics.
- Add DBSCAN / hierarchical clustering beside deterministic k-means.
- Add feature selection, categorical/missing-value transforms and pipeline composition.
- Add ROC/AUC plus multiclass macro/micro metrics and model-selection objects.
- Keep accelerated providers observationally equivalent to the pure-ooRexx reference techniques.


## After dev8

- Add additional neighbour metrics/rerankers (Manhattan, cosine, Chebyshev) behind an explicit metric contract.
- Add categorical/cyclic close-hash dimensions without weakening ordered numeric semantics.
- Add optional multi-cover/staggered schemas for very high-dimensional boundary robustness.
- Connect Layered Audio landmark/fingerprint matching to the generic multi-probe index rather than growing an audio-private neighbour table.
- Use `MLCloseNeighbourAssessment` to tune probe radius/candidate budgets against exact recall on representative corpora.
- Add native/Foreign Runtime index accelerators only after they reproduce the pure-ooRexx candidate/evidence contract.

### After dev9 pattern hashing

- multi-channel / vector-valued polar patterns;
- staggered angular covers to reduce quantization-edge sensitivity;
- learned or domain-calibrated radius/slope/curvature significance policy;
- bounded pattern-index pruning using close-neighbour codes while retaining exact reference ordering;
- direct Layered Audio envelope/spectral-landmark and Camera activity-profile adapters;
- native acceleration only after semantic equivalence is proven.


## After dev10 cylindrical temporal patterns

- bounded acceleration of temporal-pattern retrieval using dev8 close-neighbour candidate generation followed by exact temporal-pattern reranking;
- staggered angular/time covers to reduce quantization-edge sensitivity without duplicating semantic identity;
- richer multichannel policies including channel groups and calibrated significance learned from held-out reviewer evidence;
- direct Layered Audio landmark/timing adapters and Camera activity/event adapters;
- optional periodic/multi-revolution temporal motifs while preserving the current open-in-time cylinder as the default;
- native acceleration only after pure-ooRexx bearing/elevation/turn and rank ordering are reproduced exactly.
