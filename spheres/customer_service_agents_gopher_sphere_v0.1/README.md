# Customer Service Agents — LLM Gopher sphere v0.1

Covers the **customer-service agent** project, not an AI-romance product. Sources are the separately delivered controlled readback, legacy recovery, video-mesh and transcript gateway packages.

The client experience may be an obviously artificial cat or one of the A01–A06 characters, but the same ooRexx business intention and evidence/authorisation boundaries govern both. The sphere distinguishes completed code tests from unqualified live speech, face mesh and mesh dispatch.

## Entry points

- `ops.customer-service.start` — purpose and scope
- `arch.customer-service.authority-map` — component authority
- `ops.customer-service.capture` — six-utterance controls (72 planned captures)
- `ops.customer-service.legacy-recovery` — 83 existing readback-named A02 clips
- `arch.customer-service.video-mesh` — Storage Fabric -> Migratable Job -> worker placement
- `qual.customer-service.current` — actual qualification and unresolved gates

## Reproducible qualification

```sh
python3 -m unittest discover -s tests -v
```

If an LLM Gopher runtime is available, install this pack beside its `packs/core`, place `profiles/customer-service-agents.json` alongside Gopher profiles, then use `gopher --profile customer-service-agents context customer-service-agents --full`.

The sphere contains no remote credentials, raw recordings, customer PII, scripts that dispatch work, or embedded third-party components. The `integration.json` is solely for Alchemy Autobuild publication. The package is additive; it does not claim to update the published business services.
