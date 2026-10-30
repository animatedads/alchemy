# Mrs P in Queens, New York — NY State / NYC / US Federal offence-candidate matrix (v0.1)

**Research date:** 2026-10-30. **Jurisdiction overlay:** Queens County, New York City, New York State, United States. **Source case:** `docs/architecture/fixtures/mrs_p_roof_credit_pension_v0.1.json`. **Status:** SOURCE-RESEARCHED HYPOTHESES ONLY; not adjudicated offences, legal advice, or interpreter qualification. **Architecture:** Tom Dyer. **Prepared:** ChatGPT GPT-6.

## Immutable case / mutable jurisdiction

DO NOT relabel the same 15 events. Use event IDs EV01–EV15 with source claims CLM_EV01–CLM_EV15, preserve attributes age 95, Alzheimer's (reported), named persons S, T, J, H, and unresolved pronoun 'THEY' in EV15. The original JSON fixture includes UK-local assumptions and currency; this **US scenario overlay** assumes `location=Queens, NYC, New York` and `loan_principal_currency=USD` **for comparative analysis only**, without falsifying the original case claims or changing event IDs. Currency/location are context overlays, not purported evidence. Keep 2,707% rate BASIS=UNKNOWN and $30,000 as assumed *loan principal* (not necessarily proof of loss or gain). Dates are UNKNOWN, so statutory temporal applicability is unverified.

Separation: candidate is not charge; proposition may be alleged / supported / contradicted / missing. The engine must NOT change evidence classes because US criminal statutes classify conduct differently than UK/NSW.

## New York State offence candidates

