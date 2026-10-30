# SPASH V7 — completed Tier A human listening review (30 October 2026)

**Review reporter:** user / human listening assessment.  
**Recording:** privately supplied V7 dual-feed audio; original and derivatives are not published.  
**Author of public qualification record:** ChatGPT GPT-6, based on the user's direct report.  
**Evidence class:** `USER_REPORTED_COMPLETE_TIER_A_LISTENING_REVIEW`, separate from acoustic scores.

## Result

The user has listened to **all 463 of the 463 Tier A candidates** in the previously delivered 912-clip listening library, and reports that **all 463 contained human voice/speech ("verbals")**.

| Measurement | Result | Meaning |
|---|---:|---|
| Tier A clips in private index | 463 | Independently enumerated from source library index |
| Tier A unique clip IDs | 463 | No duplicate IDs |
| Tier A clips reviewed (user report) | 463 | Complete user review of this tier |
| Reviewed clips positive for vocal speech (user report) | 463 | User listening judgment |
| Reviewed Tier A false positives (user report) | 0 | None found in this reviewed tier |
| Observed speech-positive fraction among reviewed Tier A clips | **463 / 463 (100%)** | **Within-sample user-reported clip-level precision only** |
| Tier B and Tier C review | Not established by this report | 242 + 207 further candidates |
| Missed voice/speech in below-threshold timeline | Not assessed | No recall/sensitivity claim |

The private index includes approximately 4h 10m of Tier A clip durations, not necessarily independent time or different physical sources. This is a full review of the delivered Tier A candidates, **not** a proof that all human speech in the eight-hour source was retrieved.

## What the result supports

- SPASH's Tier A ranking has excellent *reported* positive predictive value on this specific noisy V7 recording.
- The user assessed the clips by listening, not merely accepting the model's labels.
- The result justifies prioritizing Tier A for additional acoustic-path and speech-reconstruction experiments and using Tier A as a **user-reviewed positive set** for later controlled experiments.

## What it does not support

- No claim that the *algorithm* independently recognised words or understood speech.
- No claim of same-speaker identity, distinct speaker count, physical source, echo identity, or legal provenance.
- No measured recall; there may be many missed speech intervals outside Tier A.
- No generalization of 100% to other recordings or to Tier B/C.
- No independent blind assessor, separately sourced negative-control audit, or numerical uncertainty interval with an independence assumption.
- The 463 clips may have temporal overlap or shared noise; treat their observations as dependent where appropriate.

## Reproducible integrity boundary

The private V7 index was re-read: **912 total candidates**, with **463 A / 242 B / 207 C** and 463 unique A IDs. All 463 Tier A archive clip bodies were verified against their index SHA-256 and size. A private review receipt was generated under the user's file workspace and binds the *user-reported* label to every exact Tier A clip ID, source time range and clip SHA-256; its content and recording identifiers are deliberately **not committed**.

The public record does not contain the original intercept audio, listening clips, their hashes, or individual time references. A follow-on evaluation should review randomly selected Tier B/C candidates and below-threshold noncandidate intervals with independent adjudication to estimate recall and false negatives.

**Architecture/naming:** Tom Dyer. **Acoustic ranking and code:** ChatGPT GPT-6. **Human validation:** user report; not independent automatic classification.

## Relation to release

The existing PR #104 is source publication, not production promotion. Its new V7 reference scanner is not yet demonstrated to be byte-identical to the historical 912-clip run. Independent tests of the exact GitHub checkout remain required.

## Further user listening confirmation (30 October 2026)

The user reports that all 463 reviewed Tier A clips contain **English-language human speech**, and that both male-sounding and female-sounding voices were audible across the entire reviewed collection. The result is **463/463 user-reported English-speech-positive clips**, with vocal variety reported for the collection as a whole. These are user listening observations, not an automatic language detector or an individual-speaker classification. The review does not establish speaker identity, the number of individuals, the recall of the search or speech in excluded intervals.
