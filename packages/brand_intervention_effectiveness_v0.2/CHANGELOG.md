# Changelog

## 0.2 — 2026-08-24

- Added an explicit confidence gate to directional intervention-effectiveness status.
- `BrandInterventionEffectivenessThreshold` now records `REQUIRE_INTERVAL_SEPARATION` (default true).
- `BrandInterventionEffectivenessAnalysis` now exposes `CONFIDENCE_GATE` and controlled evidence-gate reasons.
- A statistically sufficient, materially sized point estimate with overlapping 95% Wilson intervals now remains `NO_CLEAR_ASSOCIATION` with `CONFIDENCE_INTERVALS_OVERLAP`.
- Preserved an explicit opt-out path: callers may disable interval-separation gating, and that policy choice is retained in canonical reasoning material.
- Qualified Governance v0.1 unchanged against Effectiveness v0.2; `NO_CLEAR_ASSOCIATION` continues to map to baseline hold rather than expansion.
- Updated validation dependencies to the current Alchemy v0.8 / Brand Effect v0.6 / Journey Population v0.2 / Intervention v0.2 / Runtime Registry v0.14 line.

## 0.1

- Added time/release-scoped applied vs eligible-not-applied intervention comparison.
- Added explicit evidence thresholds and 95% Wilson rate intervals.
- Added PRIMARY and GUARDRAIL outcome roles.
- Added mixed-effects and incomplete-guardrail review states.
- Added observational/randomized/quasi-experimental assignment provenance without autonomous causal promotion.
- Added current/previous/long-baseline temporal effectiveness report.
- Added bridge from `BrandInterventionOutcomeObservation`.
- Added Alchemy privacy/introspection and opaque evidence-point controls.
