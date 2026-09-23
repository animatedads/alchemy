# Constraint-driven floor-plan inference (dev6)

The building reconstruction is intentionally not a point-cloud-to-mesh pipeline.
The hall-first structural solve produces a common floor plane, floor/wall
boundaries, openings and candidate corners.  dev5 adds defeasible semantic
metric priors.  dev6 combines them into a constraint-driven plan.

## Authority order

1. Direct image/video observations and tracked geometry.
2. Cross-view/cross-source geometric consistency.
3. High-confidence semantic hypotheses (for example a recognisable UK double socket).
4. Architectural priors (door/hall minimums, common fixture dimensions).
5. Weak guesses.

A lower layer is not overwritten by a higher-numbered item.  Every scale
constraint keeps the semantic evidence grade and source anchor that produced it.

## Robust scale

`VisionRobustMetricScaleSolver` takes all semantic anchors, computes explicit
hard lower/upper bounds, finds a weighted-median nominal scale, rejects semantic
nominal anchors outside a configurable consensus envelope, and computes the
final nominal scale only from retained nominal anchors.  Rejections are evidence
(`SEMANTIC_SCALE_OUTLIER`), not silent deletion.

This is important when object recognition is deliberately permissive.  A wall
rectangle may look like a socket and still be wrong; repeated socket/switch
anchors that agree can establish scale while an isolated bad guess is rejected.

## Topology before centimetres

`VisionPlanTopologyValidator` checks opening-to-space relationships independently
of the metric solve.  A wrong room adjacency graph should be corrected before
more V5V observations or mesh refinement are requested.

`VisionMetricPlanInference` then projects scene-unit space/opening dimensions
through the chosen scale while preserving metric lower/upper bounds.

## Multi-officer semantic corroboration

`VisionSemanticConsensus` records repeated semantic hypotheses from distinct
sources.  Multiple officers seeing a socket-like fixture can raise confidence,
but corroboration does not rewrite `ARCHITECTURAL_PRIOR` into
`DIRECT_OBSERVATION`.

## Approximate flat topology supplied during qualification

The user-supplied hand sketch is treated as topology evidence only, not a scaled
survey.  Its useful structural reading is:

- hall connected to the main living space;
- bathroom connected at/near the hall circulation;
- kitchen connected from the main living-space side;
- furniture marks are non-structural context.

No wall length is taken from the hand-drawn proportions.
