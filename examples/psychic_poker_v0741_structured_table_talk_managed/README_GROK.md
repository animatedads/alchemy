# HardWorld Casino — GROK blind-table experiment

`grok_experiment.rex` deals an ordinary, non-psychic AI player named **GROK**
into the existing casino.

GROK receives only its legal player view at each decision:
- small blind and big blind;
- its own hole cards;
- public board;
- street, pot, dealer and its stack;
- every player's public stack/bet/fold/all-in status;
- amount to call, minimum raise increment and whether raising is currently legal;
- public action history for the current hand.

It does **not** receive opponent hole cards, psychic team messages, engine equity,
or psychic observations. The RED psychics remain entitled by the existing game
rules to read GROK's cards and inspect its strategy description because GROK is
a non-psychic player.

## xAI connection

Set `XAI_API_KEY` in the environment. The key is never included in the prompt,
request body or NoSQLServer evidence.

The client uses xAI's `/v1/chat/completions` endpoint and defaults to
`grok-4.5`. If the API is unavailable or the reply is malformed, GROK falls
back to the configured ordinary poker strategy so the hand can finish.

Run:

    rexx grok_experiment.rex 5 /tmp/hardworld-grok-db

The model is instructed to return only:

    ACTION=FOLD|CHECK|CALL|RAISE
    AMOUNT=<integer>

The engine re-validates the returned action against the actual betting state;
the model cannot reopen a short all-in, check facing a bet, or raise when
raising is closed.


## v0.7.1 blind-information condition

The AI-facing prompt contains **no mention of psychics, unusual information
advantages, teams, strategy classes, or hidden experiment roles**. The two
privileged players are seated under ordinary names (`Eve`, `Frank`). Their
internal RED team identity remains available to the casino/NoSQLServer audit
only and is never included in GROK's player view.

This is deliberate experimental blinding: GROK is told it is playing ordinary
no-limit Texas Hold'em and receives only ordinary public table information.


## v0.7.2 persistent rerun identity

Normal runs no longer hard-code `experiment_id=1`. `PokerExperimentStore`
queries the existing `experiment` relation and allocates the next integer
identifier (`MAX existing id + 1`, implemented as descending order + `LIMIT 1`).

Therefore repeated executions against the same database retain all previous
runs instead of colliding with the primary key. `grok_experiment.rex` prints
the allocated experiment ID at startup.

An explicit experiment ID remains available by passing the third constructor
argument to `PokerExperimentStore` for controlled import/replay work.

## v0.7.3 source repair

Repairs a packaging error in `grok_experiment.rex` where a Python-generated
replacement inserted the literal characters `\n` between two Rexx statements
instead of an actual newline. Added `test_source_sanity.rex` to reject literal
`\n` sequences in the executable Rexx runners.

## v0.7.4 report isolation

Persistent databases can contain many experiment runs. Historical reports are
now explicitly scoped to the current `experiment_id`.

This fixes the misleading v0.7.3 `GROK ACTIONS` output where actions from run 1
and run 2 were interleaved under the same hand numbers. The same correction was
applied to profit, psychic audit, pot-settlement, action-family and BB/100
reports in the general and batch runners.

Cross-experiment analysis is still possible, but must now be requested
deliberately rather than happening accidentally in a per-run report.

## v0.7.5 complete player blinding

Removed the remaining AI-facing epistemic clue vocabulary. The player prompt no
longer says `You are NOT psychic`, and the xAI system prompt no longer describes
GROK as `ordinary non-psychic`.

The API player is simply told it is playing no-limit Texas Hold'em, to use only
the supplied game state, not invent hidden cards, maximise long-run bankroll,
and return a legal action. Internal experiment documentation may describe the
privileged players; none of that documentation is sent to the model during play.

## v0.7.6 aggressive ordinary player

Adds `AggressiveStrategy`, an ordinary non-privileged strategy with separate
SQL identity `AGGRESSIVE`. It uses risk `0.72`, bluff frequency `0.38`,
aggression `1.65`, a lower raise gate, a lower bluff-equity floor, and larger
raise sizing than `PlayerStrategy`.

The GROK experiment now also seats an ordinary player named `Hugo` using this
strategy. Because Hugo is not privileged, the existing RED players can read
his cards and strategy under the same rules that apply to other ordinary
players. GROK receives only Hugo's public table state.

