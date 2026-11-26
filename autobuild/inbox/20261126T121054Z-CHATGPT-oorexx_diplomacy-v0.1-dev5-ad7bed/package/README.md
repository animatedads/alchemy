# ooRexx Diplomacy v0.1-dev5 — deterministic competition phase controller

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
Determinism regressions: CD-NAME-TIEBREAK and CD-NAME-CONTROL use English
province names; bad_last_order_holds and retreat-duplicate test last-wins;
winter-double-coast-build tests first-legal. Reversed insertion tests reverse
directory keys, never the player's submitted order-array order. Published
results and tie-breaking traverse sorted keys, not .Directory iteration.

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

The Architect confirmed the two pending interpretations (2026-11-26):
- NONADJACENT_ARMY_MOVE=CONVOY_IF_PHYSICAL_ROUTE: nonadjacent coastal army
  order need not say VIA CONVOY if a physical convoy route exists. It
  succeeds only with matching convoy orders and an undisrupted route;
  no route is INVALID:BAD_CONVOY; physical route but no matching convoy
  orders is FAILS.
- SUPPORT_REACH=PROVINCE: support is geometrically to the province, not
  the coast accessible to the supporting fleet. The actual supported
  fleet origin/destination coast must still be literal, and the target
  move must match exactly. F RUM S F CON - BUL/SC is valid.

Both are existing resolution behavior, now explicit in the config and
validator and covered by five additional end-to-end regressions.
The historical audit in evidence/LITERAL-AUDIT.md records the questions
and the Architect's resolution.

## Qualification

Run `sh tests/run.sh` with rexx on PATH and ALCHEMY_REPO_ROOT pointing to the
estate checkout; uses hash-pinned estate SourceLinter before native suites.
Exact supplied ooRexx 5.3.0 r13196. Dev4r2 had 2934 assertions, 220 positions.
Dev4r3 reruns all existing suites with the updated strict expectations and
adds parser and end-to-end coast tests: 3055 assertions, 225 positions,
zero failures and lint zero. Dev4r4 adds five original movement cases and
28 checks: 3083 assertions, 230 positions, zero failures, lint zero.
Results: evidence/native-evidence.txt.
Dev4r5 is a qualification-only release: all four production classes and
rules.conf are byte-identical to dev4r4. DATC v3.4 F.28 and F.29 are
independently transcribed from the published source (not Claude's archive).
The two cases add 228 checks including every unit's outcome and published
order status, all initial
province occupancies/dislodgements, and all six F.28 retreat-option sets.
Exact native gate: 3311 assertions across 232 positions; zero failures;
all 10 source/test files and 4 supplemental stress scripts lint clean.
The suite remains selective; not full DATC conformance. Claude's original stress scripts and F.28/F.29 block are now recovered
from REQ-00006293/295/297; exact supplied hashes verified. The original ZIP
itself was not recovered. See evidence/CLAUDE-REQUALIFICATION.md.

Claude's independent review of dev4 (REQ-00006189) passed subject to F1;
dev4r1 corrected F1 and dev4r2 recorded F2. The 98,000-position independent
stress evidence belongs to dev4; the 20,000-fixture mutation audit previously
published applies to dev4r2. Fresh dev4r3 audit: 20,000 fixture mutations (10,000 mixed, 10,000 convoy),
zero failures, 1393 paradox cases. See evidence/LITERAL-AUDIT.md.
Dev4r4 records the ruling without changing the parser or movement solver.
Fresh dev4r4 mutation audit: 20,000 trials, zero failures, 1330 paradox
trials (347 mixed, 983 convoy). See evidence/confirmed-stress-*.txt.
Claude independently reran dev4r4 after our original audit: 3083 checks,
all ten reviewer v3.4 movement cases, three seasonal cases, 90000 random
positions and 8000 mutation trials, zero failures; 1355 paradox trials.
His interpreter was his GitHub mirror-head build of 5.3.0, not r13196.
The exact production bytes in dev4r5 are the same, but dev4r5 itself is a
qualification-only package that Claude has not independently re-run.
The hash-verified reviewer scripts are review/fuzz.rex and review/mutate.rex;
review/run-claude-qualification.sh reproduces the addendum 7 runs, using
the assembled ten-case combined file with competition strict expectations.
review/run-stress.sh reproduces the separate ChatGPT-authored 36000-trial
supplemental campaign. Both campaigns completed: 36,000 ChatGPT-authored trials plus 33,000
reviewer-authored tool trials, zero failures, 2621 paradox trials.
See evidence/STRESS-QUALIFICATION.md and raw logs. Neither is a complete
mathematical oracle.
The above qualification applies to dev4r5's referee; the four production
referee classes and rules.conf remain byte-identical in dev5.

## Step 5: game loop and replay

The competition phase controller is separate from the existing referee.
Defaults: 1901–1925, solo 18 owned centres after the Fall retreat phase.
Lifecycle settings are in data/game.conf (referee policy stays in rules.conf).
Movement, retreat, ownership and adjustments are delegated unchanged.
Surviving players each receive one detached public-state/own-task snapshot
for movement; retreat calls only for dislodged powers, adjustment calls only
for nonzero quotas. No legal-move list or referee access is exposed; no
opponent's current submissions appear in the view. A source returns
(status, array of raw order lines); failed, timed-out and malformed calls
provide no orders. Actual endpoint time limits belong to the later engine plug-ins.
No prompt or press is implemented in this increment.

Use the estate's Logging v0.7 via LogService and an INTERNAL target.
The replay projection is a line grammar, with raw order/response bytes
hex-encoded to preserve case, spacing and separators exactly. Every phase,
order call (including empty/failed), published result, unit/centre state,
dislodgement, standoff, paradox, automatic removal and year tally is recorded;
map, exact rule text and seed are recorded in the header. Wall-clock metadata
and process identities are not in canonical replay bytes. A referee failure
logs ERROR and stops without publishing that phase or a successful END.
The command runner refuses to overwrite an existing journal. Replay consumes
only logged calls, re-adjudicates through the same referee and compares all
bytes of the regenerated journal, not just a final board.

Run from package root with ooRexx 5.3.0 r13196 and REXX_PATH containing
src, tools and estate packages/oorexx_logging_v0.7/src:

    rexx tools/game.rex run HOLD 7 hold.log
    rexx tools/game.rex replay hold.log hold-replay.log
    rexx tools/game.rex run RANDOM 20261126 random.log
    rexx tools/game.rex replay random.log random-replay.log

The test stubs are deliberately weak, not competitive prompts. The random stub
uses one local Park-Miller PRNG seeded per game. Public map adjacency only,
no referee-derived move eligibility. Replay does not call the stub or PRNG.
Canonical event logs are internal evidence, not player input.
The main native test script now runs the referee suite and the step-5 game
gate, including 125 phases each in hold/random games, byte-identical replay,
directed retreat/build/solo cases, failure fallback, snapshot isolation and
tampered journal detection. Step 6 press, step 7 live engines, prompt
evolution and tournament remain outstanding.
