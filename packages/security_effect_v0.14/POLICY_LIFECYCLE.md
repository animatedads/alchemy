# Security Effect v0.10 policy lifecycle

Security rules become operative only as fixed, sealed, effective-dated policy artefacts. Runtime does not ask an LLM for a fresh security judgment.

## Publication

Without a host authority evaluator, the compatibility path retains v0.3 behaviour and publication evidence is labelled `IDENTIFIER_ONLY`.

With an `InstitutionalPolicyAuthorityEvaluator`, a publication request must bind the exact Security policy and publisher. The shared authority profile determines who may AUTHOR, APPROVE and PUBLISH that policy family. Governance can require author/approver separation and verified exact-policy approval evidence.

Security Effect does not own the host evidence-verification mechanism. It can therefore use a normal change-control database, committee workflow, cryptographic signing service or other defensible institution-specific system without baking that infrastructure into Bouncer.

## Effective time

Security policies use `[effectiveFrom, effectiveUntil)` intervals. Exact handovers are unambiguous.

## Replay

`replay()` enforces historical effective dates and emits `OPERATIVE` traces.

`counterfactual()` intentionally evaluates a chosen policy outside that restriction and emits `COUNTERFACTUAL` traces.

`compare()` reports outcome change separately from trace/policy change.

## Authority evidence versus Security evidence

Publication-authority evidence answers **who was allowed to bring this Security policy live**.

Security observations/findings answer **what is happening around this actor/session/action**.

They are separate evidence domains and must not be collapsed.


## Institutional governance

Publication may be guarded by Institutional Policy v0.6. Security rules remain domain-owned, while author/publisher authority, multi-party approval requirements, governance-profile succession, delegation/revocation and bounded emergency publication are evaluated by the shared institutional layer. Publication evidence is retained separately from Security findings and never contributes customer risk by itself.

## Relationship to deployment topology

Global lifecycle (`SUSPEND`, `RESUME`, `WITHDRAW`, `RATIFY`) applies to the exact policy version as a whole. Scoped topology (`ACTIVE`, `STAGED`, `CANARY`, scoped `SUSPENDED`) determines whether that globally eligible policy is operative at a specific deployment point. A global suspension or withdrawal always vetoes scoped activation.
