# Changelog

## v0.2 — 2026-08-24

- Added explicit Brand Interaction Effect v0.6 cohort-quality awareness.
- A `WEAK_SIGNAL` caused by a failed cohort-quality gate now routes to `REVIEW_REQUIRED` with `COHORT_EVIDENCE_QUALITY_REVIEW`, rather than being treated as an ordinary observation-only behavioural signal.
- Added bounded objectives for explicit selection provenance, selected-unit missingness, unresolved eligibility, and reanalysis after evidence-quality review.
- Added negative constraints against behaviour change from cohort-quality-failed evidence, treating an analyzable subset as the source population, or inferring representativeness from sample size.
- Preserved the existing `OBSERVE_ONLY` path for confidence/effect weak signals whose cohort-quality gate passes.
- Qualified unchanged downstream Brand Intervention Effectiveness v0.1 and Governance v0.1 against the v0.2 API.
- Updated validation dependencies to Alchemy Objects v0.8, Brand Interaction Effect v0.6, Brand Journey Population v0.2, and Runtime Registry v0.14.

## v0.1 — 2026-08-23

- Added evidence-bound intervention reasoning above Brand Journey Population.
- Added explicit evidence-age / as-of binding.
- Added `BASELINE_ONLY`, `OBSERVE_ONLY`, `REVIEW_REQUIRED` and
  `REASONING_GUIDANCE` modes.
- Added bounded objective/avoidance/obligation proposals rather than canned
  customer-facing prose.
- Added sass/dismissiveness guidance which explicitly avoids teaching extreme
  apology as a default recovery mechanism.
- Added journey context-loss/repeat-burden recovery objectives.
- Preserved Service-as-Sales brand significance without creating sales
  authority.
- Added post-intervention outcome observation and population bridge for later
  association measurement.
- Added Alchemy disclosure/relationship support and Runtime Registry module.