## v0.7.7 Psicorp aggressive psychic

Adds an internally RED-team `PsychicAggressiveStrategy`, seated under the ordinary public name `Maya`. GROK receives no role/team disclosure.

The strategy adds **representation leverage**: post-flop it compares each readable ordinary opponent's exact cards with the public board, samples plausible unseen two-card holdings, and estimates how often those holdings would already beat that opponent. A board on which many stronger hands can credibly exist increases Maya's bluff probability and lowers her raise threshold.

This is deliberately different from ordinary fold leverage: fold leverage models the opponent's readable strategy; representation leverage models what scary stronger hand the board allows Maya to represent when she knows the opponent does not actually hold it.

## Experiment-condition metadata

Each GROK run now writes one `experiment_context` row containing the casino seed, AI model, prompt version, table configuration and run timestamp. This keeps exact replay conditions distinguishable from genuinely different card worlds when the shared NoSQLServer database is circulated for analysis.

## v0.7.8 fresh casino seeds + exact replay

Normal casino runs no longer use the fixed development seed `424242`.

`grok_experiment.rex` now accepts:

    rexx grok_experiment.rex [hands] [database-root] [replay-seed]

When the third argument is omitted, a fresh seed is derived from the current
high-resolution date/time before the database observer is attached. The chosen
seed initializes the casino's isolated `PokerRandom`, is printed at startup,
and is persisted as `experiment_context.casino_seed`.

Example normal run:

    rexx grok_experiment.rex
    Casino seed: 138472901 (fresh)

Exact poker-world replay:

    rexx grok_experiment.rex 5 /tmp/hardworld-grok-db 138472901
    Casino seed: 138472901 (replay)

The same seed reproduces the casino RNG stream (deal/shuffle and internal poker
random draws). GROK API responses may still vary independently unless the model
service itself returns the same decisions; that distinction is intentional and
is why model/prompt metadata is stored beside the casino seed.

## v0.7.9 observer-visible table cards

The human experiment console now prints every seated player's two hole cards
after the deal and retains them beside each player's stack after a hand. This
is an observer/debug display only. `agentPrompt` is unchanged: GROK still
receives only its own hole cards plus public table information.

This makes live experiment transcripts substantially easier to follow without
weakening the blind AI condition.

## v0.7.10 observer display repair

Repairs the v0.7.9 observer-card display integration.

The previous static test searched for an exact source substring that did not
match the valid `showStacks` expression, and the start-of-hand seat display had
not been inserted because the patch matched a different Rexx concatenation
spelling than the real dealer-log line.

The observer console now prints all dealt hole cards immediately after the
dealer line and again with the stack display. The test now checks the semantic
method regions instead of one formatting-specific source fragment.

## v0.7.11 representation-leverage robustness

Repairs a crash in `psychicRepresentationLeverage` where an incomplete/nil
two-card holding could reach `HandEvaluator~scoreFive`, producing
`The NIL object does not understand RANK`.

The representation sampler now validates both readable target hole cards and
sampled candidate pairs before scoring. Incomplete information is skipped, not
treated as a poker hand. This leaves the evaluator strict while making the
experimental information-boundary code robust.

## v0.7.15 INTEGER-safe replay seeds

Fresh casino seeds are now constrained to `1..999999999`. NoSQLServer v0.68
validates INTEGER values with ooRexx `datatype(value,"W")` under the default
9-digit numeric precision, so 10-digit Park-Miller seeds could be rejected even
though the casino PRNG itself used higher precision.

The reduced seed domain still provides nearly one billion reproducible poker
worlds while remaining compatible with the existing `experiment_context` table.
Explicit replay seeds outside this range are rejected immediately with a clear
message rather than failing during metadata insertion.

## v0.7.16 seeded random initial seating

The initial seat order is no longer fixed.

Before the first hand, `PokerTable~seatPlayersRandomized` performs a
Fisher-Yates shuffle using the table's isolated casino PRNG. This deliberately
consumes the same seeded RNG stream that subsequently drives the deal, so an
explicit replay seed reproduces both:

1. the initial seat order; and
2. all subsequent casino randomness.

The resolved order is printed as `Initial seats:` and persisted inside
`experiment_context.table_configuration` as `seats=...`.

This removes systematic button/blind/position bias from repeated fresh-seed
experiments while preserving exact replay.

## v0.7.17 nine-handed table

Corrects the table population to **nine players**.

