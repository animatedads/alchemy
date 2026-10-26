# ooRexx Reasoned Thought v0.1 (strawman)

**Architecture:** Tom Dyer.
**Object model, concept hierarchy, qualifications:** Claude (Opus 4.8), 2026-10-26.
**Evidence-combination algebra:** ChatGPT (GPT-6) — authoritative combiner is its lane (coordination REQ-00000189).
**Status:** strawman; spine agreed with ChatGPT, combiner reference-only pending its authoritative version.

A provable, defeasible belief model — "object-oriented philosophical thoughts." An idea becomes a
first-class object that records **why** it is held and what would change it; a new utterance
**triggers re-evaluation** and the belief revises. It is the antidote to an LLM asserting a
confident attribution it cannot defend: a conclusion stands only on its recorded grounds, weighed
by evidence tier, and any bearing utterance forces re-settlement.

## The spines

| Spine | Role |
|---|---|
| utterance | the unit of incoming evidence (structured; NL→assertion parsing is a separate seam) |
| intentions | meaning registered once, **status recomputed per utterance from live state** — the SSC write-intentions pattern |
| maths | the decision is **ordinal** — grounds weighed by evidence TIER, not a manufactured scalar |
| legal | evidence carries a tier **and a binding scope**; a claim may require a minimum tier to settle, and evidence only counts where its binding is on point |
| rexx-tronics | the network re-settles affected propositions like a circuit when an utterance arrives |

## Model

- **Proposition** — a thought, with its grounds, an `assertFloor` (min tier to be assertible,
  default TESTIMONY), an optional `settleFloor` (min tier to be *settled/proven*), and
  `acceptedBindings` (which binding scopes bear on it).
- **Ground** — `SUPPORT` / `REBUT` (attack the conclusion) / `UNDERCUT` (attack another ground's
  inferential link). Each cites an `Utterance`, an `EvidenceClass`, and a **binding scope** — what
  the evidence actually proves.
- **EvidenceClass** — `STYLOMETRIC` < `TESTIMONY` < `DOCUMENTARY` < `PROVENANCE` (ordinal tiers).
- **ThoughtNetwork** — `admit(utterance)` attaches grounds, re-settles, returns an auditable change
  report; `assess(id)` → a `BeliefDecision` (stance, status, assertible, settled, tiers, live /
  defeated / ineligible ground ids, `why`). The combiner is **injectable**.
- **ConceptHierarchy** — the tree-of-knowledge layer for discussion over *universals* ("all A are
  B"): transitivity, coextension from a subsumption cycle, property flow across an equivalence
  class. Entailment lives here; belief in an asserted universal is decided by the layer above.

## Decision procedure (ordinal; ChatGPT's design, reference here)

`S(p)` = max tier of live SUPPORT grounds, `R(p)` = max of live REBUT; absence = 0.
`S>R` PRO · `R>S` CONTRA · `S=R>0` DISPUTED · `S=R=0` UNDETERMINED. A higher-tier **undercut**
defeats a lower-tier ground's inference; an equal-tier undercut quarantines it (DISPUTED); a
lower-tier one is a visible challenge only. A ground whose binding scope is not on point for the
claim is **INELIGIBLE** and does not count. Assertible iff the dominant tier meets `assertFloor`;
**settled** iff PRO with a live support ground at/above `settleFloor`. No accumulation of weaker
evidence manufactures a higher tier. The authoritative combiner (paraconsistent stance, derivation
certificates, independent-origin dedup, cycle detection) is ChatGPT's to deliver; the
`OrdinalEvidenceCombiner` here is a reference implementation of the agreed rule.

## Worked examples / qualifications (`sh run_tests.sh`, 16 checks)

**1. The RexxLA attribution** (`tests/test_attribution_reeval.rex`, vectors A–E):
stylometric resemblance settles nothing; the bracket (testimony) *supports* "Claude was involved"
while *undercutting* the stylometry→authorship step for "verbatim"; conflicting testimony about the
seam is DISPUTED; a **mail Message-ID does NOT settle verbatim-authorship** — it binds the email
*document*, not the passage (ChatGPT's correction, REQ-00000189); only an authenticated,
passage-bound generation transcript settles it.

**2. Discussion over universals** (`tests/test_hierarchy_discussion.rex`, Tom's example):
`all men are boys` + `all boys are men` ⇒ men ≡ boys (a subsumption cycle read as coextension — the
opposite of a defeat-graph cycle, which fails closed); `boys are foolish` ⇒ men are foolish
(transitivity, premise-bounded); `GIRLS RULE!` entails nothing and is assertible only at the tier
of the voice that shouted it — volume is not evidence.

## Run

```
sh run_tests.sh
```

Needs ooRexx 4.0+ (`rexx` on PATH). No native build, no Foreign Runtime.
