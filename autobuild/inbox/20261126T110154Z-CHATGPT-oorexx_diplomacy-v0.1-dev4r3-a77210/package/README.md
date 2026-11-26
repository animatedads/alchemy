# ooRexx Diplomacy v0.1-dev4r3 — literal coast contract

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

## Literal order contract (Architect correction, REQ-00006237)

Every fleet reference to a split-coast province must name its actual or
intended coast, including origin, move destination, support target,
supported fleet destination, retreat, build and disband. Missing coast =
NO_COAST; explicitly wrong coast = BAD_COAST. Armies never carry a coast.
No coast inference, even if only one coast is reachable. Case and spacing
remain forgiven; the original line is always preserved. Support-move matching
compares literal destinations, not province-only wildcard matches.
Invalid movement/assistance holds; invalid retreat is removed under the
existing retreat rule; an invalid winter disband does not satisfy the
quota and may trigger civil disorder.

### Deliberate DATC departures and policy choices

- B.2: formerly inferred the uniquely reachable coast; now invalid.
- B.7/B.8/B.15: omitted supported fleet destination coast invalid; opposing
  correctly specified supported moves now succeed.
- B.16/B.17: wrong supported fleet origin coast invalid. Board outcomes
  unchanged from dev4r2; diagnostic is now BAD_COAST per addendum 11.
- B.1 and D.30: already invalid ambiguous omission; explicit NO_COAST.
- B.3/B.10/B.11/B.12: explicit wrong coast remains invalid.
- G.1/G.5-G.7/G.9/G.11/G.19: adjacent army moves land unless VIA CONVOY,
  per existing competition choice; see DATC-PROVENANCE.md.
- Duplicate orders last-wins; builds first legal; all other agreed choices
  remain explicit in data/rules.conf.

Other defaults and province-level legality are listed in
evidence/LITERAL-AUDIT.md for Tom to rule on, not silently changed.

## Qualification

Run `sh tests/run.sh` with rexx on PATH and ALCHEMY_REPO_ROOT pointing to the
estate checkout; uses hash-pinned estate SourceLinter before native suites.
Exact supplied ooRexx 5.3.0 r13196. Dev4r2 had 2934 assertions, 220 positions.
Dev4r3 reruns all existing suites with the updated strict expectations and
adds parser and end-to-end coast tests: 3055 assertions, 225 positions,
zero failures and lint zero. Results: evidence/native-evidence.txt.
The suite remains selective; not full DATC conformance. F.28/F.29 and
Claude's original stress tools are still unavailable locally.

Claude's independent review of dev4 (REQ-00006189) passed subject to F1;
dev4r1 corrected F1 and dev4r2 recorded F2. The 98,000-position independent
stress evidence belongs to dev4; the 20,000-fixture mutation audit previously
published applies to dev4r2. Fresh dev4r3 audit: 20,000 fixture mutations (10,000 mixed, 10,000 convoy),
zero failures, 1393 paradox cases. See evidence/LITERAL-AUDIT.md.
No game loop, press, prompt evolution, tournament, or competitive prompts.
