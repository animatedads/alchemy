# Semantic metric priors — dev5

Dev5 adds a deliberately non-authoritative architectural-knowledge layer above the hall-first geometry.

The rule is:

`observe geometry -> form semantic hypothesis -> attach prior -> solve/check metric scale -> retain provenance`

A semantic guess never replaces the visual observation that caused it.  A UK double-socket hypothesis, for example, may contribute an approximate 0.15 m wall-plane scale anchor while remaining `HIGH_CONFIDENCE_SEMANTIC_GUESS` or `ARCHITECTURAL_PRIOR` rather than `DIRECT_OBSERVATION`.

## Initial user-supplied UK domestic priors

- modern internal door width >= 0.76 m
- modern internal door height >= 1.97 m
- ordinary internal door leaf thickness about 0.04-0.05 m
- ordinary hall width >= 0.80 m
- room width expected to exceed hall width
- UK double wall socket approximately 0.15 m across
- square light switch approximately 0.10 m x 0.10 m
- ordinary interior ceiling context approximately 8-12 ft (2.4384-3.6576 m), explicitly contextual rather than hard
- typical bare lightbulb approximately 0.07 m diameter when the bulb itself is visible
- radiator wall stand-off at least about 0.025 m, body depth approximately 0.05-0.12 m

These are reconstruction priors, not building-code declarations or universal facts.  Historic buildings, atypical fixtures and large-volume spaces are expected exceptions.

## Metric solve

`VisionMetricScaleSolver` combines:

- lower/upper/range constraints from dimensional priors;
- approximate scale estimates from fixtures;
- optional contextual constraints (for example normal ceiling range).

Approximate anchors contribute a weighted nominal estimate.  Lower-bound priors constrain the minimum scale.  Contextual ranges are opt-in per space.

## Plan layer

`VisionBuildingPlanHypothesis`, `VisionPlanSpace` and `VisionPlanOpening` provide a sparse plan representation that can exist before mesh generation.  The intended next projection is a top-down Wire3D plan view, then wall extrusion after scale and topology are sufficiently constrained.
