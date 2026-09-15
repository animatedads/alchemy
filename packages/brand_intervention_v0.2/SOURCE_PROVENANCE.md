# Source provenance

Brand Intervention v0.2 was developed on 2026-08-24 from the accepted `brand_intervention_v0.1` source in the user-supplied/current ooRexx API line, then qualified against the byte-preserving Journey Population v0.2 successor roll-up.

Current validation stack:

- `alchemy_objects_v0.8`
- `oorexx_crypto_v0.1`
- `interaction_event_v0.3`
- `structured_utterance_v0.3`
- `brand_interaction_effect_v0.6`
- `brand_journey_v0.1`
- `brand_journey_population_v0.2`
- `runtime_registry_v0.14`

The v0.2 semantic change is specifically downstream consumption of Brand Interaction Effect v0.6's independent `COHORT_QUALITY_GATE` and controlled cohort-quality reason codes. No empirical claim is introduced. Synthetic counts in tests remain fixtures only.

Authoritative validation roll-up SHA-256:

`f84722276fba402569fb4b1a2461420ecfe6ca80788959bb2ecdb47e83eb5eab`

Key nested payload SHA-256 values:

- `alchemy_objects_v0.8.zip`: `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073`
- `brand_interaction_effect_v0.6.zip`: `235f2ed40206b8571630e18d17bf781d973a319107122d90ba07c751a81a7a4f`
- `brand_journey_v0.1.zip`: `cebff32a3d40f9d820c245b33a14825ffbe0da4935ccd43a8a396e90a17d4bf8`
- `brand_journey_population_v0.2.zip`: `2d1e0b82686a44c369cabdbf6419d056a1545d03d0f59ede5c229518bb040ddd`
- `runtime_registry_v0.14.zip`: `b8748634f271f5389b9e7e4fd7089eda314b0eea90ab6e47151ae1de270c6209`

Supplied ooRexx runtime: Open Object Rexx 5.3.0 r13196 Internal Test Version.
