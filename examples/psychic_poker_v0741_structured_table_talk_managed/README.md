# Psychic Poker v0.7.39 — Prompt Manifest Contract


Current head: v0.7.39 extends the v0.7.38 fail-closed prompt boundary with a non-content structural manifest and a social-only counterfactual equivalence contract. Historical release notes are retained below.

v0.4 hardens the poker engine before long-run experiments. It keeps the v0.3 strategy families and NoSQLServer v0.65 live-object/federated-history integration, but fixes the two largest sources of experimental corruption: unequal all-in settlement and ambiguous psychic audit semantics.

## Poker changes

### Contribution ledger and side pots

Every `Player` already carries `totalBet`; v0.4 treats that as the hand contribution ledger. `PotBuilder` converts the distinct contribution caps into ordered pot slices.

For contributions of 100 / 300 / 500, the builder produces:

- main pot: 300, cap 100, three contributors;
- side pot: 400, cap 300, two contributors;
- unmatched return: 200 to the sole contributor above cap 300.

Folded chips remain in the pot but folded players are removed from the eligible winner set. Each contested pot is evaluated independently at showdown.

### Correct all-in betting closure

The betting round now tracks pending responses and whether each player has acted since the last full raise.

- A full legal raise reopens raising for the other actable players.
- A short all-in raise increases the amount still owed but does **not** reopen raising for a player who already acted since the last full raise.
- A player who has not yet acted after the last full raise retains the right to raise over a short all-in.
- If all remaining opponents are all-in and bets are matched, the betting round closes and the board runs out without meaningless later-street bets.
- Unmatched excess is returned at the end of the betting round so subsequent pot odds are not calculated from chips nobody could call.

`test_betting_rules.rex` contains deterministic regressions for the short-all-in reopen rule and automatic board runout.

## Psychic audit split

v0.3's `psychic_observation` mixed "privilege available" with "information actually used". v0.4 separates them.

`psychic_capability` records what the rules permit in a hand:

- `CARD_READ_AVAILABLE`
- `STRATEGY_READ_AVAILABLE`
- `TEAM_MESSAGE_AVAILABLE`

`psychic_observation` now records only privileged information actually consumed by a strategy:

- `CARD_READ` when an equity/opponent model uses known hole cards;
- `STRATEGY_READ` when an exploit model actually reads an ordinary player's strategy object;
- `TEAM_MESSAGE` when communicated teammate cards are consumed.

This preserves the original game rule that every psychic *can* inspect ordinary strategy while keeping `PSYCHIC_EQUITY` a valid control: it may have `STRATEGY_READ_AVAILABLE` but does not produce `STRATEGY_READ` unless its strategy starts using that information.

## NoSQLServer relations

`live_players` remains a live ooRexx object table through NoSQLServer v0.65.

Persistent relations are now:

- `experiment`
- `hand_result`
- `action_log`
- `psychic_capability`
- `psychic_observation`
- `pot_settlement`
- `bankroll_sample`

`pot_settlement` records main/side/uncontested settlements and uncalled returns, including contribution cap, eligible count, winner and winner share.

## Strategy families

- `STANDARD` — ordinary information; individual bankroll objective.
- `PSYCHIC_EQUITY` — privileged card information used only for better equity estimation; individual bankroll objective.
- `PSYCHIC_EXPLOIT` — card information plus ordinary-player strategy reads used for exploit leverage; individual bankroll objective.
- `PSYCHIC_TEAM` — exploit strategy plus same-team communicated cards and team-bankroll deconfliction; team bankroll objective.

These are parameterised heuristics, not claims of GTO/solver-optimal poker.

## Run

With ooRexx 5.3.0 and its stream classes available:

    rexx experiment.rex 20 /tmp/psychic-poker-v04-db

Use a fresh database directory for each run.

The experiment prints live object state, historical strategy profit, the federated live/history join, capability counts, actually consumed psychic information, pot-settlement audit, action statistics, and a small-sample BB/100 diagnostic.

## Validation

See `VALIDATION.md`. The package was exercised with the supplied ooRexx 5.3.0 build and the supplied NoSQLServer v0.65 source. The bundled NoSQLServer source is unchanged.


## v0.5 — experimental runway

v0.5 rebases the casino integration on the supplied **NoSQLServer v0.68**.
The poker engine remains deliberately independent of storage implementation.