The ninth seat is `Noah`, an ordinary non-privileged player using
`GeminiEmulatedStrategy` (`AI_GEMINI_EMULATED`). This is Gemini's own
self-authored deterministic "semi-optimal" policy, kept separate from the live,
blind `GEMINI` API player.

`Noah` is deliberately given an ordinary public name so GROK/GEMINI receive no
strategy-role hint. Internal SQL records retain the strategy identity for later
comparison.

The fresh-seed initial seating shuffle now randomizes all nine seats, and replay
with the stored seed reproduces that nine-player order.

## v0.7.18 dedicated resource-aware player

Adds `Rosa`, an ordinary player using `ResourceAwareStrategy`, as a dedicated
seat rather than leaving that strategy only as GEMINI's fallback.

The experiment is now ten-handed before eliminations:
Ada, Grace, GROK, GEMINI, Hugo, Noah, Rosa, Eve, Frank, Maya.

Initial seating is still shuffled from the stored casino seed, so replay
reproduces all ten initial positions.

Observer-only stack output now prints the actual strategy identity, e.g.
`AI_GROK`, `AI_GEMINI`, `AGGRESSIVE`, `RESOURCE_AWARE`,
`PSYCHIC_TEAM/RED`, while the API prompts remain blind.

## v0.7.19 Apex v2

Adds `ApexStrategy` (`APEX`) as an ordinary deterministic strategy and seats
player `Apex` in the seeded initial shuffle.

Apex is tight/value-heavy:
- risk `0.28`
- bluff `0.06`
- aggression `1.45`
- fast-plays most >=0.82 equity holdings
- uses an 18% flop trap mix
- uses street/strength-sensitive value sizing
- raises strong non-nut value from >=0.62 equity

The supplied concept was adapted for ooRexx correctness:
- inherited parameters use their public getters rather than subclass `expose`;
- compound `&` / `|` guards were rewritten as nested branches because ooRexx
  does not short-circuit those operators.

The table is now eleven-handed before eliminations.

## v0.7.20 Blind Benny

Adds independent psychic player `Benny` using `BLIND_PSYCHIC`.

Benny's strategy never reads his own hole cards. His equity is estimated by
sampling all plausible two-card holdings from the unseen-card pool after
conditioning on:
- the public board; and
- every other active player's exact hole cards.

He has no RED team and no psychic teammate communication. Existing psychic
card-read rules do not expose Benny's cards to Eve/Frank/Maya because Benny is
himself psychic.

Benny can therefore know everybody else's hand while treating his own two
cards as unknown random variables until showdown.

The table is now twelve-handed before eliminations.

## v0.7.22 dedicated GROK emergency fallback

Replaces the generic GROK fallback with `GrokFallbackStrategy` (`GROK_FALLBACK`).
It is deliberately tight and capital-preserving for API failure conditions:
- risk `0.22`
- bluff `0.03`
- aggression `1.15`
- folds medium equity against calls >=55% of the current pot
- only raises strong value ranges
- avoids large speculative calls

When the xAI client returns no usable decision, the observer console now prints:

    GROK FALLBACK active

before the fallback decision is made. This marker is not included in the AI prompt or opponent-visible public action history.


## v0.7.29 resilient xAI transport

`GrokAPIClient` now records `lastError`, `lastHttp`, and `attempts`, uses a
75-second default timeout, captures curl stderr, and retries transient failures
up to three times with a one-second backoff. Retryable cases are transport/000,
HTTP 408/425/429, 5xx, and empty or malformed model output. Stable client-side
HTTP failures are reported immediately.

The API key remains environment-only: the curl header references
`$XAI_API_KEY`; the key is not copied into the command line, prompt, request
body, database, or casino audit records.


## v0.7.30 same-inference table talk

The blind GROK prompt now supplies the 12 frozen Librarian tokens and accepts
`TALK` plus `TALK_TARGET` alongside `ACTION` and `AMOUNT`.  The xAI client parses
those fields, while the poker engine validates the token and active target
before publishing anything.  GROK therefore chooses the semantic act and
target, but never invents the spoken phrase.

If the xAI call fails and `GrokFallbackStrategy` is used, no inherited random
AI table talk is emitted.  Retry/fallback and speech are therefore independent:
transport hardening does not fabricate model behaviour.

## v0.7.31 public social evidence

