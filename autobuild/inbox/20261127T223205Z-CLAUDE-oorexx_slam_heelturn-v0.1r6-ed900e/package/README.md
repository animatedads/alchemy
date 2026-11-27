# Heel Turn SLAM (oorexx_slam_heelturn v0.1r6): a SLAM that plays Diplomacy

Architecture: Tom Dyer. Code: Claude (Opus 5.5). This README: Claude (Opus 5.5).
Design review on lane `slam-heelturn`: Muse (Meta Muse), REQ-00006411 (Reasoned Thought
tiers for lies, order self-check, CANNOT TELL discipline, tone is not evidence).

Part of the SLAM family. The name is a working name: in wrestling a heel turn is
the moment a partner betrays his partner, which is Diplomacy in one move. Tom Dyer
names SLAM components; rename at will.

Heel Turn is a third runner for the LLM Diplomacy competition, beside Haiku and
Sol. It is given a designer prompt that tells it how to play, exactly as they are,
and it plays: it reads the prompt, assesses the position, writes literal orders,
writes and reads press, judges tone and intent deterministically, and understands
lying (it catches lies against the published orders, and tells them only where
its prompt allows). It never predicts a string. Every answer is a realisation of
a position held in concepts.

## New in v0.1r6 (Tom Dyer's decision, 27 Nov 2026; faults found by Meta Muse)

**Each rule counted once, strongest wording wins.** A setting moves once per
policy.src rule (act|object as policy.src has it) and condition over the whole
prompt. Saying a thing again, or at greater length, does not say it harder;
equal and opposite wordings of the same rule cancel. Before this, repeated
mentions added up: Meta Muse's run of a 119-sentence prompt saturated nine
settings at 1.00 and two at 0.00, so prompt length itself was a weapon and a
short prompt could not compete. "Check every promise", "check each order",
"verify every claim" and "judge by the orders" all hit `distrust|` and count
once. `read_prompt` now shows each hit as COUNTED, REPEAT or CANCELLED, from
one read of the whole prompt, as the engine reads it. Every designer's prompt
reads differently after this and should be run through read_prompt again.

**Reader faults fixed** (Meta Muse's run on the WASM playground; tests written
for them in tests/fixtures/constructs_r6.txt, not taken from any prompt):

| sentence shape | v0.1r5 | v0.1r6 |
| --- | --- | --- |
| "Betrayal is part of the game, and so is lying." | an order to lie, counted twice | a description: not read |
| "Stab only when the gain is two centres, ..., the ally has no fleet near." | stab when **not** gain (the no flipped it) | stab when gain: a not counts only in the clause that names the condition |
| "(2) attacks on an ally only when ..." | an order to attack an ally | the -s form is a noun or a description, never an order |
| "Trust the orders and nothing else." | trust up | trust down: "X and nothing else", X not a power, turns the general act the other way |
| "Judge by the orders, never by the mail." | not read | distrust |
| "Verify every claim." | expand (claim a centre) | distrust: after a determiner, claim is the noun |

Sentences of the shape "When you break a deal, break it ..." stay not read on
purpose: their condition would read as betrayed (the other power broke it).
A not-read sentence is listed; a misread is silent.

Sample prompts: five unchanged; loyal_partner alliance 1.00 -> 0.78 (repeats);
ruthless_liar expand 0.92 -> 0.60 and promises 1.00 -> 0.78 (its "verify every
claim" no longer reads as expand, and "keep your lies consistent" no longer
reads as loyalty).

## New in v0.1r5 (Tom Dyer's decisions, 27 Nov 2026)

**Workload as the token count.** For a SLAM the competition's token count is
"total slam processing time used, so effectively workload over the slam unit".
INPUT_TOKENS is the microseconds Heel Turn spends reading a call (board,
prompt, mail, beliefs, relations), OUTPUT_TOKENS the microseconds it spends
planning and writing; the tie-break's input+output is the call's processing
time. The profile identity names the unit: `SLAM|heelturn-0.1r5|deterministic|us|0`.
The figures go only to the framework's operator audit (beside its own
elapsed), never into the replay journal or the Heel Turn log, so replay stays
byte-identical. They are wall-clock microseconds inside `invoke` on the runner
host; a series is comparable only when its games run on the same kind of host.
(Linux CPU ticks are 10 ms, too coarse for a 30 ms call.)

