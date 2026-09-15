# HardWorld Casino table talk

Table talk is deliberately NOT free text.

Each strategy may choose to speak only by selecting a token from
`librarian/poker_table_talk_dictionary.txt`. `PokerTableTalkLibrarian`
performs exact token classification, so semantic interpretation is frozen and
replayable.

Classes:
- PRESSURE
- CHALLENGE
- INTIMIDATE
- NEEDLE
- CLAIM
- RESPECT

Every utterance is public and is appended to the hand history:

    TALK Hugo -> GEMINI [INTIMIDATE] "You look nervous."

Therefore live GROK/GEMINI receive it naturally through their existing public
hand-history prompt. They receive no hidden strategy or psychic metadata.

For deterministic strategies a small generic psychology layer tracks:
- psychological pressure: can turn marginal calls into folds;
- provocation: can rarely turn a borderline CHECK/CALL into a minimum raise.

The layer never changes engine equity, never invents a card fact, and never
creates an illegal action.

Psychological state decays after decisions and halves between hands.

All talk is persisted in the NoSQLServer `table_talk` relation so its actual
effect on folding, raising, profitability and individual players can be
analysed later.


## Apex v2 counter-talk

Apex now consumes the existing bounded psychology state directly and retains the
rich provenance of the most recent utterance (`PokerTableTalkEntry` plus the
speaker object). `NEEDLE` and `CHALLENGE` can lower Apex's aggression threshold
by at most 0.05; `PRESSURE` and `INTIMIDATE` do not fabricate equity or force a
fear response. Heavy turn/river action has an independent discipline gate.

Apex can also answer a recent utterance with a dictionary-constrained response.
The response is represented as a `PokerTableTalkChoice`, so the table targets the
actual offender when that player is still active rather than selecting a random
target. Each incoming utterance is consumed at most once as a retaliation trigger.


## v0.7.30 live AI speech channel

GROK and GEMINI now have a real model-controlled mouth as well as ears.  The
player prompt asks for machine-readable lines from the same inference:

    ACTION=FOLD|CHECK|CALL|RAISE
    AMOUNT=<raise increment or 0>
    TALK=NONE|<frozen Librarian token>
    TALK_TARGET=NONE|<active opponent name>
    SOCIAL_EVIDENCE=NONE|<decision-local E-id>

The model never supplies public prose. `PokerTable~maybeAIDecisionTalk` accepts
only tokens classified by `PokerTableTalkLibrarian` and only an active named
opponent; unknown/free-form tokens and invalid targets are discarded.  The
Librarian remains authoritative for the phrase, class, pressure and provocation
deltas.  The resulting utterance uses the normal public `TALK` history/storage
path.

AI speech is emitted from the same decision that produced the betting action.
The pre-decision random `PlayerStrategy~chooseTalk` path is skipped for `AI_`
strategies, so an unavailable API/fallback strategy cannot make puppet-GROK or
puppet-GEMINI blurt random dictionary phrases.

## Paladin table-talk discipline

Paladin now owns its bounded public psychology calculation via
`handlesTableTalkPsychology`, avoiding a second generic postprocessor pass.
Pressure narrows Paladin's forgiveness margin without changing measured equity;
provocation is deliberately not allowed to buy extra aggression.  Its existing
seeded jitter, street-equity decline memory, bet-size margin and shallow-SPR
logic remain ordinary/public-information mechanisms.

The shallow-SPR path also uses the engine's actual raise convention correctly:
`Decision~amount` is the raise increment above the call, so effective chips
behind are emitted directly rather than adding `toCall` a second time.

## v0.7.31 public social evidence model

Table talk is now available to the live LLM seats as learned public evidence,
not merely as transcript colour. `PokerSocialEvidenceModel` reconstructs and
maintains a deterministic cross-experiment ledger from only two persisted
public relations:

- `table_talk`: speaker, target, frozen token/class and shared sequence number;
- `action_log`: player, public betting action and the same shared sequence.

For each utterance the model pairs that speech event with the **speaker's next
persisted public betting action in the same hand**. It never reads `equity`, hole
cards, psychic observations, strategy objects or private card state. The model
also maintains each speaker's ordinary public action baseline so an LLM can
compare a talk-conditioned sample with that player's normal behaviour.

Before a GROK/GEMINI decision, `PokerTable~agentPrompt` now contains a bounded
`SOCIAL EVIDENCE (PUBLIC EMPIRICAL HISTORY)` section. Current-hand speakers are
prioritised, then the most-sampled active-opponent patterns, with at most six
opponent profiles. Evidence includes sample counts, LOW/MEDIUM/HIGH confidence,
next-action counts, baseline counts, current token detail when relevant, and a
viewer-specific "directed at you" sample when one exists.

