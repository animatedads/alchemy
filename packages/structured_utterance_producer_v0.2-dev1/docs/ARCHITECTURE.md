# Architecture

## Ownership boundary

`StructuredUtteranceProducer` owns the **handoff moment**, not model invocation. Its input is already structured generation-time evidence. Its output is a sealed Structured Utterance plus renderings and a bounded production record.

The core rule is:

> Flattening is a rendering step, never the source of semantic authority.

The package therefore has no text parser which guesses `SALESPROP`, customer identity, privacy lineage, intent, or information use from a reply after generation.

## Why this exists

A generated phrase may contain no customer-specific wording while still have been selected because of customer-sensitive context. That relationship is knowable during generation and may be unrecoverable from the final text. The generation plan preserves it before loss.

## Privacy

Opaque producer/model/invocation references are constrained controlled tokens; arbitrary prose is rejected. Raw customer-visible delivery content is treated as SECRET in the production record's Alchemy introspection metadata. The deidentified rendering is produced using Structured Utterance's projection policy.

## Non-authorities

This component does not assert that model-declared intent is true, morally appropriate, legally permitted, causally effective, or commercially desirable. It captures evidence. Later Interaction Event and domain-effect components may assess it independently.


## Structured Response ownership boundary (v0.2-dev1)

Structured Response is the platform common occurrence/result representation. This Producer must not define a competing common envelope. Its responsibility ends at a typed domain payload representing the sealed Structured Utterance production result.

`StructuredUtteranceProductionPayload` therefore owns only:

- its domain payload schema identifier;
- stable production/plan/utterance evidence points;
- delivery and deidentified renderings; and
- the existing structured-plan source mode.

It explicitly does not own request/result/receipt semantics, warnings/errors, common evidence arrays, timing, transport, authority, cognitive admission or memory-retention semantics. Those remain external.
