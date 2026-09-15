# Security Effect v0.14 — “Bouncer”

Security Effect is the platform's deterministic **business-security understanding** layer. It is the Pit Boss / professional security desk: not a WAF, firewall, universal customer score, morality classifier, or runtime LLM guardrail.


## v0.14 continuation / irreversible-commit boundary

A fresh method assessment is no longer allowed to silently survive across a long-running staged operation. `SecurityContinuationEvidence` links an admitted invocation to a stable operation/intent identity; `SecurityCommitEvidence` then seals the exact staged-state identity, live context and observation time immediately before publication. A fixed `security.continuation.policy/0.1` governs maximum continuation age, commit-evidence freshness, required identities and single-use commit semantics.

`SecurityContinuationGuard` requires a **fresh Security assessment for the COMMIT method against the current Security snapshot**. New evidence appearing after the original method admission can therefore change the commit disposition to `HOLD`/`REVIEW_REQUIRED`. Exact state or context substitution is rejected, stale commit evidence cannot be revived by re-evaluation, and a successful commit cannot be replayed.

The optional `SecurityContinuationAccessPermissionsBridge` combines this with the existing exact invocation freshness boundary, then asks Access Permissions for the exact COMMIT method authority. Security continuation evidence remains non-authoritative. See `CONTINUATION_COMMIT.md`.

A continuation cannot be minted from Security validation alone. It must retain a non-empty origin execution-evidence identity supplied by the host/enforcement boundary after the underlying operation was actually admitted/started. The reference is provenance, not Permission authority. Combined commit consumption is fail-closed: a race cannot restore an already-marked continuation merely to permit replay.

## v0.13 exact-invocation freshness boundary

Security Effect now binds method security meaning to the **actual invocation being attempted**, not merely to subject/object/class/method. `SecurityInvocationEvidence` seals an invocation id, deterministic argument identity, invocation-context identity and observation time; `SecurityPermissionBinding` additionally retains the exact Security action identity and snapshot identity. A fixed `security.invocation.policy/0.1` controls freshness, future-clock tolerance, required identities and single-use behavior.

`SecurityInvocationGuard` rejects argument substitution, session/context substitution, stale evidence and replay. A Permission denial does not consume the Security evidence; a successful exact Permission authorization does. The optional `SecurityInvocationAlchemyPermissionPolicyAdapter` creates fresh invocation evidence from the live Alchemy `METHOD` checkpoint and its actual argument vector, verifies that Bouncer assessed that exact evidence, then invokes Access Permissions. A stale Security `ALLOW` therefore cannot be replayed against changed live arguments.

This remains an evidence boundary, not an authority boundary. Security Effect says what this exact invocation means; Access Permissions decides whether it is authorized; Alchemy Security Manager enforces the decision.


## v0.12 method/object permission boundary

Security Effect now exposes a typed method-invocation action factory and an immutable `SecurityPermissionBinding` containing the exact subject, object id, object class, method, Security disposition, Security policy identity, trace identity, and constraints. The binding is security meaning, not method authority.

An optional `SecurityAccessPermissionsBridge` can materialize that exact assessment as an ooRexx Access Permissions `PermissionRequest`. The dependency direction remains deliberate: Access Permissions consumes Security Effect; Security Effect core does not require or invoke Permissions.

The integration tests prove three non-negotiable boundaries: Security `ALLOW` alone still yields Permission default `DENY`; a real Permission rule cannot override Security `HOLD` / `REVIEW_REQUIRED`; and an exact permission for one object cannot float to a second object of the same class. A review-required method may open durable Relationship Case work while an unrelated method remains permitted, and the review case itself still carries no `DECISION` authority.

## v0.11 deterministic review referral bridge

Bouncer can now hand an action-scoped `REVIEW_REQUIRED` / `HOLD` assessment to the platform's general Relationship Case service through an optional bridge. The hand-off is governed by a separate sealed/versioned `security.review.referral/0.1` policy; Security Effect does not simply open a case for every non-ALLOW result.

The bridge opens a stable idempotent case and attaches only opaque references to the Security subject, exact assessment, and exact referral-policy identity. It deliberately never manufactures a Relationship Case `DECISION` or `ACCOUNT_CONTROL` element. Review work can therefore be opened without the referral acquiring downstream execution authority.


## v0.10 post-promotion rollback gate

Bouncer now exercises Institutional Policy v0.8's post-cutover evidence gate. A production successor can remain operative while aggregate health is within the reviewed limits. If fixed degradation criteria become true, `applyAutomatedRollback` may route the affected deployment scope back to the exact prior reviewed Security policy. The rollback deployment retains the exact gate assessment.

This is not customer risk scoring. False-positive rates, severe-incident counts, sample sizes, and monitoring windows belong to deployment governance and never enter `SecuritySnapshot`. A manual authorized rollback remains available when incident evidence falls outside the predeclared metric model. The canonical Security rule schema remains `security.policy/0.5`.

