# Hard constraints, Pareto feasibility and durable completion

## Rule

A hard constraint is a gate, not a badly weighted objective. Security, legality, runtime capability, source validity, schema validity, workspace feasibility and other mandatory requirements cannot be outweighed by a better loss, lower clipping, faster runtime or cheaper execution.

`MLConstraintAssessment~feasible` is therefore evaluated before objective scoring where possible. Infeasible candidates retain violation evidence but do not receive a Pareto position.

## Constrained evolution

`MLConstrainedParetoGeneticAlgorithm` uses the same branchable population + deterministic RNG + State-of-the-Nation checkpoints as the existing GA. Selection order is:

1. feasible before infeasible;
2. among feasible: Pareto rank, then crowding diversity;
3. among infeasible: fewer hard-constraint violations as a search-only recovery heuristic.

Only feasible Pareto points are promotable.

## Storage Fabric

Execution workspace and durable evidence are deliberately separate. Storage Fabric v0.1-dev7 is authoritative for this distinction. A disposable workspace may host a candidate evaluation, while Storage Fabric's placement evidence reports mandatory output commit bytes when the selected workspace does not count as durable.

ML persists only value objects across this seam. `MLStorageCheckpointValue` captures experiment/branch/checkpoint identity and participant journal-point strings. `MLDurableFrontierValue` captures the feasible frontier's candidate ids and objective vectors. The actual byte transfer, verification, replica policy and lifecycle safety remain Storage Fabric responsibilities.
