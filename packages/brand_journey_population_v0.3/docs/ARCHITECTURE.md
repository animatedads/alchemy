# Brand Journey Population v0.3 architecture

```text
Brand Journey
    |
    | privacy-minimised observation / aggregate counts
    v
BrandJourneyPopulation
    | upstream source / sampling / dedup provenance
    |
BrandJourneyCohortDefinition
    | local time / class / feature / outcome / release scope
    | local selection / inclusion / exclusion / outcome ascertainment
    v
BrandJourneyPopulationAnalyzer
    |
    +--> BrandJourneyPopulationSelection
    |      detailed denominator exclusions
    |
    +--> BrandEvidenceCohortProvenance (BIE v0.6)
    |      composed provenance + counts + limitations
    |
    +--> BrandEvidenceFrame
    |      2x2 evidence / materiality / support / counterevidence
    |
    +--> BrandEvidenceAssessment
    |      statistical sufficiency / quality / material investigation
    |
    +--> BrandJourneyRateUncertainty
    |      local Wilson interval material
    v
BrandEffectEvidencePacket
    |
    v
reasoning LLM / intervention layer
```

## Provenance ownership

The population and cohort are deliberately not interchangeable.

`BrandJourneyPopulation` can know how the source units arrived: source system,
unit kind, sampling method and upstream deduplication. It cannot infer those facts
from the fact that an analyzer later selected a particular cohort.

`BrandJourneyCohortDefinition` knows what the analysis selected: time window,
journey classification, feature, outcome, classifier/taxonomy, process/model
release and local inclusion/exclusion/outcome-ascertainment rules.

The analyzer composes these into the BIE v0.6 cohort-provenance object. If an
upstream fact is unknown it remains `UNSPECIFIED` and becomes an explicit
limitation rather than being fabricated.

Legacy full cohort provenance remains accepted for compatibility and is used as
fallback only when the corresponding population-owned source fact is
`UNSPECIFIED`.

## Denominator integrity

Aggregate units are indivisible. Partial time overlap is excluded, never
prorated. Feature-schema, outcome-kind and aggregate outcome-window mismatches
are distinct exclusions.

Rejected local duplicate observation/bucket attachments increment
`duplicateAttemptCount`, which is carried to BIE cohort provenance. They do not
enter the source denominator.

Mixed individual and aggregate unit forms carry a cross-form deduplication
limitation because local uniqueness within each collection cannot prove that the
same upstream journey was not represented in both forms.

## Statistical boundary

BIE v0.6 owns the primary 2x2 association evidence. Brand Journey Population
passes complete two-arm frames into its evidence engine.

If an exposed or comparison arm is absent, the population layer returns an
explicit `INSUFFICIENT` or `MATERIAL_INVESTIGATION` assessment instead of
propagating `STATISTICAL_COMPARISON_GROUP_REQUIRED` as a runtime failure.

`BrandJourneyRateUncertainty~comparisonAvailable` prevents local Wilson bounds
from being mistaken for comparison evidence when no 2x2 comparison exists.

No path in this package promotes association to causation.

## Brand boundary

Journey significance can be promotional, reputational and commercial without
being an explicit sales proposition. `SERVICE_AS_SALES_JOURNEY` therefore never
creates sales authority, a `SALESPROP`, or an upsell mandate.