## Core invariant

**Model-generated is not model-controlled.**

A human or LLM may help draft a policy. An operative policy is a sealed, versioned, reviewable algorithm that has passed publication gates. Runtime evaluation does not ask an LLM whether a customer “looks suspicious”. Repeated evaluation of the same sealed action, evidence snapshot and policy version is deterministic.

`SecurityEffectBuild~DECISION_MODE` is `DETERMINISTIC_POLICY_ONLY`.

## Business-understanding separation

Security Effect keeps observations, findings, counterevidence, unknowns, snapshots, action surfaces, fixed policy frameworks, assessments, capability envelopes and causal traces separate. There is deliberately no `riskScore(customer)` or generic `hasFlag(customer)` API.

## Institutional governance authority

Security Effect v0.10 consumes Institutional Policy v0.8. Bringing a Security policy live can therefore be governed with the same fixed/reviewable discipline as the policy itself.

A host may require **multi-party approval**. For example, a payment-security policy can require one `SECURITY` approver and one independent `FINANCE` approver, with independently verified evidence for each. The publication record retains both selections rather than flattening them into a generic “approved” flag.

Governance is also effective-dated. `InstitutionalPolicyAuthorityProfileCatalog` lets Security policy publication resolve the authority profile actually operative at the publication instant. A later committee or delegation change cannot rewrite the authority evidence attached to an older Security policy.

Delegation/revocation and bounded break-glass publication are common institutional mechanisms rather than Security-specific ad hoc code. Emergency Security policy requires explicit `EMERGENCY_PUBLISHER` authority and an expiring policy window; that authority cannot be reused as ordinary publisher authority.

This governance evidence is strictly separate from customer/security evidence. Finance approving a payment-security rule does not make a customer more suspicious; it only proves the institution was entitled to deploy that rule.





## v0.9 deterministic rollout evidence gates

Bouncer can now canary a reviewed successor policy and require fixed measurable evidence before that successor may be promoted to `ACTIVE`. The gate is an Institutional Policy artefact embedded in the authorized progressive rollout; it is not an LLM judgement and cannot change because somebody presses Submit again.

The canonical acceptance test uses a Security rollout gate requiring at least 1,000 evaluated actions, false-positive rate at or below 1%, no severe security incidents, at least five minutes of evidence, and fresh evidence at promotion time. A 100-action sample is `INSUFFICIENT_EVIDENCE`; a 2.5% false-positive rate is `PROMOTION_BLOCKED`; 6,000 actions at 0.3% with no severe incidents is `PROMOTION_ELIGIBLE`.

These measurements are **deployment/governance evidence**. They never enter `SecurityEvidenceStore`, never appear in a customer's `SecuritySnapshot`, and never become a reason to distrust the customer. They only determine whether the institution is entitled to roll out a particular reviewed Bouncer algorithm.

The successful deployment binding retains the exact assessment and gate identity that permitted cutover. Authorized failed promotion attempts remain available from the Institutional Policy catalogue for audit. Rollback to the exact prior reviewed Bouncer policy remains available without requiring a passing health report for the successor.

The canonical Security rule schema remains `security.policy/0.5`; v0.9 changes deployment-governance evidence, not Bouncer's action/finding rule language.

## v0.8 progressive policy rollout

Bouncer can now run two **already reviewed and published** versions of the same Security policy concurrently during a bounded rollout window. This is deployment behaviour, not probabilistic policy generation.

A normal cohort can remain on v1 while a pilot cohort receives v2 under `CANARY`. A later broad v2 `ACTIVE` binding performs cutover. If operational evidence justifies rollback, a later equally-specific binding to the exact immutable v1 artefact restores v1; no policy is regenerated and no runtime LLM is consulted. Historical replay continues to reconstruct which exact version the deployment topology selected at the action time.

The overlap itself requires separately retained `DEPLOY` authority evidence and is time-bounded. If the institution leaves both versions operative beyond that authorized window, Bouncer returns `PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED` rather than silently accepting permanent ambiguity.

The Security rule schema remains `security.policy/0.5`: v0.8 changes policy deployment/version-selection mechanics, not the meaning of the Security policy language.

## v0.7 deployment topology

Bouncer can now distinguish **approved policy** from **where that exact policy is deployed**. A `SecurityPolicyCatalog` may bind the same immutable Security policy to different deployment scopes across service, region, channel, tenant and cohort.

For example, the same exact policy can be:

```text
London / commerce / web              ACTIVE
Kazakhstan / commerce / web          STAGED
Kazakhstan / commerce / web / PILOT  CANARY
Kazakhstan / OurLadyAir / Shannon    ACTIVE (broader binding)
```

