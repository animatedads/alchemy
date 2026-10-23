# Architecture

`ssc-machine` is a projection, not a second source-control engine.

Gopher / bounded caller -> `semantic.source.control.machine/0.1` -> exact SSC v0.2.3 objects -> SSC repository / accepted history.

The machine layer calls `SemanticRepository`, `OoRexxSourceAnalyzer`, `ContractComparator`, and `ImpactEngine` directly. It never parses human `osc` output. Compare/impact use `reconcileTrackingSet(..., .false)`, so read-only queries do not append tracking proposals.

The exact v0.2.3 engine is vendored solely for deterministic projection. Mutation is intentionally absent from v0.1.
