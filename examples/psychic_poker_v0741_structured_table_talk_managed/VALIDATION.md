# Psychic Poker v0.7.39 validation

Validated with the supplied ooRexx 5.3.0 debug build and supplied NoSQLServer v0.68.

## Poker regressions

- PASS evaluator smoke
- PASS psychic information boundaries
- PASS strategy families and privilege boundaries
- PASS side-pot contribution ledger
- PASS betting reopen and all-in runout rules
- PASS poker RNG isolated from NoSQLServer activity

## Reproducibility proof

Seed 424242 was run once without an observer and once with full `PokerExperimentStore`/NoSQLServer logging. Both runs ended identically:

- Ada 1000
- Grace 0
- Alan 2000
- PsiEq 1000
- PsiX 1000
- PsiA 1000
- PsiB 1000

Timing on the supplied debug runtime for that single seeded hand was approximately 0.85 s without storage and 4.76 s with synchronous SQL evidence logging. This identifies persistence/observation overhead as material and keeps performance claims separate from correctness claims.

## NoSQLServer v0.68

- PASS `tests/v068_federated_facade_external_smoke.rex` unchanged.

## Important v0.6 correctness repair

Equity estimation no longer excludes an opponent merely because `totalBet = 0`. A live player with two dealt hole cards remains an opponent until folded, even before that player has acted.

## Campaign semantics

`batch_experiment.rex` is quiet and repeats tournaments by restoring all configured starting stacks whenever fewer than two players remain. The ordinary `experiment.rex` remains a single tournament and retains the live/current-stack interpretation.


## v0.6.1 HALT / native append regression

The user-observed row:

    (1,5,'PsiA','Alan','STRATEGY_READ_AVAILABLE','non-psychic strategy')

cannot violate a declared table constraint: `psychic_capability` has no primary
key, unique, foreign-key or check constraint.

NoSQLServer v0.68's generic file-engine mutation wrapper can return an ooRexx
HALT caught on the mutation path as `NOTEXECUTED / CONSTRAINT`. v0.6.1 leaves
the supplied server source unchanged but recognizes that message as an
interruption in the experiment writer.

All poker regressions pass after changing evidence writes to the public
`FederatedDatabaseEngine~insert(table,row)` surface:

- PASS evaluator smoke
- PASS psychic information boundaries
- PASS strategy families and privilege boundaries
- PASS side-pot contribution ledger
- PASS betting reopen and all-in runout rules
- PASS poker RNG isolated from NoSQLServer activity

A seeded one-hand end-to-end run completed successfully with live object SQL,
historical SQL, capability/observation audit and pot settlement reporting.


## v0.7.2 rerun regression

The second-run `PRIMARY KEY constraint failed` was caused by the GROK runner
constructing every store with explicit `experiment_id=1`.

The runner now omits that explicit ID. The store allocates the next ID from
the persistent `experiment` relation before inserting the run metadata.

Added `test_experiment_id_allocation.rex`, which creates two experiment-store
instances against the same database and requires IDs 1 then 2 with both rows
remaining queryable.

## v0.7.4 report-scope regression

A persistent second run exposed that reporting queries did not filter by
`experiment_id`. Storage was correct; presentation mixed rows from prior runs.

Added:
- `test_report_experiment_scope.rex`: stores conflicting GROK actions in two
  experiments and proves the current-run query returns only the current row.
- `test_report_source_scope.rex`: static guard that historical report queries
  in the runners contain experiment scoping.


## v0.7.6 aggressive ordinary strategy

Validated under the supplied ooRexx 5.3.0 debug runtime.

Passed:
- `test_evaluator.rex`
- `test_betting_rules.rex`
- `test_grok_prompt.rex`
- `test_aggressive_strategy.rex`

`AggressiveStrategy~new` reports:
- `strategyType = AGGRESSIVE`
- `risk = 0.72`
- `bluff = 0.38`
- `aggression = 1.65`

The GROK experiment seats `Hugo` as an ordinary `Player` using this strategy.

## v0.7.7 Psicorp aggressive psychic

Validated under the supplied ooRexx 5.3.0 debug runtime.

Passed:
- `test_psychic_aggressive_strategy.rex`
- `test_grok_prompt.rex`
- `test_strategy.rex`
- `test_psychic.rex`
- `test_betting_rules.rex`
- `test_sidepots.rex`
- `test_experiment_context.rex`

`Maya` is seated as an ordinary public name but internally uses `PSYCHIC_AGGRESSIVE` on team `RED`. The new representation-leverage calculation is post-flop only and samples plausible unseen two-card holdings against the exact readable non-psychic hand on the current board.

A new `experiment_context` table records `casino_seed`, `ai_model`, `prompt_version`, `table_configuration`, and `run_timestamp` for each experiment ID.

## v0.7.8 seed selection / replay

Removed the fixed `424242` seed from normal GROK experiment runs.

Added `CasinoSeed`:
- `fresh` derives a positive Park-Miller-compatible seed from high-resolution
  wall-clock date/time before NoSQLServer is attached;
- `normalize` validates/reduces an explicit replay seed into the PRNG domain.

`test_seed_selection.rex` verifies:
- an explicit seed remains stable;
- two fresh selections separated in time differ;
- two `PokerRandom` instances with the same seed generate the same sequence.

`test_experiment_context.rex` continues to prove the selected casino seed is
persisted with the experiment metadata.

## v0.7.11 representation leverage nil-card repair

