# Changelog

## 0.6 - 2026-08-24

- Adds sealed `BrandEvidenceCohortProvenance` for source, selection-rule, sampling, inclusion/exclusion, deduplication, classifier/taxonomy and outcome-ascertainment lineage.
- Extends `BrandEvidenceCohortAccumulator` with candidate-level `INCLUDE` / `EXCLUDE` / `UNKNOWN` selection and explicit missing exposure/outcome accounting.
- Retains controlled exclusion and unresolved-selection reason counts while keeping opaque unit ids out of persisted provenance.
- Adds cohort-quality thresholds for required provenance, selected-unit analysis completeness, unresolved eligibility and explicit selection-rule evidence.
- Prevents otherwise strong 2x2 evidence from becoming `SUPPORTED` / `STRONG` when configured cohort-quality requirements fail.
- Keeps sampling/selection facts descriptive: low selection rate or a named sampling method is not automatically labelled bias.
- Adds runtime factory for cohort provenance and regressions for selection lineage, missingness, unresolved eligibility and provenance-required support.
- Runtime API is `brand.interaction.effect/0.6`.

## 0.5 - 2026-08-23

- Adds 2x2 `BrandStatisticalEvidence` with explicit confidence level, log-relative-risk interval and conservative Wilson-derived risk-difference interval.
- Adds recorded Haldane-Anscombe correction for zero-cell relative-risk intervals.
- Adds confidence exclusion as a separate gate: count/time sufficiency plus a large point estimate is no longer enough for `SUPPORTED` when uncertainty crosses the null.
- Extends evidence reasoning material with statistical method, confidence bounds, association direction and null-exclusion results.
- Adds Alchemy-based `BrandEvidenceCohortAccumulator` so scoped frames can be constructed from deduplicated privacy-minimised interaction units rather than hand-entered totals.
- Makes `BrandEvidenceEngine` an Alchemy Object operational service.
- Adds regressions for confidence bounds, confidence-guarded weak signals and duplicate-safe cohort accumulation.
- Runtime API is `brand.interaction.effect/0.5`.

## 0.4 - 2026-08-23

- Consumes Interaction Event v0.2 native generation-intent, information-use and derived-finding evidence.
- Filters producer-supplied `STRUCTURED_FINDING/...`, `STRUCTURED_INTENT/...` and `STRUCTURED_EFFECTIVE_USE/...` string tags at the bridge.
- Regenerates those controlled observation tags only from native evidence objects and retains their stable evidence points.
- Adds anti-spoof regression proving a string tag alone cannot manufacture `SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING`, while the equivalent native evidence does.
- Keeps brand findings as assessments of interaction evidence, not legal or causal authority.
- Runtime API is `brand.interaction.effect/0.4`.

## 0.3 - 2026-08-23

- Consumed Structured Utterance v0.2 sensitive-commercial-repurposing and declared-use-mismatch findings.
- Adopted Alchemy Object v0.4.3 for `BrandInteractionEngine`.

## 0.2 - 2026-08-22

- Added weighted/statistical/temporal evidence layer and named external causal promotions.

## 0.1 - 2026-08-22

- Initial Service-as-Sales / Brand Interaction Effect model.
