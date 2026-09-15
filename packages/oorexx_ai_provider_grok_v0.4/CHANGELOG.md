# Changelog — ooRexx AI Provider Grok (xAI)

## 0.4 — 2026-08-24

- Qualification/migration release over the unchanged public v0.3 provider APIs: `ai.provider.grok/0.3`, `ai.provider.grok.capability/0.3`, `ai.provider.grok.batch/0.3`, and the v0.3 WLU planner APIs remain stable.
- Qualified the package against `oorexx_ai_access_v0.6`, `oorexx_secret_broker_v0.2`, `alchemy_objects_v0.8`, `runtime_registry_v0.14`, and `oorexx_work_load_units_v0.12`.
- Migrated every direct Grok `AlchemyObject` descendant from compatibility `initAlchemy(...)` construction to preferred `self~init:super(...)`, with complete STANDARD metadata. Core provider/capability/batch objects and both WLU planner/estimator pairs pass Alchemy v0.8 STANDARD adoption with zero warnings and `INIT` construction provenance.
- Made real-time `POSTJSON` and batch `REQUESTJSON` trusted transport boundaries `PROTECTED` and aligned their method contracts with the security-sensitive surface.
- Migrated the Batch API from the v0.1 direct `secretValue`/`release` compatibility surface to Secret Broker v0.2 `secretForTrustedConsumer()` plus deterministic `retire()`. Policy rejection remains before credential acquisition.
- Added executable Batch API coverage proving trusted lease materialization, post-transport retirement, and no credential acquisition for a rejected model.
- Fixed a latent ooRexx Batch API defect where the special `RESULT` variable was reused as a mutable Directory and could be clobbered after the first indexed assignment.
- Fixed the Grok fake-curl fixture's copied OpenAI secret marker so it now validates the actual Grok test secret.
- Corrected the capability-selector cost-ceiling fixture from 50 to 300 micro-USD; the built-in economy route costs 250 micro-USD for that fixture, while STANDARD routes remain above the ceiling. Selection logic itself was not weakened.
- Refreshed Runtime Registry/WLU HTTP qualification to assert `work.load.units/0.12` and align the staged provider runtime id with the existing v3 Ability profile.

## 0.3 — 2026-08-24

- Added **GrokCapabilitySelector**, **GrokWorkloadProfile**, **GrokModelCatalog**, **GrokRoutingPlan**, **GrokChannel**.
- Selection is workload-driven: tier floor → zone → prefer batch when allowed → cheapest cost.
- Fail-closed: never silently drops tier or zone; impossible constraints raise.
- Built-in catalog covers ECONOMY / STANDARD / FRONTIER Grok models with illustrative pricing and batch eligibility.
- Real-time, Batch, and both WLU planners retained; versions bumped in lockstep.
- Capability selector carries no credential / transport / Secret Broker authority.

## 0.2 — 2026-08-23

- Batch API path + distinct Batch WLU (long TTL, `AI_BATCH_*` facts, low delivery rate).

## 0.1 — 2026-08-23

- Initial real-time Grok provider peer to OpenAI-compat.
