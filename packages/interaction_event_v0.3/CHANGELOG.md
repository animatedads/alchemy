# Changelog

## 0.3 qualification repair - 2026-08-24

- Copies content-element and evidence-anchor metadata at construction so caller-owned mutable tables cannot alter canonical event evidence after sealing.
- Adds a regression proving sealed event canonicalisation is stable under later mutation of constructor metadata inputs.
- Records successful qualification against the current Alchemy Objects v0.8 and Runtime Registry v0.14 baseline.
- No public event/native-evidence field or method shape changes; API remains `interaction.event/0.3`.

## 0.3 - 2026-08-24

- Added native `InteractionInformationUseEvidence`, `InteractionGenerationIntentEvidence`, and `InteractionDerivedFinding` objects.
- Added sealed event attachment APIs and immutable-copy getters for all three native evidence families.
- Added stable evidence points: `INTERACTION_INFORMATION_USE:*`, `INTERACTION_GENERATION_INTENT:*`, and `INTERACTION_DERIVED_FINDING:*`.
- Restricted native evidence identifiers/roles/uses/authorities/references to controlled opaque tokens/scalars; free prose is rejected.
- Added native evidence to event canonicalisation and Alchemy relationship/instrumentation evidence.
- Extended deidentified event projection to preserve structured evidence while removing customer-bearing source references.
- Added executable native-evidence/projection/privacy acceptance coverage.
- Verified Structured Utterance v0.3 bridge and Brand Interaction Effect v0.6 native-evidence authority suites against this package.
- Updated Alchemy Objects compatibility target to v0.7 and Runtime Registry integration to v0.13.

## 0.2 - 2026-08-23

- Adopted Alchemy Objects v0.4.3 for the primary evidence-bearing objects and capture library.
- Registered disclosure-bounded state: raw/customer-derived content remains SECRET while semantic residue can be exposed at narrower profiles.
- Added inherited lifecycle/method telemetry, instrumentation evidence and detached object relationships.
- Added optional constructor sealer/capability-authority arguments without breaking existing call shapes.
- Added executable Alchemy privacy/introspection/relationship acceptance test.
- Runtime Registry generation/API advanced to v0.2.


## 0.1

- Initial rich interaction-event model and append-only capture library.
- External access-point boundary with stable event points.
- Evidence-bearing LLM/human/system assessments retained separately from facts.
- Communication-style dimensions including sass/abruptness/dismissiveness without hard-coding them as causes.
- Generic event links and explicit candidate-causality status.
- Element-level privacy/retention/origin/source-span tagging.
- De-identified analytical projection with fail-closed UNKNOWN handling.
- Customer-specific data can be abstracted away while semantic/commercial residue remains.
- Engagement-absence observation model.
- Runtime Registry module and tests.
