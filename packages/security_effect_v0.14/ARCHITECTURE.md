# Security Effect v0.13 architecture

Security Effect is an action-scoped business-security reasoning domain backed by fixed/versioned policy. It produces evidence, findings, assessments, constraints and capability envelopes; it is not the network perimeter itself.

```text
Sensors / API / Web / Shannon / HardWorld / Interaction Event
                          |
                          v
                 Security observations
                          |
                 findings + uncertainty
                          |
                          v
                SecurityEvidenceStore
                          |
                    frozen snapshot
                          |
                          +-------------------------+
                          |                         |
                          v                         v
                 proposed action          published Security policy
                                                    |
                                      Institutional Policy v0.8
                                      publication authority record
                          |                         |
                          +-----------+-------------+
                                      v
                             SecurityEffectEngine
                                      |
                           assessment + rule trace
                                      |
                                      v
                         SecurityCapabilityEnvelope
```

## Method/object permission boundary

Security Effect describes the security meaning of an exact method invocation. It does not grant that invocation. `SecurityMethodActionFactory` fixes `METHOD_INVOCATION` plus `OBJECT_ID`, `OBJECT_CLASS`, and `METHOD`; `SecurityPermissionBinding` freezes the resulting assessment identity for downstream authority evaluation. ooRexx Access Permissions remains the authority that decides whether the exact subject/object/class/method may execute, and Alchemy Security Manager remains the enforcement point.

The optional bridge is intentionally outside the Security core dependency closure to avoid a cycle: `Security Effect -> binding`, then the host loads `Access Permissions -> permission decision -> Security Manager enforcement`.


## Policy publication authority

`SecurityPolicyCatalog` can consume an Institutional Policy v0.8 authority evaluator. The shared layer may require independently scoped AUTHOR/PUBLISHER authority plus one or more approval classes such as Security and Finance. It can resolve effective-dated authority-profile succession, enforce bounded delegation/revocation, and admit explicit time-limited emergency publication.

The publication record retains the exact authority-profile semantic identity, selected grant ids, approval selections/evidence and emergency path if used. Later governance changes therefore cannot rewrite which authority brought a historical Security policy live.

## Security semantics remain local

Institutional Policy does not understand impossible travel, exploit probes, stored payment instruments, recovery channels, Barbie's bags or customer-service abilities. Those remain Security Effect concepts.

Similarly, publication authority is not a Security finding and must not influence a customer's risk merely because a policy was approved by a particular board.

## Canonical identity

v0.4 uses LF bytes for Security canonical fields. This is an intentional schema/version boundary and is covered by `test_canonical_newlines.rex`.

## Deployment topology

Security policy publication is not synonymous with global rollout. Security Effect v0.8 consumes Institutional Policy topology evidence so the runtime resolves:

```text
security evidence snapshot
        +
proposed action
        +
deployment point
        |
        v
exact published Security policy
        |
        +-- global lifecycle veto
        |
        +-- scoped topology binding
        v
DETERMINISTIC_POLICY_ONLY evaluation
```

The deployment point is operational context (`service`, `region`, `channel`, `tenant`, `cohort`), not a customer-risk feature. It selects which approved policy may run; it does not feed Security findings. Once topology exists, missing deployment context fails rather than bypassing scope controls.



## Progressive reviewed-policy rollout

Security Effect does not create a separate rollout engine. It relies on Institutional Policy v0.8 to authorize bounded overlap and uses the existing exact-version deployment bindings to select the operative reviewed Security policy per deployment point. Customer evidence is untouched by routing. Canary, cutover and rollback therefore change only which deterministic policy artefact may evaluate that evidence.


## Rollout health is not customer risk

Security Effect v0.10 deliberately keeps two evidence planes separate:

```text
customer/session/network evidence ---> SecuritySnapshot ---> Bouncer decision

canary aggregate metrics -----------> rollout gate -------> deployment promotion
```

A high false-positive rate can block rollout of a Security policy but cannot become a `SecurityFinding` about the customers whose interactions contributed to the aggregate. Promotion criteria are fixed and deterministic, and the exact assessment is retained with deployment evidence.


## Post-promotion rollback evidence

Security policy rollout health is a governance plane distinct from customer evidence. After a gated cutover, aggregate production observations can be evaluated against a sealed rollback gate. If the gate returns `ROLLBACK_ELIGIBLE`, an authorized automated rollback binds the deployment scope to the exact prior policy version. The same customer snapshot is then evaluated under that prior policy; no Security finding is created from deployment metrics.


## v0.12 review referral boundary

`SecurityRelationshipCaseBridge` is optional. A sealed `SecurityReviewReferralPolicy` maps an exact Security assessment to a Relationship Case type. Stable idempotent service commands attach reference-only `SUBJECT`, `ASSESSMENT`, and `POLICY_REFERENCE` elements. The bridge never emits `DECISION` or `ACCOUNT_CONTROL`; Relationship Case owns review workflow and an authoritative downstream domain must still own any eventual business mutation.


## Exact invocation freshness and anti-replay

The method/object boundary is strengthened in v0.13 so a Security assessment is not reusable merely because subject, object and method still match. A method invocation carries a sealed identity for the live business arguments and invocation context as well as a unique invocation id and observation time. The Security trace retains the full action and snapshot identities.

```text
actual METHOD checkpoint
  object + method + live arguments + live context
                    |
                    v
       SecurityInvocationEvidence
                    |
                    v
       exact Bouncer assessment
                    |
       freshness / substitution guard
                    |
                    v
          Access Permissions
                    |
       Permission ALLOW consumes
       exact Security invocation
                    |
                    v
       Alchemy Security Manager
```

Security evidence is therefore neither a bearer token nor method authority. A changed argument vector, changed session/workspace identity, expired observation or consumed binding requires a new Security assessment. A Permission denial leaves the fresh Security evidence unconsumed so a correct authority path may still evaluate it within its permitted freshness window.


## v0.14 continuation / commit revalidation

The exact-invocation boundary is necessary but insufficient for staged or long-running operations. v0.14 adds a generic non-authoritative continuation layer. The original Security invocation validation opens an operation; immediately before irreversible publication the host presents exact staged-state and context identities, creates a fresh COMMIT invocation, captures a current Security snapshot, and evaluates Bouncer again. Only an `ALLOW` commit assessment can pass `SecurityContinuationGuard`; Access Permissions still independently decides the exact COMMIT method authority. This is the platform's generic time-of-check/time-of-use security boundary and does not depend on a particular database, accounting engine, payment service, queue or domain aggregate.


### v0.14 start provenance and fail-closed commit consumption

`SecurityContinuationEvidence` requires an origin execution-evidence identity in addition to the original Security binding. This separates "Bouncer found this start invocation acceptable" from "an external authority/enforcement path actually admitted and started the operation". Security Effect retains the evidence reference but does not convert it into method authority.

When an exact Permission ALLOW is being committed, continuation and invocation replay barriers are consumed as one fail-closed hand-off. If a concurrent race makes the second consumption fail after the first has been marked, the first mark remains. Availability/retry convenience must not reopen an irreversible-operation replay window.
