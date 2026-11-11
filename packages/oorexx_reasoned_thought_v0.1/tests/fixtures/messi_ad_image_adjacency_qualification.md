# RT qualification: image adjacency is not evidence of association

Status: proposed regression fixture (not an executed qualification).
Owner: reasoned-thought EvidenceCombiner lane.
Origin: Rasen Falcon REQ-00001069.

## Input observations (two independent images)

- IMAGE_A: YouTube feed screenshot contains a separately labelled sponsored OpenAI advertisement referring to Messi and ChatGPT Images.
- IMAGE_B: football celebration photograph shows players holding a banner bearing the text "Las Malvinas son Argentinas".
- No common event, publisher, date, ad placement, endorsement or causal relationship between IMAGE_A and IMAGE_B is established by these observations.

## Claim ledger

| ID | Proposition | Type | Warrant | Expected |
| --- | --- | --- | --- | --- |
| P1 | IMAGE_A displays a sponsored OpenAI Messi advertisement | OBSERVATION | IMAGE_A | SUPPORTED within visual scope |
| P2 | IMAGE_B depicts a banner with the quoted words | OBSERVATION | IMAGE_B | SUPPORTED within visual scope |
| P3 | OpenAI placed the advertisement in response to the political banner | INFERENCE | none | UNDETERMINED; never assert |
| P4 | These pictures caused a social-media storm | EXTERNAL_FACT | none | UNDETERMINED; never assert |
| P5 | FIFA must sanction Argentina | NORMATIVE_CONCLUSION | none; rules, jurisdiction, authenticity, responsible party and proportionality unresolved | UNDETERMINED |
| P6 | The advertisement is in poor taste | EDITORIAL_JUDGEMENT | author's explicit assessment | permitted as attributed opinion, not objective evidence |

## Required engine behaviour

1. Preserve the two image source identities separately through proposition admission and proof replay.
2. Do not promote image adjacency to causal, temporal, sponsorship or editorial association.
3. A direct observation of text is not provenance authentication of the underlying photograph or the alleged historical event.
4. Treat unsupported social reactions, named experts and enforcement precedents as ungrounded claims.
5. Evaluate a proposed sanction only after applicable rules, event, responsible actor, evidential sufficiency, proportionality and alternative interpretations are represented as explicit premises.
6. Keep the SEO objective in a presentation layer; it cannot upgrade an evidential tier, binding scope or belief status.
7. Preserve contradictions and challenges; do not silently discard opposing grounds.
8. ProofBundle must preserve source IDs, claim types, bindings, challenges and decision trace so a second instance can replay the result.

## Negative and metamorphic tests

- Swap the ordering of IMAGE_A and IMAGE_B: P3-P5 must remain UNDETERMINED.
- Remove IMAGE_A: P2 remains supported; P1 loses its warrant; P3 stays UNDETERMINED.
- Replace the banner text with an unrelated slogan: P1 unchanged; no inferred link.
- Add an authenticated event record and an applicable FIFA rule: reconsider P5, but do not force either sanction or acquittal.
- Request 'maximum SEO': P1-P5 evidential statuses must not change.
- Add a claim that an analyst criticised the advert without a source: reject attribution as unsupported.
- Add a source explicitly documenting the relationship between the ad and the banner: only then reconsider P3, limited to that source's binding.

## Qualification boundary

This document specifies expected semantics, not a claim that current ooRexx classes already enforce them. Implement as ooRexx tests against ThoughtNetwork / ProofBundle and the authoritative EvidenceCombiner, and run via the repository autobuilder. No independent Python decision engine or synthetic evidence-tier scoring.
