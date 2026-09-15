# Conventional technique catalogue — v0.1-dev8

This increment broadens ooRexx ML without weakening the historical-object model. Each learned estimator/transform is an `MLDriveableObject`; fitting therefore creates retained journal state that can be checkpointed, rolled backward, rolled forward and branched just like the existing regression/search objects.

## Added techniques

### Binary logistic regression

`MLBinaryLogisticRegression` is a pure-ooRexx batch gradient reference implementation with explicit learning rate, epoch count and L2 policy. It accepts exactly two labels and allows the caller to name the positive label so probability semantics are not silently inferred. Learned weights, dataset identity, label mapping and final probability-error evidence are retained in model state.

### Gaussian Naive Bayes

`MLGaussianNaiveBayes` learns per-class priors, means and variances with an explicit variance floor. Prediction is performed in log-score space to avoid multiplying tiny Gaussian densities. The omitted Gaussian constant is class-independent for a fixed feature count and therefore does not alter class ordering.

### Gini decision tree

`MLDecisionTreeClassifier` performs deterministic exhaustive threshold search over numeric features using weighted Gini impurity. Tree policy (`maxDepth`, `minSamplesSplit`, `minGain`) is itself driveable state, making depth/purity alternatives natural experimental branches. `MLDecisionNode` is immutable after construction and has a canonical recursive evidence form.

### Deterministic k-means

`MLKMeans` provides unsupervised partitioning with deterministic maximin initialisation, bounded iterations, convergence tolerance, retained assignments and inertia. No hidden RNG is used; identical historical state and input data therefore replay identically without a random-state side channel.

### Principal-component analysis

`MLPrincipalComponentAnalysis` centres the source data, computes covariance in ooRexx decimal arithmetic, and extracts components through deterministic power iteration plus deflation. Learned means, components, eigenvalues and explained-variance ratios are retained. Dataset transformation preserves sample ids and creates derived provenance with transform `PCA`.

## Execution doctrine

These are reference implementations, not claims that pure ooRexx is always the fastest backend. A future NumPy/Torch/native provider may accelerate the numerical work, but accelerated execution must preserve:

- model identity and driveable-history semantics;
- dataset/provenance identity;
- policy and learned-state shape;
- deterministic/replay guarantees where declared;
- output and validation evidence within the declared numerical policy.

This is the same separation already used in Layered Audio: meaning remains in ooRexx even when machinery moves elsewhere.


### Close-neighbour hashing

`MLCloseNeighbour.cls` provides approximate-neighbour indexing for ordered numeric feature spaces. It uses significance-preserving quantised coordinates rather than cryptographic hashing or collision-only LSH. The largest weighted bin discrepancy dominates the hash-distance score, while adjacent cells remain close. Multi-probe lookup explores neighbouring cells and may rerank only the resulting bounded set with exact Euclidean distance. A brute-force oracle plus recall/efficiency assessment makes approximation quality measurable.

## Pattern hashing — polar shape recognition

`MLPatternHash.cls` adds a non-probabilistic shape-recognition technique for sequences where relative curve geometry matters more than absolute values.  The minimum is mapped to the centre of a circular grid, amplitude is normalized into radius, source sample count is normalized into angular bins, and radius/slope/curvature are hashed under a significance-ordered difference.  Rotation invariance is explicit; reversal invariance is opt-in.

The reference demo is `examples/pattern_hash_polar_demo.rex`, which also emits `pattern_hash_polar_demo.svg`.

## Temporal pattern hashing

`MLCylindricalTemporalPatternSchema` / `MLTemporalPatternIndex` extend shape recognition into time. Use this when event geometry and timing relationships matter more than absolute numerical levels. The reference implementation supports declared time-shift/time-scale invariance, multichannel event state, 3-D bearing/elevation/turn signatures, and historical driveable indexing. See `TEMPORAL_PATTERN_HASHING.md` and the cylindrical market demo.

## Wobbly fit / contextual fit restoration

`MLWobbleSetSearch` finds the smallest observation set whose temporary exclusion restores a declared fit criterion. It reports distance-to-fit, normalized distance, alternative minimal restoring sets, participation, normative wobbliness and explicit reassignment evidence. Wobbliness is model-relative and never deletion authority. See `WOBBLY_FIT.md`.
