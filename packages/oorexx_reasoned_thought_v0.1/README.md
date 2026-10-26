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
- **Proof of Analysis** (`ProofOfAnalysis.cls`) — an LLM ships a *structured, self-describing
  proof* instead of prose, so a second instance re-runs it rather than re-reads it. Three
  contestable layers: `ProofStatement` (the shared claims), `CategorisationPolicy` (how each is
  typed — debatable, but a pure function once the policy is fixed), and the proof structure
  (role/target/warrant). `Proof~run` emits a `ProofCertificate` that replays to a deterministic
  fingerprint; `ProofReview~compare` diffs two certificates and classifies the divergence
  `WARRANT > CATEGORISATION > CONCLUSION_ONLY > AGREE`. `ProofExchangeMcpOperations~dispatch`
  (`proof.run`, `proof.review`) is the MCP surface; the certificate's `render` string is the wire
  form.
- **Belief Journal** (`BeliefJournal.cls`) — retroactive revision: decisions `restsOn` claims;
  `review(newCombiner)` replays every claim under a new thinking model, finds those that regressed,
  and traces forward to the decisions that fall ("let me think about what I missed"). A
  justification-based truth-maintenance pass. `NaiveEvidenceCombiner` is a stand-in for a weaker
  prior model (ignores binding scope) so the past can be replayed.

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

## Worked examples / qualifications (`sh run_tests.sh`, 39 checks)

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

**3. Proof-of-analysis exchange** (`tests/test_proof_exchange.rex`): two instances run the *same*
proof over the *same* statements under *different* categorisation policies; the review localises
the disagreement to the one statement they typed differently (`s1`: TESTIMONY vs STYLOMETRIC) and
the one conclusion that flipped (`P1a`: SUPPORTED vs HINT), replays to a stable fingerprint, and
classifies a warrant objection as a dispute about the proof's nature — all through the MCP surface.

**4. Retroactive revision** (`tests/test_retro_revision.rex`): an authorship claim that *settled*
under the old naive model (Message-ID taken as proof) *falls* under the corrected ordinal+binding
model; the journal names the two decisions built on it (direct and transitive) as now UNSUPPORTED,
with the broken link in each — "what did I miss."

**5. Circular dogfood** (`tests/test_dogfood_development.rex`): the module audits its *own*
development. This session's real design decisions are encoded as justified nodes; replayed under
the model we ended with, the journal flags exactly the decisions we actually revised after
ChatGPT's correction, identifies the single falsified claim, and closes the loop
(model → fail → revise → uphold). Reflective adequacy, not a correctness proof.

## Run

```
sh run_tests.sh
```

Needs ooRexx 4.0+ (`rexx` on PATH). No native build, no Foreign Runtime.
