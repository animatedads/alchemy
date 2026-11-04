# Offence-neutral event and evidence contract v0.1

**Status:** design proposal for Claude's SLAM / Reasoned Thought work, 2026-10-30. **Architecture:** Tom Dyer. **Prepared:** ChatGPT GPT-6. **Implementation:** not claimed. England and Wales is the initial jurisdiction assumption; dates of events are unprovided. The Mrs P example is user-supplied, unverified case material, not findings against actual people.

## Outcome

Ingest the narrative *once* into a canonical, versioned case graph. Independently match that SAME graph against any number of offence definitions. Do not make a different event name or a special-purpose fact for fraud, theft, blackmail, regulated credit, benefit fraud, laundering, or conspiracy. Preserve provenance, uncertainty, missing evidence, contested predicates, and the statute applicable **on the event date**. Match results are investigative hypotheses, not allegations proved or prosecution decisions.

## Responsibility / boundary

- **Ingestion:** typed events and source claims from narrative, records, utterances; must not infer truth by wording.
- **Canonical fact graph:** immutable IDs for persons, events, items, claims, source evidence and links. Versioned dictionary and typed roles.
- **Reasoned Thought:** Proposition / Ground / Utterance / ThoughtNetwork, scope-aware SUPPORT, REBUT, UNDERCUT, ordinal evidence tiers, proof replay, revisions; NO automatic promotion of caller-supplied narratives to DOCUMENTARY.
- **SLAM:** discover or compose candidate pathways across source events, necessary conditions, element predicates and evidence gaps. Its exploratory paths are not proof. Existing admit/runAdmitted contract and Body Slam dependency work remain separate.
- **Offence rule packs:** versioned, jurisdiction- and commencement-specific statutory elements with objective/mental elements, alternatives, exceptions, exemptions, defences and explicit source anchors. Each rule is independent from case-specific vocabulary.
- **Output:** per-person/per-offence element matrix with status SUPPORTED / CONTRADICTED / UNKNOWN / OUT_OF_SCOPE, ground IDs and missing evidence, counterexamples, source version and derivation. Distinguish conditional match from guilt.

## Shared dictionary: event kinds (stable UPPER_SNAKE_CASE)

CONTACT_INITIATED; REPRESENTATION_MADE; MEETING_ARRANGED; MEETING_ATTENDED; CREDENTIAL_PRESENTED; THREAT_COMMUNICATED; SERVICE_AGREED; WORK_PERFORMED; PROPERTY_REMOVED; MONEY_TRANSFERRED; CREDIT_OFFERED; CREDIT_AGREEMENT_ENTERED; INTEREST_TERMS_STATED; PAYMENT_INSTRUMENT_HANDED_OVER; PAYMENT_INSTRUMENT_USED; PERSON_DIED; BENEFIT_PAYMENT_MADE; BENEFIT_PAYMENT_RECEIVED; INFORMATION_DISCLOSED; INFORMATION_WITHHELD; AGREEMENT_TO_OFFEND_ALLEGED; PROPERTY_CONVERTED; PROPERTY_TRANSFERRED.

These are event types, NOT findings of dishonesty, falsehood, illegality, causation or conspiracy. Avoid synonyms ("called" vs "rang", "claimed authority" vs "presented badge") as separate machine predicates. Maintain display-language aliases for humans only. Add types through dictionary versions with migrations; never silently reinterpret old events.

## Core typed objects (illustrative v0.1)

- Entity: entityId, kind PERSON/ORGANISATION/ACCOUNT/ASSET/AGENCY, display label, identification confidence, aliases, sourceRefs.
- Event: eventId, eventType, actors [role+entityId], participant roles, time interval [known/unknown], location [known/unknown], objects, linksToEvents, assertedBy [claim IDs], provenanceIds, polarity, version.
- Claim: claimId, exact statement, speaker/reporter, about event/entity/property, claim kind (OBSERVATION/REPORTED_STATEMENT/INFERENCE/EXPERT_OPINION/LEGAL_PROPOSITION), assertedAt, scoped predicates, epistemic status, evidenceBindings. **"Mr T said he was council" ≠ "Mr T was council".**
- EvidenceItem: evidenceId, source kind, custodian, document/content digest, acquisition and original timestamps, access/chain-of-custody, independent origin, supports/rebuts/undercuts claim ID and *scope*. The narrative itself is testimony about what happened until independently corroborated.
- OffenceDefinition: ruleId, statute citation (section + subsection), legislation URI/version hash, territorial extent, effective period, predicates (each necessary/alternative/exemption), requisite state of mind, applicability tests and defence/counterevidence probes. No post-event law.
- Assessment: ruleId, subject person, case revision ID, status per element, binding grounds, countergrounds, source snapshot; hypothesis level and missing proof; never infer "CHARGED/CONVICTED".

