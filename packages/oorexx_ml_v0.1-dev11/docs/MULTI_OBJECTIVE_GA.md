# Multi-objective / Pareto GA

v0.1-dev5 deliberately does **not** turn every quality concern into one weighted scalar.

A multi-objective experiment declares an `MLObjectiveSet`. Each member remains an ordinary `MLObjective` with its own `MINIMIZE` or `MAXIMIZE` direction. An `MLObjectiveVector` holds one score per objective. `MLParetoAnalyzer` then computes non-dominated fronts and crowding distances without inventing cross-objective weights.

## Dominance

Candidate A dominates B only when A is no worse on every objective and strictly better on at least one. Otherwise both remain legitimate alternatives on the same frontier. Equal vectors are `EQUIVALENT`; mixed wins/losses are `NON_DOMINATED`.

This is especially useful for recovered audio. dev4's scalar experiment used a resemblance term plus fixed 18x/40x artefact penalties. dev5 includes `AudioParetoObjectives.cls`, which instead exposes three independent objectives:

- recovered-reference distance (the original 0.35/0.40/0.10/0.15 distance blend, without artefact penalties);
- pre-limiter over-range fraction;
- post-limiter clipping fraction.

The 18/40 penalty choice therefore remains a calibratable scalar policy rather than a hidden truth about audio quality.

## Pareto evolution

`MLParetoGeneticAlgorithm` uses the existing `MLPopulation`, `MLDeterministicRNG`, `MLGeneticPolicy` and `MLExperiment` objects. Every generation is still transactional:

1. create a coordinated experiment checkpoint;
2. evaluate the current genomes into objective vectors;
3. compute Pareto rank and crowding distance;
4. retain elites and use rank/crowding tournament selection;
5. crossover/mutate with the journalled RNG;
6. commit the next population and RNG state;
7. publish a `MLParetoEvolutionGeneration` tied to the checkpoint.

On failure the whole generation rolls back. `run()` follows dev3's corrected complete-run semantics and explicitly evaluates the last bred population before returning.

This is intentionally described as a **Pareto-ranked GA**, not as a claim of complete NSGA-II conformance. It uses non-dominated rank plus crowding for selection and explicit elitism, while preserving the simpler historical-object lifecycle already established by ooRexx ML.

## Retention and human review

A Pareto front can contain more candidates than the material retention budget. `MLParetoRetentionSelector` fills the bounded retention budget front-by-front, using crowding to preserve diversity within a partially retained front. Human `MLReviewCase` / `MLPreferenceJudgement` objects can then choose among frontier alternatives without rewriting the model's objective vector or pretending one tradeoff is mathematically superior.

## dev6 hard-feasibility rule

Pareto dominance only compares **feasible** candidates. A hard-constraint violation is not represented by a very bad objective value and cannot be traded against another objective. Infeasible evaluations remain available as evidence and may be used by the GA only as a search-recovery signal (for example, fewer violations), but they never enter a Pareto front or retention/promotion set. See `MLConstraints.cls` and `docs/HARD_CONSTRAINTS_AND_DURABILITY.md`.
