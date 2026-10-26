# ooRexx Reasoned Thought v0.1 (strawman)

**Architecture:** Tom Dyer.
**Seed object model + worked-example qualification:** Claude (Opus 4.8), 2026-10-26.
**Status:** strawman, pending agreement with ChatGPT on the board (coordination REQ-00000181).
The evidence-combination maths is explicitly ChatGPT's to own; this package picks a v0 rule
only so the worked example runs.

A provable, defeasible belief model — "object-oriented philosophical thoughts." An idea becomes
a first-class object that records **why** it is held and what would change it; a new utterance
**triggers re-evaluation** and the belief revises. It is the antidote to an LLM asserting a
confident attribution it cannot defend: here a conclusion stands only on its recorded grounds,
and any bearing utterance forces re-settlement.

## The four Alchemy spines meet here

| Spine | Role |
|---|---|
| utterance | the unit of incoming evidence (structured; NL→assertion parsing is a separate seam) |
| intentions | meaning registered once, **status recomputed per utterance from live state** — the SSC write-intentions pattern |
| maths | the confidence-combination rule (v0: noisy-OR + class-rank gating; **ChatGPT to own**) |
| legal | evidence classes carry weight **and** rank; a claim may require a minimum class to be *settled* |

## Model

- **Proposition** — a thought, with the grounds that justify it and an optional `requiresClass`
  (the minimum evidence class needed to *settle* it, i.e. make it assertible).
- **Ground** — `SUPPORT` / `REBUT` (attack the conclusion) / `UNDERCUT` (attack another ground's
  inferential link). Each cites an `Utterance` and carries an `EvidenceClass`.
- **EvidenceClass** — `STYLOMETRIC` < `TESTIMONY` < `DOCUMENTARY` < `PROVENANCE`, each with a
  weight and a rank. No accumulation of weaker-class grounds settles a claim that demands a
  higher class.
- **ThoughtNetwork** — holds propositions; `admit(utterance)` attaches grounds, re-settles the
  affected propositions like a circuit, and returns an **auditable change report**
  (from/to status, confidence, assertibility). `assess(id)` is a pure, re-runnable judgement
  with a `why` audit trail.

## v0 combination rule (open; ChatGPT's lane)

Same-side accumulation by noisy-OR `1 - Π(1-w)`; an undercutter multiplies its target ground's
effective weight by `(1-w_undercut)`; `confidence = support × (1 - attack)`; a proposition is
*settled/assertible* only when confidence ≥ 0.66 **and** a live support ground meets
`requiresClass`. The hard case — a decisive higher-class ground overruling a weaker-class
attack — is deliberately kept out of the worked example; it needs a rank-tiered or log-odds
rule, flagged for ChatGPT rather than guessed here.

## Worked example / qualification

`tests/test_attribution_reeval.rex` runs the model on the RexxLA attribution both Claude and
ChatGPT first misread:

- `P1a` "Claude was involved"; `P1b` "those exact words are Claude's, verbatim" (requires PROVENANCE).
- Stylometric resemblance supports both → **neither assertible**. (The original overconfident
  "it's Claude's" is impossible in the model.)
- The bracket `[Sorry — Claude overstates the obvious ;)]`, admitted as TESTIMONY, **supports P1a**
  and **undercuts** the stylometric ground on P1b: the same utterance moves the two sub-claims in
  opposite directions — P1a → SUPPORTED, P1b → still UNDERDETERMINED.
- Conflicting testimony about the seam leaves it UNDERDETERMINED (a standoff).
- A Message-ID (PROVENANCE) settles P1b: the model is convincible, but only by the decisive class.

## Run

```
sh run_tests.sh
```

Needs ooRexx 4.0+ (`rexx` on PATH). 9 checks; no native build, no Foreign Runtime.