Required role labels: ACTOR, TARGET, SPEAKER, RECIPIENT, CLAIMED_AUTHORITY, BENEFICIARY, CREDITOR, DEBTOR, PAYEE, PAYER, CUSTODIAN, WITNESS. Role is case-specific per event, NOT a permanent person's identity.

## Mrs P case seed: canonical events

Actors: PERSON_P (Mrs P, age reportedly 95, Alzheimer's reportedly diagnosed), PERSON_S, PERSON_T, PERSON_J (Ms J), PERSON_H (Mr H), ORGANISATION_COUNCIL (claimed authority; **not** authenticated), and GROUP_UNSPECIFIED ("they" in pension sentence; members unknown).

| ID | Canonical type | Source-limited assertion |
|---|---|---|
| EV01 | CONTACT_INITIATED | S rang P |
| EV02 | REPRESENTATION_MADE | S said he would replace P's roof |
| EV03 | REPRESENTATION_MADE | S said roof required replacement because council said P would be evicted |
| EV04 | MEETING_ARRANGED | S arranged a meeting |
| EV05 | MEETING_ATTENDED | T attended meeting with S and P |
| EV06 | CREDENTIAL_PRESENTED | T showed an ID card purporting to identify him as council |
| EV07 | REPRESENTATION_MADE | T represented himself as council |
| EV08 | THREAT_COMMUNICATED | T said P would be taken into care if roof not fixed |
| EV09 | MONEY_TRANSFERRED | S reportedly received P's life savings; amount, mechanism, title and consent unknown |
| EV10 | WORK_PERFORMED / PROPERTY_REMOVED | S removed the roof; completion, entitlement and damage unknown |
| EV11 | CREDIT_OFFERED | S pressed P to obtain credit from J and H |
| EV12 | CREDIT_AGREEMENT_ENTERED / INTEREST_TERMS_STATED | £30,000 loan at reportedly 2707% interest; APR/period and contract terms to verify |
| EV13 | PAYMENT_INSTRUMENT_HANDED_OVER | P handed bank card to J/H; custody and later use unknown |
| EV14 | PERSON_DIED | P died; date/cause/role of any suspect unknown |
| EV15 | BENEFIT_PAYMENT_MADE / BENEFIT_PAYMENT_RECEIVED | Claim of pension collection for five years after death; recipient, transactions, type of pension and entitlement unknown |

Personal circumstances AGE_AT_EVENT=95 and DIAGNOSIS_REPORTED=Alzheimer's are separately source-bound attributes, NOT proof of incapacity, no consent or inability to understand *at a particular time*. Any "pressured" wording is recorded as an attributed account pending evidence of specific acts. Timeline ordering is provisional. EV15 must not assign "they" automatically to J, H, S or T. Preserve account-level repetitions rather than treating five years as one documented transfer.

## Initial offence candidates and element gaps (NOT outcomes)

1. **Fraud Act 2006 s2**: test each allegedly false roof/council/identity representation; dishonesty, awareness it was or might be false/misleading, and intent to gain or cause loss/risk. Independent council and roof evidence needed. Do not equate a statement with its falsity.
2. **Fraud Act 2006 s3**: only if a specific *legal duty* to disclose is identified, plus dishonest omission and intent; do not infer a general duty from silence.
3. **Fraud Act 2006 s4**: identify qualifying relationship/position and abuse plus dishonesty/intent; age or acquaintance alone does not establish the statutory position.
4. **Theft Act 1968 s1**: appropriation, property belonging to another, dishonesty, intent permanently to deprive, for money, card-related property or other assets as applicable. Investigate alleged transfer, lawful ownership, authority, consent and intent.
5. **Theft Act 1968 s21 (blackmail)**: identify *demand* with *menaces*, gain/loss intention, and whether demand is unwarranted under the statutory test. Threat to take P into care needs link to a demand, not merely an unpleasant statement.
6. **FSMA 2000 ss19, 22, 23**: credit activity carried on by way of business within the regulated perimeter, actors' legal/authorised/exempt status, permissions and relevant dates; check the Regulated Activities Order, exemptions, and regulatory changes (especially historic consumer credit regulation). 2707% interest alone is not proof of a FSMA criminal offence.
7. **Social Security Administration Act 1992 s111A (and s112 if relevant)**: specify scheme, payer/payee, false statements/documents or dishonest failure to notify, required duty/knowledge and actual post-death benefit payments; distinguish occupational/private pensions from benefits in scope.
8. **POCA 2002 ss327-329**: independently establish criminal property, a relevant dealing/arrangement/receipt, necessary knowledge/suspicion and applicable exclusions/defences. Receiving money alleged to be proceeds is not automatic proof of laundering.
9. **Criminal Law Act 1977 s1**: agreement to a defined criminal course by two or more actors plus statutory mental elements; shared attendance/friendship/sequence of acts does NOT itself prove agreement.

Investigative flags outside the first six Act packs: property damage, coercion/harassment, safeguarding/financial abuse and potential civil remedies should be recorded as NEEDS_LEGAL_SOURCE, not silently mapped to a non-implemented offence. A death requires its own causation assessment; **never infer homicide or causal responsibility from temporal proximity**.

## Engine invariants / qualification

Q1. Ingest all 15 event groups exactly once; match N rules with no case-specific aliases in statutory rule definitions.
Q2. A witness claim, even source-supplied as "fact", is not automatically a verified fact. Same statement, weaker tier -> no unjustified proof.
Q3. CREDENTIAL_PRESENTED + claim of council membership must not imply actual council authority; authentic council enquiry can SUPPORT or REBUT.
Q4. Vulnerability cannot imply incapacity, and mortality cannot imply homicide.
Q5. Separate S/T/J/H participation; unbound "they" produces UNKNOWN person-specific pension conclusions.
Q6. 2707% cannot imply criminal regulated lending absent regulatory-perimeter, by-way-of-business, permission and applicable-date proofs.
Q7. One event can support different offence *elements* in multiple rules without duplicate event ingestion; distinct factual scopes prevent irrelevant grounds.
Q8. Missing evidence stays UNKNOWN; no-evidence is not CONTRADICTED; status can change via SUPPORT / REBUT / UNDERCUT and replay.
Q9. Law dates: event pre-commencement / repealed offence/territorial mismatch -> OUT_OF_SCOPE, no anachronistic match.
Q10. Demonstrate benign/alternative fixtures: genuine council repair notice; lawfully completed roof; licensed lending; pension paid lawfully to estate; bank card given for a valid errand; no evidence of an agreement. False-positive tests must fail closed.
Q11. Every report includes a per-element proof/warrant trail, immutable source ids, law version hash, defendant identity resolution, and separate case revision.
Q12. Run existing Reasoned Thought/SLAM suites without breaking them; use exact native ooRexx 5.3.0 r13196, disclose PASS/FAIL/NOT_RUN. Autobuilder OFF.

## Legislation source acquisition (required before coding rule packs)

Obtain the six exact user-requested CLML XML endpoints, raw bytes, with proper Accept: application/xml and User-Agent. **Acquisition is not verified in this environment**: XML content-type unsupported by web viewer and container DNS unavailable. Claude must fetch them in its networked environment, record HTTP final URL/status/content-type, SHA-256, byte count, retrieved UTC time, XML namespace/root, UK legislation identifier and revision/version, and reject HTML/error-body/empty/invalid XML. Record each law's at-event-date version, changes, commencement, extent and linked subordinate law; preserve section-level original/revised distinction. Do not claim the latest consolidated text applied historically.

- https://www.legislation.gov.uk/ukpga/2006/35/data.xml (Fraud Act 2006)
- https://www.legislation.gov.uk/ukpga/1968/60/data.xml (Theft Act 1968)
- https://www.legislation.gov.uk/ukpga/2000/8/data.xml (Financial Services and Markets Act 2000)
- https://www.legislation.gov.uk/ukpga/1992/5/data.xml (Social Security Administration Act 1992)
- https://www.legislation.gov.uk/ukpga/2002/29/data.xml (Proceeds of Crime Act 2002)
- https://www.legislation.gov.uk/ukpga/1977/45/data.xml (Criminal Law Act 1977)

Source format specification: https://legislation.github.io/data-documentation/api/overview.html . HTML pages may support manual read/review but **are not byte-for-byte XML fetch substitutes**.

## Suggested execution stages, Claude's deliverables

**D1:** terminology review with explicit proposed schema version, source/claim/event separation, event IDs and robust JSON fixture of the Mrs P narrative; dissenting interpretations recorded.
**D2:** reproducible six-file CLML acquisition and hash/provenance manifest; XML section extraction for target offences with as-at-date caveats, verified citation anchors and test cases.
**D3:** independent offence rule packs that cite law per element; no case-specific rule code.
**D4:** reusable case-to-rule matcher using existing ThoughtNetwork/ProofBundle and the SLAM composition seam; not a new unreviewed truth authority.
**D5:** qualified 15-event matrix, nine candidate families, missing-evidence queue, negative/adversarial tests and regression/NOT_CLAIMED report.

Ownership: Claude to propose/implement in its existing semantics and fixture lane after owner alignment; ChatGPT retains its agreed EvidenceCombiner/SLAM admission boundaries. Rasen Falcon missives coordinate work but do not constitute new permission to edit another owner's files or merge/deploy.
