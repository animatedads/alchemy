# Heel Turn SLAM (oorexx_slam_heelturn v0.1r2): a SLAM that plays Diplomacy

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

## New in v0.1r2

DeepSeek asked for an assessment of one term: "I propose a DMZ in GAL. I will not
move into GAL this turn. If you do not attack me this turn, I will support you
into a neutral centre next turn." Checking it and its explicit forms found:

- A FALSE LIE. "My F SEV will support your A BUD - RUM next turn" is true and can
  be done, but v0.1r1 lost the supporter (the writer's unit before "support"),
  then read the blank unit as "no such unit" and recorded a DOCUMENTARY lie
  (IMPOSSIBLE_SUPPORT). Fixed: the supporter is the writer's own unit named
  before the verb; a blank unit is never a missing one.
- The condition taken for a promise: "if you do not attack me" was recorded as
  the writer's own NOATTACK. A sentence with a condition is now read as its main
  clause; the condition's acts are the other side's. With no comma the main
  clause starts at the writer's own I / we / my.
- Conditional promises are recorded with scope COND: TESTIMONY only, never
  verified against orders and never planned on, so never a lie and never
  settled, until the condition itself can be checked.
- Heel Turn agreed a DMZ and offered the same DMZ again in one message (Muse's
  test, REQ-00006429). It no longer offers a province it has already promised to
  that power this phase.

## New in v0.1r1

DeepSeek's first Heel Turn prompt (38 sentences, sent through Tom Dyer) was read
sentence by sentence with the new `tools/read_prompt.rex`. 36 read, but several
read wrongly, and one dangerously: "Before a stab, remember what you told that
power" raised the base stab setting to 0.60, over the 0.55 stab threshold, so that
player would have stabbed from 1902 whatever the condition. A misread is silent;
only an unread sentence is listed. Fixed in the reader, for every designer:

- Relative clauses and a new subject after the act describe the object, they are
  not directives: "punish a power THAT attacks you", "a province YOU plan to attack".
- before / after order steps and set no condition.
- A negative quantity on the object turns the act down: "send FEW messages".
- "When a power keeps a promise ..." is the condition kept, not the catch-all needed.
- Words: cold, coldly (hostile), plead, beg, grovel, few, fewer, little; hold,
  move, stab and attack as objects after a determiner ("promise a hold").

Gemini's two drafts (16 and 27 sentences) then showed two more gaps: "avoid
ATTACKING weak players" (attacking read only as the quality aggressive; after a
negating verb a word is now the act it negates, and weak/strong in the object
name the weakest/leader) and "always build if safe" (no rule for a bare build).
Both drafts, DeepSeek's and the seven samples now read every directive sentence.
They are fixtures in tests/prompt.rex (36 checks).

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
(`SLAM|heelturn-0.1r2|deterministic|words|0`; token counts are words, there is no
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
- `tests/prompt.rex` 36 checks: all seven prompts read into the settings they say;
  DeepSeek's and Gemini's first prompts read fully and without the v0.1 misreads.
- `tests/press.rex` 32 checks: speech acts, tone, intent, commitments, requests,
  threats, hearsay; lower-case war/gas are words; every writer sentence reads
  back as the commitment it recorded.
- `tests/orders.rex` 11 checks: every bad line caught (no coast, wrong coast, not
  in column, cannot reach, no such unit, convoy not at sea); a foreign-unit
  support passes; every power's spring plan passes its own check.
- `tests/truth.rex` 29 checks on the framework's own rendered text: a promise is
  SUPPORTED not settled; the mail header is INELIGIBLE; published orders that
  contradict it make a DOCUMENTARY lie and lower trust; matching orders SETTLE it;
  a tell does not defeat testimony and never moves trust; partial hearsay leaves
  it DISPUTED, so CANNOT TELL; an impossible support and a false claim are lies;
  memory with empty fields survives; a feasible support promise is not a lie;
  a conditional promise is neither planned on nor judged.
- `tests/game.rex` 14 checks: seven Heel Turn players, seven prompts, 1901-1905:
  FINISHED, every call OK (299), zero invalid orders, no faults, no order failed
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
- English orders inside press are read for units, provinces and notation; their
  references are not yet checked with Boston Crab's reference rules (planned, as
  agreed with Muse).
- Convoys use one fleet; multi-fleet routes are recognised as possible when
  reading others' promises but not planned.
- Play strength is not yet measured against Haiku or Sol; no live call has been
  made.
