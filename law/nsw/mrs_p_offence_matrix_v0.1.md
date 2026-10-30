# NSW / Commonwealth offence-candidate matrix: Mrs P roof / credit / pension
**Research snapshot:** 2026-10-30. **Jurisdiction hypothesis:** Newtown, Sydney, New South Wales, Australia. **Scenario:** same user-supplied and uncorroborated facts as `docs/architecture/fixtures/mrs_p_roof_credit_pension_v0.1.json`. **Status:** CANDIDATE-ONLY; not legal advice, not proof of charges, conviction, causation or legal incapacity. Event dates not supplied; do not run as-at-law determination.

## Invariants
1. Event kinds and identities EV01–EV15 DO NOT CHANGE on jurisdiction switch. Swap UK offence rule pack for NSW plus Commonwealth rules, preserving event/claim/evidence IDs.
2. Every factual assertion originates in the user's scenario; evidence items remain empty until independently verified.
3. Date unknown means every law has applicability_as_at_event=UNVERIFIED. This document cites recent sources, not necessarily the historically operative version.
4. Distinguish criminal statutory offences, common-law offences, civil regulatory contraventions and safeguarding flags.
5. Never attribute the unresolved 'they' in EV15 to S/T/J/H without independent proof.

## Candidate rule inventory (DO NOT claim any has been established)
| Rule ID | Jurisdiction / section | Event links | Proposed element checklist / gates |
|---|---|---|---|
| NSW_FRAUD_192E | Crimes Act 1900 (NSW) s192E | EV02,EV03,EV07,EV09,EV11,EV12,EV15 | deliberate/reckless deception, dishonesty, actual obtaining property/advantage or financial disadvantage caused by deception; correct actor, actual money flow |
| NSW_FALSE_STATEMENT_192G | Crimes Act 1900 s192G | EV03,EV07,EV08 | false/misleading in material particular, dishonestly made/published, intention to obtain property/advantage or cause disadvantage; need not assume money moved |
| NSW_BLACKMAIL_249K | Crimes Act 1900 s249K (defs ss249L-O) | EV08,EV09,EV11 | intentionally made unwarranted demand with menaces, requisite intent to obtain gain / cause loss or influence public duty, vulnerability-awareness if relevant; distinguish threat from actual statutory menace |
| NSW_LARCENY_117 | Crimes Act 1900 s117 / common-law elements | EV09,EV13 | taking property of another without lawful entitlement, dishonesty/fraudulent intent, intent permanently deprive; may be alternative to fraud |
| NSW_FORGERY_253_255 | Crimes Act 1900 ss253-255 | EV06,EV07 | actual FALSE DOCUMENT, making/use/possession, knowledge when required, inducing acceptance as genuine and specified financial/property advantage or public duty; mere suspicious ID not proof |
| NSW_ID_INFO_192J_192K | Crimes Act 1900 ss192J/K | EV13,EV15 | dealing/possession of card/ID information PLUS intention to commit or facilitate an indictable offence |
| NSW_DAMAGE_195 | Crimes Act 1900 s195 | EV10 | intentionally/recklessly damaged another's property; what was authorised, roofing survey, repair/completion, legal entitlement |
| NSW_MONEY_LAUNDER_193B | Crimes Act 1900 s193B | EV09,EV12,EV15 | identify actual proceeds of a crime, a distinct dealing, and relevant knowledge/recklessness and other qualifying mental element; NOT automatic from obtaining money |
| NSW_INTIMIDATION_13 | Crimes (Domestic and Personal Violence) Act 2007 s13 | EV08,EV11 | stalk/intimidate AND intend fear of physical or mental harm, which can include knowledge conduct likely cause fear; mere financial pressure alone insufficient |
| NSW_CONSPIRACY_COMMON_LAW | common-law conspiracy / conspiracy to defraud | EV04,EV05,EV11,EV12 | agreement by at least two specific persons to criminal course, intention to carry out; friendship and coincidence inadequate |
| CTH_CREDIT_UNLICENSED_29 | National Consumer Credit Protection Act 2009 (Cth) s29 | EV11,EV12 | credit activity covered by licensing perimeter, actual person/provider, Australian credit licence/representative and exemption, date; cannot swap in UK's FCA concept |
| CTH_CREDIT_RATE_32A | National Credit Code Sch1, s32A (and 32B calculation) | EV12 | covered credit contract; statutory annual cost rate above 48% on section 32B methodology; exceptions e.g. ADI/low-cost/small amount/bridging, and at-date law; alleged '2707%' not automatically APR |
| CTH_CREDIT_SOURCE_140 | National Credit Code Sch1, s140 | EV11 | supplier REQUIRED buyer to apply for/obtain credit from a particular credit provider in context of a covered purchase; recommendation/pressure alone may not suffice |
| CTH_CREDIT_HARASSMENT_155 | National Credit Code Sch1, s155 | EV11 | credit provider or supplier harassed person to apply for credit/enter credit contract or related transaction; actual conduct beyond bare adjective 'pressured' |
| CTH_SSA_215_217 | Social Security (Administration) Act 1999 (Cth) ss215,217 | EV14,EV15 | obtain social security payment KNOWING it is not payable or only partly payable, actual claimant/recipient, amount, scheme, dates |
| CTH_SSA_216_217 | Social Security (Administration) Act 1999 (Cth) ss216,217 | EV14,EV15 | payment obtained by impersonation / fraudulent device or relevant false statement with recklessness, causal payment and named person |
| CTH_FRAUD_134_2 | Criminal Code Act 1995 (Cth) Sch, s134.2 | EV14,EV15 | by deception dishonestly obtain financial advantage FROM COMMONWEALTH ENTITY, identify who got it, no default assumption about payee |
| CTH_CONSPIRACY_135_4 | Criminal Code s135.4 | EV14,EV15 | two persons conspiring with intent to dishonestly gain from / cause loss to Commonwealth entity; agreement must be proved |
| NSW_BUILDING_UNLICENSED_4 | Home Building Act 1989 (NSW) s4 | EV02,EV10 | actual residential building work within licensing requirement/value thresholds, contract identity and contractor licence check; separate from fraud |
| CTH_ACL_FALSE_SERVICE_151 | Australian Consumer Law Sch2 to Competition and Consumer Act 2010, s151 | EV02,EV03,EV07 | false/misleading representation in trade or commerce about services, affiliation/approval, price, etc; check exactly enumerated representation branch and mental/default elements |
| CTH_ACL_MISLEADING_18_CIVIL | Australian Consumer Law s18 | EV02,EV03,EV07 | misleading or deceptive conduct in trade or commerce; generally civil, NOT itself a criminal offence |
| CTH_ACL_UNCONSCIONABLE_21_CIVIL | Australian Consumer Law s21 | EV03,EV08,EV11,EV12 | unconscionability in connection with goods/services, vulnerability/undue influence/pressure; civil/regulatory, NOT itself a criminal offence |

