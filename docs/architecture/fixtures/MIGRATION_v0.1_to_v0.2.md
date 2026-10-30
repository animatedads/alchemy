# Mrs P case file: v0.1 to v0.2

Architecture: Tom Dyer. v0.1: ChatGPT (GPT-6), commit `48470c08`, unchanged. v0.2 and this note: Claude (Opus 5.5), 2026-10-30, written by `packages/oorexx_slam_v0.1/tools/migrate_case_v01_v02.rex` (ooRexx, `json.cls`). Nothing in v0.1 is deleted; a renamed type keeps its v0.1 name in `eventTypeV01`. A field-by-field comparison of the two files shows two changed values, `schemaVersion` and EV06's `eventType`, and only additions otherwise.

The dictionary is `packages/oorexx_slam_v0.1/tests/law/VOCABULARY.md` (law.kinds 0.2): 42 kinds, each an EVENT or a FINDING, with definitions in SLAM's controlled words. Gate 6 (`SlamLaw~vocabulary`, `SlamLaw~kindErrors`) refuses a kind that is not on the list, a finding used as an event, and an event whose definition needs a word of a finding.

| Change | Reason |
|---|---|
| EV06 `CREDENTIAL_PRESENTED` → `DOCUMENT_PRESENTED` | T's card was shown to a person: it is a document (Forgery and Counterfeiting Act 1981 s.1 and s.3 separate making it from using it). "Credential" is kept for one thing, authenticating to a system: `CREDENTIAL_USED`, which also covers a card and PIN at a cash machine (one event, not one type per statute). |
| EV16 `CREDENTIAL_USED` added | Tom Dyer, 2026-10-30: "Once Mrs P dies they keep withdrawing the pension". A series, count unknown, actor `THEY` (unresolved). Each withdrawal a record shows becomes its own event, `partOf: EV16`. EV15 is a payment into the account; EV16 is cash taken out of it. |
| `CLM_LEGAL_CMA` added as a `LEGAL_PROPOSITION` | "That's unauthorized access to a computer system" is a proposition to test against rule packs, not a fact. |
| Two open questions added | Who made the card (Tom: "may be forgery"), and who made each withdrawal. No `DOCUMENT_MADE` event is invented, because none is reported. |
| `jurisdiction.screen: [E.W., S.]` | Fraud Act 2006 ss.2–7, Theft Act 1968 ss.1, 21, 24A and Criminal Law Act 1977 s.1 do not extend to Scotland. The Computer Misuse Act, FSMA, SSAA and POCA sections do. Read from each section's markup (`tests/law/source/MANIFEST_LEGISLATION.md`). |

**Proposed for v0.2 and not used by this case** (sent to ChatGPT, REQ-00002599):
- `INFORMATION_WITHHELD` → `NOTIFICATION_NOT_FOUND`: "withheld" carries intent and a duty.
- `AGREEMENT_TO_OFFEND_ALLEGED` → removed as an event. `AGREEMENT` is a finding.

**Open, waiting for ChatGPT's view:** `REPRESENTATION_MADE` and `PROPERTY_CONVERTED` use statute verbs (Fraud Act s.2; POCA s.327). Both are kept as in v0.1 until that is settled.

**Kept as in v0.1** (REQ-00002593's question): EV09 stays `MONEY_TRANSFERRED`. "Alleged" is the claim's status (`ALLEGED_UNCORROBORATED`), not part of the type.

## v0.2 to v0.3 (2026-10-30)

Written by `packages/oorexx_slam_v0.1/tools/migrate_case_v02_v03.rex`, from Tom Dyer's third account (`SOURCE_NARRATIVE_2026_10_30_C`). Dictionary: law.kinds 0.4. Nothing in v0.2 is deleted; a field-by-field comparison shows `dictionary`, `schemaVersion`, EV10's time and the migration record changed, and only additions otherwise.

| Change | Reason |
|---|---|
| Entity `SON_P` (Mr P, Mrs P's son) | named in the third account |
| EV20 `MESSAGE_SENT` (2008): Mr P complained | to whom is not stated |
| EV21 `CHEQUE_DRAWN` (2008): the refund, by cheque; `DRAWER` UNRESOLVED | who wrote it is not stated, and is not filled in |
| EV22 `CHEQUE_DISHONOURED` (2008), parts EV22.1 to EV22.3 | "it bounced, three times": one event per dishonour |
| EV23 `PERSON_INJURED` (2009): Mr P hit by a falling tile; `ACTOR` UNRESOLVED | "whilst they began the 6 year process": "they" again |
| EV10 time: UNKNOWN to began 2009 | the third account dates the tile removal |
| Claims: "She forgot it" (P); "lost the power of communication" (SON_P) | reported attributes, not proof of incapacity; Mr P can no longer give evidence |
| Four open questions | the cheque's drawer and account; the complaint's recipient; how the tile fell; where the house was, for the law of 2008-2009 |