`SecurityEffectRuntimeModule~assess(action, deploymentPoint)` and `SecurityPolicyReplayEngine~replayPublished(..., deploymentPoint)` use the shared topology resolver. `STAGED`, scoped `SUSPENDED`, and `NOT_DEPLOYED` states stop policy execution; `ACTIVE` and `CANARY` are operative. Global policy suspension/withdrawal remains stronger than all scoped bindings.

Once topology bindings exist, omitting the deployment point fails with `DEPLOYMENT_POINT_REQUIRED`; it cannot be used as a compatibility escape hatch around a staged or suspended surface. Catalogues without topology remain compatible with the older global resolver.

Deployment evidence is governance evidence, not customer evidence. Moving a policy from staged to active cannot make Barbie, a Kazakhstan session, or any other customer more suspicious; it only changes which reviewed institutional algorithm is permitted to execute on that surface.

## v0.6 deployment lifecycle

Bouncer now distinguishes an immutable published Security policy from its current deployment state. `SecurityPolicyCatalog` consumes Institutional Policy v0.6 lifecycle evidence. Authorized security operations can suspend, resume, withdraw, or ratify an exact policy version without altering the Security policy artefact or the customer evidence that policy evaluates.

This matters operationally: if a Security policy itself is suspected of being defective, the runtime must not keep making customer decisions under it merely because its semantic effective dates still include the current time. A catalog-backed runtime receives `POLICY_SUSPENDED` or `POLICY_WITHDRAWN` and stops evaluation. Resume restores the same exact policy identity.

Emergency Security policy may later acquire `RATIFY` evidence from normal authority, but ratification does not convert a bounded emergency rule into an indefinite one. Continuing beyond its original effective window requires a new normally governed release.

Security Effect v0.8 advances the component API to `security.effect/0.8` while deliberately retaining `security.policy/0.5`: deployment-governance mechanics changed, but the canonical Security policy rule format did not.

## Policy lifecycle and replay

`SecurityPolicyCatalog` subclasses `InstitutionalPolicyCatalog`. Policies use `[effectiveFrom, effectiveUntil)` semantics, duplicate/overlapping versions are rejected, and named supersession is verified.

`SecurityPolicyReplayEngine` distinguishes:

- operative replay — the policy actually valid at the historical instant;
- counterfactual replay — an explicitly hypothetical alternative policy; and
- comparison — business-outcome change separately from trace/policy-identity change.

Decision traces label `OPERATIVE` versus `COUNTERFACTUAL` so hypothetical policy results cannot masquerade as historical authority.

## Cross-domain interpretation is policy-controlled

`SecurityExternalSignal -> SecurityEvidenceMappingPolicy -> SecurityFinding`

HardWorld, Interaction Event, Reputation Effect, Shannon and other producers are not silently re-labelled as security truth. Mapping policies are sealed/versioned artefacts; findings retain the rich external source object and the exact mapping rule/policy that authorised the interpretation. Unmapped signals return `NO_MAPPING`.

## Capability envelopes

`SecurityCapabilityEnvelope` merges contributions by consequence:

`ALLOW < CAUTION < REVIEW_REQUIRED < HOLD < REJECT`

A weaker contribution cannot erase a stronger constraint. Unaffected capabilities remain usable unless another applicable contribution constrains them. This is how a suspicious session can still ask Shannon about a delayed flight while a £20,000 stored-card gold purchase is held.

## Canonical scenarios

### Kazakhstan / £20,000 gold

Recent London activity followed thirty minutes later by Kazakhstan, unfamiliar device context and unknown VPN baseline can HOLD the high-value purchase, freeze recovery-channel mutation and require out-of-band confirmation while booking/customer-service abilities remain available.

### Barbie / cross-session restricted purchase

A mother's statement remains an `UNVERIFIED_THIRD_PARTY_REPORT`, not truth. Relevant institutional findings can survive into a new session so `PURCHASE_MORE_BAGS` routes to review while existing-order/customer-service abilities continue.

### Active exploit probing

Probe correlation uses its own sealed/versioned `SecurityProbePolicy`. Correlated exploit probing can constrain privileged mutation without indiscriminately poisoning unrelated reads.

## Canonical identity fix

v0.4 changes `SecurityCanonical~field` to emit a real LF byte (`'0a'x`) rather than the two literal characters backslash+n. This intentionally changes Security semantic identities across the v0.3→v0.4 boundary and improves interoperability/canonical representation. A regression test fixes that byte-level contract.

## Operational objects

Alchemy-derived stateful/service boundaries:

- `SecurityEvidenceStore`
- `SecurityEffectEngine`
- `SecurityPolicyCatalog`
- `SecurityPolicyReplayEngine`

Semantic/value objects remain lightweight deterministic objects.

## Dependencies

- ooRexx 5.3.0 r13196 or compatible
- Institutional Policy v0.8
- Alchemy Objects v0.8
- ooRexx Crypto v0.1 (Alchemy transitive closure)

Interaction Event v0.3 is an integration-test companion, not a hard runtime dependency.

No runtime LLM dependency.
