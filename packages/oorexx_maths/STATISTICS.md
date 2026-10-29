# Exact/domain-aware statistics — ooRexx Maths v0.20 candidate2

`MathStatistics` is the reusable authority for finite scalar-data reductions that had begun to reappear in consumer packages. Construct with `.Maths~statistics(values, context)`.

The object provides `count`, `sum`, `product`, `mean`, `median`, `modes`, `uniqueMode`, `minimum`, `maximum`, `range`, `deviations`, `squaredValues`, `populationVariance`, `sampleVariance`, `populationStdDev` and `sampleStdDev`.

Population and sample variance are intentionally different methods; callers must choose the denominator contract rather than inheriting an undocumented default. Under a rational context, sums, means, medians and variances remain exact where the operations are closed. Standard deviation uses the existing Maths square-root authority and therefore fails closed in an exact rational context for an irrational root.

`modes` returns every maximally frequent value. `uniqueMode` is the stricter consumer convenience and refuses ties. This preserves SLAM's current language contract without making tie-refusal the only mathematical definition of mode.

## SLAM consumer boundary

Library `oorexx_slam_v0.1-1.zip` currently implements a private `SlamMaths` containing mean/median/mode/range/variance/stddev and a private Newton square root. The intended migration is a thin SLAM adapter: language words, grounding, TESTED-edge qualification, right-to-left composition and array-shaped language results stay in SLAM; the numerical operations delegate to Maths. SLAM's existing `variance` fixture is population variance (`2 4 4 4 5 5 7 9 -> 4`).
