# Literal-contract audit — REQ-00006235 / REQ-00006237

Architecture: Tom Dyer. Audit and maintenance: ChatGPT GPT-6.2.
Independent referee review baseline: Claude, REQ-00006189.

Authorised correction implemented: COAST_REQUIRED=ALWAYS and SUPPORT_COAST=STRICT.
Missing split fleet coast NO_COAST, explicit wrong coast BAD_COAST, armies
never carry coast suffix. All six contexts plus army orders covered by
parser tests, and additional movement, retreat and adjustment fixtures.
No implicit coast selection or province wildcard in destination matching.

First run with unchanged expectations exposed exactly 4 DATC movement
outcome changes: B.2, B.7, B.8, B.15. B.16/B.17 retain strict board results,
with required diagnostic changing BAD_SUPPORT to BAD_COAST. The original
added split_coast_support_without_coast position changes to bounce; matching
explicit-coast control added. All old seasonal expectations unchanged.

## Other defaults, interpretation and recovery — sent for Architect ruling

Source line references are for dev4r3; no changes below beyond the specific coast
rule authorised by REQ-00006237.

| File / lines | Existing behaviour | Audit judgement |
|---|---|---|
| DiplomacyOrderParser.cls:83-89 | Referee caller defaults to MOVEMENT; accepts case, tabs, spacing, inserts token spacing around literal hyphen. Raw preserved. | Case/spacing expressly authorised; phase derives from caller, not player text. |
| DiplomacyOrderParser.cls:224-228; DiplomacyAdjudicator.cls:132-150 | Non-adjacent coastal army move can be convoyed without literal VIA CONVOY if a physical route exists; adjacent army defaults to land absent VIA. | The non-adjacent implicit convoy is the major remaining possible leniency. Existing adjacent-land policy is explicit; request ruling whether VIA required for every convoy move. |
| DiplomacyOrderParser.cls:174-182,314-323 | Support reachability is province-level, including fleet that reaches a different coast from explicitly named target coast; exact named supported move now must match. | No coast is guessed, but province-level support eligibility is a possible rule choice. Existing example F RUM S F CON - BUL/SC stays valid despite RUM touching BUL/EC only. Request ruling, do not silently change. |
| DiplomacyOrderParser.cls:343-371 | Last recognizable owned-unit order supersedes earlier even if malformed, wrong type or wrong coast; duplicate key is province. | Explicit last-wins rule. No executing repaired text; invalid final order falls back to hold/removal. Confirm if desired under contract rule. |
| DiplomacyAdjudicator.cls:109-124,132-141 | Initial implicit hold for every unit; invalid/absent movement orders remain holds; physical convoy impossible => invalid + hold. | Expressly authorised fallback, not a corrected order. |
| DiplomacyAdjudicator.cls:155-164 | Support hold applies to any non-moving target (including support/convoy and default hold); actual order may be missing/invalid. | Ordinary support-of-nonmovement contract interpretation; not actual text correction. Flag for review. |
| DiplomacySeason.cls:65-100 | Invalid/absent retreat => automatic removal; no inferred destination. | Expressly authorised seasonal fallback, not holding a dislodged unit. |
| DiplomacySeason.cls:205-250 | First legal builds/waives within quota, missing order permits no build; missing mandatory disband triggers deterministic civil disorder. | Expressly authorised seasonal fallback; no invented player order. |
| DiplomacyBoard.cls:42-45; movement/season occupancy keys | ProvinceOf strips suffix for occupancy, collision and adjacency of armies; unit location retains explicit coast. | State representation, not coast repair. |

Conflict/duplicate rule precedence: state errors (NO_UNIT, NOT_OWN_UNIT, WRONG_TYPE)
may win over coast diagnostics when a line contains multiple faults, as before.
Other errors are not "repaired". An explicit support destination which is not
the target's actual order does not match; it is not redirected. Validity of an
otherwise well-formed unmatched support is distinct from success.

## Exact native evidence

All suites rerun on r13196: 3055 assertions / 225 movement and seasonal
positions, zero failures, hash-pinned lint clean on 10 production/test files.
New parser tests: 242 checks, all 12 invalid codes exercised.
Fresh dev4r3 fixture mutation audit using unchanged ChatGPT harness
SHA-256 a54b8258b614d6d9e55016bba9efcf8c3e4d22f0626ef51552ae38c79bd332d0,
lint 0 findings. 10,000 MIXED seed 261126 (381 paradox trials), 10,000 CONVOY
seed 261127 (1012 paradox trials), no exceptions or invariant failures.
Not an oracle or unique board count; independent Claude stress evidence
remains specific to dev4. Reproduce from this package root (after lint):
  REXX_PATH="$PWD/src:$REXX_PATH" rexx review/literal-mutate.rex 10000 261126 MIXED
  REXX_PATH="$PWD/src:$REXX_PATH" rexx review/literal-mutate.rex 10000 261127 CONVOY
Raw logs evidence/literal-stress-mixed.txt and evidence/literal-stress-convoy.txt.
F.28/F.29 remain unavailable locally, not asserted as tested.

## Architect resolution, 2026-11-26 — dev4r4

Tom confirmed A LON - NWY is legal if any valid convoy route is possible
and that F RUM S F CON - BUL/SC is valid support. The open interpretation
questions above are resolved, no change to parser or movement equations.
NONADJACENT_ARMY_MOVE=CONVOY_IF_PHYSICAL_ROUTE and SUPPORT_REACH=PROVINCE
are now explicit enforced config values. All named fleet references remain
strict; support geographic reach uses the province. New fixtures:
nonadjacent_convoy_north_sea, nonadjacent_convoy_alternate_route,
nonadjacent_convoy_possible_but_unmatched, nonadjacent_convoy_no_route,
support_reach_province_other_coast.

Exact dev4r4 native gate: 3083 assertions / 230 positions, zero failures,
pinned lint zero findings. The five new original movement fixtures contribute
28 assertions. Unchanged mutation harness, same seeds/modes as dev4r3:
10,000 MIXED (347 paradox trials) and 10,000 CONVOY (983 paradox trials).
Total 20,000 fresh fixture mutations, 1330 paradox trials, zero failures.
Raw logs: evidence/confirmed-stress-mixed.txt and
evidence/confirmed-stress-convoy.txt. These are invariant checks, not an
independent oracle; 98,000 independent trials still apply to dev4 only.

## Dev4r5 qualification-only follow-up

The F.28/F.29 gap recorded above was closed by independent transcription
of DATC v3.4 (2026-11-19) and retesting the unchanged production referee.
See DATC-PROVENANCE.md, review/datc-v3.4-sixth-order.txt and
evidence/native-evidence.txt. All four production classes and rules.conf
are byte-identical to dev4r4. Claude independently re-qualified dev4r4 and sent the three exact blocks
via REQ-00006293/295/297 after this audit began. They are hash-verified in
evidence/reviewer-recovered.sha256. Distinguish his reviewer-authored tests
from our independent transcription and ChatGPT-authored stress harnesses.
Historical audit results remain versioned.
