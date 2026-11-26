# ooRexx Diplomacy v0.1-dev4r1 — reviewed referee correction

Architecture: Tom Dyer. Implementation: ChatGPT (GPT-6.2).
Controlling brief REQ-00006103; addenda 1–6 REQ-00006105, 06117, 06119,
06121, 06123, 06125. Independent reviewer: Claude.

## Implemented

Retains dev2 board and parser (official Autobuilder PASS). Map 75 provinces,
34 centres, six split-coast graph nodes, 22 initial units; static order
validation and duplicate handling. Dev3 adds DiplomacyAdjudicator,
DiplomacyMovementCalculation, DiplomacyGuessTrial and DiplomacyMovement.

`judge = .DiplomacyAdjudicator~new(board, 'data/rules.conf')`
`movement = judge~movement(units, submitted)`

Units: directory keyed by province; values are DiplomacyUnit objects.
Submitted: directory keyed by power, values arrays of original order lines.
The referee validates and resolves simultaneously; no player legal-order API.
The result exposes units, dislodged (original unit, attacker origin, attacker convoy flag), outcomes,
standoffs, paradoxes and published (power, original line, status) records.
Board input and raw order arrays are unchanged. Missing/invalid orders hold;
physically impossible convoy routes are distinguished from unmatched convoy
orders on a route that could physically exist. Army/fleet coast geometry,
support matching/cutting, self-dislodgement, head-to-head strength, circular
movement, multi-route convoys, Szykman paradox backup, and published outcomes
are included. Final decisions are checked against the equations except for
explicit paradox overrides. A bounded unresolved calculation fails closed.

## Dev4 season API

`options = judge~retreatOptions(movement)` (referee-only, never a player API)
`retreatState = judge~retreats(movement, submitted)`
`ownership = judge~initialOwnership`
`ownership = judge~afterFallRetreats(ownership, retreatState)`
`winter = judge~adjustments(retreatState~units, ownership, submitted)`

Retreats reject occupied and contested provinces and the land attacker's
origin; convoyed attacker origins are allowed if otherwise available. All
valid retreat orders to one province collide, even on different coasts.
Missing/invalid orders disband; explicit disbands succeed. Winter accepts
legal builds/waives and disbands within each power's quota, and handles
mandatory missing disbands deterministically. Ownership is retained when
vacant, changed by occupying units only after Fall retreats. The caller is
responsible for phase sequencing. Result: units, removed, outcomes, published
(power, original line, status), automatic (owner, type, location, reason).
The referee does not mutate input units or ownership.

Three rule interpretations are explicit in the single rules file: convoy
attacker origin may be a retreat destination (DATC 4.A.5 preferred option),
civil disorder uses shortest graph distance over land and sea to owned
centres (DATC v3 4.D.8 preference, 2023 clarification rather than a literal
2000 reading), and excess adjustments are processed first legal (DATC 4.D.4–6).
Distance ties disband fleets before armies, then alphabetical English province name (Claude review F1).
Duplicate orders for existing units use last-wins; duplicate builds are
first-legal because no unit exists yet. Claude independently confirmed these three interpretations as DATC v3.4 preferred choices.

## Qualification

Run `sh tests/run.sh` with rexx on PATH and ALCHEMY_REPO_ROOT pointing to the
estate checkout; uses hash-pinned estate SourceLinter before native suites.
Interpreter: ooRexx 5.3.0 r13196 supplied debug build. Board 513, reference
933, parser 180, original movement 147, DATC-derived movement 582, DATC
season 368, additional season 117: dev4 baseline 2840 assertions. Dev4r1 adds 43 movement and 36 seasonal
assertions: 2919 total. 218 movement or season positions (32+130+36+11+6+3); season includes full H, I, J positions
under selected policies plus B.14 and separate F.7 retreat check. Test
runner prints the one rules config. The assertions are selective, not an
exhaustive formal proof of DATC conformance. See evidence/DATC-PROVENANCE.md.

## Review gate and correction

Claude (Opus 5.5), REQ-00006189, passed the step-4 gate subject to F1:
civil-disorder final ties by English province name. This maintenance release
applies that correction only. The six available passing v3.4 movement
additions and all three seasonal review fixtures are included in the normal
runner; the original qualified v3.0 corpus remains unchanged.

The DATC-preferred B.16/B.17 fixtures are retained separately as known
disagreements, NOT asserted to pass. Existing strict support-coast behavior
is unchanged pending Tom's F2 ruling. F.28/F.29 and Claude's stress tools
are in the review archive not available in this checkout; his independent
98,000-position stress run applies to dev4, not a fresh run on dev4r1.
See evidence/REVIEW.md for details. No game loop, press, prompt evolution,
tournament code, or competitive prompts are added here.