The bundled `batch_experiment.rex` is a longer diagnostic runner intended to
exercise elimination, all-in settlement, strategy-family divergence and the
federated SQL reporting surfaces before a genuinely large statistical run.

NoSQLServer v0.68 is significant here because `FederatedDatabaseEngine` is now
itself the ordinary database facade. The same facade can resolve persistent
FILE relations, live/frozen OBJECT relations and registered external engines
(including GeoPackage) without the casino knowing which provider owns a table.

That means future HardWorld experiments can add environmental/spatial relations
without changing the poker domain or its experiment-store contract.

### Run

    rexx batch_experiment.rex

The existing deterministic evaluator, psychic-boundary, strategy, side-pot and
betting-rule tests remain the acceptance boundary.


## v0.6 — reproducible campaign runner

v0.6 makes the experimental casino reproducible and usable as a repeated-tournament campaign rather than a single tournament that necessarily ends when six players bust.

### Dedicated poker RNG

`GameConfig` now accepts an optional fifth argument, `seed`. `PokerTable`, `Deck`, bluff draws and Monte-Carlo shuffles use a dedicated `PokerRandom` (Park-Miller/Schrage) instance. They no longer use ooRexx's process-global `random()`.

This matters because NoSQLServer itself legitimately uses `random()` internally for transaction/token identities. Before v0.6, enabling SQL evidence logging could therefore perturb later poker randomness. `test_rng_isolation.rex` proves that an identical seeded hand produces identical stacks with and without a live NoSQLServer observer.

### Equity state cache

Monte-Carlo equity is cached only across poker states where its inputs are unchanged: same hand, street, board, viewer, sample count and set of dealt/non-folded opponents. Bet-size changes alone do not invalidate card equity; a fold or new street does.

While adding the cache, v0.6 also fixes a correctness defect: a player who had been dealt cards but had not yet contributed chips (`totalBet = 0`) was previously omitted as an equity opponent. Participation is now determined by being dealt into the hand, not by already having put money into the pot.

### Quiet repeated-tournament campaign

`batch_experiment.rex` now suppresses per-action console narration and, when fewer than two players remain, resets all stacks to `startingStack` and starts the next identical tournament. `hands` therefore means campaign hands rather than 'up to N hands before the first tournament ends'. Per-hand profit remains zero-sum; `experiment.rex` remains the single-tournament/live-history demonstration.

Example:

    rexx batch_experiment.rex 100000 /tmp/hardworld-casino-campaign

The debug runtime is still not a claim that 100,000 hands will be fast: synchronous evidence persistence remains significantly more expensive than poker computation. v0.6 deliberately preserves NoSQLServer's proven single-row append insert path rather than switching large persistent tables to multi-row INSERT, because v0.48 documents multi-row insertion as the whole-file atomic publication path.

## v0.6.1 — native evidence append path

Persistent evidence rows now use the public `FederatedDatabaseEngine~insert`
surface directly. This is the same single-row append path reached by SQL
`INSERT`, but avoids regenerating and reparsing SQL text for every capability,
observation, action and settlement row. Schema creation and analysis remain SQL.

A propagated ooRexx HALT returned by NoSQLServer is now reported as an
interruption, not described by the casino as a row/schema constraint failure.
The supplied NoSQLServer v0.68 source remains unmodified.


## v0.7.30 — model-controlled table talk and Paladin discipline

This cut completes the v0.7.28 table-talk loop for live agents. GROK/GEMINI can
select a frozen talk token and target on the same inference as their poker
action; the engine validates both and the Librarian owns the actual phrase.
Apex retains provenance-aware counter-talk. Paladin now owns bounded public
pressure reasoning and has a corrected shallow-SPR raise-increment calculation.
Grok transport retries/diagnostics from v0.7.29 are retained.

## v0.7.31 — learned social evidence for live agents

GROK/GEMINI now receive a compact cross-hand social-evidence section derived
only from persisted public `table_talk` and `action_log` events. Each classified
utterance is paired with that speaker's next public betting action and compared
with the speaker's overall public action baseline. Current-hand talk is
prioritised, sample size/confidence is explicit, and the prompt warns that
speech is evidence rather than truth. Hidden cards, engine equity, psychic
observations and strategy objects are outside this model. Live AI bankroll
optimisation and the absence of mechanical psychology postprocessing are
unchanged.

