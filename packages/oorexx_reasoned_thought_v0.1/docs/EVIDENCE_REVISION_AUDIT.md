# Reasoned Thought — EvidenceRevisionAudit dev2 qualification

Architecture: Tom Dyer. EvidenceCombiner and EvidenceRevisionAudit coding: ChatGPT GPT-6.
Claude owns Ground, Utterance, ThoughtNetwork, BeliefJournal, FactsMatrix, and proof/bundle classes.

## Scope

`EvidenceRevisionAudit~compare(beforeProposition, afterProposition, claimedStance="")`
returns a directory of prior and current `BeliefDecision`s, added/removed/modified ground IDs,
`policyChanged`, `claimedMatchesDerived`, and `classification`.

Classification values:
- `NO_REVISION`: same policy-relative decision, even if irrelevant new grounds arrive.
- `CLAIMED_FLIP_UNSUPPORTED`: a claimed new stance disagrees with the evidence-combiner derivation.
- `ADMITTED_DELTA_BACKED`: a decision changed and the new state follows from added grounds,
  with no change to common ground identities or policy. This is **not proof of factual truth**.
- `MUTATED_GROUND_ID`: supposedly immutable evidence with the same ID changed provenance,
  tier, relation, target, scope, or undercut link. Quarantine pending event audit.
- `UNVERIFIED_REMOVAL`: ground disappeared without a recorded revocation receipt.
- `POLICY_CHANGE_REQUIRES_REVIEW`: decision changed due to threshold/policy change.
- `INVALID_COMPARISON` / `INVALID_EVIDENCE` / `UNEXPLAINED_REVISION`.

`EvidenceCombiner` v0.2 also corrects a discovered defect: the prior v0.1 derivation
transcript did not include the source ID or undercut edge. Identical ground IDs and
outcomes could therefore produce identical derivations despite **different inputs**.
The new canonical, length-prefixed lines carry ground ID, kind, tier, source utterance,
claim target, undercut target, binding, and resolution. Deduplication keys also use
length-prefixed fields, avoiding delimiter collisions. The transcript is deterministic,
**not cryptographic or signed**. New rule version makes fingerprints distinguishable.

## Native r13196 testing

Executed on ooRexx 5.3.0 r13196 extracted from the user's Debian package,
without root, network, Foreign Runtime, or interpreter installation. Scripts are
pure ooRexx and use stand-in Proposition/Ground classes matching published method
signatures; they are **not** the upstream full Reasoned Thought qualification.

From the extracted source package directory with `rexx` on PATH:

```sh
REXX_PATH=. rexx test_combiner.rex
REXX_PATH=. rexx test_revision.rex
```

Recorded: 12 original checks PASS + 11 revision checks PASS (23 total), zero FAIL.
Proof-of-work: the added regression first failed on v0.1 because its derivation omitted
source identity. It passed only after the v0.2 fix.

## Actual internal dogfood

The test tracks the combiner's own revision: earlier proposition "the derivation
identifies the full origin/edge context" failed on the before/after test; changed
source/undercut trace fields are the specific admitted new implementation evidence.
Further tests distinguish a new high-tier admitted measurement from a mere socially
persuasive lower-tier rebuttal, guard accidental same-ID mutation/deletion, and keep
fiction-scope evidence from refuting general claims.

## Boundaries / next work

- The combiner does not authenticate a PROVENANCE label, signed source receipt,
  factual measurement, or premise warrant. `ADMITTED_DELTA_BACKED` is policy-relative.
- Historical receipts, explicit revocations, and witness/warrant authority belong to
  their owners; this library may consume receipts but not create its own authority.
- User-controlled `claimStance` is compared against the computed decision; the LLM's
  polished prose is not evidence.
- This version compares two supplied immutable-in-use snapshots; it does NOT
  automatically extract dependencies from natural language. That is the
  separate Structured Utterance/IntentionService extraction seam.
- The full 57-check upstream suite has not been locally executed in this handoff.

## v0.3: exact proposition identity and evidence-scope policy (27 October 2026)

The immutable proposition ID by itself cannot establish that two compared statements
mean the same thing. `EvidenceRevisionAudit~compare` now checks **exact statement
text** where both objects expose `~statement`; a statement change under the
same identifier is `INVALID_COMPARISON`, not a warranted belief flip. Exact
text is deliberately conservative rather than a semantic-equivalence oracle:
normalizing paraphrases, time, modality and fictional-world parameters requires
separately versioned, provenance-backed premise typing upstream. Historical
stand-ins lacking `~statement` preserve compatibility but report
`identityVerified=.false`.

An admission-policy revision is distinguishable from a new evidential defeater.
The auditor now compares `~acceptsBinding` for each binding scope observed in
either ground inventory. A changed scope eligibility returns
`POLICY_CHANGE_REQUIRES_REVIEW`, as does a changed assertion or settlement
floor **even if the output stance stays the same**. The result includes
`changedBindings` and `bindingPolicyCoverage=OBSERVED_GROUND_SCOPES_ONLY`:
unreferenced accepted scopes cannot be compared until the Proposition object
supplies an immutable policy fingerprint.

Ground identity now includes `~note`, when exposed. A changed note with the
same Ground ID is `MUTATED_GROUND_ID`. Six owner-side regression assertions
cover statement substitution, scope eligibility, explicit coverage limit,
no-output policy change, note mutation, and an unchanged control case.

The comparison still operates on caller-provided admitted grounds. Its results
prove neither the external truth of those grounds nor the historical cause of a
model's reported self-correction. This increment is **not** an independent
transcript classifier; FISH/NEPO corpora remain replay-oriented until a live
structured-utterance/dependency extractor exists. Tests must be run under the
actual ooRexx interpreter before claiming native qualification.