**Boston Crab testimony policies** (`oorexx_slam_bostoncrab` `testimony.rex`),
on the board, each an UNDERCUT at TESTIMONY tier, so the ground is quarantined
and the promise DISPUTED: CANNOT TELL, played as if not made. Each policy's
reason is kept beside the combiner's verdict (TESTIMONY_POLICY log lines,
`slam_reply` "policy:" lines).

| policy | on the board |
| --- | --- |
| IMPEACHMENT | a power with a documented lie (last `impeachment_years`) has every other claim undercut: its promises and its hearsay |
| ACCOMPLICE (Tom Dyer's definition) | two or more powers shown acting together by the published orders (one supporting or convoying the other's unit; kept as COOP lines) who then present in unison to a party (the same promise, the same warning, this phase) or present a conflicting picture (one warns of the other as a threat while the orders show them cooperating) |
| SELF-SERVING | a promise not to take one of my centres from a power that can reach it (or not to attack me, from a power whose units touch my ground), late in the game (from `self_serving_from_year`) or with the sender near a solo (`self_serving_solo_near` centres): earlier it would leave every neighbour CANNOT TELL |
| PARTIALITY | hearsay against a third power from a speaker who is not my ally |
| AGAINST-INTEREST | an announced move into my ground: noted, never upgraded |

Thresholds are in `data/testimony.src` (late year 1907, solo-near 14 centres,
impeachment two years).

**Fault fixed: Heel Turn forgot its own promises.** The memory loader asked for
13 fields on an OUT line; 12 are written. Every promise Heel Turn made was
dropped at the next call, so a sincere "I will support your F BLA - RUM"
never reached the order call (1902 Fall: `A BUD H`). Since v0.1 the honest
prompts had been breaking their word through no choice of their own, and
`promisedTo` could not stop a second, different offer. Now: `A BUD S F BLA -
RUM`. Truth test 19 writes promises, reloads memory and checks the order
constraints; it fails on the old loader. In the seven-seat game to 1908,
COOPERATION went from 0 to 42 events (kept supports are what the orders show).

**ACCOMPLICE in a Heel-Turn-only game.** Heel Turn writes no warnings about a
third power, so in its own games the unison and conflicting-presentation
checks have nothing to test; truth test 16 covers them. They will meet real
warnings once Haiku/Sol runners are at the table.

## New in v0.1r4 (Tom Dyer's decisions, 27 Nov 2026)

Heel Turn will get a series. Two of the open items were approved and are here.

**Boston Crab reference checks on English orders in press, to aid assessment.**
Boston Crab's order checker (`oorexx_slam_bostoncrab` `order_check.rex`) judges
every definite reference by concept against what writer and recipient can each
identify. Heel Turn applies the same verdict policy to unit references in press
("my army", "your fleet", "Germany's army"), with candidates taken from the
board and narrowed by what the sentence asks of the unit (move into, support
into, support from, hold):

| verdict | on the board | effect on assessment |
| --- | --- | --- |
| CLEAR | one unit fits | the reference is bound to that unit, so the promise becomes checkable against that unit's published order |
| AMBIGUOUS | several of the recipient's units fit | no unit bound; Heel Turn asks "Which of my units do you mean for X?" |
| WRITER AMBIGUOUS | several of the writer's units fit | no unit bound; Heel Turn asks "Which of your units do you mean for X?" |
| NO REFERENT | no unit of that owner and kind can do it | a writer's own promise is bound to no unit: on the board it cannot be done, a DOCUMENTARY lie under the contract rule |

NOT VISIBLE and MEANS DIFFERENT THINGS need private sight. The board is public
to every power, so they cannot arise. Every verdict is logged (REFERENCE|...)
and shown by `tools/slam_reply.rex`. I chose not to drive Boston Crab's story
Reader per message: the board already arrives as concepts, visibility is
public, and `order_check.rex` is a script, not a class to call. The verdict
policy is the part that carries over, attributed here.

**Conditional promises whose condition is checked.** "If you (do not) move
into P / attack me / support me ..., I will ..." stores the condition (NOMOVE:P,
MOVE:P, NOATTACK, ATTACK, SUPPORT, NOSUPPORT) when it is about the reader's own
orders. When the reader's own orders for that phase are published, the
condition is decided on them (DOCUMENTARY): met, the promise becomes an ordinary
promise, due that phase or the next ("next turn"); not met, it is void and never
a lie. A condition Heel Turn cannot check (about a third power) leaves the
promise TESTIMONY for ever: never planned on, never judged.

## New in v0.1r3

