# Reasoned Thought — Gopher sphere source note (candidate, 2026-10-29)

**Architecture:** Tom Dyer. **Implementation boundaries:** Claude — propositions, grounds, utterances, concept hierarchy, proof exchange and independent adversarial fixtures; ChatGPT GPT-6 — authoritative EvidenceCombiner, EvidenceRevisionAudit and StandardApplicationAudit. This file is a machine-reviewable *source note*, not a registered or accepted Gopher sphere. Rasen Falcon sphere-check currently reports `SPHERE_CHECKER_UNAVAILABLE`; do not claim registry publication.

## Identity and purpose

Logical ID: `reasoned-thought`; Rasen Falcon component `reasoned-thought`.
Git artifact: `packages/oorexx_reasoned_thought_v0.1`.
Implement a replayable, defeasible audit of propositions under stated evidential policy. A model's verbal claim to have revised its opinion does **not** establish that a new warranted defeater exists.

## Architecture / interfaces

1. `ReasonedThought.cls` defines `Proposition`, `Ground`, `Utterance` and an injectable `ThoughtNetwork`. Grounds have SUPPORT / REBUT / UNDERCUT relations; each has an evidence tier, origin and binding scope.
2. `EvidenceCombiner.cls`: `evaluate(proposition) -> BeliefDecision`, ordinal, dependency-aware, with fail-closed cycle/target checks; output is a policy-relative result, not empirical certainty. Derivation protocol v0.3 binds exact claim text when available, ground-origin/links and optional note content.
3. `EvidenceRevisionAudit.cls`: `compare(beforeProposition, afterProposition, claimedStance='')`; distinguishes evidence admissions, policy changes, claim-text substitution, mutated/deleted grounds, unsupported claimed flips, and no change.
4. `StandardApplicationAudit.cls`: same declared rule across comparable chains; may detect disparate application while refusing to infer the merits of the underlying case. Numeric feature values and measurement bases must be genuinely comparable.
5. The separate `ProofBundle` / `ProofReview` classes cover explicit source-and-run proof transport and inspection; their crypto/authentication and external service wiring are separate matters.
6. `ConceptHierarchy` owns universals and concept typing. Subsumption cycles can imply coextension and are not the same as invalid cyclic UNDERCUT dependencies.

## Evidence and scope rules

- Model output, user testimony, narrative summary, dated documents and authenticated generation traces are **different provenance classes**. Claims are proposition-bound; mail Message-ID proves email identity, not the exact LLM-generated passage.
- Evidence class and binding scope are caller-declared until a provenance/warrant validator admits them; `SETTLED` in a simulated combiner alone is **not proof of historical truth**.
- Exact claim-text identity is conservative: semantically equivalent paraphrases may fail closed, while differing modality, time or fictional-world scope must not be normalized without a versioned, source-backed rule.
- A change to evidence admission floors or accepted binding scopes is a **policy event**, not object-level new evidence. Present comparison sees only scopes found among its grounds; full immutable policy fingerprint remains upstream work.
- Inference must not promote unsupported rhetoric, a reported internal reason for a model response, or a fiction axiom into documentary evidence of reality.
- The derivation text is deterministic plaintext; do not describe it as signed proof or a cryptographic digest. `ProofBundle` integrity is separate from external source authenticity.

## Qualification and current branch

Primary candidate: [PR #49](https://github.com/animatedads/alchemy/pull/49) (`reasoned-thought/revision-identity-scope-v03`).
Regression: `tests/test_evidence_revision_audit.rex` (11 previous checks + 6 proposition/policy guards + 3 derivation trace checks, on this branch). This count is a **source assertion count**, NOT a native PASS claim.
Historical fish-essay and Nepopotania corpora are replay-oriented examples with provenance limitations; they are not ground-truth transition oracles.
Native ooRexx 5.3.0 r13196 tests and independent adversarial review must precede PR promotion/merge. Autobuilder is **not running**; do not report autobuild qualification.

## Estate integration and dependency boundaries

- This logic package does not own, deploy or modify rasenfalcon.com website, SMTP/IMAP, LDAP identity, private-CA HTTPS, or ED209 MU/MI XTP transport.
- Rasen Falcon coordination is a mailbox for review evidence, not proof of production service health. Every live deployment requires platform-service-owner tests and receipts.
- When a future Reasoned Thought service runs over JSON-RPC, Wire, NotNotes or the XTP named-service fabric, its transport credentials must be checked by the existing LDAP/private-CA stack, not a parallel authentication implementation.
- Generic finite ordering from Maths can be optional conformance instrumentation, not an authority that redefines what a philosophical evidence class means.

## Open acceptance gates

- Native branch test with stdout/stderr/exit/version.
- Independent falsifier for claimant text edits, same-ID notes, absent accepted-binding scopes and contradictory policy versions.
- Self-contained replay with source-validation receipts and warrant IDs; preserve the distinction between an observed revision and independently sufficient justification.
- Canonical sphere packaging and registry acceptance by the service owner once the checker is configured. This source note alone does **not** satisfy that gate.
