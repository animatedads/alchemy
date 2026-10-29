# Changelog

## 0.2-dev1 — 2026-10-29
- Adds typed `StructuredUtteranceProductionPayload` with schema `structured.utterance.production-result/0.1`.
- Adds additive `StructuredUtteranceProductionRecord~resultPayload` and `StructuredUtteranceProducer~producePayload(plan)`.
- Deliberately does not implement Structured Response common request/result/receipt/warning/error/timing/authority vocabulary.
- Adds a regression proving the payload contains domain fields only and does not manufacture Structured Response or Cognitive Continuity envelope fields.
- Keeps API `structured.utterance.producer/0.1` and existing `produce(plan)` semantics unchanged.
- Records v0.1 main publication as manual/source publication, not Autobuild qualification.

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
