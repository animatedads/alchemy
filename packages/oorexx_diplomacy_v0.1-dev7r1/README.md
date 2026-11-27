# ooRexx Diplomacy v0.1-dev7r1 — offline player candidate, seeded inbox fairness

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
referee classes and rules.conf remain byte-identical in dev5, dev6 and dev7.

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
Dev5 provided the no-press baseline; dev6 adds the press stage below. No live model prompt or engine is implemented yet.

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
no referee-derived move eligibility. Replay never calls the player stub. With press enabled it regenerates address lists from the logged game seed and verifies the resulting journal bytes.
Canonical event logs are internal evidence, not player input.
The main native test script now runs the referee suite and the step-5 game
gate, including 125 phases each in hold/random games, byte-identical replay,
directed retreat/build/solo cases, failure fallback, snapshot isolation and
tampered journal detection. The original no-press gate explicitly sets P=0, preserving dev5 bytes. Step 7 live engines, prompt evolution and tournament remain outstanding.

## Step 6: press and negotiation

REQ-00006117 supersedes the original shared phase-wide player list. Each
surviving player gets its own independently shuffled permutation of surviving
powers (self included) at the start of EVERY press round. A single logged
game seed initializes the press PRNG; each list and its pre-draw state are
logged. Independent draws may coincide by chance. The framework owns the
list: a callback mutating its detached copy cannot alter routing.

data/game.conf has PRESS_ROUNDS=3 by default. The 3-arg config constructor
retains dev5 compatibility (P=0); the file requires all four settings.
For P>0 the journal is DIPLOG|2 with P in META. Existing DIPLOG|1 no-press
journals remain replayable and the dev5 gate retains its exact hashes.

The press source interface is `source~press(view)` -> array(status, raw
plain-text output). Player snapshot adds ROUND, ROUNDS, PLAYER_LIST (array,
index = displayed number), INBOX (array of individually framed mail strings).
The movement order snapshot receives the last round INBOX, not PLAYER_LIST.
Retreat and adjustment calls receive neither. No opponent's list, current
outputs, private mail, or legal-order suggestions are in the snapshot.

    SEND TO: 2 5
    MESSAGE:
    example body
    END MESSAGE

Keywords are case-insensitive; recipient tokens are decimal numbers.
All addresses use the sender's exact round list, not the recipient's list
or a global list. An out-of-range/non-numeric/empty address (even in a
mixed valid/invalid recipient list) drops the whole message without notice.
Repeated recipients get one copy; self-mail is ordinary mail. At most six
SEND blocks per call, including invalid-address blocks. Only the first six
may deliver; later blocks are dropped and logged. Bodies cap at 1500 UTF-8
code points (invalid bytes count individually); line breaks count, and the
original bytes are retained in the raw-call journal. CRLF/CR line endings
are normalized to LF for framing. A malformed recognized SEND block makes
the whole response unparseable; no partial deliveries. Other text is
ignored by this press-only parser and retained in the raw journal.

All callbacks complete before any delivery. In the original DIPLOG|2
format, mail is presented by sorted
sender, then original SEND block order; recipients are sorted power codes.
Mail sent in round k appears only at round k+1, or in the final order call.
New movement phase starts with empty inboxes. Only the framework stamps the
true sender, recipient list and sequence ID. Body lines starting === are
prefixed with "> "; otherwise content is unfiltered. Syntactic injection
markers (===, SYSTEM:, FRAMEWORK: at line start after stripping) are logged
as an observable metric, not an intent classifier or penalty. No alerts,
bounces, receipts, or warnings. No mail to an actual external mail server.

Logging v0.7 INTERNAL events include PRESS_ROUND, PLAYER_LIST, PRESS_CALL
(raw status/hex output), PRESS_PARSE, MAIL_DROP, MAIL_CUT, MAIL (true sender,
recipient list, marker, capped unescaped body), PRESS_END and PRESS_TOTAL.
Replay consumes recorded press and order calls; regenerates lists, applies
the same parsing and round barrier, re-adjudicates, and compares every byte.
Call/round counters remain separate; phase count is unchanged.

    rexx tools/game.rex run SCRIPTED 7 press.log
    rexx tools/game.rex replay press.log press-replay.log

Step 6 originally stopped short of the player text and engine boundary;
step 7 below adds that offline candidate. Prompt sealing, real model
qualification and tournament metrics remain later gates. In-process stub callbacks are trusted test code,
not an isolation mechanism for arbitrary ooRexx. Player text is data only.
See evidence/PRESS-QUALIFICATION.md and tests/press.rex for the native gate.

## Step 7: offline player/runtime candidate

The existing pinned referee and rules.conf are unchanged. The game now
maintains a detached public-results cursor for each power, advancing only
on a successful call. Thus a power that skips retreats or adjustments
receives the intervening published raw-order results on its next call.
The existing LAST_RESULTS snapshot and historical canonical journal formats
are unchanged; dev7r1 introduces DIPLOG|3 for new seeded inboxes.
No player is told which orders are legal.

`DiplomacyPlayer` is the sole player-side text projection. Each call gets
a fresh fixed SYSTEM instruction followed by that power's designer prompt;
the user text contains RULES, MAP, STATE, LAST RESULTS, PLAYER LIST, INBOX,
MEMORY and TASK in that order. Rules text is supplied explicitly to the
player constructor; it is not inferred from a provider. Raw published
orders and memory lines are quoted. Address lists are populated only in
press; inbox delivery follows dev6. There are no provider conversation IDs.
One shared immutable engine profile is used for every power in a game.

