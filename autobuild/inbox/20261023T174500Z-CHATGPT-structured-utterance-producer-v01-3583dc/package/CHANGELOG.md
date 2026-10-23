# Changelog

## 0.1
- Adds provider/application-neutral `StructuredUtteranceGenerationPlan`.
- Reuses native Structured Utterance v0.3 segments, acts, lineage, information-use and generation-intent objects rather than defining a parallel taxonomy.
- Adds `StructuredUtteranceProducer`, which accepts only a sealed generation plan, creates/seals the Structured Utterance, then renders delivery/deidentified text.
- Adds explicit `FLATTENED_REPLY_INSUFFICIENT` fail-closed boundary; markup in provider text is never parsed into semantic authority.
- Adds bounded controlled provider/model/invocation provenance references.
- Adds Alchemy adoption for the public/stateful plan, producer and production record boundaries.
- Adds Shannon-style sensitive-context -> generic sales-act cross-use regression and semantic customer-reference lineage regression.
- Adds optional Runtime Registry v0.14 module qualification.

## 2026-10-23 repository admission metadata

- Added `integration.json` for the Alchemy Autobuild submission contract.
- Pins the accepted repository dependency roots: Structured Utterance v0.3, Interaction Event v0.3, Alchemy Objects v0.8, Crypto v0.8.3 and Runtime Registry v0.14.
- Runtime/API semantics are unchanged; this is repository admission/qualification metadata only.