- Autobuild ran v0.1, v0.1r1 and v0.1r2 on r13196: every suite passed and the
  game gate timed out at 600 s. Cause, my design error: the gate compared runs
  by SHA-512 through crypto's pure-ooRexx path (61 s for one 200 KB journal here;
  four files hashed), against the estate rule that hashing goes through crypto's
  Foreign Runtime provider. The gate needs equality, not a digest, and both files
  are present, so it now compares bytes (`diplomacySameJournal` for journals).
  Nothing in Heel Turn hashes.
- Heel Turn never offers a DMZ on a supply centre (v0.1r2 offered a neutral
  centre it would want).
- Designers' draft prompts are no longer test fixtures. v0.1r1 and v0.1r2
  carried two designers' unsealed drafts in tests/fixtures; the competition seals
  prompts. `tests/fixtures/constructs.txt` (written for the test) exercises the
  same constructions instead.

## v0.1r1 and v0.1r2 (reader and ledger fixes)

Designers' first prompts (two designers, three drafts, relayed by Tom Dyer) were
read sentence by sentence with `tools/read_prompt.rex`. Most sentences read, but
several read wrongly, one dangerously: a before-clause naming a stab ("before a
betrayal, remember ...") raised the base stab setting over the stab threshold,
so that player would have stabbed from 1902 whatever its conditions. A misread is
silent; only an unread sentence is listed. Fixed for every designer:

- Relative clauses and a new subject after the act describe the object, they are
  not directives ("punish any power THAT attacks you", "a province YOU plan to take").
- before / after order steps and set no condition.
- A negative quantity on the object turns the act down ("send FEW messages").
- "When a power keeps a promise ..." is the condition kept, not the catch-all needed.
- After a negating verb a word is the act it negates ("avoid ATTACKING");
  weak / strong in the object name the weakest / the leader; a bare build moves expand.
- Words: cold, coldly, plead, beg, grovel, few, fewer, little; hold, move, stab,
  attack as objects after a determiner ("promise a hold").

A designer asked for an assessment of one conditional term, which found:

- A FALSE LIE. A true, possible support promise written out in notation
  ("My F SEV will support your A BUD - RUM next turn") lost its supporter, and
  the blank unit was read as "no such unit": a DOCUMENTARY lie
  (IMPOSSIBLE_SUPPORT). Fixed: the supporter is the writer's own unit named
  before the verb; a blank unit is never a missing one.
- The condition taken for a promise: in "If you do not attack me ..., I will ..."
  the condition was recorded as the writer's own NOATTACK. A sentence with a
  condition is now read as its main clause; with no comma the main clause starts
  at the writer's own I / we / my.
- Conditional promises are recorded with scope COND: TESTIMONY only, never
  verified and never planned on, so never a lie and never settled, until the
  condition itself can be checked.
- It agreed a DMZ and offered the same DMZ again in one message (Muse's test,
  REQ-00006429). It no longer offers a province already promised to that power.

`tools/read_prompt.rex PROMPT_FILE` shows what Heel Turn reads: each sentence
READ with the settings it moved and under which condition, or NOT READ with the
unknown words, then the settings. It is the same reader the engine uses. It
should go to all seven designers at once (equal-source rule).

`tools/slam_reply.rex MESSAGE_FILE FROM TO [PROMPT_FILE] [LOG]` sends Heel Turn
one press message, from one seat to another, inside a press call the framework
itself rendered, and prints what it read, what it believes about each promise and
the messages it sent back. This is how other chats talk to the SLAM.

The settings channel is prose only: there is no knob line. A designer who wants a
setting writes the directive that moves it.

## The runner face (no change to the framework)

`HeelTurnEngine` has the face `DiplomacyPlayer` uses:
`engine~invoke(system, input)` returns a directory STATUS / TEXT / INPUT_TOKENS /
OUTPUT_TOKENS, and `engine~profile~identity` names the runner
(`SLAM|heelturn-0.1r5|deterministic|us|0`; token counts are words, there is no
tokenizer). `DiplomacyPlayer`, private press, the pinned referee and replay in
`oorexx_diplomacy_v0.1-dev7r1` are unchanged and unaware of what runs behind the
face. Heel Turn receives the same SYSTEM text (fixed header + designer prompt) and
USER text (RULES, MAP, STATE, LAST RESULTS, PLAYER LIST, INBOX, MEMORY, TASK) as
any runner, and answers in the same blocks: `SEND TO:` / `MESSAGE:` /
`END MESSAGE`, `ORDERS:` / `END ORDERS`, `MEMORY:` / `END MEMORY`. There is no
referee object and no legal-move list, as the competition requires.

Every call is fresh. What Heel Turn knows of the past is only what it wrote in its
own MEMORY block (cap 8000; it keeps itself under 7600).

## How a call goes

1. `HeelTurnView` reads the rendered text. Section headers are matched in their
   fixed order, so text inside rules or mail can never open a section early.
2. `HeelTurnPromptReader` reads the designer prompt into settings (`HeelTurnPolicy`).
3. `HeelTurnAssessment` assesses the position: centres and units per power, the
   leader, who borders whom, what can reach each province.
4. `HeelTurnMind` loads its memory, checks open promises made to it against the
   newly published orders, reads the inbox (`HeelTurnMessageReader`), and lets
   Reasoned Thought decide what it may believe (below).
5. Relations: ally, enemy, neutral, or the one ally to stab (TARGET), from
   documentary trust, geography, the board's leader, caught lies and attacks, and
   the policy.
6. `HeelTurnPlanner` plans orders on the board it can support, keeping the
   promises it meant.
7. Press calls: the composer chooses acts per recipient and the writer realises
   them. Order calls: every line is checked against the graph, then sent.
8. The ledger is written back as the MEMORY block.

## Language: concepts, not strings

The vocabulary is in Boston Crab house format:

- `data/concepts.src`: `concept|isa|defs`. Acts (attack, betray isa attack,
  support, ally, lie, keep, break, keep-out ...), objects (ally-power,
  neighbour, leader, weakest, centre, neutral, home, dmz, alliance ...),
  qualities (aggressive, cautious, honest, deceptive ...), conditions (weak,
  betrayed, attacked, gain, needed ...), times (early, late, now, next) and tone
  marks (warm, cold, flattery, urgency, hedge, assurance, fear).
- `data/lexicon.src`: `label|pos|^concept|feats`. Words and phrases ("stab in the
  back", "stay out of", "don't be afraid to"), negating verbs (avoid, refrain
  from, hesitate), condition words (if, when, unless), force words (always,
  should, may; never and rarely carry polarity) and tone markers ("trust me", "I
  swear", "perhaps", "last chance"). Simple endings are tried before a word is
  called unread.
- Closed-class words come from the Librarian's deterministic grammar:
  `LibrarianGrammar~installBuiltins` (NEGATOR MODAL PRONOUN JOIN PREP DETERMINER
  TITLE), loaded from `virtual_ryta_hardworld_v0.31_work/librarian`.
- Places and powers come from the MAP the framework sends, by code and by name
  (Galicia, the Black Sea, St Petersburg). A three-letter code that is also an
  English word (war, gas, arm) is a place only in capitals or after A/F.

## Reading the designer prompt

`data/policy.src` says what an act on an object does: `act|object|knob|weight`.
The most exact rule wins (exact act and object, then the act's parents). Each
directive has a polarity (not, never, avoid: "don't be afraid to stab" is a
double negative and raises stab), a force (must 1.0, should 0.7, may 0.4), an
optional condition ("stab an ally when they are weak" sets stab conditional on
weak; "unless the other side broke it first" sets !betrayed) and a time (early,
late, for stance settings only). Statements about others ("expect others to
lie", "assume every promise is a trap") raise suspicion; they are not licences.
Sentences with no directive are listed as not read, so a choice that rests on
them is never taken on trust; the count is in every reply and in the log.

Settings: aggression defence expand stab balance bully loyal alliance allyNear
allyFar bandwagon honesty keepWord promises trust suspicion retaliate fleetPref
talk warmth brevity patience flexibility openness memory.

The seven sample prompts in `prompts/` read fully, except two sentences in
`chaos.txt` that say nothing a player can do ("Mwahaha.").

## Orders

Destinations are only ever taken from the unit's own army or fleet column in the
MAP, so split coasts are always literal (`F STP/SC - BOT`, `F CON - BUL/EC`,
`BUILD F STP/NC`). The planner scores moves (centres by owner and season,
position, threatened homes, distance to the next centre), assigns them without
collisions or swaps, adds supports for contested moves and threatened holds,
keeps supports it promised, and convoys an army with one fleet at sea. Retreats
avoid occupied provinces, the attacker's origin and last turn's standoffs.
Builds go to vacant owned homes; fleets are chosen by the share of coastal homes
and the fleet setting.

Before any line goes out it is read back and checked against the graph
(`HeelTurnPlanner~check`): the unit is ours and where we say, the destination is
in its own column, a supporter reaches the province (SUPPORT_REACH=PROVINCE), a
supported fleet's destination coast is in its own column, a convoying fleet is
at sea, a build is a vacant owned home with the coast named. A line that fails is
not sent: the unit holds, disbands (retreat) or the line is dropped (winter).

## Press: reading, tone and intent

Each sentence gets one speech act: PROMISE PROPOSAL REQUEST THREAT ACCEPT REFUSE
ACCUSE THANKS APOLOGY GREETING QUESTION CLAIM. From it come commitments (NOMOVE
MOVE SUPPORT HOLD NOATTACK ALLY) with the force they were written with,
requests (SUPPORT, NOMOVE), threats with the provinces they guard, accusations,
hearsay about a third power, and claims the board can check (UNIT_AT,
NO_UNITS_NEAR). Orders written into the text are read in notation or English
("support my fleet in Sevastopol to the Black Sea").

Tone and intent are a separate layer, from counts only: a TONE_LABEL (HOSTILE
FLATTERING PLEADING PRESSING FRIENDLY NEUTRAL), FLAGS (OVERASSURED,
EMPTY_ASSURANCE, HEDGED, VAGUE, TAKER) and an INTENT (COERCE ACCUSE WEDGE
COOPERATE ASK PROBE INFORM). Intent steers what Heel Turn says back; it never
decides what Heel Turn believes.

Writing uses a small fixed English that the same reader reads back (tested):
"I propose a DMZ in GAL. I will not move into GAL this turn.", "Please support my
A BUD - SER.", "I will support your A VIE - GAL.", "You broke your promise about
GAL. I will not trust you again.", "Please confirm that you will not move into
GAL this turn." Powers are named in full (England, never ENG, which is also the
Channel). Volume follows talk; length follows brevity.

## Lying: understood through Reasoned Thought

Whether a promise is kept is decided by the estate's Reasoned Thought
(`oorexx_reasoned_thought_v0.1`: `ThoughtNetwork`, `OrdinalEvidenceCombiner`),
never by a score. One proposition per promise: "P keeps commitment c", assert
floor TESTIMONY, settle floor DOCUMENTARY, accepted bindings ORDERS_OF_SUBJECT and
BOARD_STATE.

| Tier | Ground | Binding |
| --- | --- | --- |
| STYLOMETRIC | tells (OVERASSURED ...): REBUT, visible only, never decisive | GENERAL |
| TESTIMONY | the promise itself (SUPPORT); hearsay from a third power (REBUT), UNDERCUT for PARTIALITY when the speaker is not the reader's ally | ORDERS_OF_SUBJECT |
| DOCUMENTARY | published orders match (SUPPORT) or contradict (REBUT); the board says it cannot be done (REBUT) | ORDERS_OF_SUBJECT, BOARD_STATE |
| PROVENANCE | the framework's mail header: who sent it, never that it is true | MAIL_ENVELOPE (INELIGIBLE here) |

- A lie is a DOCUMENTARY rebuttal: the published orders contradict a promise, or
  the board shows it could not be done. As the competition reads every order as
  a contract, an impossible promise counts as meant. A move by convoy is possible
  when a physical route of fleets exists (NONADJACENT_ARMY_MOVE).
- A claim the board denies ("my A BOH will hold" with no army in BOH) is a
  documentary lie at once.
- A kept promise is SETTLED only on the published orders.
- DISPUTED, UNDETERMINED and HINT are CANNOT TELL. Heel Turn does not plan on such
  a promise (it plays the board as if it had not been made) and asks for
  confirmation. It plans on a promise only when the combiner leaves it PRO and
  assertible, not disputed, from a power with no recent documented lie.
- Trust moves only on documentary verdicts. Tone and hearsay never move it.
- Heel Turn tells a lie only where its prompt's honesty setting, in that
  context, allows one (for example the stab target, or a gain in reach for an
  opportunist). Each promise it makes is recorded as meant (OUT sincere 1) or
  not (sincere 0, and a MYLIE line), so it keeps the promises it meant, and before a lie it checks what it
  has already told that power about that province this phase.

### Memory lines

One fact a line, fields split by `|` (empty fields kept):
`TRUST|P|v`, `REL|P|rel|year`, `IN|year|phase|from|kind|unit|prov|ttype|tloc|tdest|scope|strength|status|targets|flags`,
`HS|year|phase|from|about|partial`, `OUT|...|sincere|status`,
`LIE|P|year|phase|kind|detail`, `MYLIE|...`, `GROUND|year|phase|provinces`,
`ATK|P|year|count`, `SAID|year|phase|P|key`. The ThoughtNetwork is rebuilt each
call from these lines and the new results. A line it cannot read is logged
(MEMORY_LINE_NOT_READ), never silently dropped.

## Running log

Every call logs through the estate's logging (`oorexx_logging_v0.7`, LogService
`heelturn`, INTERNAL rule, file target; console too when asked): CALL, PROMPT and
PROMPT_NOT_READ, ASSESS, MAIL (tone, intent, flags, acts, commitments,
requests), EVENT (KEPT, LIE, TOLD_LIE, ATTACKED_BY, SUPPORTED_BY, HEARSAY,
THREAT), RELATIONS, RELY, CANNOT_TELL, SEND, ORDER_CHECK_FAIL, ORDERS, MEMORY,
FAULT (with traceback).

## Run

With an `animatedads/alchemy` checkout and ooRexx 5.3 on PATH:

```
export ALCHEMY_REPO_ROOT=/path/to/alchemy
```
```
sh tests/run.sh
```

A game with Heel Turn in every seat (prompts in `prompts/seats/AUS.txt` ...
`TUR.txt`; set REXX_PATH as `tests/run.sh` does):

```
rexx tools/heelturn_game.rex $ALCHEMY_REPO_ROOT/packages/oorexx_diplomacy_v0.1-dev7r1 prompts/seats 1905 7 game.log heelturn.log
```

To use Heel Turn as a runner elsewhere, construct
`.HeelTurnEngine~new(dataDir, logPath, progress)` and pass it to
`.DiplomacyPlayer~new` in place of a `DiplomacyEngine`.

## Qualification (ooRexx 5.3.0 built from the ooRexx/ooRexx GitHub head, 2026-11-27)

- Lint: Boston Crab pitfalls P1-P4 and the estate SourceLint, zero findings on
  every source, tool and test.
- `tests/prompt.rex` 47 checks: all seven prompts read into the settings they say;
  the constructions in tests/fixtures/constructs.txt and constructs_r6.txt read
  without the earlier misreads; each rule counts once (repeats, strongest
  wording, cancelling, eight lies read as one).
- `tests/press.rex` 40 checks: speech acts, tone, intent, commitments, requests,
  threats, hearsay; lower-case war/gas are words; every writer sentence reads
  back as the commitment it recorded.
- `tests/orders.rex` 11 checks: every bad line caught (no coast, wrong coast, not
  in column, cannot reach, no such unit, convoy not at sea); a foreign-unit
  support passes; every power's spring plan passes its own check.
- `tests/truth.rex` 57 checks on the framework's own rendered text: a promise is
  SUPPORTED not settled; the mail header is INELIGIBLE; published orders that
  contradict it make a DOCUMENTARY lie and lower trust; matching orders SETTLE it;
  a tell does not defeat testimony and never moves trust; partial hearsay leaves
  it DISPUTED, so CANNOT TELL; an impossible support and a false claim are lies;
  memory with empty fields survives; a feasible support promise is not a lie;
  a conditional promise is neither planned on nor judged; the testimony
  policies; my own promises survive memory into the order call, and a lie I
  told does not bind my orders.
- `tests/game.rex` 14 checks: seven Heel Turn players, seven prompts, 1901-1905:
  FINISHED, every call OK (303), zero invalid orders, no faults, no order failed
  its own check, lies told and lies caught, promises settled; the same seed gives
  byte-identical journal and log; the framework's replay is byte-identical.

## Limits (v0.1)

- Not qualified on Tom's ooRexx 5.3.0 r13196; built and run on the GitHub head.
  No catch/finally is used.
- The Librarian grammar is loaded from a work package
  (`virtual_ryta_hardworld_v0.31_work/librarian/LibrarianSalvagedCore_v09.cls`);
  only `LibrarianLexicon` and `LibrarianGrammar` are used. It should move to a
  published Librarian package.
- Memory cap: ledger lines older than a year are dropped, so a replay of beliefs
  reaches back about one year, not to 1901.
- The reader is closed-vocabulary. A long LLM-written prompt or message will have
  unread sentences; they are listed, not guessed. Coverage grows by adding words
  to lexicon.src, never by guessing.
- Convoys use one fleet; multi-fleet routes are recognised as possible when
  reading others' promises but not planned.
- Play strength is not yet measured against Haiku or Sol; no live call has been
  made.
