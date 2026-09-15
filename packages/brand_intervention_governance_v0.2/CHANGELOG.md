# Changelog

## 0.2

- Added `BrandInterventionGovernancePolicySelection` as a provenance-preserving consumer of Institutional Policy v0.6 catalogue resolution.
- Preserves exact selected policy id, version, semantic identity, resolution time/mode, deployment identity, publication assurance and publication authority record.
- Added `recommendUnderInstitutionalPolicy(...)` for the managed/operative governance path.
- Removed implicit construction of a local default rule set; `recommend(binding)` now fails with `GOVERNANCE_RULE_SET_REQUIRED`.
- Retained `recommend(binding, rules)` as an explicit low-level/counterfactual path and marks resulting recommendations as institutionally unmanaged.
- Positive exposure decisions now require a recommendation carrying an operative Institutional Policy selection.
- Preserved non-expanding `NO_CHANGE` / evidence-collection / pause / withdrawal records without conferring execution authority.
- Rebased compatibility validation on Brand Intervention v0.2, Effectiveness v0.2, Institutional Policy v0.6, Alchemy Objects v0.8 and Runtime Registry v0.14.
- Added regressions for missing rule sets, authority-backed policy selection, not-yet-effective policy rejection, and unmanaged positive-decision rejection.

## 0.1

- Initial intervention governance layer above Brand Intervention Effectiveness.
- Added non-executing review dispositions and full evidence bindings.
- Added stale-evidence and temporal-regression gates.
- Added explicit no-single-utility-score / guardrail-preservation contract.
- Added named external governance authority and immutable decision evidence.
- Added scope checks and evidence-backed recording for divergent decisions.
- Added Alchemy object integration and Runtime Registry module.