`grok_experiment.rex` now prints final social-evidence snapshots for GROK and
GEMINI so the experimenter can inspect the same deterministic evidence surface
that is injected into their prompts.



## v0.7.32

Adds decision-local social-evidence attribution for live GROK/GEMINI decisions
and optional deterministic paired shadow counterfactuals (`POKER_SOCIAL_SHADOW=1`).
The new `ai_social_decision` relation records validated evidence provenance and
whether removing the social-evidence block changes action or sizing.  Normal
play remains single-inference unless shadow mode is explicitly enabled.


## v0.7.33 — stable social-effect probes

v0.7.33 separates **model self-attribution** from **observed sensitivity**.
`SOCIAL_EVIDENCE=NONE` remains a valid protocol response, but is no longer
misreported as a validated evidence reference.  The new `ai_social_effect`
relation persists the exact decision-local social-evidence block plus the main,
shadow and (when requested) same-prompt control outputs.

Probe modes:

- `POKER_SOCIAL_SHADOW=1` — paired sensitivity probe: social main vs no-social shadow.
  A difference is recorded as `PAIR_SENSITIVITY`; it is not promoted to a
  causal/stable label because temperature 0 does not guarantee provider determinism.
- `POKER_SOCIAL_SHADOW=2` — strict triplet: social main, identical-social
  control, then no-social counterfactual.  A social effect is labelled
  `STABLE_SOCIAL_EFFECT` only when the identical-social control exactly matches
  the played action/sizing and the no-social output differs.  If the two
  identical-social calls differ, the result is `MODEL_INSTABILITY`.

A stable difference accompanied by `SOCIAL_EVIDENCE=NONE` is explicitly stored
as `unattributed_social_effect=TRUE`: behavioural sensitivity without a model
claim about which displayed E-id mattered.  This is the pattern observed in
experiment 34 and is intentionally not rewritten into a post-hoc attribution.

## v0.7.34 — NoSQLServer v0.74 rebase and context-matched social evidence

v0.7.34 rebases the casino's vendored `nosqlserver/src/NoSQLServer.cls` from
v0.68 to the authoritative NoSQLServer **v0.74** supplied in the 2026-08-22
recovery bundle.  The NoSQLServer source is vendored unchanged; Psychic Poker
continues to use its existing file-backed experiment relations.

The social evidence model now retains the original aggregate talk/action counts
but adds a matched public context for each displayed tell.  The matched context
is the same speaker, the same betting street, and whether the speaker's paired
next action was `FACING` a call amount or `FREE` to check.  For example:

```
E1 Hugo NEEDLE: n=8 confidence=MEDIUM next{RAISE=1 CALL=1 CHECK=0 FOLD=6} ...
  matched context PREFLOP/FACING: talk_n=5 next{RAISE=0 CALL=1 CHECK=0 FOLD=4} baseline_n=42 baseline{RAISE=7 CALL=12 CHECK=0 FOLD=23}
```

This does not tell GROK/GEMINI what the phrase means.  It removes a major
confound in the empirical comparison: a preflop tell is no longer compared only
against an opponent's pooled flop/turn/river behaviour.  Current-hand talk is
matched to the context of the speaker's actual following public action; on a
fresh experiment the context statistics are reconstructed from persisted
`table_talk` and `action_log` rows.

The live prompt contract version is `MULTI_AI_SOCIAL_ATTRIBUTION_V5`.

## v0.7.35 — disjoint silent baseline for social evidence

v0.7.35 keeps the v0.7.34 same-street / `FACING`-versus-`FREE` contextual
comparison, but separates the comparison population into two disjoint sets.
An action that is paired to a speaker's preceding table talk remains a
**talk-conditioned** sample and is no longer allowed to count simultaneously as
the baseline used to judge that talk.