| ID | Source / statute | Events | Element predicates and evidence gates |
|---|---|---|---|
| NY_LARCENY_GENERAL | Penal Law §155.05 | EV02,EV03,EV07,EV09,EV11,EV13,EV15 | Wrongfully takes/obtains/withholds property from owner with intention to deprive or appropriate; law includes false pretenses, false promises, extortion. Must prove defendant, property right, transaction and intent; breach of promise alone does NOT establish original fraudulent intent. |
| NY_LARCENY_FOURTH | Penal Law §155.30 | EV09,EV13,EV15 | Basic larceny plus qualifying circumstance: value over $1,000, credit/debit card as property, or some forms of extortion; note debit card handover does not prove wrongful taking. |
| NY_LARCENY_THIRD | Penal Law §155.35 | EV09,EV15 | Basic larceny and stolen value over $3,000; life savings amount UNKNOWN; loan principal $30,000 is not necessarily stolen sum. |
| NY_LARCENY_SECOND | Penal Law §155.40 | EV09,EV15 | Basic larceny and stolen value over $50,000 or a separately enumerated qualifying extortion basis; do not infer a $50k loss. |
| NY_CRIMINAL_IMPERSONATION_2 | Penal Law §190.25(3) | EV06,EV07,EV08 | False assertion of public servant/approval/official authority + intent to cause submission, solicit funds or reliance. Authentic government authority is counterevidence. NOT first-degree public-police impersonation merely because 'council officer' was claimed. |
| NY_FORGERY_2 | Penal Law §170.10 | EV06 | Falsely making/completing/altering qualifying government-issued/public instrument + intent to defraud/deceive/injure; card must be actual forged instrument rather than misleading but genuine card. |
| NY_FORGED_INSTRUMENT_POSSESSION_2 | Penal Law §170.25 | EV06 | Knowledge forged + possession/uttering + intent to defraud/deceive/injure. |
| NY_COERCION_3 | Penal Law §135.60 | EV08,EV11 | Compels legally optional act/omission by instilling fear of one of STATUTORILY ENUMERATED threatened acts. 'I will have you taken into care' needs legal mapping; mere frightening language does NOT necessarily satisfy s135.60. |
| NY_COERCION_1 | Penal Law §135.65 | EV08,EV11 | Coercion in third degree PLUS statute's specific aggravator; no automatic inference from elder vulnerability. |
| NY_CRIMINAL_USURY_2 | Penal Law §190.40 | EV11,EV12 | Unauthorized knowingly charged/took/received interest above 25% per year equivalent; verify real annualized basis, loan terms, identity and authorization/exemption. A raw '2707%' with UNKNOWN period is insufficient to compute. |
| NY_CRIMINAL_USURY_1 | Penal Law §190.42 | EV11,EV12 | s190.40 predicates PLUS prior criminal-usury conviction/attempt or part of scheme/business of usurious lending. Friendship J/H alone insufficient. |
| NY_CRIMINAL_MISCHIEF_4 | Penal Law §145.00 | EV10 | Without right/reasonable belief in right, intentionally damaged another's property (or qualifying reckless damage); roof removal may be authorised first step in repairs. |
| NY_CRIMINAL_MISCHIEF_2 | Penal Law §145.10 | EV10 | Intentional unlawful damage AND amount over $1,500; actual monetary repair cost UNKNOWN. |
| NY_IDENTITY_THEFT_3 | Penal Law §190.78 | EV13,EV15 | Knowingly and intending fraud assumes another's identity / uses identifying information AND financial gain/loss or qualifying criminal offence; receiving card alone insufficient. |
| NY_IDENTITY_THEFT_1 | Penal Law §190.80 | EV13,EV15 | Identity theft plus >$2,000 qualifying financial amount or other specified aggravator. |
| NY_PERSONAL_ID_INFORMATION | Penal Law §190.81 | EV13,EV15 | Knowingly possesses enumerated account/card data knowing planned use to further another NY Penal Law crime. Physical card custody does not prove knowing criminal purpose. |
| NY_CONSPIRACY_6 | Penal Law §105.00, §105.20 | EV04,EV05,EV11,EV12,EV15 | Two or more identified people agree with intent a crime be performed; overt act required for conviction. A meeting/affiliation by itself does not prove agreement. |
| NY_CONSPIRACY_5 | Penal Law §105.05, §105.20 | EV04,EV05,EV11,EV12 | Agreement with intent felony be performed plus overt act, as above. |
| NY_SCHEME_TO_DEFRAUD_2 | Penal Law §190.60 | EV02,EV03,EV07,EV09,EV11,EV12 | Systematic ongoing course of conduct INTENDED to defraud **more than one person** or obtain their property; property obtained from ≥1. **The single reported victim Mrs P does NOT establish multi-victim element.** |
| NY_SCHEME_TO_DEFRAUD_1 | Penal Law §190.65 | EV02,EV03,EV07,EV09,EV11,EV12 | Distinct numerosity/monetary or vulnerable-elder variants, all requiring appropriate *multiple intended victims*; only one alleged person in fixture, so do not select from property sum alone. |
| NY_VULNERABLE_ELDER_CAREGIVER | Penal Law §§260.31,260.32,260.34 | EV08,EV11,EV14 | NOT automatically applicable: definition of vulnerable elderly person has functional requirements; defendant must be statutory **caregiver**; offences concern physical injury/other specific acts, not a generic financial abuse offence. Alleged roof contractor/lenders not shown to be caregivers; no evidence of causation of injury/death. |

## NYC municipal administrative / consumer regulation (NOT NY Penal Law felonies)

| ID | Authority | Events | Required gating |
|---|---|---|---|
| NYC_HIC_LICENSE | NYC Admin Code §20-387; DCWP | EV02,EV10 | Home improvement qualifying scope (including residential roof work), >$200 where applicable, contractor identity, licence status, exemptions, offence date. |
| NYC_HIC_FALSE_PROMISE | NYC Admin Code §20-393(2) | EV02,EV03,EV07 | Misrepresentation or false promises in soliciting/obtaining home improvement contract; verify what S knew and what council actually said. |
| NYC_HIC_FINANCING | NYC Admin Code §20-393(4),(17); DCWP inspection checklist | EV11,EV12 | Contractor **arranged/helped** customer obtain financing tied to home improvement; exactly what S did with J/H and applicable rule/version. This is distinct from NY criminal usury. |
| NYC_BUILDING_PERMIT | NYC DOB | EV10 | Was roof work structural/non-exempt, permit required, actual permit holder? Some non-structural roof work is exempt from permit even though contractor licensing may still apply. |
| NY_GBL_349_CIVIL | NY General Business Law §349 | EV02,EV03,EV07,EV11,EV12 | State consumer deceptive/unfair/abusive conduct; principally civil/regulatory remedies. Do NOT call violation a Penal Law crime by default. |
| NY_CIVIL_USURY | NY GOL §5-501 + Banking Law §14-a | EV12 | Ordinary 16% ceiling in applicable transactions (unless exempt); NOT itself s190.40 criminal threshold; check time/exception. |
| NY_LENDER_LICENSE_340_OUT_OF_SCOPE_FOR_30K_CONSUMER | NY Banking Law §340 | EV12 | This section's personal-purpose loan licensing perimeter states principal **$25,000 or less** and separately $50,000 or less business/commercial loans, with by-way-of-business and occasional-transaction exclusions. On the assumed $30,000 personal-purpose loan, do NOT assert s340 license offence solely from allegation 'not accredited'. Reassess actual agreement and other laws if facts differ. |