Added completeness guards before both target and candidate calls to
`scoreForCards`. The evaluator is intentionally unchanged; malformed
information sets are rejected at the psychic representation boundary instead.

## v0.7.12 Gemini + resource-aware strategy

Added:
- `ResourceAwareStrategy` (`RESOURCE_AWARE`)
- `GeminiAPIClient`
- `GeminiPokerStrategy` (`AI_GEMINI`)
- generic player-name AI prompt (`You are <player>`)
- GEMINI seated under the same blind information condition as GROK
- `test_resource_aware_strategy.rex`
- `test_multi_ai_prompt.rex`

Gemini's API key is read only from `GEMINI_API_KEY`; it is not placed in the
prompt or database.

## v0.7.13 AI package load-order repair

The observed:

    Error 98.909: Class "PLAYERSTRATEGY" not found.

was caused by `ai_gemini.cls` subclassing `PlayerStrategy` without declaring
the package that defines it. Both AI strategy packages now explicitly require
`poker.cls`.

Added `test_ai_package_load.rex`, which directly requires both AI packages and
must resolve their superclass dependencies without relying on runner order.

## v0.7.14 Gemini prompt probe

Added an offline/live prompt probe that:
- prints the exact GEMINI player prompt;
- verifies hole cards, blinds and amount-to-call are present;
- verifies psychic/team/collusion/cheating vocabulary is absent;
- optionally performs a real Gemini API call when `GEMINI_API_KEY` is set;
- prints the parsed action/amount so fallback-vs-live behavior can be diagnosed.

## v0.7.15 seed INTEGER compatibility

Observed failures for seeds `1383738065` and `1338529532` were caused by
NoSQLServer INTEGER validation using ooRexx whole-number classification at the
default numeric precision. Fresh/replay seeds are now restricted to 9 digits.

Added `test_seed_metadata_integer.rex`, which stores and rereads the maximum
allowed seed (`999999999`) through the existing NoSQLServer INTEGER schema.

## v0.7.16 randomized seating

Added `PokerTable~seatPlayersRandomized`, using Fisher-Yates over the table's
own seeded `PokerRandom`.

Added `test_random_seating.rex`, which verifies that:
- a nontrivial seed changes the original fixed order;
- the same seed reproduces exactly the same seat order; and
- the subsequent table RNG sequence also remains identical after the shuffle.

The selected seat order is persisted in experiment context metadata.

## v0.7.17 nine-player correction

The previous table contained eight players:
Ada, Grace, GROK, GEMINI, Hugo, Eve, Frank, Maya.

Added ninth player:
- `Noah`
- strategy `AI_GEMINI_EMULATED`
- ordinary/non-privileged player
- included in seeded initial seat shuffle

Added `test_gemini_emulated_strategy.rex`.

## v0.7.18 resource-aware seat

Added:
- Rosa / `RESOURCE_AWARE`
- ten-player seeded initial seating
- observer-only strategy identity in stack output
- `test_resource_player_seated.rex`
- `PUBLIC_STRATEGY_ROSTER.md`

## v0.7.19 Apex

Added:
- `ApexStrategy` / `APEX`
- ordinary player `Apex`
- inclusion in seeded seating shuffle
- `test_apex_strategy.rex`
- `test_apex_player_seated.rex`
- publishable roster entry

Apex source avoids non-short-circuit compound guards and accesses inherited
strategy values through getters.

## v0.7.20 Blind Benny

Added:
- `BlindPsychicStrategy` / `BLIND_PSYCHIC`
- `PokerTable~estimateBlindPsychicEquity`
- `PokerTable~blindPsychicFieldWeakness`
- independent psychic player `Benny`
- `test_blind_benny.rex`
- `test_blind_benny_seated.rex`

The strategy source is statically guarded against references to
`player~hole`/`player~holeString`.

## v0.7.22 GROK fallback

Added:
- `GrokFallbackStrategy` / `GROK_FALLBACK`
- dedicated wiring in `grok_experiment.rex`
- observer-side `GROK FALLBACK active` marker
- `test_grok_fallback_strategy.rex`
- `test_grok_fallback_large_bet.rex`

Validated under the supplied ooRexx 5.3.0 debug runtime:

    PASS GROK fallback parameters, guard safety and wiring
    PASS GROK fallback folds medium equity versus large bet
    PASS Grok blind prompt contract
    PASS Paladin strategy parameters, guard safety, honesty boundary, and anti-chase discipline

The fallback source avoids non-short-circuit compound guards and uses inherited strategy getters.

## v0.7.23 The_Oracle

Added:
- `OracleHistoryModel`
- `OracleStrategy` / `THE_ORACLE`
- ordinary player `The_Oracle`
- positive-outcome-only training from persistent `hand_result` + `action_log`
- exclusion of psychic historical actions
- seeded empirical action weighting
- conservative no-history fallback
- `oracle_model_snapshot` persistent audit relation
- `test_oracle_strategy.rex`
- `test_oracle_seated.rex`
- `test_oracle_history_model.rex`

Compatibility sweep also repaired a pre-existing Blind Benny test false
positive: a comment inside `BlindPsychicStrategy` contained the literal
forbidden token `player~hole`, so the source-scanning test flagged the comment.
The comment wording was changed; executable Benny behavior is unchanged.

## v0.7.24 Oracle Action Value v2

Replaces winner-only `ORACLE_POSITIVE_OUTCOME_V1` with
`ORACLE_ACTION_VALUE_V2`.