Before each live GROK decision, the ordinary-player prompt may now include a
`SOCIAL EVIDENCE (PUBLIC EMPIRICAL HISTORY)` section reconstructed from
persisted `table_talk` and `action_log` rows.  It pairs a speaker's classified
utterance with that speaker's next public betting action, compares the sample
with the speaker's overall public action baseline, and labels sample confidence.

The section is evidence rather than authority: speech is not assumed truthful,
no hidden cards or engine equity are exposed, and GROK's objective remains
long-run chip bankroll.  No deterministic pressure/provocation adjustment is
applied to the live AI strategy.



## v0.7.32 social-evidence attribution

Each displayed social-evidence opponent profile is assigned a decision-local
`E` identifier.  The model output contract includes
`SOCIAL_EVIDENCE=NONE|<displayed E-id>`.  This lets the experiment distinguish
between evidence merely being present in the prompt and the model explicitly
claiming that one displayed profile materially informed its betting decision.
Claims are validated against the exact evidence IDs shown for that decision and
persisted in `ai_social_decision`.

`POKER_SOCIAL_SHADOW=1` enables an optional paired counterfactual.  The real API
client uses temperature 0 for both calls: the played decision sees social
evidence; the shadow decision sees the same public poker state with the social
statistics removed.  The shadow output is audit-only and is never executed.


## v0.7.33 stable social-effect probing

`POKER_SOCIAL_SHADOW=1` remains the two-call sensitivity probe.  Differences
from this mode are candidates, not causal claims.  `POKER_SOCIAL_SHADOW=2` adds
a second call with the **identical social prompt** before the no-social shadow.
Only a main/control match followed by a counterfactual difference is classified
as `STABLE_SOCIAL_EFFECT`; a main/control disagreement is `MODEL_INSTABILITY`.

The exact decision-local social evidence is persisted in `ai_social_effect`, so
E-ids are auditable after the hand even though later prompts reuse `E1`, `E2`,
etc.  `SOCIAL_EVIDENCE=NONE` is a valid response but is not a validated E-id.
A stable effect with `NONE` is retained as an **unattributed social effect**,
not retroactively assigned to whichever opponent looks plausible.

## v0.7.34 context-matched social evidence

The social block now supplies a same-speaker, same-street, `FACING`/`FREE`
matched baseline beneath the existing aggregate counts when such history is
available.  This is observational evidence only; GROK is not told that any talk
class implies strength or weakness.  The prompt version recorded in
`experiment_context` is `MULTI_AI_SOCIAL_ATTRIBUTION_V5`.

## v0.7.35 silent-context social baseline

GROK's social-evidence block now includes a disjoint `no_talk_n` comparison for
the same opponent, street, and `FACING`/`FREE` context.  Talk-paired actions are
excluded from that silent population.  `delta_vs_no_talk{...}` reports neutral
percentage-point changes for each public betting action; it does not tell GROK
what psychological story to attach to them.

The experiment prompt version is `MULTI_AI_SOCIAL_ATTRIBUTION_V6`.


## v0.7.36 Decision-unit evidence

Repeated same-class/token/target utterances before one speaker betting action no
longer inflate social sample size.  `table_talk` retains every utterance, while
the empirical prompt counts at most one outcome per betting decision for each
corresponding evidence category.  Historical reconstruction and live updates
share this rule.  Prompt version: `MULTI_AI_SOCIAL_ATTRIBUTION_V7`.


## v0.7.38 Prompt boundary audit

The live prompt is now assembled through `PokerPromptEnvelope`.  Every field is
provenance/disclosure-labelled and the boundary admits only public table state
plus the acting player's own CUSTOMER hole-card field.  Observer narration,
other-player private state, engine/RNG state and SECRET/INTERNAL material are
fail-closed before provider invocation.  Live prompt audits persist counts and
SHA-512 identity only; prompt text is not stored.  Prompt version:
`MULTI_AI_SOCIAL_ATTRIBUTION_V9`.


## v0.7.39 structural prompt manifest

Every GROK prompt boundary now emits a safe `SOURCE|DISCLOSURE` manifest.
For strict social counterfactuals the MAIN and NO_SOCIAL prompts must have an
identical non-social `core_manifest`; only `SOCIAL.*` provenance may differ.
Prompt values and hole cards are never stored in the manifest.  A structural
drift aborts the experiment rather than allowing a contaminated social-effect
comparison.