## US federal offence candidates

| ID | Authority | Events | Elements / federal jurisdiction |
|---|---|---|---|
| US_SSA_FALSE_OR_CONCEALED | 42 USC §408(a)(2),(3),(4) | EV14,EV15 | Only if Social Security Act Title II payment: specific material false statement OR knowing relevant change/death concealed with fraudulent intent to keep unauthorized payment. Identify payment and who applied/received; post-death beneficiary payments can have lawful amounts due. |
| US_SSA_REP_PAYEE_MISUSE | 42 USC §408(a)(5) | EV13,EV15 | If a representative payee applied for and received payments for P's benefit, knowingly/wilfully converted funds to an unauthorized other use; role not assumed. |
| US_FEDERAL_PROPERTY_THEFT | 18 USC §641 | EV14,EV15 | Knowingly stole/converted federal property or received with statutorily required knowledge; determine whether money remained property of US, not just assume all deposited private funds are federal. |
| US_BANK_FRAUD | 18 USC §1344 | EV13,EV15 | Knowingly executed scheme to defraud qualifying financial institution OR obtain bank-controlled funds through false pretenses; need actual bank interaction and scheme. |
| US_WIRE_FRAUD | 18 USC §1343 | EV01,EV09,EV13,EV15 | Actual fraud scheme, wire communication in **interstate or foreign commerce** to execute it; local phone call alone is insufficient to assert federal jurisdiction. |
| US_AGGRAVATED_IDENTITY_THEFT | 18 USC §1028A | EV13,EV15 | Knowingly uses/possesses/transfers another's identifier without lawful authority DURING AND IN RELATION TO an enumerated predicate felony. Mere card custody inadequate. |
| US_CONSPIRACY_US | 18 USC §371 | EV14,EV15 | At least two persons conspired to commit offense against / defraud US, overt act to effect object. Do not infer from plural pronoun 'they'. |

**Do not equate private/occupational/foreign pension with US Social Security.** Social Security Administration permits certain amounts due a deceased person to go to family or an estate representative. Payments over a five-year period would require careful entitlement/reconciliation; each transfer and claimant must be evidence-bound.

## Mandatory false-positive tests

1. REAL COUNCIL / TRUE ROOF ISSUE: T actually is authorised city officer and genuine notice exists -> impersonation/false representation cannot be marked proved.
2. LAWFUL LOAN: 2707% is incorrectly reported, nonannual, or lawful exempt transaction -> no criminal usury conclusion without verified annual effective rate and statute exception screening.
3. LENDING LICENCE TRAP: $30k personal loan does not automatically fall under NY Banking Law §340's $25k consumer limit.
4. VULNERABLE ELDER TRAP: AGE 95 + Alzheimer's does not by itself prove incapacity, statutory caregiver status, physical injury or causation of death.
5. SCHEME TRAP: only one victim in case; §190.60 and §190.65 cannot be established by high dollar value alone.
6. CARD TRAP: handed over voluntarily and used only with actual authority -> no identity theft established from custody.
7. SOCIAL SECURITY TRAP: beneficiary had a lawful amount payable at death; some post-death payment is not automatically fraud; private pension isn't Title II.
8. FEDERAL WIRE TRAP: telephone is not automatic interstate use.
9. CONSPIRACY TRAP: 'friends', presence together and plural 'they' do not demonstrate agreement or overt act.
10. THREAT TRAP: threat of care-placement must be tested against the enumerated feared consequences in §135.60; no generic all-purpose coercion.
11. ROOF TRAP: authorised, supervised demolition as first stage of replacement may not be criminal mischief.
12. TIME TRAP: legislation currently published does not automatically apply to the unknown historical offence dates.

