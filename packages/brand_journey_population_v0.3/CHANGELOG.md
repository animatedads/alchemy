# Changelog

## 0.3 - 2026-08-24

- Reconciles two independently developed Brand Journey Population v0.2 branches
  rather than treating either as an authoritative overwrite.
- Keeps the detailed denominator/exclusion accounting, one-arm analytical
  insufficiency handling, BIE v0.6 confidence propagation and
  `COMPARISON_AVAILABLE` guard from the `37f792...` branch.
- Keeps the truthful unknown-upstream-provenance model, duplicate-attempt
  accounting, aggregate provenance limitations and non-moralized sampling model
  from the `2d1e0b...` branch.
- Splits provenance ownership:
  - `BrandJourneyPopulation` owns upstream source/sampling/dedup facts;
  - `BrandJourneyCohortDefinition` owns local selection/inclusion/exclusion and
    outcome-ascertainment rules;
  - the analyzer composes both into native BIE v0.6
    `BrandEvidenceCohortProvenance`.
- Adds `BrandJourneyPopulation~configureSourceProvenance(...)`.
- Adds `BrandJourneyCohortDefinition~configureSelectionProvenance(...)`.
- Retains cohort `configureProvenance(...)` as a legacy full override/fallback.
- Preserves `UNSPECIFIED` for upstream source/sampling/dedup knowledge that was
  not actually supplied.
- Records rejected duplicate attachment attempts in cohort provenance without
  inflating the source denominator.
- Adds explicit limitations for pre-aggregated count provenance and mixed
  observation/aggregate cross-form deduplication.
- Advances runtime/API identity to `brand.journey.population/0.3` /
  `BRAND-JOURNEY-POPULATION-V0.3`.

## 0.2 - 2026-08-24

Two independent continuations were produced from the same v0.1 line. One focused
on detailed BIE v0.6 cohort selection/confidence semantics; the other focused on
truthful upstream provenance ownership and duplicate/provenance limitations.
Both are preserved as source branches for the v0.3 reconciliation.

## 0.1

- Added time/version-scoped journey cohort definitions.
- Added privacy-minimised journey observations and scalable aggregate buckets.
- Added explicit denominator-selection audit and exclusion counts.
- Reused Brand Interaction Effect statistical/materiality thresholds.
- Added 95% Wilson rate intervals as uncertainty material.
- Added recovery/modifier stratification with `ASSOCIATION_ONLY` semantics.
- Added current / previous / long-baseline temporal reports.
- Added one-way Brand Journey → population observation bridge.
- Added opaque evidence-point guard so free prose/customer data cannot hide in
  supposedly safe evidence references.
- Preserved `Service as Sales != upsell mandate` at the population boundary.
- Added Alchemy Object and Runtime Registry integration.