A MEMORY block replaces only its sender's private memory, capped at 8000
UTF-8 characters; absent means retain and empty means clear. Block markers
inside memory, orders or a message body are literal except for their own
end marker. Only SEND blocks in press and ORDERS in an order call can have
effects. Missing required ORDERS, duplicate MEMORY/ORDERS, incomplete
recognized blocks, provider failure or timeout are atomic failures; no
memory update, orders or delivery. Complete out-of-phase blocks are ignored.
Raw order lines, including spaces, go to the unchanged referee. No repair.
Outside text is retained as private visible model output, not hidden
provider reasoning. The operator journal (not replay, not player input)
records call identity, seed, fixed profile, SHA-512 designer-prompt digest,
full rendered system/user/visible output, status, token counts, elapsed
time, other text and truncation. Hex fields preserve literal bytes.
Game/press exceptions are separately diagnosed via estate Logging v0.7.

The provider boundary is `DiplomacyEngine~invoke(system,input)`, built
over a transport `post(provider,body,timeout)` returning
array(status,HTTP status,response body). The profile constructor and
strict five-field file loader require an explicit provider, exact model
ID, effort, max output tokens and timeout seconds. No defaults, alias
selection or retry. The template is deliberately invalid.

| Profile effort | Haiku Messages | Sol Responses |
| --- | --- | --- |
| low | output_config.effort=low | reasoning.effort=low |
| medium | output_config.effort=medium | reasoning.effort=medium |
| high | output_config.effort=high | reasoning.effort=high |

This is a supported-value mapping, not a claim of equal compute. Haiku uses
adaptive thinking; Sol uses store=false, with no previous_response_id.
No temperature/top_p/top_k; no effort=none. The adapters reject model
mismatch, incomplete response, refusal, malformed response or missing/invalid
usage. Only visible assistant text is projected. The configured timeout is
passed to transport. Exact model IDs and equal-budget profile parameters
remain Architect decisions; the test names and budgets are fixtures only,
not pins. The SHA-512 implementation is estate crypto v0.8.3 (native
qualification); prompt sealing/Foreign Runtime provider is step 8.

`DiplomacyCurlTransport` uses fixed HTTPS endpoints, Secret Broker
reference leases, curl stdin configuration (credential never in argv or
request file), shell-free player data, private temporary request/response
files, no redirects or retries and a deadline. The optional live runner
requires the estate SecretBroker v0.2 and its dependencies on REXX_PATH.
Use a private operator directory and restrictive umask. It is NOT an
authorization to spend or a live result:

    umask 077
    rexx tools/live.rex PINNED.profile RULES.txt PROMPT_DIR GAME_ID SEED NEW.log

PROMPT_DIR holds AUS.txt, ENG.txt, FRA.txt, GER.txt, ITA.txt, RUS.txt, TUR.txt.
The designated operator provisions the credential using Secret Broker's
mapped environment provider. The runner is one game year; an operator must
inspect every call status before declaring the real gate passed.

The gate adds Claude's independent rich player and auditor (five seeds,
three runs each), and 189 deterministic player-contract assertions including
one full simulated game year (56 independent calls) and byte-identical replay.
Twelve fake-curl transport assertions verify secret separation, actual outer-process deadline, timeout mapping and lease retirement.
N2 arithmetic coercion and N3 separate diagnostics are resolved. N4 empty
movement-task behavior is unchanged, pending the Architect. The independent
570-game PASS is dev5, not dev7. No real model call was made; the live
step-7 gate remains OPEN. No designer prompt sealing, tournament or
claim of equal effort is made in dev7. See evidence/CLAUDE-GAME-REVIEW.md
and evidence/DECISIONS-2026-11-27.md.

## Dev7r1: independent press review P1 — remove seat-order bias

Claude independently passed dev6's mechanics (REQ-00006401) but measured
alphabetical sender order, making AUS always first and TUR always last
in QUIET inboxes. New press games use the recipient's own independently
seeded, already logged permutation from the round just finished to order
the sender groups in that recipient's inbox. Within each sender's group,
original message order remains unchanged. All routing, caps, original
MAIL sequence IDs and canonical delivery events retain their semantics.
A new INBOX_ORDER event records actual ordered message IDs for every
recipient per round, even empty inboxes. No additional RNG draws.
DIPLOG|3 selects the new order for replay; DIPLOG|1 and DIPLOG|2 remain
byte-identically replayable using their original policies. The old P=3
directed and full press tests explicitly select historical SORTED delivery.

Claude's unchanged measuring source and megaphone script are copied from
his published review dev2; their reported hashes are checked. The new
gate independently asserts near-uniform rank in a full 25-year QUIET
game, verifies all 1050 ordered inbox records and byte-identical replay,
and checks directed unequal-volume sender groups. The player protocol
test now exercises the new format. In one-year LOUD scenarios across all
seven seats, the loud sender still occupies 94.9% of quiet opponents'
order-call inbox bytes: legal play, not a seat-specific privilege.
P2 token-efficiency tie-break (opponents can increase received input)
remains for Tom; no scoring change. P3 volume cap stays unchanged.
See evidence/CLAUDE-PRESS-REVIEW.md and evidence/INBOX-ORDER-QUALIFICATION.md.