## Particular cautionary gaps
- **Council ID:** no general allegation of 'impersonating a council officer' should be inferred from an offence specific to impersonating police. Test NSW forgery/fraud/false statement against proof the document and representation were false, and confirm the actual council and authorisation.
- **Elder capacity:** reported age 95 and Alzheimer's are characteristics with source claims; they do NOT amount to automatically proven incapacity or absence of consent at the transaction.
- **Roof:** removal could be authorised preparatory demolition, legitimate building work or damage. Need inspection, consent and licence.
- **2707%:** reported number with NO basis (per annum/effective/nominal/term/compounding/fees). Obtain signed loan, amortisation and ledger before applying s32A; $30k is not itself a 'small amount credit contract'.
- **Post-death pension:** Social Security (Administration) Act 1999 s58 permits payment of an amount already payable at death to an entitled applicant under conditions. Distinguish Commonwealth Centrelink Age Pension, veterans' benefits, superannuation, other private pension, estate rights, and benefit payments not lawfully due. The scenario has unresolved 'THEY'; do not name a recipient.
- **Death:** no cause or evidence that any participant caused death. Do not infer manslaughter/homicide from sequence. Safeguarding concern is not a substitute for homicide elements.
- **Conspiracy:** separate criminal agreement claim from friendship/meeting/financial connection. For Commonwealth s11.5 conspiracy also check its overt-act and predicate requirements.
- **Cross-jurisdiction source:** NSW state offences and federal offences can both be candidate tests; do not merge or label same section as UK offence.

## Source material (pin at application date)
NSW primary and judicial:
- NSW Crimes Act 1900, current PDF: https://legislation.nsw.gov.au/view/pdf/inforce/whole/act-1900-040
- NSW Judicial Commission fraud explanation: https://www.judcom.nsw.gov.au/publications/benchbks/criminal/fraud.html
- NSW Judicial Commission blackmail: https://www.judcom.nsw.gov.au/publications/benchbks/criminal/blackmail.html
- NSW Judicial Commission conspiracy: https://www.judcom.nsw.gov.au/publications/benchbks/criminal/conspiracy.html
- NSW Judicial Commission state and Commonwealth fraud: https://www.judcom.nsw.gov.au/publications/benchbks/sentencing/fraud_offences.html
- NSW Home Building Act 1989: https://legislation.nsw.gov.au/view/pdf/inforce/whole/act-1989-147
- NSW Fair Trading licensing: https://www.fairtrading.nsw.gov.au/help-centre/online-tools/home-building-licence-check
- Crimes (Domestic and Personal Violence) Act 2007: https://legislation.nsw.gov.au/view/pdf/inforce/whole/act-2007-080

Federal primary:
- National Consumer Credit Protection Act 2009 (s29, Sch1 ss32A, 140, 155; compilation as of 2026-06-30): https://www.legislation.gov.au/C2009A00134/2026-06-30/2026-06-30/text/original/epub/OEBPS/document_2/document_2.html
- National Consumer Credit Protection Act 2009 (s29 in Vol 1; exact compilation reference): https://www.legislation.gov.au/C2009A00134/latest
- Social Security (Administration) Act 1999 (s58 2026-09-19): https://www.legislation.gov.au/C2004A00580/2026-09-19/2026-09-19/text/original/epub/OEBPS/document_1/document_1.html
- Social Security (Administration) Act 1999 (ss215–217): https://www.legislation.gov.au/C2004A00580/latest
- Criminal Code Act 1995 (Cth) s134.2 and s135.4: https://www.legislation.gov.au/C2004A04868/latest
- Competition and Consumer Act 2010, ACL Sch2 ss18,21,151 (2026-08-27): https://www.legislation.gov.au/C2004A00109/2026-08-27/2026-08-27/text/original/epub/OEBPS/document_4/document_4.html

## Qualification instructions for Claude
Create one NSW+CTH rule pack consuming the unchanged `mrs_p_roof_credit_pension_v0.1.json` event IDs, with subject-specific scoped condition matching, source-version and event-date checks, and NO events rewritten to suit offence names. Expected baseline outcome for every criminal offence: `ELEMENTS_UNKNOWN` / conditional investigative candidate because the source narrative is uncorroborated and timestamps unknown. Assert s18 and s21 never mislabelled criminal. Assert s58 payment-after-death exception is considered. Negative fixture: legitimate roof work and genuine council, lawfully compliant licensed credit, bank card used with authority, authorised estate payment. Preserve all legal provenance. Nothing in this document constitutes engine implementation or native test PASS.