## Source anchors — authoritative public sources checked 2026-10-30

**State criminal:** New York State Senate Open Legislation
- https://www.nysenate.gov/legislation/laws/PEN/155.05
- https://www.nysenate.gov/legislation/laws/PEN/155.30
- https://www.nysenate.gov/legislation/laws/PEN/155.35
- https://www.nysenate.gov/legislation/laws/PEN/155.40
- https://www.nysenate.gov/legislation/laws/PEN/190.25
- https://www.nysenate.gov/legislation/laws/PEN/135.60
- https://www.nysenate.gov/legislation/laws/PEN/135.65
- https://www.nysenate.gov/legislation/laws/PEN/170.10
- https://www.nysenate.gov/legislation/laws/PEN/170.25
- https://www.nysenate.gov/legislation/laws/PEN/190.40
- https://www.nysenate.gov/legislation/laws/PEN/190.42
- https://www.nysenate.gov/legislation/laws/PEN/145.00
- https://www.nysenate.gov/legislation/laws/PEN/145.10
- https://www.nysenate.gov/legislation/laws/PEN/190.78
- https://www.nysenate.gov/legislation/laws/PEN/190.80
- https://www.nysenate.gov/legislation/laws/PEN/190.81
- https://www.nysenate.gov/legislation/laws/PEN/105.00
- https://www.nysenate.gov/legislation/laws/PEN/105.05
- https://www.nysenate.gov/legislation/laws/PEN/105.20
- https://www.nysenate.gov/legislation/laws/PEN/190.60
- https://www.nysenate.gov/legislation/laws/PEN/190.65
- https://www.nysenate.gov/legislation/laws/PEN/260.31
- https://www.nysenate.gov/legislation/laws/PEN/260.32
- https://www.nysenate.gov/legislation/laws/PEN/260.34

**City/state regulatory:**
- https://www.nyc.gov/assets/dca/downloads/pdf/businesses/DCAInspectionChecklist_HomeImprovement.pdf
- https://www.nyc.gov/site/dca/consumers/shopping-services-home-improvement.page
- https://portal.311.nyc.gov/article/?kanumber=KA-01808
- https://www.nysenate.gov/legislation/laws/GBS/349
- https://www.nysenate.gov/legislation/laws/GOB/5-501
- https://www.nysenate.gov/legislation/laws/BNK/14-A
- https://www.nysenate.gov/legislation/laws/BNK/340

**Federal code / federal agency:**
- https://uscode.house.gov/us/usc/119-120/t42/s408/
- https://uscode.house.gov/us/usc/t18/s641/
- https://uscode.house.gov/us/usc/t18/s1343/
- https://uscode.house.gov/us/usc/119-118/t18/s1344/
- https://uscode.house.gov/us/usc/t18/s1028A/
- https://uscode.house.gov/us/usc/119-118/t18/s371/
- https://www.ssa.gov/faqs/en/questions/KA-02101.html

## Qualification / handoff

Expected state: `INVESTIGATIVE_CANDIDATE` for applicable named offences and `ELEMENTS_UNKNOWN` for criminal liability on uncorroborated narrative. No homicide inference from EV14. Fail closed for contested status, missing event date, and unsupported identity. Strictly separate NYC licence/consumer regulation, NY state criminal law, US federal offences, and civil GBL §349. Rule-definitions independent of Mr/Mrs identity. Reuse the stable 15 case events and Reasoned Thought provenance/scope/warrant machinery, not a US-specific case parser.

**Execution status:** Research document only. No ooRexx implementation/native test. No US statute bulk source fetched or XML copied; preserves earlier UK source security coordination.