Key changes:
- learns from both wins and losses;
- signed bankroll-normalized action value;
- stronger attribution to later/riskier decisions;
- special fold damage-limitation treatment;
- empirical evidence shrunk toward conservative priors;
- explicit large-bet/current-equity safety adjustment;
- refreshes completed history before every Oracle decision, including earlier
  completed hands in the current experiment.

## v0.7.25 Oracle SQL BOOLEAN repair

Observed live failure:

    Error 34.1: Value of expression following IF keyword must be exactly
    "0" or "1"; found "FALSE".

Root cause: `row["psychic"]` from NoSQLServer is a textual SQL BOOLEAN rather
than an ooRexx logical value. Replaced direct `if row["psychic"]` tests with
explicit normalization accepting `TRUE` / `1` as true.

Added `test_oracle_boolean_boundary.rex`.

## v0.7.26 Oracle RESULT special-variable repair

Observed live failure:

    Object "RESULT" does not understand message "[]=".

Root cause: Oracle history loading used `result` as an ordinary local variable.
`RESULT` is a special Rexx variable and must not be relied upon across message
activity.

Renamed the local to `handOutcome` and added
`test_oracle_result_special.rex`.

## v0.7.27 Oracle snapshot API repair

Live startup exposed a stale v1/v2 interface mismatch in
`PokerExperimentStore~recordOracleModel`: the v2 history model exports
`completedHands` and `learnedActions`, while the store still called
`successfulHands` and `successfulActions`.

The store now uses the v2 getters. Added `test_oracle_snapshot_interface.rex`.
This release is intended to be interpreter-verified before delivery.

### Interpreter verification

Executed with the supplied:

    Open Object Rexx Version 5.3.0 r13196 - Internal Test Version

Passing tests:
- `test_oracle_snapshot_interface.rex`
- `test_oracle_boolean_boundary.rex`
- `test_oracle_result_special.rex`
- `test_oracle_strategy.rex`
- `test_oracle_seated.rex`
- `test_oracle_history_model.rex`

Also executed `grok_experiment.rex` with API keys unset. Startup successfully
created and snapshotted the Oracle model, entered live play, completed hand 1,
and continued into hand 2. The harness run was deliberately terminated by the
external execution timeout during later poker simulation; no Oracle startup or
interface exception occurred.

## v0.7.28 constrained table talk

Added:
- `PokerTableTalkLibrarian`
- 12-token frozen table-talk dictionary
- six exact psychological classes
- public `TALK` hand-history events
- deterministic-player pressure/provocation state
- bounded psychology decision postprocessor
- `table_talk` NoSQLServer relation
- `test_table_talk_dictionary.rex`
- `test_table_talk_psychology.rex`
- `test_table_talk_storage.rex`

Live API agents are not postprocessed: they see the public talk in their normal
prompt and react themselves.

### Public-history privacy repair

During table-talk integration, review found that the existing observer seat-card
display used `PokerTable~log`, which also populates the live AI
`PUBLIC HAND HISTORY`. Those lines are now emitted through `observerLog`, which
prints for the human experiment observer but does not enter `handLog`.

Public speech continues to use `log`, deliberately, because table talk is
information every seated player can hear.

Added `test_public_history_privacy.rex`.

### ooRexx 5.3.0 r13196 runtime acceptance repair

