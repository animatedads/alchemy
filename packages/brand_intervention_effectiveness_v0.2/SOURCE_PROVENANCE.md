# Source provenance

Brand Intervention Effectiveness v0.2 was developed on 2026-08-24 from the accepted `brand_intervention_effectiveness_v0.1` payload in the current ooRexx API line. The change was triggered by an executable regression showing that v0.1 could emit `PROMISING_ASSOCIATION` for a two-percentage-point improvement while its own 95% Wilson intervals overlapped.

Validation basis:

- `oorexxapis(20260824-brand-journey-population-v0.2).zip` SHA-256 `f84722276fba402569fb4b1a2461420ecfe6ca80788959bb2ecdb47e83eb5eab`
- `brand_intervention_v0.2.zip` SHA-256 `22b4fc43952e20c9640e93832f1985e45d400fb3bca860e40c7d9b649b0eeed6`

Validated component line:

- `alchemy_objects_v0.8`
- `oorexx_crypto_v0.1`
- `interaction_event_v0.3`
- `structured_utterance_v0.3`
- `brand_interaction_effect_v0.6`
- `brand_journey_v0.1`
- `brand_journey_population_v0.2`
- `brand_intervention_v0.2`
- `runtime_registry_v0.14`

The observed overlap fixture is synthetic validation evidence only, not an empirical claim about a real service.

Behaviour validation target: user-supplied Open Object Rexx 5.3.0 r13196 Internal Test Version.
