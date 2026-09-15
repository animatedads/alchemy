# GEMINI joins HardWorld Casino

`GEMINI` is a second blind AI player. It receives the same legal player-view
shape as GROK: own cards, board, blinds, pot, stacks, public actions and legal
betting constraints. No privileged-role, team, psychic or hidden-card metadata
is sent to the model.

The client uses Google's Gemini Developer API `generateContent` endpoint with
`GEMINI_API_KEY` from the environment. The default model is
`gemini-3.6-flash`. Set a different model in `GeminiAPIClient~new(...)` if
desired.

Gemini's supplied `ResourceAwareStrategy` is included as `RESOURCE_AWARE` and
is used as GEMINI's fallback if the API is unavailable or malformed.

The table now contains both GROK and GEMINI under the same blind condition,
while the internal privileged players can read both AI players under the
existing game rules.

## v0.7.13 ooRexx package dependency repair

`ai_gemini.cls` and `ai_grok.cls` now each explicitly `::requires "poker.cls"`.
ooRexx resolves class directives while loading required packages; therefore an
AI package that subclasses `PlayerStrategy` must declare that package
dependency itself instead of relying on the caller's `::requires` ordering.

`poker.cls` does not require either AI package, so this dependency is
one-directional and does not create a circular load.

## v0.7.14 Gemini prompt probe

Added `test_gemini_prompt_live.rex`.

It constructs a representative preflop state with GEMINI holding `QS JH`,
prints the exact blind player prompt, rejects forbidden experiment-leak terms,
and—when `GEMINI_API_KEY` is present—sends that prompt through the real
`GeminiAPIClient` and prints the parsed `ACTION` and `AMOUNT`.

Run:

    rexx test_gemini_prompt_live.rex

This is intended to distinguish a genuine Gemini fold from fallback behavior.


## v0.7.30 same-inference table talk

GEMINI uses the same four-line blind-agent contract as GROK: `ACTION`, `AMOUNT`,
`TALK`, and `TALK_TARGET`.  The prompt lists only the frozen Librarian tokens;
Gemini selects a token and active opponent, and the engine supplies the canonical
phrase/class/effects.  Unknown tokens or invalid targets are ignored rather than
becoming free-form speech.  Fallback play is silent unless a real model decision
contains a valid talk choice.

## v0.7.31 public social evidence

Before each live GEMINI decision, the ordinary-player prompt may now include a
`SOCIAL EVIDENCE (PUBLIC EMPIRICAL HISTORY)` section reconstructed from
persisted `table_talk` and `action_log` rows.  It pairs a speaker's classified
utterance with that speaker's next public betting action, compares the sample
with the speaker's overall public action baseline, and labels sample confidence.

The section is evidence rather than authority: speech is not assumed truthful,
no hidden cards or engine equity are exposed, and GEMINI's objective remains
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
available.  This is observational evidence only; GEMINI is not told that any
talk class implies strength or weakness.  The prompt version recorded in
`experiment_context` is `MULTI_AI_SOCIAL_ATTRIBUTION_V5`.

## v0.7.35 silent-context social baseline

GEMINI receives the same disjoint silent comparison as GROK.  A
`delta_vs_no_talk` line compares talk-conditioned next actions with the
speaker's matched public actions when no table-talk event was pending.  The
casino supplies the observed distributions only and does not convert them into
a bluff/strength/tilt rule.

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

Every GEMINI prompt boundary now emits a safe `SOURCE|DISCLOSURE` manifest.
For strict social counterfactuals the MAIN and NO_SOCIAL prompts must have an
identical non-social `core_manifest`; only `SOCIAL.*` provenance may differ.
Prompt values and hole cards are never stored in the manifest.  A structural
drift aborts the experiment rather than allowing a contaminated social-effect
comparison.