For every speaker/context the prompt now retains the all-action baseline for
orientation and adds a silent baseline containing only public actions that were
*not* the speaker's next betting action after table talk.  It also reports
neutral percentage-point differences for `RAISE`, `CALL`, `CHECK`, and `FOLD`:

    matched context PREFLOP/FACING:
      talk_n=3 next{RAISE=2 CALL=1 CHECK=0 FOLD=0}
      baseline_n=6 baseline{RAISE=2 CALL=1 CHECK=0 FOLD=3}
      no_talk_n=3 no_talk{RAISE=0 CALL=0 CHECK=0 FOLD=3}
      delta_vs_no_talk{RAISE=+66.7pp CALL=+33.3pp CHECK=0.0pp FOLD=-100.0pp}

The deltas are evidence, not semantic authority.  The engine does not label a
positive raise delta as a bluff, strength, intimidation, tilt, or any other
motive.  GROK/GEMINI remain responsible for deciding whether a sufficiently
large, sufficiently sampled public correlation has predictive value.

The live prompt contract version is `MULTI_AI_SOCIAL_ATTRIBUTION_V6`.


## v0.7.36 — decision-unit social evidence

v0.7.36 removes pseudo-replication from the learned talk statistics.  Every
utterance is still persisted in `table_talk`, but the behavioural sample unit is
now the speaker's **next public betting decision**.  Repeating the same class,
token, or same-class target several times before one action can therefore add at
most one outcome to that corresponding statistic.

This changes confidence and percentages, not speech storage.  Distinct semantic
classes before the same action may each receive one class-level observation,
because they are distinct public evidence categories, but repetition within one
category cannot manufacture extra independent decisions.  Historical rebuild
and live updates use the identical rule.

The live prompt contract version is `MULTI_AI_SOCIAL_ATTRIBUTION_V7`.

## v0.7.37 — Alchemy Object foundation and NoSQLServer v0.75

v0.7.37 rebases the casino's vendored NoSQLServer source to the authoritative
NoSQLServer **v0.75** and adopts **Alchemy Objects v0.4.3** as the common object
foundation for long-lived behavioural and service objects.

The integration is intentionally architectural rather than mechanical.  A
small Poker-specific root, `PokerAlchemyObject`, subclasses `AlchemyObject` and
is now inherited by the principal domain/service roots: configuration and RNG,
casino/table, the table-talk librarian, strategy hierarchy, players, Oracle
history, social evidence, experiment storage, and the GROK/GEMINI API clients.
Strategy subclasses inherit the foundation through `PlayerStrategy`.

High-frequency value objects such as `Card`, `Decision`, and individual
`PokerTableTalkEntry`/`PokerTableTalkChoice` instances remain lightweight.  The
Alchemy base carries lifecycle, contract, requirement, relationship, evidence,
security and introspection machinery; allocating that machinery for every card
or transient betting decision would add cost without adding a useful object
boundary.

The inherited foundation provides stable Alchemy identity plus lifecycle/usage
telemetry, method/result contracts, dependency requirements, object
relationships, disclosure-labelled state where ownership is unambiguous, and
Alchemy's sealed/security/introspection surfaces.  GROK and GEMINI clients also
advertise their optional environment/API requirements and record real external
decision calls through the same lifecycle surface.

One ooRexx ownership rule is important.  Object variables are class-scoped, and
Alchemy Objects' fixed state emitter executes in the concrete receiver's class
scope.  Consequently, v0.7.37 does **not** register superclass-owned fields such
as `Player~stack` or `PlayerStrategy~risk` for fixed emission from arbitrary
deeper subclasses; doing so could emit `NIL` and create false evidence.  A
concrete regression probe verifies CUSTOMER/INTERNAL/SECRET disclosure and
sealed evidence using state owned by the concrete class itself.

The package vendors the exact accepted Alchemy Objects v0.4.3 and
`oorexx_crypto` v0.1 dependencies.  A byte-identical `crypto.cls` is also placed
beside the vendored Alchemy source because nested ooRexx `::requires
"crypto.cls"` resolution is filename/path based: preloading the same source via
a differently qualified path does not satisfy the nested require.  This is
standalone dependency plumbing, not a fork of crypto.

Poker remains on the CLASSIC NoSQLServer behaviour profile; v0.75's optional
TUTOR Unicode text-profile work is not enabled by this package.

See `DEPENDENCY_PROVENANCE.md` and `VALIDATION.md` for exact source hashes and
runtime acceptance evidence.

## v0.7.38 — fail-closed live-AI prompt boundary