The prompt explicitly states that speech is **evidence, not truth**, reveals no
hidden cards, and does not change the live agents' objective: maximise long-run
chip bankroll. No mechanical pressure/provocation adjustment is applied to
GROK/GEMINI. They decide for themselves whether a verbal pattern is predictive.

The in-memory model is updated immediately as new `table_talk` and `action_log`
rows are persisted, and a fresh experiment reconstructs the same statistics
from earlier experiments. This gives the live agents genuine cross-hand social
memory without privileged information or a second model call.



## v0.7.32 social attribution and counterfactual audit

The social evidence block now labels each displayed opponent profile with a
**decision-local** ID (`E1`, `E2`, ...).  GROK/GEMINI return one additional
constrained field:

    SOCIAL_EVIDENCE=NONE|E1|E2|...

This is an attribution claim, not proof of causality.  `PokerSocialEvidenceModel`
retains the exact evidence object associated with each displayed ID for that
viewer/decision.  `PokerExperimentStore` validates the returned ID before
persisting it in the new `ai_social_decision` relation, alongside speaker,
class/token provenance, sample count and confidence.  A hallucinated or stale
ID is retained as evidence of what the model claimed but marked invalid.

Only the real `AI_GROK` and `AI_GEMINI` seats are written to this relation;
scripted `AI_GEMINI_EMULATED` decisions are deliberately excluded.

For causal probing, set:

    POKER_SOCIAL_SHADOW=1

When the real API client supports deterministic-temperature calls, the live
agent is queried at temperature 0 with the normal public social evidence, then
queried a second time on the **same public poker state** with the social-evidence
statistics omitted.  The second answer is a shadow counterfactual: it is never
played and never emits table talk.  `ai_social_decision` records the shadow
action/amount and separate `action_changed` / `amount_changed` flags.

This still is not a philosophical proof that the model "reasoned" from an
utterance; it is a much stronger experimental fact: under a deterministic
paired probe, adding the social-evidence block did or did not alter the model's
selected betting output.


## v0.7.33 decision-local evidence snapshots and stability controls

Experiment 34 demonstrated that a played decision can differ from the no-social
shadow while the model returns `SOCIAL_EVIDENCE=NONE`.  v0.7.33 treats those as
separate facts.  The `ai_social_effect` relation stores the exact social block
shown for that decision, evidence count, attribution status, main output,
no-social shadow, optional identical-social control and a conservative effect
classification.

`POKER_SOCIAL_SHADOW=1` is a two-call sensitivity probe.
`POKER_SOCIAL_SHADOW=2` is the stricter three-call stability probe.  In triplet
mode the labels are:

- `STABLE_SOCIAL_EFFECT` — main and identical-social control match; no-social differs.
- `STABLE_NO_EFFECT` — all relevant action/sizing outputs match.
- `MODEL_INSTABILITY` — the identical-social control does not reproduce main.

The model's E-id claim is orthogonal.  A stable effect can be `VALID`, `NONE`,
or `INVALID` attribution.  `NONE + STABLE_SOCIAL_EFFECT` is flagged as
`unattributed_social_effect=TRUE`.

## v0.7.34 context-matched evidence

Aggregate talk/action counts remain visible for continuity, but every displayed
social-evidence candidate may now include a matched baseline using only public
betting context:

- the same speaker;
- the same street (`PREFLOP`, `FLOP`, `TURN`, `RIVER`); and
- `FACING` when the paired action had `to_call > 0`, otherwise `FREE`.

This prevents simple action-context differences from masquerading as linguistic
tells.  A class that appears to precede many folds can therefore be compared
against that speaker's ordinary fold rate in the same street/facing state.  The
model still receives counts rather than a programmed interpretation and remains
free to ignore weak samples.

## v0.7.35 disjoint no-talk comparison

The contextual social model now distinguishes **talk-conditioned** actions from
**silent** actions.  A public betting action that is the speaker's next action
after one or more utterances is paired to those utterances and is excluded from
the no-talk baseline.  Actions with no pending utterance from that speaker are
eligible for the silent baseline.

Both populations are still matched by speaker, street, and `FACING`/`FREE`
state.  The prompt presents action-count distributions plus neutral
percentage-point deltas.  This prevents a talk sample from diluting its own
comparison population while avoiding any built-in interpretation such as
"CHALLENGE means bluff".


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


## v0.7.39 counterfactual structural control

The social-effect shadow experiment now verifies its own construction. MAIN and
NO_SOCIAL retain identical non-social prompt provenance and may differ only in
`SOCIAL.*` fields.  This prevents an accidental game-state/history/output-policy
change from masquerading as a table-talk effect.  The persisted manifest is
non-content metadata only.
