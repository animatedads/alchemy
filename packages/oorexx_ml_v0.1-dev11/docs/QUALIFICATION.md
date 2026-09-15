# Qualification

## v0.1-dev10

- ooRexx 5.3.0 r13196: **57/57 executable tests pass**.
- 17 source/integration surfaces compile with `rexxc`.
- Semantic Source Control v0.2.3 accepts `OorexxML / MAIN / sourceLevel 11`: 14 packages / 859 methods / 291 attributes / 0 external candidates / 0 pending proposals.
- Cylindrical market demo executes in ooRexx/RxMath and self-generates SVG evidence; A/C exact economic-time twin, A/D local timing separation, A/B nominal-price lookalike separated by auxiliary economic channels.
- Journal Pointed State, Maths/MathsBootstrap and Storage Fabric qualification snapshots remain unchanged.
- Full evidence: `qualification/QUALIFICATION_DEV10.txt`.

# ooRexx ML v0.1-dev7 qualification

Target runtime: ooRexx 5.3.0 r13196 debug x86_64.

Qualification requires:

1. JournalPointedState / Maths / MathsBootstrap / Storage Fabric snapshots remain byte-identical to the already-qualified dev6 dependency snapshots.
2. All 34 `tests/test_*.rex` programs pass.
3. All 28 dev6 constrained-Pareto, Storage, Audio, review, GA, search, training and validation regressions remain green.
4. Binary logistic regression correctly separates a simple two-class problem, exposes explicit positive-label probability semantics and survives rollback/roll-forward of fitted state.
5. Gaussian Naive Bayes learns per-class priors/means/variances and predicts using log-score ordering with a positive variance floor.
6. The deterministic Gini decision tree resolves a depth-two XOR problem and publishes canonical immutable tree evidence.
7. Deterministic k-means separates two compact clusters, retains assignments and inertia, and contains no hidden RNG dependency.
8. PCA extracts the dominant component of near-collinear two-dimensional data, reports >99% explained variance in the qualification fixture, and preserves sample identity/derived provenance through transform.
9. `MLTechniqueCatalogue` reports the new supervised/unsupervised technique families.
10. All 11 ML source classes and all integration sources compile with `rexxc`.
11. Semantic Source Control v0.2.3 reconstructs dev6 level 7, scans dev7 with zero pending/external candidates, and accepts dev7 as `OorexxML / MAIN / sourceLevel 8`.
12. The separately delivered ooRexx ML Gopher sphere validates/lints cleanly and its packaged runtime search test passes under LLM Gopher v0.21-dev1.

## v0.1-dev8 close-neighbour qualification

The dev8 sealed candidate is qualified with 41 executable tests under ooRexx 5.3.0 r13196. New regressions cover dominant-difference ordering, carry-boundary adjacency, fail-closed range policy, driveable index history, closest-first/fail-closed multi-probe policy, exact-oracle recall/efficiency assessment, and an 18-bit-like audio landmark neighbour case. All 15 ML/integration compile surfaces pass `rexxc`. Semantic Source Control v0.2.3 accepts the 12-package source as `OorexxML / MAIN / sourceLevel 9` with zero external candidates and zero pending proposals.

## dev9

- 49/49 executable tests pass under ooRexx 5.3.0 r13196.
- Seven new pattern-hash regressions cover affine invariance, sample-density invariance, significance ordering, rotation policy, reversal policy, polar grid geometry and historical index rollback/roll-forward.
- 16 source/integration surfaces compile with `rexxc`.
- Semantic Source Control v0.2.3 accepts `OorexxML / MAIN / sourceLevel 10`: 13 packages, 726 methods, 291 attributes, 0 external candidates, 0 pending proposals.
- The polar demo executes and generates an SVG from ooRexx/RxMath itself; no Python runtime path is required by the demo.
