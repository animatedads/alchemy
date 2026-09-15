# Architecture — Brand Intervention Effectiveness v0.2

`BrandInterventionEffectivenessAggregate` is the freezeable evidence residue for one outcome in one cohort/window. It retains the eligible denominator, applied and eligible-not-applied counts, outcome counts, outcome direction, study design provenance, and release provenance.

`BrandInterventionEffectivenessEngine` computes denominator sufficiency, effect materiality and Wilson uncertainty as separate gates. By default, a directional `PROMISING_ASSOCIATION` / `ADVERSE_ASSOCIATION` requires non-overlapping 95% Wilson intervals. A material point estimate with overlapping intervals remains `NO_CLEAR_ASSOCIATION`.

`BrandInterventionEffectivenessStudy` combines one PRIMARY outcome with zero or more GUARDRAIL outcomes. Guardrails are first-class because optimisation against a single business metric can damage the brand elsewhere.

`BrandInterventionEffectivenessTemporalReport` preserves CURRENT, PREVIOUS and LONG_BASELINE studies independently. It never hides a recent change inside a lifetime denominator.

`BrandInterventionEffectivenessBridge` can construct aggregates from sealed `BrandInterventionOutcomeObservation` objects. These observations already represent journeys where an intervention proposal existed, giving the bridge a meaningful eligible population.

## Causal boundary

All analyses remain `ASSOCIATION_ONLY`. Assignment method (`OBSERVATIONAL`, `RANDOMIZED`, `QUASI_EXPERIMENTAL`) is retained so an authorised downstream causal process has the material needed to reason, but this package never promotes itself to causal authority.


## Evidence gates

```text
eligible/applied/control counts + time
        ↓
STATISTICAL_SUFFICIENT
        ↓
absolute desired effect
        ↓
EFFECT_MATERIAL
        ↓
95% Wilson interval separation (configurable)
        ↓
CONFIDENCE_GATE
        ↓
PROMISING / ADVERSE directional association
```

The confidence rule is declared in `BrandInterventionEffectivenessThreshold` as `REQUIRE_INTERVAL_SEPARATION`; it is included in canonical reasoning material. Disabling it is therefore an explicit policy choice, not an implicit implementation shortcut.

`NO_CLEAR_ASSOCIATION` is intentionally used when confidence fails. Governance already maps that status to holding the baseline, so an uncertain point estimate cannot silently become expansion guidance.