Executed against the supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64`
package (Open Object Rexx 5.3.0 r13196, 64-bit Internal Test Version).

Runtime acceptance found and repaired three integration/harness defects:
- `PlayerStrategy~chooseTalk` used `tokenAt()` as though it returned a
  `PokerTableTalkEntry`; `tokenAt()` retains its token-string contract and the
  librarian now exposes `entryAt()` for classified entry retrieval.
- `PokerTable~maybeTableTalk` assumed every pre-v0.7.28 observer implemented
  `tableTalk`; the callback is now capability-checked with `hasMethod`, keeping
  older observers compatible while `PokerExperimentStore` still persists talk.
- the Apex guard-safety regression matched an ampersand appearing only in a
  comment; the comment was reworded without changing Apex strategy behaviour.

The table-talk dictionary regression now checks the `tokenAt`/`entryAt`
contract explicitly. `test_public_history_privacy.rex` now also performs a
runtime prompt-boundary check proving constrained `TALK` reaches `PUBLIC HAND
HISTORY` while observer seat-card narration does not. The experiment-ID and
Oracle-history tests now remove nested files and directories beneath their
temporary NoSQLServer roots, making repeated test runs clean rather than
inheriting journal/data files or table directories from a prior invocation.

Acceptance evidence:
- complete bundled regression suite: 43/43 PASS;
- immediate second complete run without external temp cleanup: 43/43 PASS;
- `grok_experiment.rex 1 /tmp/hardworld-grok-v0728-acceptance 138472901`
  with `XAI_API_KEY` and `GEMINI_API_KEY` unset: RC=0, one hand completed;
- six `table_talk` rows were persisted during that hand;
- the documented replay example was changed from the now-invalid
  `1384729012` to INTEGER-safe `138472901`.



## v0.7.29 Grok resilience and Apex table-talk response

Runtime regressions added:

- `test_grok_retry_client.rex` — closed-endpoint transport failures retry three
  times and preserve rc/http/stderr diagnostics.
- `test_apex_table_talk.rex` — Apex retains the actual talk entry and speaker,
  counters a deterministic NEEDLE at the offender, uses bounded provocation for
  counter-aggression without mutating measured equity, and retains the heavy
  turn/river fold gate.

The Grok API key remains environment-only (`$XAI_API_KEY`) rather than being
embedded in the curl command line. HTTP 408/425/429, 5xx, transport 000, and
empty/unparseable model output are retryable; stable non-200 client errors are
reported immediately rather than pointlessly retried.

Acceptance evidence for this cut under ooRexx 5.3.0 r13196 Internal Test:

- complete bundled regression suite: **45/45 PASS**;
- immediate second complete run: **45/45 PASS**;
- Grok closed-transport probe: three attempts, `rc=7`, `http=000`, stderr
  captured, then fallback;
- `grok_experiment.rex 1 /tmp/hardworld-v0729-smoke 883636222` with GROK and
  GEMINI keys unset: **RC=0**;
- NoSQLServer-backed tests require the supplied ooRexx runtime's standard
  `csvStream.cls` on `REXX_PATH` (in the extracted build, `/usr/local/bin`).

Live GROK/GEMINI speech remains a separate protocol change: their current API
response contract is still ACTION/AMOUNT only. This release does not claim that
transport retries add a model-controlled table-talk channel.


## v0.7.30 AI speech + Paladin table-talk discipline

Changes validated under the supplied Open Object Rexx 5.3.0 r13196 64-bit
Internal Test build:

- GROK/GEMINI agent prompts now expose the 12 frozen table-talk tokens and a
  four-line `ACTION` / `AMOUNT` / `TALK` / `TALK_TARGET` response contract.
- `Decision` carries optional talk intent from the same model inference.
- the betting loop skips inherited random `chooseTalk` for `AI_` strategies and
  emits only a validated model-selected token/active target after the decision;
  API fallback is therefore silent rather than puppet chatter.
- unknown/free-form AI talk tokens are rejected by `PokerTableTalkLibrarian`.
- Grok and Gemini real HTTP client parsing was exercised against a local loopback
  fixture returning four-line responses; both parsed action, amount, token and
  target successfully.
- Paladin owns its pressure calculation through `handlesTableTalkPsychology`,
  ignores provocation as an aggression lever, and decays shared psychology once.
- Paladin's shallow-SPR raise uses `Decision~amount` correctly as the increment
  above the call; the regression checks a 100 call / 200 effective-behind spot
  produces raise increment 200 rather than double-counting the call.

New/expanded regressions include `test_ai_table_talk.rex` and
`test_paladin_table_talk.rex`, plus updated GROK/GEMINI prompt probes.

Acceptance evidence:

- complete bundled regression suite: **47/47 PASS**;
- immediate second complete run with no external cleanup: **47/47 PASS**;
- `test_grok_retry_client.rex`: three closed-transport attempts with rc/http/
  stderr evidence before fallback;
- local loopback HTTP fixture: real Grok and Gemini clients parsed
  `ACTION/AMOUNT/TALK/TALK_TARGET`;
- `grok_experiment.rex 1 /tmp/hardworld-v0730-onehand 883636222` with both API
  keys unset: **RC=0**, full one-hand fallback/storage path completed.

A separate two-hand container smoke reached the end of hand 2 and then hit the
pre-existing NoSQLServer native-insert HALT/interruption path while writing
`hand_result`.  This is recorded rather than mislabelled as a poker/table-talk
failure; the deterministic 47-test suite and the fresh one-hand integrated run
remain clean.

## v0.7.31 persistent social evidence

Added `PokerSocialEvidenceModel` behind `PokerExperimentStore` and injected its
bounded public-only summary into `PokerTable~agentPrompt` when the observer
provides `socialEvidenceFor`.

Evidence construction is deliberately narrow:

- historical load selects only `experiment_id`, `hand_no`, `seq`, actor names,
  public action, frozen token and talk class from `action_log` / `table_talk`;
- a talk sample is paired with the same speaker's first later public action in
  the same persisted hand;
- live callbacks update the same model after the corresponding rows are
  successfully persisted;
- engine `equity`, `pot_odds`, hole cards, psychic capability/observation data,
  strategy objects and hand evaluator state are not consumed;
- the prompt labels speech as evidence rather than truth and keeps long-run
  bankroll as the only live-agent objective;
- current-hand speakers are prioritised and output is capped at six active
  opponent profiles to bound prompt growth.

New runtime regression `test_social_evidence_model.rex` writes a CHALLENGE and
subsequent RAISE plus a separate baseline FOLD in experiment 1, verifies the
live evidence counts, creates a fresh experiment 2 against the same NoSQLServer
root, and verifies that the same evidence is reconstructed from persisted rows.
It also verifies that the 0.91 engine equity and 0.13 pot-odds values supplied to
the stored Decision do not appear in the social-evidence text, and that the
normal GROK/GEMINI agent prompt includes the public evidence section.

Acceptance under Open Object Rexx 5.3.0 r13196 Internal Test:

- complete bundled regression suite: **48/48 PASS**;
- immediate second complete run: **48/48 PASS**;
- experiment 1 of a same-root two-experiment integration run completed a full
  one-hand fallback path and persisted talk/action evidence;
- experiment 2 successfully allocated, loaded prior Oracle/social history and
  entered live play from that same root before encountering the previously
  documented NoSQLServer native-insert HALT/interruption path during end-of-hand
  `bankroll_sample` persistence. This storage interruption is not attributed to
  the social model; the dedicated cross-experiment persistence regression is
  clean.
- fresh `grok_experiment.rex 1 /tmp/hardworld-v0731-onehand2 883636222`
  with both API keys unset: **RC=0**; final GROK and GEMINI social-evidence
  snapshots showed the persisted `Ada RESPECT -> next FOLD` sample with LOW
  confidence and the matching ordinary-action baseline.



## v0.7.32 social attribution / shadow counterfactual

Validated with the user-supplied ooRexx 5.3.0 r13196 64-bit Internal Test build.

New regression surfaces:

- `test_ai_social_attribution.rex`
  - reconstructs persisted Hugo `CHALLENGE -> RAISE` evidence in a fresh experiment;
  - requires the prompt to expose it as decision-local `E1`;
  - requires a live-AI decision claiming `E1` to retain Hugo/CHALLENGE/sample/confidence provenance;
  - rejects a hallucinated `E99` attribution without discarding the claim itself;
  - proves `AI_GEMINI_EMULATED` does not pollute the live-LLM attribution relation;
  - with `POKER_SOCIAL_SHADOW=1`, proves the identical public state can produce
    `CALL` with social evidence and shadow `FOLD` without it, with the change persisted.
- `test_ai_social_api_parse.rex`
  - exercises the actual curl/HTTP/JSON paths for both Grok and Gemini against a
    local loopback server;
  - verifies `SOCIAL_EVIDENCE` parsing and the temperature-0 decision path.

Acceptance results after the final audit-scope repair:

- complete suite: **50/50 PASS**;
- immediate complete rerun: **50/50 PASS**;
- real one-hand `grok_experiment.rex` with both API keys absent: **RC=0**;
- fallback experiment persisted only genuine GROK/GEMINI rows in
  `ai_social_decision`; the scripted Gemini-emulated seat is excluded.

The optional shadow mode is deliberately off by default because it doubles live
LLM decision calls.  It is an experiment/instrumentation mode, not part of the
normal poker action path.


## v0.7.33 stable social-effect audit

The experiment-34 live run exposed four paired main/shadow differences while
the models returned `SOCIAL_EVIDENCE=NONE`.  v0.7.33 preserves that observation
without overclaiming causality.

New regression surfaces:

- `test_ai_social_unattributed_effect.rex` reproduces `NONE` attribution with a
  stable main/control `CALL` and no-social `FOLD`, requiring
  `STABLE_SOCIAL_EFFECT` and `unattributed_social_effect=TRUE`.
- `test_ai_social_model_instability.rex` deliberately makes two identical-social
  calls disagree and requires `MODEL_INSTABILITY`, even though the no-social
  output also differs.
- `test_ai_social_attribution.rex` now uses strict triplet mode and requires the
  exact decision-local evidence text to be persisted with the validated E1 claim.

`evidence_valid` now means "this is a validated displayed E-id".  Therefore
`SOCIAL_EVIDENCE=NONE` stores `evidence_valid=FALSE`; the new
`attribution_status` field distinguishes `NONE` from an invalid/hallucinated ID.

The strict triplet probe is opt-in because it makes three live model calls per
played AI decision.

Final v0.7.33 acceptance under Open Object Rexx 5.3.0 r13196 Internal Test:

- complete bundled suite pass 1: **52/52 PASS**;
- complete bundled suite pass 2: **52/52 PASS**;
- one-hand `grok_experiment.rex` replay seed `607281577` with both API keys
  deliberately absent and `POKER_SOCIAL_SHADOW=2`: **RC=0**;
- fallback decisions correctly record `probe_mode=0` / `effect_status=NO_PROBE`
  because no live model inference occurred, even though decision-local social
  evidence may have been available to the attempted prompt.

## v0.7.34 authoritative-core rebase and contextual social evidence

Recovery baseline: user-supplied `oorexx-libs(8).zip` (2026-08-22).  Psychic
Poker v0.7.33 in that bundle was byte-identical to the previously accepted
v0.7.33 package.  Its sole vendored NoSQLServer source file was then replaced
with the authoritative `nosqlserver_v0.74/src/NoSQLServer.cls`, unmodified.

Compatibility gate before feature work:

- v0.7.33 + NoSQLServer v0.74 complete regression pass: 52/52 PASS
- immediate second complete regression pass: 52/52 PASS

v0.7.34 adds context-matched social evidence reconstructed from public
`action_log.street`, `action_log.to_call`, and the existing shared sequence
between `table_talk` and `action_log`.  The aggregate evidence remains present;
the matched line compares the talk-conditioned outcome with the same speaker's
baseline on the same street and the same `FACING` (`to_call > 0`) or `FREE`
(`to_call = 0`) state.

`test_social_evidence_context.rex` proves both persisted reconstruction and
current-hand context selection.  `test_nosql74_hand_completion_stress.rex`
exercises repeated `hand_result` and `bankroll_sample` native inserts without
running the expensive poker evaluator.

A diagnostic note on historical HALT reports: externally stopping a long debug
runtime run delivers an ooRexx HALT while whatever NoSQLServer operation is
currently executing.  The poker store intentionally surfaces this as
`STORAGE INTERRUPTED`.  A 25-hand focused completion test (4 players, 200
native inserts across `hand_result` and `bankroll_sample`) completed normally in
13.79 seconds on this validation container.  A much larger debug stress crossed
the container execution limit and was interrupted inside NoSQLServer; that is
not evidence of a spontaneous storage HALT.  v0.7.34 therefore records the
performance/timeout distinction rather than attributing external interruption
to data corruption.

Working-tree acceptance after the v0.7.34 changes, under ooRexx 5.3.0 r13196
Internal Test Version:

- complete sharded regression pass 1: 54/54 PASS
- complete sharded regression pass 2: 54/54 PASS
- shipped `.cls`/`.rex` compile targets: 63
- `rexxc` failures: 0

The suite is intentionally sharded for acceptance because a single long-lived
container command can hit the execution harness limit even when individual
Rexx tests are fast.  Each regression is still launched as its own ooRexx
process.

## v0.7.35 disjoint social-control baseline

Recovery baseline: user-supplied `oorexx-libs(20260822-015159).zip`, outer
SHA-256 `9f56ce7a583300075c9548b6701d1253a3a0fbb4864328ae182da10810c49c3f`.
All nested ZIPs and included manifests verified before poker work.  The
poker-critical shared line remains NoSQLServer v0.74 / Runtime Registry v0.11 /
HardWorld v0.19; the updated bundle additionally carries Camera v0.34 and
`oorexx_work_load_units_v0.2`.  The v0.7.34 vendored
`nosqlserver/src/NoSQLServer.cls` is byte-identical to the authoritative
NoSQLServer v0.74 copy in this recovery bundle.

v0.7.35 corrects a statistical overlap in v0.7.34 contextual social evidence.
The old matched baseline contained every action in the matching context,
including the action already paired to table talk.  The new
`noTalkBaselineStats` / `noTalkContextBaselineStats` populations exclude every
public action used as a speaker's next action after table talk.  Historical
reconstruction marks paired action identities using experiment, hand, speaker,
and shared action sequence; live recording makes the same decision before
updating the silent population.

`test_social_silent_baseline.rex` proves persisted reconstruction, disjointness,
live silent-baseline growth, talk-conditioned growth, and neutral
percentage-point deltas.  Existing contextual/persistence regressions remain
green.

First complete sharded acceptance under Open Object Rexx 5.3.0 r13196 Internal
Test Version: **55/55 PASS**.

Final working-tree acceptance for v0.7.35:

- complete sharded regression pass 1: **55/55 PASS**;
- complete sharded regression pass 2: **55/55 PASS**;
- shipped `.cls`/`.rex` compile targets: **64**, failures: **0**;
- one-hand `grok_experiment.rex` replay seed `607281577` with GROK/GEMINI API
  keys deliberately absent and `POKER_SOCIAL_SHADOW=2`: **RC=0**;
- the real experiment report emitted `no_talk_n` / `delta_vs_no_talk` evidence
  through the ordinary casino prompt/report path while fallback decisions
  remained non-LLM and therefore did not manufacture social-effect probes.

## v0.7.36 decision-unit social evidence

v0.7.36 continues from the manually packaged v0.7.35 Silent Baseline line and
keeps the authoritative NoSQLServer v0.74 vendored source unchanged.

The change removes pseudo-replication from talk-conditioned statistics.  Raw
utterances remain independently persisted in `table_talk`, but class, token,
target and same-context outcome statistics now count a given speaker betting
decision at most once for each corresponding evidence category.  Historical
reconstruction deduplicates by experiment/hand/speaker/action sequence; live
recording uses the same action-event identity while draining pending talk.

`test_social_decision_unit.rex` persists three identical `CALL_OUT` utterances
before one `RAISE` and proves all three speech rows survive while reconstructed
CHALLENGE/CALL_OUT/directed statistics have `n=1`.  It then repeats the live
case with two utterances before one `CALL` and requires each statistic to grow
by exactly one.  The disjoint no-talk comparison remains unchanged.

Prompt contract version: `MULTI_AI_SOCIAL_ATTRIBUTION_V7`.

Acceptance under Open Object Rexx 5.3.0 r13196 Internal Test Version:

- complete regression pass 1: **56/56 PASS** (47-test shard plus final 9-test shard);
- complete regression pass 2: **56/56 PASS** (28-test shard plus the remaining tests,
  with the outer container command split where required);
- shipped `.cls`/`.rex` compile targets: **65**, `rexxc` failures: **0**;
- one-hand `grok_experiment.rex` replay seed `607281577`, with GROK/GEMINI live
  credentials deliberately absent and `POKER_SOCIAL_SHADOW=2`: **RC=0**;
- fallback play remained silent/non-LLM and the ordinary social-evidence report
  emitted decision-unit statistics through the real casino path.

## v0.7.37 Alchemy foundation / authoritative NoSQLServer v0.75 rebase

Recovery baseline: user-supplied
`oorexx-libs(20260822-crypto-consolidated)(20260823-100223).zip`, outer SHA-256
`e95f489b0088c7d11d31f3b04ac7d2bc766661c6e103a0cfaec8292ffe5203c1`.
The bundled Psychic Poker v0.7.36 is byte-identical to the previously accepted
manual package, SHA-256
`4aeb1d041dae330bbeaeca9b45e319f8af178d0b04c004875a3f586a4af7325e`.

Authoritative rebased dependencies used by v0.7.37:

- NoSQLServer v0.75 ZIP SHA-256
  `754b74050b6a838f2e4dfbcb37fbf3504081d8614f0e1ae4922cfe62f6db400b`;
  vendored `src/NoSQLServer.cls` SHA-256
  `15c560afbff0566cb740953011e3946c8451530f79615223607e6f70ed6bcb32`.
- Alchemy Objects v0.4.3 ZIP SHA-256
  `368787648a3ac88aebef169ad34dc3468df888e2dfc3272a09fdd22b67b19764`.
- ooRexx Crypto v0.1 ZIP SHA-256
  `3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a`;
  `src/crypto.cls` SHA-256
  `1bd4765c6d60251f1275790240f70cdbd55cb94ee1f50fa0a703e184e67a2d2f`.

The recovery roll-up itself passed ZIP integrity.  Its bundled Frankenstack
v0.10 is a separate packaging exception: its manifest names eight absent
`vendor/*.zip` files.  That defect was not imported into Psychic Poker and does
not affect the three authoritative dependencies above.

Compatibility was separated from feature work.  Before Alchemy inheritance was
added, accepted v0.7.36 with only its vendored NoSQLServer source replaced by
v0.75 completed the existing suite **56/56 PASS** under Open Object Rexx 5.3.0
r13196 Internal Test Version.

v0.7.37 then adds `PokerAlchemyObject`, a thin Poker-specific subclass of
`AlchemyObject`.  Long-lived domain/service roots inherit it; transient value
objects remain lightweight.  `test_alchemy_foundation.rex` verifies identity,
lifecycle counters, method contracts, requirements/relationships,
CUSTOMER/INTERNAL/SECRET disclosure on concrete owned state, sealed snapshots,
Alchemy runtime-security semantics, and the NoSQLServer v0.75 release boundary.

A specific ooRexx class-scope regression was investigated during integration.
Fixed state emitters execute in the concrete class scope, while superclass
object variables belong to their declaring class.  v0.7.37 therefore avoids
registering superclass-owned `Player`/`PlayerStrategy` fields for fixed state
emission from arbitrary subclasses instead of producing misleading `NIL`
evidence.

Dependency validation performed on the exact vendored bytes:

- ooRexx Crypto v0.1 `MANIFEST.sha256`: **14/14 OK**;
- ooRexx Crypto v0.1 complete tests: **7/7 PASS**;
- Alchemy Objects v0.4.3 `MANIFEST.sha256`: **51/51 OK**;
- Alchemy Objects v0.4.3 complete tests: **22/22 PASS**.

Alchemy Objects' aggregate shell suite is long enough to cross this sandbox's
outer command window.  The first 15 tests completed in the aggregate process;
tests 16–22 were then run as separate ooRexx processes and all passed.  This is
recorded as completed test evidence, not inferred from an interrupted wrapper.

Psychic Poker acceptance under the same r13196 runtime:

- complete sharded regression pass 1: **57/57 PASS**;
- complete sharded regression pass 2: **57/57 PASS**;
- shipped Poker `.cls`/`.rex` compile targets (excluding vendored dependency
  source trees): **66/66**, `rexxc` failures: **0**;
- one-hand real `grok_experiment.rex` replay seed `607281577`,
  `POKER_SOCIAL_SHADOW=2`, GROK/GEMINI credentials deliberately absent:
  **RC=0**;
- fallback paths remained non-LLM; no live-model social-effect claim was
  manufactured.

The runtime package remains ooRexx.  No Python application/runtime glue was
added for the Alchemy integration.  The pre-existing local loopback HTTP helper
used by API parser regressions remains test-only.

## v0.7.38 prompt disclosure/provenance boundary

v0.7.38 advances the accepted v0.7.37 Alchemy/NoSQLServer v0.75 package without
changing betting rules, the frozen talk dictionary, social-evidence statistics,
or provider output syntax.  It moves live prompt assembly through
`PokerPromptEnvelope`, a fail-closed `PokerAlchemyObject` security boundary.

Admissible prompt disclosure is `PUBLIC` plus viewer-owned `CUSTOMER`; the
acting player's own hole cards are the sole CUSTOMER field.  `INTERNAL`,
`SECRET`, observer-only, RNG/engine, other-player private, strategy-internal and
API-secret provenance is rejected before provider invocation.  Public-history
fields additionally reject observer-style `cards=`/seat narration.

The experiment store adds `ai_prompt_boundary`.  For live GROK/GEMINI actions
it persists boundary status, counts, prompt length and SHA-512 identity, never
the prompt body.  Strict shadow mode records MAIN and NO_SOCIAL variants
separately; the same-social stability control reuses MAIN bytes.

Prompt contract version: `MULTI_AI_SOCIAL_ATTRIBUTION_V9`.

### v0.7.38 acceptance evidence

Acceptance runtime: Open Object Rexx 5.3.0 r13196 Internal Test Version, 64-bit.

- complete application regression pass 1: **59/59 PASS**;
- complete application regression pass 2: **59/59 PASS**;
- shipped Poker application `.cls`/`.rex` compile targets, excluding vendored
  dependency trees: **67/67 PASS**, `rexxc` failures **0**;
- `test_prompt_boundary_audit.rex`: **PASS**;
- `test_prompt_boundary_storage.rex`: **PASS**;
- one-hand real `grok_experiment.rex`, replay seed `769232536`,
  `POKER_SOCIAL_SHADOW=2`, GROK/GEMINI credentials deliberately absent:
  **RC=0**;
- real experiment `ai_prompt_boundary` rows for both live seats reported
  `boundary_status=PASS`, `customer_fields=1`, `rejected_fields=0`, and a
  128-hex-character SHA-512 identity while persisting no prompt body.

An earlier smoke attempt at replay seed `607281577` crossed this tool session's
120-second outer execution limit and ooRexx received HALT while evaluating a
blind-psychic field-strength path.  The process had already passed multiple
live prompt-boundary insertions.  This was an external execution-window
interruption, not an assertion/database/prompt-boundary failure; the second
fixed-seed one-hand smoke completed normally at RC=0.


## v0.7.39 prompt manifest acceptance

The prompt boundary now emits `PSYCHIC_POKER_PROMPT_FIELD_MANIFEST_V1`.  The
manifest contains provenance/disclosure labels only, never field values.  MAIN is
the structural reference; NO_SOCIAL must have the identical `core_manifest` and
may differ only in `SOCIAL.*` provenance.  `ai_prompt_manifest` persists the exact
non-content field sequence and `core_contract_status`.  Dedicated regressions
cover compatible MAIN/NO_SOCIAL construction, deliberate non-social drift
rejection, absence of hole-card values from manifests, and NoSQL persistence.


### v0.7.39 acceptance evidence

Acceptance runtime: Open Object Rexx 5.3.0 r13196 Internal Test Version, 64-bit.

- application regression pass 1: 61/61 PASS;
- application regression pass 2: 61/61 PASS;
- top-level shipped Poker `.cls`/`.rex` compilation: 69/69 PASS;
- `test_prompt_manifest_contract.rex`: proves MAIN/NO_SOCIAL core equivalence and deliberate non-social drift rejection;
- `test_prompt_manifest_storage.rex`: proves safe manifest persistence and `REFERENCE`/`MATCH` statuses;
- existing live Grok/Gemini local-HTTP parser regression remains PASS;
- real one-hand `grok_experiment.rex` replay seed `769232536`, credentials absent, `POKER_SOCIAL_SHADOW=2`: RC=0;
- the fallback smoke persisted MAIN manifest rows for both live seats with `PSYCHIC_POKER_PROMPT_FIELD_MANIFEST_V1` and `core_contract_status=REFERENCE`; no NO_SOCIAL inference is generated when the provider is unavailable, so strict MAIN/NO_SOCIAL matching is exercised by the focused live-strategy fake-client regression rather than falsely claimed from fallback play.


## v0.7.40 Alchemy v0.7 execution provenance / NoSQLServer v0.77

Feature scope is deliberately non-behavioural:
- Alchemy Objects v0.7 replaces v0.4.3;
- PokerAlchemyObject uses preferred `INIT:SUPER` construction;
- selected prompt/Oracle/store methods enable Alchemy execution provenance;
- NoSQLServer is rebased from v0.75 to v0.77;
- no betting, table-talk, prompt-field or social-model semantics are changed.

New regressions:
- `test_alchemy_v07_construction.rex`
- `test_execution_provenance_prompt_boundary.rex`
- `test_nosql77_boundary.rex`

### v0.7.40 wrapper compatibility correction

Alchemy v0.7 automatic method instrumentation expects a result-bearing method.
`PokerExperimentStore~beginExperiment` and `recordExperimentContext` are
command-style and intentionally return no object, so they are not wrapped.
Their API is left unchanged rather than manufacturing return values for
telemetry.

### v0.7.40 provenance granularity

Per-field `PokerPromptEnvelope~append` wrapping was deliberately removed after
runtime profiling. Field admission already has dedicated
`PROMPT.FIELD.ACCEPTED/REJECTED` instrumentation; full execution provenance is
retained only at prompt finalization and `PokerTable~agentPrompt`. This prevents
dozens of redundant provenance records per one logical prompt.

### v0.7.40 local r13196 evidence

Runtime: Open Object Rexx 5.3.0 r13196 Internal Test Version, 64-bit.

Completed compatibility set:
- 54/54 non-SHA-heavy `test_*.rex` regressions PASS;
- includes all three new v0.7.40 regressions;
- includes prompt-boundary audit and prompt-manifest contract;
- includes NoSQLServer repeated hand-completion writes and RNG isolation;
- 72/72 top-level Poker `.cls` / `.rex` compile targets PASS with `rexxc`.

Ten inherited deep SHA/evidence tests remain shipped and declared in the managed
suite. In this tool container they cross the external execution window while
inside the unchanged pure-ooRexx SHA-512 / evidence path; no poker assertion
failure was observed before HALT. Their v0.7.39 semantics have the supplied
61/61 acceptance evidence. They are intentionally not relabelled as locally
PASS in v0.7.40.


## v0.7.41 Structured Utterance table-talk evidence

New regressions:
- `test_structured_table_talk.rex`
- `test_structured_talk_no_free_text.rex`
- `test_structured_talk_storage.rex`
- `test_structured_talk_public_compatibility.rex`


### v0.7.41 local r13196 evidence

Runtime: Open Object Rexx 5.3.0 r13196 Internal Test Version.

New feature gates PASS:
- `test_structured_table_talk.rex`
- `test_structured_talk_no_free_text.rex`
- `test_structured_talk_storage.rex`
- `test_structured_talk_storage_runtime.rex`
- `test_structured_talk_public_compatibility.rex`

Representative inherited compatibility gates PASS include:
- betting reopen/all-in rules;
- side-pot contribution ledger;
- psychic information boundaries;
- Blind Benny own-card blindness;
- Apex/Paladin table-talk behaviour;
- GROK/GEMINI constrained table-talk channel;
- public-history privacy;
- seeded random seating;
- RNG isolation;
- Oracle signed action values;
- experiment context/id allocation;
- decision-unit social evidence;
- matched-context and disjoint no-talk social evidence;
- Alchemy v0.7 construction provenance;
- prompt disclosure boundary;
- prompt manifest contract.

All 77 top-level `.rex` / `.cls` targets compile with `rexxc`.

As in v0.7.40, inherited deep pure-ooRexx crypto/SHA evidence paths can exceed
this tool container's external execution window. They remain shipped in the
managed suite and are not relabelled as locally PASS.