v0.7.38 uses the v0.7.37 Alchemy foundation as an active security/evidence
boundary for every GROK/GEMINI prompt.  `PokerPromptEnvelope` requires every
prompt field to carry semantic provenance plus an Alchemy-style disclosure.
Only `PUBLIC` data and viewer-owned `CUSTOMER` data are admissible.  In normal
play the only CUSTOMER field is the acting player's own hole cards.

The envelope rejects `INTERNAL` and `SECRET` disclosure, observer provenance,
RNG/engine state, other-player private state, strategy internals, API secrets,
and observer-style `cards=`/seat narration presented as public hand history.
A rejection is fail-closed: the prompt cannot be finalized or sent to a live
provider.  Accepted/rejected/finalized events use Alchemy instrumentation
points and the prompt methods are declared as `SECURITY_BOUNDARY` contracts.

`PokerTable` retains non-content audit evidence for the last social and
no-social prompt variants.  `PokerExperimentStore` persists that evidence in
`ai_prompt_boundary` for live GROK/GEMINI decisions only.  The relation stores
field/disclosure/provenance counts, prompt length, boundary status, and a
SHA-512 digest of the exact prompt bytes.  It deliberately does **not** persist
the prompt text because that text contains the acting player's private cards.
The expensive pure-ooRexx SHA-512 is computed only at live-AI persistence time,
not during every generic prompt construction.

In `POKER_SOCIAL_SHADOW=2` mode the played social prompt and the no-social
counterfactual receive separate audit rows and separate digests; the identical
social control reuses the main prompt bytes.  Scripted `AI_GEMINI_EMULATED`
seats remain outside this relation.

Prompt contract version: `MULTI_AI_SOCIAL_ATTRIBUTION_V9`.

Focused regressions:

- `test_prompt_boundary_audit.rex` proves fail-closed disclosure/provenance
  rejection, exactly one viewer-private field, public-history protection, and
  digest identity without storing prompt content;
- `test_prompt_boundary_storage.rex` proves MAIN/NO_SOCIAL persistence, strong
  prompt identity, and exclusion of scripted AI-emulated seats.

v0.7.38 acceptance on ooRexx 5.3.0 r13196: **59/59 regressions twice**, **67/67**
application compile targets, and a real one-hand fallback casino run at replay
seed `769232536` with `ai_prompt_boundary` PASS evidence for both live AI seats.


## v0.7.39 prompt manifest contract

`PokerPromptEnvelope` now records a non-content structural manifest for every
admitted field (`SOURCE|DISCLOSURE`, in prompt order).  `PokerPromptManifestVerifier`
requires the MAIN and NO_SOCIAL counterfactual prompts to have byte-independent
identical non-social (`core_manifest`) provenance.  Only `SOCIAL.*` fields may
differ.  The new `ai_prompt_manifest` relation persists those safe structural
manifests and the comparison status without persisting prompt values or hole cards.
This makes shadow experiments fail closed if a future code change accidentally
changes ordinary game state, player state, output policy or history structure only
in one arm of the counterfactual.


## v0.7.40 — Alchemy execution-provenance substrate

v0.7.40 is an infrastructure-only continuation from the accepted v0.7.39
prompt-manifest contract. Poker rules, prompt fields, social statistics and the
frozen table-talk dictionary are unchanged.

The Poker house base moves from Alchemy Objects v0.4.3 to v0.7 and uses the
preferred `INIT:SUPER` construction path. Selected security/evidence boundaries
are instrumented so Alchemy v0.7 can retain bounded execution-provenance records
bound to the exact method contract revision and implementation origin without
copying method argument/result values.

Instrumented boundaries:
- `PokerPromptEnvelope~finalize`
- `PokerTable~agentPrompt`
- `OracleHistoryModel~refresh`
- result-bearing prompt/Oracle boundaries only; command-style store writes retain ordinary Alchemy lifecycle/instrumentation evidence and are not auto-wrapped.

The vendored NoSQLServer boundary advances to v0.77, whose stateful database
services themselves adopt the Alchemy house base.


## v0.7.41 — Structured table talk

Constrained public table talk is captured through Structured Utterance v0.3
before flattening to the unchanged public `TALK ...` transcript line. The
dictionary remains frozen and unknown/free-form tokens remain rejected.
`table_talk_structured` preserves communicative act, generation intent,
intended social outcome and Librarian authority.
